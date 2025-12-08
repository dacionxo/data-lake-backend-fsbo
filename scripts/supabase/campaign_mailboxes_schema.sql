-- ============================================================================
-- Campaign Mailboxes Join Table
-- ============================================================================
-- Allows campaigns to use multiple mailboxes for sending emails
-- ============================================================================

CREATE TABLE IF NOT EXISTS campaign_mailboxes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  mailbox_id UUID NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(campaign_id, mailbox_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_campaign_mailboxes_campaign_id ON campaign_mailboxes(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_mailboxes_mailbox_id ON campaign_mailboxes(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_campaign_mailboxes_user_id ON campaign_mailboxes(user_id);

-- Enable RLS
ALTER TABLE campaign_mailboxes ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can manage mailboxes for their own campaigns
CREATE POLICY "Users can manage mailboxes for their campaigns"
  ON campaign_mailboxes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM campaigns c
      WHERE c.id = campaign_mailboxes.campaign_id
        AND c.user_id = auth.uid()
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM campaigns c
      WHERE c.id = campaign_mailboxes.campaign_id
        AND c.user_id = auth.uid()
    ) AND
    EXISTS (
      SELECT 1 FROM mailboxes m
      WHERE m.id = campaign_mailboxes.mailbox_id
        AND m.user_id = auth.uid()
    )
  );

