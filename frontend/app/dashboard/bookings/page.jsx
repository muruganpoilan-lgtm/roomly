"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "../../../components/AuthProvider";
import Guard from "../../../components/dashboard/Guard";
import { api, money, plural, prettyDate } from "../../../lib/api";

function Bookings() {
  const { token, logout } = useAuth();
  const [rows, setRows] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api("/owner/bookings", { token }).then((res) => {
      if (res.status === 401) return logout();
      if (!res.ok) return setError(res.error);
      setRows(res.data);
    });
  }, [token, logout]);

  return (
    <>
      <p className="meta">
        <Link href="/dashboard">← Your properties</Link>
      </p>
      <h1 className="section-title">Bookings</h1>
      {error && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}
      {rows === null && !error && <p className="empty">Loading…</p>}
      {rows && rows.length === 0 && <p className="empty">No confirmed bookings yet.</p>}
      {rows && rows.length > 0 && (
        <ul className="rows">
          {rows.map((b) => (
            <li key={b.id} className="plain-row">
              <div>
                <p className="row-name">{b.guest}</p>
                <p className="meta">
                  {b.property} · {b.room_type} · {plural(b.rooms, "room")}, {plural(b.guests, "guest")}
                </p>
                <p className="meta">
                  {prettyDate(b.check_in)} to {prettyDate(b.check_out)}
                </p>
              </div>
              <div className="right">
                <span className="price">{money(b.total_amount)}</span>
                <p>
                  <span className={`status status-${b.status}`}>{b.status === "confirmed" ? "Confirmed" : "Cancelled"}</span>
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}

export default function BookingsDashboardPage() {
  return (
    <Guard>
      <Bookings />
    </Guard>
  );
}
