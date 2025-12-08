-- Seed Test Data for LeadMap Phase 3 Testing
-- Run this in Supabase SQL Editor

-- 1. Make yourself admin (replace with your email)
UPDATE users 
SET role = 'admin' 
WHERE email = 'your-email@example.com';  -- REPLACE THIS WITH YOUR EMAIL

-- 2. Mark some listings as expired
-- Note: 'active' column may not exist if Phase 2 wasn't fully applied
UPDATE listings 
SET expired = TRUE, 
    expired_at = NOW(),
    last_seen = NOW() - INTERVAL '7 days'
WHERE id IN (
  SELECT id FROM listings 
  WHERE expired IS NULL 
  LIMIT 2
);

-- 3. Add geo_source to some listings
UPDATE listings 
SET geo_source = 'GooglePlaces', 
    last_seen = NOW()
WHERE id IN (
  SELECT id FROM listings 
  WHERE geo_source IS NULL 
  LIMIT 2
);

-- 4. Add enrichment data to some listings
UPDATE listings 
SET owner_email = 'owner@example.com', 
    enrichment_confidence = 0.85,
    enrichment_source = 'FullContact',
    last_seen = NOW()
WHERE id IN (
  SELECT id FROM listings 
  WHERE owner_email IS NULL 
  LIMIT 2
);

-- 5. Add probate leads
INSERT INTO probate_leads (case_number, decedent_name, address, city, state, zip, filing_date, source)
VALUES 
  ('001','John Doe','1115 Catskill Rd','Indianapolis','IN','46234','2025-01-15','Test'),
  ('002','Jane Smith','2455 Main St','Detroit','MI','48201','2025-01-16','Test'),
  ('003','Robert Johnson','789 Oak Ave','Chicago','IL','60601','2025-01-17','Test')
ON CONFLICT DO NOTHING;

-- 6. Update last_seen for all listings to ensure freshness
UPDATE listings 
SET last_seen = NOW() - (random() * interval '30 days');

-- 7. Verify data
SELECT 
  'Expired listings' as type, COUNT(*) as count
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
SELECT 'Probate leads', COUNT(*) 
FROM probate_leads;

