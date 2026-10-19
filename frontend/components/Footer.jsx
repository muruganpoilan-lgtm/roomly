import Link from "next/link";

export default function Footer() {
  return (
    <footer className="site-footer">
      <div className="tiles" aria-hidden="true" />
      <div className="footer-inner">
        <p className="footer-brand">Roomly</p>
        <p className="meta">Hotels and homestays across India. Rooms are shown only when they are free on every night of your stay.</p>
        <nav className="footer-links" aria-label="Footer">
          <Link href="/">Search rooms</Link>
          <Link href="/register">List your property</Link>
          <Link href="/bookings">My bookings</Link>
        </nav>
      </div>
    </footer>
  );
}
