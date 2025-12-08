-- ============================================================================
-- Split Testing Schema for Email Campaigns
-- ============================================================================
-- World-class split testing (A/B testing) functionality for campaign steps
-- Tracks variant assignments, performance metrics, and winner selection
-- ============================================================================

-- ============================================================================
-- 1) SPLIT TEST CONFIGURATION
-- ============================================================================
-- Stores split testing settings for each campaign step
CREATE TABLE IF NOT EXISTS campaign_step_split_tests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  step_id UUID NOT NULL REFERENCES campaign_steps(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Split test status
  is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  started_at TIMESTAMPTZ, -- When split test started
  ended_at TIMESTAMPTZ, -- When split test ended (if manually stopped)
  
  -- Distribution method
  distribution_method TEXT NOT NULL DEFAULT 'equal' CHECK (
    distribution_method IN ('equal', 'percentage', 'weighted')
  ),
  
  -- Winner selection criteria
  winner_selection_criteria TEXT NOT NULL DEFAULT 'open_rate' CHECK (
    winner_selection_criteria IN (
      'open_rate',
      'click_rate',
      'reply_rate',
      'conversion_rate',
      'manual'
    )
  ),
  
  -- Auto-select winner settings
  auto_select_winner BOOLEAN DEFAULT FALSE,
  min_recipients_per_variant INTEGER DEFAULT 100, -- Minimum recipients before considering winner
  min_time_hours INTEGER DEFAULT 24, -- Minimum time before considering winner
  confidence_level DECIMAL(5,2) DEFAULT 95.00, -- Statistical confidence level (95%, 99%, etc.)
  
  -- Test duration
  test_duration_hours INTEGER, -- How long to run test before selecting winner
  test_duration_recipients INTEGER, -- Or run until X recipients per variant
  
  -- Winner tracking
  winner_variant_id UUID REFERENCES campaign_step_variants(id) ON DELETE SET NULL,
  winner_selected_at TIMESTAMPTZ,
  winner_selection_method TEXT CHECK (
    winner_selection_method IN ('auto', 'manual', 'statistical')
  ),
  
  -- Metadata
  notes TEXT, -- User notes about the test
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(step_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_split_tests_step_id ON campaign_step_split_tests(step_id);
CREATE INDEX IF NOT EXISTS idx_split_tests_user_id ON campaign_step_split_tests(user_id);
CREATE INDEX IF NOT EXISTS idx_split_tests_enabled ON campaign_step_split_tests(is_enabled) WHERE is_enabled = TRUE;
CREATE INDEX IF NOT EXISTS idx_split_tests_winner ON campaign_step_split_tests(winner_variant_id) WHERE winner_variant_id IS NOT NULL;

-- ============================================================================
-- 2) RECIPIENT VARIANT ASSIGNMENTS
-- ============================================================================
-- Tracks which variant each recipient received for each step
CREATE TABLE IF NOT EXISTS campaign_recipient_variant_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  step_id UUID NOT NULL REFERENCES campaign_steps(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES campaign_recipients(id) ON DELETE CASCADE,
  variant_id UUID NOT NULL REFERENCES campaign_step_variants(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Assignment metadata
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  assignment_method TEXT DEFAULT 'automatic' CHECK (
    assignment_method IN ('automatic', 'manual', 'weighted_random', 'round_robin')
  ),
  
  -- Email tracking
  email_id UUID REFERENCES emails(id) ON DELETE SET NULL, -- Link to sent email
  sent_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ,
  clicked_at TIMESTAMPTZ,
  replied_at TIMESTAMPTZ,
  bounced_at TIMESTAMPTZ,
  unsubscribed_at TIMESTAMPTZ,
  
  -- Performance flags
  was_opened BOOLEAN DEFAULT FALSE,
  was_clicked BOOLEAN DEFAULT FALSE,
  was_replied BOOLEAN DEFAULT FALSE,
  was_bounced BOOLEAN DEFAULT FALSE,
  was_unsubscribed BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure one variant per recipient per step
  UNIQUE(step_id, recipient_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_variant_assignments_campaign ON campaign_recipient_variant_assignments(campaign_id);
CREATE INDEX IF NOT EXISTS idx_variant_assignments_step ON campaign_recipient_variant_assignments(step_id);
CREATE INDEX IF NOT EXISTS idx_variant_assignments_recipient ON campaign_recipient_variant_assignments(recipient_id);
CREATE INDEX IF NOT EXISTS idx_variant_assignments_variant ON campaign_recipient_variant_assignments(variant_id);
CREATE INDEX IF NOT EXISTS idx_variant_assignments_user ON campaign_recipient_variant_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_variant_assignments_email ON campaign_recipient_variant_assignments(email_id) WHERE email_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_variant_assignments_performance ON campaign_recipient_variant_assignments(step_id, variant_id, was_opened, was_clicked, was_replied);

-- ============================================================================
-- 3) VARIANT DISTRIBUTION SETTINGS
-- ============================================================================
-- Stores custom distribution percentages/weights for variants
CREATE TABLE IF NOT EXISTS campaign_variant_distributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  split_test_id UUID NOT NULL REFERENCES campaign_step_split_tests(id) ON DELETE CASCADE,
  variant_id UUID NOT NULL REFERENCES campaign_step_variants(id) ON DELETE CASCADE,
  
  -- Distribution settings
  send_percentage INTEGER NOT NULL DEFAULT 50 CHECK (send_percentage >= 0 AND send_percentage <= 100),
  weight INTEGER DEFAULT 1 CHECK (weight > 0), -- For weighted distribution
  
  -- Current stats (denormalized for performance)
  total_assigned INTEGER DEFAULT 0,
  total_sent INTEGER DEFAULT 0,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(split_test_id, variant_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_variant_distributions_split_test ON campaign_variant_distributions(split_test_id);
CREATE INDEX IF NOT EXISTS idx_variant_distributions_variant ON campaign_variant_distributions(variant_id);

-- ============================================================================
-- 4) SPLIT TEST ANALYTICS VIEW
-- ============================================================================
-- Materialized view for fast analytics queries
CREATE OR REPLACE VIEW split_test_analytics AS
SELECT 
  st.id AS split_test_id,
  st.step_id,
  st.is_enabled,
  st.distribution_method,
  st.winner_selection_criteria,
  st.winner_variant_id,
  v.id AS variant_id,
  v.variant_number,
  v.name AS variant_name,
  COUNT(DISTINCT rva.recipient_id) AS total_assigned,
  COUNT(DISTINCT CASE WHEN rva.sent_at IS NOT NULL THEN rva.recipient_id END) AS total_sent,
  COUNT(DISTINCT CASE WHEN rva.was_opened = TRUE THEN rva.recipient_id END) AS total_opened,
  COUNT(DISTINCT CASE WHEN rva.was_clicked = TRUE THEN rva.recipient_id END) AS total_clicked,
  COUNT(DISTINCT CASE WHEN rva.was_replied = TRUE THEN rva.recipient_id END) AS total_replied,
  COUNT(DISTINCT CASE WHEN rva.was_bounced = TRUE THEN rva.recipient_id END) AS total_bounced,
  COUNT(DISTINCT CASE WHEN rva.was_unsubscribed = TRUE THEN rva.recipient_id END) AS total_unsubscribed,
  CASE 
    WHEN COUNT(DISTINCT CASE WHEN rva.sent_at IS NOT NULL THEN rva.recipient_id END) > 0 
    THEN ROUND(
      (COUNT(DISTINCT CASE WHEN rva.was_opened = TRUE THEN rva.recipient_id END)::DECIMAL / 
       COUNT(DISTINCT CASE WHEN rva.sent_at IS NOT NULL THEN rva.recipient_id END)::DECIMAL) * 100, 
      2
    )
    ELSE 0 
  END AS open_rate,
  CASE 
    WHEN COUNT(DISTINCT CASE WHEN rva.sent_at IS NOT NULL THEN rva.recipient_id END) > 0 
    THEN ROUND(
      (COUNT(DISTINCT CASE WHEN rva.was_clicked = TRUE THEN rva.recipient_id END)::DECIMAL / 
       COUNT(DISTINCT CASE WHEN rva.sent_at IS NOT NULL THEN rva.recipient_id END)::DECIMAL) * 100, 
      2
    )
    ELSE 0 
  END AS click_rate,
  CASE 
    WHEN COUNT(DISTINCT CASE WHEN rva.sent_at IS NOT NULL THEN rva.recipient_id END) > 0 
    THEN ROUND(
      (COUNT(DISTINCT CASE WHEN rva.was_replied = TRUE THEN rva.recipient_id END)::DECIMAL / 
       COUNT(DISTINCT CASE WHEN rva.sent_at IS NOT NULL THEN rva.recipient_id END)::DECIMAL) * 100, 
      2
    )
    ELSE 0 
  END AS reply_rate
FROM campaign_step_split_tests st
LEFT JOIN campaign_step_variants v ON v.step_id = st.step_id
LEFT JOIN campaign_recipient_variant_assignments rva ON rva.variant_id = v.id AND rva.step_id = st.step_id
GROUP BY st.id, st.step_id, st.is_enabled, st.distribution_method, st.winner_selection_criteria, 
         st.winner_variant_id, v.id, v.variant_number, v.name;

-- ============================================================================
-- 5) TRIGGERS
-- ============================================================================

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_split_test_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_campaign_step_split_tests_updated_at
  BEFORE UPDATE ON campaign_step_split_tests
  FOR EACH ROW
  EXECUTE FUNCTION update_split_test_updated_at();

CREATE TRIGGER update_campaign_recipient_variant_assignments_updated_at
  BEFORE UPDATE ON campaign_recipient_variant_assignments
  FOR EACH ROW
  EXECUTE FUNCTION update_split_test_updated_at();

CREATE TRIGGER update_campaign_variant_distributions_updated_at
  BEFORE UPDATE ON campaign_variant_distributions
  FOR EACH ROW
  EXECUTE FUNCTION update_split_test_updated_at();

-- Auto-update variant performance metrics when assignment is updated
CREATE OR REPLACE FUNCTION update_variant_performance_metrics()
RETURNS TRIGGER AS $$
BEGIN
  -- Update variant totals when assignment performance changes
  IF (OLD.was_opened IS DISTINCT FROM NEW.was_opened) OR
     (OLD.was_clicked IS DISTINCT FROM NEW.was_clicked) OR
     (OLD.was_replied IS DISTINCT FROM NEW.was_replied) OR
     (OLD.sent_at IS DISTINCT FROM NEW.sent_at) THEN
    
    UPDATE campaign_step_variants
    SET
      total_sent = (
        SELECT COUNT(*) 
        FROM campaign_recipient_variant_assignments 
        WHERE variant_id = NEW.variant_id AND sent_at IS NOT NULL
      ),
      total_opened = (
        SELECT COUNT(*) 
        FROM campaign_recipient_variant_assignments 
        WHERE variant_id = NEW.variant_id AND was_opened = TRUE
      ),
      total_clicked = (
        SELECT COUNT(*) 
        FROM campaign_recipient_variant_assignments 
        WHERE variant_id = NEW.variant_id AND was_clicked = TRUE
      ),
      total_replied = (
        SELECT COUNT(*) 
        FROM campaign_recipient_variant_assignments 
        WHERE variant_id = NEW.variant_id AND was_replied = TRUE
      ),
      updated_at = NOW()
    WHERE id = NEW.variant_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_variant_metrics_on_assignment_update
  AFTER UPDATE ON campaign_recipient_variant_assignments
  FOR EACH ROW
  EXECUTE FUNCTION update_variant_performance_metrics();

-- ============================================================================
-- 6) ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE campaign_step_split_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_recipient_variant_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_variant_distributions ENABLE ROW LEVEL SECURITY;

-- Split Tests Policies
CREATE POLICY "Users can view split tests for their campaigns"
  ON campaign_step_split_tests FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert split tests for their campaigns"
  ON campaign_step_split_tests FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update split tests for their campaigns"
  ON campaign_step_split_tests FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete split tests for their campaigns"
  ON campaign_step_split_tests FOR DELETE
  USING (user_id = auth.uid());

-- Variant Assignments Policies
CREATE POLICY "Users can view variant assignments for their campaigns"
  ON campaign_recipient_variant_assignments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM campaigns c
      WHERE c.id = campaign_recipient_variant_assignments.campaign_id
        AND c.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert variant assignments for their campaigns"
  ON campaign_recipient_variant_assignments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM campaigns c
      WHERE c.id = campaign_recipient_variant_assignments.campaign_id
        AND c.user_id = auth.uid()
    )
    AND user_id = auth.uid()
  );

CREATE POLICY "Users can update variant assignments for their campaigns"
  ON campaign_recipient_variant_assignments FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM campaigns c
      WHERE c.id = campaign_recipient_variant_assignments.campaign_id
        AND c.user_id = auth.uid()
    )
  );

-- Variant Distributions Policies
CREATE POLICY "Users can view distributions for their split tests"
  ON campaign_variant_distributions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM campaign_step_split_tests st
      WHERE st.id = campaign_variant_distributions.split_test_id
        AND st.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert distributions for their split tests"
  ON campaign_variant_distributions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM campaign_step_split_tests st
      WHERE st.id = campaign_variant_distributions.split_test_id
        AND st.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update distributions for their split tests"
  ON campaign_variant_distributions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM campaign_step_split_tests st
      WHERE st.id = campaign_variant_distributions.split_test_id
        AND st.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete distributions for their split tests"
  ON campaign_variant_distributions FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM campaign_step_split_tests st
      WHERE st.id = campaign_variant_distributions.split_test_id
        AND st.user_id = auth.uid()
    )
  );

-- ============================================================================
-- 7) HELPER FUNCTIONS
-- ============================================================================

-- Function to get next variant for a recipient (for distribution)
CREATE OR REPLACE FUNCTION get_next_variant_for_recipient(
  p_step_id UUID,
  p_recipient_id UUID,
  p_distribution_method TEXT DEFAULT 'equal'
)
RETURNS UUID AS $$
DECLARE
  v_variant_id UUID;
  v_split_test_id UUID;
  v_variant_count INTEGER;
  v_assigned_count INTEGER;
BEGIN
  -- Check if split test is enabled
  SELECT id INTO v_split_test_id
  FROM campaign_step_split_tests
  WHERE step_id = p_step_id AND is_enabled = TRUE;
  
  IF v_split_test_id IS NULL THEN
    -- No split test, return first active variant
    SELECT id INTO v_variant_id
    FROM campaign_step_variants
    WHERE step_id = p_step_id AND is_active = TRUE
    ORDER BY variant_number ASC
    LIMIT 1;
    RETURN v_variant_id;
  END IF;
  
  -- Check if recipient already has an assignment
  SELECT variant_id INTO v_variant_id
  FROM campaign_recipient_variant_assignments
  WHERE step_id = p_step_id AND recipient_id = p_recipient_id;
  
  IF v_variant_id IS NOT NULL THEN
    RETURN v_variant_id; -- Already assigned
  END IF;
  
  -- Get active variants for this step
  SELECT COUNT(*) INTO v_variant_count
  FROM campaign_step_variants
  WHERE step_id = p_step_id AND is_active = TRUE;
  
  IF v_variant_count = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Distribution logic
  IF p_distribution_method = 'equal' THEN
    -- Round-robin or random equal distribution
    SELECT id INTO v_variant_id
    FROM campaign_step_variants
    WHERE step_id = p_step_id AND is_active = TRUE
    ORDER BY 
      (SELECT COUNT(*) FROM campaign_recipient_variant_assignments 
       WHERE variant_id = campaign_step_variants.id AND step_id = p_step_id) ASC,
      variant_number ASC
    LIMIT 1;
  ELSIF p_distribution_method = 'percentage' THEN
    -- Use distribution percentages
    SELECT vd.variant_id INTO v_variant_id
    FROM campaign_variant_distributions vd
    JOIN campaign_step_variants v ON v.id = vd.variant_id
    WHERE vd.split_test_id = v_split_test_id
      AND v.is_active = TRUE
    ORDER BY 
      (SELECT COUNT(*) FROM campaign_recipient_variant_assignments 
       WHERE variant_id = vd.variant_id AND step_id = p_step_id)::DECIMAL / 
      NULLIF(vd.send_percentage, 0) ASC,
      v.variant_number ASC
    LIMIT 1;
  ELSE
    -- Default to first variant
    SELECT id INTO v_variant_id
    FROM campaign_step_variants
    WHERE step_id = p_step_id AND is_active = TRUE
    ORDER BY variant_number ASC
    LIMIT 1;
  END IF;
  
  RETURN v_variant_id;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate statistical significance between variants
CREATE OR REPLACE FUNCTION calculate_variant_significance(
  p_split_test_id UUID
)
RETURNS TABLE (
  variant_id UUID,
  variant_name TEXT,
  open_rate DECIMAL,
  click_rate DECIMAL,
  reply_rate DECIMAL,
  sample_size INTEGER,
  is_winner BOOLEAN,
  confidence_level DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id,
    COALESCE(v.name, 'Variant ' || v.variant_number::TEXT),
    sta.open_rate,
    sta.click_rate,
    sta.reply_rate,
    sta.total_sent::INTEGER,
    (st.winner_variant_id = v.id) AS is_winner,
    st.confidence_level
  FROM split_test_analytics sta
  JOIN campaign_step_variants v ON v.id = sta.variant_id
  JOIN campaign_step_split_tests st ON st.id = sta.split_test_id
  WHERE sta.split_test_id = p_split_test_id
    AND sta.total_sent > 0
  ORDER BY sta.open_rate DESC, sta.click_rate DESC;
END;
$$ LANGUAGE plpgsql;

