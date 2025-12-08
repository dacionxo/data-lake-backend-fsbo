"""
Update FSBO Leads RLS Policies Script

This script uses the Supabase Python client with service role key
to update RLS policies by executing SQL via psql or providing instructions.
"""

import subprocess
import sys
import os

# Supabase configuration
SUPABASE_URL = "https://bqkucdaefpfkunceftye.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxa3VjZGFlZnBma3VuY2VmdHllIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTEwNjYxNSwiZXhwIjoyMDc2NjgyNjE1fQ.o0ZT2Qtt344tXXuwMQJkWhtksPvcF1UpUKmD11wqKOk"

# SQL to execute
SQL_QUERY = """-- Drop existing policies
DROP POLICY IF EXISTS "All authenticated users can view fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can insert fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can update fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can delete fsbo_leads" ON fsbo_leads;

-- Recreate policies with service_role support
CREATE POLICY "All authenticated users can view fsbo_leads" ON fsbo_leads
  FOR SELECT USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can insert fsbo_leads" ON fsbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can update fsbo_leads" ON fsbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can delete fsbo_leads" ON fsbo_leads
  FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');
"""

def execute_with_supabase_client():
    """Try to execute using Supabase Python client"""
    try:
        from supabase import create_client, Client
        
        print("Connecting to Supabase with service role key...")
        supabase: Client = create_client(SUPABASE_URL, SERVICE_ROLE_KEY)
        
        # Test connection by trying to query the table
        try:
            result = supabase.table('fsbo_leads').select('listing_id').limit(1).execute()
            print("✓ Successfully connected to Supabase")
        except Exception as e:
            print(f"Connection test failed: {e}")
            return False
        
        # Supabase Python client doesn't support raw SQL execution
        # We need to use psql or the dashboard
        print("\nNote: Supabase Python client doesn't support raw SQL execution.")
        print("The service role key allows bypassing RLS, but SQL execution")
        print("must be done via Supabase Dashboard SQL Editor or psql.")
        return False
        
    except ImportError:
        print("supabase package not found. Install with: pip install supabase")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    """Main execution"""
    print("="*70)
    print("FSBO Leads RLS Policy Update")
    print("="*70)
    print()
    
    # Try Supabase client connection test
    execute_with_supabase_client()
    
    print("\n" + "="*70)
    print("SQL QUERY TO EXECUTE")
    print("="*70)
    print(SQL_QUERY)
    print("="*70)
    
    print("\n" + "="*70)
    print("INSTRUCTIONS")
    print("="*70)
    print("\nTo update the RLS policies, execute the SQL above using one of:")
    print("\nOption 1: Supabase Dashboard (Recommended)")
    print("  1. Go to: https://supabase.com/dashboard")
    print("  2. Select your project")
    print("  3. Navigate to: SQL Editor")
    print("  4. Click 'New Query'")
    print("  5. Copy and paste the SQL query above")
    print("  6. Click 'Run' (or press Ctrl+Enter)")
    print("\nOption 2: Supabase CLI (if installed)")
    print("  supabase db execute --file update_fsbo_rls_policies.sql")
    print("\nOption 3: psql (if you have database connection string)")
    print("  psql 'your-connection-string' -f update_fsbo_rls_policies.sql")
    print("="*70)
    
    print("\nAfter executing the SQL, you can re-run your Python script:")
    print("  python push_csv_to_supabase.py")
    print()

if __name__ == "__main__":
    main()
