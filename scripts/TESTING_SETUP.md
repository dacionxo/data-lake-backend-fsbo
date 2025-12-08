# Email Marketing Testing Setup Guide

This guide explains how to set up and run the integration tests for the email marketing system.

## ✅ Test Framework Complete

All 10 critical fixes now have comprehensive test coverage:
1. ✅ List-based recipient selection
2. ✅ Pause/resume/cancel workflows  
3. ✅ Reply detection
4. ✅ Bounce handling
5. ✅ Unsubscribe enforcement
6. ✅ Retry logic
7. ✅ Error handling
8. ✅ Cron security
9. ✅ Outlook messageId
10. ✅ Integration scenarios

## 📦 Installation

### Step 1: Install Test Dependencies

```bash
npm install --save-dev jest @types/jest jest-environment-node
```

### Step 2: Verify Configuration

The following files are already configured:
- ✅ `jest.config.js` - Jest configuration
- ✅ `jest.setup.js` - Test environment setup
- ✅ `package.json` - Test scripts added

## 🧪 Running Tests

### Run All Tests

```bash
npm test
```

### Run Tests in Watch Mode

```bash
npm test -- --watch
```

### Run Tests with Coverage

```bash
npm test -- --coverage
```

### Run Specific Test File

```bash
npm test integration.test.ts
npm test unit.test.ts
```

## 📝 Test Structure

```
__tests__/
  email-marketing/
    integration.test.ts  # Full integration tests
    unit.test.ts         # Unit tests for utilities
    README.md            # Test documentation
```

## 🔧 Test Configuration

### Environment Variables

Tests use these environment variables (set in `jest.setup.js`):

- `NEXT_PUBLIC_SUPABASE_URL` - Test Supabase instance
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for tests
- `CRON_SECRET` - Test cron secret
- `CALENDAR_SERVICE_KEY` - Test calendar key
- `NEXT_PUBLIC_APP_URL` - Test app URL
- `EMAIL_WEBHOOK_SECRET` - Test webhook secret

### Test Database

⚠️ **Important:** Use a separate test database or ensure tests clean up after themselves.

The integration tests include cleanup logic in `afterAll()` hooks.

## 📊 Test Coverage

### Integration Tests (`integration.test.ts`)

1. **List-Based Recipient Selection**
   - Campaign creation with listIds
   - Recipient deduplication
   - List membership fetching

2. **Pause/Resume/Cancel Workflows**
   - Status validation
   - Pre-send status checks
   - Campaign state transitions

3. **Reply Detection**
   - In-Reply-To header detection
   - References header detection
   - Stop-on-reply enforcement

4. **Bounce Handling**
   - Hard bounce recording
   - Automatic unsubscribe
   - Bounce status checks

5. **Unsubscribe Enforcement**
   - Link generation
   - Pre-send checks
   - Status updates

6. **Retry Logic**
   - Transient failure detection
   - Permanent failure detection
   - Exponential backoff

7. **Error Handling**
   - Gmail error details
   - Outlook error details
   - Graceful fallbacks

8. **Cron Security**
   - CRON_SECRET validation
   - Unauthorized rejection
   - Security logging

9. **Outlook MessageId**
   - Real ID fetching
   - Fallback handling

10. **Integration Scenarios**
    - Complete workflows
    - Edge cases
    - Error recovery

### Unit Tests (`unit.test.ts`)

- Unsubscribe utilities
- Retry logic functions
- Reply detection utilities

## ✅ Test Checklist

Before running tests, verify:

- [ ] Test dependencies installed (`npm install`)
- [ ] Environment variables configured
- [ ] Test database accessible (or mocks configured)
- [ ] No conflicting test data in database

## 🐛 Troubleshooting

### "Module not found" errors

```bash
npm install --save-dev jest @types/jest jest-environment-node
```

### "Cannot find module" for @ imports

Ensure `jest.config.js` has:
```javascript
moduleNameMapper: {
  '^@/(.*)$': '<rootDir>/$1',
}
```

### Tests timeout

Increase timeout in test file:
```javascript
jest.setTimeout(60000) // 60 seconds
```

### Database connection errors

- Check environment variables
- Verify Supabase URL is correct
- Ensure service role key has proper permissions

## 🚀 CI/CD Integration

### GitHub Actions Example

```yaml
name: Email Marketing Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm install
      - run: npm test
        env:
          NEXT_PUBLIC_SUPABASE_URL: ${{ secrets.TEST_SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.TEST_SERVICE_KEY }}
          CRON_SECRET: ${{ secrets.TEST_CRON_SECRET }}
```

## 📈 Next Steps

1. **Run Tests Locally:** `npm test`
2. **Review Coverage:** `npm test -- --coverage`
3. **Add to CI/CD:** Integrate into your pipeline
4. **Expand Coverage:** Add tests for edge cases
5. **Mock External APIs:** Avoid rate limits in tests

## 📚 Additional Resources

- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Next.js Testing Guide](https://nextjs.org/docs/testing)
- Test files include inline documentation

---

**Status:** ✅ Test Framework Complete and Ready for Use



