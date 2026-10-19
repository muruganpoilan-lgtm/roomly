export const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

// FastAPI sends errors as {detail: "text"} or, for bad input, {detail: [{loc, msg}, ...]}.
export function errorMessage(body, fallback) {
  const d = body && body.detail;
  if (typeof d === "string") return d;
  if (Array.isArray(d) && d.length) {
    const first = d[0];
    const field = Array.isArray(first.loc) ? first.loc[first.loc.length - 1] : "";
    const msg = String(first.msg || "").replace(/^Value error, /, "");
    return field && field !== "body" ? `${field}: ${msg}` : msg;
  }
  return fallback;
}

// One place for every call to the Roomly API. Never throws: returns {ok, status, data} or {ok:false, status, error}.
export async function api(path, { method = "GET", body, token } = {}) {
  let res;
  try {
    res = await fetch(`${API_BASE}${path}`, {
      method,
      headers: {
        ...(body ? { "Content-Type": "application/json" } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      cache: "no-store",
    });
  } catch {
    return {
      ok: false,
      status: 0,
      error: "Can't reach the Roomly server. Check that the backend is running, then try again.",
    };
  }
  let data = null;
  try {
    data = await res.json();
  } catch {}
  if (!res.ok) {
    return { ok: false, status: res.status, error: errorMessage(data, "Something went wrong. Try again.") };
  }
  return { ok: true, status: res.status, data };
}

// Multipart upload for photos. The browser sets the Content-Type (with its boundary) itself.
export async function apiUpload(path, files, token) {
  const form = new FormData();
  for (const f of files) form.append("files", f);
  let res;
  try {
    res = await fetch(`${API_BASE}${path}`, {
      method: "POST",
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      body: form,
      cache: "no-store",
    });
  } catch {
    return { ok: false, status: 0, error: "Can't reach the Roomly server. Check that the backend is running, then try again." };
  }
  let data = null;
  try {
    data = await res.json();
  } catch {}
  if (!res.ok) return { ok: false, status: res.status, error: errorMessage(data, "Upload failed. Try again.") };
  return { ok: true, status: res.status, data };
}

const inr = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 });
export const money = (n) => inr.format(Number(n));

// Dates travel as YYYY-MM-DD strings. These helpers avoid time-zone surprises.
const pad = (n) => String(n).padStart(2, "0");
export function isoDate(d) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
export function todayISO() {
  return isoDate(new Date());
}
export function addDays(iso, n) {
  const [y, m, d] = iso.split("-").map(Number);
  return isoDate(new Date(y, m - 1, d + n));
}
export function nightsBetween(a, b) {
  const [y1, m1, d1] = a.split("-").map(Number);
  const [y2, m2, d2] = b.split("-").map(Number);
  return Math.round((Date.UTC(y2, m2 - 1, d2) - Date.UTC(y1, m1 - 1, d1)) / 86400000);
}
export function prettyDate(iso) {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
}
export function isISODate(s) {
  return typeof s === "string" && /^\d{4}-\d{2}-\d{2}$/.test(s);
}
export function plural(n, word) {
  return `${n} ${word}${n === 1 ? "" : "s"}`;
}
