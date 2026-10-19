import Link from "next/link";
import Ridge from "../components/Ridge";
import SearchForm from "../components/SearchForm";

// Approximate height above sea level, in metres. Sorted high to low so the list reads as a climb.
const PLACES = [
  { city: "Ooty", m: 2240 },
  { city: "Kodaikanal", m: 2130 },
  { city: "Munnar", m: 1530 },
  { city: "Yercaud", m: 1500 },
  { city: "Coorg", m: 1150 },
  { city: "Valparai", m: 1050 },
  { city: "Thekkady", m: 900 },
  { city: "Wayanad", m: 800 },
  { city: "Alleppey", m: 0 },
  { city: "Kovalam", m: 0 },
  { city: "Varkala", m: 0 },
  { city: "Pondicherry", m: 0 },
  { city: "Goa", m: 0 },
];
const TOP = 2240;

export default function Home() {
  return (
    <main>
      <section className="hero">
        <div className="hero-copy">
          <h1>A room for every night of your stay</h1>
          <p className="hero-text">
            Search by city and dates. Roomly only shows rooms that are free on all of them, so there is no surprise when you reserve.
          </p>
        </div>
        <Ridge seed="western-ghats" w={1440} h={260} sky={false} colors={["#1d7f69", "#14604f", "#f4f6f2"]} className="hero-ridge" />
      </section>

      <div className="slip-wrap">
        <SearchForm />
      </div>

      <section className="page home-section">
        <h2 className="section-title">Browse by city, from the hills down to the sea</h2>
        <p className="meta ladder-note">Height above sea level, roughly.</p>
        <ul className="ladder">
          {PLACES.map((p) => (
            <li key={p.city}>
              <Link href={`/search?city=${encodeURIComponent(p.city)}`} className="ladder-row">
                <span className="ladder-city">{p.city}</span>
                <span className="ladder-bar" aria-hidden="true">
                  <i style={{ width: `${Math.max((p.m / TOP) * 100, 1.5)}%` }} />
                </span>
                <span className="ladder-m">{p.m ? `${p.m.toLocaleString("en-IN")} m` : "Sea level"}</span>
              </Link>
            </li>
          ))}
        </ul>
      </section>

      <section className="page home-section how">
        <h2 className="section-title">How a booking works</h2>
        <ol className="steps">
          <li>
            <h3>Pick your dates</h3>
            <p>Every place you see has rooms free on each night of the stay.</p>
          </li>
          <li>
            <h3>We hold your room for 10 minutes</h3>
            <p>Nobody else can take it while you check the details.</p>
          </li>
          <li>
            <h3>Pay to confirm</h3>
            <p>Unpaid holds are released automatically, so rooms go back on sale.</p>
          </li>
        </ol>
      </section>

      <section className="host-band">
        <div className="host-inner">
          <h2>Own a hotel or homestay?</h2>
          <p>Add your rooms and photos, open the nights you want to sell, and set your own prices.</p>
          <Link href="/register" className="btn btn-gold">
            List your property
          </Link>
        </div>
      </section>
    </main>
  );
}
