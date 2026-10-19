import asyncio
import json
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from .. import razorpay_client
from ..auth import current_user
from ..config import payments_enabled, settings
from ..db import get_conn
from ..razorpay_client import RazorpayError
from .bookings import release_expired_holds

router = APIRouter(prefix="/payments", tags=["payments"])


class VerifyIn(BaseModel):
    # These three names are exactly what Razorpay's checkout hands back after a payment.
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


def paise(amount: Decimal) -> int:
    return int((Decimal(amount) * 100).quantize(Decimal(1)))


def refund_payment(payment_row_id: str, provider_payment_id: str, amount: Decimal, reason: str) -> str:
    """Refund in full or part. Returns 'refunded' or 'pending' (Razorpay refused; the note says why).
    Called after the database transaction has ended, so a slow Razorpay never holds row locks."""
    try:
        r = razorpay_client.refund(provider_payment_id, paise(amount), {"reason": reason})
    except RazorpayError as e:
        with get_conn() as conn, conn.cursor() as cur:
            cur.execute("UPDATE payments SET note = %s, updated_at = now() WHERE id = %s", (f"Refund failed: {e}. Refund by hand in the Razorpay dashboard.", payment_row_id))
        return "pending"
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            """UPDATE payments SET status = 'refunded', refund_id = %s, refunded_amount = %s, note = %s, updated_at = now()
               WHERE id = %s""",
            (r.get("id"), amount, reason, payment_row_id),
        )
    return "refunded"


def settle(order_id: str, payment_id: str, user_id: str | None = None) -> dict:
    """Record a successful payment and confirm the booking. Safe to call twice (the browser and the webhook
    both report the same payment). If the guest paid after the hold ran out, the rooms are taken again when
    still free; otherwise the payment is refunded in full."""
    refund_args = None
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            """SELECT p.id, p.booking_id, p.status, p.amount, b.user_id, b.status AS booking_status,
                      b.room_type_id, b.check_in, b.check_out, b.rooms
               FROM payments p JOIN bookings b ON b.id = p.booking_id
               WHERE p.provider_order_id = %s FOR UPDATE OF p, b""",
            (order_id,),
        )
        row = cur.fetchone()
        if not row or (user_id and str(row["user_id"]) != user_id):
            raise HTTPException(404, "Payment not found")
        booking_id = str(row["booking_id"])

        if row["status"] in ("paid", "refunded"):
            return {"booking_id": booking_id, "status": "confirmed" if row["status"] == "paid" else "refunded", "already_done": True}

        cur.execute(
            "UPDATE payments SET status = 'paid', provider_payment_id = %s, updated_at = now() WHERE id = %s",
            (payment_id, row["id"]),
        )
        outcome = "confirmed"
        if row["booking_status"] == "held":
            cur.execute("UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = %s", (booking_id,))
        elif row["booking_status"] == "expired":
            # The hold ran out while the guest was paying. Take the rooms again if nobody else has.
            nights = (row["check_out"] - row["check_in"]).days
            cur.execute(
                """SELECT available FROM room_inventory
                   WHERE room_type_id = %s AND day >= %s AND day < %s ORDER BY day FOR UPDATE""",
                (row["room_type_id"], row["check_in"], row["check_out"]),
            )
            nights_rows = cur.fetchall()
            if len(nights_rows) == nights and all(n["available"] >= row["rooms"] for n in nights_rows):
                cur.execute(
                    """UPDATE room_inventory SET available = available - %s
                       WHERE room_type_id = %s AND day >= %s AND day < %s""",
                    (row["rooms"], row["room_type_id"], row["check_in"], row["check_out"]),
                )
                cur.execute("UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = %s", (booking_id,))
            else:
                outcome = "refunded"
                refund_args = (str(row["id"]), payment_id, row["amount"], "Rooms were taken before payment arrived")
        elif row["booking_status"] == "cancelled":
            outcome = "refunded"
            refund_args = (str(row["id"]), payment_id, row["amount"], "Booking was released before payment arrived")

    if refund_args:
        refund_payment(*refund_args)
    return {"booking_id": booking_id, "status": outcome}


@router.get("/config")
def config():
    on = payments_enabled()
    return {"enabled": on, "key_id": settings.razorpay_key_id if on else None}


@router.post("/bookings/{booking_id}/order")
def create_order(booking_id: str, user: dict = Depends(current_user)):
    """Start a payment for a held booking. Asking twice returns the same order, never a second one."""
    if not payments_enabled():
        raise HTTPException(503, "Online payments aren't switched on yet")
    with get_conn() as conn, conn.cursor() as cur:
        release_expired_holds(cur)
        cur.execute("SELECT id, user_id, status, total_amount FROM bookings WHERE id = %s FOR UPDATE", (booking_id,))
        b = cur.fetchone()
        if not b or str(b["user_id"]) != user["id"]:
            raise HTTPException(404, "Booking not found")
        if b["status"] != "held":
            raise HTTPException(409, "Your hold ended, so this booking can't be paid. Search again" if b["status"] == "expired" else f"This booking is already {b['status']}")

        cur.execute("SELECT provider_order_id, amount FROM payments WHERE booking_id = %s AND status = 'created'", (booking_id,))
        existing = cur.fetchone()
        if existing:
            order_id, amount = existing["provider_order_id"], existing["amount"]
        else:
            amount = b["total_amount"]
            try:
                order = razorpay_client.create_order(paise(amount), receipt=booking_id, notes={"booking_id": booking_id})
            except RazorpayError as e:
                raise HTTPException(502, f"Payment could not be started: {e}")
            order_id = order["id"]
            cur.execute(
                "INSERT INTO payments (booking_id, provider_order_id, amount) VALUES (%s, %s, %s)",
                (booking_id, order_id, amount),
            )
    return {"order_id": order_id, "amount": paise(amount), "currency": "INR", "key_id": settings.razorpay_key_id}


@router.post("/verify")
def verify(body: VerifyIn, user: dict = Depends(current_user)):
    """Called by the website or app right after Razorpay's checkout succeeds."""
    if not razorpay_client.valid_checkout_signature(body.razorpay_order_id, body.razorpay_payment_id, body.razorpay_signature):
        raise HTTPException(400, "We couldn't verify this payment. If money was taken, it will be refunded or confirmed shortly")
    return settle(body.razorpay_order_id, body.razorpay_payment_id, user_id=user["id"])


@router.post("/webhook")
async def webhook(request: Request):
    """Razorpay calls this when a payment is captured, even if the guest closed the browser first.
    Dashboard setup: Settings > Webhooks > URL https://YOUR-DOMAIN/payments/webhook, events payment.captured and order.paid,
    and the same secret as RAZORPAY_WEBHOOK_SECRET."""
    raw = await request.body()
    if not razorpay_client.valid_webhook_signature(raw, request.headers.get("X-Razorpay-Signature", "")):
        raise HTTPException(400, "Bad signature")
    try:
        event = json.loads(raw)
        if event.get("event") in ("payment.captured", "order.paid"):
            entity = event["payload"]["payment"]["entity"]
            await asyncio.to_thread(settle, entity["order_id"], entity["id"])
    except HTTPException:
        pass  # a payment we have no booking for: answer 200 so Razorpay stops retrying
    except (KeyError, ValueError, TypeError):
        pass  # an event shape we don't use
    return {"ok": True}
