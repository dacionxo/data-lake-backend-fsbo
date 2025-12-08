# DealMachine Lead Detail Modal - Complete Feature Documentation

## Source
- **URL**: https://app.dealmachine.com/leads#property(id)=2142634558!fsp
- **CSS Selector**: `#root > div.deal-modal-overlay.animated.animate_delay_025s.fadeIn > div > div > div > div`
- **XPath**: `/html/body/div[2]/div[3]/div/div/div/div`
- **Screenshots**: Captured on 2025-11-20

---

## **COMPLETE UI STRUCTURE**

### **1. MODAL OVERLAY & CONTAINER**
```css
.deal-modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 9999;
  animation: fadeIn 0.25s ease-out;
}

.deal-wrapper {
  max-width: 1400px;
  width: 95vw;
  max-height: 90vh;
  background: #ffffff;
  border-radius: 12px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  display: flex;
  overflow: hidden;
}
```

---

### **2. HEADER SECTION** (Top bar)

#### **Left Side - Property Address**
```jsx
<div className="modal-header-left">
  <button className="close-button" aria-label="Close">
    <X size={20} />
  </button>
  <div className="property-address">
    <h1>732 Baldwin Ave</h1>
    <p>Norfolk, VA 23517</p>
  </div>
</div>
```

**Styling:**
```css
.modal-header-left {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px 20px;
}

.property-address h1 {
  font-size: 20px;
  font-weight: 600;
  color: #111827;
  margin: 0;
}

.property-address p {
  font-size: 14px;
  color: #6b7280;
  margin: 0;
}
```

#### **Right Side - Action Icons**
```jsx
<div className="modal-header-actions">
  {/* Camera/Photo Icon */}
  <button className="action-icon" title="Add Photo">
    <Camera size={20} />
  </button>
  
  {/* Favorite/Star Icon */}
  <button className="action-icon" title="Add to Favorites">
    <Star size={20} />
  </button>
  
  {/* Owner Assignment */}
  <button className="action-icon-badge" title="Assign Owner">
    <User size={20} />
    <span className="badge success">1</span>
  </button>
  
  {/* List Management */}
  <button className="action-icon-badge" title="Manage Lists">
    <List size={20} />
    <span className="badge info">1</span>
  </button>
  
  {/* Tag Management */}
  <button className="action-icon-badge" title="Manage Tags">
    <Tag size={20} />
    <span className="badge success">3</span>
  </button>
  
  {/* Pipeline Status Dropdown */}
  <select className="status-dropdown">
    <option>New Prospect</option>
    <option>Contacted</option>
    <option>Qualified</option>
    <option>Negotiation</option>
    <option>Under Contract</option>
    <option>Closed</option>
  </select>
</div>
```

**Styling:**
```css
.modal-header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px 20px;
}

.action-icon {
  width: 40px;
  height: 40px;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  background: #ffffff;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.15s ease;
}

.action-icon:hover {
  background: #f9fafb;
  border-color: #d1d5db;
}

.action-icon-badge {
  position: relative;
  width: 40px;
  height: 40px;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  background: #ffffff;
  display: flex;
  align-items: center;
  justify-center: center;
  cursor: pointer;
}

.badge {
  position: absolute;
  top: -6px;
  right: -6px;
  min-width: 20px;
  height: 20px;
  padding: 0 6px;
  border-radius: 10px;
  font-size: 11px;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #ffffff;
}

.badge.success {
  background: #10b981;
}

.badge.info {
  background: #3b82f6;
}

.status-dropdown {
  padding: 8px 32px 8px 12px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: #ffffff;
  font-size: 14px;
  font-weight: 500;
  color: #111827;
  cursor: pointer;
  appearance: none;
  background-image: url("data:image/svg+xml,...");
  background-repeat: no-repeat;
  background-position: right 8px center;
}
```

---

### **3. LEFT PANEL - PROPERTY IMAGE & INFO**

#### **A. Google Maps Street View Image**
```jsx
<div className="property-image-container">
  <img 
    src={`https://maps.googleapis.com/maps/api/streetview?size=640x480&location=${address}&key=YOUR_KEY`}
    alt="Property Street View"
    className="property-image"
  />
</div>
```

**Styling:**
```css
.property-image-container {
  width: 50%;
  min-height: 400px;
  background: #f3f4f6;
  position: relative;
  overflow: hidden;
}

.property-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
```

#### **B. Property Valuation Section**
```jsx
<div className="property-valuation">
  <div className="valuation-main">
    <span className="price-value">$678,000</span>
    <span className="price-label">
      Est. Value
      <InfoIcon size={14} />
    </span>
  </div>
  
  <div className="property-specs">
    <span>6 bds</span>
    <span className="separator">|</span>
    <span>3 ba</span>
    <span className="separator">|</span>
    <span>2,786 sqft</span>
  </div>
</div>
```

**Styling:**
```css
.property-valuation {
  padding: 20px;
  background: linear-gradient(135deg, #ffffff 0%, #f9fafb 100%);
  border-top: 1px solid #e5e7eb;
}

.valuation-main {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-bottom: 12px;
}

.price-value {
  font-size: 32px;
  font-weight: 700;
  color: #111827;
}

.price-label {
  font-size: 14px;
  color: #6b7280;
  display: flex;
  align-items: center;
  gap: 4px;
}

.property-specs {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 16px;
  color: #374151;
  font-weight: 500;
}

.separator {
  color: #d1d5db;
}
```

#### **C. Property Tags/Badges**
```jsx
<div className="property-tags">
  <span className="tag">Off Market</span>
  <span className="tag">Free And Clear</span>
  <span className="tag">High Equity</span>
  <span className="tag">Senior Owner</span>
</div>
```

**Styling:**
```css
.property-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}

.tag {
  padding: 6px 12px;
  border-radius: 16px;
  background: #f3f4f6;
  color: #6b7280;
  font-size: 13px;
  font-weight: 500;
  border: 1px solid #e5e7eb;
}
```

#### **D. Contact Information Section**
```jsx
<div className="contact-section">
  <h3 className="section-label">Contact Information:</h3>
  
  {/* Primary Contact */}
  <div className="primary-contact">
    <div className="contact-header">
      <h4 className="contact-name">The Gull Revocable Trust</h4>
      <button className="more-options">
        <MoreVertical size={20} />
      </button>
    </div>
    <p className="contact-address">732 Baldwin Ave<br/>Norfolk, VA 23517</p>
    
    <button className="start-mail-button">
      Start Mail
    </button>
  </div>
  
  {/* Associated Contacts */}
  <div className="associated-contacts">
    <div className="section-header">
      <h4>Associated contacts: (1)</h4>
      <InfoIcon size={14} />
    </div>
    
    <div className="contact-card">
      <div className="contact-info">
        <h5>Janet B Gull</h5>
        <div className="contact-badges">
          <span className="badge-small">
            <Check size={12} />
            Likely Owner
          </span>
          <span className="badge-small">
            <Home size={12} />
            Resident
          </span>
        </div>
      </div>
      
      <div className="contact-actions">
        <button className="contact-action">
          <Mail size={16} />
          <span className="action-badge">2</span>
        </button>
        <button className="contact-action">
          <Phone size={16} />
          <span className="action-badge">1</span>
        </button>
        <button className="contact-expand">
          <ChevronRight size={16} />
        </button>
      </div>
    </div>
  </div>
</div>
```

**Styling:**
```css
.contact-section {
  padding: 20px;
  border-top: 1px solid #e5e7eb;
}

.section-label {
  font-size: 13px;
  color: #6b7280;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 16px;
}

.primary-contact {
  padding: 16px;
  background: #f9fafb;
  border-radius: 8px;
  margin-bottom: 20px;
}

.contact-header {
  display: flex;
  justify-content: space-between;
  align-items: start;
  margin-bottom: 8px;
}

.contact-name {
  font-size: 16px;
  font-weight: 600;
  color: #111827;
  margin: 0;
}

.contact-address {
  font-size: 14px;
  color: #6b7280;
  line-height: 1.6;
  margin: 0 0 16px 0;
}

.start-mail-button {
  width: 100%;
  padding: 10px 16px;
  background: #ef4444;
  color: #ffffff;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s ease;
}

.start-mail-button:hover {
  background: #dc2626;
}

.associated-contacts {
  border-top: 1px solid #e5e7eb;
  padding-top: 16px;
}

.section-header {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 12px;
}

.section-header h4 {
  font-size: 14px;
  font-weight: 600;
  color: #374151;
  margin: 0;
}

.contact-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: #ffffff;
}

.contact-info h5 {
  font-size: 14px;
  font-weight: 600;
  color: #111827;
  margin: 0 0 6px 0;
}

.contact-badges {
  display: flex;
  gap: 6px;
}

.badge-small {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  border-radius: 12px;
  background: #f3f4f6;
  font-size: 12px;
  color: #6b7280;
}

.contact-actions {
  display: flex;
  gap: 8px;
}

.contact-action {
  position: relative;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: none;
  background: #3b82f6;
  color: #ffffff;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
}

.action-badge {
  position: absolute;
  top: -4px;
  right: -4px;
  min-width: 18px;
  height: 18px;
  padding: 0 4px;
  background: #ffffff;
  color: #3b82f6;
  font-size: 11px;
  font-weight: 600;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
}
```

---

### **4. RIGHT PANEL - TABBED CONTENT**

#### **A. Tab Navigation**
```jsx
<div className="tabs-navigation">
  <button className={`tab ${activeTab === 'info' ? 'active' : ''}`} 
          onClick={() => setActiveTab('info')}>
    Info
  </button>
  <button className={`tab ${activeTab === 'comps' ? 'active' : ''}`}
          onClick={() => setActiveTab('comps')}>
    Comps
  </button>
  <button className={`tab ${activeTab === 'mail' ? 'active' : ''}`}
          onClick={() => setActiveTab('mail')}>
    Mail
  </button>
  <button className={`tab ${activeTab === 'activity' ? 'active' : ''}`}
          onClick={() => setActiveTab('activity')}>
    Activity
  </button>
</div>
```

**Styling:**
```css
.tabs-navigation {
  display: flex;
  border-bottom: 1px solid #e5e7eb;
  padding: 0 20px;
}

.tab {
  padding: 16px 20px;
  border: none;
  background: transparent;
  font-size: 15px;
  font-weight: 500;
  color: #6b7280;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  transition: all 0.15s ease;
  position: relative;
  top: 1px;
}

.tab:hover {
  color: #374151;
}

.tab.active {
  color: #3b82f6;
  border-bottom-color: #3b82f6;
}
```

#### **B. Info Tab Content**
```jsx
<div className="tab-content">
  {/* Search Bar */}
  <div className="search-container">
    <SearchIcon size={16} />
    <input 
      type="text" 
      placeholder="Search Information"
      className="search-input"
    />
  </div>
  
  {/* Key Metrics */}
  <div className="metrics-grid">
    <div className="metric-card">
      <label>
        Estimated equity:
        <InfoIcon size={14} />
      </label>
      <value>$678,000</value>
    </div>
    
    <div className="metric-card">
      <label>
        Percent equity:
        <InfoIcon size={14} />
      </label>
      <value>100%</value>
    </div>
  </div>
  
  {/* Property Characteristics */}
  <div className="info-section">
    <h3>Property Characteristics</h3>
    
    <div className="info-row">
      <span className="info-label">
        Living area:
        <InfoIcon size={14} />
      </span>
      <span className="info-value">2,786 sqft</span>
    </div>
    
    <div className="info-row">
      <span className="info-label">
        Year built:
        <InfoIcon size={14} />
      </span>
      <span className="info-value">1923</span>
    </div>
    
    <button className="more-info-toggle">
      <ChevronDown size={16} />
      More Info
    </button>
  </div>
  
  {/* Land Information */}
  <div className="info-section">
    <h3>Land Information</h3>
    
    <div className="info-row">
      <span className="info-label">
        APN (Parcel ID):
        <InfoIcon size={14} />
      </span>
      <span className="info-value">17819000</span>
    </div>
    
    <div className="info-row">
      <span className="info-label">
        Lot size (Acres):
        <InfoIcon size={14} />
      </span>
      <span className="info-value">0.13 acres</span>
    </div>
    
    <button className="more-info-toggle">
      <ChevronDown size={16} />
      More Info
    </button>
  </div>
  
  {/* Tax Information */}
  <div className="info-section">
    <h3>Tax Information</h3>
    
    <div className="info-row">
      <span className="info-label">
        Tax delinquent?:
        <InfoIcon size={14} />
      </span>
      <span className="info-value">No</span>
    </div>
    
    <div className="info-row">
      <span className="info-label">
        Tax delinquent year:
        <InfoIcon size={14} />
      </span>
      <span className="info-value">--</span>
    </div>
  </div>
</div>
```

**Styling:**
```css
.tab-content {
  padding: 20px;
  overflow-y: auto;
  max-height: calc(90vh - 200px);
}

.search-container {
  position: relative;
  margin-bottom: 24px;
}

.search-container svg {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  color: #9ca3af;
}

.search-input {
  width: 100%;
  padding: 10px 12px 10px 40px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  font-size: 14px;
  color: #374151;
}

.search-input::placeholder {
  color: #9ca3af;
}

.metrics-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-bottom: 24px;
}

.metric-card {
  padding: 16px;
  background: #f9fafb;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
}

.metric-card label {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 13px;
  color: #6b7280;
  font-weight: 500;
  margin-bottom: 8px;
}

.metric-card value {
  display: block;
  font-size: 24px;
  font-weight: 700;
  color: #111827;
}

.info-section {
  margin-bottom: 24px;
  padding-bottom: 24px;
  border-bottom: 1px solid #e5e7eb;
}

.info-section:last-child {
  border-bottom: none;
}

.info-section h3 {
  font-size: 15px;
  font-weight: 600;
  color: #374151;
  margin: 0 0 16px 0;
}

.info-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 0;
  font-size: 14px;
}

.info-label {
  display: flex;
  align-items: center;
  gap: 4px;
  color: #6b7280;
  font-weight: 500;
}

.info-value {
  color: #111827;
  font-weight: 500;
}

.more-info-toggle {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 0;
  margin-top: 8px;
  border: none;
  background: transparent;
  color: #3b82f6;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
}

.more-info-toggle:hover {
  color: #2563eb;
}
```

---

### **5. PAGINATION NAVIGATION** (Arrow buttons)
```jsx
{/* Previous Button */}
<button 
  className="pagination-arrow prev"
  disabled={currentIndex === 0}
  onClick={goToPrevious}
>
  <ChevronLeft size={24} />
</button>

{/* Next Button */}
<button 
  className="pagination-arrow next"
  disabled={currentIndex === listingList.length - 1}
  onClick={goToNext}
>
  <ChevronRight size={24} />
</button>
```

**Styling:**
```css
.pagination-arrow {
  position: fixed;
  top: 50%;
  transform: translateY(-50%);
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: #ffffff;
  border: 1px solid #e5e7eb;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.15s ease;
  z-index: 10000;
}

.pagination-arrow:hover {
  background: #f9fafb;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
}

.pagination-arrow:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.pagination-arrow.prev {
  left: 20px;
}

.pagination-arrow.next {
  right: 20px;
}
```

---

## **KEY FEATURES TO IMPLEMENT**

### **1. Owner Assignment**
- Click icon opens dropdown/modal
- Search and select team members
- Shows current owner with avatar
- Badge shows count of owners (1)

### **2. List Management**
- Click icon opens list selector modal
- Add/remove lead from multiple lists
- Shows "All Leads", custom lists
- Badge shows count of lists (1)

### **3. Tag Management**  
- Click icon opens tag input/selector
- Create new tags inline
- Multi-select existing tags
- Badge shows count of tags (3)
- Tags displayed as pills below valuation

### **4. Pipeline Status**
- Dropdown with predefined stages
- Color-coded stages
- Updates in real-time
- Affects list filtering

### **5. Google Maps Integration**
- Street View API for property image
- Shows actual property condition
- Better than static images
- Helps with property verification

### **6. Contact Information**
- Multiple associated contacts
- Badges for "Likely Owner", "Resident"
- Email/phone counts with icons
- Click to expand contact details

### **7. Tabbed Information**
- **Info**: Property details, land info, tax info
- **Comps**: Comparable properties
- **Mail**: Mail campaign history
- **Activity**: Timeline of all actions

### **8. Property Tags/Badges**
- "Off Market", "Free And Clear", "High Equity", "Senior Owner"
- Auto-generated based on data
- Helps quick filtering/identification
- Visual indicators of opportunity

### **9. Keyboard Navigation**
- Left/Right arrows for pagination
- ESC to close modal
- Tab navigation between fields

### **10. Responsive Design**
- Modal adapts to screen size
- Maintains readability
- Touch-friendly on tablets

---

## **API INTEGRATION REQUIREMENTS**

### Google Maps Street View API
```javascript
const getStreetViewImage = (address: string) => {
  const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_KEY
  const encodedAddress = encodeURIComponent(address)
  return `https://maps.googleapis.com/maps/api/streetview?size=640x480&location=${encodedAddress}&key=${apiKey}`
}
```

### Supabase Schema Updates Required
```sql
-- Add new columns to listings table
ALTER TABLE listings ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS tags TEXT[];
ALTER TABLE listings ADD COLUMN IF NOT EXISTS lists TEXT[];
ALTER TABLE listings ADD COLUMN IF NOT EXISTS pipeline_status TEXT DEFAULT 'new_prospect';
ALTER TABLE listings ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN DEFAULT false;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS property_tags TEXT[]; -- Auto-generated tags

-- Create lists table
CREATE TABLE IF NOT EXISTS lead_lists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create tags table
CREATE TABLE IF NOT EXISTS lead_tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL UNIQUE,
  color TEXT DEFAULT '#3b82f6',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create activity log table
CREATE TABLE IF NOT EXISTS lead_activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  listing_id TEXT REFERENCES listings(listing_id),
  user_id UUID REFERENCES auth.users(id),
  activity_type TEXT NOT NULL,
  activity_data JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## **IMPLEMENTATION PRIORITY**

### Phase 1 (MVP - Essential)
1. ✅ Modal structure with header
2. ✅ Google Maps Street View image
3. ✅ Property valuation display
4. ✅ Basic property details
5. ✅ Pagination navigation
6. Owner assignment dropdown
7. Pipeline status dropdown
8. Tags input/management
9. Lists management
10. Keyboard navigation

### Phase 2 (Enhanced)
1. Associated contacts section
2. Tabbed navigation (Info/Comps/Mail/Activity)
3. Expandable "More Info" sections
4. Property badges auto-generation
5. Search within info
6. Activity timeline

### Phase 3 (Advanced)
1. Comps tab with comparable properties
2. Mail campaign integration
3. Photo upload/gallery
4. Notes and comments
5. Document attachments
6. Integration with email/phone systems

---

## **COLOR PALETTE**

```css
:root {
  /* Primary Colors */
  --color-primary: #3b82f6;
  --color-primary-hover: #2563eb;
  --color-danger: #ef4444;
  --color-danger-hover: #dc2626;
  --color-success: #10b981;
  --color-warning: #f59e0b;
  
  /* Neutrals */
  --color-gray-50: #f9fafb;
  --color-gray-100: #f3f4f6;
  --color-gray-200: #e5e7eb;
  --color-gray-300: #d1d5db;
  --color-gray-400: #9ca3af;
  --color-gray-500: #6b7280;
  --color-gray-600: #4b5563;
  --color-gray-700: #374151;
  --color-gray-800: #1f2937;
  --color-gray-900: #111827;
  
  /* Backgrounds */
  --bg-primary: #ffffff;
  --bg-secondary: #f9fafb;
  --bg-tertiary: #f3f4f6;
  
  /* Borders */
  --border-light: #e5e7eb;
  --border-default: #d1d5db;
  --border-dark: #9ca3af;
  
  /* Shadows */
  --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  --shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  --shadow-2xl: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
}
```

---

## **ANIMATION CLASSES**

```css
@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes slideInUp {
  from {
    transform: translateY(20px);
    opacity: 0;
  }
  to {
    transform: translateY(0);
    opacity: 1;
  }
}

@keyframes slideInLeft {
  from {
    transform: translateX(-20px);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}

.animate_delay_025s {
  animation-delay: 0.25s;
}

.fadeIn {
  animation: fadeIn 0.3s ease-out;
}

.slideInUp {
  animation: slideInUp 0.3s ease-out;
}

.slideInLeft {
  animation: slideInLeft 0.3s ease-out;
}
```

---

## **MOBILE RESPONSIVENESS**

```css
@media (max-width: 1024px) {
  .deal-wrapper {
    flex-direction: column;
    width: 95vw;
    max-height: 95vh;
  }
  
  .property-image-container,
  .tab-content-panel {
    width: 100%;
  }
  
  .property-image-container {
    min-height: 250px;
  }
  
  .pagination-arrow {
    width: 40px;
    height: 40px;
  }
  
  .pagination-arrow.prev {
    left: 10px;
  }
  
  .pagination-arrow.next {
    right: 10px;
  }
}

@media (max-width: 640px) {
  .modal-header-actions {
    flex-wrap: wrap;
    gap: 8px;
  }
  
  .action-icon,
  .action-icon-badge {
    width: 36px;
    height: 36px;
  }
  
  .metrics-grid {
    grid-template-columns: 1fr;
  }
  
  .property-specs {
    font-size: 14px;
  }
  
  .price-value {
    font-size: 24px;
  }
}
```

---

## **ACCESSIBILITY FEATURES**

1. **Keyboard Navigation**: Full support for Tab, Enter, ESC, Arrow keys
2. **ARIA Labels**: All buttons and interactive elements labeled
3. **Focus States**: Clear visual indicators for focused elements
4. **Screen Reader Support**: Proper semantic HTML and labels
5. **Color Contrast**: WCAG AA compliant color combinations
6. **Touch Targets**: Minimum 44x44px for all interactive elements

---

## **PERFORMANCE OPTIMIZATIONS**

1. **Lazy Loading**: Images loaded on demand
2. **Virtualization**: Long lists use virtual scrolling
3. **Debouncing**: Search inputs debounced (300ms)
4. **Caching**: API responses cached in memory
5. **Code Splitting**: Tabs loaded dynamically
6. **Image Optimization**: WebP format with fallbacks

---

This documentation provides a complete blueprint for recreating the DealMachine lead detail modal with all features, styling, and interactions documented in detail.

