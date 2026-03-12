#!/usr/bin/env python3
"""
Run on EC2 (or locally with AWS_PROFILE) to verify SQS access and env before starting the FSBO worker.
Exits 0 if all checks pass, 1 otherwise. Use: python diagnose_sqs.py
"""
import os
import sys

SQS_QUEUE_URL = os.environ.get(
    "FSBO_SQS_QUEUE_URL",
    "https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs",
)
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")


def main() -> int:
    print("=== FSBO SQS + EC2 worker diagnostic ===\n")

    # 1. Env
    print("1. Environment")
    print(f"   FSBO_SQS_QUEUE_URL = {SQS_QUEUE_URL[:60]}...")
    print(f"   AWS_REGION         = {AWS_REGION}")
    supabase_url = os.environ.get("SUPABASE_URL", "")
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    print(f"   SUPABASE_URL       = {'(set)' if supabase_url else '(NOT SET)'}")
    print(f"   SUPABASE_SERVICE_ROLE_KEY = {'(set)' if supabase_key else '(NOT SET)'}")
    if not supabase_url or not supabase_key:
        print("   -> WARNING: Worker will need SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY to save leads.\n")
    else:
        print("   -> OK\n")

    # 2. Boto3 / credentials
    print("2. AWS credentials (boto3)")
    try:
        import boto3
        sts = boto3.client("sts", region_name=AWS_REGION)
        identity = sts.get_caller_identity()
        print(f"   Account: {identity.get('Account')}")
        print(f"   Arn:     {identity.get('Arn', '')[:70]}...")
        print("   -> OK\n")
    except Exception as e:
        print(f"   -> FAIL: {e}")
        print("   Fix: Attach an IAM instance profile to this EC2 with SQS (and optional SSM) permissions.\n")
        return 1

    # 3. SQS get_queue_attributes
    print("3. SQS get_queue_attributes")
    try:
        sqs = boto3.client("sqs", region_name=AWS_REGION)
        resp = sqs.get_queue_attributes(
            QueueUrl=SQS_QUEUE_URL,
            AttributeNames=[
                "ApproximateNumberOfMessages",
                "ApproximateNumberOfMessagesNotVisible",
                "ApproximateNumberOfMessagesDelayed",
            ],
        )
        attrs = resp.get("Attributes", {})
        visible = attrs.get("ApproximateNumberOfMessages", "?")
        in_flight = attrs.get("ApproximateNumberOfMessagesNotVisible", "?")
        delayed = attrs.get("ApproximateNumberOfMessagesDelayed", "?")
        print(f"   Visible (available):  {visible}")
        print(f"   Not visible (in flight): {in_flight}")
        print(f"   Delayed:             {delayed}")
        print("   -> OK\n")
    except Exception as e:
        print(f"   -> FAIL: {e}")
        print("   Fix: Ensure the IAM role has sqs:GetQueueAttributes on this queue.\n")
        return 1

    # 4. SQS receive_message (dry run: receive 1, do not delete)
    print("4. SQS receive_message (1 message, no delete)")
    try:
        resp = sqs.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=1,
            VisibilityTimeout=30,
        )
        messages = resp.get("Messages") or []
        if messages:
            body = (messages[0].get("Body") or "")[:80]
            print(f"   Received 1 message (body preview): {body}...")
            print("   -> OK (message returns to queue after visibility timeout)\n")
        else:
            print("   No messages in queue right now (this is OK).")
            print("   -> OK\n")
    except Exception as e:
        print(f"   -> FAIL: {e}")
        print("   Fix: Ensure the IAM role has sqs:ReceiveMessage on this queue.\n")
        return 1

    print("=== All checks passed. You can start the worker: python fsbo_sqs_worker.py ===\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
