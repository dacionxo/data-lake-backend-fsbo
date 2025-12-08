# LeadMap Project Structure & File Explanations

## 📁 Root Directory Files

### Configuration Files
- **`package.json`** - Node.js dependencies and scripts (Next.js, Supabase, Stripe, Mapbox)
- **`next.config.js`** - Next.js configuration (Mapbox image domains, build settings)
- **`tailwind.config.js`** - TailwindCSS configuration (dark mode, custom colors)
- **`tsconfig.json`** - TypeScript configuration for Next.js
- **`postcss.config.js`** - PostCSS configuration for TailwindCSS
- **`vercel.json`** - Vercel deployment configuration

### Environment & Documentation
- **`.env.local`** - Local environment variables (API keys, database URLs) - **Not in git**
- **`README.md`** - Project setup instructions and documentation
- **`QUICK_DEPLOY.md`** - Quick deployment guide
- **`SETUP_LOCAL.md`** - Local development setup guide
- **`VERCEL_ENV_SETUP.md`** - Vercel environment variables setup guide
- **`PROJECT_STRUCTURE.md`** - This file - comprehensive project structure documentation
- **`HOMEPAGE_SECTIONS_REFERENCE.txt`** - Reference for landing page sections

## 📁 App Directory (`/app`)

### Pages
- **`page.tsx`** - Landing page (server component, checks auth and Supabase config, redirects to dashboard if logged in, shows LandingPage component with error handling)
- **`layout.tsx`** - Root layout with Inter font and Providers wrapper
- **`globals.css`** - Global styles, TailwindCSS imports, custom component classes
- **`providers.tsx`** - React Context provider for user authentication and profile state

### Dashboard
- **`dashboard/page.tsx`** - Dashboard page (server component, checks auth, renders Dashboard)
- **`dashboard/components/`** - Dashboard-specific components
  - **`Header.tsx`** - Dashboard header with navigation and user info
  - **`Sidebar.tsx`** - Navigation sidebar
  - **`DashboardContent.tsx`** - Main dashboard content
  - **`DashboardLayout.tsx`** - Dashboard layout wrapper
  - **`Analytics.tsx`** - Analytics and statistics display
  - **`NextSteps.tsx`** - Next steps guidance component
- **`dashboard/leads/page.tsx`** - Leads page
- **`dashboard/leads/layout.tsx`** - Leads layout
- **`dashboard/map/page.tsx`** - Map view page
- **`dashboard/enrichment/page.tsx`** - Lead enrichment page
- **`dashboard/templates/page.tsx`** - Email templates page
- **`dashboard/settings/page.tsx`** - User settings page
- **`dashboard/docs/page.tsx`** - Documentation page
- **`dashboard/email/`** - Email marketing features
  - **`campaigns/page.tsx`** - Campaign list page
  - **`campaigns/new/page.tsx`** - Campaign creation wizard
  - **`campaigns/[id]/page.tsx`** - Campaign detail page
  - **`compose/page.tsx`** - Email composer page
  - **`mailboxes/page.tsx`** - Mailbox management page (deprecated, moved to settings)
- **`dashboard/marketing/`** - Marketing tools
  - **`page.tsx`** - Marketing dashboard with tabs
  - **`components/EmailMarketing.tsx`** - Main email marketing component with tabs (Campaigns, Unibox, Templates, Analytics)
  - **`components/UniboxWrapper.tsx`** - Unibox 3-pane layout wrapper
  - **`campaigns/[id]/page.tsx`** - Marketing campaign builder
  - **`campaigns/[id]/review/page.tsx`** - Campaign review page
- **`dashboard/unibox/`** - Unified inbox
  - **`page.tsx`** - Unibox main page
  - **`components/UniboxContent.tsx`** - 3-pane Unibox layout orchestrator
  - **`components/UniboxSidebar.tsx`** - Left sidebar (mailboxes/filters)
  - **`components/ThreadList.tsx`** - Middle pane (thread list)
  - **`components/ThreadView.tsx`** - Right pane (conversation view)
  - **`components/ReplyComposer.tsx`** - Reply/forward composer

### Pricing
- **`pricing/page.tsx`** - Pricing page (server component, renders PricingPage)

### Admin
- **`admin/page.tsx`** - Admin panel (server component, checks subscription, renders AdminPanel)

### API Routes (`/app/api`)

#### Authentication
- **`auth/callback/route.ts`** - Supabase OAuth callback handler with error handling for missing environment variables, creates user profiles with service role key

#### User Management
- **`users/create-profile/route.ts`** - Creates user profile with trial period (bypasses RLS using service role key)

#### Stripe Integration
- **`stripe/create-checkout-session/route.ts`** - Creates Stripe checkout sessions for subscriptions
- **`stripe/webhook/route.ts`** - Handles Stripe webhooks (subscription updates, payments)

#### Admin Features
- **`admin/upload-csv/route.ts`** - Handles CSV file uploads and data import to listings table (admin only)

#### AI Assistant Integration
- **`assistant/route.ts`** - OpenRouter AI API integration for AI-powered assistant responses with multiple model fallbacks
- **`assistant/test/route.ts`** - Test endpoint for assistant API

#### Lead Management
- **`leads/expired/route.ts`** - GET endpoint to fetch expired leads with filtering by source
- **`sync-leads/route.ts`** - POST endpoint to sync leads from external scrapers (FSBO integration)
- **`enrich-leads/route.ts`** - POST endpoint to enrich lead data with additional information
- **`geo-leads/route.ts`** - POST endpoint to fetch leads by geographic location

#### Probate Leads
- **`probate-leads/route.ts`** - GET: List probate leads with filtering by state; POST: Upload probate leads (CSV or JSON, admin only)

#### Email Templates
- **`email-templates/route.ts`** - GET: List all email templates; POST: Create new template (admin only)
- **`email-templates/[id]/route.ts`** - GET: Get template by ID; PUT: Update template (admin only); DELETE: Delete template (admin only)

#### Email System
- **`mailboxes/route.ts`** - GET: List user mailboxes; POST: Create/update mailbox
- **`mailboxes/[id]/route.ts`** - DELETE: Remove mailbox; PATCH: Update mailbox settings
- **`mailboxes/[id]/watch/route.ts`** - POST: Setup Gmail Watch; DELETE: Stop Watch
- **`mailboxes/oauth/gmail/route.ts`** - GET: Initiate Gmail OAuth flow
- **`mailboxes/oauth/gmail/callback/route.ts`** - GET: Handle Gmail OAuth callback
- **`mailboxes/oauth/outlook/route.ts`** - GET: Initiate Outlook OAuth flow
- **`mailboxes/oauth/outlook/callback/route.ts`** - GET: Handle Outlook OAuth callback
- **`emails/send/route.ts`** - POST: Send one-off email
- **`emails/received/route.ts`** - GET: List received emails; POST: Log received email
- **`emails/queue/route.ts`** - POST: Queue email for background processing
- **`emails/stats/route.ts`** - GET: Get email statistics
- **`email/track/open/route.ts`** - GET: Track email opens (1x1 pixel)
- **`email/track/click/route.ts`** - GET: Track email clicks and redirect
- **`email/preferences/route.ts`** - GET: Get user email preferences; PATCH: Update preferences
- **`email/analytics/timeseries/route.ts`** - GET: Get time-series email analytics
- **`email/analytics/recipient/route.ts`** - GET: Get per-recipient engagement data
- **`email/analytics/export/route.ts`** - GET: Export analytics as CSV
- **`webhooks/gmail/route.ts`** - POST: Handle Gmail Pub/Sub webhook notifications
- **`webhooks/outlook/route.ts`** - POST: Handle Outlook change notifications
- **`unibox/threads/route.ts`** - GET: List email threads; POST: Create thread
- **`unibox/threads/[id]/route.ts`** - GET: Get thread details; PATCH: Update thread
- **`unibox/threads/[id]/reply/route.ts`** - POST: Reply to thread
- **`unibox/threads/[id]/forward/route.ts`** - POST: Forward thread
- **`r/[eventId]/route.ts`** - GET: Clean URL redirect for click tracking

#### Campaign Management
- **`campaigns/route.ts`** - GET: List campaigns with stats; POST: Create campaign
- **`campaigns/[id]/route.ts`** - GET: Get campaign details; PATCH: Update campaign
- **`campaigns/[id]/pause/route.ts`** - POST: Pause campaign
- **`campaigns/[id]/resume/route.ts`** - POST: Resume campaign
- **`campaigns/[id]/cancel/route.ts`** - POST: Cancel campaign
- **`campaigns/[id]/report/route.ts`** - GET: Get campaign report/analytics

#### Background Jobs (Cron)
- **`cron/process-emails/route.ts`** - GET/POST: Process queued emails (runs every minute)
- **`cron/process-campaigns/route.ts`** - GET/POST: Process campaign sequences (runs every minute)
- **`cron/gmail-watch-renewal/route.ts`** - GET/POST: Renew Gmail Watch subscriptions (runs daily)
- **`cron/sync-mailboxes/route.ts`** - GET/POST: Sync all mailboxes (runs every 5 minutes)
- **`cron/provider-health-check/route.ts`** - GET/POST: Check provider health (runs hourly)

## 📁 Components Directory (`/components`)

### Core Components
- **`LandingPage.tsx`** - Comprehensive landing page (~1965 lines) with signup/login forms, hero section, feature showcases, animated carousel, OAuth integration, and multi-signup functionality
- **`Dashboard.tsx`** - Main dashboard with tab navigation (Table/Map views)
- **`Navigation.tsx`** - Top navigation bar with user info and logout
- **`ThemeProvider.tsx`** - Theme context provider for dark/light mode
- **`ThemeToggle.tsx`** - Theme toggle component

### Data Display
- **`LeadsTable.tsx`** - Leads table with search, filters, and pagination
- **`GoogleMapsView.tsx`** - Interactive Google Maps view with property markers and popups
- **`EmailTemplateModal.tsx`** - Modal component for creating/editing email templates

### Subscription & Admin
- **`PricingPage.tsx`** - Pricing plans and Stripe checkout integration
- **`TrialExpired.tsx`** - Trial expiration screen with upgrade prompts
- **`AdminPanel.tsx`** - Admin interface for CSV uploads and data management

### AI Chatbot Components
- **`AdvancedChatbot.tsx`** - Intelligent rule-based chatbot with pattern recognition and context awareness
- **`AdvancedChatButton.tsx`** - Floating chat button for advanced chatbot

## 📁 Library Directory (`/lib`)

### Utilities
- **`supabase.ts`** - Supabase client configuration (client and server components)
- **`supabase-client-cache.ts`** - Client caching utilities to prevent multiple client instances and reduce token refresh calls
- **`stripe.ts`** - Stripe configuration and client-side Stripe.js loader
- **`openrouter.ts`** - OpenRouter AI API client with multiple free model fallbacks
- **`assistant.ts`** - AI assistant utilities and helpers
- **`assistant-simple.ts`** - Simple assistant implementation
- **`api.ts`** - API client utilities
- **`knowledge.json`** - Knowledge base data for AI assistant

## 📁 Types Directory (`/types`)

### TypeScript Definitions
- **`index.ts`** - TypeScript interfaces (User, Listing, PricingPlan)

## 📁 Supabase Directory (`/supabase`)

### Database
- **`schema.sql`** - Complete database schema with tables, indexes, RLS policies, and sample data

## 🔧 Key Features by File

### Authentication Flow
1. **`app/page.tsx`** - Checks Supabase configuration and redirects authenticated users
2. **`LandingPage.tsx`** - User signs up/logs in with email/password or OAuth (Google/Azure)
3. **`api/auth/callback/route.ts`** - Handles OAuth callbacks and creates user profiles
4. **`api/users/create-profile/route.ts`** - Creates user profiles with trial periods
5. **`providers.tsx`** - Manages auth state and profile creation
6. **`dashboard/page.tsx`** - Redirects unauthenticated users

### Data Management
1. **`LeadsTable.tsx`** - Displays and filters property leads
2. **`GoogleMapsView.tsx`** - Shows leads on interactive Google Maps
3. **`AdminPanel.tsx`** - Allows CSV uploads for bulk data
4. **`api/sync-leads/route.ts`** - Syncs leads from external scrapers
5. **`api/enrich-leads/route.ts`** - Enriches lead data
6. **`api/geo-leads/route.ts`** - Fetches leads by geographic location
7. **`api/probate-leads/route.ts`** - Manages probate leads

### Subscription System
1. **`PricingPage.tsx`** - Shows pricing plans
2. **`api/stripe/create-checkout-session`** - Creates payment sessions
3. **`api/stripe/webhook`** - Updates subscription status
4. **`TrialExpired.tsx`** - Displays trial expiration screen

### Database Operations
1. **`supabase/schema.sql`** - Defines database structure
2. **`providers.tsx`** - Fetches user profiles
3. **`Dashboard.tsx`** - Fetches property listings
4. **`api/admin/upload-csv/route.ts`** - Bulk data import

### Email Management
1. **`api/email-templates/route.ts`** - CRUD operations for email templates
2. **`api/email-templates/[id]/route.ts`** - Individual template operations
3. **`EmailTemplateModal.tsx`** - Template editor component
4. **`api/mailboxes/route.ts`** - Mailbox management (Gmail, Outlook, SMTP)
5. **`api/emails/send/route.ts`** - Send one-off emails
6. **`api/campaigns/route.ts`** - Campaign creation and management
7. **`api/cron/process-emails/route.ts`** - Background email processor
8. **`api/unibox/threads/route.ts`** - Unified inbox thread management
9. **`api/email/analytics/timeseries/route.ts`** - Email analytics time-series data
10. **`dashboard/marketing/components/EmailMarketing.tsx`** - Email marketing dashboard
11. **`dashboard/unibox/`** - Unified inbox UI (3-pane layout)

## 🚀 Deployment Flow

1. **Environment Setup** - Copy `env.example` to `.env.local`
2. **Database Setup** - Run `schema.sql` in Supabase
3. **Stripe Setup** - Configure products and webhooks
4. **Deploy** - Push to GitHub, connect to Vercel

## 📊 File Size & Complexity

### Largest Files (by functionality)
- **`LandingPage.tsx`** (~1,965 lines) - Comprehensive landing page with animations, carousel, OAuth, and feature showcases
- **`AdvancedChatbot.tsx`** (~400+ lines) - Intelligent chatbot with pattern recognition
- **`LeadsTable.tsx`** (~272+ lines) - Data table with filters and pagination
- **`GoogleMapsView.tsx`** (~246+ lines) - Complex Google Maps integration
- **`AdminPanel.tsx`** (~229+ lines) - CSV upload interface
- **`Header.tsx`** (~144 lines) - Dashboard header component

### Most Critical Files
- **`app/page.tsx`** - Entry point with error handling and Supabase configuration checks
- **`api/auth/callback/route.ts`** - OAuth callback with robust error handling
- **`api/users/create-profile/route.ts`** - User profile creation with service role key
- **`providers.tsx`** - Authentication state management
- **`supabase/schema.sql`** - Database structure and data
- **`Dashboard.tsx`** - Main application interface
- **`api/stripe/webhook`** - Payment processing
- **`AdvancedChatbot.tsx`** - AI assistant with real estate expertise
- **`api/assistant/route.ts`** - OpenRouter AI integration with multiple model fallbacks

## 🔄 Data Flow

1. **User visits site** → `app/page.tsx` → Checks Supabase config → Shows `LandingPage.tsx`
2. **User signs up/logs in** → `LandingPage.tsx` → Supabase Auth
3. **OAuth callback** → `api/auth/callback/route.ts` → Creates profile (if needed) → Redirects to dashboard
4. **Email signup** → `LandingPage.tsx` → `api/users/create-profile/route.ts` → Creates profile → Redirects to dashboard
5. **Profile state** → `providers.tsx` → Manages auth state → `users` table
6. **Dashboard loads** → `Dashboard.tsx` → Fetches listings → Displays in table or map
7. **Data displayed** → `LeadsTable.tsx` or `GoogleMapsView.tsx`
8. **Admin uploads** → `AdminPanel.tsx` → `api/admin/upload-csv/route.ts` → `listings` table
9. **Lead sync** → External scraper → `api/sync-leads/route.ts` → Updates `listings` table
10. **Lead enrichment** → `api/enrich-leads/route.ts` → Enhances lead data
11. **AI Assistant** → `AdvancedChatbot.tsx` → `api/assistant/route.ts` → OpenRouter API (with multiple model fallbacks)

## 🤖 AI Assistant Integration

### AI Assistant Architecture
1. **OpenRouter Integration** - Uses OpenRouter API with multiple free model fallbacks
2. **Advanced Chatbot** - Intelligent rule-based responses with pattern recognition and context awareness
3. **Multiple Model Fallbacks** - Automatically tries different models if one fails

### Assistant Features
- **Property Analysis** - Detailed research frameworks and valuation
- **Market Intelligence** - Local market trends and opportunities
- **Lead Generation** - FSBO strategies and distressed property identification
- **Investment Strategies** - Buy & hold, fix & flip, wholesale, BRRRR methods
- **Deal Structuring** - Creative financing and negotiation tactics
- **Location-Specific** - Market knowledge and insights
- **Context Awareness** - Address recognition and specialized knowledge

### Assistant Data Flow
1. **User asks question** → `AdvancedChatbot.tsx` → Pattern recognition
2. **AI Response** → `api/assistant/route.ts` → `lib/openrouter.ts` → OpenRouter API (tries multiple free models)
3. **Fallback Response** → Rule-based responses when API unavailable or models fail
4. **Context Awareness** → Address recognition and specialized knowledge from `lib/knowledge.json`

## 🛡️ Error Handling & Configuration

### Error Handling Improvements
- **`app/page.tsx`** - Checks for Supabase environment variables before initializing client
- **`api/auth/callback/route.ts`** - Handles missing environment variables gracefully, won't crash if service role key is missing
- **`api/users/create-profile/route.ts`** - Validates environment variables and provides helpful error messages
- All API routes include try-catch blocks and proper error responses

### Configuration Requirements
- **Required**: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- **For Payments**: Stripe keys and price IDs
- **For Maps**: `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`
- **For AI**: `OPENROUTER_API_KEY` (optional, uses free models as fallback)
- **App URL**: `NEXT_PUBLIC_APP_URL` (defaults to localhost:3000)

### Database Tables
- **`users`** - User profiles, subscriptions, trial periods
- **`listings`** - Property leads with address, price, status
- **`probate_leads`** - Probate case leads
- **`email_templates`** - Email template storage

---
*This structure supports a full-featured SaaS application with robust error handling, authentication, payments, data management, interactive mapping, and AI-powered assistant with OpenRouter integration.*
