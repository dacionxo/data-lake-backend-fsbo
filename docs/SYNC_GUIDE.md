# Supabase Schema Synchronization Guide

This guide explains how to keep Supabase schema files synchronized between the **Data Lake Backend** and **LeadMap-main** repositories.

## 🎯 Purpose

Since the Data Lake Backend is responsible for all property data added to the website, it's critical that Supabase schema changes are synchronized bidirectionally between:

- `D:\Data Lake Backend\supabase\`
- `d:\Downloads\LeadMap-main\LeadMap-main\supabase\`

## 🔄 Synchronization Methods

### Method 1: PowerShell Script (Windows)

**Location:** `scripts\sync-supabase-schemas.ps1`

#### Basic Usage

```powershell
# Sync both directions (default)
.\scripts\sync-supabase-schemas.ps1

# Sync only from Data Lake to LeadMap
.\scripts\sync-supabase-schemas.ps1 -Direction ToLeadMap

# Sync only from LeadMap to Data Lake
.\scripts\sync-supabase-schemas.ps1 -Direction ToDataLake

# Dry run (see what would change without making changes)
.\scripts\sync-supabase-schemas.ps1 -WhatIf
```

#### Examples

```powershell
# Check what would be synced (safe to run anytime)
cd "D:\Data Lake Backend"
.\scripts\sync-supabase-schemas.ps1 -WhatIf

# Actually sync both directions
.\scripts\sync-supabase-schemas.ps1

# After modifying schemas in LeadMap, sync to Data Lake
.\scripts\sync-supabase-schemas.ps1 -Direction ToDataLake
```

### Method 2: Python Script (Cross-platform)

**Location:** `scripts\sync-supabase-schemas.py`

#### Basic Usage

```bash
# Sync both directions (default)
python scripts/sync-supabase-schemas.py

# Sync only from Data Lake to LeadMap
python scripts/sync-supabase-schemas.py --direction to-leadmap

# Sync only from LeadMap to Data Lake
python scripts/sync-supabase-schemas.py --direction to-datalake

# Dry run
python scripts/sync-supabase-schemas.py --what-if
```

## 📋 Workflow Recommendations

### When Modifying Schemas in Data Lake Backend

1. Make your changes in `D:\Data Lake Backend\supabase\`
2. Test your changes
3. Sync to LeadMap:
   ```powershell
   cd "D:\Data Lake Backend"
   .\scripts\sync-supabase-schemas.ps1 -Direction ToLeadMap
   ```
4. Verify changes in LeadMap repository

### When Modifying Schemas in LeadMap

1. Make your changes in `d:\Downloads\LeadMap-main\LeadMap-main\supabase\`
2. Test your changes
3. Sync to Data Lake:
   ```powershell
   cd "D:\Data Lake Backend"
   .\scripts\sync-supabase-schemas.ps1 -Direction ToDataLake
   ```
4. Verify changes in Data Lake repository

### Regular Maintenance

Run a bidirectional sync periodically to ensure both repositories are in sync:

```powershell
cd "D:\Data Lake Backend"
.\scripts\sync-supabase-schemas.ps1
```

## 🔍 How It Works

The sync script:

1. **Scans** both directories for all `.sql` files recursively
2. **Compares** files by MD5 hash to detect changes
3. **Copies** files that are:
   - New (exist in source but not destination)
   - Modified (different hash)
4. **Skips** files that are identical
5. **Preserves** directory structure

### What Gets Synced

- ✅ All `.sql` files (schema files, migrations, etc.)
- ✅ Directory structure is preserved
- ✅ Edge Functions SQL files

### What Gets Excluded

- ❌ `.temp/` directories
- ❌ `__pycache__/` directories
- ❌ Non-SQL files

## ⚠️ Important Notes

1. **Always test first**: Use `-WhatIf` or `--what-if` to preview changes
2. **Backup before syncing**: Consider committing changes to git before syncing
3. **One-way conflicts**: If the same file differs in both locations, the script will overwrite the destination with the source
4. **Manual review**: After syncing, review the changes to ensure they're correct

## 🚨 Conflict Resolution

If the same file has been modified in both repositories:

1. The sync script will overwrite the destination with the source
2. To merge changes manually:
   - Use a diff tool to compare files
   - Manually merge the changes
   - Re-sync in the appropriate direction

## 🔧 Troubleshooting

### Script can't find paths

**Error:** `Path not found`

**Solution:** Update the paths in the script to match your actual directory structure:
- PowerShell: Edit `$DataLakePath` and `$LeadMapPath` variables
- Python: Edit `DATA_LAKE_PATH` and `LEADMAP_PATH` constants

### Permission errors

**Error:** `Access denied` or `Permission denied`

**Solution:** 
- Run PowerShell as Administrator
- Check file permissions
- Ensure files aren't locked by another process

### Files not syncing

**Issue:** Files exist but aren't being synced

**Solution:**
- Check that files have `.sql` extension
- Verify files aren't in excluded directories (`.temp`, `__pycache__`)
- Run with `-WhatIf` to see what would be synced

## 📝 Best Practices

1. **Sync before major changes**: Always sync before making schema modifications
2. **Sync after changes**: Sync immediately after modifying schemas
3. **Use version control**: Commit changes to git before and after syncing
4. **Document changes**: Note what was changed and why
5. **Test after sync**: Verify that synced changes work correctly

## 🔗 Integration with Git

### Recommended Git Workflow

```bash
# 1. Make schema changes
# 2. Commit to Data Lake Backend
git add supabase/
git commit -m "Update schema: [description]"

# 3. Sync to LeadMap
.\scripts\sync-supabase-schemas.ps1 -Direction ToLeadMap

# 4. Commit to LeadMap
cd "d:\Downloads\LeadMap-main\LeadMap-main"
git add supabase/
git commit -m "Sync schema from Data Lake Backend: [description]"
```

## 📞 Support

If you encounter issues with synchronization:

1. Check the error message
2. Verify paths are correct
3. Run with `-WhatIf` to preview changes
4. Check file permissions
5. Review the troubleshooting section above
