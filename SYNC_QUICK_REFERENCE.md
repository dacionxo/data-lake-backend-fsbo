# 🔄 Schema Sync Quick Reference

## Quick Commands

### Sync Both Directions
```powershell
cd "D:\Data Lake Backend"
.\scripts\sync-supabase-schemas.ps1
```

### Preview Changes (Safe)
```powershell
.\scripts\sync-supabase-schemas.ps1 -WhatIf
```

### Sync Data Lake → LeadMap
```powershell
.\scripts\sync-supabase-schemas.ps1 -Direction ToLeadMap
```

### Sync LeadMap → Data Lake
```powershell
.\scripts\sync-supabase-schemas.ps1 -Direction ToDataLake
```

## When to Sync

✅ **After modifying schemas in Data Lake Backend** → Run `-Direction ToLeadMap`  
✅ **After modifying schemas in LeadMap** → Run `-Direction ToDataLake`  
✅ **Before making changes** → Run `-WhatIf` to check current state  
✅ **Regular maintenance** → Run without parameters to sync both ways

## Workflow

1. Make schema changes
2. Test changes
3. Run sync script
4. Verify in both repositories
5. Commit to git

## Full Documentation

See [docs/SYNC_GUIDE.md](docs/SYNC_GUIDE.md) for complete details.
