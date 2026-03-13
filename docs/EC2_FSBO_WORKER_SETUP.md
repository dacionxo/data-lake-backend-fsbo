# EC2 FSBO SQS Worker Setup

## Current instance

- **Instance ID**: `i-07b1cb421f130ca3e`
- **Type**: `t4g.small` (ARM, Amazon Linux 2023)
- **Region**: `us-east-1`
- **Public IP**: `44.223.9.224` (may change after stop/start)
- **Name tag**: `fsbo-sqs-worker`
- **Security group**: `fsbo-worker-sg` (SSH 22 allowed; egress all)

Bootstrap runs at boot: clone `Data-Lake-Backend`, install Python deps, run `fsbo_sqs_worker.py` in a loop with **concurrency** (default 50 workers) for ~70k listings/hour. Log: `/var/log/fsbo-bootstrap.log`.

---

## Get messages in flight (step-by-step)

If messages are **in SQS but never "in flight"**, no process on EC2 is consuming the queue. Do this in order:

### Step 1: Attach IAM role to the instance

- **EC2 → Instances** → select `fsbo-sqs-worker` (or your instance)
- **Actions → Security → Modify IAM role**
- Select the profile for **ecs2-listing-worker-role** (or the role that has SQS + optional SSM)
- **Update**

Without this, the instance has no AWS credentials and cannot call SQS.

### Step 2: SSH and pull latest code (if the instance was set up earlier)

User data runs only at **first boot**. If you added `diagnose_sqs.py` or `start_fsbo_worker.sh` later, pull on the instance:

```bash
ssh -i your-key.pem ec2-user@<instance-public-ip>
cd /opt/fsbo-worker && sudo git pull origin main
cd scripts/redfin-scraper
```

(Use your repo’s default branch if not `main`.)

### Step 3: Run the diagnostic

From `/opt/fsbo-worker/scripts/redfin-scraper` (or your clone path):

```bash
cd /opt/fsbo-worker/scripts/redfin-scraper
python3.11 diagnose_sqs.py
```

- If it prints **"All checks passed"**: go to Step 4.
- If it fails on **AWS credentials** or **SQS**: the IAM role is missing or has no SQS permissions. Fix the role (see §1) and run the diagnostic again.
- If **SUPABASE_URL** / **SUPABASE_SERVICE_ROLE_KEY** are "(NOT SET)": set them via `.env` or SSM (see §2) before starting the worker.

### Step 4: Set Supabase (and optional DataImpulse) and start the worker

**Option A — Use the start script (recommended)**

Create a `.env` in `scripts/redfin-scraper` with at least:

```bash
SUPABASE_URL=https://bqkucdaefpfkunceftye.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
```

Then:

```bash
chmod +x start_fsbo_worker.sh
./start_fsbo_worker.sh
```

The script runs the diagnostic, then starts the worker. You should see "SQS connectivity OK" and "[JOB] ..." as messages move to **in flight** and get processed.

**Option B — Start worker manually**

```bash
cd /opt/fsbo-worker/scripts/redfin-scraper
export AWS_REGION=us-east-1
export FSBO_SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs"
export SUPABASE_URL="https://bqkucdaefpfkunceftye.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<your-service-role-key>"
# optional: export FSBO_WORKER_CONCURRENCY=70
nohup python3.11 fsbo_sqs_worker.py > /var/log/fsbo-worker.log 2>&1 &
tail -f /var/log/fsbo-worker.log
```

### Step 5: Confirm messages are in flight and leads in Supabase

- **SQS**: In the AWS console, queue `fsbo-listing-jobs` → **Monitoring**: **ApproximateNumberOfMessagesNotVisible** should increase while the worker runs; **ApproximateNumberOfMessagesVisible** should decrease.
- **Supabase**: Table `fsbo_leads` should get new rows and recent `last_scraped_at` values.

---

## 1. IAM instance profile (required for SQS)

**Role name in use:** `ecs2-listing-worker-role`

The role must allow at least:

- **SQS**: `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes` on the queue (or `sqs:*` on the queue ARN).
- **SSM** (optional): `ssm:GetParameter`, `ssm:GetParameters` on the `/fsbo/*` parameters if you use Parameter Store for credentials.

Attach the role to the instance:

- **EC2 → Instances** → select `fsbo-sqs-worker` (or instance ID `i-07b1cb421f130ca3e`)
- **Actions → Security → Modify IAM role**
- Choose the instance profile that uses `ecs2-listing-worker-role` (the profile name may be the same as the role in the dropdown)
- **Update**

After this, the instance has credentials for SQS (and SSM if that role has those permissions).

---

## 2. Supabase and DataImpulse credentials

The worker needs `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`; DataImpulse is optional.

**Required values for this project:**

- **SUPABASE_URL**: `https://bqkucdaefpfkunceftye.supabase.co`
- **SUPABASE_SERVICE_ROLE_KEY**: your Supabase service role key (from Supabase Dashboard → Settings → API).

### Option A: SSM Parameter Store (recommended for EC2)

If the instance IAM role has `ssm:GetParameter`, the worker can read these at runtime. Create the parameters once:

**From your machine (if your IAM user has `ssm:PutParameter`):**

```powershell
cd scripts\redfin-scraper
$env:AWS_PROFILE = "StackDealFSBO-Scraper"
$env:AWS_REGION  = "us-east-1"
$env:SUPABASE_SERVICE_ROLE_KEY = "<paste-your-service-role-key>"
.\store_fsbo_secrets_ssm.ps1
```

**Or create them in the AWS Console (no PutParameter permission needed):**

1. **AWS Console → Systems Manager → Parameter Store** (region `us-east-1`).
2. **Create parameter** for each:

   | Name                         | Type        | Value                                                                 |
   |-----------------------------|-------------|-----------------------------------------------------------------------|
   | `/fsbo/supabase-url`        | String      | `https://bqkucdaefpfkunceftye.supabase.co`                            |
   | `/fsbo/supabase-service-role-key` | SecureString | Your Supabase service role key (from Dashboard → Settings → API) |
   | `/fsbo/dataimpulse-login`   | SecureString | (optional) DataImpulse login                                        |
   | `/fsbo/dataimpulse-password` | SecureString | (optional) DataImpulse password                                    |

3. Ensure the EC2 instance IAM role has `ssm:GetParameter` on `arn:aws:ssm:us-east-1:859217211854:parameter/fsbo/*`. Then bootstrap and `start_fsbo_worker.sh` will read these; no need to SSH to set env.

### Option B: Set on instance via SSH (no SSM needed)

1. SSH to the instance:  
   `ssh -i your-key.pem ec2-user@<instance-public-ip>`
2. Go to the worker directory and create `.env` from the example:

   ```bash
   cd /opt/fsbo-worker/scripts/redfin-scraper
   cp .env.example .env
   nano .env   # or vi .env
   ```

   Set these (paste your real service role key):

   ```bash
   SUPABASE_URL=https://bqkucdaefpfkunceftye.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=<paste-your-service-role-key-here>
   ```

   Optional (DataImpulse proxy rotation): `DATAIMPULSE_LOGIN`, `DATAIMPULSE_PASSWORD`; or set `DATAIMPULSE_PROXY_LIST_PATH=proxies.txt` with one URL per line. Country/region is configured at the provider. Concurrency: `FSBO_WORKER_CONCURRENCY=70`
3. Start the worker: `./start_fsbo_worker.sh` or:

   ```bash
   export SUPABASE_URL="https://bqkucdaefpfkunceftye.supabase.co"
   export SUPABASE_SERVICE_ROLE_KEY="<your-service-role-key>"
   nohup python3.11 fsbo_sqs_worker.py > /var/log/fsbo-worker.log 2>&1 &
   tail -f /var/log/fsbo-worker.log
   ```

---

## 3. SQS queue

- **Queue URL**: `https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs`
- Enqueue jobs with `enqueue_fsbo_sqs.py` (from your machine or another host). The EC2 worker polls this queue and scrapes each listing, then pushes to Supabase.

---

## 4. Troubleshooting: messages in SQS but not “in flight”

If the queue shows **messages available** but **none in flight**, no consumer is processing. On EC2, check:

1. **IAM role attached**  
   EC2 → Instances → select the instance → **Security** tab → **IAM role**. It must be the role that has `sqs:ReceiveMessage` and `sqs:DeleteMessage` on the queue (e.g. `ecs2-listing-worker-role`). If it’s empty or wrong, use **Actions → Security → Modify IAM role** and attach the correct profile.

2. **Worker process running**  
   SSH to the instance and run:
   ```bash
   sudo tail -100 /var/log/fsbo-bootstrap.log
   ```
   You should see “FSBO SQS worker started” and “SQS connectivity OK”. If you see “Cannot connect to SQS” or “FSBO_SQS_QUEUE_URL is not set”, fix IAM or env and restart (e.g. reboot or run the worker manually from step 5 below).

3. **Supabase credentials**  
   The worker needs `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`. If missing, it may fail after connecting to SQS when it tries to save. Set them via SSM (Option A) or `.env` / export (Option B).

4. **Run worker manually (same dir as script)**  
   From the instance:
   ```bash
   cd /opt/fsbo-worker/scripts/redfin-scraper
   export AWS_REGION=us-east-1
   export FSBO_SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs"
   export SUPABASE_URL="https://your-project.supabase.co"
   export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
   python3.11 fsbo_sqs_worker.py
   ```
   If it logs “SQS connectivity OK” and then “[JOB] …”, it is processing. Stop with Ctrl+C and fix bootstrap/credentials so it runs automatically.

---

## 5. Useful commands

```bash
# Instance status and IP
aws ec2 describe-instances --instance-ids i-07b1cb421f130ca3e \
  --query "Reservations[0].Instances[0].{State:State.Name,PublicIp:PublicIpAddress}" --output table

# SSH (use the key pair you associated)
ssh -i your-key.pem ec2-user@<PublicIp>

# View bootstrap log on instance
sudo tail -f /var/log/fsbo-bootstrap.log
```

---

## 6. Re-launch with IAM profile (optional)

To have the profile attached from the start next time:

1. Create the instance profile and role (see §1).
2. Launch with:

   ```bash
   aws ec2 run-instances \
     --instance-type t4g.small \
     --image-id ami-0a9eef82780017c25 \
     --subnet-id subnet-0e08e1f57ce3bf240 \
     --security-group-ids sg-0a4d0ddf247c82f4c \
     --iam-instance-profile Name=ecs2-listing-worker-role \
     --user-data file://scripts/redfin-scraper/ec2-userdata-bootstrap.sh \
     --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=fsbo-sqs-worker}]"
   ```

Use the same security group and user data; replace subnet/AMI if your account differs.
