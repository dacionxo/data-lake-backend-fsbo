# Deal Form Update Summary

## Overview
Updated the Create Deal form to match the provided design with customizable form fields and all required functionality.

## Changes Made

### 1. **DealFormModal Component** (`app/dashboard/crm/deals/components/DealFormModal.tsx`)
   - Complete rewrite to match the design
   - Header with "Create deal" title, "Customize deal form" link with gear icon, and X close button
   - Form fields in the correct order:
     - Deal name* (required)
     - Pipeline* (required dropdown)
     - Stage* (required dropdown, depends on pipeline)
     - Company (dropdown showing unique companies from contacts)
     - Estimated close date* (required, mm/dd/yyyy format with calendar icon)
     - Owner (shows current user with clear button and dropdown)
     - Amount ($) (number input with up/down arrows)
     - Closed won reason (textarea)
     - Closed lost reason (textarea)
     - Actual closed date (date field with mm/dd/yyyy format)
   - Three action buttons:
     - Save (yellow)
     - Save and create another (yellow)
     - Cancel (grey)
   - Integration with form customization settings
   - Date formatting helper functions for mm/dd/yyyy format

### 2. **DealFormSettingsModal Component** (`app/dashboard/crm/deals/components/DealFormSettingsModal.tsx`)
   - New component for customizing the deal form
   - Allows toggling field visibility
   - Allows setting required status (except for Deal name which is always required)
   - Allows reordering fields
   - Settings saved to localStorage
   - Reset to default functionality

### 3. **DealsPage Updates** (`app/dashboard/crm/deals/page.tsx`)
   - Added `users` state
   - Added `fetchUsers()` function to fetch users for the Owner dropdown
   - Updated `DealFormModal` props to include `users`
   - Users are fetched when onboarding is complete

### 4. **API Routes**

   #### **Users API** (`app/api/crm/deals/users/route.ts`)
   - New route to fetch users for the Owner dropdown
   - Returns current user (can be extended for team members)
   
   #### **Deals API - POST** (`app/api/crm/deals/route.ts`)
   - Updated to handle new fields:
     - `closed_date`
     - `closed_won_reason`
     - `closed_lost_reason`
     - `contact_company` (finds or creates contact by company)
   
   #### **Deals API - PUT** (`app/api/crm/deals/[dealId]/route.ts`)
   - Updated to handle new fields:
     - `closed_date`
     - `closed_won_reason`
     - `closed_lost_reason`
     - `contact_company` (finds contact by company if contact_id not provided)

### 5. **Database Schema Update** (`supabase/deals_form_fields_update.sql`)
   - Added `closed_won_reason` TEXT field to `deals` table
   - Added `closed_lost_reason` TEXT field to `deals` table
   - Added comments for documentation

## Features Implemented

### Form Customization
- Fields can be shown/hidden
- Fields can be marked as required (except Deal name)
- Fields can be reordered
- Settings persist in localStorage

### Company Selection
- Dropdown populated with unique companies from contacts
- Automatically links to contact when company is selected

### Owner Selection
- Defaults to current user
- Shows "David Walker (You)" format
- Dropdown to select other users (for team setups)
- Clear button to remove owner

### Date Formatting
- Estimated close date uses mm/dd/yyyy format
- Actual closed date uses mm/dd/yyyy format
- Calendar icon for visual indication

### Save Options
- "Save" - saves and closes form
- "Save and create another" - saves and resets form for another deal
- "Cancel" - closes without saving

## Database Migration Required

Run the following SQL script to add the new fields:

```sql
-- Run: supabase/deals_form_fields_update.sql
ALTER TABLE deals 
ADD COLUMN IF NOT EXISTS closed_won_reason TEXT,
ADD COLUMN IF NOT EXISTS closed_lost_reason TEXT;
```

## Testing Checklist

- [ ] Create a new deal with all fields
- [ ] Edit an existing deal
- [ ] Test form customization (show/hide fields, reorder)
- [ ] Test Company dropdown with contacts
- [ ] Test Owner selection
- [ ] Test date input with mm/dd/yyyy format
- [ ] Test "Save and create another" functionality
- [ ] Verify closed_won_reason and closed_lost_reason save correctly
- [ ] Verify form settings persist across sessions

## Notes

- Date inputs use text fields with mm/dd/yyyy format validation
- Form customization settings are stored in localStorage (can be migrated to database later)
- Owner field currently supports single user (can be extended for teams)
- Company field automatically finds matching contacts by company name

