# List Pagination API Documentation

## Problem Solved

The original `/api/listings/paginated` endpoint only queries base listing tables (`listings`, `expired_listings`, etc.) and never reads from `list_memberships` where items saved from Prospect/Enrich are stored. This means newly added list items wouldn't appear when using that endpoint.

## Solution

A new endpoint `/api/lists/[listId]/paginated` has been created that:

1. **Queries `list_memberships`** - Reads from the membership table where saved items live
2. **Joins with source tables** - Fetches full listing/contact data from appropriate tables
3. **Supports pagination** - Full pagination with search, sort, and filter capabilities
4. **Maintains compatibility** - Returns data in the same format as `/api/listings/paginated`

## Endpoint

### `GET /api/lists/[listId]/paginated`

Paginated API for fetching list items from `list_memberships` with full data joined from source tables.

#### Query Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | number | `1` | Page number (1-indexed) |
| `pageSize` | number | `20` | Items per page (max: 100) |
| `sortBy` | string | `created_at` | Field to sort by: `created_at`, `item_id`, `list_price`, `city`, `state`, `agent_name` |
| `sortOrder` | string | `desc` | Sort order: `asc` or `desc` |
| `search` | string | `''` | Search query (searches across address, city, state, zip, name, email, etc.) |
| `itemType` | string | `null` | Filter by item type: `listing`, `contact`, `company` |
| `table` | string | `null` | Optional: Filter listings by source table (`listings`, `expired_listings`, `fsbo_leads`, etc.) |

#### Authentication

Requires authenticated user. The list must belong to the authenticated user.

#### Response Format

```json
{
  "data": [
    {
      "listing_id": "...",
      "street": "...",
      "city": "...",
      "state": "...",
      // ... full listing/contact data
      "_membership_id": "uuid",
      "_membership_created_at": "timestamp",
      "_item_type": "listing" | "contact" | "company"
    }
  ],
  "count": 150,
  "page": 1,
  "pageSize": 20,
  "totalPages": 8,
  "hasNextPage": true,
  "hasPreviousPage": false,
  "list": {
    "id": "uuid",
    "name": "My List",
    "type": "properties" | "people"
  }
}
```

#### Example Usage

```typescript
// Fetch first page of list items
const response = await fetch('/api/lists/123e4567-e89b-12d3-a456-426614174000/paginated?page=1&pageSize=20')
const data = await response.json()

// Search within list
const searchResponse = await fetch('/api/lists/123e4567-e89b-12d3-a456-426614174000/paginated?search=california&page=1')

// Filter by item type
const contactsResponse = await fetch('/api/lists/123e4567-e89b-12d3-a456-426614174000/paginated?itemType=contact&page=1')

// Sort by price
const sortedResponse = await fetch('/api/lists/123e4567-e89b-12d3-a456-426614174000/paginated?sortBy=list_price&sortOrder=desc&page=1')
```

## Comparison with `/api/listings/paginated`

| Feature | `/api/listings/paginated` | `/api/lists/[listId]/paginated` |
|---------|---------------------------|--------------------------------|
| **Data Source** | Base tables only | `list_memberships` + source tables |
| **Shows Saved Items** | ❌ No | ✅ Yes |
| **List Filtering** | ❌ No | ✅ Yes (by listId) |
| **Item Type Filter** | ❌ No | ✅ Yes (listing/contact/company) |
| **Source Table Filter** | ✅ Yes (table param) | ✅ Yes (table param) |
| **Search** | ✅ Yes | ✅ Yes |
| **Sorting** | ✅ Yes | ✅ Yes |
| **Pagination** | ✅ Yes | ✅ Yes |

## Migration Guide

### Before (Doesn't Show Saved Items)

```typescript
// ❌ This only queries base tables, won't show items added from Prospect/Enrich
const response = await fetch('/api/listings/paginated?table=listings&page=1')
```

### After (Shows Saved Items)

```typescript
// ✅ This queries list_memberships and shows all saved items
const response = await fetch('/api/lists/YOUR_LIST_ID/paginated?page=1')
```

## Implementation Details

### How It Works

1. **Query `list_memberships`** - Gets paginated membership records for the specified list
2. **Fetch Source Data** - For each membership, fetches full data from:
   - Listing tables: `listings`, `expired_listings`, `fsbo_leads`, `frbo_leads`, `imports`, `foreclosure_listings`
   - Contact table: `contacts`
   - Company table: `companies` (future)
3. **Join & Merge** - Combines membership metadata with source data
4. **Filter & Sort** - Applies search filters and sorting
5. **Return** - Returns paginated results with metadata

### Performance Considerations

- Uses batch queries to fetch listings from multiple source tables in parallel
- Limits query sizes to prevent timeouts (max 1000 items per batch)
- Deduplicates results to handle items that might exist in multiple source tables
- Uses efficient indexes on `list_memberships` for fast pagination

### Error Handling

- Returns `401` if user is not authenticated
- Returns `404` if list doesn't exist or doesn't belong to user
- Returns `500` for server errors with details in response

## Related Endpoints

- `/api/lists/[listId]/items` - Similar endpoint but returns data in a different format (used by list detail page)
- `/api/lists/[listId]/add` - Adds items to a list (writes to `list_memberships`)
- `/api/listings/paginated` - Original pagination endpoint (base tables only)

## Notes

- Items added from Prospect/Enrich are stored in `list_memberships`, not in base listing tables
- This endpoint is the correct way to fetch paginated list contents
- The endpoint maintains backward compatibility with the response format of `/api/listings/paginated`
- All queries respect Row Level Security (RLS) policies



