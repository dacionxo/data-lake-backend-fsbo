# NextDeal Data Lake Architecture

Complete architecture diagram showing data flow from Redfin scraping to LeadMap-main user interface.

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           EXTERNAL DATA SOURCES                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                     │
│  │   Redfin     │  │  CSV Files   │  │  Apollo.io   │                     │
│  │   Website    │  │              │  │     API      │                     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘                     │
│         │                 │                  │                              │
└─────────┼─────────────────┼──────────────────┼──────────────────────────────┘
          │                 │                  │
          ▼                 ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DATA-LAKE-BACKEND                                        │
│              (Ingestion & Enrichment Layer)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                    INGESTION PIPELINES                      │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  ┌──────────────────┐    ┌──────────────────┐            │          │
│  │  │  Redfin Scraper  │    │   CSV Importer   │            │          │
│  │  │   (FSBO.py)      │    │                  │            │          │
│  │  │                  │    │                  │            │          │
│  │  │ • Sitemap Parse  │    │ • File Upload    │            │          │
│  │  │ • Page Scrape    │    │ • Parse CSV      │            │          │
│  │  │ • AWS IP Rotate  │    │ • Validate       │            │          │
│  │  └────────┬─────────┘    └────────┬─────────┘            │          │
│  │           │                       │                       │          │
│  └───────────┼───────────────────────┼───────────────────────┘          │
│              │                       │                                   │
│              ▼                       ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                      RAW ZONE                                │          │
│  │              (Unprocessed Data Storage)                      │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  • raw_redfin_responses  • raw_csv_imports                 │          │
│  │  • raw_apollo_imports                                     │          │
│  │                                                             │          │
│  │  [Stores raw JSON responses, unvalidated data]             │          │
│  └───────────────────────┬─────────────────────────────────────┘          │
│                          │                                                 │
│                          ▼                                                 │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                  ENRICHMENT PIPELINES                       │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  ┌──────────────────┐    ┌──────────────────┐            │          │
│  │  │  Skip Tracing    │    │   Geocoding      │            │          │
│  │  │  (Enrichment.py) │    │   (backfill-     │            │          │
│  │  │                  │    │    geocodes.ts)  │            │          │
│  │  │ • Contact Lookup │    │                  │            │          │
│  │  │ • Phone/Email    │    │ • Address → Lat  │            │          │
│  │  │ • Owner Info     │    │ • Address → Lng  │            │          │
│  │  └────────┬─────────┘    └────────┬─────────┘            │          │
│  │           │                       │                       │          │
│  └───────────┼───────────────────────┼───────────────────────┘          │
│              │                       │                                   │
│              ▼                       ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                     STAGING ZONE                             │          │
│  │            (Normalized & Partially Processed)                │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  • fsbo_raw          • import_staging                       │          │
│  │                                                             │          │
│  │  [Normalized data, validated structure]                     │          │
│  └───────────────────────┬─────────────────────────────────────┘          │
│                          │                                                 │
│                          ▼                                                 │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                   VALIDATION & QUALITY                       │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  • Data Validation    • Quality Checks                      │          │
│  │  • Deduplication      • Business Rules                      │          │
│  │                                                             │          │
│  └───────────────────────┬─────────────────────────────────────┘          │
│                          │                                                 │
└──────────────────────────┼─────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SUPABASE DATABASE                                  │
│                    (PostgreSQL + Real-time + Auth)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                     CURATED ZONE                             │          │
│  │              (Production-Ready Data)                         │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  PROPERTY TABLES (listing_id = TEXT PK)                    │          │
│  │  • listings              • fsbo_leads                      │          │
│  │  • expired_listings      • frbo_leads                      │          │
│  │  • foreclosure_listings  • imports                         │          │
│  │                                                             │          │
│  │  USER ENTITIES (id = UUID PK)                              │          │
│  │  • contacts              • deals                           │          │
│  │  • tasks                 • lists                           │          │
│  │  • list_items                                             │          │
│  │                                                             │          │
│  │  PIPELINE TRACKING                                         │          │
│  │  • pipelines             • pipeline_runs                   │          │
│  │  • pipeline_run_events   • zone_transitions                │          │
│  │                                                             │          │
│  │  FEATURE FLAGS                                             │          │
│  │  • feature_flags (toggle pipelines/behaviors)              │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                  SUPABASE EDGE FUNCTIONS                     │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  • geocode-new-listings (serverless geocoding)             │          │
│  │  • webhook-handlers (external integrations)                │          │
│  │                                                             │          │
│  └───────────────────────┬─────────────────────────────────────┘          │
│                          │                                                 │
└──────────────────────────┼─────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         LEADMAP-MAIN                                         │
│                   (UX, CRM, Cron, Auth Layer)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                   NEXT.JS APPLICATION                        │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  ┌──────────────────┐    ┌──────────────────┐            │          │
│  │  │   API ROUTES     │    │   PAGES/UI       │            │          │
│  │  │                  │    │                  │            │          │
│  │  │ • /api/listings  │    │ • Dashboard      │            │          │
│  │  │ • /api/contacts  │    │ • Prospects      │            │          │
│  │  │ • /api/deals     │    │ • CRM            │            │          │
│  │  │ • /api/tasks     │    │ • Settings       │            │          │
│  │  └────────┬─────────┘    └────────┬─────────┘            │          │
│  │           │                       │                       │          │
│  └───────────┼───────────────────────┼───────────────────────┘          │
│              │                       │                                   │
│              ▼                       ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                   CRON TRIGGERS                              │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  • Trigger pipelines via API/webhook                        │          │
│  │  • Scheduled data refresh                                   │          │
│  │  • Background job execution                                 │          │
│  │                                                             │          │
│  └───────────────────────┬─────────────────────────────────────┘          │
│                          │                                                 │
│                          ▼                                                 │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                  AUTHENTICATION                              │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  • User Registration    • Login                            │          │
│  │  • Session Management   • RBAC                             │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              END USERS                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  • Real Estate Agents    • Investors     • Property Managers              │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────┐          │
│  │                    USER INTERFACE                            │          │
│  ├─────────────────────────────────────────────────────────────┤          │
│  │                                                             │          │
│  │  • View Listings       • Manage Contacts                   │          │
│  │  • Track Deals         • Create Tasks                      │          │
│  │  • Email Campaigns     • Analytics Dashboard               │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Summary

### 1. Data Ingestion (Data-Lake-Backend)
- **Source:** Redfin, CSV files, Apollo.io
- **Process:** Scraping, parsing, validation
- **Storage:** RAW ZONE tables

### 2. Data Enrichment (Data-Lake-Backend)
- **Process:** Skip tracing, geocoding, normalization
- **Storage:** STAGING ZONE tables

### 3. Data Validation (Data-Lake-Backend)
- **Process:** Quality checks, deduplication, business rules
- **Storage:** CURATED ZONE tables

### 4. Data Consumption (LeadMap-main)
- **Read:** CURATED ZONE tables only
- **Display:** User interfaces and dashboards
- **Manage:** User-specific CRM data

### 5. Pipeline Triggers (LeadMap-main)
- **Schedule:** Cron jobs trigger Data-Lake-Backend pipelines
- **Monitor:** Pipeline run status and results

## Key Components

### Pipeline Orchestration
- **Tracking:** `pipeline_runs`, `pipeline_run_events`
- **Configuration:** `config/pipeline-config.yaml`
- **Feature Flags:** `feature_flags` table

### Data Zones
- **RAW:** Unprocessed external data
- **STAGING:** Normalized, partially processed
- **CURATED:** Production-ready, validated

### ID Strategy
- **Properties:** `listing_id` (TEXT) - canonical business ID
- **User Entities:** `id` (UUID) - technical ID

### Shared Configuration
- **Files:** `config/pipeline-config.{yaml,json,ts}`
- **Environment:** `.env` variables
- **Feature Flags:** Supabase `feature_flags` table

## Technology Stack

### Data-Lake-Backend
- Python 3.10+
- Supabase Python Client
- AWS API Gateway (IP rotation)
- BeautifulSoup, Playwright (scraping)

### LeadMap-main
- Next.js 14+
- TypeScript
- Supabase JS Client
- React/UI Libraries
- Vercel (hosting)

### Shared Infrastructure
- Supabase (PostgreSQL, Auth, Real-time, Edge Functions)
- AWS (IP rotation, infrastructure)

## Related Documentation

- [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) - Detailed responsibilities
- [SYNC_GUIDE.md](./SYNC_GUIDE.md) - Schema synchronization
- [canonical_id_strategy.sql](../scripts/supabase/canonical_id_strategy.sql) - ID strategy
