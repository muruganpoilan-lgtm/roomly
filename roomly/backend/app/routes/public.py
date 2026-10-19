from datetime import date

from fastapi import APIRouter, HTTPException, Query

from ..db import get_conn

router = APIRouter(tags=["public"])


@router.get("/amenities")
def amenities():
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, name FROM amenities ORDER BY name")
        return cur.fetchall()


@router.get("/search")
def search(
    city: str | None = None,
    check_in: date = Query(...),
    check_out: date = Query(...),
    guests: int = Query(1, ge=1),
    min_price: float | None = None,
    max_price: float | None = None,
    property_type: str | None = Query(None, pattern="^(hotel|homestay|apartment|resort)$"),
    min_rating: float | None = None,
    sort: str = Query("price", pattern="^(price|rating)$"),
):
    if check_out <= check_in:
        raise HTTPException(400, "check_out must be after check_in")
    nights = (check_out - check_in).days

    # A room type counts only if EVERY night in the range is open with at least one room.
    sql = """
        SELECT p.id, p.name, p.type, p.city, p.rating_avg, p.rating_count,
               MIN(x.nightly) AS price_per_night,
               (SELECT url FROM property_photos ph WHERE ph.property_id = p.id ORDER BY position LIMIT 1) AS photo
        FROM properties p
        JOIN (
            SELECT rt.property_id, AVG(COALESCE(ri.price, rt.base_price)) AS nightly
            FROM room_types rt
            JOIN room_inventory ri ON ri.room_type_id = rt.id
            WHERE ri.day >= %(ci)s AND ri.day < %(co)s AND rt.max_guests >= %(guests)s
            GROUP BY rt.property_id, rt.id
            HAVING COUNT(*) = %(nights)s AND MIN(ri.available) >= 1
        ) x ON x.property_id = p.id
        WHERE p.status = 'approved'
    """
    params = {"ci": check_in, "co": check_out, "guests": guests, "nights": nights}
    if city:
        sql += " AND p.city ILIKE %(city)s"
        params["city"] = f"%{city}%"
    if property_type:
        sql += " AND p.type = %(ptype)s"
        params["ptype"] = property_type
    if min_rating is not None:
        sql += " AND p.rating_avg >= %(min_rating)s"
        params["min_rating"] = min_rating
    sql += " GROUP BY p.id HAVING TRUE"
    if min_price is not None:
        sql += " AND MIN(x.nightly) >= %(min_price)s"
        params["min_price"] = min_price
    if max_price is not None:
        sql += " AND MIN(x.nightly) <= %(max_price)s"
        params["max_price"] = max_price
    sql += " ORDER BY p.rating_avg DESC, 7 ASC" if sort == "rating" else " ORDER BY 7 ASC, p.rating_avg DESC"
    sql += " LIMIT 50"

    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return {"nights": nights, "results": cur.fetchall()}


@router.get("/properties/{property_id}")
def property_detail(property_id: str, check_in: date | None = None, check_out: date | None = None):
    if (check_in is None) != (check_out is None):
        raise HTTPException(400, "Send both check_in and check_out, or neither")
    if check_in and check_out <= check_in:
        raise HTTPException(400, "check_out must be after check_in")
    nights = (check_out - check_in).days if check_in else None

    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            """SELECT id, name, type, description, city, address, lat, lng, rating_avg, rating_count
               FROM properties WHERE id = %s AND status = 'approved'""",
            (property_id,),
        )
        prop = cur.fetchone()
        if not prop:
            raise HTTPException(404, "Property not found")
        cur.execute("SELECT url FROM property_photos WHERE property_id = %s ORDER BY position", (property_id,))
        prop["photos"] = [r["url"] for r in cur.fetchall()]
        cur.execute(
            """SELECT a.name FROM property_amenities pa JOIN amenities a ON a.id = pa.amenity_id
               WHERE pa.property_id = %s ORDER BY a.name""",
            (property_id,),
        )
        prop["amenities"] = [r["name"] for r in cur.fetchall()]
        cur.execute(
            """SELECT rt.id, rt.name, rt.max_guests, rt.base_price,
                      x.nights_open, x.min_available, x.stay_total
               FROM room_types rt
               LEFT JOIN LATERAL (
                 SELECT COUNT(*) AS nights_open, MIN(ri.available) AS min_available,
                        SUM(COALESCE(ri.price, rt.base_price)) AS stay_total
                 FROM room_inventory ri
                 WHERE ri.room_type_id = rt.id AND ri.day >= %(ci)s::date AND ri.day < %(co)s::date
               ) x ON true
               WHERE rt.property_id = %(pid)s
               ORDER BY rt.base_price""",
            {"ci": check_in, "co": check_out, "pid": property_id},
        )
        rooms = cur.fetchall()
        photos_by_room: dict = {r["id"]: [] for r in rooms}
        if rooms:
            cur.execute(
                "SELECT room_type_id, url FROM room_type_photos WHERE room_type_id = ANY(%s) ORDER BY position",
                ([r["id"] for r in rooms],),
            )
            for p in cur.fetchall():
                photos_by_room[p["room_type_id"]].append(p["url"])
    for r in rooms:
        r["photos"] = photos_by_room[r["id"]]
        if nights is not None:
            r["rooms_left"] = int(r["min_available"] or 0) if r["nights_open"] == nights else 0
            r["bookable"] = r["rooms_left"] > 0
            if not r["bookable"]:
                r["stay_total"] = None
        for key in ("nights_open", "min_available"):
            r.pop(key, None)
        if nights is None:
            r.pop("stay_total", None)
    prop["room_types"] = rooms
    return prop
