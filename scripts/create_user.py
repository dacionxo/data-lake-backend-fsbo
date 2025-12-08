"""
Create User Script for Supabase

This script creates a user using the Supabase Management API

Usage:
1. Install dependencies: pip install supabase
2. Set environment variables:
   - SUPABASE_URL: Your Supabase project URL
   - SUPABASE_SERVICE_ROLE_KEY: Your service role key (from Dashboard → Settings → API)
3. Run: python scripts/create_user.py
"""

import os
from supabase import create_client, Client

# Get credentials from environment variables
supabase_url = os.getenv('SUPABASE_URL', 'YOUR_SUPABASE_URL')
supabase_service_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY', 'YOUR_SERVICE_ROLE_KEY')

# Create Supabase admin client
supabase: Client = create_client(supabase_url, supabase_service_key)

def create_user():
    try:
        email = 'tyquanwilkerson1118345@gmail.com'
        password = 'Flower12!'
        
        print('Creating user...')
        print(f'Email: {email}')
        
        # Create user using Admin API
        response = supabase.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True,  # Auto-confirm email (skip verification)
            "user_metadata": {
                "name": "Tyquan Wilkerson"  # Optional: add name to metadata
            }
        })
        
        if response.user:
            print('✅ User created successfully!')
            print(f'User ID: {response.user.id}')
            print(f'Email: {response.user.email}')
            print('\nNote: The user profile will be automatically created in the public.users table')
            print('via the handle_new_user() trigger.')
        else:
            print('Error: Failed to create user')
            if hasattr(response, 'error'):
                print(f'Error details: {response.error}')
                
    except Exception as e:
        print(f'Unexpected error: {e}')

if __name__ == '__main__':
    create_user()

