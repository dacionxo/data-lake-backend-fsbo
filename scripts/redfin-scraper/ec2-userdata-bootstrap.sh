#!/bin/bash
# FSBO SQS worker bootstrap for Amazon Linux 2023 (ARM t4g.small)
# Requires instance role with: SQS (ReceiveMessage, DeleteMessage), optional SSM GetParameters
set -e
exec > /var/log/fsbo-bootstrap.log 2>&1

echo "=== FSBO EC2 worker bootstrap starting ==="

# Install Python 3.11, pip, git
dnf install -y python3.11 python3.11-pip git

# Clone repo (public FSBO-specific repo)
REPO_URL="https://github.com/dacionxo/data-lake-backend-fsbo.git"
WORK_DIR="/opt/fsbo-worker"
mkdir -p /opt
if [ -d "$WORK_DIR" ]; then rm -rf "$WORK_DIR"; fi
git clone --depth 1 "$REPO_URL" "$WORK_DIR"
cd "$WORK_DIR/scripts/redfin-scraper"

# Install Python deps (no requirements-fsbo-worker.txt in repo; install inline)
python3.11 -m pip install --break-system-packages --quiet \
  boto3 requests beautifulsoup4 pandas tqdm supabase aiohttp requests-ip-rotator

# Load all FSBO env from SSM Parameter Store (if instance role has ssm:GetParameter)
get_ssm() { aws ssm get-parameter --name "$1" --with-decryption --query Parameter.Value --output text 2>/dev/null; }
v=$(get_ssm /fsbo/supabase-url); [ -n "$v" ] && export SUPABASE_URL="$v"
v=$(get_ssm /fsbo/supabase-service-role-key); [ -n "$v" ] && export SUPABASE_SERVICE_ROLE_KEY="$v"
v=$(get_ssm /fsbo/fsbo-sqs-queue-url); [ -n "$v" ] && export FSBO_SQS_QUEUE_URL="$v"
v=$(get_ssm /fsbo/aws-region); [ -n "$v" ] && export AWS_REGION="$v"
v=$(get_ssm /fsbo/fsbo-worker-concurrency); [ -n "$v" ] && export FSBO_WORKER_CONCURRENCY="$v"
v=$(get_ssm /fsbo/dataimpulse-login); [ -n "$v" ] && export DATAIMPULSE_LOGIN="$v"
v=$(get_ssm /fsbo/dataimpulse-password); [ -n "$v" ] && export DATAIMPULSE_PASSWORD="$v"
export FSBO_SQS_QUEUE_URL="${FSBO_SQS_QUEUE_URL:-https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export FSBO_WORKER_CONCURRENCY="${FSBO_WORKER_CONCURRENCY:-50}"

# Run worker (restart on failure). Ensure instance has IAM role with SQS ReceiveMessage/DeleteMessage.
echo "=== Starting FSBO SQS worker (concurrency=$FSBO_WORKER_CONCURRENCY) ==="
while true; do
  python3.11 fsbo_sqs_worker.py || true
  sleep 10
done
