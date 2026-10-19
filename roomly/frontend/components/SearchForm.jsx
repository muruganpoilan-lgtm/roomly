"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { addDays, nightsBetween, plural, todayISO } from "../lib/api";

// The booking slip: city, two dates, guests. Used big on the home page and compact above search results.
export default function SearchForm({ initial = {}, compact = false }) {
  const router = useRouter();
  const [city, setCity] = useState(initial.city || "");
  const [checkIn, setCheckIn] = useState(initial.check_in || "");
  const [checkOut, setCheckOut] = useState(initial.check_out || "");
  const [guests, setGuests] = useState(String(initial.guests || 2));
  const [error, setError] = useState("");
  const [today, setToday] = useState("");

  // Default to tomorrow for one night. Done after load so the server and browser always agree on first paint.
  useEffect(() => {
    const t = todayISO();
    setToday(t);
    setCheckIn((v) => v || addDays(t, 1));
    setCheckOut((v) => v || addDays(t, 2));
  }, []);

  function onCheckIn(value) {
    setCheckIn(value);
    if (value && (!checkOut || checkOut <= value)) setCheckOut(addDays(value, 1));
  }

  function onSubmit(e) {
    e.preventDefault();
    if (!checkIn || !checkOut) {
      setError("Choose your check-in and check-out dates.");
      return;
    }
    if (checkOut <= checkIn) {
      setError("Check-out must be after check-in.");
      return;
    }
    setError("");
    const params = new URLSearchParams({ check_in: checkIn, check_out: checkOut, guests });
    if (city.trim()) params.set("city", city.trim());
    router.push(`/search?${params.toString()}`);
  }

  const nights = checkIn && checkOut && checkOut > checkIn ? nightsBetween(checkIn, checkOut) : 0;

  return (
    <form className={`slip${compact ? " compact" : ""}`} onSubmit={onSubmit} noValidate>
      <div className="slip-grid">
        <label className="field">
          <span>City</span>
          <input
            type="text"
            value={city}
            onChange={(e) => setCity(e.target.value)}
            placeholder="Goa, Ooty, Jaipur"
            autoComplete="off"
          />
        </label>
        <label className="field">
          <span>Check-in</span>
          <input type="date" value={checkIn} min={today || undefined} onChange={(e) => onCheckIn(e.target.value)} />
        </label>
        <label className="field">
          <span>Check-out</span>
          <input
            type="date"
            value={checkOut}
            min={checkIn || today || undefined}
            onChange={(e) => setCheckOut(e.target.value)}
          />
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
        <button type="submit" className="btn btn-primary">
          Search rooms
        </button>
      </div>
      {error ? (
        <p className="form-error" role="alert">
          {error}
        </p>
      ) : (
        <p className="slip-note">{nights ? `${plural(nights, "night")}. We only show rooms that are free on every night.` : "Pick your dates to see free rooms."}</p>
      )}
    </form>
  );
}
