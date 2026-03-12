-- ============================================================================
-- Enum Lookup Tables Schema
-- ============================================================================
-- This schema introduces lookup tables for enums that are currently encoded
-- as TEXT + CHECK constraints. This provides:
-- - Data integrity through foreign keys
-- - Easier management of enum values
-- - Better query performance
-- - Audit trails for enum changes
--
-- LOOKUP TABLES:
-- - lead_status (status values for listings)
-- - pipeline_status (pipeline run statuses)
-- - user_role (user roles: user, admin)
-- - plan_tier (subscription tiers: free, starter, pro)
-- - contact_status (contact status values)
-- - deal_stage (deal pipeline stages)
-- - task_status (task status values)
-- - task_priority (task priority levels)
-- - list_type (list types: people, properties)
-- - list_item_type (list item types: contact, company, listing)
-- ============================================================================

-- Ensure uuid extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- LOOKUP TABLES
-- ============================================================================

-- Lead Status Lookup Table
CREATE TABLE IF NOT EXISTS lead_status (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- e.g., 'fsbo', 'frbo', 'expired', 'active', 'sold'
  label TEXT NOT NULL, -- Human-readable label
  description TEXT,
  category TEXT, -- 'listing', 'category', etc.
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Pipeline Status Lookup Table
CREATE TABLE IF NOT EXISTS pipeline_status (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- e.g., 'queued', 'running', 'completed', 'failed'
  label TEXT NOT NULL,
  description TEXT,
  is_terminal BOOLEAN NOT NULL DEFAULT FALSE, -- true if this is a final state
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User Role Lookup Table
CREATE TABLE IF NOT EXISTS user_role (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- 'user', 'admin'
  label TEXT NOT NULL,
  description TEXT,
  permissions JSONB, -- Optional: store permissions as JSON
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Plan Tier Lookup Table
CREATE TABLE IF NOT EXISTS plan_tier (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- 'free', 'starter', 'pro'
  label TEXT NOT NULL,
  description TEXT,
  monthly_price NUMERIC(10, 2),
  features JSONB, -- Feature list as JSON
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Contact Status Lookup Table
CREATE TABLE IF NOT EXISTS contact_status (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- 'new', 'contacted', 'qualified', 'nurturing', 'not_interested'
  label TEXT NOT NULL,
  description TEXT,
  category TEXT, -- 'active', 'inactive', etc.
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Deal Stage Lookup Table
CREATE TABLE IF NOT EXISTS deal_stage (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- 'new', 'contacted', 'qualified', 'proposal', etc.
  label TEXT NOT NULL,
  description TEXT,
  category TEXT, -- 'open', 'won', 'lost'
  probability_default INTEGER DEFAULT 0, -- Default probability for this stage
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Task Status Lookup Table
CREATE TABLE IF NOT EXISTS task_status (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- 'pending', 'in_progress', 'completed', 'cancelled'
  label TEXT NOT NULL,
  description TEXT,
  is_complete BOOLEAN NOT NULL DEFAULT FALSE,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Task Priority Lookup Table
CREATE TABLE IF NOT EXISTS task_priority (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- 'low', 'medium', 'high', 'urgent'
  label TEXT NOT NULL,
  description TEXT,
  priority_level INTEGER NOT NULL, -- Numeric level (1-4)
  color_code TEXT, -- UI color code
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- List Type Lookup Table
CREATE TABLE IF NOT EXISTS list_type (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- 'people', 'properties'
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- List Item Type Lookup Table
CREATE TABLE IF NOT EXISTS list_item_type (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE, -- 'contact', 'company', 'listing'
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_lead_status_code ON lead_status(code);
CREATE INDEX IF NOT EXISTS idx_lead_status_active ON lead_status(active);
CREATE INDEX IF NOT EXISTS idx_pipeline_status_code ON pipeline_status(code);
CREATE INDEX IF NOT EXISTS idx_user_role_code ON user_role(code);
CREATE INDEX IF NOT EXISTS idx_plan_tier_code ON plan_tier(code);
CREATE INDEX IF NOT EXISTS idx_contact_status_code ON contact_status(code);
CREATE INDEX IF NOT EXISTS idx_deal_stage_code ON deal_stage(code);
CREATE INDEX IF NOT EXISTS idx_task_status_code ON task_status(code);
CREATE INDEX IF NOT EXISTS idx_task_priority_code ON task_priority(code);

-- ============================================================================
-- INITIAL ENUM VALUES
-- ============================================================================

-- Lead Status Values
INSERT INTO lead_status (code, label, description, category, display_order) VALUES
  ('fsbo', 'FSBO', 'For Sale By Owner', 'category', 1),
  ('frbo', 'FRBO', 'For Rent By Owner', 'category', 2),
  ('expired', 'Expired', 'Listing has expired', 'listing', 3),
  ('active', 'Active', 'Active listing', 'listing', 4),
  ('sold', 'Sold', 'Property has been sold', 'listing', 5),
  ('pending', 'Pending', 'Sale is pending', 'listing', 6),
  ('foreclosure', 'Foreclosure', 'Foreclosure listing', 'category', 7)
ON CONFLICT (code) DO NOTHING;

-- Pipeline Status Values
INSERT INTO pipeline_status (code, label, description, is_terminal, display_order) VALUES
  ('queued', 'Queued', 'Pipeline run is queued', FALSE, 1),
  ('running', 'Running', 'Pipeline run is currently executing', FALSE, 2),
  ('completed', 'Completed', 'Pipeline run completed successfully', TRUE, 3),
  ('failed', 'Failed', 'Pipeline run failed', TRUE, 4),
  ('cancelled', 'Cancelled', 'Pipeline run was cancelled', TRUE, 5),
  ('timeout', 'Timeout', 'Pipeline run timed out', TRUE, 6)
ON CONFLICT (code) DO NOTHING;

-- User Role Values
INSERT INTO user_role (code, label, description, display_order) VALUES
  ('user', 'User', 'Standard user account', 1),
  ('admin', 'Admin', 'Administrator account with full access', 2)
ON CONFLICT (code) DO NOTHING;

-- Plan Tier Values
INSERT INTO plan_tier (code, label, description, monthly_price, display_order) VALUES
  ('free', 'Free', 'Free tier with basic features', 0.00, 1),
  ('starter', 'Starter', 'Starter tier with enhanced features', 29.99, 2),
  ('pro', 'Pro', 'Professional tier with all features', 99.99, 3)
ON CONFLICT (code) DO NOTHING;

-- Contact Status Values
INSERT INTO contact_status (code, label, description, category, display_order) VALUES
  ('new', 'New', 'Newly added contact', 'active', 1),
  ('contacted', 'Contacted', 'Contact has been reached', 'active', 2),
  ('qualified', 'Qualified', 'Contact is qualified', 'active', 3),
  ('nurturing', 'Nurturing', 'Contact in nurturing phase', 'active', 4),
  ('not_interested', 'Not Interested', 'Contact is not interested', 'inactive', 5)
ON CONFLICT (code) DO NOTHING;

-- Deal Stage Values
INSERT INTO deal_stage (code, label, description, category, probability_default, display_order) VALUES
  ('new', 'New', 'New deal opportunity', 'open', 10, 1),
  ('contacted', 'Contacted', 'Initial contact made', 'open', 20, 2),
  ('qualified', 'Qualified', 'Deal is qualified', 'open', 40, 3),
  ('proposal', 'Proposal', 'Proposal sent', 'open', 60, 4),
  ('negotiation', 'Negotiation', 'In negotiation', 'open', 80, 5),
  ('closed_won', 'Closed Won', 'Deal won', 'won', 100, 6),
  ('closed_lost', 'Closed Lost', 'Deal lost', 'lost', 0, 7)
ON CONFLICT (code) DO NOTHING;

-- Task Status Values
INSERT INTO task_status (code, label, description, is_complete, display_order) VALUES
  ('pending', 'Pending', 'Task is pending', FALSE, 1),
  ('in_progress', 'In Progress', 'Task is in progress', FALSE, 2),
  ('completed', 'Completed', 'Task is completed', TRUE, 3),
  ('cancelled', 'Cancelled', 'Task was cancelled', TRUE, 4)
ON CONFLICT (code) DO NOTHING;

-- Task Priority Values
INSERT INTO task_priority (code, label, description, priority_level, color_code, display_order) VALUES
  ('low', 'Low', 'Low priority task', 1, '#gray', 1),
  ('medium', 'Medium', 'Medium priority task', 2, '#blue', 2),
  ('high', 'High', 'High priority task', 3, '#orange', 3),
  ('urgent', 'Urgent', 'Urgent priority task', 4, '#red', 4)
ON CONFLICT (code) DO NOTHING;

-- List Type Values
INSERT INTO list_type (code, label, description, display_order) VALUES
  ('people', 'People', 'List of people/contacts', 1),
  ('properties', 'Properties', 'List of properties', 2)
ON CONFLICT (code) DO NOTHING;

-- List Item Type Values
INSERT INTO list_item_type (code, label, description, display_order) VALUES
  ('contact', 'Contact', 'Contact item', 1),
  ('company', 'Company', 'Company item', 2),
  ('listing', 'Listing', 'Property listing item', 3)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to validate enum value exists
CREATE OR REPLACE FUNCTION validate_enum_value(
  p_enum_table TEXT,
  p_code TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I WHERE code = $1 AND active = TRUE)', p_enum_table)
  INTO v_exists
  USING p_code;
  
  RETURN v_exists;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Lookup tables are read-only for all authenticated users
-- Only admins can modify

ALTER TABLE lead_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_role ENABLE ROW LEVEL SECURITY;
ALTER TABLE plan_tier ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_stage ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_priority ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_item_type ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view lookup tables
CREATE POLICY "Users can view lead_status"
  ON lead_status FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view pipeline_status"
  ON pipeline_status FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view user_role"
  ON user_role FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view plan_tier"
  ON plan_tier FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view contact_status"
  ON contact_status FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view deal_stage"
  ON deal_stage FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view task_status"
  ON task_status FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view task_priority"
  ON task_priority FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view list_type"
  ON list_type FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view list_item_type"
  ON list_item_type FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can modify lookup tables
CREATE POLICY "Admins can manage lead_status"
  ON lead_status FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

-- Apply same admin policy to all lookup tables
CREATE POLICY "Admins can manage pipeline_status"
  ON pipeline_status FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

CREATE POLICY "Admins can manage user_role"
  ON user_role FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

CREATE POLICY "Admins can manage plan_tier"
  ON plan_tier FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

CREATE POLICY "Admins can manage contact_status"
  ON contact_status FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

CREATE POLICY "Admins can manage deal_stage"
  ON deal_stage FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

CREATE POLICY "Admins can manage task_status"
  ON task_status FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

CREATE POLICY "Admins can manage task_priority"
  ON task_priority FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

CREATE POLICY "Admins can manage list_type"
  ON list_type FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

CREATE POLICY "Admins can manage list_item_type"
  ON list_item_type FOR ALL
  TO authenticated
  USING (
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE lead_status IS 'Lookup table for lead/listing status values';
COMMENT ON TABLE pipeline_status IS 'Lookup table for pipeline run status values';
COMMENT ON TABLE user_role IS 'Lookup table for user roles';
COMMENT ON TABLE plan_tier IS 'Lookup table for subscription plan tiers';
COMMENT ON TABLE contact_status IS 'Lookup table for contact status values';
COMMENT ON TABLE deal_stage IS 'Lookup table for deal pipeline stages';
COMMENT ON TABLE task_status IS 'Lookup table for task status values';
COMMENT ON TABLE task_priority IS 'Lookup table for task priority levels';
COMMENT ON TABLE list_type IS 'Lookup table for list types';
COMMENT ON TABLE list_item_type IS 'Lookup table for list item types';

COMMENT ON FUNCTION validate_enum_value IS 'Validates that an enum code exists and is active in a lookup table';

