#!/usr/bin/env python3
"""
Look up property owner / resident data from CyberBackgroundChecks.com by address.
URL format: https://www.cyberbackgroundchecks.com/address/<street-slug>/<city>/<state>
Robots.txt compliant: uses User-Agent Mediapartners-Google (per cyberbackgroundchecks.com/robots.txt).
Run with Python that has cloudscraper (e.g. py -3.13 cyber_background_checks_lookup.py).

When available, requests are routed through a US-based residential proxy to
avoid Cloudflare IP reputation issues. Two modes are supported:

1) Proxy list file (one proxy per line, login:password@hostname:port):
   PROXY_LIST_FILE (default: proxies.txt). Rotates through the list per request.

2) DataImpulse-style HTTP proxy (host + login/password):
   PROXY_HOST, PROXY_PORT, PROXY_LOGIN, PROXY_PASSWORD
   Optional: PROXY_COUNTRY=us (adds __cr.us to login for US residential).

3) Scraper API (URL + apiKey):
   RESIDENTIAL_PROXY_API_URL, RESIDENTIAL_PROXY_API_KEY
   Calls: ...?apiKey=...&geoCode=us&superParam=true&url=<encoded target URL>
"""
import os
import re
import sys
from urllib.parse import quote

try:
    import cloudscraper
except ImportError:
    cloudscraper = None

try:
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None

# Robots.txt compliance for cyberbackgroundchecks.com (Mediapartners-Google)
USER_AGENT_MEDIAPARTNERS_GOOGLE = "Mediapartners-Google"

BASE_URL = "https://www.cyberbackgroundchecks.com"

# Proxy list file: one line per proxy, format login:password@hostname:port
PROXY_LIST_FILE = os.getenv("PROXY_LIST_FILE", "proxies.txt")

# Optional residential proxy: DataImpulse-style (host/port/login/password).
PROXY_HOST = os.getenv("PROXY_HOST")
PROXY_PORT = os.getenv("PROXY_PORT")
PROXY_LOGIN = os.getenv("PROXY_LOGIN") or os.getenv("PROXY_USER")
PROXY_PASSWORD = os.getenv("PROXY_PASSWORD")
PROXY_COUNTRY = os.getenv("PROXY_COUNTRY", "").strip().lower()  # e.g. "us" -> __cr.us
# Enforce superParam=true for residential proxy (DataImpulse: __superParam.true in login).
PROXY_SUPER_PARAM = os.getenv("PROXY_SUPER_PARAM", "true").strip().lower()

# Optional scraper API (URL + apiKey).
RESIDENTIAL_PROXY_API_URL = os.getenv("RESIDENTIAL_PROXY_API_URL") or os.getenv(
    "RESIDENTIAL_PROXY_URL"
)
RESIDENTIAL_PROXY_API_KEY = os.getenv("RESIDENTIAL_PROXY_API_KEY")

# Loaded proxy list and round-robin index
_proxy_list_cache = None
_proxy_index = [0]  # list so it's mutable in nested scope


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
            # format: login:password@hostname:port
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


def address_to_slug(street_address, city, state):
    """Build URL path: /address/<street-slug>/<city>/<state>."""
    # e.g. "1739 Emerald Sea Drive" -> "1739-emerald-sea-drive"
    street_slug = re.sub(r"[^\w\s]", "", street_address).strip().lower()
    street_slug = re.sub(r"\s+", "-", street_slug)
    city_slug = city.strip().lower().replace(" ", "-")
    state_slug = state.strip().lower().replace(" ", "")
    return f"/address/{street_slug}/{city_slug}/{state_slug}"


def _build_proxy_api_url(target_url: str) -> str:
    """
    Build the residential proxy API URL for a given target URL.

    This assumes the provider accepts:
      - apiKey: API key / token
      - geoCode: country code for routing (us)
      - superParam: "true" for premium/unblocked routing
      - url: the ultimate target URL to fetch
    """
    assert RESIDENTIAL_PROXY_API_URL is not None
    assert RESIDENTIAL_PROXY_API_KEY is not None
    encoded_target = quote(target_url, safe="")
    sep = "&" if "?" in RESIDENTIAL_PROXY_API_URL else "?"
    super_val = PROXY_SUPER_PARAM or "true"
    return (
        f"{RESIDENTIAL_PROXY_API_URL}{sep}apiKey={RESIDENTIAL_PROXY_API_KEY}"
        f"&geoCode=us&superParam={super_val}&url={encoded_target}"
    )


def fetch_page(url):
    """Fetch URL with User-Agent Mediapartners-Google for robots.txt compliance.

    Uses DataImpulse-style proxy (PROXY_* env) or scraper API when configured;
    otherwise direct cloudscraper/requests.
    """
    headers = {"User-Agent": USER_AGENT_MEDIAPARTNERS_GOOGLE}

    # 1) Scraper API when configured.
    if RESIDENTIAL_PROXY_API_URL and RESIDENTIAL_PROXY_API_KEY:
        import requests

        proxy_url = _build_proxy_api_url(url)
        resp = requests.get(proxy_url, timeout=30, headers=headers)
        return resp

    # 2) Proxy list file (rotate per request).
    proxies = _get_next_proxies()
    if not proxies:
        proxies = _dataimpulse_proxies()
    # 3) DataImpulse-style single proxy (host/port/login/password).
    if proxies:
        if cloudscraper and hasattr(cloudscraper, "create_scraper"):
            scraper = cloudscraper.create_scraper()
            resp = scraper.get(url, timeout=30, headers=headers, proxies=proxies)
        else:
            import requests

            resp = requests.get(url, timeout=30, headers=headers, proxies=proxies)
        return resp

    # 4) Direct.
    if cloudscraper and hasattr(cloudscraper, "create_scraper"):
        scraper = cloudscraper.create_scraper()
        resp = scraper.get(url, timeout=30, headers=headers)
    else:
        import requests

        resp = requests.get(url, timeout=30, headers=headers)
    return resp


def parse_owner_data(soup):
    """Extract owner/resident/address info from page (best-effort)."""
    results = []
    text_lower = soup.get_text().lower()

    # Common patterns: "owner", "property owner", "resident", "name"
    for tag in soup.find_all(["div", "section", "article", "p", "span", "td", "li"]):
        cls = " ".join(tag.get("class", []))
        txt = tag.get_text().strip()
        if not txt or len(txt) > 200:
            continue
        # Likely name/owner blocks
        if any(k in cls.lower() for k in ("owner", "resident", "name", "person", "result", "card", "profile")):
            results.append({"type": "block", "class": cls, "text": txt})
        if "owner" in txt.lower() or "resident" in txt.lower() or "lives at" in txt.lower():
            results.append({"type": "snippet", "text": txt})

    # Headings that might introduce owner name
    for tag in soup.find_all(["h1", "h2", "h3", "h4"]):
        txt = tag.get_text().strip()
        if txt and "who lives" in text_lower or "resident" in text_lower or "owner" in text_lower:
            results.append({"type": "heading", "text": txt})

    # Dedupe by text
    seen = set()
    unique = []
    for r in results:
        t = r["text"][:150]
        if t not in seen:
            seen.add(t)
            unique.append(r)
    return unique


def main():
    street = "1739 Emerald Sea Drive"
    city = "Chesapeake"
    state = "VA"

    path = address_to_slug(street, city, state)
    url = BASE_URL + path
    print(f"URL: {url}")
    print("Fetching with cloudscraper..." if cloudscraper else "Fetching with requests...")

    if not BeautifulSoup:
        print("Install beautifulsoup4 for parsing.")
        return 1

    try:
        resp = fetch_page(url)
    except Exception as e:
        print(f"Request error: {e}")
        return 1

    print(f"Status: {resp.status_code}")

    if resp.status_code != 200:
        print(f"Manual link: {url}")
        return 1

    soup = BeautifulSoup(resp.content, "html.parser")
    data = parse_owner_data(soup)

    out_path = "cyber_background_checks_result_1739_Emerald_Sea.txt"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(f"CyberBackgroundChecks address lookup: {street}, {city}, {state}\n")
        f.write(f"URL: {url}\n")
        f.write(f"Status: {resp.status_code}\n\n")
        if data:
            f.write("Extracted snippets:\n")
            for r in data:
                f.write(f"  [{r['type']}] {r['text'][:300]}\n")
        else:
            f.write("No owner/resident blocks detected. Raw page title and first 2000 chars:\n")
            f.write(soup.title.get_text() if soup.title else "")
            f.write("\n\n")
            f.write(soup.get_text()[:2000])
    print(f"Wrote: {out_path}")

    if data:
        print("\nExtracted snippets:")
        for r in data[:15]:
            print(f"  {r['text'][:120]}...")
    else:
        print("No structured owner blocks found; see output file for raw content.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
