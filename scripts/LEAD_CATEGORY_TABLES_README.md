# Lead Category Tables - Database Schema

## Overview

This document describes the separate Supabase tables created for each lead category to ensure complete data separation and prevent cross-contamination between different lead types.

## Tables Created

### 1. `expired_listings`
- **Purpose**: Stores listings that have expired, been sold, or are off-market
- **Key Fields**: 
  - `expired_date` - When the listing expired
  - `sold_date` - When the listing was sold (if applicable)
  - `status` - 'expired', 'sold', 'off market', etc.
  - `active` - Defaults to FALSE for expired listings

### 2. `fsbo_leads`
- **Purpose**: Stores FSBO (For Sale By Owner) property leads
- **Key Fields**:
  - `status` - Defaults to 'fsbo'
  - `fsbo_source` - Where the FSBO listing was found (e.g., 'craigslist', 'facebook', 'zillow')
  - `owner_contact_method` - Preferred contact method
  - `agent_name`, `agent_email`, `agent_phone` - Owner contact info for FSBO

### 3. `frbo_leads`
- **Purpose**: Stores FRBO (For Rent By Owner) property leads
- **Key Fields**:
  - `status` - Defaults to 'frbo'
  - `list_price` - Monthly rent price
  - `frbo_source` - Where the FRBO listing was found
  - `lease_term` - 'month-to-month', '12 months', etc.
  - `available_date` - When the property becomes available

### 4. `imports`
- **Purpose**: Stores imported leads from CSV, API, or other external sources
- **Key Fields**:
  - `import_source` - 'csv', 'api', 'manual', etc. (REQUIRED)
  - `import_batch_id` - Group imports by batch
  - `import_date` - When the import occurred

### 5. `trash`
- **Purpose**: Stores leads that have been marked as trash/not useful
- **Key Fields**:
  - `status` - Defaults to 'trash'
  - `active` - Defaults to FALSE for trash leads
  - `trash_reason` - Why this lead was marked as trash
  - `trashed_by` - User who marked it as trash
  - `trashed_at` - When it was marked as trash
  - `original_category` - What category this was in before being trashed

### 6. `foreclosure_listings`
- **Purpose**: Stores foreclosure property listings
- **Key Fields**:
  - `status` - Defaults to 'foreclosure'
  - `foreclosure_type` - 'pre-foreclosure', 'auction', 'bank-owned', etc.
  - `auction_date` - If applicable
  - `default_amount` - Amount in default
  - `lender_name` - Name of the lender
  - `case_number` - Foreclosure case number

## Existing Tables

### `listings`
- **Purpose**: General listings table for "All Prospects"
- **Note**: This is the main table that contains all general property listings

### `probate_leads`
- **Purpose**: Stores probate property leads from court filings
- **Note**: This table already exists and has a different structure (case_number, decedent_name, etc.)

## Table Structure

All category tables (except `probate_leads`) share the same base structure as the `listings` table, ensuring consistency:

- **Primary Key**: `listing_id` (TEXT)
- **Required Fields**: `listing_id`, `property_url` (UNIQUE)
- **Common Fields**: All property details (address, price, beds, baths, sqft, etc.)
- **Enrichment Fields**: Agent info, photos, AI scores, etc.
- **Management Fields**: `owner_id`, `tags`, `lists`, `pipeline_status`
- **Location Fields**: `lat`, `lng`

## Installation

1. Go to your Supabase Dashboard
2. Navigate to SQL Editor
3. Click "New Query"
4. Copy and paste the contents of `supabase/lead_category_tables.sql`
5. Click "Run" (or press Ctrl+Enter)
6. Wait for "Success" message

## Usage in Application

The application code in `app/dashboard/prospect-enrich/page.tsx` has been updated to:

1. Query the appropriate table based on the selected filter:
   - "All Prospects" → `listings` table
   - "Expired Listings" → `expired_listings` table
   - "Probate Leads" → `probate_leads` table (via API)
   - "FSBO" → `fsbo_leads` table
   - "FRBO" → `frbo_leads` table
   - "Imports" → `imports` table
   - "Trash" → `trash` table
   - "Foreclosure listings" → `foreclosure_listings` table

2. Fetch counts from each table separately to ensure accurate counts

3. Prevent cross-contamination by querying only the relevant table for each category

## Benefits

1. **Data Separation**: Each category has its own dedicated table
2. **No Cross-Contamination**: FSBO leads won't show up in probate leads, etc.
3. **Category-Specific Fields**: Each table can have fields specific to that category
4. **Better Performance**: Indexes are optimized for each table's use case
5. **Clear Organization**: Easy to understand which data belongs to which category
6. **Scalability**: Each table can be optimized independently

## Migration Notes

- The `fsbo_leads` table may already exist - the SQL uses `CREATE TABLE IF NOT EXISTS` to avoid errors
- If you have existing data in the `listings` table that should be moved to category tables, you'll need to:
  1. Identify which category each listing belongs to
  2. Insert into the appropriate category table
  3. Optionally remove from the `listings` table (or keep as a backup)

## Security

All tables have Row Level Security (RLS) enabled with policies that:
- Allow all authenticated users to read leads
- Allow authenticated users to insert/update leads
- Adjust these policies based on your specific security requirements


