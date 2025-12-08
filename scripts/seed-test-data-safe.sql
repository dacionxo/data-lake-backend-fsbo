-- SAFE Seed Test Data for LeadMap
-- This version only uses columns that exist in the base schema

-- 1. Make yourself admin (replace with your email)
UPDATE users 
SET role = 'admin' 
WHERE email = 'your-email@example.com';  -- REPLACE THIS WITH YOUR EMAIL

-- 2. Verify what columns exist (run this to check)
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'listings' 
ORDER BY ordinal_position;

-- 3. Add basic test data (only if columns exist)
-- This creates some sample listings if you don't have any yet
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM listings LIMIT 1) THEN
    INSERT INTO listings (address, city, state, zip, price, price_drop_percent, days_on_market, url)
    VALUES 
      ('123 Test St', 'Los Angeles', 'CA', '90210', 500000, 15.5, 45, 'https://example.com/1'),
      ('456 Sample Ave', 'Miami', 'FL', '33101', 350000, 12.3, 30, 'https://example.com/2'),
      ('789 Demo Rd', 'Chicago', 'IL', '60601', 420000, 8.7, 60, 'https://example.com/3');
  END IF;
END $$;

-- 4. Try to add Phase 2 columns if they don't exist
ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS expired BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS expired_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS owner_email TEXT,
  ADD COLUMN IF NOT EXISTS enrichment_source TEXT,
  ADD COLUMN IF NOT EXISTS enrichment_confidence FLOAT,
  ADD COLUMN IF NOT EXISTS geo_source TEXT,
  ADD COLUMN IF NOT EXISTS radius_km FLOAT;

-- 5. Now mark some listings as expired (if expired column now exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'listings' AND column_name = 'expired'
  ) THEN
    UPDATE listings 
    SET expired = TRUE, 
        expired_at = NOW()
    WHERE id IN (
      SELECT id FROM listings 
      WHERE expired IS NOT DISTINCT FROM FALSE  -- handles NULL as well
      LIMIT 2
    );
  END IF;
END $$;

-- 6. Add geo_source to some listings
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'listings' AND column_name = 'geo_source'
  ) THEN
    UPDATE listings 
    SET geo_source = 'GooglePlaces'
    WHERE id IN (
      SELECT id FROM listings 
      WHERE geo_source IS NULL 
      LIMIT 2
    );
  END IF;
END $$;

-- 7. Add enrichment data
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'listings' AND column_name = 'owner_email'
  ) THEN
    UPDATE listings 
    SET owner_email = 'owner@example.com', 
        enrichment_confidence = 0.85,
        enrichment_source = 'FullContact'
    WHERE id IN (
      SELECT id FROM listings 
      WHERE owner_email IS NULL 
      LIMIT 2
    );
  END IF;
END $$;

-- 8. Add probate leads (only if table exists)
INSERT INTO probate_leads (case_number, decedent_name, address, city, state, zip, filing_date, source)
VALUES 
  ('001','John Doe','1115 Catskill Rd','Indianapolis','IN','46234','2025-01-15','Test'),
  ('002','Jane Smith','2455 Main St','Detroit','MI','48201','2025-01-16','Test'),
  ('003','Robert Johnson','789 Oak Ave','Chicago','IL','60601','2025-01-17','Test')
ON CONFLICT DO NOTHING;

-- 9. Verify data
SELECT 
  'Total listings' as type, COUNT(*) as count
FROM listings
UNION ALL
SELECT 'Expired listings', COUNT(*) 
FROM listings 
WHERE expired = TRUE
UNION ALL
SELECT 'Geo-sourced', COUNT(*) 
FROM listings 
WHERE geo_source IS NOT NULL
UNION ALL
SELECT 'Enriched', COUNT(*) 
FROM listings 
WHERE owner_email IS NOT NULL OR enrichment_confidence IS NOT NULL
UNION ALL
SELECT 'Probate leads', COALESCE((SELECT COUNT(*) FROM probate_leads), 0);

