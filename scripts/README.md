# LeadMap - Real Estate Lead Generation Platform

A modern, AI-powered SaaS platform for real estate agents and brokers to discover undervalued property leads with interactive maps, advanced filtering, and intelligent data enrichment.

## ✨ Features

- 🏠 **Property Lead Discovery** - Find undervalued properties with price drop alerts
- 🗺️ **Interactive Maps** - Visualize leads on Google Maps with color-coded markers
- 📊 **Advanced Filtering** - Filter by type (All, Expired, Probate, Geo, Enriched)
- 🤖 **AI-Powered Enrichment** - Skip tracing and data enrichment with confidence scores
- 📧 **Email Templates** - Pre-built templates with AI-powered rewriting
- 💳 **Stripe Integration** - Secure subscription management with 7-day free trial
- 📱 **Responsive Design** - Works perfectly on desktop and mobile
- 🔐 **Secure Authentication** - Supabase-powered auth with OAuth (Google & Microsoft)
- 🌙 **Dark Mode** - Beautiful dark theme support
- 📈 **Admin Panel** - CSV upload, email templates, and probate lead management
- ⚡ **Real-time Updates** - Live data synchronization

## 🛠️ Tech Stack

- **Frontend**: Next.js 16, React, TypeScript, TailwindCSS
- **Backend**: Supabase (PostgreSQL, Auth, API)
- **Payments**: Stripe
- **Maps**: Google Maps API
- **AI**: Ollama integration for assistant features
- **Deployment**: Vercel

## Quick Start

### 1. Clone and Install

```bash
git clone <your-repo-url>
cd LeadMap
npm install
```

### 2. Environment Setup

Create a `.env.local` file with the following variables:

```env
# Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# Stripe Configuration
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret

# Mapbox API (Recommended)
NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN=your_mapbox_access_token

# Google Maps API (Alternative)
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_api_key

# Google Street View API (for property detail modals)
NEXT_PUBLIC_GOOGLE_STREET_VIEW_API_KEY=your_google_street_view_api_key

# App Configuration
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Stripe Price IDs
NEXT_PUBLIC_STRIPE_STARTER_PRICE_ID=price_starter_monthly
NEXT_PUBLIC_STRIPE_PRO_PRICE_ID=price_pro_monthly
STRIPE_STARTER_PRICE_ID=price_starter_monthly
STRIPE_PRO_PRICE_ID=price_pro_monthly

# Email Provider Configuration (for transactional emails)
# Choose one or more providers. The system will use the first available provider in order.

# Resend (Recommended for Next.js)
RESEND_API_KEY=re_xxxxxxxxxxxxx
RESEND_FROM_EMAIL=noreply@yourdomain.com
RESEND_SANDBOX_DOMAIN=sandbox.yourdomain.com  # Optional: for test mode

# SendGrid (Alternative)
SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
SENDGRID_FROM_EMAIL=noreply@yourdomain.com
SENDGRID_SANDBOX_MODE=false  # Set to true for test mode

# Mailgun (Alternative)
MAILGUN_API_KEY=xxxxxxxxxxxxx
MAILGUN_DOMAIN=yourdomain.com
MAILGUN_SANDBOX_DOMAIN=sandbox.yourdomain.com  # Optional: for test mode

# AWS SES (Alternative)
AWS_SES_REGION=us-east-1
AWS_SES_ACCESS_KEY_ID=your_access_key
AWS_SES_SECRET_ACCESS_KEY=your_secret_key
AWS_SES_FROM_EMAIL=noreply@yourdomain.com
AWS_SES_CONFIGURATION_SET=your_config_set  # Optional: for tracking

# SMTP (Generic)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_FROM_EMAIL=noreply@yourdomain.com
SMTP_SECURE=true  # Use TLS/SSL

# Generic Email Service API (Alternative)
EMAIL_SERVICE_URL=https://api.example.com/send
EMAIL_SERVICE_API_KEY=your_api_key
EMAIL_FROM=noreply@yourdomain.com

# Email Settings & Policies
EMAIL_DEFAULT_FROM_NAME=Your Company Name
EMAIL_DEFAULT_REPLY_TO=support@yourdomain.com
EMAIL_DEFAULT_FOOTER=<p>© 2024 Your Company. All rights reserved.</p>

# Email Environment Policy
EMAIL_ALLOW_SEND_IN_DEV=false  # Set to true to allow sending in development
EMAIL_SANDBOX_MODE=false  # Set to true to enable sandbox/test mode globally
EMAIL_TRACKING_DOMAIN=track.yourdomain.com  # Optional: for click/open tracking

# Email Provider Health Checks
EMAIL_HEALTH_CHECK_ENABLED=true  # Enable automatic health checks
EMAIL_HEALTH_CHECK_INTERVAL=3600  # Check every hour (in seconds)
```

### 3. Database Setup

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Run the SQL schema from `supabase/schema.sql` in your Supabase SQL editor
3. This will create the necessary tables and sample data

### 4. Stripe Setup

1. Create a [Stripe account](https://stripe.com)
2. Create two products in Stripe Dashboard:
   - **Starter Plan**: $49/month
   - **Pro Plan**: $99/month
3. Copy the Price IDs to your environment variables

### 5. Mapbox Setup (Recommended)

1. Go to [mapbox.com](https://mapbox.com) and create a free account
2. Go to your [Account page](https://account.mapbox.com/access-tokens/)
3. Create a new access token or use the default public token
4. Add the token to your environment variables

**Alternative: Google Maps Setup**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Enable Maps JavaScript API
3. Create an API key and restrict it to your domain

### 6. OAuth Setup (Google & Microsoft)

For OAuth authentication with Google and Microsoft, see the detailed guide:
- **[OAuth Setup Guide](./OAUTH_SETUP_GUIDE.md)** - Complete step-by-step instructions

Quick summary:
1. Create OAuth apps in Google Cloud Console and Azure Portal
2. Configure credentials in Supabase Dashboard > Authentication > Providers
3. Set up redirect URLs

### 7. Run Development Server

```bash
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000) to see your app!

## 📚 Documentation

- **[SETUP.md](./SETUP.md)** - Complete setup guide for Google Maps, OAuth, and GitHub
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Detailed deployment guide for Vercel
- **[PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md)** - Detailed file structure and explanations
- **[CHANGELOG.md](./CHANGELOG.md)** - Complete development history and feature timeline

## 🚀 Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment instructions.

### Quick Deploy to Vercel

1. Push your code to GitHub
2. Connect your repository to Vercel
3. Add all environment variables in Vercel dashboard
4. Deploy!

### Configure Stripe Webhook

1. In Stripe Dashboard, go to Webhooks
2. Add endpoint: `https://your-domain.vercel.app/api/stripe/webhook`
3. Select events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`
4. Copy the webhook secret to your environment variables

## Project Structure

```
LeadMap/
├── app/                    # Next.js App Router
│   ├── api/               # API routes
│   │   ├── auth/          # Authentication callbacks
│   │   ├── stripe/        # Stripe integration
│   │   ├── admin/         # Admin CSV upload
│   │   ├── campaigns/     # Campaign management APIs
│   │   ├── emails/        # Email sending & tracking
│   │   ├── mailboxes/     # Mailbox management
│   │   └── cron/          # Background job processors
│   ├── dashboard/         # Main dashboard
│   │   ├── email/         # Email features
│   │   │   ├── campaigns/ # Campaign pages (list, detail, create)
│   │   │   ├── compose/    # Email composer
│   │   │   └── mailboxes/ # Mailbox management
│   │   ├── marketing/     # Marketing tools
│   │   │   └── campaigns/ # Marketing campaign pages
│   │   └── crm/           # CRM features
│   ├── pricing/           # Pricing page
│   └── admin/             # Admin panel
├── components/            # React components
│   ├── Dashboard.tsx      # Main dashboard component
│   ├── LeadsTable.tsx     # Leads table with filters
│   ├── MapView.tsx        # Google Maps integration
│   ├── PricingPage.tsx    # Subscription plans
│   └── AdminPanel.tsx     # CSV upload interface
├── lib/                   # Utilities
│   ├── supabase.ts        # Supabase client
│   ├── stripe.ts          # Stripe configuration
│   ├── email/             # Email system
│   │   ├── providers/     # Email provider abstractions
│   │   └── campaigns/     # Campaign utilities (dedupe, warmup, throttle)
│   └── api.ts             # API client functions
├── types/                 # TypeScript definitions
└── supabase/              # Database schema
    ├── campaigns_complete_schema.sql  # Campaigns & sequences
    ├── email_settings_schema.sql      # Email settings
    ├── email_provider_credentials_schema.sql  # Provider credentials
    └── email_tracking_schema.sql      # Open/click tracking
```

## 📧 Email Marketing System - End-to-End Workflow

### Complete Email Flow: Connect → Compose → Send → Track

The email marketing system provides a complete workflow for managing email campaigns, from connecting mailboxes to tracking performance.

#### Step 1: Connect Mailbox
1. Navigate to **Settings → Email Accounts** (or **Email → Email Accounts** in sidebar)
2. Click **"Connect Mailbox"**
3. Choose your provider:
   - **Gmail**: OAuth connection (requires Google Cloud Console setup)
   - **Outlook**: OAuth connection (requires Azure AD setup)
   - **SMTP/IMAP**: Manual configuration for custom email servers
4. Complete OAuth flow or enter SMTP credentials
5. Mailbox is now connected and ready to use

#### Step 2: Compose Email
1. Navigate to **Email → Compose** in sidebar
2. Select your connected mailbox
3. Enter recipient email address
4. (Optional) Select a template from the dropdown
5. Enter subject and HTML content
6. (Optional) Schedule for later
7. Click **"Send Now"** or **"Schedule"**

#### Step 3: Create Campaign
1. Navigate to **Email → Campaigns** in sidebar
2. Click **"Create Campaign"** or **"New"**
3. **Campaign Wizard Steps**:
   - **Basics**: Name, description, mailbox selection
   - **Steps**: Define email sequence (single or multi-step)
     - For sequences: Set delay hours between steps
     - Enable "Stop on Reply" to pause sequence when recipient responds
   - **Recipients**: Add recipients manually or import CSV
   - **Review**: Confirm settings and recipient count
4. Click **"Create Campaign"**
5. Campaign is created in "draft" status

#### Step 4: Send Campaign
1. From campaign list, click on your campaign
2. Review campaign details and recipient list
3. Click **"Start Campaign"** or **"Send"**
4. **Safety Rails**: If sending to 100+ recipients, confirmation modal appears:
   - "You're about to email X recipients. Are you sure?"
5. Campaign status changes to "running"
6. Background processor sends emails respecting rate limits

#### Step 5: Track Performance
1. Navigate to **Email → Analytics** in sidebar
2. View **KPI Cards**:
   - Total sent
   - Open rate
   - Click rate
   - Reply rate
   - Opportunities
3. View **Time-Series Graph**:
   - Toggle metrics on/off via legend
   - See trends over time
4. Filter by date range and mailbox
5. Export data as CSV if needed

#### Step 6: Manage Templates
1. Navigate to **Email → Templates** in sidebar
2. **Create Template**:
   - Click **"New"**
   - Enter name, subject, and HTML content
   - Use **"Rewrite with AI"** button to improve content
   - Save template
3. **Use Template in Campaign**:
   - Click **"Use in Campaign"** button (Send icon) next to template
   - Automatically opens campaign wizard with template pre-filled
4. **Edit Template**:
   - Click template name or edit icon
   - Modify content
   - Use **"Rewrite with AI"** for improvements
   - Save changes

#### Step 7: Unified Inbox (Unibox)
1. Navigate to **Email → Unibox** in sidebar
2. **3-Pane Layout**:
   - **Left Sidebar**: Mailbox selection and filters
   - **Middle Pane**: Thread list with unread counts
   - **Right Pane**: Full conversation view
3. **Features**:
   - View all emails (sent and received) in threaded conversations
   - Reply and forward directly from Unibox
   - Link emails to CRM contacts/listings
   - Search and filter threads
4. Real-time updates via Gmail Watch (for Gmail mailboxes)

### Email System Features

#### Mailbox Management
- **OAuth Integration**: Gmail and Outlook OAuth flows
- **SMTP/IMAP Support**: Generic email server support
- **Token Encryption**: Secure storage of OAuth tokens
- **Rate Limiting**: Per-mailbox daily/hourly limits
- **Health Monitoring**: Automatic health checks

#### Campaign System
- **Single & Sequence Campaigns**: One-time sends or multi-step drips
- **Template Integration**: Use templates in campaigns
- **Recipient Management**: Manual entry or CSV import
- **Safety Rails**: Confirmation for bulk sends (100+ recipients)
- **Reply Detection**: Automatically stop sequences on reply
- **Background Processing**: Cron job processes queued emails

#### Analytics & Tracking
- **Open Tracking**: 1x1 pixel tracking
- **Click Tracking**: Link click tracking with clean URLs
- **Time-Series Analytics**: Daily/weekly/monthly aggregations
- **Per-Recipient Profiles**: Individual engagement tracking
- **Export**: CSV export of analytics data

#### AI Integration
- **Content AI**: Generate subject lines in campaign builder
- **Rewrite with AI**: Improve template content
- **Assistant Integration**: Uses OpenRouter API with fallbacks

## Features Overview

### Authentication & Trial Management
- Email/password signup and login
- 7-day free trial on signup
- Automatic trial expiration handling
- Secure session management

### Dashboard
- **Leads Table**: Sortable, filterable table with search
- **Map View**: Interactive Google Maps with property markers
- **Real-time Data**: Live updates from Supabase
- **Responsive Design**: Works on all devices

### Subscription Management
- **Free Trial**: 7 days, no credit card required
- **Starter Plan**: $49/month, 50 leads/month
- **Pro Plan**: $99/month, unlimited leads
- **Stripe Integration**: Secure payment processing

### Admin Features
- **CSV Upload**: Bulk import property leads
- **Data Management**: View and manage all listings
- **Template Download**: CSV format guidance

## 🔌 API Endpoints

### Core Endpoints
- `POST /api/stripe/create-checkout-session` - Create Stripe checkout
- `POST /api/stripe/webhook` - Handle Stripe webhooks
- `POST /api/admin/upload-csv` - Upload CSV files
- `GET /api/auth/callback` - OAuth callback handler

### Lead Management
- `POST /api/sync-leads` - Sync FSBO leads (with expiration tracking)
- `GET /api/leads/expired` - Get expired leads
- `POST /api/geo-leads` - Fetch geo leads from Google Places
- `POST /api/enrich-leads` - Enrich lead data with skip tracing

### Email & Templates
- `GET /api/email-templates` - List all email templates
- `POST /api/email-templates` - Create template (admin only)
- `GET /api/email-templates/[id]` - Get template by ID
- `PUT /api/email-templates/[id]` - Update template (admin only)
- `DELETE /api/email-templates/[id]` - Delete template (admin only)
- `POST /api/emails/send` - Send email via mailbox (transactional or campaign)
- `POST /api/emails/queue` - Queue email for background processing
- `GET /api/emails/settings` - Get email settings (from name, reply-to, footer)
- `PUT /api/emails/settings` - Update email settings
- `GET /api/mailboxes/[id]/health` - Check mailbox connection health

### Campaigns & Sequences
- `GET /api/campaigns` - List all campaigns
- `POST /api/campaigns` - Create new campaign
- `GET /api/campaigns/[id]` - Get campaign details
- `PATCH /api/campaigns/[id]` - Update campaign
- `POST /api/campaigns/[id]/pause` - Pause a running campaign
- `POST /api/campaigns/[id]/resume` - Resume a paused campaign
- `GET /api/campaigns/[id]/report` - Get campaign statistics and reports

### Probate Leads
- `GET /api/probate-leads` - List probate leads (filterable by state)
- `POST /api/probate-leads` - Upload probate leads (admin only)

### AI Assistant
- `POST /api/assistant` - AI assistant powered by Ollama

## Database Schema

### Users Table
- `id` - UUID (Primary Key)
- `email` - User email
- `name` - User name
- `trial_end` - Trial expiration date
- `is_subscribed` - Subscription status
- `plan_tier` - free/starter/pro
- `stripe_customer_id` - Stripe customer ID
- `stripe_subscription_id` - Stripe subscription ID

### Listings Table
- `id` - UUID (Primary Key)
- `address` - Property address
- `city` - City name
- `state` - State abbreviation
- `zip` - ZIP code
- `price` - Property price
- `price_drop_percent` - Price drop percentage
- `days_on_market` - Days on market
- `url` - Source URL
- `latitude` - Latitude (optional)
- `longitude` - Longitude (optional)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.

## 📖 Additional Resources

- **Setup Guides**: See [SETUP.md](./SETUP.md) for Google Maps, OAuth, and GitHub setup
- **Development History**: See [CHANGELOG.md](./CHANGELOG.md) for complete feature timeline
- **Project Structure**: See [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) for detailed file explanations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 💬 Support

For support, email support@leadmap.com or create an issue in the repository. 
