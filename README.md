# Data Lake Backend

A comprehensive backend system for real estate lead data collection, enrichment, and storage. This repository contains all the tools, scripts, and schemas needed to scrape, process, and store real estate leads in Supabase.

## 📁 Repository Structure

```
Data Lake Backend/
├── scripts/
│   ├── redfin-scraper/          # Redfin FSBO lead scraper
│   │   ├── FSBO.py              # Main scraper script
│   │   ├── Enrichment.py        # Skip tracing and data enrichment
│   │   ├── supabase_client.py   # Supabase integration
│   │   ├── orchestrator.py      # Job orchestration
│   │   └── worker.py            # Worker processes
│   ├── backfill-geocodes.ts     # Geocoding backfill script
│   ├── sync-supabase-schemas.ps1 # Schema sync script (PowerShell)
│   ├── sync-supabase-schemas.py  # Schema sync script (Python)
│   ├── create_user.py           # User creation scripts
│   ├── create_user.js
│   ├── create_user_simple.js
│   ├── seed-test-data.sql       # Test data seeding
│   └── README-GEOCODING.md      # Geocoding documentation
├── supabase/
│   ├── schema.sql               # Main database schema
│   ├── complete_schema.sql      # Complete schema
│   ├── functions/               # Supabase Edge Functions
│   └── migrations/              # Database migrations
└── docs/                        # All documentation and guides
```

## 🚀 Features

### 1. Redfin Scraper
- **FSBO Lead Scraping**: Automated scraping of For Sale By Owner listings from Redfin
- **IP Rotation**: AWS API Gateway integration for robust scraping
- **Data Enrichment**: Skip tracing and contact information enrichment
- **Supabase Integration**: Direct database insertion

### 2. Geocoding System
- **Free-First Approach**: Uses Nominatim (OpenStreetMap) as primary geocoder
- **Fallback Options**: Mapbox (free tier) and Google Maps (paid fallback)
- **Batch Processing**: Efficient backfill of missing coordinates

### 3. Supabase Schema
- **Complete Database Schema**: All tables, views, and functions
- **Migrations**: Version-controlled database changes
- **Edge Functions**: Serverless functions for geocoding

## 📋 Prerequisites

- Python 3.10+ (for Redfin scraper)
- Node.js 18+ (for TypeScript scripts)
- Supabase account and project
- AWS account (optional, for IP rotation)

## 🛠️ Setup

### 1. Environment Variables

Create a `.env` file in the root directory:

```env
# Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Geocoding (Optional)
NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN=your_mapbox_token
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_key

# AWS (Optional, for IP rotation)
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
```

### 2. Install Dependencies

#### Python Dependencies (Redfin Scraper)
```bash
cd scripts/redfin-scraper
pip install -r requirements.txt
```

#### Node.js Dependencies (Geocoding Scripts)
```bash
npm install
```

### 3. Database Setup

Run the Supabase schema files in order:
1. `supabase/schema.sql` - Base schema
2. `supabase/complete_schema.sql` - Complete schema with all features
3. Run any migrations in `supabase/migrations/`

## 📖 Usage

### Redfin Scraper

```bash
cd scripts/redfin-scraper
python FSBO.py
```

The scraper will:
1. Fetch listing URLs from Redfin sitemaps
2. Scrape property details from each listing
3. Enrich data with skip tracing
4. Save to CSV and/or Supabase

### Geocoding Backfill

```bash
npx tsx scripts/backfill-geocodes.ts
```

This script will:
1. Find all records with missing coordinates
2. Geocode addresses using free services first
3. Fall back to paid services only if needed
4. Update records in Supabase

### User Creation

```bash
# Python version
python scripts/create_user.py

# Node.js version
node scripts/create_user.js
```

## 🔄 Schema Synchronization

**IMPORTANT**: The Supabase schema files must stay synchronized between this repository and LeadMap-main. Use the sync scripts to keep them in sync:

```powershell
# Sync both directions
.\scripts\sync-supabase-schemas.ps1

# Preview changes (dry run)
.\scripts\sync-supabase-schemas.ps1 -WhatIf
```

See [SYNC_GUIDE.md](docs/SYNC_GUIDE.md) for detailed instructions.

## 📚 Documentation

All documentation files are in the `docs/` directory. Key documents include:

- **SYNC_GUIDE.md** - Schema synchronization guide ⭐
- **PROJECT_STRUCTURE.md** - Overview of the entire system
- **SETUP.md** - Detailed setup instructions
- **README-GEOCODING.md** - Geocoding system documentation
- **PHASE_0_SETUP_GUIDE.md** - Initial setup checklist

## 🔧 Scripts Overview

### Data Collection
- `redfin-scraper/FSBO.py` - Main Redfin scraper
- `redfin-scraper/Enrichment.py` - Data enrichment engine

### Data Processing
- `backfill-geocodes.ts` - Geocode missing addresses
- `create_user.py/js` - User management scripts

### Database
- `seed-test-data.sql` - Test data for development
- All schema files in `supabase/`

## 🗄️ Database Schema

The Supabase schema includes:
- **Listings Tables**: `listings`, `expired_listings`, `fsbo_leads`, etc.
- **User Management**: Authentication and user profiles
- **Email System**: Campaigns, templates, tracking
- **CRM Features**: Deals, contacts, lists
- **Calendar Integration**: Google Calendar sync

See `supabase/complete_schema.sql` for the full schema.

## 🔐 Security Notes

- Never commit `.env` files
- Use service role keys only in server-side scripts
- Rotate API keys regularly
- Follow rate limits for all APIs

## 📝 License

[Add your license here]

## 🤝 Contributing

[Add contribution guidelines here]

## 📞 Support

[Add support contact information here]
