# Deals Module Documentation

## Table of Contents
1. [Overview](#overview)
2. [Core Features](#core-features)
3. [Database Schema](#database-schema)
4. [API Endpoints](#api-endpoints)
5. [User Interface Components](#user-interface-components)
6. [Integration with Other Modules](#integration-with-other-modules)
7. [User Workflows](#user-workflows)
8. [Technical Implementation](#technical-implementation)

---

## Overview

The Deals module is a comprehensive CRM-style pipeline management system designed specifically for real estate investors. It allows users to track property deals from initial lead to closing, manage contacts, log activities, assign tasks, and collaborate with team members.

### Key Capabilities
- **Pipeline Management**: Customizable deal pipelines with multiple stages
- **Dual View Modes**: Kanban board and table/list views
- **Activity Tracking**: Complete audit trail of all deal-related activities
- **Task Management**: Integrated task creation and tracking
- **Contact Linking**: Connect multiple contacts to each deal
- **Team Collaboration**: Owner assignment, watchers, and permissions
- **Filtering & Search**: Advanced filtering by pipeline, stage, owner, and custom fields

---

## Core Features

### 1. Pipeline Management

Deals are organized into **pipelines**, which represent different sales processes or market strategies. Each pipeline contains ordered **stages** that represent the progression of a deal.

**Default Pipeline Stages:**
- New Lead
- Contacted
- Qualified
- Proposal
- Negotiation
- Under Contract
- Closed Won
- Closed Lost

**Custom Pipelines:**
- Users can create multiple pipelines (e.g., "Residential Acquisitions", "Commercial Deals", "Wholesale")
- Each pipeline can have custom stages tailored to specific workflows
- One pipeline can be marked as default

### 2. View Modes

#### Kanban Board View
- **Drag-and-Drop**: Move deals between stages by dragging cards
- **Visual Organization**: Each stage is a column with deal cards
- **Quick Information**: Cards show deal value, contact, close date, and probability
- **Stage Totals**: Each column displays the count and total value of deals

#### Table View
- **Sortable Columns**: Sort by name, value, stage, probability, close date, or contact
- **Comprehensive Data**: View all deal information in a tabular format
- **Bulk Actions**: Select multiple deals for batch operations
- **Export Ready**: Table format is ideal for CSV export

### 3. Deal Creation & Editing

**Required Fields:**
- Deal Name (Title)
- Pipeline (defaults to user's default pipeline)
- Initial Stage

**Optional Fields:**
- Description
- Deal Value (monetary amount)
- Probability (0-100%)
- Expected Close Date
- Contact (primary contact)
- Multiple Contacts (via deal_contacts table)
- Property/Listing ID (links to property database)
- Notes
- Tags (for categorization)

### 4. Activity Feed

Every action on a deal is logged in the activity feed:
- **Note Creation**: User-added notes and comments
- **Stage Changes**: Automatic logging when deal moves between stages
- **Value Updates**: Track when deal value changes
- **Task Creation/Completion**: Linked task activities
- **Email/Call Logging**: Communication history (future feature)
- **Document Uploads**: Track when documents are attached

### 5. Task Management

Tasks can be created directly from deals:
- **Linked Tasks**: Tasks are automatically linked to deals via `related_type='deal'` and `related_id`
- **Priority Levels**: Low, Medium, High, Urgent
- **Due Dates**: Set deadlines for task completion
- **Status Tracking**: Pending, In Progress, Completed, Cancelled
- **Activity Integration**: Task creation and completion appear in deal activity feed

### 6. Contact Management

**Primary Contact:**
- Single contact linked via `contact_id` field
- Used for quick reference and default communication

**Multiple Contacts:**
- Deal can have multiple contacts via `deal_contacts` table
- Each contact can have a role (seller, buyer, broker, agent, contractor, etc.)
- Useful for complex deals with multiple parties

---

## Database Schema

### Core Tables

#### `deals` Table
```sql
- id (UUID, Primary Key)
- user_id (UUID, Foreign Key to auth.users)
- contact_id (UUID, Foreign Key to contacts, nullable)
- listing_id (TEXT, links to property listings, nullable)
- title (TEXT, required)
- description (TEXT, nullable)
- value (NUMERIC, deal value in dollars, nullable)
- stage (TEXT, required, default: 'new')
- probability (INTEGER, 0-100, default: 0)
- expected_close_date (TIMESTAMPTZ, nullable)
- closed_date (TIMESTAMPTZ, nullable)
- pipeline_id (UUID, Foreign Key to deal_pipelines, nullable)
- owner_id (UUID, Foreign Key to auth.users, nullable)
- assigned_to (UUID, Foreign Key to auth.users, nullable)
- source (TEXT, nullable)
- source_id (TEXT, nullable)
- notes (TEXT, nullable)
- tags (TEXT[], array of tags)
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)
```

#### `deal_pipelines` Table
```sql
- id (UUID, Primary Key)
- user_id (UUID, Foreign Key to auth.users)
- name (TEXT, required)
- description (TEXT, nullable)
- stages (TEXT[], array of stage names in order)
- is_default (BOOLEAN, default: false)
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)
```

#### `deal_activities` Table
```sql
- id (UUID, Primary Key)
- deal_id (UUID, Foreign Key to deals)
- user_id (UUID, Foreign Key to auth.users)
- activity_type (TEXT): 'note', 'email', 'call', 'sms', 'meeting', 
  'task_created', 'task_completed', 'stage_changed', 'value_changed', 
  'contact_added', 'document_uploaded', 'status_changed'
- title (TEXT, required)
- description (TEXT, nullable)
- metadata (JSONB, additional structured data)
- created_at (TIMESTAMPTZ)
```

#### `deal_contacts` Table (Many-to-Many)
```sql
- id (UUID, Primary Key)
- deal_id (UUID, Foreign Key to deals)
- contact_id (UUID, Foreign Key to contacts)
- role (TEXT, nullable): 'seller', 'buyer', 'broker', 'agent', etc.
- created_at (TIMESTAMPTZ)
```

#### `deal_watchers` Table
```sql
- id (UUID, Primary Key)
- deal_id (UUID, Foreign Key to deals)
- user_id (UUID, Foreign Key to auth.users)
- created_at (TIMESTAMPTZ)
```

#### `deal_documents` Table
```sql
- id (UUID, Primary Key)
- deal_id (UUID, Foreign Key to deals)
- user_id (UUID, Foreign Key to auth.users)
- file_name (TEXT, required)
- file_url (TEXT, required)
- file_type (TEXT, nullable)
- file_size (BIGINT, nullable)
- description (TEXT, nullable)
- created_at (TIMESTAMPTZ)
```

### Relationships

```
deals
├── user_id → auth.users (deal owner)
├── contact_id → contacts (primary contact)
├── listing_id → listings/fsbo_leads/frbo_leads (property reference)
├── pipeline_id → deal_pipelines (pipeline assignment)
├── owner_id → auth.users (deal owner/creator)
└── assigned_to → auth.users (assigned team member)

deal_activities
├── deal_id → deals
└── user_id → auth.users (who performed the activity)

deal_contacts
├── deal_id → deals
└── contact_id → contacts

deal_watchers
├── deal_id → deals
└── user_id → auth.users

deal_documents
├── deal_id → deals
└── user_id → auth.users

tasks
├── related_type = 'deal'
└── related_id = deal.id
```

---

## API Endpoints

### Deals

#### `GET /api/crm/deals`
Fetch deals with filtering, sorting, and pagination.

**Query Parameters:**
- `page` (default: 1)
- `pageSize` (default: 20, max: 100)
- `search` - Search in title, description, notes
- `stage` - Filter by stage
- `pipeline` - Filter by pipeline ID
- `owner` - Filter by owner ID
- `assignedTo` - Filter by assigned user ID
- `sortBy` - Field to sort by (default: 'created_at')
- `sortOrder` - 'asc' or 'desc' (default: 'desc')

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "123 Main St Property",
      "value": 250000,
      "stage": "Under Contract",
      "contact": { ... },
      ...
    }
  ],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "total": 45,
    "totalPages": 3
  }
}
```

#### `POST /api/crm/deals`
Create a new deal.

**Request Body:**
```json
{
  "title": "Deal Name",
  "description": "Optional description",
  "value": 250000,
  "stage": "New Lead",
  "probability": 25,
  "expected_close_date": "2024-12-31T00:00:00Z",
  "contact_id": "uuid",
  "listing_id": "listing-id",
  "pipeline_id": "uuid",
  "tags": ["residential", "fixer-upper"],
  "contact_ids": ["uuid1", "uuid2"]
}
```

#### `GET /api/crm/deals/[dealId]`
Get a single deal with all related data (contacts, activities, tasks, documents, watchers).

#### `PUT /api/crm/deals/[dealId]`
Update a deal. Automatically logs stage changes in activity feed.

#### `DELETE /api/crm/deals/[dealId]`
Delete a deal (cascades to related records).

### Activities

#### `GET /api/crm/deals/[dealId]/activities`
Get activities for a deal.

**Query Parameters:**
- `limit` (default: 50)

#### `POST /api/crm/deals/[dealId]/activities`
Create a new activity (note, email, call, etc.).

**Request Body:**
```json
{
  "activity_type": "note",
  "title": "Note added",
  "description": "Seller is motivated by quick closing",
  "metadata": { "custom": "data" }
}
```

### Pipelines

#### `GET /api/crm/deals/pipelines`
Get all pipelines for the user. Creates default pipeline if none exist.

#### `POST /api/crm/deals/pipelines`
Create a new pipeline.

**Request Body:**
```json
{
  "name": "Commercial Pipeline",
  "description": "For commercial property deals",
  "stages": ["Lead", "Qualified", "LOI", "Under Contract", "Closed"],
  "is_default": false
}
```

---

## User Interface Components

### Main Page (`app/dashboard/crm/deals/page.tsx`)

**Features:**
- View toggle (Kanban/Table)
- Pipeline and stage filtering
- Search functionality
- Sort controls
- Create deal button
- Empty state handling
- Onboarding modal

**State Management:**
- `deals` - Array of deal objects
- `pipelines` - Available pipelines
- `contacts` - Available contacts for linking
- `viewMode` - 'kanban' or 'table'
- `selectedDeal` - Currently viewed deal
- `showDealForm` - Form modal visibility

### Kanban Board (`DealsKanban.tsx`)

**Features:**
- Drag-and-drop between stages
- Deal cards with key information
- Quick actions menu (edit, delete)
- Stage totals (count and value)
- Probability indicators
- Contact and date display

**Interactions:**
- Click card → Open deal detail view
- Drag card → Update deal stage
- Right-click menu → Edit or delete

### Table View (`DealsTable.tsx`)

**Features:**
- Sortable columns
- Row actions menu
- Probability progress bars
- Stage badges with colors
- Contact information
- Responsive design

### Deal Form Modal (`DealFormModal.tsx`)

**Sections:**
1. Basic Info (title, description)
2. Financial (value, probability)
3. Pipeline & Stage selection
4. Contact linking
5. Close date
6. Tags management
7. Notes

**Validation:**
- Title is required
- Probability must be 0-100
- Date format validation

### Deal Detail View (`DealDetailView.tsx`)

**Tabs:**
1. **Overview**
   - Deal information
   - Linked contacts
   - Tags
   - Notes

2. **Activity**
   - Chronological activity feed
   - Add note functionality
   - Activity type icons
   - User attribution

3. **Tasks**
   - List of linked tasks
   - Add task form
   - Priority indicators
   - Due date tracking

4. **Documents**
   - Uploaded documents
   - File metadata
   - Download links

---

## Integration with Other Modules

### 1. Contacts Module

**Connection:**
- Deals link to contacts via `contact_id` (primary) and `deal_contacts` (multiple)
- Contacts API (`/api/crm/contacts`) provides contact list for deal forms
- Contact information displays in deal cards and detail views

**Data Flow:**
```
Contacts Module → Deals Module
- Select contact when creating deal
- View contact info from deal detail
- Contact changes reflect in deal views
```

**Use Cases:**
- Create deal from contact page
- View all deals for a specific contact
- Link multiple parties to complex deals

### 2. Tasks Module

**Connection:**
- Tasks link to deals via `related_type='deal'` and `related_id=deal.id`
- Tasks API (`/api/tasks`) handles task CRUD operations
- Tasks appear in deal detail view and activity feed

**Data Flow:**
```
Deals Module → Tasks Module
- Create task from deal detail view
- Task appears in deal's task list
- Task completion logged in deal activity
- Tasks API creates task with deal relationship
```

**Use Cases:**
- "Schedule inspection" task for deal
- "Send offer letter" task with due date
- "Follow up with seller" reminder

### 3. Properties/Listings Module

**Connection:**
- Deals link to properties via `listing_id` field
- Can reference listings from multiple tables (listings, fsbo_leads, frbo_leads, imports)
- Property data can auto-populate deal form

**Data Flow:**
```
Properties Module → Deals Module
- Create deal from property page
- Property address auto-fills deal title
- Property price suggests deal value
- Property owner becomes primary contact
```

**Use Cases:**
- Convert property lead to deal
- Track multiple deals for same property
- Link property documents to deal

### 4. Calendar Module

**Connection:**
- Calendar events can link to deals via `related_type='deal'` and `related_id`
- Deal activities can create calendar events
- Scheduled meetings/calls appear in both modules

**Data Flow:**
```
Deals Module ↔ Calendar Module
- Schedule showing from deal → Creates calendar event
- Calendar event completion → Logs activity in deal
- Deal close date → Creates reminder event
```

**Use Cases:**
- Schedule property showing from deal
- Set reminder for contract deadline
- Log call/meeting in deal activity

### 5. Lists Module

**Connection:**
- Deals can be added to lists via `list_items` table
- Lists can contain deals alongside contacts and properties
- Deal filtering can use list membership

**Data Flow:**
```
Lists Module ↔ Deals Module
- Add deal to "Hot Leads" list
- Filter deals by list membership
- Bulk operations on listed deals
```

### 6. User Management & Permissions

**Connection:**
- Deals are user-scoped (`user_id`)
- Team collaboration via `owner_id` and `assigned_to`
- Watchers system for notifications
- Role-based access (future feature)

**Data Flow:**
```
User System → Deals Module
- User authentication required for all operations
- Deal ownership determines edit permissions
- Assigned user sees deal in their dashboard
- Watchers receive activity notifications
```

---

## User Workflows

### Workflow 1: Creating a Deal from a Property Lead

1. User views property in listings/leads module
2. Clicks "Create Deal" button on property
3. Deal form pre-populates:
   - Title: Property address
   - Listing ID: Current property
   - Contact: Property owner (if available)
   - Value: List price (if available)
4. User selects pipeline and initial stage
5. Deal created and appears in pipeline

### Workflow 2: Moving Deal Through Pipeline

1. User views deals in Kanban board
2. Drags deal card from "Qualified" to "Proposal" stage
3. System automatically:
   - Updates deal stage in database
   - Creates activity log entry
   - Notifies watchers (if configured)
4. Deal appears in new stage column

### Workflow 3: Adding Activity and Tasks

1. User opens deal detail view
2. Navigates to Activity tab
3. Adds note: "Seller wants quick closing, motivated"
4. Creates task: "Schedule inspection by Friday" (High priority)
5. System:
   - Creates activity entry
   - Creates linked task
   - Both appear in respective tabs

### Workflow 4: Team Collaboration

1. Deal owner assigns deal to team member
2. Team member sees deal in their dashboard
3. Team member adds watcher to deal
4. All watchers receive notifications for:
   - Stage changes
   - New activities
   - Task assignments
   - Value updates

### Workflow 5: Closing a Deal

1. Deal reaches "Under Contract" stage
2. User updates expected close date
3. On closing day:
   - User moves deal to "Closed Won" or "Closed Lost"
   - System sets `closed_date` timestamp
   - Deal value contributes to pipeline analytics
4. Deal archived but remains visible for reporting

---

## Technical Implementation

### Frontend Architecture

**Technology Stack:**
- Next.js 14+ (App Router)
- React (Client Components)
- TypeScript
- Tailwind CSS
- Lucide React (Icons)

**State Management:**
- React hooks (useState, useEffect)
- Server-side data fetching
- Optimistic UI updates

**Component Structure:**
```
app/dashboard/crm/deals/
├── page.tsx (Main container)
└── components/
    ├── DealsKanban.tsx
    ├── DealsTable.tsx
    ├── DealFormModal.tsx
    ├── DealDetailView.tsx
    └── DealsOnboardingModal.tsx
```

### Backend Architecture

**API Routes:**
- Next.js API Routes (App Router)
- Server-side authentication
- Supabase integration
- Error handling and validation

**Database:**
- Supabase (PostgreSQL)
- Row Level Security (RLS) via user_id
- Foreign key constraints
- Indexes for performance

**Authentication:**
- Supabase Auth
- Cookie-based sessions
- Service role for server-side queries

### Data Flow

```
User Action
    ↓
React Component
    ↓
API Route (/api/crm/deals/...)
    ↓
Authentication Check
    ↓
Supabase Query
    ↓
Database Operation
    ↓
Response to Frontend
    ↓
UI Update
```

### Performance Considerations

**Optimizations:**
- Pagination for large deal lists
- Indexed database queries
- Lazy loading of deal details
- Efficient filtering at database level
- Caching of pipeline/contact data

**Scalability:**
- User-scoped data (horizontal scaling)
- Efficient indexes on foreign keys
- Pagination limits (max 100 per page)
- Activity feed limits (100 most recent)

---

## Future Enhancements

### Planned Features

1. **AI Integration**
   - AI-generated deal summaries
   - Email draft suggestions
   - Lead scoring and prioritization
   - Next-step recommendations

2. **Email/SMS Integration**
   - Send emails from deal page
   - SMS notifications
   - Email templates
   - Communication logging

3. **Document Management**
   - File upload to Supabase Storage
   - Document versioning
   - E-signature integration
   - Contract templates

4. **Analytics & Reporting**
   - Pipeline conversion rates
   - Average deal value by stage
   - Time in stage metrics
   - Win/loss analysis

5. **Automation**
   - Workflow automation
   - Auto-assignment rules
   - Stage progression triggers
   - Reminder automation

6. **Integrations**
   - Salesforce sync
   - HubSpot sync
   - Google Calendar deep integration
   - Slack notifications

---

## Troubleshooting

### Common Issues

**Issue: Deals not appearing**
- Check user authentication
- Verify `user_id` matches current user
- Check pipeline filter settings
- Verify database connection

**Issue: Drag-and-drop not working**
- Check browser compatibility
- Verify deal update API response
- Check console for errors
- Ensure deal belongs to user

**Issue: Activities not logging**
- Verify activity API endpoint
- Check user permissions
- Review activity type values
- Check database constraints

**Issue: Tasks not linking**
- Verify `related_type='deal'`
- Check `related_id` matches deal ID
- Review task creation API
- Check task table foreign keys

---

## Conclusion

The Deals module provides a comprehensive solution for real estate deal management, seamlessly integrating with contacts, tasks, properties, calendar, and other system modules. Its flexible pipeline system, dual view modes, and robust activity tracking make it a powerful tool for real estate investors managing multiple deals simultaneously.

For technical support or feature requests, please refer to the main project documentation or contact the development team.

