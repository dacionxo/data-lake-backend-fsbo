# Calendar Integration Documentation

## Overview

This calendar system provides comprehensive scheduling functionality for the LeadMap real estate SaaS platform. It includes:

- **Native Calendar UI** - FullCalendar-based interface with month/week/day/list views
- **External Calendar Sync** - OAuth integration with Google Calendar and Outlook
- **Event Management** - Create, update, delete events with full CRUD operations
- **Free/Busy Checking** - Check availability to avoid double-booking
- **Reminders & Notifications** - Configurable reminders for events
- **Automated Follow-ups** - Trigger follow-up workflows after events
- **Scheduling Buttons** - Quick scheduling from leads, properties, and contacts

## Features

### 1. Calendar Views
- **Month View** - Full month calendar with event dots
- **Week View** - Detailed weekly schedule with time slots
- **Day View** - Hourly breakdown for a single day
- **List View** - Chronological list of upcoming events

### 2. Event Types
- Phone Calls
- Property Visits
- Property Showings
- Content Posts
- Meetings
- Follow-ups
- Other

### 3. External Calendar Integration
- **Google Calendar** - Full OAuth 2.0 integration
- **Microsoft Outlook** - OAuth integration (coming soon)
- **Apple iCloud** - OAuth integration (coming soon)

### 4. Event Features
- Drag-and-drop rescheduling
- Recurring events (RRULE support)
- All-day events
- Location and conferencing links
- Attendees management
- Tags and notes
- Custom colors

## Setup Instructions

### 1. Database Schema

Run the calendar schema SQL file in your Supabase SQL Editor:

```sql
-- Run: supabase/calendar_schema.sql
```

This creates the following tables:
- `calendar_events` - All calendar events
- `calendar_connections` - OAuth connections to external calendars
- `calendar_availability` - User availability settings
- `calendar_reminders` - Reminder tracking
- `calendar_sync_logs` - Sync operation logs
- `calendar_freebusy_cache` - Cached free/busy data

### 2. Install Dependencies

```bash
npm install
```

The following packages are added:
- `@fullcalendar/core` - Core calendar functionality
- `@fullcalendar/react` - React wrapper
- `@fullcalendar/daygrid` - Month view
- `@fullcalendar/timegrid` - Week/day views
- `@fullcalendar/interaction` - Drag-and-drop
- `@fullcalendar/list` - List view
- `googleapis` - Google Calendar API
- `rrule` - Recurrence rule parsing

### 3. Environment Variables

Add to your `.env.local`:

```env
# Google Calendar OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# App URL (for OAuth callbacks)
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

### 4. Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable "Google Calendar API"
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client ID"
5. Set application type to "Web application"
6. Add authorized redirect URI: `http://localhost:3000/api/calendar/oauth/google/callback`
7. Copy Client ID and Client Secret to `.env.local`

## API Routes

### Events

- `GET /api/calendar/events` - List events (with date range filters)
- `POST /api/calendar/events` - Create event
- `GET /api/calendar/events/[eventId]` - Get event details
- `PUT /api/calendar/events/[eventId]` - Update event
- `DELETE /api/calendar/events/[eventId]` - Delete event

### Free/Busy

- `GET /api/calendar/freebusy` - Get availability for date range

### Connections

- `GET /api/calendar/connections` - List connected calendars
- `POST /api/calendar/connections` - Create connection (OAuth callback)
- `DELETE /api/calendar/connections/[connectionId]` - Disconnect calendar

### OAuth

- `GET /api/calendar/oauth/google` - Initiate Google OAuth
- `GET /api/calendar/oauth/google/callback` - Handle OAuth callback

## Usage Examples

### Schedule a Call from a Lead

```tsx
import ScheduleButton from '@/app/dashboard/crm/calendar/components/ScheduleButton'

<ScheduleButton
  relatedType="lead"
  relatedId={leadId}
  eventType="call"
  variant="button"
/>
```

### Create Event Programmatically

```typescript
const response = await fetch('/api/calendar/events', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
  body: JSON.stringify({
    title: 'Property Showing',
    eventType: 'showing',
    startTime: '2024-01-15T10:00:00Z',
    endTime: '2024-01-15T11:00:00Z',
    location: '123 Main St',
    relatedType: 'listing',
    relatedId: listingId,
    reminderMinutes: [15, 60],
  }),
})
```

### Check Availability

```typescript
const response = await fetch(
  `/api/calendar/freebusy?start=${startDate}&end=${endDate}`,
  { credentials: 'include' }
)
const { busy, free } = await response.json()
```

## UI Components

### CalendarView
Main calendar component with FullCalendar integration.

```tsx
<CalendarView
  onEventClick={(event) => console.log(event)}
  onDateSelect={(start, end) => console.log(start, end)}
/>
```

### CreateEventModal
Modal for creating new events.

```tsx
<CreateEventModal
  isOpen={isOpen}
  onClose={() => setIsOpen(false)}
  initialDate={new Date()}
  relatedType="contact"
  relatedId={contactId}
  defaultEventType="call"
/>
```

### EventModal
Modal for viewing/editing event details.

```tsx
<EventModal
  event={event}
  onClose={() => setEvent(null)}
  onEdit={(id) => console.log('Edit', id)}
  onDelete={(id) => console.log('Delete', id)}
/>
```

### ScheduleButton
Quick scheduling button for leads/properties.

```tsx
<ScheduleButton
  relatedType="listing"
  relatedId={listingId}
  eventType="visit"
  variant="icon"
/>
```

## Calendar Settings

Access calendar settings at `/dashboard/settings`. From there you can:

- Connect Google Calendar
- Connect Outlook Calendar (coming soon)
- View connected calendars
- Sync calendars manually
- Disconnect calendars

## Two-Way Sync

When external calendars are connected:

1. **Events created in LeadMap** → Automatically synced to external calendar
2. **Events created in external calendar** → Synced to LeadMap (via webhooks/polling)
3. **Events updated in either** → Changes reflected in both
4. **Events deleted in either** → Removed from both

## Reminders

Events can have multiple reminders:
- 5 minutes before
- 15 minutes before
- 30 minutes before
- 1 hour before
- 1 day before

Reminders are sent via:
- In-app notifications
- Email (via Resend)
- SMS (via Twilio - optional)

## Follow-up Automation

After an event ends, you can trigger automated follow-ups:

```typescript
{
  followUpEnabled: true,
  followUpDelayHours: 24, // 24 hours after event
}
```

This can trigger:
- Email sequences
- Task creation
- CRM status updates
- Next action scheduling

## Security

- All API routes require authentication
- OAuth tokens are stored securely (should be encrypted in production)
- RLS policies ensure users only see their own events
- Minimal OAuth scopes (calendar read/write only)

## Future Enhancements

- [ ] Outlook Calendar OAuth
- [ ] Apple iCloud OAuth
- [ ] Unified calendar API (Nylas/OneCal integration)
- [ ] Webhook-based real-time sync
- [ ] Group scheduling
- [ ] Time zone detection
- [ ] Working hours configuration
- [ ] Buffer times between events
- [ ] Recurring event templates
- [ ] Event templates
- [ ] Bulk event operations
- [ ] Calendar sharing
- [ ] Team calendars

## Troubleshooting

### Events not syncing
- Check calendar connection status in settings
- Verify OAuth tokens are valid
- Check sync logs in database

### OAuth not working
- Verify redirect URI matches exactly
- Check Google Cloud Console credentials
- Ensure environment variables are set

### Calendar not loading
- Check browser console for errors
- Verify API routes are accessible
- Check authentication status

## Support

For issues or questions, please refer to:
- API documentation in code comments
- Database schema comments
- Component prop types

