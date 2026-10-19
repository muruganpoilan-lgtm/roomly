-- Razorpay payments. Run once on an existing database:
--   docker compose exec -T postgres psql -U roomly -d roomly < db/migrations/002_payments.sql
-- (a fresh database gets all of this from schema.sql)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS refund_id        text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS refunded_amount  numeric(10,2) NOT NULL DEFAULT 0;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS note             text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS updated_at       timestamptz NOT NULL DEFAULT now();
-- A Razorpay order belongs to one payment row, and a booking has at most one open (unpaid) order.
CREATE UNIQUE INDEX IF NOT EXISTS payments_order_uq ON payments (provider_order_id) WHERE provider_order_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS payments_one_open ON payments (booking_id) WHERE status = 'created';
