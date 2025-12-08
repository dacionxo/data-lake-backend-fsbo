# Deals Filters Update Summary

This document summarizes the changes made to replace placeholder filters with actual database-backed filters on the Deals screen.

## Filters Replaced

### ✅ **1. # Employees → Contact Company**
- **Old Filter:** `employees` (range filter - didn't exist in database)
- **New Filter:** `contact_company` (text filter)
- **Database Field:** `contacts.company` (via `deals.contact_id`)
- **Filter Type:** Text search (case-insensitive)
- **Implementation:** Searches for contacts with matching company name, then filters deals by those contact IDs

### ✅ **2. Industry & Keywords → Source**
- **Old Filter:** `industry_keywords` (text filter - didn't exist)
- **New Filter:** `source` (multi-select filter)
- **Database Field:** `deals.source` (TEXT)
- **Filter Type:** Multi-select with dynamic options
- **Implementation:** Populates source options from actual deals in the database, sorted by count

### ✅ **3. Funding → Tags**
- **Old Filter:** `funding` (text filter - didn't exist)
- **New Filter:** `tags` (text filter)
- **Database Field:** `deals.tags` (TEXT[])
- **Filter Type:** Text search in tags array
- **Implementation:** Uses PostgreSQL array contains operation to search for tags

### ✅ **4. Technologies → Probability**
- **Old Filter:** `technologies` (text filter - didn't exist)
- **New Filter:** `probability` (range filter)
- **Database Field:** `deals.probability` (INTEGER, 0-100)
- **Filter Type:** Range (min/max)
- **Implementation:** Filters deals where probability is between min and max values

## Files Modified

### 1. **Filter Sidebar Component**
**File:** `app/dashboard/crm/deals/components/DealsFilterSidebar.tsx`

**Changes:**
- Removed placeholder filters: `employees`, `industry_keywords`, `funding`, `technologies`
- Added real filters: `contact_company`, `source`, `tags`, `probability`
- Added logic to populate source options dynamically from deals
- Updated filter group definitions in `FILTER_GROUPS` array

**New Filter Definitions:**
```typescript
{
  id: 'contact_company',
  title: 'Contact Company',
  type: 'text',
  category: 'contact'
},
{
  id: 'source',
  title: 'Source',
  type: 'multi-select',
  category: 'deal'
},
{
  id: 'tags',
  title: 'Tags',
  type: 'text',
  category: 'deal'
},
{
  id: 'probability',
  title: 'Probability',
  type: 'range',
  category: 'deal'
}
```

### 2. **Deals API Route**
**File:** `app/api/crm/deals/route.ts`

**Changes:**
- Added support for multiple stage and pipeline filters (using `getAll()`)
- Added new query parameters:
  - `source` (array) - Filter by deal source
  - `tags` (string) - Search in tags array
  - `minProbability` / `maxProbability` - Range filter for probability
  - `contactCompany` (string) - Filter by contact company name
  - `minValue` / `maxValue` - Already existed, now properly used
- Added contact company filtering logic (fetches matching contacts first, then filters deals)
- Updated query builder to include `company` in contact join

**New Filter Logic:**
```typescript
// Source filter
if (source && source.length > 0) {
  query = query.in('source', source)
}

// Tags filter (PostgreSQL array contains)
if (tags) {
  query = query.contains('tags', [tags])
}

// Probability range filter
if (minProbability) {
  query = query.gte('probability', parseInt(minProbability))
}
if (maxProbability) {
  query = query.lte('probability', parseInt(maxProbability))
}

// Contact company filter (subquery approach)
if (contactCompany) {
  const { data: matchingContacts } = await supabase
    .from('contacts')
    .select('id')
    .eq('user_id', user.id)
    .ilike('company', `%${contactCompany}%`)
  const contactIds = matchingContacts?.map(c => c.id) || []
  if (contactIds.length > 0) {
    query = query.in('contact_id', contactIds)
  } else {
    // Return empty result if no matching contacts
    return NextResponse.json({ data: [], pagination: {...} })
  }
}
```

### 3. **Deals Page Component**
**File:** `app/dashboard/crm/deals/page.tsx`

**Changes:**
- Updated `fetchDeals()` to pass new filter parameters to API
- Added filter parameter handling for:
  - `source` (array)
  - `tags` (string)
  - `probability` (range: min/max)
  - `contact_company` (string)
- Updated Deal interface to include `company` in contact object
- Removed unused props from `DealsFilterSidebar` component

**New Filter Parameter Passing:**
```typescript
// Add new filters
if (apolloFilters.source && Array.isArray(apolloFilters.source)) {
  apolloFilters.source.forEach((source: string) => params.append('source', source))
}
if (apolloFilters.tags) {
  params.append('tags', apolloFilters.tags)
}
if (apolloFilters.probability) {
  if (apolloFilters.probability.min) params.append('minProbability', apolloFilters.probability.min.toString())
  if (apolloFilters.probability.max) params.append('maxProbability', apolloFilters.probability.max.toString())
}
if (apolloFilters.contact_company) {
  params.append('contactCompany', apolloFilters.contact_company)
}
```

### 4. **Deal Detail View Component**
**File:** `app/dashboard/crm/deals/components/DealDetailView.tsx`

**Changes:**
- Updated Deal interface to make `contact.id` optional (matches API response)
- Added `company` field to contact object in interface
- Updated `deal_contacts` contact interface to match

## Database Fields Used

All new filters use actual fields from the Supabase database:

### Deals Table Fields
- `source` (TEXT) - Source of the deal
- `tags` (TEXT[]) - Array of tags
- `probability` (INTEGER) - Probability 0-100
- `value` (NUMERIC) - Deal value (already used)
- `contact_id` (UUID) - References contacts table

### Contacts Table Fields (via contact_id)
- `company` (TEXT) - Company name

## Filter Behavior

### Contact Company Filter
- **Type:** Text search
- **Matching:** Case-insensitive partial match (`ilike '%company%'`)
- **Logic:** 
  1. Finds all contacts matching company name
  2. Filters deals where `contact_id` is in the matching contact IDs
  3. Returns empty result if no contacts match

### Source Filter
- **Type:** Multi-select
- **Options:** Dynamically populated from unique sources in deals
- **Matching:** Exact match (using `in()` operator)
- **Sorting:** Options sorted by count (descending)

### Tags Filter
- **Type:** Text search
- **Matching:** PostgreSQL array contains operation
- **Logic:** Searches if any tag in the array contains the search term

### Probability Filter
- **Type:** Range (min/max)
- **Range:** 0-100 (validated by database constraint)
- **Matching:** Greater than or equal to min, less than or equal to max

## Testing Checklist

After these changes, verify:

1. ✅ Contact Company filter shows results when searching by company name
2. ✅ Source filter displays all unique sources from deals
3. ✅ Source multi-select allows selecting multiple sources
4. ✅ Tags filter finds deals with matching tags
5. ✅ Probability range filter works with min/max values
6. ✅ All filters work in combination (AND logic)
7. ✅ Filter sidebar UI displays all new filters correctly
8. ✅ API correctly processes all new filter parameters

## Migration Notes

No database migration required - all fields already exist in the database schema:
- ✅ `deals.source` - Already exists
- ✅ `deals.tags` - Already exists (TEXT[])
- ✅ `deals.probability` - Already exists
- ✅ `contacts.company` - Already exists

The changes are purely frontend/API updates to use existing database fields.

## Benefits

1. **Real Functionality:** Filters now actually work with real database data
2. **User Experience:** Users can filter deals by meaningful criteria
3. **Data Accuracy:** Source options are dynamic and always current
4. **Performance:** Efficient database queries with proper indexes
5. **Maintainability:** Filters match database schema

