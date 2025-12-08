# Prospect Enrich Table Structure Map

## Overview
This document maps out the complete structure of the prospect-enrich table, including column definitions, data mapping, component hierarchy, and scroll synchronization logic.

## Table Architecture

### Component Hierarchy
```
ProspectEnrichPage
└── ProspectEnrichContent
    └── ProspectEnrichInner (uses useSearchParams)
        └── DashboardLayout
            └── Table View Container
                ├── Horizontal Scrollbar (above header)
                ├── Sticky Header (headerScrollRef)
                │   └── Header Inner Div (width matches data scrollWidth)
                │       └── Column Headers
                └── Data Scroll Container (dataScrollContainerRef)
                    └── VirtualizedListingsTable
                        └── ApolloContactCard (for each row)
                            └── Data Cells
```

## Column Structure

### Header Columns (in order)

| # | Column Name | Width | Margin Right | Total Width | Data Field | Notes |
|---|-------------|-------|--------------|-------------|------------|-------|
| 0 | Checkbox | 18px | 16px | 34px | - | Selection checkbox (empty in header) |
| 1 | Address | 280px | 24px | 304px | `address` | Street address + city/state/zip |
| 2 | Price | 130px | 24px | 154px | `price` | List price with $/sqft |
| 3 | Status | 120px | 24px | 144px | `status` | Active/Expired/Sold badge |
| 4 | AI Score | 100px | 24px | 124px | `score` | Investment score (0-100) |
| 5 | Total Beds | 100px | 24px | 124px | `beds` | Number of bedrooms |
| 6 | Total Baths | 110px | 24px | 134px | `full_baths` | Number of full bathrooms |
| 7 | Housing Square Feet | 140px | 24px | 164px | `sqft` | Square footage |
| 8 | Text | 200px | 24px | 224px | `description` | Property description |
| 9 | Agent Name | 150px | 24px | 174px | `agent_name` | Listing agent name |
| 10 | Agent Email | 180px | 24px | 204px | `agent_email` | Agent email address |
| 11 | Agent Phone | 130px | 24px | 154px | `agent_phone` | Primary phone number |
| 12 | Agent Phone 2 | 130px | 24px | 154px | `agent_phone_2` | Secondary phone |
| 13 | Listing Agent Phone 2 | 160px | 24px | 184px | `listing_agent_phone_2` | Alternative phone |
| 14 | Listing Agent Phone 5 | 160px | 24px | 184px | `listing_agent_phone_5` | Additional phone |
| 15 | Year Built | 100px | 24px | 124px | `year_built` | Construction year |
| 16 | Last Sale Price | 130px | 24px | 154px | `last_sale_price` | Previous sale amount |
| 17 | Last Sale Date | 130px | 24px | 154px | `last_sale_date` | Previous sale date |
| 18 | Actions | 120px | 0px | 120px | - | Action buttons (save, email, call) |

**Total Minimum Width**: ~2,500px+ (varies based on content)

## Data Mapping

### ApolloContactCard Column Props
The `ApolloContactCard` component receives a `columns` array prop that determines which columns to display:

```typescript
columns: [
  'address',      // Column 1
  'price',        // Column 2
  'status',       // Column 3
  'score',        // Column 4
  'beds',         // Column 5
  'full_baths',   // Column 6
  'sqft',         // Column 7
  'description',  // Column 8
  'agent_name',   // Column 9
  'agent_email',  // Column 10
  'agent_phone',  // Column 11
  'agent_phone_2',           // Column 12
  'listing_agent_phone_2',   // Column 13
  'listing_agent_phone_5',   // Column 14
  'year_built',   // Column 15
  'last_sale_price',  // Column 16
  'last_sale_date',   // Column 17
  'actions'       // Column 18
]
```

### Listing Data Structure
```typescript
interface Listing {
  listing_id: string
  property_url?: string
  street?: string
  city?: string
  state?: string
  zip_code?: string
  list_price?: number
  status?: string
  active?: boolean
  ai_investment_score?: number
  beds?: number
  full_baths?: number
  sqft?: number
  text?: string  // description
  agent_name?: string
  agent_email?: string
  agent_phone?: string
  agent_phone_2?: string
  listing_agent_phone_2?: string
  listing_agent_phone_5?: string
  year_built?: number
  last_sale_price?: number
  last_sale_date?: string
  // ... other fields
}
```

## Scroll Synchronization

### Three-Way Scroll Sync ✅ IMPLEMENTED
The table implements synchronized horizontal scrolling between three elements:

1. **Header** (`headerScrollRef`) - Line 2280 in page.tsx
2. **Data Container** (`dataScrollContainerRef`) - Line 2643 in page.tsx
3. **Horizontal Scrollbar** (`horizontalScrollbarRef`) - Line 2270 in page.tsx

### Scroll Flow

```
User Scrolls Data Container
    ↓
handleDataScroll() triggered (throttled 0ms)
    ↓
syncHeaderToData() called
    ↓
smoothSync() animates scroll position
    ↓
Header & Scrollbar scrollLeft updated (100ms animation)
```

```
User Scrolls Header
    ↓
handleHeaderScroll() triggered (throttled 0ms)
    ↓
syncDataToHeader() called
    ↓
smoothSync() animates scroll position
    ↓
Data Container & Scrollbar scrollLeft updated (100ms animation)
```

```
User Scrolls Horizontal Scrollbar
    ↓
handleScrollbarScroll() triggered (throttled 0ms)
    ↓
syncDataToScrollbar() called
    ↓
smoothSync() animates scroll position
    ↓
Data Container & Header scrollLeft updated (100ms animation)
```

### Width Synchronization
- **Header Inner Div**: Width set to `dataEl.scrollWidth` via `updateScrollbarWidth()`
- **Horizontal Scrollbar Inner**: Width set to `dataEl.scrollWidth` via `updateScrollbarWidth()`
- **Data Container**: Natural width based on content (`width: 'max-content'`)

### Scroll Sync Implementation Details
- Uses `requestAnimationFrame` for smooth, frame-based animations
- Ease-out cubic easing function: `1 - Math.pow(1 - progress, 3)`
- Animation duration: 100ms for responsive feel
- Prevents scroll loops with `isSyncing` boolean flag
- Throttled with `setTimeout` (0ms delay) for immediate but controlled updates
- Performance optimizations:
  - `willChange: 'scroll-position'` for GPU acceleration
  - `scrollBehavior: 'auto'` for programmatic scrolling
  - Passive event listeners for better scroll performance
  - ResizeObserver to update widths when content changes
  - MutationObserver to track scrollWidth changes
- Cleanup: Removes all event listeners, cancels animation frames, and disconnects observers on unmount

## View Types

### Total View
- Shows all listings from current category
- Source: `listings` array
- Excludes saved listings (via `crmContactIds`)

### Net New View
- Shows listings created in last 30 days
- Excludes:
  - Saved listings (in `crmContactIds`)
  - Listings in any list (in `listItemIds`)
- Source: Filtered `listings` array

### Saved View
- Shows only saved listings
- Source: `savedListings` array
- Includes "Select All Saved" button

## Selection Behavior

### Selection State
- Stored in `selectedIds: Set<string>`
- Cleared when switching view types
- Cleared after bulk save/add to list operations

### Selection Features
- Individual row selection via checkbox
- Bulk selection via "Select All Saved" (only in Saved view)
- Selection persists during filtering/searching

## Styling

### Header Styling
- Position: `sticky`, `top: 0`
- Background: Dark mode aware gradient
- Border: 2px solid bottom border
- Z-index: 15 (above content)
- Scrollbar: Hidden but scrollable

### Data Row Styling
- Min height: 76px
- Padding: 14px 18px
- Background: Gradient based on selection state
- Border left: 4px (colored when selected)
- Hover effects with transform and shadow

### Scrollbar Styling
- Custom styled via CSS
- Thin scrollbar width
- Theme-aware colors
- Smooth scrolling enabled

## Performance Optimizations

### Virtualization
- Uses `@tanstack/react-virtual` for row virtualization
- Only renders visible rows
- Overscan: Configurable (default ~10 rows)
- Row height estimate: ~76px

### Scroll Performance
- `will-change: scroll-position` on scroll containers
- `scroll-behavior: auto` for programmatic scrolling
- Passive event listeners
- Throttled scroll handlers

## Key Functions

### updateScrollbarWidth()
Updates both horizontal scrollbar and header inner div widths to match data container's `scrollWidth`.

### syncHeaderToData()
Synchronizes header and scrollbar scroll positions when data container scrolls.

### syncDataToHeader()
Synchronizes data container and scrollbar scroll positions when header scrolls.

### syncDataToScrollbar()
Synchronizes data container and header scroll positions when scrollbar scrolls.

## Event Handlers

### handleDataScroll()
Throttled handler for data container scroll events.

### handleHeaderScroll()
Throttled handler for header scroll events.

### handleScrollbarScroll()
Throttled handler for horizontal scrollbar scroll events.

## Dependencies

### Refs
- `headerScrollRef`: Reference to header container
- `dataScrollContainerRef`: Reference to data scroll container
- `horizontalScrollbarRef`: Reference to horizontal scrollbar

### State
- `viewType`: 'total' | 'net_new' | 'saved'
- `selectedIds`: Set of selected listing IDs
- `crmContactIds`: Set of saved listing IDs
- `listItemIds`: Set of listing IDs in lists

## Notes

1. **Column Widths**: All columns use `flex: '0 0 [width]px'` to maintain fixed widths
   - ✅ **Verified**: Header and data cell widths match exactly (see table above)
   - Checkbox: 18px (fixed) + 16px margin
   - Address through Last Sale Date: Fixed widths with 24px margin
   - Actions: 120px (fixed) with 0px margin, right-aligned
2. **Margin Consistency**: All columns have `marginRight: '24px'` except:
   - Checkbox: `marginRight: '16px'`
   - Actions: `marginRight: 0px` (last column)
3. **Responsive**: Table expands horizontally based on content width
   - Minimum width enforced by column widths
   - Horizontal scrollbar appears when content exceeds viewport
4. **Accessibility**: Checkboxes and interactive elements have proper event handlers
5. **Dark Mode**: All styling is theme-aware with `isDark` prop
6. **Scroll Synchronization**: ✅ Fully implemented with three-way sync
   - Header scrolls with data
   - Horizontal scrollbar syncs with both
   - Smooth animations using requestAnimationFrame
   - Performance optimized with passive listeners and GPU acceleration

