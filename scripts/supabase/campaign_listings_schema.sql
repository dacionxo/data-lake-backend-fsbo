-- ============================================================================
-- CAMPAIGN_LISTINGS TABLE
-- ============================================================================
-- Join table that links campaigns to listings saved from Prospect & Enrich
-- This ensures listings saved in Prospect & Enrich can be retrieved in Campaign Details
-- ============================================================================

CREATE TABLE IF NOT EXISTS campaign_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  listing_id TEXT NOT NULL, -- No foreign key constraint since listings can be in multiple tables
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Prevent duplicate listings in the same campaign
  UNIQUE (campaign_id, listing_id)
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_campaign_listings_campaign_id ON campaign_listings(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_listings_listing_id ON campaign_listings(listing_id);
CREATE INDEX IF NOT EXISTS idx_campaign_listings_user_id ON campaign_listings(user_id);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE campaign_listings ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see campaign_listings for their own campaigns
CREATE POLICY "campaign_listings_by_user"
ON campaign_listings
FOR ALL
USING (user_id = auth.uid());

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE campaign_listings IS 'Join table linking campaigns to listings saved from Prospect & Enrich screen';
COMMENT ON COLUMN campaign_listings.user_id IS 'User who owns the campaign (acts as tenant scope)';
COMMENT ON COLUMN campaign_listings.campaign_id IS 'Campaign the listing belongs to';
COMMENT ON COLUMN campaign_listings.listing_id IS 'Listing ID from the listings table';

