#!/bin/bash

# Email Webhook Testing Script
# This script tests all webhook event types

# Configuration - UPDATE THESE VALUES
APP_URL="${APP_URL:-http://localhost:3000}"
WEBHOOK_SECRET="${EMAIL_WEBHOOK_SECRET:-}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Email Webhook Testing Script"
echo "=========================================="
echo ""
echo "App URL: $APP_URL"
echo "Webhook Secret: ${WEBHOOK_SECRET:+Set}${WEBHOOK_SECRET:-Not set}"
echo ""

# Check if email ID is provided
if [ -z "$EMAIL_ID" ]; then
  echo -e "${YELLOW}⚠️  EMAIL_ID not set.${NC}"
  echo "Please provide an email ID from your emails table."
  echo ""
  echo "To get an email ID, run this in Supabase SQL Editor:"
  echo "  SELECT id, to_email, created_at FROM emails ORDER BY created_at DESC LIMIT 1;"
  echo ""
  read -p "Enter email ID (or press Enter to skip): " EMAIL_ID
  if [ -z "$EMAIL_ID" ]; then
    echo -e "${RED}❌ Email ID required. Exiting.${NC}"
    exit 1
  fi
fi

# Check if recipient email is provided
RECIPIENT_EMAIL="${RECIPIENT_EMAIL:-test@example.com}"
echo "Using Email ID: $EMAIL_ID"
echo "Using Recipient Email: $RECIPIENT_EMAIL"
echo ""

# Function to test webhook
test_webhook() {
  local event_type=$1
  local payload=$2
  local description=$3
  
  echo -e "${YELLOW}Testing: $description${NC}"
  
  # Build curl command
  local curl_cmd="curl -s -w '\nHTTP Status: %{http_code}\n' -X POST '$APP_URL/api/webhooks/email/providers'"
  curl_cmd="$curl_cmd -H 'Content-Type: application/json'"
  curl_cmd="$curl_cmd -H 'x-provider: generic'"
  
  if [ -n "$WEBHOOK_SECRET" ]; then
    curl_cmd="$curl_cmd -H 'x-webhook-secret: $WEBHOOK_SECRET'"
  fi
  
  curl_cmd="$curl_cmd -d '$payload'"
  
  # Execute and capture response
  local response=$(eval $curl_cmd)
  local http_code=$(echo "$response" | grep "HTTP Status" | awk '{print $3}')
  local body=$(echo "$response" | sed '/HTTP Status/d')
  
  # Check result
  if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    echo -e "${GREEN}✅ Success (HTTP $http_code)${NC}"
    echo "Response: $body"
  else
    echo -e "${RED}❌ Failed (HTTP $http_code)${NC}"
    echo "Response: $body"
  fi
  echo ""
}

# Test 1: Delivered Event
echo "=========================================="
echo "Test 1: Delivered Event"
echo "=========================================="
DELIVERED_PAYLOAD=$(cat <<EOF
{
  "eventType": "delivered",
  "emailId": "$EMAIL_ID",
  "recipientEmail": "$RECIPIENT_EMAIL",
  "providerMessageId": "test-delivered-$(date +%s)"
}
EOF
)
test_webhook "delivered" "$DELIVERED_PAYLOAD" "Delivered Event"

# Wait a moment
sleep 1

# Test 2: Bounced Event (Hard)
echo "=========================================="
echo "Test 2: Bounced Event (Hard Bounce)"
echo "=========================================="
BOUNCED_PAYLOAD=$(cat <<EOF
{
  "eventType": "bounced",
  "emailId": "$EMAIL_ID",
  "recipientEmail": "$RECIPIENT_EMAIL",
  "providerMessageId": "test-bounced-$(date +%s)",
  "bounceType": "hard",
  "bounceReason": "550 Mailbox not found"
}
EOF
)
test_webhook "bounced" "$BOUNCED_PAYLOAD" "Hard Bounce Event"

# Wait a moment
sleep 1

# Test 3: Bounced Event (Soft)
echo "=========================================="
echo "Test 3: Bounced Event (Soft Bounce)"
echo "=========================================="
SOFT_BOUNCE_PAYLOAD=$(cat <<EOF
{
  "eventType": "bounced",
  "emailId": "$EMAIL_ID",
  "recipientEmail": "$RECIPIENT_EMAIL",
  "providerMessageId": "test-soft-bounce-$(date +%s)",
  "bounceType": "soft",
  "bounceReason": "Mailbox temporarily unavailable"
}
EOF
)
test_webhook "bounced" "$SOFT_BOUNCE_PAYLOAD" "Soft Bounce Event"

# Wait a moment
sleep 1

# Test 4: Complaint Event
echo "=========================================="
echo "Test 4: Complaint Event (Spam)"
echo "=========================================="
COMPLAINT_PAYLOAD=$(cat <<EOF
{
  "eventType": "complaint",
  "emailId": "$EMAIL_ID",
  "recipientEmail": "$RECIPIENT_EMAIL",
  "providerMessageId": "test-complaint-$(date +%s)",
  "complaintType": "spam"
}
EOF
)
test_webhook "complaint" "$COMPLAINT_PAYLOAD" "Complaint Event"

echo "=========================================="
echo "Testing Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Check the email_events table in Supabase:"
echo "   SELECT * FROM email_events WHERE email_id = '$EMAIL_ID' ORDER BY event_timestamp DESC;"
echo ""
echo "2. Check the analytics dashboard:"
echo "   $APP_URL/dashboard/marketing/analytics"
echo ""

