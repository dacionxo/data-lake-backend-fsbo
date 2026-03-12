# Data Lake SDK - TypeScript

Unified TypeScript SDK for NextDeal Data Lake operations on Supabase.

## Installation

```bash
npm install @nextdeal/datalake-sdk
```

## Usage

```typescript
import { DataLakeClient } from '@nextdeal/datalake-sdk';

// Initialize client
const client = new DataLakeClient({
  supabaseUrl: 'https://your-project.supabase.co',
  supabaseKey: 'your-service-role-key'
});

// Raw zone operations
const rawData = await client.raw.saveRedfinResponse(responseData, url);

// Staging zone operations
const stagingData = await client.staging.saveFsboRaw(fsboData);

// Curated zone operations
const lead = await client.curated.saveFsboLead(enrichedLead);

// Pipeline operations
const pipelineRun = await client.pipelines.startRun('redfin_fsbo_scraper');
await client.pipelines.logEvent(pipelineRun.id, 'progress', 'Processed 100 records');
await client.pipelines.completeRun(pipelineRun.id, { recordsProcessed: 100 });
```

## Features

- Type-safe models that map to Supabase tables
- Zone-based operations (raw, staging, curated)
- Pipeline tracking and event logging
- Automatic data lineage tracking
- Error handling and retries


