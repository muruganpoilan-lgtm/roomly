CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  email         text NOT NULL UNIQUE,
  phone         text,
  password_hash text NOT NULL,
  role          text NOT NULL DEFAULT 'guest' CHECK (role IN ('guest', 'owner', 'admin')),
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE properties (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id     uuid NOT NULL REFERENCES users(id),
  name         text NOT NULL,
  type         text NOT NULL CHECK (type IN ('hotel', 'homestay', 'apartment', 'resort')),
  description  text,
  city         text NOT NULL,
  address      text,
  lat          numeric(9,6),
  lng          numeric(9,6),
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  rating_avg   numeric(2,1) NOT NULL DEFAULT 0,
  rating_count int NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_properties_city ON properties (lower(city));

CREATE TABLE amenities (
  id   serial PRIMARY KEY,
  name text NOT NULL UNIQUE
);

CREATE TABLE property_amenities (
  property_id uuid REFERENCES properties(id) ON DELETE CASCADE,
  amenity_id  int REFERENCES amenities(id),
  PRIMARY KEY (property_id, amenity_id)
);

CREATE TABLE property_photos (
  id          serial PRIMARY KEY,
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  url         text NOT NULL,
  storage_key text,  -- file path inside the upload store; NULL for external URLs
  position    int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE room_types (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  name        text NOT NULL,
  max_guests  int NOT NULL DEFAULT 2,
  base_price  numeric(10,2) NOT NULL CHECK (base_price >= 0),
  total_rooms int NOT NULL CHECK (total_rooms > 0)
);

CREATE TABLE room_type_photos (
  id           serial PRIMARY KEY,
  room_type_id uuid NOT NULL REFERENCES room_types(id) ON DELETE CASCADE,
  url          text NOT NULL,
  storage_key  text,
  position     int NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_room_type_photos ON room_type_photos (room_type_id, position);

-- One row per room type per night. This is what prevents double-booking.
CREATE TABLE room_inventory (
  room_type_id uuid NOT NULL REFERENCES room_types(id) ON DELETE CASCADE,
  day          date NOT NULL,
  available    int NOT NULL CHECK (available >= 0),
  price        numeric(10,2),
  PRIMARY KEY (room_type_id, day)
);

CREATE TABLE bookings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id),
  property_id     uuid NOT NULL REFERENCES properties(id),
  room_type_id    uuid NOT NULL REFERENCES room_types(id),
  check_in        date NOT NULL,
  check_out       date NOT NULL,
  rooms           int NOT NULL CHECK (rooms > 0),
  guests          int NOT NULL CHECK (guests > 0),
  total_amount    numeric(10,2) NOT NULL,
  status          text NOT NULL DEFAULT 'held' CHECK (status IN ('held', 'confirmed', 'cancelled', 'expired')),
  hold_expires_at timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (check_out > check_in)
);
CREATE INDEX idx_bookings_user ON bookings (user_id);
CREATE INDEX idx_bookings_hold ON bookings (status, hold_expires_at);

CREATE TABLE payments (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id          uuid NOT NULL REFERENCES bookings(id),
  provider            text NOT NULL DEFAULT 'razorpay',
  provider_order_id   text,
  provider_payment_id text,
  amount              numeric(10,2) NOT NULL,
  status              text NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'paid', 'failed', 'refunded')),
  refund_id           text,
  refunded_amount     numeric(10,2) NOT NULL DEFAULT 0,
  note                text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
-- A Razorpay order belongs to one payment row, and a booking has at most one open (unpaid) order.
CREATE UNIQUE INDEX payments_order_uq ON payments (provider_order_id) WHERE provider_order_id IS NOT NULL;
CREATE UNIQUE INDEX payments_one_open ON payments (booking_id) WHERE status = 'created';

CREATE TABLE reviews (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  uuid NOT NULL UNIQUE REFERENCES bookings(id),
  property_id uuid NOT NULL REFERENCES properties(id),
  user_id     uuid NOT NULL REFERENCES users(id),
  rating      int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO amenities (name) VALUES
  ('Wi-Fi'), ('Air conditioning'), ('Parking'), ('Breakfast'), ('Swimming pool'),
  ('Kitchen'), ('TV'), ('Hot water'), ('Power backup'), ('Pets allowed');
