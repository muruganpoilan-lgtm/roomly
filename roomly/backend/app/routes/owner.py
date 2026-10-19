from datetime import date, timedelta

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from ..auth import require_role
from ..config import settings
from ..db import get_conn
from ..schemas import InventoryIn, PropertyIn, PropertyUpdate, RoomTypeIn, RoomTypeUpdate
from ..storage import delete_image, save_image

router = APIRouter(prefix="/owner", tags=["owner and admin"])
owner_only = require_role("owner", "admin")  # admins can manage every property


def _own_property(cur, property_id: str, user: dict):
    cur.execute("SELECT owner_id FROM properties WHERE id = %s", (property_id,))
    row = cur.fetchone()
    if not row:
        raise HTTPException(404, "Property not found")
    if user["role"] != "admin" and str(row["owner_id"]) != user["id"]:
        raise HTTPException(403, "That's not your property")


def _own_room_type(cur, room_type_id: str, user: dict) -> dict:
    cur.execute("SELECT id, property_id, total_rooms FROM room_types WHERE id = %s", (room_type_id,))
    rt = cur.fetchone()
    if not rt:
        raise HTTPException(404, "Room type not found")
    _own_property(cur, str(rt["property_id"]), user)
    return rt


def _upload_photos(table: str, parent_col: str, parent_id: str, folder: str, files: list[UploadFile], user: dict, check):
    """Shared photo upload for properties and room types. Files are saved first, then recorded in one
    transaction; if the database step fails, the saved files are removed again."""
    if not files:
        raise HTTPException(400, "Choose at least one photo")
    saved: list[tuple[str, str]] = []
    try:
        with get_conn() as conn, conn.cursor() as cur:
            check(cur, parent_id, user)
            cur.execute(f"SELECT COUNT(*) AS n, COALESCE(MAX(position), -1) AS last FROM {table} WHERE {parent_col} = %s", (parent_id,))
            info = cur.fetchone()
            if info["n"] + len(files) > settings.max_photos_per_item:
                raise HTTPException(400, f"You can add up to {settings.max_photos_per_item} photos. This one has {info['n']}")
            for f in files:
                saved.append(save_image(f, folder))
            out = []
            for i, (url, key) in enumerate(saved, start=1):
                cur.execute(
                    f"INSERT INTO {table} ({parent_col}, url, storage_key, position) VALUES (%s, %s, %s, %s) RETURNING id, url, position",
                    (parent_id, url, key, info["last"] + i),
                )
                out.append(cur.fetchone())
            return out
    except Exception:
        for _, key in saved:
            delete_image(key)
        raise


def _delete_photo(table: str, parent_col: str, parent_id: str, photo_id: int, user: dict, check):
    with get_conn() as conn, conn.cursor() as cur:
        check(cur, parent_id, user)
        cur.execute(f"DELETE FROM {table} WHERE id = %s AND {parent_col} = %s RETURNING storage_key", (photo_id, parent_id))
        row = cur.fetchone()
        if not row:
            raise HTTPException(404, "Photo not found")
    delete_image(row["storage_key"])
    return {"deleted": photo_id}


# ---------- properties ----------

@router.post("/properties", status_code=201)
def create_property(body: PropertyIn, user: dict = Depends(owner_only)):
    with get_conn() as conn, conn.cursor() as cur:
        owner_id = user["id"]
        if body.owner_id:
            if user["role"] != "admin":
                raise HTTPException(403, "Only admins can create a property for another owner")
            cur.execute("SELECT id FROM users WHERE id = %s AND role = 'owner'", (body.owner_id,))
            if not cur.fetchone():
                raise HTTPException(404, "That owner account doesn't exist")
            owner_id = body.owner_id
        # Listings made by an admin are trusted and go live at once; owners' listings wait for approval.
        status = "approved" if user["role"] == "admin" else "pending"
        cur.execute(
            """INSERT INTO properties (owner_id, name, type, description, city, address, lat, lng, status)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id""",
            (owner_id, body.name, body.type, body.description, body.city, body.address, body.lat, body.lng, status),
        )
        pid = cur.fetchone()["id"]
        for amenity_id in body.amenity_ids:
            cur.execute(
                "INSERT INTO property_amenities (property_id, amenity_id) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                (pid, amenity_id),
            )
        for pos, url in enumerate(body.photo_urls):
            cur.execute("INSERT INTO property_photos (property_id, url, position) VALUES (%s, %s, %s)", (pid, url, pos))
    return {"id": pid, "status": status}


@router.get("/properties")
def my_properties(user: dict = Depends(owner_only)):
    sql = "SELECT id, name, type, city, status, rating_avg, rating_count FROM properties"
    params: tuple = ()
    if user["role"] != "admin":
        sql += " WHERE owner_id = %s"
        params = (user["id"],)
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql + " ORDER BY created_at DESC", params)
        return cur.fetchall()


@router.get("/properties/{property_id}")
def my_property_detail(property_id: str, user: dict = Depends(owner_only)):
    """Everything an owner needs to edit a listing: photos and rooms with their photos."""
    with get_conn() as conn, conn.cursor() as cur:
        _own_property(cur, property_id, user)
        cur.execute(
            "SELECT id, name, type, description, city, address, lat, lng, status FROM properties WHERE id = %s",
            (property_id,),
        )
        prop = cur.fetchone()
        cur.execute("SELECT id, url, position FROM property_photos WHERE property_id = %s ORDER BY position", (property_id,))
        prop["photos"] = cur.fetchall()
        cur.execute(
            "SELECT id, name, max_guests, base_price, total_rooms FROM room_types WHERE property_id = %s ORDER BY base_price",
            (property_id,),
        )
        rooms = cur.fetchall()
        for r in rooms:
            cur.execute("SELECT id, url, position FROM room_type_photos WHERE room_type_id = %s ORDER BY position", (r["id"],))
            r["photos"] = cur.fetchall()
        prop["room_types"] = rooms
        cur.execute("SELECT amenity_id FROM property_amenities WHERE property_id = %s", (property_id,))
        prop["amenity_ids"] = [r["amenity_id"] for r in cur.fetchall()]
        return prop


@router.patch("/properties/{property_id}")
def update_property(property_id: str, body: PropertyUpdate, user: dict = Depends(owner_only)):
    changes = body.model_dump(exclude_none=True)
    amenity_ids = changes.pop("amenity_ids", None)
    if not changes and amenity_ids is None:
        raise HTTPException(400, "Nothing to change")
    with get_conn() as conn, conn.cursor() as cur:
        _own_property(cur, property_id, user)
        if amenity_ids is not None:
            cur.execute("SELECT id FROM amenities WHERE id = ANY(%s)", (amenity_ids,))
            if len(cur.fetchall()) != len(set(amenity_ids)):
                raise HTTPException(400, "Unknown amenity")
            cur.execute("DELETE FROM property_amenities WHERE property_id = %s", (property_id,))
            for aid in set(amenity_ids):
                cur.execute("INSERT INTO property_amenities (property_id, amenity_id) VALUES (%s, %s)", (property_id, aid))
        if changes:
            sets = ", ".join(f"{col} = %s" for col in changes)  # column names come from the schema model
            cur.execute(f"UPDATE properties SET {sets} WHERE id = %s", (*changes.values(), property_id))
        # An owner who edits a rejected listing sends it back for review.
        if user["role"] != "admin":
            cur.execute("UPDATE properties SET status = 'pending' WHERE id = %s AND status = 'rejected'", (property_id,))
        cur.execute("SELECT status FROM properties WHERE id = %s", (property_id,))
        return {"id": property_id, "status": cur.fetchone()["status"]}


@router.post("/properties/{property_id}/photos", status_code=201)
def upload_property_photos(property_id: str, files: list[UploadFile] = File(...), user: dict = Depends(owner_only)):
    return _upload_photos("property_photos", "property_id", property_id, f"properties/{property_id}", files, user, _own_property)


@router.delete("/properties/{property_id}/photos/{photo_id}")
def delete_property_photo(property_id: str, photo_id: int, user: dict = Depends(owner_only)):
    return _delete_photo("property_photos", "property_id", property_id, photo_id, user, _own_property)


# ---------- rooms ----------

@router.post("/properties/{property_id}/room-types", status_code=201)
def add_room_type(property_id: str, body: RoomTypeIn, user: dict = Depends(owner_only)):
    with get_conn() as conn, conn.cursor() as cur:
        _own_property(cur, property_id, user)
        cur.execute(
            """INSERT INTO room_types (property_id, name, max_guests, base_price, total_rooms)
               VALUES (%s, %s, %s, %s, %s) RETURNING id""",
            (property_id, body.name, body.max_guests, body.base_price, body.total_rooms),
        )
        return {"id": cur.fetchone()["id"]}


@router.patch("/room-types/{room_type_id}")
def update_room_type(room_type_id: str, body: RoomTypeUpdate, user: dict = Depends(owner_only)):
    changes = body.model_dump(exclude_none=True)
    if not changes:
        raise HTTPException(400, "Nothing to change")
    with get_conn() as conn, conn.cursor() as cur:
        rt = _own_room_type(cur, room_type_id, user)
        new_total = changes.get("total_rooms")
        if new_total is not None and new_total < rt["total_rooms"]:
            cur.execute(
                "SELECT COALESCE(MAX(available), 0) AS most FROM room_inventory WHERE room_type_id = %s AND day >= %s",
                (room_type_id, date.today()),
            )
            if cur.fetchone()["most"] > new_total:
                raise HTTPException(409, "Some upcoming nights have more rooms open than that. Lower the open rooms for those dates first")
        sets = ", ".join(f"{col} = %s" for col in changes)  # column names come from the schema model, never from the request
        cur.execute(f"UPDATE room_types SET {sets} WHERE id = %s", (*changes.values(), room_type_id))
        return {"id": room_type_id, "updated": list(changes)}


@router.delete("/room-types/{room_type_id}")
def delete_room_type(room_type_id: str, user: dict = Depends(owner_only)):
    with get_conn() as conn, conn.cursor() as cur:
        _own_room_type(cur, room_type_id, user)
        cur.execute("SELECT 1 FROM bookings WHERE room_type_id = %s LIMIT 1", (room_type_id,))
        if cur.fetchone():
            raise HTTPException(409, "This room has bookings, so it can't be deleted. Close its dates instead")
        cur.execute("SELECT storage_key FROM room_type_photos WHERE room_type_id = %s", (room_type_id,))
        keys = [r["storage_key"] for r in cur.fetchall()]
        cur.execute("DELETE FROM room_types WHERE id = %s", (room_type_id,))
    for key in keys:
        delete_image(key)
    return {"deleted": room_type_id}


@router.post("/room-types/{room_type_id}/photos", status_code=201)
def upload_room_photos(room_type_id: str, files: list[UploadFile] = File(...), user: dict = Depends(owner_only)):
    return _upload_photos("room_type_photos", "room_type_id", room_type_id, f"rooms/{room_type_id}", files, user, _own_room_type)


@router.delete("/room-types/{room_type_id}/photos/{photo_id}")
def delete_room_photo(room_type_id: str, photo_id: int, user: dict = Depends(owner_only)):
    return _delete_photo("room_type_photos", "room_type_id", room_type_id, photo_id, user, _own_room_type)


@router.put("/room-types/{room_type_id}/inventory")
def set_inventory(room_type_id: str, body: InventoryIn, user: dict = Depends(owner_only)):
    """Open rooms for sale for a date range. Rooms already booked are subtracted automatically."""
    with get_conn() as conn, conn.cursor() as cur:
        rt = _own_room_type(cur, room_type_id, user)
        if body.rooms_open > rt["total_rooms"]:
            raise HTTPException(400, f"This room type only has {rt['total_rooms']} rooms")
        cur.execute(
            """INSERT INTO room_inventory (room_type_id, day, available, price)
               SELECT %(rt)s, d::date, GREATEST(%(open)s - COALESCE(b.booked, 0), 0), %(price)s
               FROM generate_series(%(start)s::date, %(end)s::date, interval '1 day') AS d
               LEFT JOIN LATERAL (
                 SELECT SUM(rooms) AS booked FROM bookings
                 WHERE room_type_id = %(rt)s AND status IN ('held', 'confirmed')
                   AND check_in <= d::date AND check_out > d::date
               ) b ON true
               ON CONFLICT (room_type_id, day)
               DO UPDATE SET available = EXCLUDED.available, price = EXCLUDED.price""",
            {"rt": room_type_id, "open": body.rooms_open, "price": body.price, "start": body.start, "end": body.end},
        )
        return {"nights_updated": (body.end - body.start).days + 1}


@router.get("/room-types/{room_type_id}/inventory")
def get_inventory(room_type_id: str, start: date | None = None, days: int = 60, user: dict = Depends(owner_only)):
    """Open rooms and price for each night, so owners can see what guests will see."""
    days = max(1, min(days, 366))
    start = start or date.today()
    with get_conn() as conn, conn.cursor() as cur:
        _own_room_type(cur, room_type_id, user)
        cur.execute(
            """SELECT day, available, price FROM room_inventory
               WHERE room_type_id = %s AND day >= %s AND day < %s ORDER BY day""",
            (room_type_id, start, start + timedelta(days=days)),
        )
        return cur.fetchall()


@router.get("/bookings")
def owner_bookings(user: dict = Depends(owner_only)):
    sql = """SELECT b.id, p.name AS property, rt.name AS room_type, u.name AS guest,
                    b.check_in, b.check_out, b.rooms, b.guests, b.total_amount, b.status
             FROM bookings b
             JOIN properties p ON p.id = b.property_id
             JOIN room_types rt ON rt.id = b.room_type_id
             JOIN users u ON u.id = b.user_id
             WHERE b.status IN ('confirmed', 'cancelled')"""
    params: tuple = ()
    if user["role"] != "admin":
        sql += " AND p.owner_id = %s"
        params = (user["id"],)
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql + " ORDER BY b.check_in DESC", params)
        return cur.fetchall()
