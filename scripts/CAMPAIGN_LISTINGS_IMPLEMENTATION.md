# Campaign Listings Implementation

This document describes the implementation of the campaign listings feature, which allows listings saved from Prospect & Enrich to be displayed in the Campaign Details → Listings tab.

## Overview

The implementation ensures that:
1. Listings saved from Prospect & Enrich can be persisted to a campaign
2. Campaign Details → Listings tab can fetch and display those listings
3. All queries are properly scoped by user_id (multi-tenant safe)

## Database Schema

### `campaign_listings` Table

Created in `supabase/campaign_listings_schema.sql`:

```sql
CREATE TABLE campaign_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  listing_id TEXT NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (campaign_id, listing_id)
);
```

**Key Features:**
- Uses `user_id` for multi-tenant scoping (matches existing campaigns table pattern)
- Unique constraint prevents duplicate listings in the same campaign
- RLS policy ensures users can only see their own campaign listings

## API Endpoints

### GET `/api/campaigns/:campaignId/listings`

Fetches all listings saved to a campaign.

**Response:**
```json
{
  "listings": [
    {
      "listing_id": "...",
      "property_url": "...",
      "street": "...",
      "city": "...",
      "state": "...",
      "zip_code": "...",
      "beds": 3,
      "full_baths": 2,
      "list_price": 500000,
      "agent_name": "...",
      "agent_email": "...",
      "agent_phone": "...",
      "saved_at": "2024-01-01T00:00:00Z"
    }
  ],
  "count": 10
}
```

### POST `/api/campaigns/:campaignId/listings`

Saves listings to a campaign.

**Request Body:**
```json
{
  "listingIds": ["listing_id_1", "listing_id_2", "listing_id_3"]
}
```

**Response:**
```json
{
  "success": true,
  "count": 3,
  "message": "Successfully saved 3 listing(s) to campaign"
}
```

## Frontend Components

### Add Leads Modal - Listings Tab

Location: `app/dashboard/email/campaigns/[id]/components/AddLeadsModal.tsx`

**Features:**
- The "Listings" tab in the Add Leads modal now fetches listings saved to the campaign from `campaign_listings`
- Falls back to user's saved listings from contacts if no campaign listings exist
- When listings are selected and added, they are automatically saved to `campaign_listings`
- Displays listings with address, agent info, and email

**How it works:**
1. When user clicks "Add Leads" → "Listings" tab
2. Modal fetches listings from `/api/campaigns/:campaignId/listings` (campaign_listings)
3. If no campaign listings exist, falls back to user's saved listings from contacts
4. User selects listings and clicks "Add Leads"
5. Listings are saved to both `campaign_recipients` (as email recipients) and `campaign_listings` (for tracking)

### Campaign Details Page

Updated `app/dashboard/email/campaigns/[id]/page.tsx`:
- Removed redundant "Listings" tab from navigation
- Listings are now shown in the "Leads" tab via the Add Leads modal

## Utility Functions

### `saveListingsToCampaign`

Location: `app/dashboard/prospect-enrich/utils/listUtils.ts`

**Function Signature:**
```typescript
export async function saveListingsToCampaign(
  supabase: any,
  userId: string,
  campaignId: string,
  listingIds: string[]
)
```

**Usage Example:**
```typescript
import { saveListingsToCampaign } from '../utils/listUtils'

// Save selected listings to a campaign
await saveListingsToCampaign(
  supabase,
  user.id,
  campaignId,
  selectedListingIds
)
```

## Integration with Prospect & Enrich

To save listings from Prospect & Enrich to a campaign, you can:

1. **Use the utility function:**
```typescript
import { saveListingsToCampaign } from '../utils/listUtils'

const handleSaveToCampaign = async (campaignId: string, listingIds: string[]) => {
  await saveListingsToCampaign(supabase, profile.id, campaignId, listingIds)
}
```

2. **Use the API endpoint directly:**
```typescript
const response = await fetch(`/api/campaigns/${campaignId}/listings`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ listingIds: ['listing_id_1', 'listing_id_2'] })
})
```

## Setup Instructions

1. **Run the database migration:**
   ```sql
   -- Execute supabase/campaign_listings_schema.sql
   ```

2. **The API endpoints and components are ready to use**

3. **To add "Save to Campaign" button in Prospect & Enrich:**
   - Add a campaign selector/dropdown
   - On save, call `saveListingsToCampaign` or POST to `/api/campaigns/:id/listings`
   - The listings will automatically appear in Campaign Details → Listings tab

## Multi-Tenant Safety

- All queries filter by `user_id` from the authenticated session
- RLS policies ensure users can only access their own campaign listings
- Campaign ownership is verified before allowing listing saves/fetches

## Notes

- The implementation uses `user_id` instead of `org_id` to match the existing campaigns table pattern
- Listings are linked via `listing_id` which references the `listings` table
- The unique constraint on `(campaign_id, listing_id)` prevents duplicates
- Listings are fetched with a join to get full listing details

