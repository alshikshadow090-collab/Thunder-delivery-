-- ============================================================
-- Thunder Delivery — Database Schema (PostgreSQL 14+ / Neon)
-- Reconstructed from live Neon introspection + verified against
-- actual queries used in src/routes/*.js on 2026-09-21.
-- Run this ONCE against a fresh database to recreate the schema.
-- ============================================================

-- ---------- Reference / lookup tables ----------

CREATE TABLE order_types (
  type_id   SERIAL PRIMARY KEY,
  type_name TEXT NOT NULL
);

CREATE TABLE payment_methods (
  method_id   SERIAL PRIMARY KEY,
  method_name TEXT NOT NULL
);

CREATE TABLE loyalty_tiers (
  tier_name         TEXT PRIMARY KEY,
  points_multiplier NUMERIC,
  perks             JSONB
);

-- ---------- Core identity tables ----------

CREATE TABLE users (
  user_id       SERIAL PRIMARY KEY,
  full_name     TEXT NOT NULL,
  phone         TEXT NOT NULL UNIQUE,
  email         TEXT,
  password_hash TEXT NOT NULL,
  profile_image TEXT,
  notify_channel TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMP
);

CREATE TABLE drivers (
  driver_id     SERIAL PRIMARY KEY,
  full_name     TEXT NOT NULL,
  phone         TEXT NOT NULL UNIQUE,
  email         TEXT,
  password_hash TEXT,
  vehicle_type  TEXT,
  vehicle_plate TEXT,
  rating_avg    NUMERIC DEFAULT 0,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  is_online     BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMP
);

CREATE TABLE driver_live_location (
  driver_id  INTEGER PRIMARY KEY REFERENCES drivers(driver_id) ON DELETE CASCADE,
  latitude   NUMERIC,
  longitude  NUMERIC,
  heading    NUMERIC,
  speed      NUMERIC,
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------- Vendors / menu (for delivery-from-vendor orders) ----------

CREATE TABLE vendors (
  vendor_id           SERIAL PRIMARY KEY,
  business_name       TEXT NOT NULL,
  category_id         INTEGER,
  address_text        TEXT,
  latitude            NUMERIC,
  longitude           NUMERIC,
  logo_url            TEXT,
  cover_image_url     TEXT,
  status              TEXT DEFAULT 'active',
  is_open             BOOLEAN NOT NULL DEFAULT true,
  rating_avg          NUMERIC DEFAULT 0,
  min_order_value     NUMERIC DEFAULT 0,
  delivery_fee        NUMERIC DEFAULT 0,
  commission_percent  NUMERIC DEFAULT 0,
  avg_prep_minutes    INTEGER,
  created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMP
);

CREATE TABLE menu_categories (
  menu_category_id SERIAL PRIMARY KEY,
  vendor_id        INTEGER NOT NULL REFERENCES vendors(vendor_id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  display_order    INTEGER DEFAULT 0,
  is_active        BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE menu_items (
  item_id           SERIAL PRIMARY KEY,
  vendor_id         INTEGER NOT NULL REFERENCES vendors(vendor_id) ON DELETE CASCADE,
  menu_category_id  INTEGER REFERENCES menu_categories(menu_category_id) ON DELETE SET NULL,
  name              TEXT NOT NULL,
  description       TEXT,
  price             NUMERIC NOT NULL,
  currency          TEXT DEFAULT 'SDG',
  image_url         TEXT,
  prep_minutes      INTEGER,
  is_available      BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMP NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMP
);

-- ---------- Orders ----------

CREATE TABLE orders (
  order_id             SERIAL PRIMARY KEY,
  user_id              INTEGER NOT NULL REFERENCES users(user_id),
  driver_id            INTEGER REFERENCES drivers(driver_id),
  type_id              INTEGER REFERENCES order_types(type_id),
  status               TEXT NOT NULL DEFAULT 'pending',
  pickup_lat           NUMERIC,
  pickup_lng           NUMERIC,
  pickup_address_text  TEXT,
  dropoff_lat          NUMERIC,
  dropoff_lng          NUMERIC,
  dropoff_address_text TEXT,
  notes                TEXT,
  distance_km          NUMERIC,
  estimated_price      NUMERIC,
  final_price          NUMERIC,
  currency             TEXT DEFAULT 'SDG',
  is_scheduled         BOOLEAN DEFAULT false,
  scheduled_at         TIMESTAMP,
  created_at           TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_driver_id ON orders(driver_id);
CREATE INDEX idx_orders_status ON orders(status);

CREATE TABLE order_status_log (
  log_id        SERIAL PRIMARY KEY,
  order_id      INTEGER NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  status        TEXT NOT NULL,
  changed_by    TEXT,
  changed_by_id INTEGER,
  notes         TEXT,
  changed_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_status_log_order_id ON order_status_log(order_id);

CREATE TABLE sos_alerts (
  alert_id     SERIAL PRIMARY KEY,
  order_id     INTEGER REFERENCES orders(order_id),
  user_id      INTEGER REFERENCES users(user_id),
  triggered_by TEXT NOT NULL,
  latitude     NUMERIC,
  longitude    NUMERIC,
  notes        TEXT,
  created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
  resolved_at  TIMESTAMP
);

-- ---------- Wallet / payments ----------

CREATE TABLE wallets (
  wallet_id  SERIAL PRIMARY KEY,
  user_id    INTEGER NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
  balance    NUMERIC NOT NULL DEFAULT 0,
  currency   TEXT DEFAULT 'SDG',
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE wallet_transactions (
  tx_id         SERIAL PRIMARY KEY,
  wallet_id     INTEGER NOT NULL REFERENCES wallets(wallet_id) ON DELETE CASCADE,
  order_id      INTEGER REFERENCES orders(order_id),
  amount        NUMERIC NOT NULL,
  tx_type       TEXT NOT NULL,
  balance_after NUMERIC,
  reference     TEXT,
  created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);

-- ---------- Loyalty / referrals ----------

CREATE TABLE loyalty_accounts (
  account_id     SERIAL PRIMARY KEY,
  user_id        INTEGER NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
  points_balance INTEGER NOT NULL DEFAULT 0,
  tier_name      TEXT REFERENCES loyalty_tiers(tier_name)
);

CREATE TABLE referral_codes (
  code    TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  uses    INTEGER NOT NULL DEFAULT 0
);

-- ---------- Notifications ----------

CREATE TABLE notifications (
  notification_id SERIAL PRIMARY KEY,
  recipient_id     INTEGER NOT NULL,
  recipient_type   TEXT NOT NULL, -- 'user' | 'driver' (polymorphic, no FK)
  type             TEXT,
  title            TEXT NOT NULL,
  body             TEXT,
  payload          JSONB,
  is_read          BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_recipient ON notifications(recipient_id, recipient_type);

-- تحديث: هذه الأعمدة تمت إضافتها لاحقاً على قاعدة البيانات الحية
ALTER TABLE vendors
  ADD COLUMN IF NOT EXISTS owner_name    TEXT,
  ADD COLUMN IF NOT EXISTS phone         TEXT,
  ADD COLUMN IF NOT EXISTS email         TEXT,
  ADD COLUMN IF NOT EXISTS password_hash TEXT;
