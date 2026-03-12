#!/bin/bash
# Run the FSBO SQS worker on EC2. Use from: scripts/redfin-scraper/
#   ./start_fsbo_worker.sh
# Ensures we're in the right dir, load .env, optionally SSM, then run the worker.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== FSBO worker start (dir=$SCRIPT_DIR) ==="

# Load .env if present
if [ -f .env ]; then
  echo "Loading .env..."
  set -a
  source .env
  set +a
fi

# Load from SSM (if instance role has ssm:GetParameter) so EC2 has all env in one place
get_ssm() { aws ssm get-parameter --name "$1" --with-decryption --query Parameter.Value --output text 2>/dev/null || true; }
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

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
  echo "ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set (via .env or SSM /fsbo/supabase-url and /fsbo/supabase-service-role-key)."
  exit 1
fi

echo "Running diagnostic..."
python3.11 diagnose_sqs.py || { echo "Diagnostic failed; fix IAM/env and retry."; exit 1; }

echo "Starting worker (concurrency=$FSBO_WORKER_CONCURRENCY)..."
exec python3.11 fsbo_sqs_worker.py
