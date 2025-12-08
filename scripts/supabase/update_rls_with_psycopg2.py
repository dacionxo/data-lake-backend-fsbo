"""
Update FSBO RLS Policies using psycopg2 (Direct PostgreSQL Connection)

This script requires the database password from Supabase Dashboard.
Get it from: Settings → Database → Connection String → URI
"""

import os
import sys

# Supabase configuration
SUPABASE_URL = "https://bqkucdaefpfkunceftye.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxa3VjZGFlZnBma3VuY2VmdHllIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTEwNjYxNSwiZXhwIjoyMDc2NjgyNjE1fQ.o0ZT2Qtt344tXXuwMQJkWhtksPvcF1UpUKmD11wqKOk"

# Extract project reference
PROJECT_REF = "bqkucdaefpfkunceftye"

SQL_QUERY = """
DROP POLICY IF EXISTS "All authenticated users can view fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can insert fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can update fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can delete fsbo_leads" ON fsbo_leads;

CREATE POLICY "All authenticated users can view fsbo_leads" ON fsbo_leads
  FOR SELECT USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can insert fsbo_leads" ON fsbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can update fsbo_leads" ON fsbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can delete fsbo_leads" ON fsbo_leads
  FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');
"""

def execute_with_psycopg2():
    """Execute SQL using psycopg2"""
    try:
        import psycopg2
        from urllib.parse import quote_plus
        
        # Get database password from environment or prompt
        db_password = os.getenv('SUPABASE_DB_PASSWORD')
        
        if not db_password:
            print("="*70)
            print("DATABASE PASSWORD REQUIRED")
            print("="*70)
            print("\nTo get your database password:")
            print("1. Go to: https://supabase.com/dashboard")
            print("2. Select your project")
            print("3. Go to: Settings → Database")
            print("4. Find 'Connection string' section")
            print("5. Copy the password from the URI")
            print("\nThen set it as an environment variable:")
            print("  $env:SUPABASE_DB_PASSWORD='your-password'")
            print("  python update_rls_with_psycopg2.py")
            print("\nOr provide it when prompted below:")
            print("="*70)
            
            db_password = input("\nEnter database password (or press Enter to skip): ").strip()
            if not db_password:
                print("Skipping direct execution. Please use Supabase Dashboard SQL Editor.")
                return False
        
        # Build connection string
        # Format: postgresql://postgres:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres
        conn_string = f"postgresql://postgres:{quote_plus(db_password)}@db.{PROJECT_REF}.supabase.co:5432/postgres"
        
        print("\nConnecting to PostgreSQL...")
        conn = psycopg2.connect(conn_string)
        conn.autocommit = True
        cursor = conn.cursor()
        
        print("Executing SQL to update RLS policies...")
        cursor.execute(SQL_QUERY)
        
        print("✓ Successfully updated RLS policies!")
        print("✓ Policies now allow both 'authenticated' and 'service_role'")
        
        cursor.close()
        conn.close()
        return True
        
    except ImportError:
        print("psycopg2 not found. Install with: pip install psycopg2-binary")
        return False
    except psycopg2.OperationalError as e:
        print(f"Connection error: {e}")
        print("Please verify your database password is correct.")
        return False
    except Exception as e:
        print(f"Error executing SQL: {e}")
        return False

if __name__ == "__main__":
    print("="*70)
    print("FSBO Leads RLS Policy Update (Direct PostgreSQL)")
    print("="*70)
    print()
    
    if execute_with_psycopg2():
        print("\n" + "="*70)
        print("SUCCESS!")
        print("="*70)
        print("\nYou can now re-run your Python script:")
        print("  python push_csv_to_supabase.py")
        print()
    else:
        print("\n" + "="*70)
        print("ALTERNATIVE: Use Supabase Dashboard")
        print("="*70)
        print("\n1. Go to: https://supabase.com/dashboard")
        print("2. Select your project")
        print("3. Navigate to: SQL Editor")
        print("4. Copy and paste the SQL from: update_fsbo_rls_policies.sql")
        print("5. Click 'Run'")
        print("="*70)

