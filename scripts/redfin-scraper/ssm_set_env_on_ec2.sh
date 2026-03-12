#!/bin/bash
# Run on EC2 via SSM: fetches /fsbo/* from Parameter Store and writes .env
set -e
ENV_FILE="/opt/fsbo-worker/scripts/redfin-scraper/.env"
mkdir -p "$(dirname "$ENV_FILE")"
get_ssm() { aws ssm get-parameter --name "$1" --with-decryption --query Parameter.Value --output text --region us-east-1; }
echo "SUPABASE_URL=$(get_ssm /fsbo/supabase-url)" > "$ENV_FILE"
echo "SUPABASE_SERVICE_ROLE_KEY=$(get_ssm /fsbo/supabase-service-role-key)" >> "$ENV_FILE"
echo "FSBO_SQS_QUEUE_URL=$(get_ssm /fsbo/fsbo-sqs-queue-url)" >> "$ENV_FILE"
echo "AWS_REGION=$(get_ssm /fsbo/aws-region)" >> "$ENV_FILE"
echo "FSBO_WORKER_CONCURRENCY=$(get_ssm /fsbo/fsbo-worker-concurrency)" >> "$ENV_FILE"
chmod 600 "$ENV_FILE"
echo "Created $ENV_FILE"; wc -l "$ENV_FILE"
