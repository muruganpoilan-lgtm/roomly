"""Small Razorpay client using only the standard library: create an order, refund a payment,
and check the signatures Razorpay sends. Docs: https://razorpay.com/docs/api/"""
import base64
import hashlib
import hmac
import json
import urllib.error
import urllib.request

from .config import settings


class RazorpayError(Exception):
    pass


def _call(method: str, path: str, payload: dict | None = None) -> dict:
    token = base64.b64encode(f"{settings.razorpay_key_id}:{settings.razorpay_key_secret}".encode()).decode()
    req = urllib.request.Request(
        f"{settings.razorpay_api_base}{path}",
        method=method,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={"Authorization": f"Basic {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        detail = ""
        try:
            detail = json.loads(e.read()).get("error", {}).get("description", "")
        except Exception:
            pass
        raise RazorpayError(detail or f"Razorpay answered with HTTP {e.code}") from e
    except Exception as e:
        raise RazorpayError("Could not reach Razorpay") from e


def create_order(amount_paise: int, receipt: str, notes: dict) -> dict:
    return _call("POST", "/orders", {"amount": amount_paise, "currency": "INR", "receipt": receipt, "notes": notes})


def refund(payment_id: str, amount_paise: int, notes: dict) -> dict:
    return _call("POST", f"/payments/{payment_id}/refund", {"amount": amount_paise, "speed": "normal", "notes": notes})


def _same(expected: str, given: str) -> bool:
    return bool(given) and hmac.compare_digest(expected, given)


def valid_checkout_signature(order_id: str, payment_id: str, signature: str) -> bool:
    """The signature the Razorpay checkout hands the browser or app after a successful payment."""
    msg = f"{order_id}|{payment_id}".encode()
    expected = hmac.new(settings.razorpay_key_secret.encode(), msg, hashlib.sha256).hexdigest()
    return _same(expected, signature)


def valid_webhook_signature(raw_body: bytes, signature: str) -> bool:
    if not settings.razorpay_webhook_secret:
        return False
    expected = hmac.new(settings.razorpay_webhook_secret.encode(), raw_body, hashlib.sha256).hexdigest()
    return _same(expected, signature)
