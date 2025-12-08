# Removed Footer Pages Documentation

This document lists all the footer links that were removed because the corresponding pages have not been created yet. Use this as a reference when you're ready to add these pages back to the footer.

## 📋 Removed Pages by Category

### Product Column

The following pages were removed from the **Product** section:

1. **Features** (`/features`)
   - **Description**: Page showcasing all product features
   - **Suggested Content**: Feature list, feature comparisons, feature details
   - **Location to Add**: `app/features/page.tsx`
   - **Footer Location**: Product Column, after Dashboard link

2. **Integrations** (`/integrations`)
   - **Description**: Page listing all available integrations
   - **Suggested Content**: Integration list, setup guides, API documentation
   - **Location to Add**: `app/integrations/page.tsx`
   - **Footer Location**: Product Column, after Pricing link

3. **API** (`/api`)
   - **Description**: API documentation and developer resources
   - **Suggested Content**: API endpoints, authentication, code examples, SDKs
   - **Location to Add**: `app/api/page.tsx` (Note: This should be different from `app/api/` route handlers)
   - **Footer Location**: Product Column, after Integrations link

### Resources Column

The following pages were removed from the **Resources** section:

1. **Blog** (`/blog`)
   - **Description**: Company blog with articles and updates
   - **Suggested Content**: Blog posts, categories, search functionality
   - **Location to Add**: `app/blog/page.tsx` (or `app/blog/[slug]/page.tsx` for individual posts)
   - **Footer Location**: Resources Column

2. **Guides** (`/guides`)
   - **Description**: Helpful guides and tutorials
   - **Suggested Content**: Step-by-step guides, tutorials, best practices
   - **Location to Add**: `app/guides/page.tsx` (or `app/guides/[slug]/page.tsx` for individual guides)
   - **Footer Location**: Resources Column

3. **Case Studies** (`/case-studies`)
   - **Description**: Customer success stories and case studies
   - **Suggested Content**: Customer testimonials, success stories, ROI metrics
   - **Location to Add**: `app/case-studies/page.tsx` (or `app/case-studies/[slug]/page.tsx` for individual case studies)
   - **Footer Location**: Resources Column

4. **Help Center** (`/help`)
   - **Description**: Help documentation and support resources
   - **Suggested Content**: FAQ, troubleshooting, support articles, search
   - **Location to Add**: `app/help/page.tsx` (or `app/help/[category]/page.tsx` for categories)
   - **Footer Location**: Resources Column

5. **Documentation** (`/documentation`)
   - **Description**: Technical documentation and reference materials
   - **Suggested Content**: API docs, user guides, technical specifications
   - **Location to Add**: `app/documentation/page.tsx` (or `app/documentation/[section]/page.tsx` for sections)
   - **Footer Location**: Resources Column

### Company Column

The following pages were removed from the **Company** section:

1. **About Us** (`/about`)
   - **Description**: Company information, mission, vision, team
   - **Suggested Content**: Company history, team members, mission statement, values
   - **Location to Add**: `app/about/page.tsx`
   - **Footer Location**: Company Column, before Contact link
   - **Note**: This was also replaced with "Contact" in the main navigation header

2. **Careers** (`/careers`)
   - **Description**: Job openings and career opportunities
   - **Suggested Content**: Job listings, company culture, benefits, application process
   - **Location to Add**: `app/careers/page.tsx` (or `app/careers/[id]/page.tsx` for individual job postings)
   - **Footer Location**: Company Column, after Contact link

3. **Partners** (`/partners`)
   - **Description**: Partner program information and partner directory
   - **Suggested Content**: Partner benefits, partner directory, partnership application
   - **Location to Add**: `app/partners/page.tsx`
   - **Footer Location**: Company Column, after Careers link

4. **Press** (`/press`)
   - **Description**: Press releases, media kit, press contacts
   - **Suggested Content**: Press releases, media kit downloads, press contact information
   - **Location to Add**: `app/press/page.tsx` (or `app/press/[slug]/page.tsx` for individual press releases)
   - **Footer Location**: Company Column, after Partners link

## 🔄 How to Add Pages Back

### Step 1: Create the Page

Create a new page file following Next.js App Router conventions:

```typescript
// Example: app/features/page.tsx
export default function FeaturesPage() {
  return (
    <div>
      <h1>Features</h1>
      {/* Your content here */}
    </div>
  )
}
```

### Step 2: Add to Footer

Once the page is created, add it back to the footer in these files:

1. **`components/LandingPage.tsx`** - Main landing page footer
2. **`components/PricingPage.tsx`** - Pricing page footer

### Step 3: Update Footer Structure

The footer structure follows this pattern:

```tsx
{/* Product Column */}
<div className="flex flex-col gap-4">
  <h4 className="text-sm font-heading font-semibold text-black uppercase tracking-wider">Product</h4>
  <nav className="flex flex-col gap-3">
    <a href="/dashboard" className="text-sm font-light text-black hover:text-black transition-colors">Dashboard</a>
    <a href="/pricing" className="text-sm font-light text-black hover:text-black transition-colors">Pricing</a>
    {/* Add your new link here */}
    <a href="/features" className="text-sm font-light text-black hover:text-black transition-colors">Features</a>
  </nav>
</div>
```

### Step 4: Restore Resources Column (If Needed)

If you want to restore the Resources column, add it back between the Product and Company columns:

```tsx
{/* Resources Column */}
<div className="flex flex-col gap-4">
  <h4 className="text-sm font-heading font-semibold text-black uppercase tracking-wider">Resources</h4>
  <nav className="flex flex-col gap-3">
    <a href="/blog" className="text-sm font-light text-black hover:text-black transition-colors">Blog</a>
    <a href="/guides" className="text-sm font-light text-black hover:text-black transition-colors">Guides</a>
    {/* Add other resource links as pages are created */}
  </nav>
</div>
```

## 📝 Current Footer Structure

### Product Column (Currently Active)
- Dashboard (`/dashboard`)
- Pricing (`/pricing`)

### Resources Column (Removed)
- **Status**: Entire column has been removed from the footer
- **Note**: The Resources column and all its links (Blog, Guides, Case Studies, Help Center, Documentation) have been completely removed from the footer. When ready to add resources back, the entire column can be restored.

### Company Column (Currently Active)
- Contact (`/contact`)

### Brand Column (Always Active)
- Privacy Policy (`/privacy`)
- Terms of Service (`/terms`)
- Refund Policy (`/refund-policy`)

## 🎨 Design Consistency

When creating new pages, maintain consistency with existing pages:

- **Contact Page**: `app/contact/page.tsx` - Reference for design style
- **Privacy Page**: `app/privacy/page.tsx` - Reference for legal page style
- **Terms Page**: `app/terms/page.tsx` - Reference for legal page style
- **Refund Policy Page**: `app/refund-policy/page.tsx` - Reference for policy page style

## ✅ Checklist for Adding a Page Back

- [ ] Page created at correct location (`app/[page-name]/page.tsx`)
- [ ] Page content and design completed
- [ ] Link added to footer in `components/LandingPage.tsx`
- [ ] Link added to footer in `components/PricingPage.tsx`
- [ ] Link tested and working
- [ ] Page is responsive and matches site design
- [ ] SEO metadata added (title, description, etc.)

## 📌 Notes

- All removed pages were removed from both `LandingPage.tsx` and `PricingPage.tsx` footers
- The "About" link in the main navigation header was replaced with "Contact"
- **The Resources column has been completely removed** from the footer (not just emptied). When ready to add resources back, restore the entire column structure.
- Keep the footer structure consistent across all pages that use it

