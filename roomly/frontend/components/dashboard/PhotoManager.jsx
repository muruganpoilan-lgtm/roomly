"use client";

import { useRef, useState } from "react";
import { api, apiUpload } from "../../lib/api";

// Upload and remove photos for a property or a room. `base` is e.g. /owner/properties/ID or /owner/room-types/ID.
export default function PhotoManager({ base, photos, token, onChange, onAuthError }) {
  const input = useRef(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function upload(e) {
    const files = Array.from(e.target.files || []);
    if (!files.length) return;
    setError("");
    setBusy(true);
    const res = await apiUpload(`${base}/photos`, files, token);
    setBusy(false);
    if (input.current) input.current.value = "";
    if (res.status === 401) return onAuthError();
    if (!res.ok) return setError(res.error);
    onChange();
  }

  async function remove(id) {
    if (!window.confirm("Remove this photo?")) return;
    setError("");
    const res = await api(`${base}/photos/${id}`, { method: "DELETE", token });
    if (res.status === 401) return onAuthError();
    if (!res.ok) return setError(res.error);
    onChange();
  }

  return (
    <div>
      {photos.length > 0 && (
        <ul className="photo-grid">
          {photos.map((p) => (
            <li key={p.id}>
              <img src={p.url} alt="" loading="lazy" />
              <button type="button" className="photo-remove" onClick={() => remove(p.id)} aria-label="Remove photo">
                Remove
              </button>
            </li>
          ))}
        </ul>
      )}
      <label className="btn btn-small" aria-busy={busy}>
        {busy ? "Uploading…" : photos.length ? "Add more photos" : "Add photos"}
        <input ref={input} type="file" accept="image/jpeg,image/png,image/webp" multiple onChange={upload} disabled={busy} className="sr-only" />
      </label>
      <p className="meta">JPG, PNG or WebP, up to 5 MB each. The first photo is the cover.</p>
      {error && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
