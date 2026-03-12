# NextDeal Redfin FSBO Scraper

World-class FSBO (For Sale By Owner) lead scraper with pipeline abstraction, robust error handling, and idempotent upserts.

## 🎯 Features

- **Pipeline Abstraction**: Clear separation of stages (discover → fetch → parse → normalize → upsert)
- **Idempotent Upserts**: Safe to run multiple times without duplicates
- **Incremental Scraping**: Only processes new/changed listings
- **Robust Error Handling**: Timeouts, retries, exponential backoff
- **AWS IP Rotation**: Automatic region failover and health checks
- **Raw Response Storage**: Store raw responses in Supabase Storage for debugging
- **Volume & Coverage Checks**: Automatic alerts for suspicious counts
- **Source Health Dashboard**: Per-source metrics for monitoring
- **Multi-Source Support**: Redfin, Zillow FSBO, Craigslist, etc.

## 📋 Pipeline Stages

### 1. Sitemap Discovery
- Recursively parses Redfin XML sitemaps
- Filters by target states
- Supports incremental scraping (by timestamp)

### 2. Fetch
- Downloads listing pages
- HTTP error handling with retries
- Exponential backoff for failed requests
- IP rotation with region fallback

### 3. Parse
- Extracts data from HTML and embedded JSON
- Handles multiple extraction methods
- Logs missing fields for debugging

### 4. Normalize
- Cleans and standardizes data
- Normalizes ZIP codes, prices, phone numbers
- Generates consistent listing_id

### 5. Upsert + Log
- Idempotent database inserts/updates
- Uses `listing_id` + `property_url` for conflict resolution
- Stores raw responses for reprocessing

## 🚀 Usage

### Basic Usage

```python
from nextdeal_redfin.pipeline import FSBOPipeline, PipelineConfig
from nextdeal_redfin.handlers import *
from nextdeal_redfin.http_client import RobustHTTPClient
from nextdeal_redfin.ip_rotation import IPRotationManager, IPRotationConfig

# Configure pipeline
config = PipelineConfig(
    source='redfin',
    target_states=['CA', 'TX', 'FL'],
    sitemap_urls=['https://www.redfin.com/newest_listings.xml'],
    incremental=True,
    retry_budget=3,
    timeout=30,
)

# Initialize handlers
http_client = RobustHTTPClient(timeout=30, retry_budget=3)
ip_rotation = IPRotationManager(IPRotationConfig(
    target_domain='https://www.redfin.com',
    regions=['us-east-1', 'us-west-2'],
))

# Create pipeline
pipeline = FSBOPipeline(
    config=config,
    sitemap_discoverer=SitemapDiscoveryHandler(http_client),
    fetcher=FetchHandler(http_client, ip_rotation),
    parser=ParseHandler(),
    normalizer=NormalizeHandler(),
    upsert_handler=UpsertHandler(supabase_client),
    raw_storage_handler=RawStorageHandler(supabase_storage),
    health_checker=HealthChecker(supabase_client),
)

# Run pipeline
result = pipeline.run()
print(f"Upserted {result.listings_upserted} listings")
print(f"Success rate: {result.success_rate:.1f}%")
```

### CLI Usage

```bash
# Run scraper
nextdeal-fsbo scrape --source redfin --states CA,TX,FL

# Run with incremental mode
nextdeal-fsbo scrape --incremental --last-scrape 2024-01-01

# Check source health
nextdeal-fsbo health --source redfin
```

## 🔧 Configuration

Configuration is centralized in `config/pipeline-config.yaml`:

```yaml
regions:
  aws:
    - "us-east-1"
    - "us-west-2"
  target_states:
    - "CA"
    - "TX"

batch:
  scraper:
    fetch_batch_size: 10
    max_workers: 10

delays:
  scraper:
    between_requests: 1.0
    retry_delay: 30.0
```

## 🧩 Local AWS account setup (IP rotation)

When you run the scraper **locally**, all AWS resources used for IP rotation (API Gateway, CloudWatch logs, etc.) should live in a **dedicated AWS account**. To wire the scraper to that account:

1. **Create/configure an AWS CLI profile** for the new account:

   ```bash
   aws configure --profile StackDealFSBO-Scraper
   # Set Access Key, Secret, Region (for example: us-east-1)

   aws sts get-caller-identity --profile StackDealFSBO-Scraper
   # Confirm the Account ID is the new scraper account
   ```

2. **Use that profile when running the scraper locally** so that `requests_ip_rotator`/API Gateway resources are created and used in the new account:

   ```bash
   # PowerShell
   $Env:AWS_PROFILE = "StackDealFSBO-Scraper"
   $Env:AWS_REGION  = "us-east-1"
   python FSBO.py
   ```

   ```bash
   # bash / WSL
   export AWS_PROFILE=StackDealFSBO-Scraper
   export AWS_REGION=us-east-1
   python FSBO.py
   ```

3. **Rotate away from any old account credentials**:
   - Remove or stop using any previous AWS profiles/keys that pointed at an old account for this scraper.
   - After the first run with the new profile, open the AWS console for the new account and verify that:
     - API Gateway REST APIs have been created.
     - CloudWatch log groups for those APIs are present.

Going forward, as long as you set `AWS_PROFILE=StackDealFSBO-Scraper` (or equivalent) before running the scraper locally, all AWS calls for IP rotation will go through the new AWS account.

## 📊 Idempotent Upserts

The scraper uses idempotent upserts to prevent duplicates:

```sql
-- Upsert using listing_id as conflict key
INSERT INTO fsbo_leads (...)
VALUES (...)
ON CONFLICT (listing_id) DO UPDATE SET
  last_scraped_at = EXCLUDED.last_scraped_at,
  active = EXCLUDED.active,
  ...
```

Both `listing_id` and `property_url` are enforced as unique constraints.

## 🔄 Incremental Scraping

Incremental scraping only processes new/changed listings:

```python
# Get last scrape timestamp
last_scrape = supabase.rpc('get_last_scrape_timestamp', {'p_source': 'redfin'})

# Run incremental scrape
pipeline.run(incremental=True, last_sitemap_timestamp=last_scrape)
```

## 🌐 IP Rotation

AWS API Gateway IP rotation with automatic failover:

```python
ip_rotation = IPRotationManager(IPRotationConfig(
    target_domain='https://www.redfin.com',
    regions=['us-east-1', 'us-west-2', 'us-east-2'],
    health_check_url='https://www.redfin.com/robots.txt',
    max_failures_per_region=5,
))
```

## 📦 Raw Response Storage

Raw responses are stored in Supabase Storage for debugging:

```python
# Store raw response
raw_id = raw_storage_handler.store(
    url=listing_url,
    response_data={'html': html_content, 'json': json_data},
    source='redfin',
)

# Link to fsbo_leads
fsbo_lead['raw_response_id'] = raw_id
```

## 📈 Source Health Dashboard

View per-source metrics:

```sql
SELECT * FROM source_health_summary
WHERE source_type = 'fsbo_leads'
ORDER BY leads_last_24h DESC;
```

## 🧪 Testing

Run integration tests:

```bash
pytest tests/test_fsbo_pipeline.py -v
```

Tests verify:
- Pipeline stages execute correctly
- Idempotent upserts work
- Incremental scraping filters correctly
- Error handling works
- Results appear in UI

## 📚 Related Documentation

- [Pipeline Architecture](../../docs/ARCHITECTURE.md)
- [Schema Documentation](../../scripts/supabase/README_SCHEMAS.md)
- [Configuration Guide](../../config/pipeline-config.yaml)


