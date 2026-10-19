"use client";

import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "./AuthProvider";
import Ridge from "./Ridge";
import { api, money, plural, todayISO } from "../lib/api";

export default function RoomList({ rooms, checkIn: ci, checkOut: co, guests: g, nights }) {
  const router = useRouter();
  const pathname = usePathname();
  const { token, logout } = useAuth();

  const [checkIn, setCheckIn] = useState(ci);
  const [checkOut, setCheckOut] = useState(co);
  const [guests, setGuests] = useState(String(g));
  const [qty, setQty] = useState({});
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [today, setToday] = useState("");

  // Set after load so the server and the browser agree on first paint, whatever their time zones.
  useEffect(() => setToday(todayISO()), []);

  const hasDates = Boolean(ci && co);
  const here = `${pathname}?${new URLSearchParams({ check_in: ci, check_out: co, guests: String(g) }).toString()}`;

  function updateDates(e) {
    e.preventDefault();
    if (!checkIn || !checkOut || checkOut <= checkIn) {
      setError("Choose a check-out date after check-in.");
      return;
    }
    setError("");
    router.replace(`${pathname}?${new URLSearchParams({ check_in: checkIn, check_out: checkOut, guests }).toString()}`);
  }

  function goToLogin() {
    router.push(`/login?next=${encodeURIComponent(here)}`);
  }

  async function book(room) {
    setError("");
    if (!token) {
      goToLogin();
      return;
    }
    setBusy(room.id);
    const res = await api("/bookings", {
      method: "POST",
      token,
      body: { room_type_id: room.id, check_in: ci, check_out: co, rooms: Number(qty[room.id] || 1), guests: Number(g) },
    });
    setBusy("");
    if (res.status === 401) {
      logout();
      goToLogin();
      return;
    }
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.push(`/bookings?new=${res.data.booking_id}`);
  }

  return (
    <div>
      <form className="dates-bar" onSubmit={updateDates} noValidate>
        <label className="field">
          <span>Check-in</span>
          <input type="date" value={checkIn} min={today || undefined} onChange={(e) => setCheckIn(e.target.value)} />
        </label>
        <label className="field">
          <span>Check-out</span>
          <input type="date" value={checkOut} min={checkIn || today || undefined} onChange={(e) => setCheckOut(e.target.value)} />
        </label>
        <label className="field">
          <span>Guests</span>
          <select value={guests} onChange={(e) => setGuests(e.target.value)}>
            {[1, 2, 3, 4, 5, 6, 7, 8].map((n) => (
              <option key={n} value={n}>
                {n}
              </option>
            ))}
          </select>
        </label>
        <button type="submit" className="btn btn-small">
          {hasDates ? "Update dates" : "Check availability"}
        </button>
      </form>

      {error && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}

      {rooms.length === 0 && <p className="empty">The owner hasn't added rooms yet.</p>}

      {rooms.map((room) => {
        const bookable = hasDates && room.bookable;
        const left = room.rooms_left || 0;
        return (
          <article className="room" key={room.id}>
            {room.photos && room.photos[0] ? (
              <img className="thumb" src={room.photos[0]} alt="" loading="lazy" />
            ) : (
              <div className="thumb"><Ridge seed={room.id} /></div>
            )}
            <div>
              <h3 className="room-name">{room.name}</h3>
              <p className="meta">Sleeps {room.max_guests}</p>
              <p>
                <span className="price">{money(room.base_price)}</span> <span className="meta">a night</span>
              </p>
              {bookable && (
                <p className="meta">
                  {money(room.stay_total)} for {plural(nights, "night")}
                  {Number(qty[room.id] || 1) > 1 ? ` per room` : ""}
                </p>
              )}
              {bookable && left <= 2 && <p className="scarce">Only {left} left for these dates</p>}
              {hasDates && !bookable && <p className="unavailable">Not free on all of these dates</p>}
              {!hasDates && <p className="unavailable">Choose dates to see if it's free</p>}
            </div>
            {bookable && (
              <div className="room-actions">
                {left > 1 && (
                  <label className="field">
                    <span>Rooms</span>
                    <select value={qty[room.id] || "1"} onChange={(e) => setQty({ ...qty, [room.id]: e.target.value })}>
                      {Array.from({ length: Math.min(left, 5) }, (_, i) => i + 1).map((n) => (
                        <option key={n} value={n}>
                          {n}
                        </option>
                      ))}
                    </select>
                  </label>
                )}
                <button type="button" className="btn btn-primary" onClick={() => book(room)} aria-busy={busy === room.id}>
                  {busy === room.id ? "Holding your room…" : token ? "Reserve" : "Log in to reserve"}
                </button>
              </div>
            )}
          </article>
        );
      })}
    </div>
  );
}
