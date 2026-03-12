import json
import logging
import os
from datetime import datetime
from typing import Any, Dict, List

import requests

from FSBO import scrape_redfin_listing, compute_completeness


logger = logging.getLogger()
logger.setLevel(logging.INFO)


DATAIMPULSE_LOGIN_ENV = "DATAIMPULSE_LOGIN"
DATAIMPULSE_PASSWORD_ENV = "DATAIMPULSE_PASSWORD"
DATAIMPULSE_HOST_ENV = "DATAIMPULSE_HOST"
DATAIMPULSE_PORT_ENV = "DATAIMPULSE_PORT"

SUPABASE_URL_ENV = "SUPABASE_URL"
SUPABASE_SERVICE_ROLE_KEY_ENV = "SUPABASE_SERVICE_ROLE_KEY"
SUPABASE_FSBO_TABLE_ENV = "SUPABASE_FSBO_TABLE"  # default: fsbo_leads


def _build_proxy_url() -> str:
    """
    Build the HTTP proxy URL for DataImpulse rotating residential proxies using
    Lambda environment variables. Does NOT hardcode credentials.
    """
    login = os.environ.get(DATAIMPULSE_LOGIN_ENV)
    password = os.environ.get(DATAIMPULSE_PASSWORD_ENV)
    host = os.environ.get(DATAIMPULSE_HOST_ENV, "gw.dataimpulse.com")
    port = os.environ.get(DATAIMPULSE_PORT_ENV, "823")

    if not login or not password:
        raise RuntimeError(
            "DataImpulse credentials are not set in environment variables "
            f"({DATAIMPULSE_LOGIN_ENV}, {DATAIMPULSE_PASSWORD_ENV})."
        )

    # Username is used as-is (no region suffix needed)
    username = login
    return f"http://{username}:{password}@{host}:{port}"


def _build_session() -> requests.Session:
    """
    Create a requests.Session configured to use DataImpulse rotating
    residential proxies and efficient headers for HTML-only scraping.
    """
    proxy_url = _build_proxy_url()
    session = requests.Session()
    session.proxies.update(
        {
            "http": proxy_url,
            "https": proxy_url,
        }
    )
    session.headers.update(
        {
            # Realistic browser UA
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/127.0.0.0 Safari/537.36"
            ),
            # Request HTML only (no images or other heavy assets)
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive",
        }
    )
    session.timeout = 30
    return session


def _get_supabase_rest_config() -> Dict[str, str]:
    """
    Read Supabase REST configuration from environment.
    Uses the service role key so upserts work regardless of RLS.
    """
    url = os.environ.get(SUPABASE_URL_ENV)
    key = os.environ.get(SUPABASE_SERVICE_ROLE_KEY_ENV)
    table = os.environ.get(SUPABASE_FSBO_TABLE_ENV, "fsbo_leads")

    if not url or not key:
        raise RuntimeError(
            "Supabase REST config not set (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing)."
        )

    # Normalize URL (strip trailing slash)
    url = url.rstrip("/")
    return {"url": url, "key": key, "table": table}


def _supabase_upsert_fsbo_lead(data: Dict[str, Any]) -> bool:
    """
    Minimal Supabase REST upsert into fsbo_leads.
    Relies on Supabase side to handle schema/type coercion where possible.
    """
    cfg = _get_supabase_rest_config()
    endpoint = f"{cfg['url']}/rest/v1/{cfg['table']}"

    if not data.get("property_url"):
        logging.warning("Skipping Supabase upsert: missing property_url")
        return False

    # Basic timestamps
    now_iso = datetime.utcnow().isoformat()
    data.setdefault("scrape_date", now_iso.split("T")[0])
    data["last_scraped_at"] = now_iso

    # Remove obviously unserializable values (best-effort)
    safe_payload: Dict[str, Any] = {}
    for k, v in data.items():
        try:
            json.dumps(v)
            safe_payload[k] = v
        except TypeError:
            safe_payload[k] = str(v)

    headers = {
        "apikey": cfg["key"],
        "Authorization": f"Bearer {cfg['key']}",
        "Content-Type": "application/json",
        # Use merge-duplicates upsert on property_url
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }

    # Upsert based on property_url conflict target
    params = {"on_conflict": "property_url"}

    resp = requests.post(endpoint, headers=headers, params=params, json=[safe_payload])
    if 200 <= resp.status_code < 300:
        return True

    logging.warning(
        f"Supabase upsert failed for {data.get('property_url')}: "
        f"status={resp.status_code}, body={resp.text}"
    )
    return False


def _scrape_and_save(url: str, run_id: str, attempt: int) -> Dict[str, Any]:
    """
    Scrape a single listing URL via DataImpulse proxy, compute completeness,
    and upsert into Supabase using existing helper.
    Returns a small status dict for metrics.
    """
    session = _build_session()
    try:
        data = scrape_redfin_listing(url, session)
        if not data:
            logger.warning(f"No data returned for URL: {url}")
            return {"url": url, "status": "empty"}

        # Attach run metadata
        data.setdefault("property_url", url)
        data["lambda_run_id"] = run_id
        data["lambda_attempt"] = attempt

        # Compute completeness using shared logic
        present, total, pct, missing = compute_completeness(data)
        data["completeness_present_required"] = present
        data["completeness_total_required"] = total
        data["completeness_ratio"] = round(pct, 4)
        data["completeness_missing_required"] = ",".join(missing) if missing else ""

        ok = _supabase_upsert_fsbo_lead(data)
        status = "saved" if ok else "supabase_error"
        logger.info(
            f"[{status}] {url} "
            f"completeness={present}/{total} ({pct*100:.1f}%), "
            f"missing={missing if missing else '[]'}"
        )
        return {
            "url": url,
            "status": status,
            "completeness_ratio": data["completeness_ratio"],
        }
    except Exception as e:
        logger.warning(f"Scrape failed for {url}: {e}")
        return {"url": url, "status": "error", "error": str(e)}


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda handler for processing FSBO listing scrape jobs from SQS.

    Expected SQS message body JSON:
      {
        "url": "https://www.redfin.com/...",
        "run_id": "fsbo-2026-03-11",
        "attempt": 1
      }
    """
    records: List[Dict[str, Any]] = event.get("Records", [])
    results: List[Dict[str, Any]] = []

    for record in records:
        try:
            body = record.get("body") or "{}"
            job = json.loads(body)
        except json.JSONDecodeError:
            logger.warning("Received invalid JSON body in SQS message.")
            continue

        url = job.get("url")
        if not url:
            logger.warning("SQS job missing 'url'; skipping.")
            continue

        run_id = job.get("run_id", "fsbo-lambda-run")
        attempt = int(job.get("attempt", 1))
        result = _scrape_and_save(url, run_id, attempt)
        results.append(result)

    # Aggregate simple metrics for CloudWatch / debugging
    total = len(results)
    saved = sum(1 for r in results if r.get("status") == "saved")
    errors = sum(1 for r in results if r.get("status") == "error")

    logger.info(
        f"Lambda batch done: total={total}, saved={saved}, errors={errors}"
    )

    return {
        "batch_total": total,
        "saved": saved,
        "errors": errors,
        "results": results,
    }

