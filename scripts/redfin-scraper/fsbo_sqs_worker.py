"""
EC2 (or ECS) SQS worker for FSBO listing jobs.
Polls fsbo-listing-jobs, scrapes each URL with FSBO.py, pushes to Supabase.
Supports configurable concurrency for high throughput (e.g. 70k listings/hour).
"""
import json
import logging
import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from queue import Empty, Full, Queue
from typing import Any, Dict, List, Tuple

import boto3
import requests

from FSBO import scrape_redfin_listing, compute_completeness, _push_listing_to_supabase
from proxy_rotation import get_next_proxy, get_proxy_count, load_proxies


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("FSBOSQSWorker")


SQS_QUEUE_URL = os.environ.get(
    "FSBO_SQS_QUEUE_URL",
    "https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs",
)
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
# Concurrency: workers processing jobs in parallel. ~50–80 for 70k/hour (depends on scrape latency).
WORKER_CONCURRENCY = int(os.environ.get("FSBO_WORKER_CONCURRENCY", "50"))
# Max jobs to hold in memory (received but not yet processed). Keep below SQS visibility timeout capacity.
IN_FLIGHT_QUEUE_SIZE = int(os.environ.get("FSBO_IN_FLIGHT_QUEUE_SIZE", "500"))
# SQS receive batch size (max 10)
RECEIVE_BATCH_SIZE = 10
# Visibility timeout (seconds) — must be longer than time to process one message
VISIBILITY_TIMEOUT = int(os.environ.get("FSBO_VISIBILITY_TIMEOUT", "300"))

# Serialize Supabase writes (client may not be thread-safe)
_supabase_lock = threading.Lock()

# One requests.Session per worker thread (Session is not thread-safe)
_thread_local = threading.local()


def _get_session() -> requests.Session:
    if not hasattr(_thread_local, "session"):
        _thread_local.session = _build_session()
    return _thread_local.session


def _build_session() -> requests.Session:
    """
    Create a requests.Session for scraping. Proxy is set per request via
    proxy_rotation.get_next_proxy() in process_message for DataImpulse rotation.
    """
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/127.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive",
        }
    )
    return session


def process_message(body: Dict[str, Any], session: requests.Session) -> bool:
    """
    Process a single SQS job: scrape the listing URL and push to Supabase.
    Returns True if successful (saved to Supabase), False otherwise.
    """
    url = body.get("url")
    if not url:
        logger.warning("SQS message missing 'url'; skipping.")
        return False

    run_id = body.get("run_id", "fsbo-ec2-run")
    attempt = int(body.get("attempt", 1))

    logger.info(f"[JOB] run_id={run_id} attempt={attempt} url={url}")

    # Rotate DataImpulse proxy per request (round-robin from proxy_rotation)
    proxy_url = get_next_proxy()
    if proxy_url:
        session.proxies.update({"http": proxy_url, "https": proxy_url})
    else:
        session.proxies.clear()

    try:
        data = scrape_redfin_listing(url, session)
        if not data:
            logger.warning(f"No data returned for URL: {url}")
            return False

        data.setdefault("property_url", url)
        data["worker_run_id"] = run_id
        data["worker_attempt"] = attempt

        present, total, pct, missing = compute_completeness(data)
        data["completeness_present_required"] = present
        data["completeness_total_required"] = total
        data["completeness_ratio"] = round(pct, 4)
        data["completeness_missing_required"] = ",".join(missing) if missing else ""

        with _supabase_lock:
            ok = _push_listing_to_supabase(data)
        status = "saved" if ok else "supabase_error"

        logger.info(
            f"[{status}] {url} "
            f"completeness={present}/{total} ({pct*100:.1f}%), "
            f"missing={missing if missing else '[]'}"
        )
        return ok
    except Exception as e:
        logger.exception(f"Exception while processing URL {url}: {e}")
        return False


def _verify_sqs_connection(sqs_client) -> bool:
    """Verify we can reach SQS (credentials + queue). Returns True if OK."""
    try:
        resp = sqs_client.get_queue_attributes(
            QueueUrl=SQS_QUEUE_URL,
            AttributeNames=["ApproximateNumberOfMessages"],
        )
        logger.info(
            f"SQS connectivity OK. Queue has ~{resp.get('Attributes', {}).get('ApproximateNumberOfMessages', '?')} messages visible."
        )
        return True
    except Exception as e:
        logger.error(
            "Cannot connect to SQS. Check IAM role (instance profile), queue URL, and region. Error: %s",
            e,
        )
        return False


def _receiver_loop(
    sqs_client,
    job_queue: "Queue[Tuple[Dict[str, Any], str]]",
    stop_event: threading.Event,
) -> None:
    """Pull messages from SQS and put (body, receipt_handle) into job_queue."""
    while not stop_event.is_set():
        try:
            resp = sqs_client.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=RECEIVE_BATCH_SIZE,
                WaitTimeSeconds=10,
                VisibilityTimeout=VISIBILITY_TIMEOUT,
            )
        except Exception as e:
            logger.error("Error receiving messages from SQS: %s", e)
            if stop_event.wait(timeout=5):
                break
            continue

        messages = resp.get("Messages") or []
        if not messages:
            continue

        for msg in messages:
            if stop_event.is_set():
                break
            receipt_handle = msg.get("ReceiptHandle")
            body_raw = msg.get("Body") or "{}"
            try:
                body = json.loads(body_raw)
            except json.JSONDecodeError:
                logger.warning("Invalid JSON body: %r", body_raw)
                body = {}
            while not stop_event.is_set():
                try:
                    job_queue.put((body, receipt_handle), timeout=5)
                    break
                except Full:
                    continue


def _worker_process_job(
    item: Tuple[Dict[str, Any], str],
    sqs_client,
) -> bool:
    """Process one (body, receipt_handle); delete from SQS on completion. Uses thread-local session."""
    body, receipt_handle = item
    session = _get_session()
    delete_ok = True
    try:
        process_message(body, session)
    finally:
        try:
            sqs_client.delete_message(
                QueueUrl=SQS_QUEUE_URL,
                ReceiptHandle=receipt_handle,
            )
        except Exception as e:
            logger.error("Failed to delete SQS message: %s", e)
            delete_ok = False
    return delete_ok


def main() -> int:
    """
    Long-running EC2/ECS worker:
    - Verifies SQS connectivity at startup.
    - One thread receives from SQS and enqueues (body, receipt_handle).
    - A thread pool processes jobs concurrently (scrape + Supabase), then deletes.
    """
    if not SQS_QUEUE_URL:
        logger.error("FSBO_SQS_QUEUE_URL is not set.")
        return 1

    sqs = boto3.client("sqs", region_name=AWS_REGION)

    if not _verify_sqs_connection(sqs):
        logger.error("SQS connectivity check failed. Fix IAM/queue/region and restart.")
        return 1

    n_proxies = get_proxy_count()
    if n_proxies:
        logger.info(
            "FSBO SQS worker started. Queue=%s Region=%s Concurrency=%d DataImpulse proxies=%d (rotating)",
            SQS_QUEUE_URL,
            AWS_REGION,
            WORKER_CONCURRENCY,
            n_proxies,
        )
    else:
        logger.info(
            "FSBO SQS worker started. Queue=%s Region=%s Concurrency=%d (no proxy rotation)",
            SQS_QUEUE_URL,
            AWS_REGION,
            WORKER_CONCURRENCY,
        )

    job_queue: "Queue[Tuple[Dict[str, Any], str]]" = Queue(maxsize=IN_FLIGHT_QUEUE_SIZE)
    stop_event = threading.Event()

    receiver = threading.Thread(
        target=_receiver_loop,
        args=(sqs, job_queue, stop_event),
        daemon=True,
    )
    receiver.start()

    try:
        with ThreadPoolExecutor(max_workers=WORKER_CONCURRENCY) as executor:
            while True:
                try:
                    item = job_queue.get(timeout=20)
                except Empty:
                    continue
                executor.submit(_worker_process_job, item, sqs)
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        stop_event.set()
    return 0


if __name__ == "__main__":
    sys.exit(main())
