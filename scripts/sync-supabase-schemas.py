#!/usr/bin/env python3
"""
Supabase Schema Synchronization Script
Syncs Supabase schema files between Data Lake Backend and LeadMap-main repositories

Usage:
    python sync-supabase-schemas.py [--direction both|to-leadmap|to-datalake] [--what-if]
"""

import os
import sys
import shutil
import hashlib
import argparse
from pathlib import Path
from typing import Dict, Tuple

# Define paths
DATA_LAKE_PATH = Path(r"D:\Downloads\Data Lake Backend\supabase")
LEADMAP_PATH = Path(r"d:\Downloads\LeadMap-main\LeadMap-main\supabase")


def get_file_hash(file_path: Path) -> str:
    """Calculate MD5 hash of a file."""
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


def get_sql_files(base_path: Path) -> Dict[str, Path]:
    """Get all SQL files recursively, excluding temp directories."""
    sql_files = {}
    
    for sql_file in base_path.rglob("*.sql"):
        # Skip temp directories
        if ".temp" in sql_file.parts or "__pycache__" in sql_file.parts:
            continue
        
        # Get relative path
        rel_path = sql_file.relative_to(base_path)
        sql_files[str(rel_path).replace("\\", "/")] = sql_file
    
    return sql_files


def sync_files(source_path: Path, dest_path: Path, direction_name: str, what_if: bool = False) -> Tuple[int, int, int]:
    """Sync files from source to destination."""
    print(f"\n📤 Syncing: {direction_name}")
    print(f"   From: {source_path}")
    print(f"   To:   {dest_path}\n")
    
    source_files = get_sql_files(source_path)
    dest_files = get_sql_files(dest_path)
    
    created = 0
    updated = 0
    skipped = 0
    
    for rel_path, source_file in source_files.items():
        dest_file = dest_path / rel_path
        
        # Create directory if it doesn't exist
        dest_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Check if file needs to be copied/updated
        if not dest_file.exists():
            print(f"   CREATE: {rel_path}")
            if not what_if:
                shutil.copy2(source_file, dest_file)
            created += 1
        else:
            # Compare file hashes
            source_hash = get_file_hash(source_file)
            dest_hash = get_file_hash(dest_file)
            
            if source_hash != dest_hash:
                print(f"   UPDATE: {rel_path}")
                if not what_if:
                    shutil.copy2(source_file, dest_file)
                updated += 1
            else:
                skipped += 1
    
    print(f"\n   Summary:")
    print(f"   - Created: {created}")
    print(f"   - Updated: {updated}")
    print(f"   - Skipped: {skipped}\n")
    
    return created, updated, skipped


def main():
    parser = argparse.ArgumentParser(description="Sync Supabase schemas between repositories")
    parser.add_argument(
        "--direction",
        choices=["both", "to-leadmap", "to-datalake"],
        default="both",
        help="Sync direction (default: both)"
    )
    parser.add_argument(
        "--what-if",
        action="store_true",
        help="Dry run - show what would be synced without making changes"
    )
    
    args = parser.parse_args()
    
    print("🔄 Supabase Schema Synchronization")
    print("=" * 40)
    print(f"\nData Lake Backend: {DATA_LAKE_PATH}")
    print(f"LeadMap-main:     {LEADMAP_PATH}")
    print(f"\nDirection: {args.direction}")
    if args.what_if:
        print("Mode: DRY RUN (no files will be modified)")
    print()
    
    # Verify paths exist
    if not DATA_LAKE_PATH.exists():
        print(f"❌ Error: Data Lake Backend path not found: {DATA_LAKE_PATH}")
        sys.exit(1)
    
    if not LEADMAP_PATH.exists():
        print(f"❌ Error: LeadMap-main path not found: {LEADMAP_PATH}")
        sys.exit(1)
    
    try:
        if args.direction in ["both", "to-leadmap"]:
            sync_files(
                DATA_LAKE_PATH,
                LEADMAP_PATH,
                "Data Lake → LeadMap",
                args.what_if
            )
        
        if args.direction in ["both", "to-datalake"]:
            sync_files(
                LEADMAP_PATH,
                DATA_LAKE_PATH,
                "LeadMap → Data Lake",
                args.what_if
            )
        
        print("✅ Synchronization complete!")
        
        if args.what_if:
            print("\n💡 This was a dry run. Run without --what-if to apply changes.")
    
    except Exception as e:
        print(f"❌ Synchronization failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

