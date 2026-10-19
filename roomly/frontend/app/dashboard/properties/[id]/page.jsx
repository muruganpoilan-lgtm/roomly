"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useAuth } from "../../../../components/AuthProvider";
import Guard from "../../../../components/dashboard/Guard";
import PropertyForm from "../../../../components/dashboard/PropertyForm";
import PhotoManager from "../../../../components/dashboard/PhotoManager";
import RoomCard from "../../../../components/dashboard/RoomCard";
import { api } from "../../../../lib/api";

const STATUS_NOTE = {
  pending: "Waiting for approval. Guests can't see this property until an admin approves it.",
  approved: "Live. Guests can find it once a room has open dates.",
  rejected: "Not approved. Update the details and save to send it for review again.",
};

function Editor({ id }) {
  const { token, logout } = useAuth();
  const [prop, setProp] = useState(null);
  const [error, setError] = useState("");
  const [saved, setSaved] = useState("");
  const [room, setRoom] = useState({ name: "", max_guests: "2", base_price: "", total_rooms: "1" });
  const [roomError, setRoomError] = useState("");
  const [roomBusy, setRoomBusy] = useState(false);

  const onAuthError = useCallback(() => logout(), [logout]);

  const load = useCallback(async () => {
    const res = await api(`/owner/properties/${id}`, { token });
    if (res.status === 401) return logout();
    if (!res.ok) return setError(res.error);
    setError("");
    setProp(res.data);
  }, [id, token, logout]);

  useEffect(() => {
    load();
  }, [load]);

  async function saveDetails(body) {
    setSaved("");
    const res = await api(`/owner/properties/${id}`, { method: "PATCH", token, body });
    if (res.status === 401) {
      logout();
      return "Your session ended. Log in again.";
    }
    if (!res.ok) return res.error;
    setSaved("Saved.");
    load();
    return null;
  }

  async function addRoom(e) {
    e.preventDefault();
    setRoomError("");
    const body = {
      name: room.name.trim(),
      max_guests: Number(room.max_guests),
      base_price: Number(room.base_price),
      total_rooms: Number(room.total_rooms),
    };
    if (!body.name || room.base_price === "" || !(body.base_price >= 0)) {
      return setRoomError("Enter a room name and the usual price for a night.");
    }
    setRoomBusy(true);
    const res = await api(`/owner/properties/${id}/room-types`, { method: "POST", token, body });
    setRoomBusy(false);
    if (res.status === 401) return logout();
    if (!res.ok) return setRoomError(res.error);
    setRoom({ name: "", max_guests: "2", base_price: "", total_rooms: "1" });
    load();
  }

  const setR = (k) => (e) => setRoom({ ...room, [k]: e.target.value });

  if (error) {
    return (
      <>
        <p className="form-error" role="alert">
          {error}
        </p>
        <p className="meta">
          <Link href="/dashboard">← Your properties</Link>
        </p>
      </>
    );
  }
  if (!prop) return <p className="empty">Loading…</p>;

  return (
    <>
      <p className="meta">
        <Link href="/dashboard">← Your properties</Link>
      </p>
      <h1 className="section-title">{prop.name}</h1>
      <p className="notice">{STATUS_NOTE[prop.status]}</p>

      <section className="prop-section">
        <h2>Details</h2>
        <div className="narrow">
          <PropertyForm key={prop.id} initial={prop} submitLabel="Save details" onSubmit={saveDetails} />
          {saved && (
            <p className="ok" role="status">
              {saved}
            </p>
          )}
        </div>
      </section>

      <section className="prop-section">
        <h2>Property photos</h2>
        <PhotoManager base={`/owner/properties/${id}`} photos={prop.photos} token={token} onChange={load} onAuthError={onAuthError} />
      </section>

      <section className="prop-section">
        <h2>Rooms</h2>
        {prop.room_types.length === 0 && <p className="meta">No rooms yet. Add the first one below.</p>}
        {prop.room_types.map((r) => (
          <RoomCard key={r.id} room={r} token={token} reload={load} onAuthError={onAuthError} />
        ))}

        <form className="room-card stack" onSubmit={addRoom} noValidate>
          <h3>Add a room type</h3>
          <div className="four">
            <label className="field">
              <span>Room name</span>
              <input type="text" value={room.name} onChange={setR("name")} placeholder="Deluxe double" />
            </label>
            <label className="field">
              <span>Sleeps</span>
              <input type="number" min="1" max="20" value={room.max_guests} onChange={setR("max_guests")} />
            </label>
            <label className="field">
              <span>Usual price a night (₹)</span>
              <input type="number" min="0" value={room.base_price} onChange={setR("base_price")} />
            </label>
            <label className="field">
              <span>Rooms of this type</span>
              <input type="number" min="1" max="500" value={room.total_rooms} onChange={setR("total_rooms")} />
            </label>
          </div>
          {roomError && (
            <p className="form-error" role="alert">
              {roomError}
            </p>
          )}
          <div className="actions">
            <button type="submit" className="btn btn-primary btn-small" aria-busy={roomBusy}>
              {roomBusy ? "Adding…" : "Add room"}
            </button>
          </div>
        </form>
      </section>
    </>
  );
}

export default function PropertyEditorPage() {
  const { id } = useParams();
  return (
    <Guard>
      <Editor id={id} />
    </Guard>
  );
}
