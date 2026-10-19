"use client";

import { useEffect, useState } from "react";
import { api } from "../../lib/api";

export const TYPES = [
  ["hotel", "Hotel"],
  ["homestay", "Homestay"],
  ["apartment", "Apartment"],
  ["resort", "Resort"],
];

// Used for both "add property" and "edit property". `initial` is the saved property when editing.
export default function PropertyForm({ initial, submitLabel, onSubmit }) {
  const [form, setForm] = useState({
    name: initial?.name || "",
    type: initial?.type || "hotel",
    city: initial?.city || "",
    address: initial?.address || "",
    description: initial?.description || "",
  });
  const [amenityIds, setAmenityIds] = useState(initial?.amenity_ids || []);
  const [amenities, setAmenities] = useState([]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api("/amenities").then((res) => res.ok && setAmenities(res.data));
  }, []);

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });
  const toggle = (id) => setAmenityIds((ids) => (ids.includes(id) ? ids.filter((x) => x !== id) : [...ids, id]));

  async function submit(e) {
    e.preventDefault();
    setError("");
    if (!form.name.trim() || !form.city.trim()) {
      setError("Enter the property name and the city.");
      return;
    }
    setBusy(true);
    const err = await onSubmit({
      name: form.name.trim(),
      type: form.type,
      city: form.city.trim(),
      address: form.address.trim() || null,
      description: form.description.trim() || null,
      amenity_ids: amenityIds,
    });
    setBusy(false);
    if (err) setError(err);
  }

  return (
    <form className="stack" onSubmit={submit} noValidate>
      <label className="field">
        <span>Property name</span>
        <input type="text" value={form.name} onChange={set("name")} maxLength={150} />
      </label>
      <div className="two">
        <label className="field">
          <span>Type</span>
          <select value={form.type} onChange={set("type")}>
            {TYPES.map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>City</span>
          <input type="text" value={form.city} onChange={set("city")} maxLength={80} />
        </label>
      </div>
      <label className="field">
        <span>Address</span>
        <input type="text" value={form.address} onChange={set("address")} autoComplete="street-address" />
      </label>
      <label className="field">
        <span>Description</span>
        <textarea rows={5} value={form.description} onChange={set("description")} />
      </label>
      {amenities.length > 0 && (
        <fieldset className="amenities">
          <legend>Amenities</legend>
          {amenities.map((a) => (
            <label key={a.id} className="check">
              <input type="checkbox" checked={amenityIds.includes(a.id)} onChange={() => toggle(a.id)} />
              <span>{a.name}</span>
            </label>
          ))}
        </fieldset>
      )}
      {error && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}
      <button type="submit" className="btn btn-primary" aria-busy={busy}>
        {busy ? "Saving…" : submitLabel}
      </button>
    </form>
  );
}
