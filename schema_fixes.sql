ALTER TABLE vendors
  ADD COLUMN IF NOT EXISTS owner_name    TEXT,
  ADD COLUMN IF NOT EXISTS phone         TEXT,
  ADD COLUMN IF NOT EXISTS email         TEXT,
  ADD COLUMN IF NOT EXISTS password_hash TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vendors_phone_key') THEN
    ALTER TABLE vendors ADD CONSTRAINT vendors_phone_key UNIQUE (phone);
  END IF;
END $$;
