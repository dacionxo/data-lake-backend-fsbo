# SMS Implementation Guide - GoHighLevel-Class SMS Stack

## Overview
World-class SMS functionality using Twilio Conversations API with:
- Two-way messaging
- Drip campaigns
- Personalization
- Analytics & event tracking
- Full compliance (STOP/HELP, quiet hours, A2P)

## Architecture

### Channel Layer
- **Twilio Conversations API** for SMS delivery & 2-way messaging
- Handles delivery receipts, inbound messages, and threading

### Core App Layer
- **Next.js API Routes** (`/app/api/sms/*`, `/app/api/twilio/*`)
- **Twilio SDK** for sending/receiving
- **Supabase** for data persistence and analytics

### Data Layer (Supabase)
1. `sms_conversations` - Conversation threads per lead
2. `sms_messages` - Individual SMS messages
3. `sms_campaigns` - Drip/broadcast campaigns
4. `sms_campaign_steps` - Multi-step sequences
5. `sms_campaign_enrollments` - Which leads are in which drips
6. `sms_events` - Event log for analytics

### Real-Time UI
- Dashboard SMS panel with live message stream
- Supabase Realtime or short polling (5s)
- Per-lead conversation view

### Automation
- Cron job hitting `/api/sms/drip/run` every minute
- Processes due enrollments, sends next steps
- Respects quiet hours, stop-on-reply

## Implementation Checklist

### Phase 1: Twilio Setup
- [ ] Create Twilio Conversations Service
- [ ] Get Conversation Service SID (ISxxxxxxxx)
- [ ] Provision SMS number + Messaging Service
- [ ] Link Messaging Service to Conversations Service
- [ ] Configure webhooks (onMessageAdded, onDeliveryUpdated, etc.)
- [ ] Add environment variables to `.env.local`
- [ ] Install Twilio SDK: `npm install twilio`

### Phase 2: Database Schema
- [ ] Create `sms_conversations` table
- [ ] Create `sms_messages` table with enums
- [ ] Create `sms_campaigns` table
- [ ] Create `sms_campaign_steps` table
- [ ] Create `sms_campaign_enrollments` table
- [ ] Create `sms_events` table
- [ ] Add indexes for performance
- [ ] Create analytics views (campaign_performance, user_daily_metrics)

### Phase 3: Backend Core
- [ ] Create `lib/twilio.ts` helper
- [ ] Implement `getOrCreateConversationForLead()`
- [ ] Implement `sendConversationMessage()`
- [ ] Create webhook route: `/app/api/twilio/conversations/webhook/route.ts`
- [ ] Implement `handleMessageAdded()` in webhook
- [ ] Implement `handleDeliveryUpdated()` in webhook
- [ ] Add Twilio signature validation
- [ ] Implement STOP/HELP keyword detection

### Phase 4: API Endpoints
- [ ] Create `/app/api/sms/messages/route.ts` (GET, POST)
- [ ] Implement GET messages for conversation
- [ ] Implement POST to send message
- [ ] Add template personalization support
- [ ] Create `/app/api/sms/conversations/route.ts`
- [ ] Create `/app/api/sms/campaigns/route.ts` (CRUD)
- [ ] Create `/app/api/sms/campaigns/[id]/route.ts`
- [ ] Create `/app/api/sms/campaigns/[id]/steps/route.ts`
- [ ] Create `/app/api/sms/campaigns/[id]/enroll/route.ts`
- [ ] Create `/app/api/sms/drip/run/route.ts` (cron runner)

### Phase 5: Drip Campaign Engine
- [ ] Implement drip runner logic
- [ ] Add quiet hours check
- [ ] Add stop-on-reply handling
- [ ] Add enrollment completion logic
- [ ] Implement template rendering with lead data
- [ ] Add event logging for each step
- [ ] Set up cron job (Supabase or external)

### Phase 6: Frontend Components
- [ ] Create `SmsConversationPanel.tsx`
- [ ] Add message list UI (inbound/outbound styling)
- [ ] Add send message form
- [ ] Implement polling/realtime updates
- [ ] Create `SmsCampaignBuilder.tsx`
- [ ] Add campaign step editor
- [ ] Create `SmsAnalyticsDashboard.tsx`
- [ ] Add campaign performance charts
- [ ] Add user engagement metrics

### Phase 7: Integration with Existing Features
- [ ] Add SMS button to lead rows in LeadsTable
- [ ] Add SMS panel to MapView lead detail
- [ ] Add SMS conversation to listing detail pages
- [ ] Link SMS to existing template system
- [ ] Add SMS enrollment option in bulk actions
- [ ] Create SMS campaign from saved lists

### Phase 8: Analytics & Reporting
- [ ] Implement campaign performance view
- [ ] Add per-user daily metrics
- [ ] Create delivery rate tracking
- [ ] Add reply rate calculation
- [ ] Add opt-out rate tracking
- [ ] Build timeline visualization per lead
- [ ] Add cost tracking (messages sent * rate)

### Phase 9: Compliance
- [ ] Add consent language to first messages
- [ ] Implement STOP keyword auto-response
- [ ] Implement HELP keyword auto-response
- [ ] Add A2P 10DLC registration docs
- [ ] Add quiet hours enforcement
- [ ] Add rate limiting (daily/hourly caps)
- [ ] Update Terms of Service SMS section
- [ ] Add unsubscribe management UI

### Phase 10: Testing & Polish
- [ ] Test two-way messaging flow
- [ ] Test drip campaign execution
- [ ] Test quiet hours logic
- [ ] Test STOP/HELP keywords
- [ ] Test webhook signature validation
- [ ] Test template personalization
- [ ] Load test with 100+ enrollments
- [ ] Test error handling (failed sends, invalid numbers)
- [ ] Add retry logic for failed messages
- [ ] Add admin SMS settings page

## Environment Variables

```bash
# Twilio Core
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token

# Conversations
TWILIO_CONVERSATIONS_SERVICE_SID=ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_SMS_NUMBER=+1xxxxxxxxxx

# Security
TWILIO_WEBHOOK_AUTH_TOKEN=some-long-random-string
CRON_SECRET=another-long-random-string

# App
NEXT_PUBLIC_APP_URL=https://your-domain.com
```

## Success Metrics

- **Delivery Rate**: >95% (messages delivered vs sent)
- **Reply Rate**: Track per campaign, aim for 10-30% for cold outreach
- **Opt-Out Rate**: <2% (keep under TCPA limits)
- **Latency**: <5s from send API call to Twilio delivery
- **Uptime**: 99.9% webhook availability

## Next Steps After Implementation

1. **Advanced Features**
   - MMS support (images in messages)
   - SMS templates library
   - A/B testing for campaign steps
   - Auto-responder based on keywords
   - Lead scoring based on SMS engagement

2. **Integrations**
   - Calendar booking via SMS
   - Payment links in SMS
   - Document signing triggers
   - CRM deal creation from SMS replies

3. **AI Enhancements**
   - Auto-reply suggestions
   - Sentiment analysis on replies
   - Optimal send time prediction
   - Auto-tagging based on message content

