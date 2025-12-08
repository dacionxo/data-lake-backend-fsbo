# LeadMap Lead Detail Modal - Quick Feature Guide

## 🎯 What You'll See When You Click "View Property"

### **Header Bar** (Top)
```
┌─────────────────────────────────────────────────────────────────────┐
│ [X]  732 Baldwin Ave                    📷 ⭐ 👤¹ 📋¹ 🏷️³ [▼New]  │
│      Norfolk, VA 23517                                              │
└─────────────────────────────────────────────────────────────────────┘
```

**Icons Explained:**
- **[X]**: Close modal
- **📷**: Add photos (placeholder)
- **⭐**: Toggle favorite (yellow when active)
- **👤¹**: Assign owner (badge shows count)
- **📋¹**: Manage lists (badge shows count)
- **🏷️³**: Manage tags (badge shows count)
- **[▼New]**: Pipeline status dropdown

---

### **Main Content** (Split View)

```
┌───────────────────────────┬──────────────────────────────────┐
│                           │ [Info] [Comps] [Mail] [Activity]│
│                           │                                  │
│   GOOGLE STREET VIEW      │  🔍 Search Information          │
│   (Property Photo)        │                                  │
│                           │  ┌────────────┬────────────────┐│
│                           │  │ Est Equity │ Percent Equity ││
│   ──────────────────────  │  │ $678,000   │ 100%          ││
│                           │  └────────────┴────────────────┘│
│   $678,000  Est. Value    │                                  │
│   6 bd | 3 ba | 2,786 sqft│  Property Characteristics        │
│                           │  Living area: ......... 2,786 sqft│
│   [Off Market] [High Eq.] │  Year built: ................ 1923│
│   [Free & Clear]          │  ▼ More Info                     │
│                           │                                  │
│   CONTACT INFORMATION:    │  Land Information                │
│   ┌─────────────────────┐ │  APN: ...................... --  │
│   │ Gull Revocable Trust│ │  Lot size: ................. --  │
│   │ 732 Baldwin Ave     │ │                                  │
│   │ Norfolk, VA 23517   │ │  Tax Information                 │
│   │ [Start Mail]        │ │  Tax delinquent?: ............ No│
│   └─────────────────────┘ │  Tax year: ................... --│
│                           │  Last Sale: ......... $XXX,XXX   │
│   Associated contacts: (1)│  Last Sale Date: ...... MM/DD/YY │
│   Janet B Gull            │                                  │
│   [✓Agent]  [@] [☎] [>]  │                                  │
│                           │                                  │
└───────────────────────────┴──────────────────────────────────┘
```

---

### **Footer Bar** (Bottom)
```
┌─────────────────────────────────────────────────────────────────────┐
│ [< Previous]  [Next >]  1 of 25              [View Property →]      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🎨 Interactive Elements

### **1. Owner Assignment** (Click 👤 icon)
```
┌────────────────────────┐
│ Assign Owner      [X]  │
├────────────────────────┤
│ [🔍 Search users...]   │
│                        │
│ ○ John Doe             │
│ ○ Jane Smith           │
│ ● Mike Johnson (You)   │
│ ○ Unassigned           │
└────────────────────────┘
```

### **2. List Management** (Click 📋 icon)
```
┌────────────────────────┐
│ Manage Lists      [X]  │
├────────────────────────┤
│ ☑ All Leads            │
│ ☑ Hot Prospects        │
│ ☐ Cold Leads           │
│ ☐ Follow Up            │
│ ☐ Closed Deals         │
│                        │
│ [+ Create New List]    │
└────────────────────────┘
```

### **3. Tag Management** (Click 🏷️ icon)
```
┌────────────────────────┐
│ Manage Tags       [X]  │
├────────────────────────┤
│ [Type to add tag...]   │
│                        │
│ [High Value] [x]       │
│ [Motivated Seller] [x] │
│ [Cash Buyer] [x]       │
│                        │
│ Suggestions:           │
│ • Wholesale            │
│ • Fix & Flip           │
│ • Buy & Hold           │
└────────────────────────┘
```

---

## 📑 Tab Contents

### **Info Tab** (Default)
- Key metrics (Equity, Percent Equity)
- Property characteristics (Living area, Year built)
- Land information (APN, Lot size)
- Tax information (Delinquent status, Last sale)

### **Comps Tab** (Coming Soon)
```
     🏠
Comparable Properties
View similar properties in the area to 
help determine market value and 
investment potential.

     [Find Comps]
```

### **Mail Tab** (Coming Soon)
```
     ✉️
Mail Campaigns
Send direct mail campaigns to this 
property owner to generate leads and 
build relationships.

     [Start Mail Campaign]
```

### **Activity Tab** (Coming Soon)
```
     📊
Activity Timeline
Track all interactions, notes, and 
changes related to this property 
in one place.

┌────────────────────────┐
│   No activity yet      │
└────────────────────────┘
```

---

## ⌨️ Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **ESC** | Close modal |
| **←** (Left Arrow) | Previous property |
| **→** (Right Arrow) | Next property |
| **Tab** | Navigate between elements |
| **Enter** | Activate focused element |

---

## 🎯 Click Actions

### **Header Actions:**
- **Camera icon**: (Future) Open photo upload
- **Star icon**: Toggle favorite status (UI only, needs backend)
- **User icon**: Open owner assignment dropdown
- **List icon**: Open list manager popup
- **Tag icon**: Open tag manager popup
- **Pipeline dropdown**: Change property status

### **Left Panel Actions:**
- **Street View image**: (Future) Open full-screen view
- **Start Mail button**: (Future) Launch mail campaign
- **@ icon**: Send email to contact
- **☎ icon**: Call contact
- **> icon**: Expand contact details

### **Right Panel Actions:**
- **Tab buttons**: Switch between Info/Comps/Mail/Activity
- **More Info buttons**: Expand sections
- **Search bar**: (Future) Search within property info

### **Footer Actions:**
- **Previous button**: Go to previous property in list
- **Next button**: Go to next property in list
- **View Property**: Open original listing URL in new tab

---

## 🎨 Visual Indicators

### **Badges with Counts:**
- **Green badge (👤¹, 🏷️³)**: Success/positive count
- **Blue badge (📋¹)**: Info/neutral count
- **Number shows**: How many items assigned

### **Property Badges:**
- **Off Market**: Property not actively listed
- **High Equity**: Great profit potential
- **Free And Clear**: No known liens
- **Senior Property**: Built before 1970

### **Contact Badges:**
- **✓ Agent**: Verified real estate agent
- **@ with number**: Number of email addresses
- **☎ with number**: Number of phone numbers

### **Tab States:**
- **Blue text + underline**: Active tab
- **Gray text**: Inactive tab
- **Hover**: Darkens to show interactivity

---

## 🚀 Pro Tips

1. **Fast Navigation**: Use arrow keys to quickly browse properties
2. **Batch Actions**: Assign to list first, then add tags later
3. **Status Tracking**: Update pipeline status as you progress
4. **Quick Contact**: Click email/phone icons for instant action
5. **Keyboard Shortcuts**: Master ESC and arrows for efficiency

---

## 🔧 Setup Required

### **For Google Street View:**
1. Get Google Maps API key
2. Add to `.env.local`:
   ```
   NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_key_here
   ```
3. Restart dev server

### **Without API Key:**
- Falls back to static map
- Then property photo
- Then placeholder icon

---

## 📊 Data Requirements

### **Minimum Required Fields:**
- `listing_id`: Unique identifier
- `street`: Property address
- `city`, `state`, `zip_code`: Location

### **Optional Fields (Enhance Display):**
- `list_price`: For valuation
- `beds`, `full_baths`, `sqft`: Property stats
- `year_built`: For age calculations
- `agent_name`, `agent_email`, `agent_phone`: Contact info
- `lat`, `lng`: For accurate maps
- `photos`, `photos_json`: Property images
- `text`: Full property description
- `last_sale_price`, `last_sale_date`: Historical data

### **Managed Fields (Auto-Updated):**
- `owner_id`: From owner selector
- `tags`: From tag manager
- `lists`: From list manager
- `pipeline_status`: From pipeline dropdown

---

## 🎬 Getting Started

1. **Open the modal**: Click "View Property" on any listing
2. **Explore the interface**: Click around, hover over icons
3. **Try shortcuts**: Use arrow keys to navigate
4. **Assign ownership**: Click 👤 icon and select owner
5. **Organize**: Add to lists and tags
6. **Update status**: Change pipeline status as needed
7. **Navigate**: Use Previous/Next to browse all leads

---

**Need Help?** Check the full documentation:
- `DEALMACHINE_MODAL_ANALYSIS.md`: Complete feature breakdown
- `DEALMACHINE_IMPLEMENTATION_SUMMARY.md`: Technical details
- `README.md`: General project setup

---

*Happy prospecting! 🏡*

