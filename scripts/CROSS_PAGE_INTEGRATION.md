# Cross-Page Integration Guide

This document explains how to use the cross-page state management and action system to make buttons and features work across different pages.

## Overview

The system provides:
1. **Shared State Management** - Selection, filters, and view state shared across pages
2. **Action Routing** - Actions automatically route to the correct pages
3. **Reusable Components** - Action buttons that work anywhere
4. **Easy Integration** - Simple hooks for common operations

## Architecture

### Components

1. **PageStateContext** (`app/contexts/PageStateContext.tsx`)
   - Manages global page state (selections, filters, navigation)
   - Provides action execution and routing
   - Handles state persistence

2. **ActionMapper** (`app/lib/actionMapper.ts`)
   - Maps actions to target pages
   - Validates actions
   - Provides action configuration

3. **ActionButton** (`app/components/ActionButton.tsx`)
   - Reusable button component for actions
   - Handles validation and execution automatically

4. **usePageActions Hook** (`app/hooks/usePageActions.ts`)
   - Convenient methods for executing actions
   - Quick action helpers

## Usage

### 1. Using ActionButton Component

```tsx
import ActionButton from '@/app/components/ActionButton'

// Simple usage
<ActionButton action="save_to_crm" />

// With specific listing
<ActionButton 
  action="create_deal" 
  listingId={listing.listing_id}
  listing={listing}
/>

// Custom styling
<ActionButton 
  action="send_email"
  variant="outline"
  size="sm"
  label="Email"
/>
```

### 2. Using usePageActions Hook

```tsx
import { usePageActions } from '@/app/hooks/usePageActions'

function MyComponent() {
  const { quickActions, canExecuteAction, selectedCount } = usePageActions()
  
  const handleSave = async () => {
    const validation = canExecuteAction('save_to_crm')
    if (!validation.canExecute) {
      alert(validation.error)
      return
    }
    
    await quickActions.saveToCrm()
  }
  
  return (
    <button onClick={handleSave} disabled={selectedCount === 0}>
      Save to CRM ({selectedCount})
    </button>
  )
}
```

### 3. Using PageState Directly

```tsx
import { usePageState } from '@/app/contexts/PageStateContext'

function MyComponent() {
  const { 
    state, 
    selectListing, 
    executeAction,
    navigateToPage 
  } = usePageState()
  
  const handleAction = async () => {
    const context = {
      sourcePage: '/dashboard/prospect-enrich',
      listingIds: Array.from(state.selectedListingIds),
      listings: state.selectedListings
    }
    
    await executeAction('add_to_pipeline', context)
  }
}
```

## Available Actions

| Action | Target Page | Requires Selection | Description |
|--------|------------|-------------------|-------------|
| `save_to_crm` | Modal (List Selector) | Yes (min 1) | Save selected items to CRM - shows list selector modal |
| `add_to_list` | Modal (List Selector) | Yes (min 1) | Add to a list - shows list selector modal |
| `add_to_pipeline` | `/dashboard/crm/pipeline` | Yes (min 1) | Add to sales pipeline |
| `create_deal` | `/dashboard/crm/deals` | Yes (exactly 1) | Create a deal from selection |
| `send_email` | `/dashboard/crm/sequences` | Yes (min 1) | Send email to selected |
| `make_call` | `/dashboard/crm/activities` | Yes (min 1) | Log a call activity |
| `view_details` | Current page | Yes (exactly 1) | View details modal |
| `export` | Current page | No | Export data |
| `import` | `/admin` | No | Import data |
| `enrich` | `/dashboard/prospect-enrich` | Yes (min 1) | Enrich selected leads |
| `create_task` | `/dashboard/tasks` | Yes (min 1) | Create task for selection |
| `create_campaign` | `/dashboard/crm/campaigns` | Yes (min 1) | Create campaign |
| `add_to_sequence` | `/dashboard/crm/sequences` | Yes (min 1) | Add to email sequence |

## List Selection Modal

When `save_to_crm` or `add_to_list` actions are executed, a modal automatically appears that:
- Shows all user's lists (filtered by type - properties for listings)
- Allows searching through lists
- Allows creating a new list on the fly
- Remembers user's lists (fetched from database)
- Adds selected items to the chosen list
- Clears selection after successful add

The modal is handled globally via `GlobalListSelector` component and doesn't require any setup in individual pages.

## Receiving Actions on Target Pages

When an action navigates to a page, the target page should check for pending actions:

```tsx
'use client'

import { useEffect } from 'react'
import { usePageState } from '@/app/contexts/PageStateContext'
import { useSearchParams } from 'next/navigation'

export default function TargetPage() {
  const searchParams = useSearchParams()
  const { state } = usePageState()
  
  useEffect(() => {
    // Check URL params for action
    const action = searchParams.get('action')
    const listingIds = searchParams.get('ids')?.split(',')
    
    if (action === 'add_to_pipeline' && listingIds) {
      // Handle the action
      handleAddToPipeline(listingIds)
    }
    
    // Also check sessionStorage for action context
    const pendingAction = sessionStorage.getItem('pendingAction')
    if (pendingAction) {
      const { action, context } = JSON.parse(pendingAction)
      // Handle action with full context
      handleAction(action, context)
      sessionStorage.removeItem('pendingAction')
    }
  }, [searchParams])
  
  // ... rest of component
}
```

## Selection Management

The system automatically manages selections across pages:

```tsx
import { usePageState } from '@/app/contexts/PageStateContext'

function MyComponent() {
  const { 
    state,
    selectListing,
    deselectListing,
    selectAll,
    clearSelection
  } = usePageState()
  
  // Select a single listing
  selectListing(listing.listing_id, listing)
  
  // Deselect
  deselectListing(listing.listing_id)
  
  // Select all
  selectAll(listingIds, listings)
  
  // Clear all
  clearSelection()
  
  // Check if selected
  const isSelected = state.selectedListingIds.has(listing.listing_id)
}
```

## State Persistence

State is automatically saved to localStorage and persists across page reloads:
- Selected items
- Search query
- Active filters
- Sort settings
- View type

## Adding New Actions

1. Add action type to `ActionType` in `PageStateContext.tsx`
2. Add route configuration in `actionMapper.ts`:
```ts
'new_action': {
  targetPage: '/dashboard/target-page',
  requiresSelection: true,
  minSelections: 1
}
```
3. Add button config if needed:
```ts
{
  action: 'new_action',
  label: 'New Action',
  icon: 'IconName',
  color: 'blue'
}
```

## Best Practices

1. **Always validate actions** before execution
2. **Use quickActions** for common operations
3. **Check selection state** before showing action buttons
4. **Handle errors gracefully** when actions fail
5. **Clear selections** after successful actions
6. **Use ActionButton component** for consistent UI

## Example: Full Integration

```tsx
'use client'

import { usePageActions } from '@/app/hooks/usePageActions'
import { usePageState } from '@/app/contexts/PageStateContext'
import ActionButton from '@/app/components/ActionButton'

export default function ProspectPage() {
  const { quickActions, canExecuteAction, selectedCount } = usePageActions()
  const { state, selectListing, clearSelection } = usePageState()
  
  const handleBulkAction = async () => {
    if (selectedCount === 0) {
      alert('Please select at least one item')
      return
    }
    
    await quickActions.saveToCrm()
    clearSelection()
  }
  
  return (
    <div>
      {/* Action buttons */}
      <div>
        <ActionButton action="save_to_crm" />
        <ActionButton action="add_to_pipeline" />
        <ActionButton action="send_email" />
      </div>
      
      {/* Selection count */}
      {selectedCount > 0 && (
        <div>
          {selectedCount} selected
          <button onClick={clearSelection}>Clear</button>
        </div>
      )}
      
      {/* List items with selection */}
      {listings.map(listing => (
        <div key={listing.listing_id}>
          <input
            type="checkbox"
            checked={state.selectedListingIds.has(listing.listing_id)}
            onChange={(e) => {
              if (e.target.checked) {
                selectListing(listing.listing_id, listing)
              } else {
                deselectListing(listing.listing_id)
              }
            }}
          />
          <ActionButton 
            action="view_details"
            listingId={listing.listing_id}
            listing={listing}
            variant="ghost"
            size="sm"
          />
        </div>
      ))}
    </div>
  )
}
```

## Troubleshooting

**Actions not routing correctly:**
- Check action is defined in `ACTION_ROUTES`
- Verify target page exists
- Check browser console for errors

**Selections not persisting:**
- Ensure PageStateProvider wraps your app
- Check localStorage is enabled
- Verify state is being saved

**Action buttons disabled:**
- Check selection count meets requirements
- Verify action validation
- Check for error messages in tooltip

