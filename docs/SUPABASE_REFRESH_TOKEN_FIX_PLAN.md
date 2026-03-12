# Supabase Refresh Token Fix Plan

## 🔴 Critical Issues Identified

### Error: `Invalid Refresh Token: Refresh Token Not Found`
### Rate Limit: 800 requests/min on `/auth/v1/token?grant_type=refresh_token`

## 📋 Root Causes

1. **Multiple Client Instances**: Creating new Supabase clients on every render/request
2. **Manual Refresh Loops**: Code calling `refreshSession()` in loops or intervals
3. **Server-Side Auto-Refresh**: Server components/API routes using auto-refresh (should use service role)
4. **Stale/Invalid Tokens**: Trying to refresh tokens that don't exist or are expired
5. **No Error Handling**: Not clearing invalid tokens when refresh fails
6. **Cron Jobs**: May be using user tokens instead of service role keys

## ✅ Fix Checklist

### Phase 1: Client Singleton Pattern (CRITICAL)

- [ ] **Fix 1.1**: Create global Supabase client singleton
  - File: `lib/supabase-singleton.ts` (NEW)
  - Ensure only ONE client instance exists per environment
  - Use window-level caching for client-side
  - Use module-level caching for server-side

- [ ] **Fix 1.2**: Update `app/providers.tsx`
  - Remove client creation from useMemo
  - Import singleton client instead
  - Remove window.__supabaseClient hack

- [ ] **Fix 1.3**: Update `app/page.tsx`
  - Use cached server client from singleton
  - Don't create new client on every request

- [ ] **Fix 1.4**: Update `lib/supabase-client-cache.ts`
  - Make it a true singleton
  - Persist across all renders/requests
  - Clear cache only on explicit logout

### Phase 2: Remove Manual Refresh Calls

- [ ] **Fix 2.1**: Remove `getSession()` from providers.tsx
  - Use `onAuthStateChange` events only
  - Don't poll for session state
  - Let Supabase client handle refresh automatically

- [ ] **Fix 2.2**: Search and remove all `refreshSession()` calls
  - Files to check:
    - All components
    - All API routes
    - All cron jobs
  - Replace with proper error handling

- [ ] **Fix 2.3**: Remove any `setInterval` or `setTimeout` with auth calls
  - Check for polling patterns
  - Replace with event-driven approach

### Phase 3: Server-Side Fixes

- [ ] **Fix 3.1**: Update all API routes
  - Use service role key for backend operations
  - Set `autoRefreshToken: false`
  - Don't use user tokens for server operations

- [ ] **Fix 3.2**: Update all cron jobs
  - Files:
    - `app/api/cron/process-emails/route.ts`
    - `app/api/calendar/cron/token-refresh/route.ts`
    - `app/api/cron/sync-mailboxes/route.ts`
    - `app/api/cron/gmail-watch-renewal/route.ts`
  - Ensure they use service role key
  - Set `autoRefreshToken: false`

- [ ] **Fix 3.3**: Update all server components
  - Use `getServerComponentClient()` from cache
  - Don't create new clients

### Phase 4: Error Handling & Token Management

- [ ] **Fix 4.1**: Handle invalid refresh tokens
  - When refresh fails with "token not found":
    - Clear cookies/localStorage
    - Redirect to login
    - Don't retry

- [ ] **Fix 4.2**: Add refresh token validation
  - Check if token exists before refresh
  - Check if token is expired
  - Don't attempt refresh on invalid tokens

- [ ] **Fix 4.3**: Add circuit breaker
  - Stop refresh attempts after 3 consecutive failures
  - Exponential backoff: 1s, 2s, 4s, 8s
  - Reset on successful auth

- [ ] **Fix 4.4**: Clear invalid tokens
  - On refresh failure, clear:
    - Cookies (all Supabase auth cookies)
    - localStorage (if used)
    - Session storage

### Phase 5: Rate Limiting & Backoff

- [ ] **Fix 5.1**: Add exponential backoff to all auth operations
  - Current: 30s throttle in providers.tsx
  - Increase to: 60s minimum between refresh attempts
  - Max backoff: 5 minutes

- [ ] **Fix 5.2**: Add request deduplication
  - If refresh is in progress, don't start another
  - Queue requests instead of parallel calls

- [ ] **Fix 5.3**: Add rate limit detection
  - Detect 429 errors
  - Automatically back off
  - Log warnings

### Phase 6: Monitoring & Debugging

- [ ] **Fix 6.1**: Add refresh token logging
  - Log all refresh attempts
  - Log success/failure
  - Track source (component/route/cron)

- [ ] **Fix 6.2**: Add metrics
  - Count refresh attempts per minute
  - Alert if > 10/min
  - Track which code path triggers most refreshes

- [ ] **Fix 6.3**: Add debugging endpoint
  - `/api/debug/auth-status`
  - Shows current session state
  - Shows refresh token status
  - Shows client instances

## 🚀 Implementation Priority

### CRITICAL (Do First)
1. Fix client singleton pattern
2. Remove getSession() from providers.tsx
3. Fix server-side client creation
4. Add invalid token handling

### HIGH (Do Next)
5. Update all API routes to use service role
6. Fix cron jobs
7. Add circuit breaker

### MEDIUM (Do After)
8. Add monitoring
9. Add rate limit detection
10. Add request deduplication

## 📝 Code Patterns to Fix

### ❌ BAD Pattern 1: Creating clients in components
```typescript
// DON'T DO THIS
function MyComponent() {
  const supabase = createClientComponentClient()
  // ...
}
```

### ✅ GOOD Pattern 1: Using singleton
```typescript
// DO THIS
import { getClient } from '@/lib/supabase-singleton'

function MyComponent() {
  const supabase = getClient()
  // ...
}
```

### ❌ BAD Pattern 2: Manual refresh in loops
```typescript
// DON'T DO THIS
useEffect(() => {
  const interval = setInterval(async () => {
    await supabase.auth.refreshSession()
  }, 1000)
  return () => clearInterval(interval)
}, [])
```

### ✅ GOOD Pattern 2: Event-driven
```typescript
// DO THIS
useEffect(() => {
  const { data: { subscription } } = supabase.auth.onAuthStateChange(
    (event, session) => {
      // Handle auth changes
    }
  )
  return () => subscription.unsubscribe()
}, [])
```

### ❌ BAD Pattern 3: Server-side with auto-refresh
```typescript
// DON'T DO THIS (in API routes)
const supabase = createClient(url, anonKey)
```

### ✅ GOOD Pattern 3: Service role for backend
```typescript
// DO THIS (in API routes)
const supabase = createClient(url, serviceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})
```

## 🔍 Files to Modify

### High Priority
1. `lib/supabase-singleton.ts` (CREATE NEW)
2. `app/providers.tsx`
3. `app/page.tsx`
4. `lib/supabase-client-cache.ts`
5. `app/api/calendar/cron/token-refresh/route.ts`
6. `app/api/cron/process-emails/route.ts`

### Medium Priority
7. All API routes in `app/api/`
8. All server components
9. All cron jobs

### Low Priority
10. Add monitoring/logging
11. Add debugging tools

## 🧪 Testing Checklist

- [ ] Test with no users (should not hit refresh endpoint)
- [ ] Test with one user (should refresh max 1x per hour)
- [ ] Test with invalid token (should clear and redirect)
- [ ] Test rate limit handling (should back off)
- [ ] Test multiple tabs (should share client instance)
- [ ] Test server-side operations (should use service role)
- [ ] Test cron jobs (should not use user tokens)

## 📊 Success Metrics

- ✅ Refresh requests: < 10 per minute (currently 800)
- ✅ No "Invalid Refresh Token" errors
- ✅ No 429 rate limit errors
- ✅ Single client instance per environment
- ✅ Proper error handling and user feedback

