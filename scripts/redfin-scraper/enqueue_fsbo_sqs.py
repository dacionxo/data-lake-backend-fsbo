import argparse
import json
import logging
import os
from datetime import datetime, timedelta
from typing import List, Set

import boto3

from supabase_client import supabase


logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


def load_urls_from_file(path: str) -> List[str]:
    if not os.path.exists(path):
        raise FileNotFoundError(f"URL file not found: {path}")
    urls: List[str] = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            url = line.strip()
            if url:
                urls.append(url)
    logger.info(f"Loaded {len(urls)} URLs from {path}")
    return urls


def load_already_scraped_urls(max_age_days: int) -> Set[str]:
    """
    Fetch property_url values from fsbo_leads that have been scraped recently.
    Used to avoid re-enqueuing fresh listings and save proxy bandwidth.
    """
    if not supabase:
        logger.warning("Supabase client is not initialized; no dedup will be applied.")
        return set()

    cutoff: datetime | None = None
    if max_age_days > 0:
        cutoff = datetime.utcnow() - timedelta(days=max_age_days)

    try:
        query = supabase.table("fsbo_leads").select("property_url,last_scraped_at").limit(50000)
        resp = query.execute()
        rows = resp.data or []
    except Exception as e:
        logger.warning(f"Failed to fetch existing fsbo_leads from Supabase: {e}")
        return set()

    urls: Set[str] = set()
    for row in rows:
        url = (row.get("property_url") or "").strip()
        if not url:
            continue
        if cutoff and row.get("last_scraped_at"):
            try:
                ts = datetime.fromisoformat(str(row["last_scraped_at"]).replace("Z", "+00:00"))
                if ts >= cutoff:
                    urls.add(url)
            except Exception:
                # If timestamp is malformed, just ignore age-based filter
                urls.add(url)
        else:
            # If no age filter, consider any row as already scraped
            if max_age_days <= 0:
                urls.add(url)

    logger.info(f"Found {len(urls)} already-scraped URLs in fsbo_leads for deduplication.")
    return urls


def enqueue_urls(
    queue_url: str,
    urls: List[str],
    run_id: str,
    max_age_days: int,
    region_name: str | None = None,
) -> int:
    """
    Enqueue listing URLs into SQS for processing by the Lambda worker.
    Applies deduplication against recent fsbo_leads rows to minimize proxy traffic.
    """
    sqs = boto3.client("sqs", region_name=region_name)
    existing_urls = load_already_scraped_urls(max_age_days=max_age_days)

    to_send: List[str] = []
    for url in urls:
        if url in existing_urls:
            continue
        to_send.append(url)

    logger.info(f"{len(to_send)} URLs remaining after deduplication (from {len(urls)} total).")

    batch_size = 10
    sent = 0
    for i in range(0, len(to_send), batch_size):
        batch = to_send[i : i + batch_size]
        entries = []
        for j, url in enumerate(batch):
            body = json.dumps(
                {
                    "url": url,
                    "run_id": run_id,
                    "attempt": 1,
                }
            )
            entries.append({"Id": f"{i+j}", "MessageBody": body})

        resp = sqs.send_message_batch(QueueUrl=queue_url, Entries=entries)
        failed = resp.get("Failed", [])
        if failed:
            logger.warning(f"SQS send_message_batch had failures: {failed}")
        sent += len(entries) - len(failed)

    logger.info(f"Enqueued {sent} URLs to SQS queue {queue_url}")
    return sent


def main():
    parser = argparse.ArgumentParser(description="Enqueue FSBO listing URLs into SQS for Lambda scraping.")
    parser.add_argument("--queue-url", required=True, help="SQS queue URL for fsbo-listing-worker.")
    parser.add_argument(
        "--urls-file",
        required=True,
        help="Path to text file with one listing URL per line (e.g. fsbo_listing_urls.txt).",
    )
    parser.add_argument(
        "--run-id",
        default=datetime.utcnow().strftime("fsbo-%Y%m%d-%H%M%S"),
        help="Run identifier attached to each job for tracking.",
    )
    parser.add_argument(
        "--max-age-days",
        type=int,
        default=1,
        help="Do not enqueue URLs that have been scraped within the last N days (0 to disable).",
    )
    parser.add_argument(
        "--region",
        default=None,
        help="AWS region name for SQS client (optional, uses default if not set).",
    )

    args = parser.parse_args()
    urls = load_urls_from_file(args.urls_file)
    enqueue_urls(
        queue_url=args.queue_url,
        urls=urls,
        run_id=args.run_id,
        max_age_days=args.max_age_days,
        region_name=args.region,
    )


if __name__ == "__main__":
    main()

