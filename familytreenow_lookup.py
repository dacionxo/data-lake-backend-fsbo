#!/usr/bin/env python3
"""
Open a specific FamilyTreeNow people-search results page and extract a target
element using a precise CSS selector, using cloudscraper when available.

When using a scraper/headless-browser API (RESIDENTIAL_PROXY_API_URL + KEY):
  - render=true: access the target with a real browser and retrieve results.
  - blockResources=false: if still blocked, do not block resources.
  - customWait=2000: browser wait on the page for N ms (env PROXY_CUSTOM_WAIT_MS).

Target URL:
  https://www.familytreenow.com/search/people/results?streetaddress=...

Target CSS selector:
  body > div.container.body-content > div > div.col-sm-7... > a
"""

import os
import sys
from urllib.parse import quote

try:
    import cloudscraper
except ImportError:
    cloudscraper = None

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    sync_playwright = None

try:
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None


URL = (
    "https://www.familytreenow.com/search/people/results"
    "?streetaddress=2224%20Courtney%20Ave"
    "&citystatezip=Norfolk,%20VA"
    "&rid=asn"
)

# Headers that FamilyTreeNow accepts (browser-like + Referer).
FAMILYTREENOW_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0 Safari/537.36",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.familytreenow.com/",
    "Connection": "keep-alive",
}

CSS_SELECTOR = (
    "body > div.container.body-content > div > "
    "div.col-sm-7.col-md-8.col-lg-6 > div:nth-child(2) > div > "
    "div:nth-child(6) > div.panel-body > div > div > div:nth-child(1) > "
    "div:nth-child(1) > div > a"
)


# Proxy list file: one line per proxy, format login:password@hostname:port
PROXY_LIST_FILE = os.getenv("PROXY_LIST_FILE", "proxies.txt")

# DataImpulse-style proxy (host/port/login/password). Optional PROXY_COUNTRY=us.
PROXY_HOST = os.getenv("PROXY_HOST")
PROXY_PORT = os.getenv("PROXY_PORT")
PROXY_LOGIN = os.getenv("PROXY_LOGIN") or os.getenv("PROXY_USER")
PROXY_PASSWORD = os.getenv("PROXY_PASSWORD")
PROXY_COUNTRY = os.getenv("PROXY_COUNTRY", "").strip().lower()
# Enforce superParam=true for residential proxy (DataImpulse: __superParam.true in login).
PROXY_SUPER_PARAM = os.getenv("PROXY_SUPER_PARAM", "true").strip().lower()

# Browser waitUntil: domcontentloaded | networkidle0 | networkidle2 | load (default: load).
# Playwright accepts: load, domcontentloaded, networkidle, commit; we map networkidle0/2 -> networkidle.
_WAIT_UNTIL_OPTIONS = frozenset({"domcontentloaded", "networkidle0", "networkidle2", "load"})
FAMILYTREENOW_WAIT_UNTIL = os.getenv("FAMILYTREENOW_WAIT_UNTIL", "load").strip().lower()
if FAMILYTREENOW_WAIT_UNTIL not in _WAIT_UNTIL_OPTIONS:
    FAMILYTREENOW_WAIT_UNTIL = "load"
if FAMILYTREENOW_WAIT_UNTIL in ("networkidle0", "networkidle2"):
    _WAIT_UNTIL_PLAYWRIGHT = "networkidle"
else:
    _WAIT_UNTIL_PLAYWRIGHT = FAMILYTREENOW_WAIT_UNTIL

RESIDENTIAL_PROXY_API_URL = os.getenv("RESIDENTIAL_PROXY_API_URL") or os.getenv(
    "RESIDENTIAL_PROXY_URL"
)
RESIDENTIAL_PROXY_API_KEY = os.getenv("RESIDENTIAL_PROXY_API_KEY")

# Headless browser network params (scraper API): render=true, blockResources=false, customWait=2000
PROXY_RENDER = os.getenv("PROXY_RENDER", "true").strip().lower() == "true"
PROXY_BLOCK_RESOURCES = os.getenv("PROXY_BLOCK_RESOURCES", "false").strip().lower() == "true"
PROXY_CUSTOM_WAIT_MS = os.getenv("PROXY_CUSTOM_WAIT_MS", "2000").strip()

_proxy_list_cache = None
_proxy_index = [0]


def _load_proxy_list():
    """Load proxy list from file. Each line: login:password@hostname:port."""
    global _proxy_list_cache
    if _proxy_list_cache is not None:
        return _proxy_list_cache
    path = PROXY_LIST_FILE
    if not path or not os.path.isfile(path):
        _proxy_list_cache = []
        return _proxy_list_cache
    proxies = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "@" not in line:
                continue
            auth, hostport = line.rsplit("@", 1)
            if ":" not in auth or ":" not in hostport:
                continue
            raw_user, pw = auth.split(":", 1)
            if PROXY_SUPER_PARAM and "__superParam." not in raw_user:
                raw_user = f"{raw_user}__superParam.{PROXY_SUPER_PARAM}"
            user = quote(raw_user, safe="")
            pw = quote(pw, safe="")
            base = f"http://{user}:{pw}@{hostport}"
            proxies.append({"http": base, "https": base})
    _proxy_list_cache = proxies
    return _proxy_list_cache


def _get_next_proxies():
    """Return next proxy dict from the list (round-robin), or None if list empty."""
    lst = _load_proxy_list()
    if not lst:
        return None
    idx = _proxy_index[0] % len(lst)
    _proxy_index[0] += 1
    return lst[idx]


def _get_next_proxy_playwright():
    """
    Return next proxy in Playwright format: {"server": "http://host:port", "username": ..., "password": ...},
    or None. Uses proxy list file first, then single DataImpulse env proxy.
    """
    # Prefer proxy list: we need server + username + password (unquoted for Playwright).
    path = PROXY_LIST_FILE
    if path and os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as f:
            lines = [ln.strip() for ln in f if ln.strip() and not ln.strip().startswith("#")]
        if lines:
            line = lines[_proxy_index[0] % len(lines)]
            _proxy_index[0] += 1
            if "@" in line and ":" in line:
                auth, hostport = line.rsplit("@", 1)
                if ":" in auth and ":" in hostport:
                    raw_user, pw = auth.split(":", 1)
                    if PROXY_SUPER_PARAM and "__superParam." not in raw_user:
                        raw_user = f"{raw_user}__superParam.{PROXY_SUPER_PARAM}"
                    return {
                        "server": f"http://{hostport}",
                        "username": raw_user,
                        "password": pw,
                    }
    if all([PROXY_HOST, PROXY_PORT, PROXY_LOGIN, PROXY_PASSWORD]):
        login = PROXY_LOGIN
        if PROXY_COUNTRY:
            login = f"{login}__cr.{PROXY_COUNTRY}"
        if PROXY_SUPER_PARAM and "__superParam." not in login:
            login = f"{login}__superParam.{PROXY_SUPER_PARAM}"
        return {
            "server": f"http://{PROXY_HOST}:{PROXY_PORT}",
            "username": login,
            "password": PROXY_PASSWORD,
        }
    return None


def _dataimpulse_proxies():
    """Build requests proxies dict for DataImpulse-style proxy with optional country."""
    if not all([PROXY_HOST, PROXY_PORT, PROXY_LOGIN, PROXY_PASSWORD]):
        return None
    login = PROXY_LOGIN
    if PROXY_COUNTRY:
        login = f"{login}__cr.{PROXY_COUNTRY}"
    if PROXY_SUPER_PARAM and "__superParam." not in login:
        login = f"{login}__superParam.{PROXY_SUPER_PARAM}"
    user = quote(login, safe="")
    pw = quote(PROXY_PASSWORD, safe="")
    base = f"http://{user}:{pw}@{PROXY_HOST}:{PROXY_PORT}"
    return {"http": base, "https": base}


def _build_proxy_api_url(target_url: str) -> str:
    """
    Build scraper/headless-browser API URL with geoCode=us, superParam=true,
    and optional render=true, blockResources=false, customWait=2000.
    """
    assert RESIDENTIAL_PROXY_API_URL is not None
    assert RESIDENTIAL_PROXY_API_KEY is not None
    encoded_target = quote(target_url, safe="")
    sep = "&" if "?" in RESIDENTIAL_PROXY_API_URL else "?"
    super_val = PROXY_SUPER_PARAM or "true"
    parts = [
        f"{RESIDENTIAL_PROXY_API_URL}{sep}apiKey={RESIDENTIAL_PROXY_API_KEY}",
        f"geoCode=us",
        f"superParam={super_val}",
        f"url={encoded_target}",
    ]
    if PROXY_RENDER:
        parts.append("render=true")
    parts.append(f"blockResources={'true' if PROXY_BLOCK_RESOURCES else 'false'}")
    try:
        wait_ms = int(PROXY_CUSTOM_WAIT_MS) if PROXY_CUSTOM_WAIT_MS else 2000
    except ValueError:
        wait_ms = 2000
    parts.append(f"customWait={wait_ms}")
    return "&".join(parts)


def get_scraper():
    """
    Return a cloudscraper session if available, otherwise None.

    Some environments may have a cloudscraper module without create_scraper;
    in that case we gracefully fall back to requests.
    """
    if cloudscraper and hasattr(cloudscraper, "create_scraper"):
        return cloudscraper.create_scraper()
    return None


def fetch_page_with_browser(url: str):
    """
    Fetch URL with a real browser (Playwright): JavaScript runs and cookies are kept.
    Returns an object with .status_code and .content, or None if Playwright unavailable.
    """
    if sync_playwright is None:
        return None
    proxy = _get_next_proxy_playwright()
    try:
        with sync_playwright() as p:
            launch_opts = {"headless": True, "timeout": 30000}
            if proxy:
                launch_opts["proxy"] = proxy
            browser = p.chromium.launch(**launch_opts)
            context = browser.new_context(
                user_agent=FAMILYTREENOW_HEADERS["User-Agent"],
                locale="en-US",
                extra_http_headers={
                    "Accept-Language": FAMILYTREENOW_HEADERS["Accept-Language"],
                    "Referer": FAMILYTREENOW_HEADERS["Referer"],
                },
            )
            page = context.new_page()
            response = page.goto(url, wait_until=_WAIT_UNTIL_PLAYWRIGHT, timeout=30000)
            status = response.status if response else 0
            content = page.content()
            browser.close()
            return type("BrowserResponse", (), {"status_code": status, "content": content.encode("utf-8")})()
    except Exception:
        return None


def fetch_page(url: str):
    """Fetch target URL: prefer browser (cookies + JS), else residential proxy, else direct."""
    headers = FAMILYTREENOW_HEADERS

    # 0) Browser path (cookies + JavaScript) when Playwright is available.
    if sync_playwright is not None:
        browser_resp = fetch_page_with_browser(url)
        if browser_resp is not None and browser_resp.status_code == 200:
            return browser_resp
        # If browser got 403 or failed, fall through to requests path (with proxy).

    # 1) Scraper API (headless browser network) when configured.
    if RESIDENTIAL_PROXY_API_URL and RESIDENTIAL_PROXY_API_KEY:
        import requests

        proxy_url = _build_proxy_api_url(url)
        try:
            wait_ms = int(PROXY_CUSTOM_WAIT_MS) if PROXY_CUSTOM_WAIT_MS else 2000
        except ValueError:
            wait_ms = 2000
        timeout_sec = max(30, (wait_ms / 1000) + 15)
        resp = requests.get(proxy_url, headers=headers, timeout=timeout_sec)
        return resp

    # 2) Proxy list file (rotate per request), then single DataImpulse proxy.
    proxies = _get_next_proxies()
    if not proxies:
        proxies = _dataimpulse_proxies()
    if proxies:
        scraper = get_scraper()
        if scraper is not None:
            resp = scraper.get(url, headers=headers, timeout=30, proxies=proxies)
        else:
            import requests

            resp = requests.get(url, headers=headers, timeout=30, proxies=proxies)
        return resp

    # 3) Direct.
    scraper = get_scraper()
    if scraper is not None:
        resp = scraper.get(url, headers=headers, timeout=30)
    else:
        import requests

        resp = requests.get(url, headers=headers, timeout=30)
    return resp


def main() -> int:
    print(f"Fetching FamilyTreeNow URL:\n  {URL}")
    if RESIDENTIAL_PROXY_API_URL and RESIDENTIAL_PROXY_API_KEY:
        print("Using headless browser API (render=true, blockResources=false, customWait)...")
    if sync_playwright is not None and not (RESIDENTIAL_PROXY_API_URL and RESIDENTIAL_PROXY_API_KEY):
        print("Using browser (cookies + JavaScript) with proxy if configured...")
        print(f"  wait_until={FAMILYTREENOW_WAIT_UNTIL}")
    if not BeautifulSoup:
        print("Error: beautifulsoup4 is not installed. Install with: pip install beautifulsoup4")
        return 1

    try:
        resp = fetch_page(URL)
    except Exception as exc:  # pragma: no cover - runtime safeguard
        print(f"Request error: {exc}")
        return 1

    print(f"HTTP status: {resp.status_code}")
    if resp.status_code != 200:
        print("Non-200 response; cannot reliably parse page.")
        return 1

    soup = BeautifulSoup(resp.content, "html.parser")
    node = soup.select_one(CSS_SELECTOR)

    if not node:
        print("CSS selector did not match any element.")
        return 1

    text = node.get_text(strip=True)
    href = node.get("href")

    print("\nMatched element via CSS selector:")
    print(f"  Text: {text!r}")
    print(f"  Href: {href!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

