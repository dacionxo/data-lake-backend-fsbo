# Apollo-Grade Lists System - Setup Guide

This guide will help you set up the world-class list management system modeled after Apollo.io, Clay, and DealMachine.

## ✅ Features Implemented

- **Many-to-Many Relationship** - Fully normalized `list_memberships` table
- **Zero Duplication** - Leads can belong to multiple lists, lists can have multiple leads
- **Apollo-Style UI** - Clean, modern interface with People/Companies sections
- **Optimistic Updates** - Instant UI feedback with delayed API sync
- **Search & Filters** - Find lists quickly
- **Bulk Operations** - Add multiple items to multiple lists at once
- **Proper Deduplication** - UNIQUE constraints prevent duplicates

## 📋 Setup Steps

### 1. Run Database Migration

Execute the SQL migration to create the new schema:

1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Click **New Query**
4. Copy and paste the contents of `supabase/apollo_lists_schema.sql`
5. Click **Run** (or press Ctrl+Enter)
6. Wait for "Success" message

**Important:** If you have existing `list_items` data, migrate it first:

```sql
-- Migrate existing data (run before dropping old tables)
INSERT INTO list_memberships (list_id, item_type, item_id, created_at)
SELECT list_id, item_type, item_id, created_at
FROM list_items
ON CONFLICT (list_id, item_type, item_id) DO NOTHING;
```

### 2. Update Your Code

The new system uses:
- `list_memberships` table instead of `list_items`
- New API endpoints: `/api/lists`, `/api/lists/[listId]/add`, etc.
- New components: `AddToListsModal`, updated `ListsPage`

### 3. API Endpoints

#### GET /api/lists
Fetches all lists for the authenticated user.

**Query params:**
- `type`: `'people' | 'properties'` (optional)
- `includeCount`: `boolean` (include item count)

**Example:**
```typescript
const response = await fetch('/api/lists?type=properties&includeCount=true')
const { lists } = await response.json()
```

#### POST /api/lists
Creates a new list.

**Body:**
```json
{
  "name": "My List",
  "type": "properties",
  "description": "Optional description"
}
```

#### POST /api/lists/[listId]/add
Adds an item to a list.

**Body:**
```json
{
  "itemId": "listing_id_or_contact_id",
  "itemType": "listing" | "contact" | "company"
}
```

#### POST /api/lists/[listId]/remove
Removes an item from a list.

**Body:**
```json
{
  "itemId": "listing_id_or_contact_id",
  "itemType": "listing" | "contact" | "company"
}
```

#### POST /api/lists/bulk-add
Bulk add operation (Apollo-grade).

**Body:**
```json
{
  "listIds": ["list-id-1", "list-id-2"],
  "items": [
    { "itemId": "item-1", "itemType": "listing" },
    { "itemId": "item-2", "itemType": "listing" }
  ]
}
```

#### GET /api/leads/[leadId]/lists
Gets all lists that a lead belongs to.

**Query params:**
- `itemType`: `'listing' | 'contact' | 'company'` (required)

## 🎨 UI Components

### AddToListsModal

The new Apollo-style modal component:

```tsx
import AddToListsModal from '@/app/dashboard/prospect-enrich/components/AddToListsModal'

<AddToListsModal
  isOpen={isModalOpen}
  onClose={() => setIsModalOpen(false)}
  itemId={listing.listing_id}
  itemType="listing"
  onSuccess={() => {
    // Refresh data
  }}
/>
```

**Features:**
- Search lists
- Create new list inline
- Optimistic updates
- Toggle multiple lists
- Shows item counts

### ListsPage

The new "My Lists" page with People/Companies sections:

- Located at: `/dashboard/lists`
- Shows separate sections for People and Properties lists
- Search and filter functionality
- Sort by name, created date, or last modified
- Click list name to view details

## 🧠 Architecture

### Database Schema

```
lists
├── id (UUID)
├── user_id (UUID) → auth.users(id)
├── name (TEXT)
├── type ('people' | 'properties')
├── description (TEXT)
├── created_at (TIMESTAMPTZ)
└── updated_at (TIMESTAMPTZ)

list_memberships (The Powerful Link Table)
├── id (UUID)
├── list_id (UUID) → lists(id)
├── item_type ('listing' | 'contact' | 'company')
├── item_id (TEXT) → listing_id, contact.id, or company.id
├── created_at (TIMESTAMPTZ)
└── UNIQUE(list_id, item_type, item_id)
```

### Key Principles

1. **Never store lists inside the lead**
   - Leads and lists are fully normalized
   - Use `list_memberships` for relationships

2. **Many-to-Many Relationship**
   - A lead can belong to multiple lists
   - A list can contain multiple leads
   - Zero duplication

3. **Optimistic Updates**
   - Update UI immediately
   - Sync with API in background
   - Revert on error

4. **Proper Deduplication**
   - UNIQUE constraint prevents duplicates
   - API handles conflicts gracefully

## 🔄 Migration from Old System

If you're migrating from `list_items` to `list_memberships`:

1. **Backup your data** (always!)
2. **Run the migration SQL** (see step 1)
3. **Update your code** to use new API endpoints
4. **Test thoroughly** before deploying

## 🚀 Usage Examples

### Add a listing to a list

```typescript
const response = await fetch(`/api/lists/${listId}/add`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    itemId: listing.listing_id,
    itemType: 'listing'
  })
})
```

### Get all lists for a lead

```typescript
const response = await fetch(`/api/leads/${listing.listing_id}/lists?itemType=listing`)
const { lists } = await response.json()
// lists is an array of List objects
```

### Bulk add to multiple lists

```typescript
const response = await fetch('/api/lists/bulk-add', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    listIds: ['list-1', 'list-2'],
    items: [
      { itemId: 'listing-1', itemType: 'listing' },
      { itemId: 'listing-2', itemType: 'listing' }
    ]
  })
})
```

## 🐛 Troubleshooting

### "List not found" errors
- Verify the list exists and belongs to the authenticated user
- Check RLS policies are set correctly

### Duplicate entries
- The UNIQUE constraint should prevent this
- API handles conflicts gracefully (ignores duplicates)

### Performance issues
- Indexes are created automatically
- Use `includeCount=false` if you don't need counts
- Consider pagination for large lists

## ✅ Checklist

- [ ] Run database migration (`apollo_lists_schema.sql`)
- [ ] Migrate existing `list_items` data (if applicable)
- [ ] Update code to use new API endpoints
- [ ] Test adding items to lists
- [ ] Test removing items from lists
- [ ] Test bulk operations
- [ ] Verify search and filters work
- [ ] Test optimistic updates
- [ ] Verify no duplicate entries

## 🎉 You're Done!

Your Apollo-grade list management system is now ready. Users can:
- Create People and Properties lists
- Add leads to multiple lists
- Search and filter lists
- Use bulk operations
- Enjoy instant UI updates

The system is fully normalized, scalable, and matches the UX of top-tier SaaS platforms like Apollo.io.

