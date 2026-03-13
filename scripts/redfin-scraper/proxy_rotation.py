"""
DataImpulse (and generic) proxy rotation for FSBO scraper.
Pattern from Skip Tracing Module (ask_grok_cyberbackground) and scrapy-rotating-proxies:
- Load proxy list from file or env (one URL per line or comma-separated).
- Round-robin, thread-safe get_next_proxy() so each request can use a different proxy.
Use in fsbo_sqs_worker and lambda_fsbo_worker for better rotation and fewer bans.
"""
import itertools
import os
import threading
from pathlib import Path
from typing import List, Optional

# Script dir for default proxy file path
_SCRIPT_DIR = Path(__file__).resolve().parent

_proxy_list: List[str] = []
_proxy_cycle = None
_proxy_lock = threading.Lock()


def _normalize_proxy(line: str) -> str:
    """Ensure proxy URL has scheme; return empty if invalid."""
    line = (line or "").strip()
    if not line or line.startswith("#"):
        return ""
    if not line.startswith(("http://", "https://")):
        line = "http://" + line
    return line


def _build_dataimpulse_urls() -> List[str]:
    """Build DataImpulse proxy URL from env. Country/region is configured at the provider or in the proxy list."""
    login = os.environ.get("DATAIMPULSE_LOGIN", "").strip()
    password = os.environ.get("DATAIMPULSE_PASSWORD", "").strip()
    host = os.environ.get("DATAIMPULSE_HOST", "gw.dataimpulse.com").strip()
    port = os.environ.get("DATAIMPULSE_PORT", "823").strip()

    if not login or not password:
        return []
    return [f"http://{login}:{password}@{host}:{port}"]


def load_proxies() -> List[str]:
    """
    Load proxy list for rotation. Order of precedence:
    1) DATAIMPULSE_PROXY_LIST_PATH — path to file (one proxy URL per line)
    2) DATAIMPULSE_PROXY_LIST — comma-separated URLs
    3) DataImpulse credentials in env (LOGIN, PASSWORD, HOST, PORT)
    Returns list of normalized proxy URLs (may be empty).
    """
    global _proxy_list, _proxy_cycle
    if _proxy_list:
        return _proxy_list

    out: List[str] = []

    # 1) File path
    path_str = os.environ.get("DATAIMPULSE_PROXY_LIST_PATH", "").strip()
    if path_str:
        p = Path(path_str)
        if not p.is_absolute():
            p = _SCRIPT_DIR / path_str
        if p.is_file():
            with open(p, "r", encoding="utf-8") as f:
                for line in f:
                    p_url = _normalize_proxy(line)
                    if p_url:
                        out.append(p_url)

    # 2) Comma-separated list in env
    if not out:
        list_str = os.environ.get("DATAIMPULSE_PROXY_LIST", "").strip()
        if list_str:
            for part in list_str.split(","):
                p_url = _normalize_proxy(part)
                if p_url:
                    out.append(p_url)

    # 3) Build from DataImpulse credentials (single or multi-region)
    if not out:
        out = _build_dataimpulse_urls()

    _proxy_list = out
    _proxy_cycle = itertools.cycle(out) if out else None
    return _proxy_list


def get_next_proxy() -> Optional[str]:
    """Next proxy from rotation (round-robin). Thread-safe. None if no proxies configured."""
    load_proxies()
    if _proxy_cycle is None:
        return None
    with _proxy_lock:
        return next(_proxy_cycle)


def get_proxy_count() -> int:
    """Number of proxies in the rotation (0 if none)."""
    return len(load_proxies())
