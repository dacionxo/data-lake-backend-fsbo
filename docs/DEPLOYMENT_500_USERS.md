# Deployment Guide: 500 Concurrent Users

Step-by-step guide for deploying and configuring the system to support 500 concurrent users.

## 📋 Pre-Deployment Checklist

### Database Optimizations

1. **Apply Schema Files in Order:**
   ```bash
   # 1. Base schema
   psql $DATABASE_URL -f scripts/supabase/complete_schema.sql
   
   # 2. Scalability optimizations (CRITICAL for 500 users)
   psql $DATABASE_URL -f scripts/supabase/scalability_optimizations.sql
   ```

2. **Verify Indexes Created:**
   ```sql
   -- Check critical indexes exist
   SELECT indexname, tablename 
   FROM pg_indexes 
   WHERE schemaname = 'public' 
   AND indexname LIKE 'idx_%user%'
   ORDER BY tablename, indexname;
   ```

3. **Schedule Materialized View Refreshes:**
   ```sql
   -- Enable pg_cron extension
   CREATE EXTENSION IF NOT EXISTS pg_cron;
   
   -- Schedule refresh every 15 minutes
   SELECT cron.schedule(
     'refresh-dashboard-views',
     '*/15 * * * *',
     'SELECT refresh_dashboard_views_for_users();'
   );
   ```

### Supabase Configuration

1. **Connection Pooling:**
   - Go to Supabase Dashboard → Settings → Database
   - Enable connection pooler
   - Set pool mode to "Transaction"
   - Recommended pool size: 100-200 connections

2. **Database Settings:**
   - Enable query timeout: 30 seconds
   - Set statement timeout: 30 seconds
   - Enable query performance monitoring

3. **RLS Policies:**
   - Verify all policies include `deleted_at IS NULL` for user tables
   - Test policies with multiple concurrent users

### LeadMap-main Configuration

1. **Update API Routes:**
   ```typescript
   // Use connection pooler URL
   const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
   // Should be: https://[project].pooler.supabase.com
   
   // Always filter deleted records
   const { data } = await supabase
     .from('contacts')
     .select('*')
     .eq('user_id', userId)
     .is('deleted_at', null); // CRITICAL
   ```

2. **Implement Pagination:**
   ```typescript
   // All list queries must paginate
   export async function GET(request: Request) {
     const { searchParams } = new URL(request.url);
     const page = parseInt(searchParams.get('page') || '1');
     const limit = 50; // Max 50 per page
     const offset = (page - 1) * limit;
     
     const { data, count } = await supabase
       .from('contacts')
       .select('*', { count: 'exact' })
       .eq('user_id', userId)
       .is('deleted_at', null)
       .range(offset, offset + limit - 1);
     
     return Response.json({ data, count, page, limit });
   }
   ```

3. **Add Caching:**
   ```typescript
   // Cache dashboard data
   import { unstable_cache } from 'next/cache';
   
   export const getDashboardData = unstable_cache(
     async (userId: string) => {
       // Fetch dashboard data
     },
     ['dashboard'],
     { revalidate: 900 } // 15 minutes
   );
   ```

## 🔍 Monitoring Setup

### 1. Database Monitoring

```sql
-- Create monitoring dashboard query
CREATE VIEW database_performance_monitor AS
SELECT 
  (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') AS active_connections,
  (SELECT COUNT(*) FROM pg_stat_activity 
   WHERE state = 'active' AND query_start < NOW() - INTERVAL '30 seconds') AS slow_queries,
  (SELECT COUNT(*) FROM pg_stat_activity WHERE wait_event_type IS NOT NULL) AS waiting_queries,
  (SELECT MAX(EXTRACT(EPOCH FROM (NOW() - query_start))) FROM pg_stat_activity WHERE state = 'active') AS max_query_duration;
```

### 2. Application Monitoring

Set up alerts for:
- API response time > 500ms
- Database connection pool utilization > 80%
- Error rate > 1%
- Slow queries > 10 concurrent

## ✅ Verification Tests

### Test 1: Concurrent User Access

```bash
# Simulate 500 concurrent users querying dashboard
for i in {1..500}; do
  curl -X GET "https://your-app.com/api/dashboard" \
    -H "Authorization: Bearer $TOKEN_$i" &
done
wait
```

**Expected:** All requests complete in < 500ms

### Test 2: Pagination Performance

```bash
# Test pagination with large datasets
curl "https://your-app.com/api/contacts?page=1&limit=50"
curl "https://your-app.com/api/contacts?page=10&limit=50"
curl "https://your-app.com/api/contacts?page=100&limit=50"
```

**Expected:** Consistent response times regardless of page number

### Test 3: Materialized View Performance

```sql
-- Compare materialized view vs direct query
EXPLAIN ANALYZE SELECT * FROM source_health_summary;
EXPLAIN ANALYZE 
SELECT fsbo_source, COUNT(*) 
FROM fsbo_leads 
GROUP BY fsbo_source;
```

**Expected:** Materialized view query is 10-100x faster

## 🚀 Production Deployment Steps

1. **Backup Database**
   ```bash
   pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql
   ```

2. **Apply Optimizations**
   ```bash
   psql $DATABASE_URL -f scripts/supabase/scalability_optimizations.sql
   ```

3. **Verify Indexes**
   ```sql
   SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';
   -- Should see 100+ indexes
   ```

4. **Test with Staging**
   - Deploy to staging environment
   - Run load tests with 500 concurrent users
   - Verify all queries use indexes (EXPLAIN ANALYZE)

5. **Deploy to Production**
   - Apply during low-traffic window
   - Monitor connection pool utilization
   - Watch for slow queries

6. **Post-Deployment**
   - Verify materialized views are refreshing
   - Check dashboard response times
   - Monitor error rates

## 📊 Performance Benchmarks

### Target Metrics (500 Users)

| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| API Response Time | < 200ms | > 500ms |
| Database Query Time | < 100ms | > 300ms |
| Concurrent Connections | < 150 | > 200 |
| Slow Queries | < 5 | > 10 |
| Error Rate | < 0.1% | > 1% |

### Expected Performance

- **Dashboard Load**: < 200ms
- **Contact List (Paginated)**: < 150ms
- **Deal Pipeline**: < 200ms
- **Prospect & Enrich Filter**: < 300ms
- **Search Query**: < 250ms

## 🔧 Troubleshooting

### Issue: Slow Queries

**Check:**
```sql
-- Find slow queries
SELECT pid, now() - query_start AS duration, query 
FROM pg_stat_activity 
WHERE state = 'active' 
AND query_start < NOW() - INTERVAL '5 seconds'
ORDER BY duration DESC;
```

**Solution:**
- Verify indexes are being used (EXPLAIN ANALYZE)
- Check for missing deleted_at filters
- Ensure pagination is implemented

### Issue: Connection Pool Exhausted

**Check:**
```sql
SELECT COUNT(*) FROM pg_stat_activity;
```

**Solution:**
- Increase connection pool size
- Verify connection pooling is enabled
- Check for connection leaks in application code

### Issue: High Lock Contention

**Check:**
```sql
SELECT * FROM pg_locks WHERE NOT granted;
```

**Solution:**
- Verify all writes use proper transaction isolation
- Check for long-running transactions
- Ensure indexes reduce lock scope

## 📚 Additional Resources

- [Scalability Guide](./SCALABILITY_500_USERS.md)
- [Index Optimization Schema](../scripts/supabase/index_optimization_schema.sql)
- [Supabase Performance Guide](https://supabase.com/docs/guides/database/performance)


