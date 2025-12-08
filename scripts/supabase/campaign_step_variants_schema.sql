-- ============================================================================
-- Campaign Step Variants Schema
-- ============================================================================
-- Allows multiple email variants per campaign step for A/B testing
-- ============================================================================

-- Create campaign_step_variants table
CREATE TABLE IF NOT EXISTS campaign_step_variants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  step_id UUID NOT NULL REFERENCES campaign_steps(id) ON DELETE CASCADE,
  
  -- Variant identification
  variant_number INTEGER NOT NULL, -- 1, 2, 3... (per step)
  name TEXT, -- Optional name for the variant (e.g., "Subject A", "Version 2")
  
  -- Email content (overrides step defaults)
  subject TEXT NOT NULL,
  html TEXT NOT NULL,
  plain_text TEXT, -- Optional plain text version
  
  -- A/B testing settings
  send_percentage INTEGER DEFAULT 100, -- Percentage of recipients to get this variant (for split testing)
  is_active BOOLEAN DEFAULT TRUE, -- Whether this variant is currently active
  
  -- Performance tracking
  total_sent INTEGER DEFAULT 0,
  total_opened INTEGER DEFAULT 0,
  total_clicked INTEGER DEFAULT 0,
  total_replied INTEGER DEFAULT 0,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(step_id, variant_number)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_campaign_step_variants_step_id ON campaign_step_variants(step_id);
CREATE INDEX IF NOT EXISTS idx_campaign_step_variants_active ON campaign_step_variants(is_active) WHERE is_active = TRUE;

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_campaign_step_variants_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_campaign_step_variants_updated_at
  BEFORE UPDATE ON campaign_step_variants
  FOR EACH ROW
  EXECUTE FUNCTION update_campaign_step_variants_updated_at();

-- Enable RLS
ALTER TABLE campaign_step_variants ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view variants for their campaigns"
  ON campaign_step_variants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM campaign_steps cs
      JOIN campaigns c ON c.id = cs.campaign_id
      WHERE cs.id = campaign_step_variants.step_id
        AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert variants for their campaigns"
  ON campaign_step_variants FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM campaign_steps cs
      JOIN campaigns c ON c.id = cs.campaign_id
      WHERE cs.id = campaign_step_variants.step_id
        AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update variants for their campaigns"
  ON campaign_step_variants FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM campaign_steps cs
      JOIN campaigns c ON c.id = cs.campaign_id
      WHERE cs.id = campaign_step_variants.step_id
        AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete variants for their campaigns"
  ON campaign_step_variants FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM campaign_steps cs
      JOIN campaigns c ON c.id = cs.campaign_id
      WHERE cs.id = campaign_step_variants.step_id
        AND c.user_id = auth.uid()
    )
  );

