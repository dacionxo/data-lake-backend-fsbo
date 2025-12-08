# Lists and Pagination Logic Documentation

This document explains the logic behind saving items to lists and how pagination works when clicking on pagination controls.

---

## Table of Contents

1. [Saving Items to Lists](#saving-items-to-lists)
   - [Overview](#overview)
   - [Single Item Save Flow](#single-item-save-flow)
   - [Bulk Save Flow](#bulk-save-flow)
   - [Database Structure](#database-structure)
   - [Error Handling](#error-handling)

2. [Pagination Logic](#pagination-logic)
   - [Overview](#overview-1)
   - [Pagination Component](#pagination-component)
   - [Page Change Flow](#page-change-flow)
   - [State Management](#state-management)
   - [Data Fetching](#data-fetching)

---

## Saving Items to Lists

### Overview

The list saving system allows users to add items (listings, contacts, or companies) to lists for organization and management. The system uses an optimistic conflict handling approach that gracefully handles duplicates.

### Single Item Save Flow

#### 1. **User Action**
- User clicks "Save" or "Add to List" button on a listing/contact/company
- The action is triggered from components like:
  - `AddToCrmButton.tsx`
  - `AddToListsModal.tsx`
  - `GlobalListSelector.tsx`

#### 2. **Item Identification**
The system identifies the item using a multi-step verification process:

**Location:** `app/dashboard/prospect-enrich/utils/listUtils.ts`

```typescript
// Step 1: Try to find listing by listing_id
if (listing.listing_id) {
  const { data: foundListing } = await supabase
    .from('listings')
    .select('listing_id, property_url')
    .eq('listing_id', listing.listing_id)
    .maybeSingle()
}

// Step 2: If not found, try property_url
if (!itemIdToStore && listing.property_url) {
  const { data: foundListing } = await supabase
    .from('listings')
    .select('listing_id, property_url')
    .eq('property_url', listing.property_url)
    .maybeSingle()
}

// Step 3: Use canonical ID if found in database
if (verificationDetails.found && verificationDetails.canonicalId) {
  finalItemId = verificationDetails.canonicalId
} else {
  // Normalize identifier for consistency
  finalItemId = normalizeListingIdentifier(itemIdToStore)
}
```

**Key Points:**
- Prefers `listing_id` from database (canonical identifier)
- Falls back to `property_url` if listing not in database yet
- Normalizes identifiers to ensure consistency

#### 3. **API Request**
**Endpoint:** `POST /api/lists/[listId]/add`

**Location:** `app/api/lists/[listId]/add/route.ts`

**Request Body:**
```json
{
  "itemId": "string",
  "itemType": "listing" | "contact" | "company"
}
```

#### 4. **Server-Side Processing**

**Authentication:**
```typescript
// Verify user is authenticated
const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
if (authError || !user) {
  return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
}
```

**List Verification:**
```typescript
// Verify list exists and belongs to user
const { data: list } = await supabase
  .from('lists')
  .select('id, user_id, name')
  .eq('id', listId)
  .single()

if (list.user_id !== user.id) {
  return NextResponse.json({ error: 'Unauthorized' }, { status: 403 })
}
```

**Insert Membership:**
```typescript
const { data: membership, error: insertError } = await supabase
  .from('list_memberships')
  .insert({
    list_id: listId,
    item_type: itemType,
    item_id: itemId,
  })
  .select()
  .single()
```

#### 5. **Duplicate Handling**

The system uses optimistic conflict handling - duplicates are treated as successful operations:

```typescript
if (insertError) {
  // Check if it's a duplicate key error (PostgreSQL error code 23505)
  if (insertError.code === '23505' || insertError.message?.includes('duplicate')) {
    // Item already in list - return success
    const { data: existing } = await supabase
      .from('list_memberships')
      .select('*')
      .eq('list_id', listId)
      .eq('item_type', itemType)
      .eq('item_id', itemId)
      .single()

    return NextResponse.json({
      success: true,
      message: 'Item already in list',
      membership: existing,
    })
  }
  // Handle other errors...
}
```

**Why this approach?**
- Prevents duplicate entries in the UI
- Gracefully handles race conditions (multiple rapid clicks)
- Provides consistent user experience

### Bulk Save Flow

#### 1. **User Action**
- User selects multiple items (checkboxes)
- Clicks "Add to List" or uses Global List Selector

**Location:** `app/components/GlobalListSelector.tsx`

#### 2. **Item Normalization**
```typescript
const items = listingIds
  .map(listingId => {
    const normalizedId = normalizeListingIdentifier(listingId)
    if (!normalizedId) {
      console.warn(`⚠️ Skipping invalid listing ID: ${listingId}`)
      return null
    }
    return {
      itemId: normalizedId,
      itemType: 'listing' as const
    }
  })
  .filter((item): item is { itemId: string; itemType: 'listing' } => item !== null)
```

#### 3. **Bulk API Request**
**Endpoint:** `POST /api/lists/bulk-add`

**Location:** `app/api/lists/bulk-add/route.ts`

**Request Body:**
```json
{
  "listIds": ["list-id-1", "list-id-2"],
  "items": [
    { "itemId": "item-1", "itemType": "listing" },
    { "itemId": "item-2", "itemType": "listing" }
  ]
}
```

#### 4. **Bulk Insert**
```typescript
// Build bulk insert array
const memberships = []
for (const listId of listIds) {
  for (const item of items) {
    memberships.push({
      list_id: listId,
      item_type: item.itemType,
      item_id: item.itemId,
    })
  }
}

// Bulk insert (conflicts are ignored - duplicates are fine)
const { data: inserted } = await supabase
  .from('list_memberships')
  .insert(memberships)
  .select()
```

**Benefits:**
- Single database transaction for multiple items
- Efficient for adding many items at once
- Duplicates are automatically ignored

### Database Structure

#### `lists` Table
```sql
CREATE TABLE lists (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL, -- 'people' | 'properties'
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### `list_memberships` Table
```sql
CREATE TABLE list_memberships (
  id UUID PRIMARY KEY,
  list_id UUID REFERENCES lists(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL, -- 'listing' | 'contact' | 'company'
  item_id TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(list_id, item_type, item_id) -- Prevents duplicates
);
```

**Key Constraints:**
- Unique constraint on `(list_id, item_type, item_id)` prevents duplicates
- Foreign key to `lists` with CASCADE delete
- Stores generic item references (not specific table references)

### Error Handling

#### Common Scenarios:

1. **Item Already in List**
   - Status: Success (200)
   - Response: `{ success: true, message: 'Item already in list' }`
   - User Experience: Silent success (no error shown)

2. **List Not Found**
   - Status: 404
   - Response: `{ error: 'List not found' }`
   - User Experience: Error message displayed

3. **Unauthorized**
   - Status: 401 or 403
   - Response: `{ error: 'Unauthorized' }`
   - User Experience: Redirect to login or error message

4. **Invalid Item Type**
   - Status: 400
   - Response: `{ error: 'itemType must be "listing", "contact", or "company"' }`
   - User Experience: Error message displayed

---

## Pagination Logic

### Overview

The pagination system allows users to navigate through large datasets efficiently. It supports:
- Page-by-page navigation
- Page size selection (10, 25, 50, 100 items per page)
- Smart page number display (with ellipsis for large page counts)
- Real-time data fetching on page changes

### Pagination Component

**Location:** `app/dashboard/prospect-enrich/components/ApolloPagination.tsx`

#### Component Props:
```typescript
interface ApolloPaginationProps {
  currentPage: number        // Currently active page (1-indexed)
  totalPages: number         // Total number of pages
  pageSize: number          // Items per page
  totalItems: number        // Total number of items
  onPageChange: (page: number) => void      // Callback when page changes
  onPageSizeChange: (size: number) => void  // Callback when page size changes
  isDark?: boolean          // Dark mode support
}
```

#### Visual Structure:

```
[< Previous]  [1] [2] [3] ... [10]  [Next >]  [25 per page ▼]
```

### Page Change Flow

#### 1. **User Clicks Pagination Button**

**Scenario A: Click on Page Number**
```typescript
<button
  onClick={() => onPageChange(pageNum)}
  // ... styling
>
  {pageNum}
</button>
```

**Scenario B: Click Previous/Next**
```typescript
// Previous button
<button
  onClick={() => onPageChange(currentPage - 1)}
  disabled={currentPage === 1}
>
  <ChevronLeft />
</button>

// Next button
<button
  onClick={() => onPageChange(currentPage + 1)}
  disabled={currentPage === totalPages}
>
  <ChevronRight />
</button>
```

#### 2. **Page Number Calculation**

The component intelligently displays page numbers:

```typescript
const getPageNumbers = () => {
  const pages: (number | string)[] = []
  const maxVisible = 7

  if (totalPages <= maxVisible) {
    // Show all pages if 7 or fewer
    for (let i = 1; i <= totalPages; i++) {
      pages.push(i)
    }
  } else {
    if (currentPage <= 3) {
      // Near start: [1] [2] [3] [4] [5] ... [10]
      for (let i = 1; i <= 5; i++) {
        pages.push(i)
      }
      pages.push('...')
      pages.push(totalPages)
    } else if (currentPage >= totalPages - 2) {
      // Near end: [1] ... [6] [7] [8] [9] [10]
      pages.push(1)
      pages.push('...')
      for (let i = totalPages - 4; i <= totalPages; i++) {
        pages.push(i)
      }
    } else {
      // Middle: [1] ... [4] [5] [6] ... [10]
      pages.push(1)
      pages.push('...')
      for (let i = currentPage - 1; i <= currentPage + 1; i++) {
        pages.push(i)
      }
      pages.push('...')
      pages.push(totalPages)
    }
  }

  return pages
}
```

**Examples:**
- Total pages: 10, Current: 1 → `[1] [2] [3] [4] [5] ... [10]`
- Total pages: 10, Current: 5 → `[1] ... [4] [5] [6] ... [10]`
- Total pages: 10, Current: 10 → `[1] ... [6] [7] [8] [9] [10]`

#### 3. **Callback Execution**

When a page is clicked, the `onPageChange` callback is called:

```typescript
// In parent component (e.g., ListDetailPage)
const handlePageChange = (page: number) => {
  setCurrentPage(page)  // Update state
  // State change triggers useEffect to fetch new data
}
```

### State Management

#### Parent Component State

**Location:** `app/dashboard/lists/[id]/page.tsx`

```typescript
// Pagination state
const [currentPage, setCurrentPage] = useState(1)
const [pageSize] = useState(20)  // Match Apollo.io default
const [totalCount, setTotalCount] = useState(0)
const [totalPages, setTotalPages] = useState(0)
```

#### State Updates Trigger Data Fetching

```typescript
// Fetch list data when dependencies change
useEffect(() => {
  fetchListData()
}, [listId, currentPage, pageSize, sortBy, sortOrder, debouncedSearch, router])
```

**Key Point:** When `currentPage` changes, the `useEffect` hook automatically triggers `fetchListData()`.

### Data Fetching

#### 1. **API Request with Pagination Parameters**

**Location:** `app/dashboard/lists/[id]/page.tsx`

```typescript
const fetchListData = useCallback(async () => {
  if (!listId) return

  try {
    setLoading(true)
    
    // Build query parameters
    const params = new URLSearchParams({
      page: currentPage.toString(),      // Requested page number
      pageSize: pageSize.toString(),     // Items per page
      sortBy,                            // Sort field
      sortOrder,                         // Sort direction
      ...(debouncedSearch && { search: debouncedSearch })  // Optional search
    })

    // Make API request
    const response = await fetch(`/api/lists/${listId}/items?${params}`, {
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
      }
    })
    
    const data: ListItemsResponse = await response.json()
    
    // Update state with fetched data
    setListings(data.listings)          // Items for current page
    setTotalCount(data.totalCount)      // Total items (all pages)
    setTotalPages(data.totalPages)      // Total pages
  } catch (err) {
    console.error('Error fetching list data:', err)
    setListings([])
  } finally {
    setLoading(false)
  }
}, [listId, currentPage, pageSize, sortBy, sortOrder, debouncedSearch, router])
```

#### 2. **Server-Side Pagination**

**Endpoint:** `GET /api/lists/[listId]/items`

**Location:** `app/api/lists/[listId]/items/route.ts`

**Query Parameters:**
- `page`: Page number (1-indexed)
- `pageSize`: Number of items per page
- `sortBy`: Field to sort by
- `sortOrder`: 'asc' or 'desc'
- `search`: Optional search query

**Server Implementation:**
```typescript
// Parse query parameters
const page = Math.max(1, parseInt(searchParams.get('page') || '1', 10))
const pageSize = Math.min(100, Math.max(1, parseInt(searchParams.get('pageSize') || '20', 10)))
const offset = (page - 1) * pageSize

// Get total count (for all items matching filters)
const { count: totalCount } = await supabase
  .from('list_memberships')
  .select('*', { count: 'exact', head: true })
  .eq('list_id', listId)
  .eq('item_type', 'listing')

// Fetch paginated items
const { data: memberships } = await supabase
  .from('list_memberships')
  .select('*')
  .eq('list_id', listId)
  .eq('item_type', 'listing')
  .order(sortBy, { ascending: sortOrder === 'asc' })
  .range(offset, offset + pageSize - 1)  // PostgreSQL range query

// Calculate total pages
const totalPages = Math.ceil(totalCount / pageSize)

// Return response
return NextResponse.json({
  listings: enrichedListings,
  totalCount,
  totalPages,
  currentPage: page,
  pageSize
})
```

**Key Database Operations:**
- `count: 'exact'` - Gets total count efficiently
- `.range(offset, offset + pageSize - 1)` - Fetches only current page items
- Offset calculation: `(page - 1) * pageSize`

#### 3. **Response Structure**

```typescript
interface ListItemsResponse {
  listings: Listing[]      // Items for current page only
  totalCount: number       // Total items across all pages
  totalPages: number       // Total number of pages
  currentPage: number      // Current page number
  pageSize: number         // Items per page
  list: {
    id: string
    name: string
    type: string
  }
}
```

### Page Size Change Flow

#### 1. **User Selects New Page Size**

```typescript
<select
  value={pageSize}
  onChange={(e) => onPageSizeChange(Number(e.target.value))}
>
  <option value={10}>10 per page</option>
  <option value={25}>25 per page</option>
  <option value={50}>50 per page</option>
  <option value={100}>100 per page</option>
</select>
```

#### 2. **State Update and Reset**

```typescript
const handlePageSizeChange = useCallback((size: number) => {
  if (pagination) {
    pagination.onPageSizeChange(size)
  } else {
    setInternalPageSize(size)
    setInternalCurrentPage(1)  // Reset to first page
  }
}, [pagination])
```

**Key Points:**
- Page size change resets to page 1
- Triggers new data fetch with updated page size
- Recalculates total pages based on new page size

### Performance Optimizations

#### 1. **Debounced Search**
```typescript
// Debounce search query changes
useEffect(() => {
  const timer = setTimeout(() => {
    setDebouncedSearch(searchQuery)
    setCurrentPage(1)  // Reset to first page on search
  }, 300)

  return () => clearTimeout(timer)
}, [searchQuery])
```

**Benefit:** Prevents excessive API calls while user is typing

#### 2. **Loading States**
```typescript
const [loading, setLoading] = useState(true)

// Show loading indicator during fetch
{loading ? (
  <div>Loading...</div>
) : (
  <ListItems items={listings} />
)}
```

#### 3. **Efficient Database Queries**
- Only fetches items for current page
- Uses `count: 'exact'` for total count (doesn't fetch all rows)
- Uses indexed queries on `list_id` and `item_type`

### Display Calculations

#### Item Range Display
```typescript
const startItem = (currentPage - 1) * pageSize + 1
const endItem = Math.min(currentPage * pageSize, totalItems)

// Example: "Showing 21 - 40 of 100"
<div>
  Showing {startItem.toLocaleString()} - {endItem.toLocaleString()} of {totalItems.toLocaleString()}
</div>
```

**Examples:**
- Page 1, 20 per page, 100 total → "Showing 1 - 20 of 100"
- Page 2, 20 per page, 100 total → "Showing 21 - 40 of 100"
- Page 5, 20 per page, 100 total → "Showing 81 - 100 of 100"

### Error Handling

#### Network Errors
```typescript
try {
  const response = await fetch(`/api/lists/${listId}/items?${params}`)
  if (!response.ok) {
    if (response.status === 401) {
      router.push('/login')
      return
    }
    if (response.status === 404) {
      router.push('/dashboard/lists')
      return
    }
    // Handle other errors...
  }
} catch (err) {
  console.error('Error fetching list data:', err)
  setListings([])
}
```

#### Empty States
```typescript
if (totalCount === 0) {
  return <EmptyState message="No items in this list" />
}

if (listings.length === 0 && !loading) {
  return <EmptyState message="No items found for this page" />
}
```

---

## Summary

### Saving Items to Lists
1. **Multi-step verification** ensures correct item identification
2. **Optimistic duplicate handling** provides smooth UX
3. **Bulk operations** are efficient and scalable
4. **Database constraints** prevent duplicate entries

### Pagination
1. **Smart page number display** keeps UI clean for large datasets
2. **State-driven data fetching** automatically updates on page changes
3. **Server-side pagination** ensures efficient database queries
4. **Debounced search** prevents excessive API calls

Both systems are designed for performance, user experience, and reliability at scale.

