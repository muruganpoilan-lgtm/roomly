from datetime import date
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException

from ..auth import current_user
from ..config import settings
from ..db import get_conn
from ..schemas import BookingIn

router = APIRouter(prefix="/bookings", tags=["bookings"])


def _give_rooms_back(cur, b: dict) -> None:
    """Return a booking's rooms to the nightly inventory. Locks rows in date order to avoid deadlocks."""
    cur.execute(
        """SELECT day FROM room_inventory
           WHERE room_type_id = %s AND day >= %s AND day < %s ORDER BY day FOR UPDATE""",
        (b["room_type_id"], b["check_in"], b["check_out"]),
    )
    cur.execute(
        """UPDATE room_inventory SET available = available + %s
           WHERE room_type_id = %s AND day >= %s AND day < %s""",
        (b["rooms"], b["room_type_id"], b["check_in"], b["check_out"]),
    )


def release_expired_holds(cur) -> int:
    """Expire unpaid holds past their deadline and give the rooms back."""
    cur.execute(
        """SELECT id, room_type_id, check_in, check_out, rooms FROM bookings
           WHERE status = 'held' AND hold_expires_at < now() FOR UPDATE SKIP LOCKED"""
    )
    expired = cur.fetchall()
    for b in expired:
        _give_rooms_back(cur, b)
        cur.execute("UPDATE bookings SET status = 'expired' WHERE id = %s", (b["id"],))
    return len(expired)


def expire_holds() -> int:
    """Run on a timer from main.py, so unpaid rooms go back on sale even when nobody is booking."""
    with get_conn() as conn, conn.cursor() as cur:
        return release_expired_holds(cur)


@router.post("", status_code=201)
def create_booking(body: BookingIn, user: dict = Depends(current_user)):
    nights = (body.check_out - body.check_in).days
    with get_conn() as conn, conn.cursor() as cur:
        release_expired_holds(cur)

        cur.execute(
            """SELECT rt.id, rt.property_id, rt.max_guests, rt.base_price, p.status
               FROM room_types rt JOIN properties p ON p.id = rt.property_id WHERE rt.id = %s""",
            (body.room_type_id,),
        )
        rt = cur.fetchone()
        if not rt or rt["status"] != "approved":
            raise HTTPException(404, "Room type not found")
        if body.guests > rt["max_guests"] * body.rooms:
            raise HTTPException(400, f"This room sleeps {rt['max_guests']} guests. Add more rooms or choose a bigger one")

        # Lock every night of the stay, in date order. A second guest booking the same
        # rooms waits here until this transaction finishes, then sees the updated count.
        cur.execute(
            """SELECT day, available, price FROM room_inventory
               WHERE room_type_id = %s AND day >= %s AND day < %s ORDER BY day FOR UPDATE""",
            (body.room_type_id, body.check_in, body.check_out),
        )
        nights_rows = cur.fetchall()
        if len(nights_rows) != nights or any(r["available"] < body.rooms for r in nights_rows):
            raise HTTPException(409, "Those rooms were just taken for your dates. Try other dates")

        total = sum((r["price"] if r["price"] is not None else rt["base_price"]) for r in nights_rows) * Decimal(body.rooms)

        cur.execute(
            """UPDATE room_inventory SET available = available - %s
               WHERE room_type_id = %s AND day >= %s AND day < %s""",
            (body.rooms, body.room_type_id, body.check_in, body.check_out),
        )
        cur.execute(
            """INSERT INTO bookings (user_id, property_id, room_type_id, check_in, check_out, rooms, guests,
                                     total_amount, status, hold_expires_at)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'held', now() + make_interval(mins => %s))
               RETURNING id, total_amount, hold_expires_at""",
            (user["id"], rt["property_id"], body.room_type_id, body.check_in, body.check_out,
             body.rooms, body.guests, total, settings.hold_minutes),
        )
        booking = cur.fetchone()
    return {"booking_id": booking["id"], "status": "held", "total_amount": booking["total_amount"],
            "pay_before": booking["hold_expires_at"], "nights": nights}


@router.get("/mine")
def my_bookings(user: dict = Depends(current_user)):
    with get_conn() as conn, conn.cursor() as cur:
        release_expired_holds(cur)  # so a guest never sees a hold that has already run out
        cur.execute(
            """SELECT b.id, p.name AS property, p.city, rt.name AS room_type, b.check_in, b.check_out,
                      b.rooms, b.guests, b.total_amount, b.status, b.hold_expires_at
               FROM bookings b
               JOIN properties p ON p.id = b.property_id
               JOIN room_types rt ON rt.id = b.room_type_id
               WHERE b.user_id = %s ORDER BY b.created_at DESC""",
            (user["id"],),
        )
        return cur.fetchall()


@router.post("/{booking_id}/confirm")
def confirm_booking(booking_id: str, user: dict = Depends(current_user)):
    """Dev-only shortcut. Real confirmation will happen from the Razorpay payment webhook."""
    if not settings.allow_fake_confirm:
        raise HTTPException(403, "Payment is required to confirm a booking")
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, user_id, status, hold_expires_at FROM bookings WHERE id = %s FOR UPDATE", (booking_id,))
        b = cur.fetchone()
        if not b or str(b["user_id"]) != user["id"]:
            raise HTTPException(404, "Booking not found")
        if b["status"] != "held":
            raise HTTPException(409, f"This booking is already {b['status']}")
        cur.execute("SELECT now() > %s AS late", (b["hold_expires_at"],))
        if cur.fetchone()["late"]:
            raise HTTPException(409, "Your hold expired. Search again")
        cur.execute("UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = %s", (booking_id,))
    return {"booking_id": booking_id, "status": "confirmed"}


@router.post("/{booking_id}/cancel")
def cancel_booking(booking_id: str, user: dict = Depends(current_user)):
    refund_args = None
    refund = {"status": "none", "amount": 0, "reason": "no_payment"}
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            """SELECT id, user_id, status, room_type_id, check_in, check_out, rooms
               FROM bookings WHERE id = %s FOR UPDATE""",
            (booking_id,),
        )
        b = cur.fetchone()
        if not b or str(b["user_id"]) != user["id"]:
            raise HTTPException(404, "Booking not found")
        if b["status"] not in ("held", "confirmed"):
            raise HTTPException(409, f"This booking is already {b['status']}")
        if b["check_in"] < date.today():
            raise HTTPException(409, "You can't cancel a stay that has already started")
        _give_rooms_back(cur, b)
        cur.execute("UPDATE bookings SET status = 'cancelled', hold_expires_at = NULL WHERE id = %s", (booking_id,))

        if b["status"] == "confirmed":
            cur.execute("SELECT id, provider_payment_id, amount FROM payments WHERE booking_id = %s AND status = 'paid' FOR UPDATE", (booking_id,))
            pay = cur.fetchone()
            if pay:
                refund["reason"] = "too_late"
                # Full refund if there are at least REFUND_FULL_HOURS left before check-in (midnight, India time); none after.
                cur.execute(
                    "SELECT (%s::date::timestamp AT TIME ZONE 'Asia/Kolkata') - now() >= make_interval(hours => %s) AS full",
                    (b["check_in"], settings.refund_full_hours),
                )
                if cur.fetchone()["full"]:
                    refund_args = (str(pay["id"]), pay["provider_payment_id"], pay["amount"], "Cancelled by guest")
                    refund = {"status": "refunded", "amount": pay["amount"], "reason": "full"}
    if refund_args:
        from .payments import refund_payment  # imported here because payments.py imports this module

        refund["status"] = refund_payment(*refund_args)
    return {"booking_id": booking_id, "status": "cancelled", "refund": refund}
