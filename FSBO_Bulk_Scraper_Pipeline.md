## FSBO Bulk Scraper Pipeline (Local + AWS SQS + Lambda or EC2 + DataImpulse + Supabase)

This document explains **end‑to‑end** how your FSBO bulk scraper works: where URLs come from, how they get into SQS, how **Lambda or EC2** consume jobs and scrape via DataImpulse, and how records land in Supabase.

---

## 1. Components Overview

- **Local code (your machine)**
  - `FSBO.py` – sitemap crawler + full field scraper.
  - `enqueue_fsbo_sqs.py` – controller that pushes jobs into SQS.
- **AWS**
  - **SQS**: `fsbo-listing-jobs`
    - Queue URL: `https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs`
    - Single job queue; consumed by **Lambda** and/or **EC2** (same message format).
  - **Lambda** (optional): `fsbo-listing-worker`
    - Code: `lambda_fsbo_worker.py` + `FSBO.py`
    - Role: `fsbo-listing-worker-role`
    - Trigger: SQS batch; good for bursty, event-driven scaling.
  - **EC2 worker** (primary / recommended): long-running poller
    - Script: `fsbo_sqs_worker.py` — polls SQS, scrapes with `FSBO.py`, pushes via `supabase_client`.
    - Instance: `t4g.small` (ARM, Amazon Linux 2023), e.g. `i-07b1cb421f130ca3e` (see [docs/EC2_FSBO_WORKER_SETUP.md](docs/EC2_FSBO_WORKER_SETUP.md)).
    - IAM: instance profile `ecs2-listing-worker-role` (SQS + optional SSM for secrets).
    - Runs at boot via bootstrap; optional DataImpulse proxy via env or SSM.
- **DataImpulse Residential Proxies**
  - Used by Lambda and/or EC2 to fetch Redfin pages from rotating residential IPs (configurable on each).
- **Supabase**
  - Project URL: `https://bqkucdaefpfkunceftye.supabase.co`
  - Main table: `fsbo_leads` (Lambda: REST API; EC2: `supabase_client`; local: `supabase_client`).

---

## 2. Step 1 – Discover all listing URLs (local)

**Goal**: Build the canonical list of Redfin FSBO listing URLs.

Run locally:

```powershell
cd "D:\Downloads\Data Lake Backend"
python "scripts\redfin-scraper\FSBO.py" --export-urls
```

What happens:

- `FSBO.py`:
  - Crawls Redfin sitemaps across all U.S. states.
  - Filters URLs to valid property listings.
- The function `export_listing_urls` writes them to:

```text
D:\Downloads\FSBO Documents\fsbo_listing_urls.txt
```

(one URL per line).

This file is the **source of truth** for the bulk run.

---

## 3. Step 2 – Enqueue jobs into SQS (local controller)

**Goal**: Turn each URL into a job for the EC2 and/or Lambda workers.

Run locally:

```powershell
$env:AWS_PROFILE = "StackDealFSBO-Scraper"
$env:AWS_REGION  = "us-east-1"

python "scripts\redfin-scraper\enqueue_fsbo_sqs.py" `
  --queue-url "https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs" `
  --urls-file "D:\Downloads\FSBO Documents\fsbo_listing_urls.txt" `
  --max-age-days 0 `
  --region "us-east-1"
```

What `enqueue_fsbo_sqs.py` does:

- Loads all URLs from `fsbo_listing_urls.txt`.
- Optionally checks Supabase (`fsbo_leads`) to **skip recently scraped URLs** (when `--max-age-days > 0`).
- Sends each remaining URL as an SQS message:

```json
{
  "url": "https://www.redfin.com/...",
  "run_id": "fsbo-YYYYMMDD-HHMMSS",
  "attempt": 1
}
```

The queue `fsbo-listing-jobs` now contains **one job per listing URL**.

---

## 4. Step 3 – Job processing: Lambda and/or EC2 (AWS)

The same SQS queue is consumed by one or both of:

| Consumer | How it runs | When to use |
|----------|-------------|-------------|
| **EC2 worker** | Long-running `fsbo_sqs_worker.py` polls SQS with a **concurrent** thread pool (default 50 workers); restarts on failure via bootstrap loop. | **Primary**: predictable cost, no Lambda timeout; ~70k listings/hour with `FSBO_WORKER_CONCURRENCY=50–80`. |
| **Lambda** | SQS trigger invokes `fsbo-listing-worker` per batch of messages. | Optional: extra burst capacity; same queue, same message format. |

You can run **EC2 only**, **Lambda only**, or **both** (they share the queue; each message is processed once).

### 4.1. EC2 worker (recommended)

- **Where**: `t4g.small` instance (e.g. `i-07b1cb421f130ca3e`), see [docs/EC2_FSBO_WORKER_SETUP.md](docs/EC2_FSBO_WORKER_SETUP.md).
- **How**: Bootstrap at boot clones repo, installs deps, runs `fsbo_sqs_worker.py` in a loop. Worker uses a **thread pool** (default 50 concurrent workers; set `FSBO_WORKER_CONCURRENCY=50–80` for ~70k listings/hour). One thread receives from SQS and enqueues jobs; worker threads scrape with `FSBO.py` (optional DataImpulse via env/SSM) and upsert to `fsbo_leads` via `supabase_client`.
- **Credentials**: Supabase (required) and DataImpulse (optional) via SSM Parameter Store or SSH `.env` on the instance. **IAM**: instance profile must have SQS `ReceiveMessage`/`DeleteMessage` (and optional SSM for secrets). If messages stay “available” and never “in flight”, see [EC2 setup §4](docs/EC2_FSBO_WORKER_SETUP.md#4-troubleshooting-messages-in-sqs-but-not-in-flight).
- **Logs**: Bootstrap log: `/var/log/fsbo-bootstrap.log`; worker logs “SQS connectivity OK” at startup, then `[JOB]` / `[saved]` per listing.

### 4.2. Lambda (optional)

- **Trigger**: In AWS console, attach SQS `fsbo-listing-jobs` to `fsbo-listing-worker` (batch size e.g. 5–10, visibility timeout ≥ Lambda timeout).
- **Invocation**: When messages appear, Lambda is invoked with a batch of records; each record `body` is the same JSON as above (`url`, `run_id`, `attempt`).
- **Scaling**: Multiple concurrent Lambda executions process batches in parallel for high throughput.

---

## 5. Step 4a – EC2 worker: scrape via DataImpulse (optional) + write to Supabase

### 5.1. EC2 proxy configuration (optional)

`fsbo_sqs_worker.py` builds a `requests.Session`. If `DATAIMPULSE_LOGIN` and `DATAIMPULSE_PASSWORD` are set (via SSM or `.env` on the instance), it uses the same DataImpulse proxy pattern as Lambda (e.g. `gw.dataimpulse.com:823`). Otherwise it fetches without a proxy.

### 5.2. EC2 scraping and Supabase write

For each SQS message, the worker:

1. Calls `FSBO.scrape_redfin_listing(url, session)` (same logic as Lambda).
2. Computes completeness with `compute_completeness(data)`.
3. Pushes to Supabase via `_push_listing_to_supabase` (uses `supabase_client` / full client on the instance).

Same schema and `fsbo_leads` table as Lambda; same completeness fields.

---

## 6. Step 4b – Lambda: scrape via DataImpulse + write to Supabase (optional)

### 6.1. Lambda proxy configuration (DataImpulse)

`lambda_fsbo_worker.py` builds a DataImpulse rotating residential proxy from env vars:

- `DATAIMPULSE_LOGIN=<your-login>`
- `DATAIMPULSE_PASSWORD=<your-password>`
- `DATAIMPULSE_HOST=gw.dataimpulse.com`
- `DATAIMPULSE_PORT=823`
- `DATAIMPULSE_REGION_TAG=__cr.us`

Example proxy URL:

```text
http://<LOGIN>__cr.us:<PASSWORD>@gw.dataimpulse.com:823
```

The worker creates a `requests.Session` with:

- Proxies set to that URL (`http`/`https`).
- HTML-only headers (`Accept: text/html,...`).
- Keep-alive and gzip enabled.

Every listing fetch goes through DataImpulse’s **rotating residential IP pool**.

### 6.2. Lambda scraping logic

For each URL in the SQS batch, the worker:

1. Uses `FSBO.py`’s `scrape_redfin_listing(url, session)` to:
   - Fetch the Redfin page through DataImpulse.
   - Parse HTML and embedded JSON.
   - Fill out the `data` dict with all your FSBO fields.
2. Calls `compute_completeness(data)` to compute:
   - `completeness_present_required`
   - `completeness_total_required`
   - `completeness_ratio` (0.0–1.0)
   - `completeness_missing_required` (comma-separated list of missing required fields).
3. Attaches run metadata:
   - `lambda_run_id`
   - `lambda_attempt`

### 6.3. Lambda Supabase upsert (REST API)

To keep the Lambda small, it uses **direct Supabase REST**, not the heavy `supabase` Python client.

Env vars:

- `SUPABASE_URL=https://bqkucdaefpfkunceftye.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY=...` (service role or high-privileged key)
- Optional: `SUPABASE_FSBO_TABLE=fsbo_leads` (defaults to `fsbo_leads`)

The worker:

- Builds endpoint:

```text
{SUPABASE_URL}/rest/v1/fsbo_leads
```

- Sends a POST with:

```http
POST /rest/v1/fsbo_leads?on_conflict=property_url
Prefer: resolution=merge-duplicates,return=minimal
Authorization: Bearer <SERVICE_ROLE_KEY>
apikey: <SERVICE_ROLE_KEY>
Content-Type: application/json

[
  { ... full lead data dict ... }
]
```

Supabase:

- Upserts by `property_url` (merge/update existing rows).
- Stores all fields under your `fsbo_leads` schema.
- Tracks timestamps (`scrape_date`, `last_scraped_at`) that Lambda sets.

---

## 7. Tracking where you are in the pipeline

Use these signals to see how far a bulk run has gotten and whether workers are keeping up.

### 7.1. After Step 1 (discover URLs)

- **Total URLs for this run**: count lines in the export file:
  ```powershell
  (Get-Content "D:\Downloads\FSBO Documents\fsbo_listing_urls.txt").Count
  ```
- That number is the **maximum** jobs that can be enqueued for this run.

### 7.2. After Step 2 (enqueue)

The enqueue script prints:

- `Loaded N URLs from ...` — total from the file.
- `Found X already-scraped URLs in fsbo_leads for deduplication` — skipped (if `--max-age-days > 0`).
- `Y URLs remaining after deduplication` — actually sent to SQS.
- `Enqueued Z URLs to SQS queue ...` — **Z** is the number of jobs in the queue for this run.

Note the **run_id** (e.g. `fsbo-20260311-143022`). You can pass it explicitly:  
`--run-id "fsbo-20260311-143022"` for easier tracking.

### 7.3. Queue state (how many jobs left / in progress)

Use the SQS queue URL to see pending and in-flight counts:

```powershell
$env:AWS_PROFILE = "StackDealFSBO-Scraper"
$env:AWS_REGION  = "us-east-1"
aws sqs get-queue-attributes `
  --queue-url "https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs" `
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible
```

- **ApproximateNumberOfMessages** — jobs waiting to be picked up (not yet processed).
- **ApproximateNumberOfMessagesNotVisible** — jobs currently being processed (in visibility timeout).

When both are `0`, the queue is drained for this run (all jobs consumed; see Supabase for how many were saved).

### 7.4. How many have been saved (Supabase)

- **Total leads**: In Supabase Dashboard → Table Editor → `fsbo_leads`, check row count.
- **Scraped in this run**: Filter or query by `last_scraped_at` after your enqueue time, e.g. in SQL Editor:
  ```sql
  SELECT COUNT(*) FROM fsbo_leads
  WHERE last_scraped_at >= '2026-03-11 14:30:00+00';
  ```
  Use the time you started the enqueue (or the run start) in UTC.

Rough progress: **(enqueued − queue visible − queue not visible)** ≈ already processed; compare with Supabase count for “saved” vs “failed”.

### 7.5. Worker health (EC2 vs Lambda)

- **EC2**: SSH and tail the bootstrap log to see active processing and errors:
  ```bash
  sudo tail -f /var/log/fsbo-bootstrap.log
  ```
  Look for `[JOB]`, `[saved]`, or error lines.
- **Lambda**: CloudWatch Logs for `/aws/lambda/fsbo-listing-worker` — recent invocations and batch summaries.

Together: **enqueued count** (Step 2) − **SQS visible** − **SQS not visible** ≈ **processed**; **Supabase count (recent `last_scraped_at`)** ≈ **saved**.

---

## 8. Step 5 – Monitoring and throughput

### 8.1. What to watch

- **EC2 worker**
  - SSH to instance and run: `sudo tail -f /var/log/fsbo-bootstrap.log` for bootstrap and worker output.
  - Worker logs: `[JOB]`, `[saved]`, or errors per URL.
- **Lambda** (if used)
  - **CloudWatch Logs → `/aws/lambda/fsbo-listing-worker`**
    - Per-URL: `[saved]` vs `[supabase_error]` vs scrape errors.
    - Per-batch: `Lambda batch done: total=..., saved=..., errors=...`
- **SQS → fsbo-listing-jobs → Monitoring**
  - `ApproximateNumberOfMessagesVisible` (pending jobs).
  - `NumberOfMessagesDeleted` (completed jobs).
- **Supabase Dashboard**
  - `fsbo_leads` row count; recent rows by `last_scraped_at`; completeness via `completeness_ratio` and `completeness_missing_required`.

### 8.2. Tuning throughput

- **EC2**: Set `FSBO_WORKER_CONCURRENCY=50` (default) to ~80 for ~70k listings/hour. One instance runs many threads; add more EC2 instances (same queue) for more throughput, or enable Lambda in addition.
- **Lambda** (if used): Increase reserved concurrency; adjust SQS trigger batch size (e.g. 5 → 10 → 20). Watch 403/429 and DataImpulse usage.
- Use `--max-age-days` in `enqueue_fsbo_sqs.py` to skip recently scraped URLs and save proxy traffic.

---

## 9. Local vs worker behavior

- **Local runs**:
  - `FSBO.py --async` or sync `main()`.
  - Uses `supabase_client.save_lead_to_fsbo_leads` for rich mapping and type handling.
  - Ideal for development, debugging, and smaller test runs.
- **EC2 worker (bulk)**:
  - Polls SQS, uses full `FSBO.py` + `supabase_client` (or `_push_listing_to_supabase`), optional DataImpulse.
  - Same scraping logic and completeness metrics; no Lambda timeout; predictable cost.
- **Lambda (bulk, optional)**:
  - SQS-triggered; DataImpulse + Supabase REST; same scraping logic.
  - Good for burst capacity alongside EC2.

---

## 10. One-command bulk run summary (once everything is wired)

1. **One-time**: EC2 worker instance running with IAM profile and Supabase/DataImpulse credentials (see [docs/EC2_FSBO_WORKER_SETUP.md](docs/EC2_FSBO_WORKER_SETUP.md)). Optionally configure Lambda trigger on the same SQS queue for extra capacity.
2. From your machine:

```powershell
cd "D:\Downloads\Data Lake Backend"

python "scripts\redfin-scraper\FSBO.py" --export-urls

$env:AWS_PROFILE = "StackDealFSBO-Scraper"
$env:AWS_REGION  = "us-east-1"

python "scripts\redfin-scraper\enqueue_fsbo_sqs.py" `
  --queue-url "https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs" `
  --urls-file "D:\Downloads\FSBO Documents\fsbo_listing_urls.txt" `
  --max-age-days 0 `
  --region "us-east-1"
```

This enqueues all current FSBO listing URLs into SQS. **EC2 worker(s)** (and Lambda if configured) consume the queue, scrape via DataImpulse (if configured), and upsert into Supabase `fsbo_leads`.

