/**
 * Create User Script for Supabase (Simple HTTP Version)
 * 
 * This script creates a user using direct HTTP requests to Supabase Management API
 */

const fs = require('fs')
const path = require('path')

// Try to load .env.local file
function loadEnvFile() {
  // Try multiple possible paths
  const possiblePaths = [
    path.join(__dirname, '..', '.env.local'),
    path.join(process.cwd(), '.env.local'),
    '.env.local'
  ]
  
  for (const envPath of possiblePaths) {
    if (fs.existsSync(envPath)) {
      console.log(`Loading environment from: ${envPath}`)
      const envContent = fs.readFileSync(envPath, 'utf8')
      envContent.split(/\r?\n/).forEach(line => {
        // Skip comments and empty lines
        if (line.trim().startsWith('#') || !line.trim()) return
        
        const match = line.match(/^([^=]+)=(.*)$/)
        if (match) {
          const key = match[1].trim()
          let value = match[2].trim()
          // Remove quotes if present
          value = value.replace(/^["']|["']$/g, '')
          process.env[key] = value
        }
      })
      return true
    }
  }
  return false
}

// Load .env.local if it exists
const envLoaded = loadEnvFile()

// Get credentials from environment variables
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (envLoaded) {
  console.log('Environment file loaded')
}

async function createUser() {
  try {
    // Check if credentials are set
    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('❌ Error: Supabase credentials not found!')
      console.error('\nPlease ensure .env.local contains:')
      console.error('  NEXT_PUBLIC_SUPABASE_URL=your-project-url')
      console.error('  SUPABASE_SERVICE_ROLE_KEY=your-service-role-key')
      return
    }

    const email = 'tyquanwilkerson1118345@gmail.com'
    const password = 'Flower12!'

    console.log('Creating user...')
    console.log(`Email: ${email}`)
    console.log(`Supabase URL: ${supabaseUrl.substring(0, 30)}...`)

    // Use fetch API (available in Node.js 18+)
    const response = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
      method: 'POST',
      headers: {
        'apikey': supabaseServiceKey,
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email: email,
        password: password,
        email_confirm: true, // Auto-confirm email (skip verification)
        user_metadata: {
          name: 'Tyquan Wilkerson'
        }
      })
    })

    const data = await response.json()

    if (!response.ok) {
      console.error('❌ Error creating user:')
      console.error(JSON.stringify(data, null, 2))
      return
    }

    console.log('✅ User created successfully!')
    console.log('User ID:', data.id)
    console.log('Email:', data.email)
    console.log('\nNote: The user profile will be automatically created in the public.users table')
    console.log('via the handle_new_user() trigger.')

  } catch (err) {
    console.error('❌ Unexpected error:', err.message)
    if (err.message.includes('fetch')) {
      console.error('\nNote: This script requires Node.js 18+ with fetch API support.')
      console.error('Alternatively, use the Supabase Dashboard method.')
    }
  }
}

// Run the script
createUser()

