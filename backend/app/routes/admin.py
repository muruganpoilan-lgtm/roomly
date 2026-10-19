from fastapi import APIRouter, Depends, HTTPException

from ..auth import require_role
from ..db import get_conn

router = APIRouter(prefix="/admin", tags=["admin"])
admin_only = require_role("admin")


@router.get("/properties/pending")
def pending_properties(user: dict = Depends(admin_only)):
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            """SELECT p.id, p.name, p.type, p.city, p.created_at, u.name AS owner, u.email AS owner_email
               FROM properties p JOIN users u ON u.id = p.owner_id
               WHERE p.status = 'pending' ORDER BY p.created_at""",
        )
        return cur.fetchall()


def _set_status(property_id: str, status: str):
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("UPDATE properties SET status = %s WHERE id = %s RETURNING id", (status, property_id))
        if not cur.fetchone():
            raise HTTPException(404, "Property not found")
    return {"id": property_id, "status": status}


@router.post("/properties/{property_id}/approve")
def approve(property_id: str, user: dict = Depends(admin_only)):
    return _set_status(property_id, "approved")


@router.post("/properties/{property_id}/reject")
def reject(property_id: str, user: dict = Depends(admin_only)):
    return _set_status(property_id, "rejected")
