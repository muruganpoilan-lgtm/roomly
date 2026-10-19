import Link from "next/link";
import Ridge from "../../components/Ridge";
import SearchForm from "../../components/SearchForm";
import { addDays, api, isISODate, money, nightsBetween, plural, todayISO } from "../../lib/api";

export const metadata = { title: "Search stays: Roomly" };

const TYPE_LABEL = { hotel: "Hotel", homestay: "Homestay", apartment: "Apartment", resort: "Resort" };

export default async function SearchPage({ searchParams }) {
  const sp = await searchParams;
  const get = (k) => (Array.isArray(sp[k]) ? sp[k][0] : sp[k]) || "";

  const checkIn = isISODate(get("check_in")) ? get("check_in") : addDays(todayISO(), 1);
  const checkOutRaw = isISODate(get("check_out")) ? get("check_out") : "";
  const checkOut = checkOutRaw && checkOutRaw > checkIn ? checkOutRaw : addDays(checkIn, 1);
  const guests = Math.min(Math.max(Number(get("guests")) || 2, 1), 40);
  const city = get("city");
  const sort = get("sort") === "rating" ? "rating" : "price";
  const type = Object.hasOwn(TYPE_LABEL, get("type")) ? get("type") : "";
  const maxPrice = Number(get("max_price")) > 0 ? get("max_price") : "";
  const nights = nightsBetween(checkIn, checkOut);

  const q = new URLSearchParams({ check_in: checkIn, check_out: checkOut, guests: String(guests), sort });
  if (city) q.set("city", city);
  if (type) q.set("property_type", type);
  if (maxPrice) q.set("max_price", maxPrice);
  const res = await api(`/search?${q.toString()}`);

  const detailQuery = new URLSearchParams({ check_in: checkIn, check_out: checkOut, guests: String(guests) }).toString();

  return (
    <main className="page">
      <SearchForm compact initial={{ city, check_in: checkIn, check_out: checkOut, guests }} />

      <div className="results-layout">
        <form className="filters" method="get" action="/search">
          <h2 className="mini-title">Narrow down</h2>
          <input type="hidden" name="city" value={city} />
          <input type="hidden" name="check_in" value={checkIn} />
          <input type="hidden" name="check_out" value={checkOut} />
          <input type="hidden" name="guests" value={guests} />
          <fieldset className="radios">
            <legend>Type of place</legend>
            {[["", "Any"], ...Object.entries(TYPE_LABEL)].map(([v, label]) => (
              <label key={v || "any"} className="check">
                <input type="radio" name="type" value={v} defaultChecked={type === v} />
                <span>{label}</span>
              </label>
            ))}
          </fieldset>
          <label className="field">
            <span>Most per night (₹)</span>
            <input type="number" name="max_price" min="0" step="100" defaultValue={maxPrice} placeholder="No limit" />
          </label>
          <label className="field">
            <span>Sort by</span>
            <select name="sort" defaultValue={sort}>
              <option value="price">Lowest price</option>
              <option value="rating">Best rated</option>
            </select>
          </label>
          <button type="submit" className="btn btn-primary btn-small">
            Apply filters
          </button>
        </form>

        <div>
          {!res.ok ? (
            <div className="empty" role="alert">
              <h2>We couldn't load results</h2>
              <p>{res.error}</p>
            </div>
          ) : res.data.results.length === 0 ? (
            <div className="empty">
              <h2>No rooms free for all {plural(nights, "night")}</h2>
              <p>Try other dates, a shorter stay, or remove the price limit. Rooms only show up when they are free on every night.</p>
            </div>
          ) : (
            <>
              <h1 className="result-title">
                {city ? `Stays in ${city}` : "Stays across India"}
              </h1>
              <p className="result-summary">
                {plural(res.data.results.length, "place")} with rooms free for {plural(nights, "night")}
              </p>
              <ul className="results">
                {res.data.results.map((p) => {
                  const perNight = Number(p.price_per_night);
                  return (
                    <li key={p.id}>
                      <Link className="result" href={`/properties/${p.id}?${detailQuery}`}>
                        <div className="result-photo">
                          {p.photo ? <img src={p.photo} alt="" loading="lazy" /> : <Ridge seed={p.id} />}
                        </div>
                        <div className="result-body">
                          <p className="meta">{TYPE_LABEL[p.type] || p.type} in {p.city}</p>
                          <h3 className="row-name">{p.name}</h3>
                          <p className="rating">
                            {p.rating_count > 0 ? (
                              <>
                                <b className="score">{Number(p.rating_avg).toFixed(1)}</b> from {plural(p.rating_count, "review")}
                              </>
                            ) : (
                              "New on Roomly"
                            )}
                          </p>
                        </div>
                        <div className="price-box">
                          <span className="price">{money(perNight)}</span>
                          <span className="price-sub">a night</span>
                          <span className="price-sub">{money(perNight * nights)} for {plural(nights, "night")}</span>
                        </div>
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </>
          )}
        </div>
      </div>
    </main>
  );
}
