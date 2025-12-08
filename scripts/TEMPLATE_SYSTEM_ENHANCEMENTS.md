# Template System Enhancements

This document describes the comprehensive enhancements made to the email template system to address all identified limitations.

## Overview

The template system has been completely upgraded with:
- Advanced templating engine with conditional logic and loops
- HTML escaping and sanitization
- Variable validation and preview
- Subject line templating
- Version history and tracking
- Enhanced folder organization
- Performance statistics
- Built-in testing workflow
- Template ownership and sharing (global/user/team scopes)

## 1. Advanced Templating Engine

### Features
- **Simple Variables**: `{{variable}}`
- **Nested Variables**: `{{listing.address}}`, `{{owner.name}}`
- **Conditionals**: `{{#if condition}}...{{/if}}`
- **Loops**: `{{#each items}}...{{/each}}`
- **Formatters**: `{{price|currency}}`, `{{date|date}}`, `{{text|uppercase}}`

### Example Usage

```html
Hello {{owner.name}},

{{#if price_drop_percent > 5}}
Great news! The price at {{address}} has dropped by {{price_drop_percent}}%.
{{/if}}

Property Details:
- Address: {{listing.address}}
- City: {{listing.city}}, {{listing.state}} {{listing.zip}}
- Price: {{price|currency}}
- Days on Market: {{days_on_market}}

{{#each features}}
  - {{this}}
{{/each}}
```

### Implementation
- **File**: `lib/email/template-engine.ts`
- **Functions**: `renderTemplate()`, `renderSubject()`, `previewTemplate()`

## 2. HTML Escaping and Sanitization

### Security Features
- **Default HTML Escaping**: All variables are HTML-escaped by default
- **Safe HTML Option**: Use `allowHtml: true` option to allow HTML in specific contexts
- **Subject Line Safety**: Subjects are never HTML-escaped (plain text only)

### Example
```typescript
// Default: HTML escaped
renderTemplate('{{address}}', context) 
// Output: "123 &lt;script&gt;alert('xss')&lt;/script&gt; St"

// With allowHtml (use with caution)
renderTemplate('{{address}}', context, { allowHtml: true })
// Output: "123 <script>alert('xss')</script> St"
```

## 3. Variable Validation

### Features
- **Variable Extraction**: Automatically detects all variables in a template
- **Allowed Variables**: Restrict templates to specific allowed variables
- **Preview Mode**: Shows warnings for unknown or missing variables
- **Strict Mode**: Throws errors on unknown variables

### Example
```typescript
const validation = validateTemplateVariables(
  'Hello {{name}}, your address is {{address}}',
  ['name', 'address'] // Allowed variables
)

// Returns: { valid: true, unknownVariables: [] }

// Or with unknown variable
const validation2 = validateTemplateVariables(
  'Hello {{name}}, your address is {{adress}}', // typo!
  ['name', 'address']
)
// Returns: { valid: false, unknownVariables: ['adress'] }
```

### Preview Function
```typescript
const preview = previewTemplate(template, sampleContext)
// Returns: {
//   rendered: "...",
//   variables: ["address", "owner_name", ...],
//   warnings: ["Some variables may be missing"],
//   unknownVariables: []
// }
```

## 4. Subject Line Templating

### Usage
```typescript
const subject = renderSubject(
  'Property at {{address}} - Price dropped {{price_drop_percent}}%',
  lead
)
// Output: "Property at 123 Main St - Price dropped 5%"
```

### Integration
- Subject templates are stored in `email_templates.subject`
- Rendered automatically when sending emails
- Supports all template features except HTML (plain text only)

## 5. Template Versioning

### Features
- **Automatic Versioning**: New versions created automatically on template updates
- **Version History**: Complete history of all template changes
- **Version Restore**: Restore any previous version
- **Immutable History**: Old versions are never modified

### Database Schema
- `template_versions` table stores all historical versions
- `email_templates.version` tracks current version
- Auto-incremented version numbers

### API Endpoints
- `GET /api/email-templates/[id]/versions` - List all versions
- `POST /api/email-templates/[id]/versions` - Restore a version

### Example
```typescript
// Get version history
const { versions } = await getTemplateVersions(templateId)

// Restore version 3
await restoreTemplateVersion(templateId, 3, 'Restored from backup')
```

## 6. Enhanced Folder Organization

### Folder Structure
Templates can be organized in folders using `folder_path`:
- `/Cold Outreach/Initial`
- `/Follow-up/First Touch`
- `/Follow-up/Second Touch`
- `/Referral`
- `/Transactional`
- `/Other`

### Categories and Folders
- **Categories**: Legacy field, still supported (e.g., 'cold_outreach', 'follow_up')
- **Folders**: New hierarchical organization system
- Templates can have both category and folder_path

### Folder Management
- Create folders via API: `POST /api/template-folders`
- Folders support scoping: global, user, team
- Hierarchical structure with parent folders

## 7. Performance Statistics

### Tracked Metrics
- Total sent
- Total opened
- Total clicked
- Total replied
- Total bounced
- Total unsubscribed
- Open rate (%)
- Click rate (%)
- Reply rate (%)
- Bounce rate (%)
- Last used date

### Database Schema
- `template_stats` table stores aggregated statistics
- Statistics tracked per template version
- Auto-updated via triggers when emails are sent

### API Endpoints
- `GET /api/email-templates/[id]/stats` - Get statistics
- `GET /api/email-templates/[id]/stats?version=2` - Get stats for specific version

### Example
```typescript
const { stats } = await getTemplateStats(templateId)
// Returns: {
//   total_sent: 100,
//   total_opened: 45,
//   open_rate: 45.0,
//   click_rate: 12.5,
//   ...
// }
```

## 8. Built-in Testing Workflow

### Features
- **Test Email API**: Send test emails with rendered templates
- **Test Context**: Use custom data or lead data for testing
- **Test History**: Track all test sends
- **UI Integration**: Test button in template modals

### API Endpoint
- `POST /api/email-templates/[id]/test`

### Example
```typescript
await testEmailTemplate({
  template_id: '...',
  test_email: 'test@example.com',
  test_context: { address: '123 Test St', ... },
  mailbox_id: '...'
})
```

### UI Integration
The `EmailTemplateModal` component includes:
- "Send Test" button
- Test email address input
- Mailbox ID selection
- Rendered preview before sending

## 9. Template Ownership and Sharing

### Scopes
1. **Global**: Available to all users (admin-created templates)
2. **User**: Private to the creator
3. **Team**: Shared within a team (future feature)

### Database Fields
- `scope`: 'global' | 'user' | 'team'
- `created_by`: User who created the template
- `team_id`: Team identifier (for team scope)

### RLS Policies
- Users can view global templates and their own templates
- Users can create templates (scope defaults to 'user')
- Users can update/delete their own templates
- Admins can manage all templates

### API Filtering
```typescript
// List only user's templates
listEmailTemplates('?scope=user')

// List global templates
listEmailTemplates('?scope=global')

// List all (default: user + global)
listEmailTemplates()
```

## Database Migration

### New Tables
1. `template_versions` - Version history
2. `template_stats` - Performance statistics
3. `template_test_sends` - Test email tracking
4. `template_folders` - Folder organization

### Enhanced Tables
- `email_templates` - Added fields:
  - `subject` - Subject line template
  - `version` - Current version number
  - `parent_template_id` - Link to parent template
  - `folder_path` - Folder organization
  - `description` - Template description
  - `scope` - Ownership scope
  - `team_id` - Team identifier
  - `is_active` - Active/inactive flag
  - `tags` - Array of tags
  - `allowed_variables` - Restricted variable list

### Migration Script
Run `supabase/template_system_enhancements.sql` to apply all schema changes.

## API Updates

### New Endpoints
- `POST /api/email-templates/[id]/test` - Send test email
- `GET /api/email-templates/[id]/versions` - Get version history
- `POST /api/email-templates/[id]/versions` - Restore version
- `GET /api/email-templates/[id]/stats` - Get statistics
- `GET /api/template-folders` - List folders
- `POST /api/template-folders` - Create folder

### Enhanced Endpoints
- `GET /api/email-templates` - Now supports filtering by category, folder, scope
- `POST /api/email-templates` - Accepts all new fields
- `PUT /api/email-templates/[id]` - Supports all new fields, auto-versions on update

## Component Updates

### EmailTemplateModal
Enhanced with:
- Template validation display
- Subject preview
- Test email functionality
- Folder/category display
- Unknown variable warnings

## Usage Examples

### Creating a Template with All Features
```typescript
await createEmailTemplate({
  title: 'Price Drop Alert',
  subject: 'Price dropped {{price_drop_percent}}% at {{address}}',
  body: '...',
  category: 'follow_up',
  folder_path: '/Follow-up/Price Drops',
  description: 'Alert when price drops significantly',
  scope: 'user',
  allowed_variables: ['address', 'price', 'price_drop_percent', 'owner_name'],
  tags: ['price-drop', 'alert', 'follow-up'],
  is_active: true,
})
```

### Rendering with Advanced Features
```typescript
const rendered = renderTemplate(template.body, lead, {
  escapeHtml: true, // Default
  allowedVariables: template.allowed_variables,
  strictMode: false,
})
```

## Migration Guide

### For Existing Templates
1. Run the database migration
2. Existing templates will be automatically assigned:
   - `version: 1`
   - `scope: 'user'` (based on created_by)
   - `is_active: true`
3. Subject lines will default to template title

### For Template Rendering
- Old `renderTemplate()` calls will continue to work
- New advanced features are opt-in via options
- HTML escaping is enabled by default (safer)

## Future Enhancements

Potential future improvements:
- Template A/B testing
- Template snippets/library
- Visual template builder
- Template collaboration (comments, suggestions)
- Template marketplace
- Advanced analytics (time-to-open, device breakdown, etc.)

## Security Considerations

1. **HTML Escaping**: Always enabled by default
2. **Variable Validation**: Use `allowed_variables` to restrict templates
3. **RLS Policies**: Templates are scoped by ownership
4. **Versioning**: Prevents accidental corruption of historical sends
5. **Test Sends**: Tracked separately from production sends

## Performance Notes

- Template rendering is synchronous and fast
- Statistics are aggregated, not per-email
- Version history is indexed for quick access
- Folder queries use indexes for performance

