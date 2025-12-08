"""
Direct SQL Execution for Supabase using service role

This script attempts to execute SQL directly using various methods.
"""

import requests
import json

SUPABASE_URL = "https://bqkucdaefpfkunceftye.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxa3VjZGFlZnBma3VuY2VmdHllIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTEwNjYxNSwiZXhwIjoyMDc2NjgyNjE1fQ.o0ZT2Qtt344tXXuwMQJkWhtksPvcF1UpUKmD11wqKOk"

SQL_QUERY = """DROP POLICY IF EXISTS "All authenticated users can view fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can insert fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can update fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can delete fsbo_leads" ON fsbo_leads;
CREATE POLICY "All authenticated users can view fsbo_leads" ON fsbo_leads FOR SELECT USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');
CREATE POLICY "Authenticated users can insert fsbo_leads" ON fsbo_leads FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');
CREATE POLICY "Authenticated users can update fsbo_leads" ON fsbo_leads FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');
CREATE POLICY "Authenticated users can delete fsbo_leads" ON fsbo_leads FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');"""

def try_supabase_sql_api():
    """Try to execute SQL via Supabase SQL API endpoint"""
    # Supabase doesn't have a public SQL execution API endpoint
    # But we can try the management API or project API
    endpoints = [
        f"{SUPABASE_URL}/rest/v1/rpc/exec_sql",
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        f"https://api.supabase.com/v1/projects/bqkucdaefpfkunceftye/sql",
    ]
    
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }
    
    for endpoint in endpoints:
        try:
            print(f"Trying endpoint: {endpoint}")
            response = requests.post(
                endpoint,
                headers=headers,
                json={"query": SQL_QUERY},
                timeout=10
            )
            print(f"Response status: {response.status_code}")
            print(f"Response: {response.text[:200]}")
            if response.status_code == 200:
                return True
        except Exception as e:
            print(f"Error with {endpoint}: {e}")
            continue
    
    return False

if __name__ == "__main__":
    print("Attempting to execute SQL via Supabase API...")
    if not try_supabase_sql_api():
        print("\nDirect SQL execution via API is not available.")
        print("Please use Supabase Dashboard SQL Editor to execute the SQL.")

