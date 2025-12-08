/**
 * Create User Script for Supabase
 * 
 * This script creates a user using the Supabase Management API
 * 
 * Usage:
 * 1. Install dependencies: npm install @supabase/supabase-js
 * 2. Set environment variables:
 *    - SUPABASE_URL: Your Supabase project URL
 *    - SUPABASE_SERVICE_ROLE_KEY: Your service role key (from Dashboard → Settings → API)
 * 3. Run: node scripts/create_user.js
 */

const { createClient } = require('@supabase/supabase-js')
const fs = require('fs')
const path = require('path')

// Try to load .env.local file
function loadEnvFile() {
  const envPath = path.join(__dirname, '..', '.env.local')
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8')
    envContent.split('\n').forEach(line => {
      const match = line.match(/^([^=]+)=(.*)$/)
      if (match) {
        const key = match[1].trim()
        const value = match[2].trim().replace(/^["']|["']$/g, '')
        process.env[key] = value
      }
    })
  }
}

// Load .env.local if it exists
loadEnvFile()

// Get credentials from environment variables (check both NEXT_PUBLIC and regular versions)
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || 'YOUR_SUPABASE_URL'
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'YOUR_SERVICE_ROLE_KEY'

// Create Supabase admin client (uses service role key for admin operations)
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

async function createUser() {
  try {
    // Check if credentials are set
    if (supabaseUrl === 'YOUR_SUPABASE_URL' || supabaseServiceKey === 'YOUR_SERVICE_ROLE_KEY') {
      console.error('❌ Error: Supabase credentials not found!')
      console.error('\nPlease set the following environment variables:')
      console.error('  - NEXT_PUBLIC_SUPABASE_URL or SUPABASE_URL')
      console.error('  - SUPABASE_SERVICE_ROLE_KEY')
      console.error('\nOr create a .env.local file in the project root with:')
      console.error('  NEXT_PUBLIC_SUPABASE_URL=your-project-url')
      console.error('  SUPABASE_SERVICE_ROLE_KEY=your-service-role-key')
      console.error('\nYou can find these in: Supabase Dashboard → Settings → API')
      return
    }

    const email = 'tyquanwilkerson1118345@gmail.com'
    const password = 'Flower12!'

    console.log('Creating user...')
    console.log(`Email: ${email}`)
    console.log(`Supabase URL: ${supabaseUrl.substring(0, 30)}...`)

    // Create user using Admin API
    const { data, error } = await supabase.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true, // Auto-confirm email (skip verification)
      user_metadata: {
        name: 'Tyquan Wilkerson' // Optional: add name to metadata
      }
    })

    if (error) {
      console.error('Error creating user:', error)
      return
    }

    console.log('✅ User created successfully!')
    console.log('User ID:', data.user.id)
    console.log('Email:', data.user.email)
    console.log('\nNote: The user profile will be automatically created in the public.users table')
    console.log('via the handle_new_user() trigger.')

  } catch (err) {
    console.error('Unexpected error:', err)
  }
}

// Run the script
createUser()

