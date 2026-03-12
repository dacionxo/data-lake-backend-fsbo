# Project Structure & Separation of Responsibilities

This document outlines the architecture and responsibilities of the NextDeal data lake ecosystem, which consists of two main repositories: **Data-Lake-Backend** and **LeadMap-main**.

## 🏗️ Architecture Overview

The system is split into two complementary repositories with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    Data-Lake-Backend                        │
│  • Data Ingestion & ETL                                     │
│  • Schema & Data Quality                                    │
│  • Pipeline Orchestration                                   │
└─────────────────────────────────────────────────────────────┘
                           ↓
                   ┌───────────────┐
                   │   Supabase    │
                   │   (Database)  │
                   └───────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                     LeadMap-main                            │
│  • User Experience (UX)                                     │
│  • CRM Workflows                                            │
│  • Cron Triggers                                            │
│  • User Authentication                                      │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Repository Responsibilities

### Data-Lake-Backend

**Purpose:** Ingestion, enrichment, schema & data quality

**Core Responsibilities:**
- ✅ **Data Ingestion**
  - Web scraping (Redfin FSBO scraper)
  - CSV/API imports
  - Raw data collection and storage
- ✅ **Data Enrichment**
  - Skip tracing and contact information lookup
  - Geocoding and address normalization
  - Data quality validation
- ✅ **Schema Management**
  - Database schema definitions
  - Migrations and versioning
  - Data lake zone organization (raw/staging/curated)
- ✅ **Pipeline Orchestration**
  - Pipeline runs and tracking
  - Error handling and retries
  - Batch processing
- ✅ **Data Quality**
  - Validation rules
  - Data lineage tracking
  - Audit trails

**Key Technologies:**
- Python 3.10+ (scraping, enrichment)
- Supabase (database)
- AWS (IP rotation, infrastructure)

**What it does NOT do:**
- ❌ User authentication
- ❌ UI/UX presentation
- ❌ CRM workflow logic
- ❌ Scheduled job triggers (LeadMap-main triggers pipelines)

---

### LeadMap-main

**Purpose:** UX, CRM workflows, cron triggers, user auth

**Core Responsibilities:**
- ✅ **User Experience (UX)**
  - Web application UI (Next.js/React)
  - User dashboards and interfaces
  - Data visualization and reporting
- ✅ **CRM Workflows**
  - Contact management
  - Deal pipeline management
  - Task and list management
  - Email campaign orchestration
- ✅ **Cron Triggers**
  - Scheduled pipeline execution triggers
  - Periodic data refresh jobs
  - Background task scheduling
- ✅ **User Authentication**
  - User registration and login
  - Session management
  - Role-based access control (RBAC)
- ✅ **API Routes**
  - RESTful API endpoints
  - Data querying and filtering
  - Business logic layer

**Key Technologies:**
- Next.js 14+ (React framework)
- TypeScript
- Supabase (database, auth)
- Vercel (hosting)

**What it does NOT do:**
- ❌ Data scraping (uses Data-Lake-Backend)
- ❌ Schema definition (references Data-Lake-Backend schemas)
- ❌ Raw data processing (reads curated data)

---

## 🔄 Data Flow

### Ingestion Flow

```
1. Data-Lake-Backend
   └─> Redfin Scraper runs
       └─> Raw data → raw_redfin_responses (RAW ZONE)

2. Data-Lake-Backend
   └─> Enrichment Pipeline
       └─> Raw → fsbo_raw (STAGING ZONE)

3. Data-Lake-Backend
   └─> Geocoding Pipeline
       └─> Staging → fsbo_leads (CURATED ZONE)

4. LeadMap-main
   └─> Reads from curated tables
       └─> Displays in UI
```

### User Interaction Flow

```
1. User logs in (LeadMap-main auth)
   └─> Authenticated session created

2. User views listings (LeadMap-main)
   └─> Queries curated tables (listings, fsbo_leads)
   └─> Renders in UI

3. User creates contact (LeadMap-main)
   └─> Inserts into contacts table
   └─> User-scoped (user_id enforced)

4. User triggers pipeline (LeadMap-main cron)
   └─> Calls Data-Lake-Backend API/webhook
   └─> Pipeline runs in Data-Lake-Backend
   └─> Results stored in Supabase
```

---

## 📁 Shared Resources

### Database Schema

**Source of Truth:** `Data-Lake-Backend/scripts/supabase/`

Both repositories reference the same Supabase database, but:
- **Data-Lake-Backend** defines the schema
- **LeadMap-main** consumes the schema (via sync scripts)

**Synchronization:**
- Use `sync-supabase-schemas.ps1` or `sync-supabase-schemas.py`
- See [SYNC_GUIDE.md](./SYNC_GUIDE.md) for details

### Configuration

**Source of Truth:** `Data-Lake-Backend/config/`

Both repositories read from the same configuration:
- `config/pipeline-config.yaml` - Human-readable config
- `config/pipeline-config.json` - JSON format
- `config/pipeline-config.ts` - TypeScript with env overrides

**Environment Variables:**
- Both repos use `.env` files
- Same variable names for consistency
- See configuration files for all options

### Feature Flags

**Source of Truth:** Supabase `feature_flags` table

Both repositories query the same feature flags:
- Python jobs (Data-Lake-Backend) check flags before running
- Next.js API routes (LeadMap-main) check flags for feature toggles

**Usage:**
```python
# Python (Data-Lake-Backend)
is_enabled = supabase.rpc('is_feature_enabled', {
    'p_flag_key': 'enable_fsbo_enrichment'
})
```

```typescript
// TypeScript (LeadMap-main)
const enabled = await supabase.rpc('is_feature_enabled', {
  p_flag_key: 'enable_fsbo_enrichment'
});
```

---

## 🔑 Canonical ID Strategy

### Properties (listing_id as TEXT)

All property-related tables use `listing_id TEXT PRIMARY KEY`:
- `listings`
- `fsbo_leads`
- `expired_listings`
- `frbo_leads`
- `foreclosure_listings`
- `imports`
- `trash`

**Rationale:** Business identifier, not technical ID. Allows cross-referencing across systems.

### User Entities (UUID)

User-specific entities use `UUID PRIMARY KEY`:
- `contacts.id`
- `deals.id`
- `tasks.id`
- `lists.id`
- `list_items.id`

**Rationale:** Technical IDs for relationships, scoped per user.

See [canonical_id_strategy.sql](../scripts/supabase/canonical_id_strategy.sql) for full documentation.

---

## 🚀 Development Workflow

### Adding a New Pipeline (Data-Lake-Backend)

1. Create Python script in `scripts/`
2. Add pipeline definition to `config/pipeline-config.yaml`
3. Update schema if needed in `scripts/supabase/`
4. Add feature flag in Supabase `feature_flags` table
5. Document in `docs/`

### Adding a New UI Feature (LeadMap-main)

1. Create React component
2. Create API route if needed
3. Query curated tables (never raw/staging)
4. Check feature flags if rolling out gradually
5. Document in LeadMap-main docs

### Schema Changes

1. Update schema in `Data-Lake-Backend/scripts/supabase/`
2. Run sync script to update `LeadMap-main/supabase/`
3. Test migrations in development
4. Apply to production in coordinated deployment

---

## 📊 Data Lake Zones

The database is organized into three zones:

### RAW ZONE
- **Purpose:** Store unprocessed data from external sources
- **Tables:** `raw_redfin_responses`, `raw_csv_imports`, `raw_apollo_imports`
- **Access:** Data-Lake-Backend only

### STAGING ZONE
- **Purpose:** Normalized, partially processed data
- **Tables:** `fsbo_raw`, `import_staging`
- **Access:** Data-Lake-Backend processing, LeadMap-main can query for debugging

### CURATED ZONE
- **Purpose:** Production-ready, validated data
- **Tables:** `listings`, `fsbo_leads`, `contacts`, `deals`, etc.
- **Access:** Both repositories (LeadMap-main primary consumer)

See [data_lake_zones_schema.sql](../scripts/supabase/data_lake_zones_schema.sql) for details.

---

## 🔐 Security Model

### Authentication
- Handled by **LeadMap-main** (Supabase Auth)
- Users authenticate via email/password
- Sessions managed by Next.js middleware

### Authorization
- Row-Level Security (RLS) policies in Supabase
- User-specific data scoped by `user_id`
- Universal data (listings) accessible to all authenticated users
- Admin-only features protected by role checks

### Data Access
- **Data-Lake-Backend:** Uses service role key (server-side only)
- **LeadMap-main:** Uses anon key (client-side) + service role (API routes)

---

## 📝 Best Practices

### For Data-Lake-Backend Developers

1. ✅ Always write to appropriate zone (raw → staging → curated)
2. ✅ Use feature flags for new pipelines
3. ✅ Track pipeline runs in `pipeline_runs` table
4. ✅ Validate data before moving to curated zone
5. ✅ Document schema changes thoroughly

### For LeadMap-main Developers

1. ✅ Only query curated zone tables
2. ✅ Check feature flags for feature toggles
3. ✅ Always scope user-specific queries by `user_id`
4. ✅ Use API routes for database operations (never direct client queries for sensitive operations)
5. ✅ Sync schema files after Data-Lake-Backend changes

### For Both

1. ✅ Follow canonical ID strategy (`listing_id` for properties, UUID for user entities)
2. ✅ Read configuration from centralized config files
3. ✅ Check feature flags before enabling new features
4. ✅ Coordinate schema migrations
5. ✅ Test in development before production

---

## 📚 Related Documentation

- [SYNC_GUIDE.md](./SYNC_GUIDE.md) - Schema synchronization guide
- [INSTALLATION_ORDER.md](../scripts/supabase/INSTALLATION_ORDER.md) - Database setup order
- [canonical_id_strategy.sql](../scripts/supabase/canonical_id_strategy.sql) - ID strategy documentation
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Architecture diagram


