-- Template System Enhancements Migration
-- Adds versioning, enhanced categories, ownership, stats, and subject templating

-- Add new columns to email_templates table
ALTER TABLE email_templates
  ADD COLUMN IF NOT EXISTS subject TEXT,
  ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS parent_template_id UUID REFERENCES email_templates(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS folder_path TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'user' CHECK (scope IN ('global', 'user', 'team')),
  ADD COLUMN IF NOT EXISTS team_id UUID,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS allowed_variables TEXT[] DEFAULT '{}';

-- Create template_versions table for version history
CREATE TABLE IF NOT EXISTS template_versions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  template_id UUID NOT NULL REFERENCES email_templates(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  title TEXT NOT NULL,
  subject TEXT,
  body TEXT NOT NULL,
  category TEXT NOT NULL,
  folder_path TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_name TEXT,
  change_notes TEXT
);

-- Create template_stats table for performance tracking
CREATE TABLE IF NOT EXISTS template_stats (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  template_id UUID NOT NULL REFERENCES email_templates(id) ON DELETE CASCADE,
  version INTEGER,
  total_sent INTEGER DEFAULT 0,
  total_opened INTEGER DEFAULT 0,
  total_clicked INTEGER DEFAULT 0,
  total_replied INTEGER DEFAULT 0,
  total_bounced INTEGER DEFAULT 0,
  total_unsubscribed INTEGER DEFAULT 0,
  open_rate DECIMAL(5, 2) DEFAULT 0,
  click_rate DECIMAL(5, 2) DEFAULT 0,
  reply_rate DECIMAL(5, 2) DEFAULT 0,
  bounce_rate DECIMAL(5, 2) DEFAULT 0,
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(template_id, version)
);

-- Create template_test_sends table for test email tracking
CREATE TABLE IF NOT EXISTS template_test_sends (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  template_id UUID NOT NULL REFERENCES email_templates(id) ON DELETE CASCADE,
  version INTEGER,
  test_email TEXT NOT NULL,
  rendered_subject TEXT,
  rendered_body TEXT,
  test_context JSONB,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  sent_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  opened_at TIMESTAMPTZ,
  clicked_at TIMESTAMPTZ
);

-- Create template_folders table for organizing templates
CREATE TABLE IF NOT EXISTS template_folders (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  path TEXT NOT NULL UNIQUE,
  parent_folder_id UUID REFERENCES template_folders(id) ON DELETE CASCADE,
  scope TEXT DEFAULT 'user' CHECK (scope IN ('global', 'user', 'team')),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  team_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Update categories to support hierarchical structure
-- Common categories: Cold Outreach, Follow-up, Referral, Transactional, Other
-- These can be stored in folder_path like: "/Cold Outreach/Initial", "/Follow-up/First Touch"

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_template_versions_template_id ON template_versions(template_id);
CREATE INDEX IF NOT EXISTS idx_template_versions_version ON template_versions(template_id, version);
CREATE INDEX IF NOT EXISTS idx_template_stats_template_id ON template_stats(template_id);
CREATE INDEX IF NOT EXISTS idx_template_stats_version ON template_stats(template_id, version);
CREATE INDEX IF NOT EXISTS idx_template_test_sends_template_id ON template_test_sends(template_id);
CREATE INDEX IF NOT EXISTS idx_template_folders_path ON template_folders(path);
CREATE INDEX IF NOT EXISTS idx_template_folders_user_id ON template_folders(user_id);
CREATE INDEX IF NOT EXISTS idx_email_templates_scope ON email_templates(scope);
CREATE INDEX IF NOT EXISTS idx_email_templates_folder_path ON email_templates(folder_path);
CREATE INDEX IF NOT EXISTS idx_email_templates_parent_id ON email_templates(parent_template_id);

-- Function to create a new version when template is updated
CREATE OR REPLACE FUNCTION create_template_version()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create version if body, subject, or title changed
  IF (TG_OP = 'UPDATE' AND (
    OLD.body IS DISTINCT FROM NEW.body OR
    OLD.subject IS DISTINCT FROM NEW.subject OR
    OLD.title IS DISTINCT FROM NEW.title
  )) THEN
    -- Get the next version number
    NEW.version := COALESCE((SELECT MAX(version) FROM template_versions WHERE template_id = NEW.id), 0) + 1;
    
    -- Save current version to history
    INSERT INTO template_versions (
      template_id,
      version,
      title,
      subject,
      body,
      category,
      folder_path,
      created_by,
      created_by_name,
      change_notes
    )
    SELECT
      OLD.id,
      OLD.version,
      OLD.title,
      OLD.subject,
      OLD.body,
      OLD.category,
      OLD.folder_path,
      OLD.created_by,
      (SELECT name FROM users WHERE id = OLD.created_by LIMIT 1),
      'Auto-saved on update'
    WHERE OLD.version IS NOT NULL;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-create versions
DROP TRIGGER IF EXISTS trigger_create_template_version ON email_templates;
CREATE TRIGGER trigger_create_template_version
  BEFORE UPDATE ON email_templates
  FOR EACH ROW
  EXECUTE FUNCTION create_template_version();

-- Function to update template stats
CREATE OR REPLACE FUNCTION update_template_stats()
RETURNS TRIGGER AS $$
DECLARE
  template_uuid UUID;
  template_version_num INTEGER;
BEGIN
  -- Extract template_id from campaign or email metadata
  template_uuid := (NEW.metadata->>'template_id')::UUID;
  template_version_num := COALESCE((NEW.metadata->>'template_version')::INTEGER, 1);
  
  IF template_uuid IS NOT NULL THEN
    INSERT INTO template_stats (
      template_id,
      version,
      total_sent,
      total_opened,
      total_clicked,
      total_replied,
      total_bounced,
      total_unsubscribed,
      last_used_at
    )
    VALUES (
      template_uuid,
      template_version_num,
      CASE WHEN NEW.status = 'sent' THEN 1 ELSE 0 END,
      CASE WHEN NEW.opened_at IS NOT NULL THEN 1 ELSE 0 END,
      CASE WHEN NEW.clicked_at IS NOT NULL THEN 1 ELSE 0 END,
      CASE WHEN NEW.replied_at IS NOT NULL THEN 1 ELSE 0 END,
      CASE WHEN NEW.status = 'bounced' THEN 1 ELSE 0 END,
      CASE WHEN NEW.unsubscribed_at IS NOT NULL THEN 1 ELSE 0 END,
      CASE WHEN NEW.status = 'sent' THEN NOW() ELSE NULL END
    )
    ON CONFLICT (template_id, version)
    DO UPDATE SET
      total_sent = template_stats.total_sent + CASE WHEN NEW.status = 'sent' THEN 1 ELSE 0 END,
      total_opened = template_stats.total_opened + CASE WHEN NEW.opened_at IS NOT NULL THEN 1 ELSE 0 END,
      total_clicked = template_stats.total_clicked + CASE WHEN NEW.clicked_at IS NOT NULL THEN 1 ELSE 0 END,
      total_replied = template_stats.total_replied + CASE WHEN NEW.replied_at IS NOT NULL THEN 1 ELSE 0 END,
      total_bounced = template_stats.total_bounced + CASE WHEN NEW.status = 'bounced' THEN 1 ELSE 0 END,
      total_unsubscribed = template_stats.total_unsubscribed + CASE WHEN NEW.unsubscribed_at IS NOT NULL THEN 1 ELSE 0 END,
      open_rate = CASE 
        WHEN template_stats.total_sent > 0 THEN 
          (template_stats.total_opened::DECIMAL / template_stats.total_sent * 100)
        ELSE 0 
      END,
      click_rate = CASE 
        WHEN template_stats.total_sent > 0 THEN 
          (template_stats.total_clicked::DECIMAL / template_stats.total_sent * 100)
        ELSE 0 
      END,
      reply_rate = CASE 
        WHEN template_stats.total_sent > 0 THEN 
          (template_stats.total_replied::DECIMAL / template_stats.total_sent * 100)
        ELSE 0 
      END,
      bounce_rate = CASE 
        WHEN template_stats.total_sent > 0 THEN 
          (template_stats.total_bounced::DECIMAL / template_stats.total_sent * 100)
        ELSE 0 
      END,
      last_used_at = COALESCE(
        CASE WHEN NEW.status = 'sent' THEN NOW() ELSE NULL END,
        template_stats.last_used_at
      ),
      updated_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: The trigger for update_template_stats would need to be attached to the emails table
-- This is just the function definition. The trigger should be created separately if emails table exists.

-- RLS Policies for new tables
ALTER TABLE template_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE template_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE template_test_sends ENABLE ROW LEVEL SECURITY;
ALTER TABLE template_folders ENABLE ROW LEVEL SECURITY;

-- Template versions policies
CREATE POLICY "Users can view template versions"
  ON template_versions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM email_templates
      WHERE email_templates.id = template_versions.template_id
      AND (
        email_templates.scope = 'global' OR
        email_templates.created_by = auth.uid() OR
        email_templates.scope = 'user' AND email_templates.created_by = auth.uid()
      )
    )
  );

-- Template stats policies
CREATE POLICY "Users can view template stats"
  ON template_stats FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM email_templates
      WHERE email_templates.id = template_stats.template_id
      AND (
        email_templates.scope = 'global' OR
        email_templates.created_by = auth.uid() OR
        email_templates.scope = 'user' AND email_templates.created_by = auth.uid()
      )
    )
  );

-- Template test sends policies
CREATE POLICY "Users can view their test sends"
  ON template_test_sends FOR SELECT
  USING (sent_by = auth.uid());

CREATE POLICY "Users can create test sends"
  ON template_test_sends FOR INSERT
  WITH CHECK (sent_by = auth.uid());

-- Template folders policies
CREATE POLICY "Users can view folders"
  ON template_folders FOR SELECT
  USING (
    scope = 'global' OR
    user_id = auth.uid() OR
    (scope = 'user' AND user_id = auth.uid())
  );

CREATE POLICY "Users can create folders"
  ON template_folders FOR INSERT
  WITH CHECK (user_id = auth.uid() OR scope = 'global');

-- Update existing email_templates RLS policies to support scope
DROP POLICY IF EXISTS "Authenticated users can view templates" ON email_templates;
CREATE POLICY "Users can view templates based on scope"
  ON email_templates FOR SELECT
  USING (
    scope = 'global' OR
    created_by = auth.uid() OR
    (scope = 'user' AND created_by = auth.uid())
  );

-- Update insert policy to allow users to create their own templates
DROP POLICY IF EXISTS "Admins can insert templates" ON email_templates;
CREATE POLICY "Users can create templates"
  ON email_templates FOR INSERT
  WITH CHECK (
    created_by = auth.uid() OR
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

-- Update update policy to allow users to update their own templates
DROP POLICY IF EXISTS "Admins can update templates" ON email_templates;
CREATE POLICY "Users can update their own templates or admins can update any"
  ON email_templates FOR UPDATE
  USING (
    created_by = auth.uid() OR
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

-- Update delete policy
DROP POLICY IF EXISTS "Admins can delete templates" ON email_templates;
CREATE POLICY "Users can delete their own templates or admins can delete any"
  ON email_templates FOR DELETE
  USING (
    created_by = auth.uid() OR
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

