import { notFound } from "next/navigation";
import PhotoGallery from "../../../components/PhotoGallery";
import RoomList from "../../../components/RoomList";
import { api, isISODate, nightsBetween, plural } from "../../../lib/api";

const TYPE_LABEL = { hotel: "Hotel", homestay: "Homestay", apartment: "Apartment", resort: "Resort" };

export async function generateMetadata({ params }) {
  const { id } = await params;
  const res = await api(`/properties/${id}`);
  return { title: res.ok ? `${res.data.name}: Roomly` : "Property: Roomly" };
}

export default async function PropertyPage({ params, searchParams }) {
  const { id } = await params;
  const sp = await searchParams;
  const get = (k) => (Array.isArray(sp[k]) ? sp[k][0] : sp[k]) || "";

  const ci = isISODate(get("check_in")) ? get("check_in") : "";
  const co = isISODate(get("check_out")) ? get("check_out") : "";
  const hasDates = Boolean(ci && co && co > ci);
  const guests = Math.min(Math.max(Number(get("guests")) || 2, 1), 40);

  const qs = hasDates ? `?${new URLSearchParams({ check_in: ci, check_out: co }).toString()}` : "";
  const res = await api(`/properties/${id}${qs}`);

  if (!res.ok && res.status === 404) notFound();
  if (!res.ok) {
    return (
      <main className="page">
        <div className="empty" role="alert">
          <h2>We couldn't load this place</h2>
          <p>{res.error}</p>
        </div>
      </main>
    );
  }

  const p = res.data;
  return (
    <main className="page">
      <div className="prop-head">
        <p className="meta">{TYPE_LABEL[p.type] || p.type} in {p.city}</p>
        <h1>{p.name}</h1>
        <p className="rating">
          {p.rating_count > 0 ? (
            <>
              <b className="score">{Number(p.rating_avg).toFixed(1)}</b> from {plural(p.rating_count, "review")}
            </>
          ) : (
            "New on Roomly"
          )}
          {p.address ? <span className="meta"> &nbsp;{p.address}</span> : null}
        </p>
      </div>

      <PhotoGallery photos={p.photos} name={p.name} seed={p.id} />

      <div className="prop-body">
        <div>
          {p.description && (
            <section className="prop-section">
              <h2>About this place</h2>
              <p className="prose">{p.description}</p>
            </section>
          )}
          {p.amenities.length > 0 && (
            <section className="prop-section">
              <h2>What's included</h2>
              <ul className="amenity-list">
                {p.amenities.map((a) => (
                  <li key={a}>{a}</li>
                ))}
              </ul>
            </section>
          )}
        </div>
      </div>

      <section className="prop-section">
        <h2>Rooms</h2>
        <RoomList
          rooms={p.room_types}
          checkIn={hasDates ? ci : ""}
          checkOut={hasDates ? co : ""}
          guests={guests}
          nights={hasDates ? nightsBetween(ci, co) : 0}
        />
      </section>
    </main>
  );
}
