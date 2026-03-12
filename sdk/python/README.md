# Data Lake SDK - Python

Unified Python SDK for NextDeal Data Lake operations on Supabase.

## Installation

```bash
pip install -e .
```

## Usage

```python
from nextdeal_datalake import DataLakeClient

# Initialize client
client = DataLakeClient(
    supabase_url="https://your-project.supabase.co",
    supabase_key="your-service-role-key"
)

# Raw zone operations
raw_data = client.raw.save_redfin_response(response_data, url)

# Staging zone operations
staging_data = client.staging.save_fsbo_raw(fsbo_data)

# Curated zone operations
lead = client.curated.save_fsbo_lead(enriched_lead)

# Pipeline operations
pipeline_run = client.pipelines.start_run("redfin_fsbo_scraper")
client.pipelines.log_event(pipeline_run.id, "progress", "Processed 100 records")
client.pipelines.complete_run(pipeline_run.id, records_processed=100)
```

## Features

- Type-safe models that map to Supabase tables
- Zone-based operations (raw, staging, curated)
- Pipeline tracking and event logging
- Automatic data lineage tracking
- Error handling and retries


