"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "../../components/AuthProvider";
import Guard from "../../components/dashboard/Guard";
import { api, prettyDate } from "../../lib/api";

const STATUS = { pending: "Waiting for approval", approved: "Live", rejected: "Not approved" };

function Dashboard() {
  const { token, role, logout } = useAuth();
  const [props, setProps] = useState(null);
  const [pending, setPending] = useState([]);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    const res = await api("/owner/properties", { token });
    if (res.status === 401) return logout();
    if (!res.ok) return setError(res.error);
    setError("");
    setProps(res.data);
    if (role === "admin") {
      const p = await api("/admin/properties/pending", { token });
      if (p.ok) setPending(p.data);
    }
  }, [token, role, logout]);

  useEffect(() => {
    load();
  }, [load]);

  async function decide(id, action) {
    const res = await api(`/admin/properties/${id}/${action}`, { method: "POST", token });
    if (res.status === 401) return logout();
    if (!res.ok) setError(res.error);
    load();
  }

  return (
    <>
      <div className="dash-head">
        <h1 className="section-title">{role === "admin" ? "All properties" : "Your properties"}</h1>
        <div className="actions">
          <Link href="/dashboard/bookings" className="btn btn-small">
            Bookings
          </Link>
          <Link href="/dashboard/new" className="btn btn-small btn-primary">
            Add a property
          </Link>
        </div>
      </div>

      {error && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}

      {role === "admin" && pending.length > 0 && (
        <section className="notice">
          <h2 className="mini-title">Waiting for your approval</h2>
          <ul className="rows">
            {pending.map((p) => (
              <li key={p.id} className="plain-row">
                <div>
                  <Link href={`/dashboard/properties/${p.id}`} className="row-name">
                    {p.name}
                  </Link>
                  <p className="meta">
                    {p.city} · {p.owner} ({p.owner_email}) · added {prettyDate(String(p.created_at).slice(0, 10))}
                  </p>
                </div>
                <div className="actions">
                  <button type="button" className="btn btn-small btn-primary" onClick={() => decide(p.id, "approve")}>
                    Approve
                  </button>
                  <button type="button" className="btn btn-small btn-danger" onClick={() => decide(p.id, "reject")}>
                    Reject
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      {props === null && !error && <p className="empty">Loading…</p>}

      {props && props.length === 0 && (
        <div className="empty">
          <h2>No properties yet</h2>
          <p>
            <Link href="/dashboard/new">Add your first property</Link>, then its rooms, photos and open dates.
          </p>
        </div>
      )}

      {props && props.length > 0 && (
        <ul className="rows">
          {props.map((p) => (
            <li key={p.id} className="plain-row">
              <div>
                <Link href={`/dashboard/properties/${p.id}`} className="row-name">
                  {p.name}
                </Link>
                <p className="meta">
                  {p.type} · {p.city}
                </p>
              </div>
              <span className={`status status-${p.status === "approved" ? "confirmed" : p.status === "pending" ? "held" : "cancelled"}`}>
                {STATUS[p.status] || p.status}
              </span>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}

export default function DashboardPage() {
  return (
    <Guard>
      <Dashboard />
    </Guard>
  );
}
