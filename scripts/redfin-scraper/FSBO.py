#!/usr/bin/env python3
"""
World-Class Redfin FSBO Lead Scraper

- Recursively parses Redfin XML sitemaps (site index and state-level)
- Extracts all property URLs in target states
- Uses HomeHarvest's session if available for robust requests
- Explicitly extracts every field in FIELDS from each listing page and logs missing fields
- Real-time CSV/database sync
- Docker/cloud-ready, proxy/throttling supported, error logs
- Handles sitemap requests directly to avoid 421 errors
- Preserves leading zeros in ZIP codes
- Cleans price data by removing "Price," and "—Est." text
- Extracts monthly payment estimates
"""
import requests
import xml.etree.ElementTree as ET
try:
    import pandas as pd
except Exception:
    # In environments where pandas (or its platform-specific wheels) are not available
    # (e.g. AWS Lambda with a Windows-built wheel), fall back to a stub. Code paths
    # that require pandas (CSV writing, some conversions) must guard on `pd is not None`.
    pd = None
from tqdm import tqdm
import time
import random
import logging
import sys
import os
import asyncio
from bs4 import BeautifulSoup
import re
import json
from concurrent.futures import ThreadPoolExecutor
import threading
from requests_ip_rotator import ApiGateway

# Async HTTP client
import aiohttp

# HomeHarvest requires Python 3.10+ due to type union syntax (| operator)
# Skip import on older Python versions to avoid compatibility errors
if sys.version_info >= (3, 10):
    try:
        # Try to import HomeHarvest's Scraper base for better request handling if available
        from homeharvest.core.scrapers import Scraper
    except ImportError:
        Scraper = None
else:
    Scraper = None

try:
    from supabase_client import save_fsbo_pagination_to_supabase, save_lead_to_fsbo_leads
except ImportError:
    save_fsbo_pagination_to_supabase = None
    save_lead_to_fsbo_leads = None

# Target states to scrape. Includes all US states plus DC.
TARGET_STATES = {
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
    "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
    "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
    "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
    "DC",
}
# Generate state-specific sitemap URLs using format: newest_listings_{STATE}.xml
SITEMAP_URLS = [
    f"https://www.redfin.com/newest_listings_{state}.xml"
    for state in sorted(TARGET_STATES)
]
CSV_PATH = r"D:\Downloads\FSBO Documents\scraper.csv"
LOG_PATH = r"D:\Downloads\FSBO Documents\scraper.log"
URL_EXPORT_PATH = r"D:\Downloads\FSBO Documents\fsbo_listing_urls.txt"

# Async tuning defaults (can be overridden via CLI/env)
DEFAULT_ASYNC_CONCURRENCY = int(os.environ.get("FSBO_ASYNC_CONCURRENCY", "200"))
DEFAULT_ASYNC_BATCH_SIZE = int(os.environ.get("FSBO_ASYNC_BATCH_SIZE", "200"))

# Max listings to scrape and import (CSV + Supabase).
# Set to None for no limit (production / full run).
LISTING_IMPORT_LIMIT = None

# Blacklisted phone numbers - these will not be included in the export
BLACKLISTED_PHONE_NUMBERS = ["1-844-759-7732", "844-759-7732", "(844) 759-7732", "8447597732"]

# URLs that must never be treated as property listings (e.g. CDN images, static assets)
BLOCKLISTED_LISTING_URLS = frozenset([
    "https://ssl.cdn-redfin.com/vLATEST/images/footer/flags/united-states.png",
    "https://ssl.cdn-redfin.com/vLATEST/images/footer/equal-housing.png",
])
# Substrings that indicate a URL is not a property listing page (do not scrape/import)
NON_LISTING_URL_PATTERNS = (
    "cdn-redfin.com/images/",
    "150x150/gen120x120",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".xml",
)

# Do not scrape photos from these areas (Redfin estimate comps, similar listings, new listings, footer)
PHOTOS_EXCLUDED_CONTAINER_SELECTORS = [
    "#redfin-estimate",
    "#lsis-listings",
    "#lsis-new-listings-in-zip-panel",
    "#new-listings-in-zip-scroll",
    "#recommended-homes-scroll",
    "div.footerContent.fluid-gutter.row",
    "#content > div:nth-child(11)",
]

FIELDS = [
    "scrape_date", "property_url", "property_id", "listing_id", "mls", "mls_id", "mls_status", "status", "permalink",
    "street", "unit", "city", "state", "zip_code", "formatted_address",
    "style", "beds", "full_baths", "half_baths", "sqft", "year_built", "stories", "garage", "lot_sqft", "text", "type",
    "days_on_mls", "list_price", "list_price_min", "list_price_max", "list_date", "pending_date", "sold_price",
    "last_sold_date", "last_sold_price", "price_per_sqft", "new_construction", "hoa_fee", "monthly_fees",
    "one_time_fees",
    "estimated_value", "tax_assessed_value", "tax_history", "latitude", "longitude", "neighborhoods", "county",
    "fips_code", "parcel_number", "nearby_schools", "agent_uuid", "agent_name", "agent_email", "broker_uuid",
    "broker_name",
    "office_uuid", "office_name", "office_email",
    # Consolidated Phone Numbers
    "agent_phone", "agent_phone_1", "agent_phone_2", "listing_agent_phone", "listing_agent_phone_2",
    "listing_agent_phone_3",
    "listing_agent_phone_4", "listing_agent_phone_5", "office_phones",
    "agent_state_license",
    "estimated_monthly_rental", "tags", "flags", "photos", "primary_photo", "alt_photos", "open_houses", "units",
    "pet_policy", "parking", "terms", "current_estimates", "estimates", "ai_investment_score", "dnc_flag",
    "privacy_flag",
    # Added individual image fields
    "image1_url", "image2_url", "image3_url", "image4_url",
    # Added new fields
    "listing_source_name", "listing_source_id", "listing_source",
    "monthly_payment_estimate", "time_listed", "listing_agent", "property_type_detail",
    # Adding the newly requested fields
    "listing_agent_email"
]

# Subset of fields that are considered required for a "complete" listing.
# Used for computing per-listing completeness scores and run-level metrics.
REQUIRED_FIELDS = [
    "property_url",
    "street",
    "city",
    "state",
    "zip_code",
    "beds",
    "full_baths",
    "sqft",
    "list_price",
    "status",
    "agent_name",
    "agent_email",
    "agent_phone",
]

# Create log directory if it doesn't exist
try:
    log_dir = os.path.dirname(LOG_PATH)
    if log_dir and not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)
    logging.basicConfig(filename=LOG_PATH, level=logging.INFO)
except (PermissionError, OSError):
    # If we can't create the log file, use console logging instead
    logging.basicConfig(level=logging.INFO)


def is_valid_listing_url(url):
    """
    Return False if url is blocklisted or is a non-listing resource (e.g. CDN images).
    Ensures only property listing pages are scraped/imported.
    """
    if not url or not isinstance(url, str):
        return False
    u = url.strip()
    if u in BLOCKLISTED_LISTING_URLS:
        return False
    if any(pat in u for pat in NON_LISTING_URL_PATTERNS):
        return False
    return True


def fetch_listing_urls_from_sitemap(sitemap_url, session):
    """Recursively fetch all property URLs from Redfin sitemaps."""
    listing_urls = set()
    try:
        logging.info(f"Fetching sitemap: {sitemap_url}")
        resp = session.get(sitemap_url, timeout=30)
        resp.raise_for_status()
        root = ET.fromstring(resp.content)
        if root.tag[0] == "{":
            namespace = root.tag[1:].split("}")[0]
        else:
            namespace = ""
        ns = {'ns': namespace} if namespace else {}

        if root.tag.endswith('sitemapindex'):
            sitemap_tags = root.findall('.//ns:sitemap', ns) if ns else root.findall('.//sitemap')
            logging.info(f"Found {len(sitemap_tags)} state sitemaps in {sitemap_url}")
            for sm in sitemap_tags:
                state_url_tag = sm.find('ns:loc', ns) if ns else sm.find('loc')
                if state_url_tag is not None:
                    state_feed_url = state_url_tag.text
                    logging.info(f"Fetching state sitemap: {state_feed_url}")
                    state_listing_urls = fetch_listing_urls_from_sitemap(state_feed_url, session)
                    listing_urls.update(state_listing_urls)
        elif root.tag.endswith('urlset'):
            url_tags = root.findall('.//ns:url', ns) if ns else root.findall('.//url')
            logging.info(f"Found {len(url_tags)} listings in {sitemap_url}")
            for url_tag in url_tags:
                loc_tag = url_tag.find('ns:loc', ns) if ns else url_tag.find('loc')
                if loc_tag is not None:
                    loc = loc_tag.text
                    if loc and any(f"/{state}/" in loc for state in TARGET_STATES) and is_valid_listing_url(loc):
                        listing_urls.add(loc)
        else:
            logging.warning(f"Unknown root tag {root.tag} in {sitemap_url}")
    except Exception as e:
        logging.error(f"Failed to parse sitemap {sitemap_url}: {e}")
    return listing_urls


def fetch_sitemap_urls(direct_session):
    """Fetch all listing URLs from the main sitemap indexes using direct session."""
    all_listing_urls = set()
    for sitemap_url in SITEMAP_URLS:
        urls = fetch_listing_urls_from_sitemap(sitemap_url, direct_session)
        logging.info(f"Fetched {len(urls)} listing URLs from {sitemap_url}")
        all_listing_urls.update(urls)
    
    # Get a proper random sample for display (not just first 5)
    if all_listing_urls:
        sample_size = min(5, len(all_listing_urls))
        sample = random.sample(list(all_listing_urls), sample_size)
        print(f"Sample listing URLs ({sample_size} of {len(all_listing_urls)}): {sample}")
    else:
        print("No listing URLs found in sitemaps")
    
    return list(all_listing_urls)


def load_urls_from_file(path: str):
    """Load listing URLs from a text file (one URL per line)."""
    if not os.path.exists(path):
        logging.error(f"URLs file not found: {path}")
        return []
    urls = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            url = line.strip()
            if url:
                urls.append(url)
    logging.info(f"Loaded {len(urls)} listing URLs from file: {path}")
    return urls


def export_listing_urls(export_path: str = URL_EXPORT_PATH) -> int:
    """
    Fetch all listing URLs from sitemaps and export them to a local text file.
    One URL per line. Returns the number of URLs written.
    """
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
    })

    urls = fetch_sitemap_urls(session)
    urls = sorted(set(urls))

    export_dir = os.path.dirname(export_path)
    if export_dir and not os.path.exists(export_dir):
        os.makedirs(export_dir, exist_ok=True)

    with open(export_path, "w", encoding="utf-8") as f:
        for url in urls:
            f.write(url + "\n")

    msg = f"Exported {len(urls)} listing URLs to {export_path}"
    logging.info(msg)
    print(msg)
    return len(urls)


def log_missing(field, url):
    logging.warning(f"{field} not found for {url}")


def compute_completeness(data, required_fields=None):
    """
    Compute a simple completeness score for a scraped listing.
    Returns (present_count, total_required, pct, missing_fields).
    """
    if required_fields is None:
        required_fields = REQUIRED_FIELDS

    missing = []
    present = 0
    total = len(required_fields)

    for f in required_fields:
        v = data.get(f)
        if v is None or (isinstance(v, str) and not v.strip()):
            missing.append(f)
        else:
            present += 1

    pct = present / total if total > 0 else 1.0
    return present, total, pct, missing


# HELPER FUNCTIONS FOR ENHANCED EXTRACTION
def deep_get(data, keys):
    """Safely access nested dictionary items"""
    if not data or not isinstance(data, dict):
        return None

    if not keys:
        return data

    if len(keys) == 1:
        return data.get(keys[0])

    key = keys[0]
    if key in data and isinstance(data[key], dict):
        return deep_get(data[key], keys[1:])

    return None


# NEW: Function to normalize ZIP codes
def normalize_zip(zip_like):
    """
    Normalize ZIP-like input to a 5-digit string.
    - If zip_like is None/empty -> return ""
    - Extract the first run of digits, take last 5 if >5, pad left with zeros if <5.
    """
    if not zip_like:
        return ""
    # Make sure we operate on string
    s = str(zip_like)
    # Extract only digits
    m = re.search(r'(\d+)', s)
    if not m:
        return ""
    digits = m.group(1)
    # If longer than 5 (e.g., ZIP+4 as '123456789' or '12345-6789'), prefer first 5
    if len(digits) >= 5:
        return digits[:5]
    # If shorter, zero-pad to 5
    return digits.zfill(5)


# NEW: Function to clean price text
def clean_price_text(price_text):
    """
    Clean price text by removing unwanted prefixes and suffixes
    """
    if not price_text:
        return ""

    # Convert to string if not already
    price_str = str(price_text).strip()

    # Remove "Price," prefix
    price_str = re.sub(r'^Price,\s*', '', price_str)

    # Remove "—Est." suffix
    price_str = re.sub(r'—Est\.$', '', price_str)
    price_str = re.sub(r'—Est\.?$', '', price_str)  # Handle cases with/without period

    # Remove any other variations of "Est" suffix
    price_str = re.sub(r'\s*Est\.?$', '', price_str)

    return price_str.strip()


def extract_detailed_json(soup, url):
    """Extract JSON data from script tags with more comprehensive patterns."""
    json_patterns = [
        r'window\.__INITIAL_STATE__\s*=\s*(\{.*?\});',
        r'window\.__PRELOADED_STATE__\s*=\s*(\{.*?\});',
        r'_PRELOADED_STATE_\s*=\s*(\{.*?\});',
        r'window\.__reactServerState\s*=\s*(\{.*?\});',
        r'window\.__APOLLO_STATE__\s*=\s*(\{.*?\});',
        r'window\.__REDUX_STATE__\s*=\s*(\{.*?\});',
        r'ReactDOM.hydrate\(.*?,\s*(\{.*?\})\);'
    ]

    for script in soup.find_all("script"):
        if not script.string:
            continue

        script_text = script.string
        for pattern in json_patterns:
            try:
                match = re.search(pattern, script_text, re.DOTALL)
                if match:
                    json_text = match.group(1)
                    # Balance braces if needed
                    open_braces = json_text.count('{')
                    close_braces = json_text.count('}')
                    if open_braces > close_braces:
                        json_text += '}' * (open_braces - close_braces)
                    return json.loads(json_text)
            except Exception:
                continue

    # Try inline JSON with LD+JSON
    for script in soup.find_all("script", {"type": "application/ld+json"}):
        if script.string:
            try:
                return json.loads(script.string)
            except:
                continue

    return {}


def extract_json_from_html(soup, url):
    # Find JSON inside <script> tags
    for script in soup.find_all("script"):
        if script.string and "window.__INITIAL_STATE__" in script.string:
            try:
                match = re.search(r'window\.__INITIAL_STATE__\s*=\s*(\{.*?\});', script.string, re.DOTALL)
                if match:
                    json_text = match.group(1)
                    return json.loads(json_text)
            except Exception as e:
                logging.error(f"Error parsing JSON for {url}: {e}")
    return {}


# Function for XPath extraction when needed - using lxml if available
def extract_by_xpath(html_content, xpath_expression):
    try:
        from lxml import html
        tree = html.fromstring(html_content)
        elements = tree.xpath(xpath_expression)
        if elements:
            if hasattr(elements[0], 'text_content'):
                return elements[0].text_content().strip()
            elif isinstance(elements[0], str):
                return elements[0].strip()
    except ImportError:
        logging.info("lxml not available for XPath extraction, falling back to CSS selectors")
    except Exception as e:
        logging.error(f"XPath extraction error: {e}")
    return None


# Function to extract email addresses from text
def extract_email_from_text(text):
    if not text:
        return None

    email_pattern = re.compile(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')
    match = email_pattern.search(text)
    if match:
        return match.group(0)
    return None


# Function to clean and normalize phone numbers
def normalize_phone(phone_text):
    if not phone_text:
        return ""

    # Clean the phone text
    digits_only = re.sub(r'\D', '', phone_text)

    # Check if this is a blacklisted number
    if any(re.sub(r'\D', '', blacklisted) == digits_only for blacklisted in BLACKLISTED_PHONE_NUMBERS):
        logging.info(f"Found blacklisted phone number: {phone_text} - excluding from export")
        return ""

    # Format consistently if it's a valid number
    if len(digits_only) == 10:
        return f"({digits_only[:3]}) {digits_only[3:6]}-{digits_only[6:]}"
    elif len(digits_only) == 11 and digits_only[0] == '1':
        return f"({digits_only[1:4]}) {digits_only[4:7]}-{digits_only[7:]}"
    else:
        return phone_text.strip()


# Function to extract phone number from text content
def extract_phone_from_text(text):
    if not text:
        return None

    phone_pattern = re.compile(r'(\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4})')
    match = phone_pattern.search(text)
    if match:
        return normalize_phone(match.group(1))
    return None


def _get_photos_excluded_containers(soup):
    """Return set of elements that are excluded photo areas (comps, similars, footer, etc.)."""
    containers = set()
    for sel in PHOTOS_EXCLUDED_CONTAINER_SELECTORS:
        try:
            for el in soup.select(sel):
                containers.add(el)
        except Exception:
            pass
    return containers


def _is_img_in_excluded_photo_container(img, excluded_containers):
    """Return True if img is inside any excluded container (do not use for Photos_JSON)."""
    if not excluded_containers:
        return False
    for parent in img.parents:
        if parent in excluded_containers:
            return True
    return False


# NEW: Function to extract monthly payment estimate
def extract_monthly_payment(soup, html_content):
    """Extract monthly payment estimate using both CSS selectors and XPath."""
    payment_estimate = ""

    # Try CSS Selector
    css_selector = "#MortgageCalculator > div.calculatorContentsContainer > div.MortgageCalculatorSummary.isDesktop > div > div.sectionText.shift-reset-right > div > p"
    payment_tag = soup.select_one(css_selector)
    if payment_tag:
        payment_estimate = payment_tag.get_text(strip=True)
        logging.info(f"Found monthly_payment_estimate using CSS selector: {payment_estimate}")
        return payment_estimate

    # Try XPath if CSS selector failed
    xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[14]/section/div/div/div/div/div[1]/div[1]/div/div[1]/div/p'
    payment_text = extract_by_xpath(html_content, xpath)
    if payment_text:
        payment_estimate = payment_text
        logging.info(f"Found monthly_payment_estimate using XPath: {payment_estimate}")
        return payment_estimate

    # Generic mortgage calculator selector fallback
    generic_selectors = [
        ".MortgageCalculatorSummary p",
        ".sectionText p",
        "#MortgageCalculator p",
    ]

    for selector in generic_selectors:
        tags = soup.select(selector)
        for tag in tags:
            text = tag.get_text(strip=True)
            if re.search(r'\$[\d,]+/mo', text) or "per month" in text.lower():
                payment_estimate = text
                logging.info(f"Found monthly_payment_estimate using generic selector: {payment_estimate}")
                return payment_estimate

    return payment_estimate


# Agent name: (css_selector, xpath) pairs for house-info agent section (first match wins).
AGENT_NAME_SELECTORS = [
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div > div > span.agent-basic-details--heading > span", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div/div/span[1]/span"),
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div > div > span.agent-basic-details--heading > span", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div/div/span[1]/span"),
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div:nth-child(1) > div > span.agent-basic-details--heading > span", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div[1]/div/span[1]"),
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div:nth-child(1) > div > span.agent-basic-details--heading > span", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div[1]/div/span[1]/span"),
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div > div > span.agent-basic-details--heading", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div/div/span[1]"),
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div > div > span.agent-basic-details--heading", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div/div/span[1]"),
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div/div"),
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div:nth-child(1) > div > span.agent-basic-details--heading", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div[1]/div/span[1]"),
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div:nth-child(1) > div > span.agent-basic-details--heading", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div[1]/div/span[1]"),
    ("#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div:nth-child(2) > div > span.agent-basic-details--heading", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div[2]/div/span[1]"),
    # Legacy fallbacks (div[8] in path)
    ("#house-info > div:nth-child(3) > div > div > div.agent-info-container > div.agent-info-content > div > div > span.agent-basic-details--heading > span", "/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/div/div[1]/div[2]/div/div/span[1]/span"),
]

# Listing source name: (css_selector, xpath) pairs for house-info listing section (first match wins).
LISTING_SOURCE_NAME_SELECTORS = [
    ("#house-info > div:nth-child(3) > div > div > div.listingInfoSection > div > div.ListingSource > span.ListingSource--dataSourceName", "/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/div/div[2]/div/div[2]/span[3]"),
    ("#house-info > div:nth-child(4) > div > div > div.listingInfoSection > div > div.ListingSource", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[3]/div/div[2]"),
    ("#house-info > div:nth-child(4) > div > div > div.listingInfoSection > div > div.ListingSource", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[2]/div/div[2]"),
    ("#house-info > div:nth-child(4) > div > div > div.listingInfoSection > div > div.ListingSource", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div[1]/div/div[4]/div/div/div[2]/div/div[2]"),
    ("#house-info > div:nth-child(4) > div > div > div.listingInfoSection > div > div.ListingSource", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div[1]/div/div[4]/div/div/div[3]/div/div[2]"),
    ("#house-info > div:nth-child(4) > div > div > div > div.ListingSource", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div/div/div[4]/div/div/div/div[2]"),
]

# FSBO Pagination Table: CSS selectors and XPaths for property details section
# Each tuple: (field_key, css_selector, xpath, transform).
# transform: None | "yes_no" (element exists->Yes) | "deck_yes_no" | "garage_yes_no" | "pool_scan" | "has_patio" | "has_porch" | "has_fireplace" | "driveway_normalize" | "lot_size_exclude" | "apn_exclude" | "extract_phone" | "flood_after_factor" | "basement_yes_no"
FSBO_PAGINATION_SELECTORS = [
    # living_area: multiple possible locations on different listing layouts (first match wins)
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[6]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[5]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(16) > ul:nth-child(6) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[8]/ul[6]/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(16) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[8]/ul/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(16) > ul:nth-child(3) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[8]/ul[3]/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[6]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(16) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[8]/ul[2]/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul:nth-child(3) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul[3]/li[3]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[4]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer > div > div:nth-child(6) > ul > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(16) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[8]/ul[2]/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[2]/li[3]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer > div > div:nth-child(4) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[2]/li[3]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[5]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(16) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[8]/ul/li[2]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[3]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(6) > li:nth-child(10)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[6]/li[10]", None),
    ("living_area", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[5]", None),
    # year_built: multiple possible locations (first match wins)
    ("year_built", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(4) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[4]/li[2]", None),
    ("year_built", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul/li[9]", None),
    ("year_built", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(7) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[7]/li[2]", None),
    ("year_built", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul/li[9]", None),
    ("year_built", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[9]", None),
    ("year_built", "#property-details-scroll > div > div > div:nth-child(5) > ul > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div[2]/ul/li[9]", None),
    ("year_built", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[6]/ul/li[9]", None),
    ("year_built", "#property-details-scroll > div > div > div > ul > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/ul/li[9]", None),
    # property_type: propertyDetails-preview and house-info (first match with "property type" wins)
    ("property_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[2]", None),
    ("property_type", "#house-info > div:nth-child(3) > div > div > div > div > div:nth-child(1) > div > span.valueText", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[3]/div/div/div/div/div[1]/div/span[1]", None),
    ("property_type", "#house-info > div:nth-child(3) > div > div > div > div > div:nth-child(1) > div > span.valueType", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[3]/div/div/div/div/div[1]/div/span[2]", None),
    ("property_type", "#house-info > div:nth-child(3) > div > div > div > div > div:nth-child(1) > div > span.valueType", "//*[@id=\"house-info\"]/div[3]/div/div/div/div/div[1]/div/span[2]", None),
    ("property_type", "#house-info > div:nth-child(3) > div > div > div > div > div:nth-child(1) > div > span.valueText", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div[1]/div/div[3]/div/div/div/div/div[1]/div/span[1]", None),
    ("property_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul/li[8]", None),
    ("property_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul/li[8]", None),
    ("property_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[7]/ul/li[8]", None),
    ("property_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[8]", None),
    ("property_type", "#property-details-scroll > div > div > div > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/ul/li[8]", None),
    ("property_type", "#house-info > div:nth-child(2) > div > div > div > div > div:nth-child(1) > div > span.valueText", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[2]/div/div/div/div/div[1]/div/span[1]", None),
    # construction_type: usually contains "Construction Materials" or "Construction Type". Exclude: Roof, Building Area, Patio, Levels, Stories, etc.
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[2]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[3]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[4]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[4]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[5]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[6]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[6]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[7]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[8]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[2]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[3]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[4]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[6]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[9]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(12)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[12]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[4]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[2]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[6]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(6) > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[6]/li[8]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul/li[3]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[2]/li[5]", None),
    ("construction_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[4]", None),
    # building_style: usually contains "Style:". Exclude: Subdivision Name, Association Approval Required, High School Source
    ("building_style", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[7]/ul/li[8]", None),
    ("building_style", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul/li[8]", None),
    ("building_style", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[6]/ul/li[8]", None),
    ("building_style", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul/li[8]", None),
    ("building_style", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[8]", None),
    ("building_style", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[8]", None),
    ("building_style", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(4) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[4]/li[3]", None),
    ("effective_year_built", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(4) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[4]/li[2]", None),
    ("number_of_units", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[4]", None),
    # stories: # of stories total, behind Property Type: "X" Stories, Stories (Total), under Floor Plan Features or Levels; multiple selectors for layout variants
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[7]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[7]/ul/li[6]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul/li[6]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(3) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[2]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[2]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[3]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[6]/ul/li[6]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[6]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(16) > ul:nth-child(2) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[8]/ul[2]/li[6]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[3]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(11)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[11]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul/li[6]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul/li[7]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(2) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[2]/li[4]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(16) > ul:nth-child(6) > li:nth-child(10)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[8]/ul[6]/li[10]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[6]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer > div > div:nth-child(4) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[1]/li[2]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[2]", None),
    ("stories", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[4]", None),
    ("garage", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div.super-group-content.oneCol > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[1]/ul/li[2]", "garage_yes_no"),
    ("heating_type", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[3]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[4]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(15) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[15]/li[2]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul:nth-child(2) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul[2]/li[4]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[2]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[8]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[3]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(2) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[1]/ul[2]/li[5]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[3]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[6]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[4]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[2]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[5]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[2]/li[5]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(23) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[23]/li[2]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(5) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[5]/li[3]", None),
    ("heating_gas", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[5]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(15) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[15]/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul[2]/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul/li[5]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[5]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(2) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[1]/ul[2]/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[2]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[4]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[2]/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(23) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[23]/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[5]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(5) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[5]/li[2]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(2) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[16]/section/div/div/div/div[1]/div/div[1]/ul/li[2]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(8) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[8]/li[4]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[2]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(16) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[16]/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(7) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[7]/li[4]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[1]/li[2]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul/li[3]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul/li[4]", None),
    ("air_conditioning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[8]", None),
    ("basement", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[5]", "basement_yes_no"),
    ("deck", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[3]", "deck_yes_no"),
    ("interior_walls", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(5) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[5]/li[5]", None),
    ("exterior_walls", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[2]", None),
    # fireplaces: if any scraped text contains "fireplace" -> "Has Fireplace" in Supabase (marketing remarks, ai-summary, house-info, property details, property history)
    ("fireplaces", "#marketingRemarks-preview > div.sectionContentContainer.expanded > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[1]/div/div/div/div/div[1]/div", "has_fireplace"),
    ("fireplaces", "#ai-summary", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[2]", "has_fireplace"),
    ("fireplaces", "#house-info > div:nth-child(1)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[1]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(11) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[11]/li[2]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[3]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[2]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[5]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li.propertyDetailsHeader", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[1]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[2]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(12) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[12]/li[2]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(15) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[15]/li[3]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[6]", "has_fireplace"),
    ("fireplaces", "#propertyHistoryRemarks-preview > div.sectionContentContainer.expanded > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div/div[5]/div/div/div[1]/div/div/p", "has_fireplace"),
    ("fireplaces", "#ai-summary > div.aiSummary__body > ul", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[2]/div[2]/ul", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(11) > li.propertyDetailsHeader", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[11]/li[1]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[2]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[5]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[2]", "has_fireplace"),
    ("fireplaces", "#marketing-remarks-scroll > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[1]/div/div/div/div/p", "has_fireplace"),
    ("fireplaces", "#propertyHistoryRemarks-preview > div.sectionContentContainer.expanded > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div/div[1]/div/div/div[7]/div/div/div[1]/div/div/p", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[2]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[3]", "has_fireplace"),
    ("fireplaces", "#ai-summary > div.aiSummary__body", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[2]/div[2]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(22) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[22]/li[2]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(13) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[13]/li[2]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(7) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[7]/li[3]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[3]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(14) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[14]/li[3]", "has_fireplace"),
    ("fireplaces", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(5) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[5]/li[3]", "has_fireplace"),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[2]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(16) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[16]/li[3]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(5) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[5]/li[3]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(7) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[7]/li[4]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[8]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[4]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(2) > ul:nth-child(3) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[1]/ul[3]/li[3]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[4]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(11) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[11]/li[3]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[5]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(8) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[8]/li[3]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[5]", None),
    ("flooring_cover", "#marketing-remarks-scroll > p > span > span:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[1]/div/div/div/div/div[1]/div/div/p/span/span[2]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(24) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[24]/li[5]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(12) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[12]/li[6]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[8]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(10) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[2]/ul[10]/li[5]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(6) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[6]/li[4]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(9) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[9]/li[2]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[8]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[3]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(13) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[13]/li[4]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[7]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[5]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(3) > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[3]/li[8]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(8) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[8]/li[5]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(7) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[7]/li[5]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer > div > div:nth-child(4) > ul:nth-child(5) > li.propertyDetailsHeader", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[5]/li[1]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(15) > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[15]/li[9]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(1) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[1]/li[5]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(15) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[15]/li[4]", None),
    ("flooring_cover", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(16) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[16]/li[2]", None),
    ("flooring_cover", "#propertyHistoryRemarks-preview > div.sectionContentContainer.expanded > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div/div[1]/div/div/div[7]/div/div/div[1]/div/div/p", None),
    ("driveway", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div.super-group-content.oneCol > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[1]/ul/li[3]", "driveway_normalize"),
    ("driveway", "#propertyDetails-preview > div.sectionContentContainer > div > div.super-group-content.oneCol > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[1]/ul/li[2]", "driveway_normalize"),
    ("driveway", "#propertyDetails-preview > div.sectionContentContainer > div > div.super-group-content.oneCol > ul > li.propertyDetailsHeader", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[1]/ul/li[1]", "driveway_normalize"),
    ("driveway", "#propertyDetails-preview > div.sectionContentContainer > div > div.super-group-content.oneCol > ul > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[1]/ul/li[2]", "driveway_normalize"),
    ("driveway", "#propertyDetails-preview > div.sectionContentContainer > div > div.super-group-content.oneCol > ul > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[1]/ul/li[2]", "driveway_normalize"),
    ("driveway", "#propertyDetails-preview > div.sectionContentContainer > div > div.super-group-content.oneCol > ul:nth-child(2) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[1]/ul[2]/li[2]", "driveway_normalize"),
    ("driveway", "#propertyDetails-preview > div.sectionContentContainer > div > div.super-group-content.oneCol > ul", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[1]/ul", "driveway_normalize"),
    ("driveway", "#propertyDetails-preview > div.sectionContentContainer > div > div.super-group-content.oneCol > ul:nth-child(1) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[1]/ul[1]/li[2]", "driveway_normalize"),
    ("pool", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]", "pool_scan"),
    ("patio", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", "has_patio"),
    ("porch", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[4]", "has_porch"),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[5]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[3]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[3]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[4]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[4]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[5]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[6]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[7]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[8]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[2]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[3]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[3]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[5]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[6]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[7]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[2]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[5]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(6) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[6]/li[6]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[1]/li[3]", None),
    ("roof", "#propertyDetails-preview > div.sectionContentContainer > div > div:nth-child(4) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[1]/li[3]", None),
    # sewer: usually contains "Sewer"
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[4]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul/li[4]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[5]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[3]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[4]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[8]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[2]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(10)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[10]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[3]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[4]/ul/li[3]", "sewer_connected"),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[3]", "sewer_connected"),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[2]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[2]", "sewer_connected"),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[6]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul/li[2]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[2]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul/li[3]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul/li[2]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[4]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[2]", "sewer_connected"),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[5]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul:nth-child(2) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul[2]/li[2]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[6]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul/li[8]", None),
    ("sewer", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[9]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[5]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul/li[2]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul:nth-child(1) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul[1]/li[4]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[3]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[2]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[2]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[9]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[3]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(12)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[12]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[4]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[2]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[2]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[4]/ul/li[2]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[3]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[2]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[4]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[3]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[3]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[5]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[2]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[4]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul/li[2]", None),
    ("water", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul:nth-child(1) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul[1]/li[3]", None),
    # apn: exclude Homestead Y/N, Lot Features:, etc.; usually contains APN:, Parcel Number:, Parcel
    ("apn", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(12)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul/li[12]", "apn_exclude"),
    ("apn", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(12)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul/li[12]", "apn_exclude"),
    ("apn", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(12)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[7]/ul/li[12]", "apn_exclude"),
    ("apn", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(12)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[12]", "apn_exclude"),
    ("apn", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[2]", "apn_exclude"),
    ("apn", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(12)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[12]", "apn_exclude"),
    ("apn", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(12)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[6]/ul/li[12]", "apn_exclude"),
    ("apn", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(10)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[16]/section/div/div/div/div[1]/div/div[4]/ul/li[10]", "apn_exclude"),
    ("apn_alt", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[3]", "apn_exclude"),
    ("lot_size", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul/li[7]", "lot_size_exclude"),
    ("lot_size", "#house-info > div:nth-child(3) > div > div > div > div > div:nth-child(3) > div > span.valueText", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div[1]/div/div[3]/div/div/div/div/div[3]/div/span[1]", "lot_size_exclude"),
    ("lot_size", "#house-info > div:nth-child(3) > div > div > div > div > div:nth-child(3) > div > span.valueText", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[3]/div/div/div/div/div[3]/div/span[1]", "lot_size_exclude"),
    ("lot_size", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul/li[7]", "lot_size_exclude"),
    ("lot_size", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[7]/ul/li[7]", "lot_size_exclude"),
    ("lot_size", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[7]", "lot_size_exclude"),
    ("lot_size", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[6]/ul/li[7]", "lot_size_exclude"),
    ("lot_size", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[3]", "lot_size_exclude"),
    ("lot_size", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[16]/section/div/div/div/div[1]/div/div[4]/ul/li[5]", "lot_size_exclude"),
    ("lot_size", "#house-info > div:nth-child(3) > div > div > div > div > div:nth-child(2) > div > span.valueText", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[3]/div/div/div/div/div[2]/div/span[1]", "lot_size_exclude"),
    ("lot_size", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[7]", "lot_size_exclude"),
    ("legal_name", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[2]", None),
    ("legal_description", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(4) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[4]/li[3]", None),
    ("property_class", "#house-info > div:nth-child(3) > div > div > div > div > div:nth-child(1) > div > span.valueText", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[3]/div/div/div/div/div[1]/div/span[1]", None),
    ("county_name", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(11)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul/li[11]", None),
    ("county_name", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(11)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[7]/ul/li[11]", None),
    ("county_name", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(14) > ul > li:nth-child(11)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[7]/ul/li[11]", None),
    ("county_name", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul > li:nth-child(11)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul/li[11]", None),
    ("county_name", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul > li:nth-child(11)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[6]/ul/li[11]", None),
    ("county_name", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(3) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[3]/li[2]", None),
    ("county_name", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul > li:nth-child(11)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul/li[11]", None),
    # elementary_school_district: may contain "School District", "Elementary School"; prioritize School District / Elementary School District. Exclude: Short Term Rental Allowed, Directions, Has Cooling, Heating, Forced Air, Has HOA, List Price:, Sewer:, Fee:, GPS Friendly.
    ("elementary_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[2]", None),
    ("elementary_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[2]", None),
    ("elementary_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[2]", None),
    ("elementary_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[3]", None),
    ("elementary_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(8) > ul:nth-child(1) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[4]/ul[1]/li[2]", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(1) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[1]/div/div/div/div/div", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(1) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[10]/section/div/div[2]/div[2]/div/div/div/div[1]/div/div/div/div/div", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div.schools-content > div:nth-child(1) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div[2]/div[1]/div/div/div/div/div", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(1) > div > div > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[1]/div/div/div/div/p", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(1) > div > div > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[10]/section/div/div[2]/div[2]/div/div/div/div[1]/div/div/div/div/p", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(1) > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[1]/div/div", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div.schools-content > div:nth-child(1) > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div[2]/div[1]/div/div", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[10]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div/div/div/p", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div/div/div/p", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div/div/div/div", None),
    ("elementary_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[10]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div", None),
    # middle_school_district: may contain "School District", "Middle School"; prioritize School District / Middle School District. Exclude: Short Term Rental Allowed, Directions, Has Cooling, Heating, Forced Air, Has HOA, List Price:, Sewer:, Fee:, GPS Friendly.
    ("middle_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[3]", None),
    ("middle_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(1) > div > div > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[10]/section/div/div[2]/div[2]/div/div/div/div[1]/div/div/div/div/p", None),
    ("middle_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[10]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div/div/div/p", None),
    ("middle_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div/div/div/p", None),
    ("middle_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div/div/div/div", None),
    ("middle_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[10]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[3]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[5]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[3]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[4]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[5]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[6]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[7]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(2) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[2]/li[2]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(1) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[1]/li[5]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(12) > ul:nth-child(3) > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[6]/ul[3]/li[7]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(1) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[1]/li[4]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[4]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[5]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(2) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[5]/ul[2]/li[4]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(10) > ul:nth-child(3) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[5]/ul[3]/li[4]", None),
    ("high_school_district", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(1) > li.entryItem", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[1]/li[2]", None),
    ("high_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(3) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[3]/div/div/div/div/div", None),
    ("high_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(3) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[10]/section/div/div[2]/div[2]/div/div/div/div[3]/div/div/div/div/div", None),
    ("high_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[10]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div/div/div/div", None),
    ("high_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(2) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[2]/div/div/div/div/div", None),
    ("high_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div.schools-content > div:nth-child(1) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div[2]/div[1]/div/div/div/div/div", None),
    ("high_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div.schools-content > div:nth-child(2) > div > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div[2]/div[2]/div/div/div/div/div", None),
    ("high_school_district", "#neighborhood-scroll > div > div.around-this-home-tabs > div.container.useMinHeight > div > div > div > div:nth-child(3) > div > div > div > div > p", "/html/body/div[1]/div[9]/div[2]/div[1]/div[13]/section/div/div[2]/div[2]/div/div/div/div[3]/div/div/div/div/p", None),
    # zoning: usually contains "Zoning". Exclude: Roof, Building Area, Flood Zone, Patio, Construction, etc.
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(4) > li:nth-child(8)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[4]/li[8]", None),
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[5]", None),
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(6) > li:nth-child(11)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[6]/li[11]", None),
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(4) > li:nth-child(3)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[4]/li[3]", None),
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[4]", None),
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(7) > li:nth-child(9)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[7]/li[9]", None),
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(6) > li:nth-child(6)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[6]/li[6]", None),
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[18]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[4]", None),
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(5) > li:nth-child(7)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[5]/li[7]", None),
    ("zoning", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(2) > li:nth-child(5)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[2]/li[5]", None),
    ("flood_zone", "#climateRiskDataSection-collapsible > div.sectionContentContainer.expanded > div > div > div:nth-child(2) > div > div > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[29]/section/div/div/div[2]/div/div/div[2]/div/div/div/div", "flood_after_factor"),
    ("tax_year", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td:nth-child(1)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[1]", None),
    ("tax_year", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td:nth-child(1)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[1]", None),
    ("tax_amount", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[2]", None),
    ("tax_amount", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[2]", None),
    ("assessment_year", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td:nth-child(1)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[1]", None),
    ("assessment_year", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td:nth-child(1)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[1]", None),
    ("total_assessed_value", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td.assessment", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[5]", None),
    ("total_assessed_value", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td.assessment", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[5]", None),
    ("assessed_improvement_value", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[4]", None),
    ("assessed_improvement_value", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels > div.propertyHistoryTabPanel.tax-history-panel.isActive > table > tbody > tr:nth-child(2) > td:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div/div[2]/div[2]/table/tbody/tr[2]/td[4]", None),
    ("total_market_value", "#content > div.detailsContent > div.theRailSection > div.alongTheRail > div:nth-child(1) > section > div > div > div > div.flex-1 > div.AddressBannerV2.desktop > div > div > div > div > div.stat-block.price-section > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[1]/section/div/div/div/div[1]/div[2]/div/div/div/div/div[1]/div", None),
    # last_sale_price: property history/sales table as full text (entire table imported as text)
    ("last_sale_price", "#property-history-transition-node > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div", None),
    ("last_sale_price", "#property-history-transition-node > div.BasicTable.font-body-base.PropertyHistoryEventTable", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div", None),
    ("last_sale_price", "#property-history-transition-node > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div[1]", None),
    ("last_sale_price", "#propertyHistoryEventTable-preview > div.sectionContentContainer.expanded > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div/div[1]/div/div", None),
    ("last_sale_price", "#propertyHistoryEventTable-preview > div.sectionContentContainer.expanded > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div/div[1]/div/div", None),
    ("last_sale_price", "#property-history-transition-node", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div", None),
    ("last_sale_price", "#property-history-transition-node > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div", None),
    ("last_sale_price", "#propertyHistoryEventTable-preview > div.sectionContentContainer.expanded > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div[1]/div[1]/div/div", None),
    ("last_sale_price", "#propertyHistoryEventTable-preview > div.sectionContentContainer.expanded > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]/div[1]/div/div/div[1]/div[1]/div/div", None),
    ("last_sale_price", "#property-history-transition-node > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[12]/section/div/div/div[2]/div/div/div/div[1]/div/div/div", None),
    ("last_sale_price", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div", None),
    ("last_sale_price", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div > div.propertyHistoryTabPanels", "/html/body/div[1]/div[9]/div[2]/div[1]/div[24]/section/div/div/div[2]/div/div/div[2]", None),
    ("last_sale_price", "#propertyHistory-collapsible > div.sectionContentContainer.expanded > div > div", "/html/body/div[1]/div[9]/div[2]/div[1]/div[20]/section/div/div/div[2]/div/div", None),
    # agent_phone: may contain text; scrape phone numbers from text before Supabase (extract_phone transform)
    ("agent_phone", "#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div > div > span.agent-extra-info--phone > div > span:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div/div/span[5]/div/span[2]", "extract_phone"),
    ("agent_phone", "#house-info > div:nth-child(4) > div > div > div.listingContactSection", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[2]", "extract_phone"),
    ("agent_phone", "#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div:nth-child(1) > div > span.agent-extra-info--phone > div > span:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div[1]/div/span[5]/div/span[2]", "extract_phone"),
    ("agent_phone", "#house-info > div:nth-child(4) > div > div > div.listingContactSection", "/html/body/div[1]/div[9]/div[2]/div[1]/div[3]/section/div/div[1]/div/div[4]/div/div/div[2]", "extract_phone"),
    ("agent_phone", "#house-info > div:nth-child(4) > div > div > div.agent-info-container > div.agent-info-content > div > div > span:nth-child(5) > div > span:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[6]/section/div/div[1]/div/div[4]/div/div/div[1]/div[2]/div/div/span[5]/div/span[2]", "extract_phone"),
    ("agent_phone", "#content > div.detailsContent > div.belowTheRail > div:nth-child(2) > section > div > div.disclaimer > div > div.listingProvider > div.listingAgent", "/html/body/div[1]/div[9]/div[3]/div[2]/section/div/div[2]/div/div[1]/div[2]", "extract_phone"),
    ("amenities", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(4) > ul:nth-child(4) > li:nth-child(4)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[2]/ul[4]/li[4]", None),
    ("amenities_alt", "#propertyDetails-preview > div.sectionContentContainer.expanded > div > div:nth-child(6) > ul:nth-child(3) > li:nth-child(2)", "/html/body/div[1]/div[9]/div[2]/div[1]/div[22]/section/div/div/div/div[1]/div/div[3]/ul[3]/li[2]", None),
]


def _apply_pagination_transform(raw_text, transform, soup_el, html_content):
    """Apply transform to raw extracted value. Returns final string value."""
    if transform is None:
        return (raw_text or "").strip() or None
    text = (raw_text or "").strip().lower()
    if transform == "yes_no":
        return "Yes" if (raw_text and raw_text.strip()) else "No"
    if transform == "basement_yes_no":
        return "Yes" if (raw_text and raw_text.strip()) else "No"
    if transform == "deck_yes_no":
        return "Yes" if "deck" in text else "No"
    if transform == "garage_yes_no":
        return "Yes" if (raw_text and "garage" in (raw_text or "").lower()) else "No"
    if transform == "pool_scan":
        scan_text = (raw_text or "").strip().lower()
        if soup_el:
            try:
                scan_text = (soup_el.get_text(strip=True) if hasattr(soup_el, 'get_text') else str(soup_el)).lower()
            except Exception:
                pass
        return "Yes" if "pool" in scan_text else "No"
    if transform == "has_patio":
        if not raw_text or not (raw_text or "").strip():
            return ""
        lower = raw_text.strip().lower()
        if "patio and porch features" in lower or "patio" in lower:
            return "Has Patio"
        return ""
    if transform == "has_porch":
        return "Has Porch" if (raw_text and "porch" in raw_text.lower()) else ""
    if transform == "has_fireplace":
        return "Has Fireplace" if (raw_text and "fireplace" in text) else ""
    if transform == "driveway_normalize":
        if not raw_text or not (raw_text or "").strip():
            return None
        t = (raw_text or "").strip()
        # Don't include Cooling or Virtual Tour entries as driveway
        if "Cooling: Central Air" in t or "VirtualTourURLUnbranded2" in t or "Virtual Tour Unbranded 2 (External Link)" in t:
            return None
        lower = t.lower()
        if "detached" in lower:
            return "Detached Garage"
        if "covered spaces" in lower:
            return "Half-Garage"
        if "garage" in lower:
            return "Has Garage"
        return t or None
    if transform == "lot_size_exclude":
        if not raw_text or not (raw_text or "").strip():
            return None
        t = (raw_text or "").strip()
        if "$" in t:
            return None
        lower = t.lower()
        # Exclude: High School, $, School District Source, Restrictions; municipality, school source, HOA, etc.
        exclude = (
            "municipality", "middle school source", "hoa", "high school district", "high school",
            "school district source", "restrictions",
            "geocode", "road", "monthly", "association",
        )
        if any(phrase in lower for phrase in exclude):
            return None
        return t or None
    if transform == "apn_exclude":
        if not raw_text or not (raw_text or "").strip():
            return None
        t = (raw_text or "").strip()
        lower = t.lower()
        # Exclude non-APN content
        exclude = (
            "homestead y/n", "lot features:", "building area units:", "unfinished sq.ft. source:",
            "foundation details:", "property sub type:", "lot size acres:", "new construction",
            "entry level:", "water view y/n:", "waterfront features:", "road surface type:",
        )
        if any(phrase in lower for phrase in exclude):
            return None
        # Usually contains APN:, Parcel Number:, or Parcel
        if "apn" not in lower and "parcel number" not in lower and "parcel" not in lower:
            return None
        # Normalize for Supabase: store only the value, never the "APN: " (or similar) prefix
        for prefix in ("apn:", "parcel number:", "parcel:"):
            if lower.startswith(prefix):
                t = t[len(prefix):].strip()
                break
        return t or None
    if transform == "sewer_connected":
        if not raw_text or not (raw_text or "").strip():
            return None
        lower = (raw_text or "").strip().lower()
        if "sewer" in lower and ("connected" in lower or "municipal" in lower):
            return "Sewer Connected"
        return None
    if transform == "extract_phone":
        if not raw_text or not (raw_text or "").strip():
            return None
        phone = extract_phone_from_text((raw_text or "").strip())
        if not phone or phone in BLACKLISTED_PHONE_NUMBERS:
            return None
        return phone
    if transform == "flood_after_factor":
        if not raw_text:
            return None
        idx = raw_text.find("Flood Factor")
        if idx == -1:
            return raw_text.strip() or None
        after = raw_text[idx + len("Flood Factor"):].strip()
        return after.strip(": \t").strip() or raw_text.strip() or None
    return (raw_text or "").strip() or None


def _is_living_area_value(raw_text):
    """Return True only if raw_text contains the 'living area' label."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    return "living area" in s or "living_area" in s


def _is_year_built_value(raw_text):
    """Return True only if raw_text contains the 'Year Built' label."""
    if not raw_text or not str(raw_text).strip():
        return False
    return "year built" in str(raw_text).strip().lower()


def _strip_label_prefix(value):
    """If value is a string containing ': ', return only the part after the first ': ' (trimmed). Otherwise return value unchanged."""
    if not value or not isinstance(value, str):
        return value
    if ": " not in value:
        return value
    return value.split(": ", 1)[1].strip() or value


# Fields that should have "Label: value" normalized to "value" before storing in Supabase.
_NORMALIZE_LABEL_VALUE_FIELDS = frozenset({
    "year_built", "living_area", "construction_type", "building_style", "stories",
    "heating_gas", "air_conditioning", "roof", "sewer", "apn", "lot_size",
    "county_name", "zoning",
})


# Keywords that disqualify scraped text from being used as stories.
_STORIES_EXCLUDE = (
    "roof", "building area", "above grade finished area", "architectural style",
    "flood zone", "patio", "construction materials", "water", "construction",
    "ownership", "tax annual amount", "tax annual ammount", "heating", "exterior",
    "street", "green indoor air", "sliding description", "shingle", "flip tax fee type",
    "partial", "complete", "green indoor", "living area", "lot size", "pool",
    "tax year", "foundation", "flood",
)


def _is_stories_value(raw_text):
    """Return True only if raw_text usually contains 'Stories' or 'Levels' and none of the exclude keywords."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if any(ex in s for ex in _STORIES_EXCLUDE):
        return False
    # Must contain stories or levels to be accepted
    if "stories" in s or "story" in s or "levels" in s or "level:" in s or "# of stories" in s:
        return True
    if "floor plan" in s and ("stories" in s or "levels" in s) and any(c.isdigit() for c in s):
        return True
    return False


def _is_property_type_value(raw_text):
    """Return True if raw_text contains the 'property type' label or is a known property type value (e.g. from #house-info span.valueText)."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if "property type" in s:
        return True
    # Accept value-only content from #house-info (e.g. span.valueText: "Single Family", "Condo")
    known_types = ("single family", "condo", "townhouse", "multi-family", "multifamily", "mobile", "land", "other")
    return any(t in s or s in t for t in known_types)


def _is_heating_gas_value(raw_text):
    """Return True if raw_text contains heating-related label (Heating Information, Heating:, Has Heating, Heating Fuel, or heating)."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    return (
        "heating information" in s
        or "heating:" in s
        or "has heating" in s
        or "heating fuel" in s
        or "heating" in s
    )


def _is_roof_value(raw_text):
    """Return True only if raw_text contains 'Roof' or 'Roof Details'."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    return "roof" in s or "roof details" in s


# Exclude: Subdivision Name, Association Approval Required, High School Source
_BUILDING_STYLE_EXCLUDE = (
    "subdivision name",
    "association approval required",
    "high school source",
)


def _is_building_style_value(raw_text):
    """Return True if raw_text usually contains 'Style:'. Exclude subdivision, association approval, high school source."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if any(ex in s for ex in _BUILDING_STYLE_EXCLUDE):
        return False
    return "style:" in s


# Exclude: Roof, Building Area, Above Grade Finished Area, Patio And Porch Features, No, Levels, Architectural Style, Stories, Not Federal Flood Zone, Patio, Water Source, Green Energy, Ownership Interest, Tax Annual Amount, Heating, Exterior Features, StreetDirPrefix, Siding Description, Flip, Partial, Complete, Lot Size Area, Pool Description, Tax Year, Foundation Details
_CONSTRUCTION_TYPE_EXCLUDE = (
    "roof",
    "building area",
    "above grade finished area",
    "patio and porch features",
    " no ",
    "levels",
    "architectural style",
    "stories",
    "not federal flood zone",
    "patio",
    "water source",
    "green energy",
    "ownership interest",
    "tax annual amount",
    "heating",
    "exterior features",
    "streetdirprefix",
    "siding description",
    "flip",
    "partial",
    "complete",
    "lot size area",
    "pool description",
    "tax year",
    "foundation details",
)


def _is_construction_type_value(raw_text):
    """Return True if raw_text usually contains 'Construction Materials' or 'Construction Type'. Exclude roof, building area, patio, etc."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if any(ex in s for ex in _CONSTRUCTION_TYPE_EXCLUDE):
        return False
    return "construction materials" in s or "construction type" in s


# Zoning: usually contains "Zoning". Exclude: Roof, Building Area, Architectural Style, Flood Zone, Patio, Construction Materials, Water, Tax Annual, Heating, Exterior, etc.
_ZONING_EXCLUDE = (
    "roof",
    "building area",
    "above grade finished area",
    "architectural style",
    "flood zone",
    "patio",
    "construction materials",
    "water",
    "construction",
    "ownership",
    "tax annual",
    "heating",
    "exterior",
    "street",
    "green indoor air",
    "sliding description",
    "shingle",
    "flip tax fee type",
    "partial",
    "complete",
    "green indoor",
    "living area",
    "lot size",
    "pool",
    "tax year",
    "foundation",
    "flood",
    "property sub type",
    "raw mis",
    "tidal water",
    "common walls",
    "property match",
    "above grade",
    "plat",
    " lot ",
    "tin",
    "levels",
    "front",
    " main ",
    "additional",
    "above",
    "# of docks",
)


def _is_zoning_value(raw_text):
    """Return True if raw_text usually contains 'Zoning'. Exclude roof, building area, flood zone, patio, construction, etc."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if any(ex in s for ex in _ZONING_EXCLUDE):
        return False
    return "zoning" in s


def _is_property_class_value(raw_text):
    """Return True if raw_text is valid property_class. Exclude 'Listed by' (agent/listing attribution)."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if "listed by" in s:
        return False
    return True


def _is_high_school_district_value(raw_text):
    """Return True if raw_text contains 'School District', 'High School District', or 'High School'. Always exclude 'middle' and 'elementary'."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if "middle" in s or "elementary" in s:
        return False
    return (
        "school district" in s
        or "high school district" in s
        or "high school" in s
    )


def _high_school_district_priority(raw_text):
    """Return 2 for 'School District' or 'High School District', 1 for 'High School', else 0."""
    if not raw_text or not str(raw_text).strip():
        return 0
    s = str(raw_text).strip().lower()
    if "school district" in s or "high school district" in s:
        return 2
    if "high school" in s:
        return 1
    return 0


# Phrases that disqualify scraped text from being used as elementary_school_district.
# Exclude: Community Features / Short Term Rental Allowed, Directions, Has Cooling, Heating, Forced Air, Has HOA, List Price:, Sewer:, Fee:, GPS Friendly. Exclude any with "High" (e.g. high school).
_ELEMENTARY_SCHOOL_DISTRICT_EXCLUDE = (
    "short term rental allowed",
    "directions",
    "has cooling",
    "heating",
    "forced air",
    "has hoa",
    "list price:",
    "sewer:",
    "fee:",
    "gps friendly",
    "community features",
    "high",
)


def _is_elementary_school_district_value(raw_text):
    """Return True if raw_text contains 'School District', 'Elementary School District', or 'Elementary School', and none of the exclude phrases."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if any(ex in s for ex in _ELEMENTARY_SCHOOL_DISTRICT_EXCLUDE):
        return False
    return (
        "school district" in s
        or "elementary school district" in s
        or "elementary school" in s
    )


def _elementary_school_district_priority(raw_text):
    """Prioritize 'School District' or 'Elementary School District' (2) over 'Elementary School' (1). Use others if available."""
    if not raw_text or not str(raw_text).strip():
        return 0
    s = str(raw_text).strip().lower()
    if "school district" in s or "elementary school district" in s:
        return 2
    if "elementary school" in s:
        return 1
    return 0


# Phrases that disqualify scraped text from being used as middle_school_district.
# Exclude: Short Term Rental Allowed, Directions, Has Cooling, Heating, Forced Air, Has HOA, List Price:, Sewer:, Fee:, GPS Friendly, Community Features.
_MIDDLE_SCHOOL_DISTRICT_EXCLUDE = (
    "short term rental allowed",
    "directions",
    "has cooling",
    "heating",
    "forced air",
    "has hoa",
    "list price:",
    "sewer:",
    "fee:",
    "gps friendly",
    "community features",
)


def _is_middle_school_district_value(raw_text):
    """Return True if raw_text contains 'School District', 'Middle School District', or 'Middle School'. Exclude 'high', 'elementary', and community-feature phrases."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if "high" in s or "elementary" in s:
        return False
    if any(ex in s for ex in _MIDDLE_SCHOOL_DISTRICT_EXCLUDE):
        return False
    return (
        "school district" in s
        or "middle school district" in s
        or "middle school" in s
    )


def _middle_school_district_priority(raw_text):
    """Prioritize 'School District' or 'Middle School District' (2) over 'Middle School' (1). Use others if available."""
    if not raw_text or not str(raw_text).strip():
        return 0
    s = str(raw_text).strip().lower()
    if "school district" in s or "middle school district" in s:
        return 2
    if "middle school" in s:
        return 1
    return 0


def _is_county_name_value(raw_text):
    """Return True if raw_text typically contains 'county' (e.g. County name or label)."""
    if not raw_text or not str(raw_text).strip():
        return False
    return "county" in str(raw_text).strip().lower()


# Phrases that disqualify scraped text from being used as air_conditioning.
_AIR_CONDITIONING_EXCLUDE = (
    "association",
    "water source",
    "sewer",
    "underground utilities",
    "elementary",
    "middle or junior school",
    "junior school",
    "high school",
    " plan",
    "hoa",
    "heating",
    "finished",
    "gas",
    "circuit",
    "subdivision",
    " street",
)


def _is_air_conditioning_value(raw_text):
    """Return True if raw_text is cooling-related and contains none of the exclude phrases."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if any(ex in s for ex in _AIR_CONDITIONING_EXCLUDE):
        return False
    return "cooling" in s


def _air_conditioning_priority(raw_text):
    """Return 2 for 'Cooling Type', 1 for 'Cooling Fuel', else 0. Prefer Cooling Type over Cooling Fuel."""
    if not raw_text or not str(raw_text).strip():
        return 0
    s = str(raw_text).strip().lower()
    if "cooling type" in s:
        return 2
    if "cooling fuel" in s:
        return 1
    return 0


# Phrases that disqualify scraped text from being used as flooring_cover.
_FLOORING_COVER_EXCLUDE = (
    "appliances",
    "bathroom",
    "laundry",
    "breakfast",
    "property type",
    "cooling",
    "rooms",
    " room ",
    "living room",
    "bathrooms",
    "fireplaces",
    "basement",
    "media",
    "baths",
    " bath ",
    "features",
    "bedroom",
    "laundryfeatures",
    "additional",
    "ceiling",
    "lot",
    "view",
    "kitchen",
    "other",
    "dishwasher",
)


def _is_flooring_cover_value(raw_text):
    """Return True if raw_text does not contain any of the flooring_cover exclude phrases."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    return not any(ex in s for ex in _FLOORING_COVER_EXCLUDE)


# Phrases that disqualify scraped text from being used as sewer.
_SEWER_EXCLUDE = (
    "water source:",
    "winter tax year:",
    "unfinished sq. ft.:",
    "tax year:",
    "tax annual amount:",
    "utilities:",
    "tax legal description:",
    "solid waste information:",
    "parcel number:",
    "tax lot:",
    "high school:",
    "has heating",
)


def _is_sewer_value(raw_text):
    """Return True if raw_text usually contains 'Sewer' or 'Sewer Septic' and none of the exclude phrases."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if any(ex in s for ex in _SEWER_EXCLUDE):
        return False
    return "sewer" in s or "sewer septic" in s


# Phrases that disqualify scraped text from being used as water (water source).
_WATER_EXCLUDE = (
    "tax year:",
    "tax annual amount:",
    "tax legal description:",
    "parcel number:",
    "tax lot:",
    "high school:",
    "elementary school:",
    "middle school:",
    "has heating",
    "sewer:",
)


def _is_water_value(raw_text):
    """Return True if raw_text looks like water source content (Water Source:, Water:, municipal, well, etc.)."""
    if not raw_text or not str(raw_text).strip():
        return False
    s = str(raw_text).strip().lower()
    if any(ex in s for ex in _WATER_EXCLUDE):
        return False
    return "water" in s and ("water source" in s or "water:" in s or "municipal" in s or "well" in s or "public" in s)


def extract_fsbo_pagination_fields(soup, html_content, url):
    """
    Extract all FSBO Pagination Table fields from the property details section
    using CSS selectors with XPath fallback. Returns a dict suitable for
    fsbo_pagination Supabase table (snake_case keys).
    """
    result = {}
    if soup is None:
        return result
    html_str = html_content if isinstance(html_content, str) else (html_content.decode("utf-8", errors="replace") if html_content else "")
    high_school_candidates = []  # (priority, value); priority 2 = School District/High School District, 1 = High School
    elementary_school_candidates = []  # (priority, value); priority 2 = School District/Elementary School District, 1 = Elementary School
    middle_school_candidates = []  # (priority, value); priority 2 = School District/Middle School District, 1 = Middle School
    air_conditioning_candidates = []  # (priority, value); priority 2 = Cooling Type, 1 = Cooling Fuel
    for item in FSBO_PAGINATION_SELECTORS:
        if len(item) == 4:
            field_key, css_sel, xpath, transform = item
        else:
            continue
        raw = None
        soup_el = None
        try:
            soup_el = soup.select_one(css_sel)
            if soup_el:
                raw = soup_el.get_text(strip=True) if hasattr(soup_el, 'get_text') else str(soup_el)
        except Exception as e:
            logging.debug(f"FSBO pagination CSS failed for {field_key}: {e}")
        if raw is None or (isinstance(raw, str) and not raw.strip()) and xpath and html_str:
            try:
                raw = extract_by_xpath(html_str, xpath)
                if raw and isinstance(raw, str):
                    raw = raw.strip()
            except Exception as e:
                logging.debug(f"FSBO pagination XPath failed for {field_key}: {e}")
        if transform == "pool_scan" and soup_el is None and raw:
            soup_el = raw  # pass raw text for pool scan
        value = _apply_pagination_transform(raw, transform, soup_el, html_str)
        if value is not None and value != "":
            # Only set living_area when scraped content actually represents living area
            if field_key == "living_area" and not _is_living_area_value(raw):
                value = None
            # Only set year_built when scraped content contains "Year Built"
            if field_key == "year_built" and not _is_year_built_value(raw):
                value = None
            # Only set property_type when scraped content contains "property type"
            if field_key == "property_type" and not _is_property_type_value(raw):
                value = None
            # Only set heating_gas when scraped content contains heating-related label
            if field_key == "heating_gas" and not _is_heating_gas_value(raw):
                value = None
            # Only set roof when scraped content contains "Roof" or "Roof Details"
            if field_key == "roof" and not _is_roof_value(raw):
                value = None
            # Only set building_style when content usually contains "Style:"; exclude Subdivision Name, Association Approval Required, High School Source
            if field_key == "building_style" and not _is_building_style_value(raw):
                value = None
            # Only set construction_type when content usually contains "Construction Materials" or "Construction Type"; exclude Roof, Building Area, Patio, etc.
            if field_key == "construction_type" and not _is_construction_type_value(raw):
                value = None
            # Only set zoning when content usually contains "Zoning"; exclude Roof, Building Area, Flood Zone, Patio, etc.
            if field_key == "zoning" and not _is_zoning_value(raw):
                value = None
            # Only set property_class when content does not contain "Listed by"
            if field_key == "property_class" and not _is_property_class_value(raw):
                value = None
            # Only set county_name when scraped content typically contains "county"
            if field_key == "county_name" and not _is_county_name_value(raw):
                value = None
            # Only set flooring_cover when scraped content does not contain exclude phrases (appliances, bathroom, etc.)
            if field_key == "flooring_cover" and not _is_flooring_cover_value(raw):
                value = None
            # Only set sewer when scraped content usually contains Sewer/Sewer Septic and not exclude phrases (Water Source, Tax Year, etc.)
            if field_key == "sewer" and not _is_sewer_value(raw):
                value = None
            # Only set water when scraped content usually contains Water Source:, Water:, or Water & Sewer
            if field_key == "water" and not _is_water_value(raw):
                value = None
            # Only set stories when content looks like # of stories total, Property Type: X Stories, Stories (Total), Floor Plan Features, or Levels
            if field_key == "stories" and not _is_stories_value(raw):
                value = None
            # high_school_district: collect candidates and pick by priority (School District / High School District > High School)
            if field_key == "high_school_district":
                if value is not None and value != "" and _is_high_school_district_value(raw):
                    pri = _high_school_district_priority(raw)
                    if pri:
                        high_school_candidates.append((pri, value))
                continue
            # elementary_school_district: collect candidates, exclude non-school phrases, pick by priority
            if field_key == "elementary_school_district":
                if value is not None and value != "" and _is_elementary_school_district_value(raw):
                    pri = _elementary_school_district_priority(raw)
                    if pri:
                        elementary_school_candidates.append((pri, value))
                continue
            # middle_school_district: collect candidates; prioritize School District / Middle School District, use Middle School if available. Exclude high, elementary, community-feature phrases.
            if field_key == "middle_school_district":
                if value is not None and value != "" and _is_middle_school_district_value(raw):
                    pri = _middle_school_district_priority(raw)
                    if pri:
                        middle_school_candidates.append((pri, value))
                continue
            # air_conditioning: collect candidates, exclude non-cooling phrases, prefer Cooling Type over Cooling Fuel
            if field_key == "air_conditioning":
                if value is not None and value != "" and _is_air_conditioning_value(raw):
                    pri = _air_conditioning_priority(raw)
                    if pri:
                        air_conditioning_candidates.append((pri, value))
                    else:
                        air_conditioning_candidates.append((1, value))  # cooling-related but no type/fuel label
                continue
            if value is not None and value != "":
                result.setdefault(field_key, value)  # first successful selector wins when multiple options exist
    if high_school_candidates:
        best = max(enumerate(high_school_candidates), key=lambda ix_p: (ix_p[1][0], -ix_p[0]))
        result["high_school_district"] = best[1][1]
    if elementary_school_candidates:
        best = max(enumerate(elementary_school_candidates), key=lambda ix_p: (ix_p[1][0], -ix_p[0]))
        result["elementary_school_district"] = best[1][1]
    if middle_school_candidates:
        best = max(enumerate(middle_school_candidates), key=lambda ix_p: (ix_p[1][0], -ix_p[0]))
        result["middle_school_district"] = best[1][1]
    if air_conditioning_candidates:
        best = max(enumerate(air_conditioning_candidates), key=lambda ix_p: (ix_p[1][0], -ix_p[0]))
        result["air_conditioning"] = best[1][1]
    # Merge apn_alt into apn if apn empty
    if result.get("apn_alt") and not result.get("apn"):
        result["apn"] = result.pop("apn_alt", None)
    else:
        result.pop("apn_alt", None)
    if result.get("amenities_alt") and not result.get("amenities"):
        result["amenities"] = result.get("amenities_alt")
    result.pop("amenities_alt", None)
    # Normalize fields that may contain "Label: value" -> store only "value" for Supabase
    for key in _NORMALIZE_LABEL_VALUE_FIELDS:
        if key in result and result[key] is not None:
            result[key] = _strip_label_prefix(result[key])
    # Normalize flood_zone: remove "-  " and strip leading "- " for Supabase
    if result.get("flood_zone") and isinstance(result["flood_zone"], str):
        v = result["flood_zone"].replace("-  ", "").strip()
        result["flood_zone"] = v.lstrip("- ").strip()
    # Normalize elementary_school_district: strip "This home is within the" when present
    if result.get("elementary_school_district") and isinstance(result["elementary_school_district"], str):
        v = result["elementary_school_district"]
        if "This home is within the" in v:
            result["elementary_school_district"] = v.replace("This home is within the", "", 1).strip()
    return result


def scrape_pagination_only(url, session):
    """
    Fetch one listing page and extract only fsbo_pagination fields.
    Used to amend existing leads so each listing_id has both main lead data and fsbo_pagination.
    Returns a dict with property_url, listing_id, scrape_date, and all pagination fields, or None on failure.
    """
    if not is_valid_listing_url(url):
        logging.debug(f"Skipping blocklisted/non-listing URL: {url}")
        return None
    try:
        resp = session.get(url, timeout=30)
        if resp.status_code != 200:
            logging.warning(f"Failed to fetch {url}: {resp.status_code}")
            return None
        soup = BeautifulSoup(resp.text, "html.parser")
        html_content = resp.text
        pagination_fields = extract_fsbo_pagination_fields(soup, html_content, url)
        if not pagination_fields:
            logging.debug(f"No pagination fields extracted for {url}")
        listing_id = url.rstrip("/").split("/")[-1]
        data = {
            "property_url": url,
            "listing_id": listing_id,
            "scrape_date": time.strftime("%Y-%m-%d"),
        }
        data.update(pagination_fields)
        # Beds/baths/living_area from page if we want them in pagination row
        beds_tag = soup.find("div", {"data-rf-test-id": "abp-beds"})
        baths_tag = soup.find("div", {"data-rf-test-id": "abp-baths"})
        sqft_tag = soup.find("div", {"data-rf-test-id": "abp-sqFt"})
        if beds_tag:
            data["bedrooms"] = beds_tag.get_text(strip=True)
        if baths_tag:
            data["bathrooms"] = baths_tag.get_text(strip=True)
        if sqft_tag:
            data.setdefault("living_area", sqft_tag.get_text(strip=True))
        return data
    except Exception as e:
        logging.error(f"scrape_pagination_only failed for {url}: {e}")
        return None


def amend_existing_leads_pagination(urls, session=None, max_workers=20):
    """
    Concurrently scrape pagination data for existing leads and upsert into fsbo_pagination.
    Ensures each listing_id has both main lead data (listings/fsbo_leads) and fsbo_pagination.
    urls: list of property URLs, or list of dicts with 'property_url' (and optionally 'listing_id').
    """
    if not urls:
        logging.info("No URLs to amend for pagination.")
        return 0
    # Normalize to list of url strings
    url_list = []
    for u in urls:
        if isinstance(u, dict):
            url_list.append(u.get("property_url") or u.get("url"))
        else:
            url_list.append(u)
    url_list = [u for u in url_list if u and isinstance(u, str) and is_valid_listing_url(u)]
    if not url_list:
        return 0
    target_domain = "https://www.redfin.com"
    session_provided = session is not None
    gateway = None
    if not session_provided:
        gateway = ApiGateway(target_domain, regions=["us-east-1", "us-west-2", "us-east-2", "eu-west-1"])
        gateway.start()
        session = requests.Session()
        session.mount(target_domain, gateway)
        session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
        })
    try:
        saved = 0
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(scrape_pagination_only, u, session): u for u in url_list}
            for future in tqdm(futures, total=len(futures), desc="Amending pagination"):
                try:
                    data = future.result()
                    if data and save_fsbo_pagination_to_supabase:
                        if save_fsbo_pagination_to_supabase(data):
                            saved += 1
                except Exception as e:
                    url = futures.get(future, "unknown")
                    logging.warning(f"Amend pagination failed for {url}: {e}")
        logging.info(f"Amended fsbo_pagination for {saved}/{len(url_list)} listings.")
        return saved
    finally:
        if gateway is not None:
            try:
                gateway.shutdown()
            except Exception as e:
                logging.warning(f"ApiGateway shutdown: {e}")


# Retry config for listing fetches: improves data accuracy under rate limits or transient errors
SCRAPE_MAX_RETRIES = 3
SCRAPE_RETRY_BACKOFF_BASE_SEC = 2  # exponential: 2, 4, 8


def scrape_redfin_listing(url, session):
    """Scrape one Redfin property page and extract all fields. Log missing fields. Retries on 429/503/connection errors."""
    if not is_valid_listing_url(url):
        logging.warning(f"Skipping blocklisted/non-listing URL (not imported): {url}")
        return None
    for attempt in range(1, SCRAPE_MAX_RETRIES + 1):
        try:
            resp = session.get(url, timeout=30)
            if resp.status_code == 200:
                break
            if resp.status_code in (429, 503) and attempt < SCRAPE_MAX_RETRIES:
                backoff = SCRAPE_RETRY_BACKOFF_BASE_SEC ** attempt
                logging.warning(f"Retry {attempt}/{SCRAPE_MAX_RETRIES} for {url}: status {resp.status_code}, waiting {backoff}s")
                time.sleep(backoff)
                continue
            if resp.status_code in (403, 429):
                logging.warning(f"Rate limit or block for {url}: status {resp.status_code}. Consider lowering concurrency.")
            else:
                logging.warning(f"Failed to fetch {url}: status {resp.status_code}")
            return None
        except requests.RequestException as e:
            if attempt < SCRAPE_MAX_RETRIES:
                backoff = SCRAPE_RETRY_BACKOFF_BASE_SEC ** attempt
                logging.warning(f"Retry {attempt}/{SCRAPE_MAX_RETRIES} for {url}: {e}, waiting {backoff}s")
                time.sleep(backoff)
            else:
                logging.warning(f"Failed to fetch {url} after {SCRAPE_MAX_RETRIES} attempts: {e}")
                return None
    try:
        soup = BeautifulSoup(resp.text, "html.parser")
        data = dict.fromkeys(FIELDS, "")
        data['scrape_date'] = time.strftime("%Y-%m-%d")
        data['property_url'] = url
        data['property_id'] = url.split("/")[-1]
        data['permalink'] = url

        # Try to extract embedded JSON for hidden fields
        page_json = extract_json_from_html(soup, url)
        detailed_json = extract_detailed_json(soup, url)

        # NEW: Extract monthly payment estimate
        data['monthly_payment_estimate'] = extract_monthly_payment(soup, resp.content)

        # ENHANCED ADDRESS EXTRACTION
        street_found = False

        # Method 1: Original method with data-rf-test-id
        street_tag = soup.find("span", {"data-rf-test-id": "abp-streetLine"})
        if street_tag:
            data['street'] = street_tag.get_text(strip=True)
            street_found = True
            logging.info(f"Found street using data-rf-test-id for {url}")

        # Method 2: Try specific CSS selector for streetAddress class
        if not street_found:
            street_tag = soup.select_one('h1.streetAddress, .streetAddress, h1.addressBannerRevamp')
            if street_tag:
                data['street'] = street_tag.get_text(strip=True)
                street_found = True
                logging.info(f"Found street using streetAddress class for {url}")

        # Method 3: Try the specific selectors from your requirements
        if not street_found:
            street_tag = soup.select_one(
                '#content > div.detailsContent > div.theRailSection > div.alongTheRail > div:nth-child(1) > section > div > div > div > div.flex-1 > div.AddressBannerV2.deskto[...]')
            if street_tag:
                data['street'] = street_tag.get_text(strip=True)
                street_found = True
                logging.info(f"Found street using specific CSS selector for {url}")

        # Method 4: More generic heading patterns
        if not street_found:
            address_candidates = [
                soup.select_one('.address h1'),
                soup.select_one('.address-container h1'),
                soup.select_one('.AddressBannerV2 h1'),
                soup.select_one('.address'),
                soup.select_one('[data-rf-test-name="address-value"]'),
                soup.find('h1', string=lambda s: s and any(char.isdigit() for char in s))
            ]

            for candidate in address_candidates:
                if candidate:
                    data['street'] = candidate.get_text(strip=True)
                    street_found = True
                    logging.info(f"Found street using generic patterns for {url}")
                    break

        # Method 5: Try to extract from JSON
        if not street_found and detailed_json:
            try:
                # Try various paths where address might be stored in JSON
                street = deep_get(detailed_json, ["payload", "propertyData", "address", "streetLine"]) or \
                         deep_get(detailed_json, ["propertyData", "address", "streetLine"]) or \
                         deep_get(detailed_json, ["address", "streetLine"]) or \
                         deep_get(detailed_json, ["payload", "property", "streetAddress"])

                if street:
                    data['street'] = street
                    street_found = True
                    logging.info(f"Found street from JSON data for {url}")
            except Exception as e:
                logging.error(f"Error extracting street from JSON for {url}: {e}")

        # If still not found, log it
        if not street_found:
            log_missing("street", url)

        # City extraction (keeping the original with fallbacks)
        city_tag = soup.find("span", {"data-rf-test-id": "abp-cityStateZip"})
        if city_tag:
            data['city'] = city_tag.get_text(strip=True)
        else:
            # Try to get city from alternate sources
            city_candidates = [
                soup.select_one('.cityStateZip'),
                soup.select_one('.address-city'),
                soup.select_one('[data-rf-test-name="city-value"]')
            ]

            for candidate in city_candidates:
                if candidate:
                    data['city'] = candidate.get_text(strip=True)
                    break

            # Try to extract city from JSON if still not found
            if not data['city'] and detailed_json:
                try:
                    city = deep_get(detailed_json, ["payload", "propertyData", "address", "city"]) or \
                           deep_get(detailed_json, ["propertyData", "address", "city"]) or \
                           deep_get(detailed_json, ["address", "city"])

                    if city:
                        data['city'] = city
                except Exception:
                    pass

            if not data['city']:
                log_missing("city", url)

        # Try to parse state/zip from URL if not found
        url_parts = url.split("/")
        if len(url_parts) > 4:
            data['state'] = url_parts[3]
            if len(url_parts) > 5:
                # UPDATED: use normalize_zip for ZIP codes
                zip_match = re.search(r'(\d{5})', url_parts[5])
                if zip_match:
                    data['zip_code'] = normalize_zip(zip_match.group(1))
                else:
                    # fallback: extract any digits and zero-pad
                    any_digits = re.search(r'(\d+)', url_parts[5])
                    if any_digits:
                        data['zip_code'] = normalize_zip(any_digits.group(1))
        else:
            log_missing("state or zip_code", url)

        # Try to get ZIP from JSON as well
        if detailed_json and (not data.get('zip_code') or data.get('zip_code') == ""):
            zip_val = deep_get(detailed_json, ["payload", "propertyData", "address", "zipcode"]) or \
                      deep_get(detailed_json, ["propertyData", "address", "zipcode"]) or \
                      deep_get(detailed_json, ["address", "zipcode"]) or \
                      deep_get(detailed_json, ["zipCode"])

            if zip_val:
                data['zip_code'] = normalize_zip(zip_val)

        # Example for beds, baths, sqft, price
        beds_tag = soup.find("div", {"data-rf-test-id": "abp-beds"})
        baths_tag = soup.find("div", {"data-rf-test-id": "abp-baths"})
        sqft_tag = soup.find("div", {"data-rf-test-id": "abp-sqFt"})
        price_tag = soup.find("div", {"data-rf-test-id": "abp-price"})
        data['beds'] = beds_tag.get_text(strip=True) if beds_tag else log_missing("beds", url)
        data['full_baths'] = baths_tag.get_text(strip=True) if baths_tag else log_missing("full_baths", url)
        data['sqft'] = sqft_tag.get_text(strip=True) if sqft_tag else log_missing("sqft", url)

        # Complete fsbo_pagination scrape (property details section). Do not push to Supabase
        # until both FSBO_Leads and fsbo_pagination data are in `data` (this merge completes both).
        pagination_fields = extract_fsbo_pagination_fields(soup, resp.text, url)
        data.update(pagination_fields)
        data.setdefault("bedrooms", data.get("beds", ""))
        data.setdefault("bathrooms", data.get("full_baths", ""))
        if data.get("living_area") == "" and data.get("sqft"):
            data["living_area"] = data["sqft"]

        # UPDATED: Clean price text to remove "Price," and "—Est." text
        if price_tag:
            raw_price = price_tag.get_text(strip=True)
            data['list_price'] = clean_price_text(raw_price)
            logging.info(f"Cleaned price from '{raw_price}' to '{data['list_price']}'")
        else:
            log_missing("list_price", url)

        # Get description text
        desc_tag = soup.find("div", {"class": "remarks"})
        data['text'] = desc_tag.get_text(strip=True) if desc_tag else log_missing("text", url)

        # ENHANCED PHOTO EXTRACTION WITH MULTIPLE METHODS
        photo_found = False
        _photos_excluded_containers = _get_photos_excluded_containers(soup)

        # Method 1: Try to extract from JSON data (most reliable when available)
        if detailed_json:
            # Extract photo URLs from the JSON
            try:
                media_items = deep_get(detailed_json, ["payload", "propertyData", "media", "photos"]) or \
                              deep_get(detailed_json, ["propertyData", "media", "photos"]) or \
                              deep_get(detailed_json, ["payload", "propertyDetail", "photos"]) or \
                              deep_get(detailed_json, ["propertyDetail", "photos"])

                if media_items and isinstance(media_items, list) and len(media_items) > 0:
                    # Extract the URLs from the media items
                    photo_urls = []
                    for item in media_items:
                        if isinstance(item, dict):
                            url_val = item.get('url') or item.get('photoUrl') or item.get('imageUrl')
                            if url_val:
                                photo_urls.append(url_val)

                    if photo_urls:
                        data['photos'] = ",".join(photo_urls)
                        data['primary_photo'] = photo_urls[0]

                        # Fill individual image slots
                        if len(photo_urls) > 0:
                            data['image1_url'] = photo_urls[0]
                        if len(photo_urls) > 1:
                            data['image2_url'] = photo_urls[1]
                        if len(photo_urls) > 2:
                            data['image3_url'] = photo_urls[2]
                        if len(photo_urls) > 3:
                            data['image4_url'] = photo_urls[3]

                        photo_found = True
                        logging.info(f"Found {len(photo_urls)} images from JSON data for {url}")
            except Exception as e:
                logging.error(f"Error extracting photos from JSON for {url}: {e}")

        # Method 1a (high priority): Lightbox photo grid - try first among DOM sources
        if not photo_found:
            try:
                container = soup.select_one(
                    "#LightboxPhotoGrid > div.bp-LightboxPhotoGrid__withSidebar > div.bp-PhotoArea.bp-PhotoAreaGrid.bp-PhotoAreaGrid__ctaLayout"
                )
                if container:
                    photo_tags = container.select("img")
                    photo_tags = [img for img in photo_tags if not _is_img_in_excluded_photo_container(img, _photos_excluded_containers)]
                    urls = []
                    for img in photo_tags:
                        src = img.get("src") or img.get("data-src") or img.get("data-lazy-src")
                        if src and src.strip().startswith("http"):
                            urls.append(src.strip())
                    if urls:
                        data["photos"] = ",".join(urls)
                        data["primary_photo"] = urls[0]
                        for i, u in enumerate(urls[:4]):
                            data[f"image{i + 1}_url"] = u
                        photo_found = True
                        logging.info(f"Found {len(urls)} images from LightboxPhotoGrid for {url}")
                if not photo_found and resp:
                    try:
                        from lxml import html as lxml_html
                        tree = lxml_html.fromstring(resp.content)
                        nodes = tree.xpath("/html/body/div[4]/div[2]/div/div[2]/div[2]/div/div/div[1]/div/div[1]/div[1]//img")
                        urls = []
                        for img in nodes:
                            src = img.get("src") or img.get("data-src") or img.get("data-lazy-src")
                            if src and isinstance(src, str) and src.strip().startswith("http"):
                                urls.append(src.strip())
                        if urls:
                            data["photos"] = ",".join(urls)
                            data["primary_photo"] = urls[0]
                            for i, u in enumerate(urls[:4]):
                                data[f"image{i + 1}_url"] = u
                            photo_found = True
                            logging.info(f"Found {len(urls)} images from LightboxPhotoGrid (XPath) for {url}")
                    except Exception:
                        pass
            except Exception as e:
                logging.debug(f"LightboxPhotoGrid photo extraction: {e}")

        # Method 1b: Preferred DOM area - overview-scroll InlinePhotoPreviewSection
        if not photo_found:
            try:
                container = soup.select_one("#overview-scroll > div.componentSection.InlinePhotoPreviewSection > div")
                if container:
                    photo_tags = container.select("img")
                    photo_tags = [img for img in photo_tags if not _is_img_in_excluded_photo_container(img, _photos_excluded_containers)]
                    urls = []
                    for img in photo_tags:
                        src = img.get("src") or img.get("data-src") or img.get("data-lazy-src")
                        if src and src.strip().startswith("http"):
                            urls.append(src.strip())
                    if urls:
                        data["photos"] = ",".join(urls)
                        data["primary_photo"] = urls[0]
                        for i, u in enumerate(urls[:4]):
                            data[f"image{i + 1}_url"] = u
                        photo_found = True
                        logging.info(f"Found {len(urls)} images from InlinePhotoPreviewSection for {url}")
            except Exception as e:
                logging.debug(f"InlinePhotoPreviewSection photo extraction: {e}")

        # Method 2: Original method - gallery images
        if not photo_found:
            photo_tags = soup.find_all("img", {"class": "gallery-image"})
            photo_tags = [img for img in photo_tags if not _is_img_in_excluded_photo_container(img, _photos_excluded_containers)]
            if photo_tags:
                urls = [img.get('src') for img in photo_tags if img.get('src')]
                if urls:
                    data['photos'] = ",".join(urls)
                    data['primary_photo'] = urls[0]

                    # Fill individual image slots
                    if len(urls) > 0:
                        data['image1_url'] = urls[0]
                    if len(urls) > 1:
                        data['image2_url'] = urls[1]
                    if len(urls) > 2:
                        data['image3_url'] = urls[2]
                    if len(urls) > 3:
                        data['image4_url'] = urls[3]

                    photo_found = True
                    logging.info(f"Found {len(urls)} images using gallery-image class for {url}")

        # Method 3: Try multiple CSS selectors for photo gallery
        if not photo_found:
            selectors = [
                "img.Photo",  # Common class name
                "div.HomePhotos img",  # Common container
                "section.PhotosView img",  # Another common pattern
                ".InlinePhotoPreview img",  # Another gallery pattern
                "div[data-rf-test-id='gallery'] img",  # Test ID approach
                "div.HomeCard img",  # HomeCard images
                ".multimedia-img img",  # Another common pattern
                "picture img"  # Any image in picture tag
            ]

            for selector in selectors:
                photo_tags = soup.select(selector)
                photo_tags = [img for img in photo_tags if not _is_img_in_excluded_photo_container(img, _photos_excluded_containers)]
                if photo_tags:
                    urls = [img.get('src') for img in photo_tags if img.get('src')]
                    if urls:
                        data['photos'] = ",".join(urls)
                        data['primary_photo'] = urls[0]

                        # Fill individual image slots
                        if len(urls) > 0:
                            data['image1_url'] = urls[0]
                        if len(urls) > 1:
                            data['image2_url'] = urls[1]
                        if len(urls) > 2:
                            data['image3_url'] = urls[2]
                        if len(urls) > 3:
                            data['image4_url'] = urls[3]

                        photo_found = True
                        logging.info(f"Found {len(urls)} images using selector '{selector}' for {url}")
                        break

        # Method 4: Preferred MBImage ID selectors (overview gallery area)
        MBIMAGE_SELECTORS = [
            "#MBImage > img",
            "#MBImage6 > img",
            "#MBImage19 > img",
            "#MBImage10 > img",
            "#MBImage15 > img",
            "#MBImage3 > img",
            "#MBImage13 > img",
            "#MBImage9 > img",
            "#MBImage18 > img",
            "#MBImage > picture > img",
            "#MBImage6 > picture > img",
            "#MBImage9 > picture > img",
            "#MBImage18 > picture > img",
        ]
        mbimage_urls = []
        for sel in MBIMAGE_SELECTORS:
            img = soup.select_one(sel)
            if img and img.get("src") and not _is_img_in_excluded_photo_container(img, _photos_excluded_containers):
                u = img.get("src").strip()
                if u.startswith("http") and u not in mbimage_urls:
                    mbimage_urls.append(u)
        if mbimage_urls:
            if not data.get("photos"):
                data["photos"] = ",".join(mbimage_urls)
                data["primary_photo"] = mbimage_urls[0]
                logging.info(f"Found {len(mbimage_urls)} images from MBImage selectors for {url}")
            for i, u in enumerate(mbimage_urls[:4]):
                if not data.get(f"image{i + 1}_url"):
                    data[f"image{i + 1}_url"] = u

        # Method 5: Check for lazily-loaded images
        if not photo_found:
            lazy_imgs = soup.select('img[data-lazy-src], img[loading="lazy"]')
            lazy_imgs = [img for img in lazy_imgs if not _is_img_in_excluded_photo_container(img, _photos_excluded_containers)]
            if lazy_imgs:
                urls = []
                for img in lazy_imgs:
                    url_val = img.get('data-lazy-src') or img.get('data-src') or img.get('src')
                    if url_val and url_val.startswith('http') and (
                            '.jpg' in url_val or '.png' in url_val or '.jpeg' in url_val):
                        urls.append(url_val)

                if urls:
                    data['photos'] = ",".join(urls)
                    data['primary_photo'] = urls[0]

                    # Fill individual image slots
                    if len(urls) > 0:
                        data['image1_url'] = urls[0]
                    if len(urls) > 1:
                        data['image2_url'] = urls[1]
                    if len(urls) > 2:
                        data['image3_url'] = urls[2]
                    if len(urls) > 3:
                        data['image4_url'] = urls[3]

                    photo_found = True
                    logging.info(f"Found {len(urls)} images from lazy-loaded images for {url}")

        # Log missing if still not found
        if not data.get('photos'):
            log_missing("photos", url)
        if not data.get('primary_photo'):
            log_missing("primary_photo", url)
        if not data.get('image1_url'):
            log_missing("image1_url", url)
        if not data.get('image2_url'):
            log_missing("image2_url", url)
        if not data.get('image3_url'):
            log_missing("image3_url", url)
        if not data.get('image4_url'):
            log_missing("image4_url", url)

        # AGENT PHONE EXTRACTION - FOCUSED FIX
        # Using exact XPath and CSS selectors provided

        phone_found = False

        # Method 1: Agent Phone 1 - Direct CSS selector for mortgage calculator
        try:
            # Exact CSS selector provided
            phone1_selector = "#MortgageCalculator > div.calculatorContentsContainer > div.MortgageCalculatorSummary.isDesktop > div > div.sectionText.shift-reset-right > div > p"
            phone1_tag = soup.select_one(phone1_selector)

            if phone1_tag:
                print(f"Found phone1_tag content: {phone1_tag.get_text(strip=True)}")  # Debug print
                phone_text = phone1_tag.get_text(strip=True)
                phone_number = extract_phone_from_text(phone_text)

                if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                    data['agent_phone'] = phone_number  # Set as primary agent_phone
                    data['agent_phone_1'] = phone_number
                    phone_found = True
                    print(f"Set agent_phone to {phone_number} from mortgage calculator")
                    logging.info(f"Found agent_phone from mortgage calculator: {phone_number} for {url}")
        except Exception as e:
            logging.error(f"Error extracting agent_phone_1 with CSS: {e}")

        # Method 2: Agent Phone 1 - XPath approach
        if not phone_found:
            try:
                # Exact XPath provided
                phone1_xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[18]/section/div/div/div/div/div[1]/div[1]/div/div[1]/div/p'
                phone_text = extract_by_xpath(resp.content, phone1_xpath)

                if phone_text:
                    print(f"Found phone1 XPath content: {phone_text}")  # Debug print
                    phone_number = extract_phone_from_text(phone_text)

                    if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                        data['agent_phone'] = phone_number  # Set as primary agent_phone
                        data['agent_phone_1'] = phone_number
                        phone_found = True
                        print(f"Set agent_phone to {phone_number} from XPath mortgage calculator")
                        logging.info(f"Found agent_phone from XPath mortgage calculator: {phone_number} for {url}")
            except Exception as e:
                logging.error(f"Error extracting agent_phone_1 with XPath: {e}")

        # Method 3: Agent Phone 2 - CSS selector
        try:
            # Exact CSS selector provided
            phone2_selector = "#content > div.detailsContent > div.theRailSection > div.alongTheRail > div:nth-child(12) > section > div > div > div.cta > p > a"
            phone2_tag = soup.select_one(phone2_selector)

            if phone2_tag:
                print(f"Found phone2_tag content: {phone2_tag.get_text(strip=True)}")  # Debug print
                phone_text = phone2_tag.get_text(strip=True)
                phone_number = normalize_phone(phone_text)

                if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                    data['agent_phone_2'] = phone_number
                    # If primary phone not set, use this one
                    if not data.get('agent_phone'):
                        data['agent_phone'] = phone_number
                        phone_found = True
                        print(f"Set agent_phone to {phone_number} from CTA")
                    logging.info(f"Found agent_phone_2 from CTA: {phone_number} for {url}")
        except Exception as e:
            logging.error(f"Error extracting agent_phone_2 with CSS: {e}")

        # Method 4: Agent Phone 2 - XPath
        if not phone_found:
            try:
                # Exact XPath provided
                phone2_xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/div/div[1]/div[2]/div/div/span[5]/div/span[2]'
                phone_text = extract_by_xpath(resp.content, phone2_xpath)

                if phone_text:
                    print(f"Found phone2 XPath content: {phone_text}")  # Debug print
                    phone_number = normalize_phone(phone_text)

                    if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                        data['agent_phone_2'] = phone_number
                        # If primary phone not set, use this one
                        if not data.get('agent_phone'):
                            data['agent_phone'] = phone_number
                            phone_found = True
                            print(f"Set agent_phone to {phone_number} from XPath agent info")
                        logging.info(f"Found agent_phone_2 from XPath agent info: {phone_number} for {url}")
            except Exception as e:
                logging.error(f"Error extracting agent_phone_2 with XPath: {e}")

        # NEW FIELDS: LISTING AGENT PHONE AND EMAIL EXTRACTION

        # Method 1: Listing Agent Phone - from listing agent section in disclaimer
        try:
            # Exact CSS selector provided
            listing_agent_selector = "#content > div.detailsContent > div.belowTheRail > div:nth-child(2) > section > div > div.disclaimer > div > div.listingProvider > div.listingAgent"
            listing_agent_tag = soup.select_one(listing_agent_selector)

            if listing_agent_tag:
                print(f"Found listing agent tag content: {listing_agent_tag.get_text(strip=True)}")
                phone_number = extract_phone_from_text(listing_agent_tag.get_text(strip=True))

                if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                    data['listing_agent_phone'] = phone_number
                    print(f"Set listing_agent_phone to {phone_number}")
                    logging.info(f"Found listing_agent_phone from disclaimer section: {phone_number} for {url}")
        except Exception as e:
            logging.error(f"Error extracting listing_agent_phone with CSS: {e}")

        # Method 2: Listing Agent Phone - XPath approach
        if not data.get('listing_agent_phone'):
            try:
                listing_agent_xpath = '/html/body/div[1]/div[8]/div[3]/div[2]/section/div/div[2]/div/div[1]/div[2]'
                listing_agent_text = extract_by_xpath(resp.content, listing_agent_xpath)

                if listing_agent_text:
                    print(f"Found listing agent XPath content: {listing_agent_text}")
                    phone_number = extract_phone_from_text(listing_agent_text)

                    if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                        data['listing_agent_phone'] = phone_number
                        print(f"Set listing_agent_phone to {phone_number} from XPath")
                        logging.info(f"Found listing_agent_phone from XPath: {phone_number} for {url}")
            except Exception as e:
                logging.error(f"Error extracting listing_agent_phone with XPath: {e}")

        # Method 3: Listing Agent Phone 2 - from listing contact section
        try:
            listing_contact_selector = "#house-info > div:nth-child(3) > div > div > div.listingContactSection"
            listing_contact_tag = soup.select_one(listing_contact_selector)

            if listing_contact_tag:
                print(f"Found listing contact section: {listing_contact_tag.get_text(strip=True)}")
                phone_number = extract_phone_from_text(listing_contact_tag.get_text(strip=True))

                if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                    data['listing_agent_phone_2'] = phone_number
                    print(f"Set listing_agent_phone_2 to {phone_number}")
                    logging.info(f"Found listing_agent_phone_2 from contact section: {phone_number} for {url}")
        except Exception as e:
            logging.error(f"Error extracting listing_agent_phone_2 with CSS: {e}")

        # Method 4: Listing Agent Phone 2 - XPath approach
        if not data.get('listing_agent_phone_2'):
            try:
                listing_contact_xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/div/div[2]'
                listing_contact_text = extract_by_xpath(resp.content, listing_contact_xpath)

                if listing_contact_text:
                    print(f"Found listing contact XPath content: {listing_contact_text}")
                    phone_number = extract_phone_from_text(listing_contact_text)

                    if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                        data['listing_agent_phone_2'] = phone_number
                        print(f"Set listing_agent_phone_2 to {phone_number} from XPath")
                        logging.info(f"Found listing_agent_phone_2 from XPath: {phone_number} for {url}")
            except Exception as e:
                logging.error(f"Error extracting listing_agent_phone_2 with XPath: {e}")

        # Method 5: Listing Agent Phone 3 - (same section as Phone 2 but separate extraction logic)
        try:
            # Look for tel: links specifically in the listing contact section
            if 'listing_contact_tag' in locals() and listing_contact_tag:
                tel_links = listing_contact_tag.select('a[href^="tel:"]')
                if tel_links:
                    href = tel_links[0].get('href', '')
                    if href.startswith('tel:'):
                        phone_number = normalize_phone(href[4:])  # Remove 'tel:' prefix
                        if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                            data['listing_agent_phone_3'] = phone_number
                            print(f"Set listing_agent_phone_3 to {phone_number} from tel: link")
                            logging.info(f"Found listing_agent_phone_3 from tel link: {phone_number} for {url}")
        except Exception as e:
            logging.error(f"Error extracting listing_agent_phone_3 with CSS: {e}")

        # START: New fields from user request
        # Listing_Agent_Phone_Number_4
        try:
            phone4_selector = "#house-info > div:nth-child(3) > div > div > div.listingContactSection"
            phone4_tag = soup.select_one(phone4_selector)
            if phone4_tag:
                phone_text = phone4_tag.get_text(strip=True)
                phone_number = extract_phone_from_text(phone_text)
                if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                    data['listing_agent_phone_4'] = phone_number
                    logging.info(f"Found listing_agent_phone_4 from CSS: {phone_number} for {url}")
        except Exception as e:
            logging.error(f"Error extracting listing_agent_phone_4 with CSS: {e}")

        if not data.get('listing_agent_phone_4'):
            try:
                phone4_xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/div/div[2]'
                phone_text = extract_by_xpath(resp.content, phone4_xpath)
                if phone_text:
                    phone_number = extract_phone_from_text(phone_text)
                    if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                        data['listing_agent_phone_4'] = phone_number
                        logging.info(f"Found listing_agent_phone_4 from XPath: {phone_number} for {url}")
            except Exception as e:
                logging.error(f"Error extracting listing_agent_phone_4 with XPath: {e}")

        # Listing_Agent_Phone_Number_5
        try:
            phone5_selector = "#house-info > div:nth-child(3) > div > div > div.agent-info-container > div.agent-info-content > div > div > span.agent-extra-info--phone > div > span:nth-child(2)"
            phone5_tag = soup.select_one(phone5_selector)
            if phone5_tag:
                phone_text = phone5_tag.get_text(strip=True)
                phone_number = normalize_phone(phone_text)
                if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                    data['listing_agent_phone_5'] = phone_number
                    logging.info(f"Found listing_agent_phone_5 from CSS: {phone_number} for {url}")
        except Exception as e:
            logging.error(f"Error extracting listing_agent_phone_5 with CSS: {e}")

        if not data.get('listing_agent_phone_5'):
            try:
                phone5_xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/div/div[1]/div[2]/div/div/span[5]/div/span[2]'
                phone_text = extract_by_xpath(resp.content, phone5_xpath)
                if phone_text:
                    phone_number = normalize_phone(phone_text)
                    if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                        data['listing_agent_phone_5'] = phone_number
                        logging.info(f"Found listing_agent_phone_5 from XPath: {phone_number} for {url}")
            except Exception as e:
                logging.error(f"Error extracting listing_agent_phone_5 with XPath: {e}")

        # Listing_Source
        try:
            source_selector = "#house-info > div:nth-child(3) > div > p"
            source_tag = soup.select_one(source_selector)
            if source_tag:
                data['listing_source'] = source_tag.get_text(strip=True)
                logging.info(f"Found listing_source from CSS for {url}")
        except Exception as e:
            logging.error(f"Error extracting listing_source with CSS: {e}")

        if not data.get('listing_source'):
            try:
                source_xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/p'
                source_text = extract_by_xpath(resp.content, source_xpath)
                if source_text:
                    data['listing_source'] = source_text
                    logging.info(f"Found listing_source from XPath for {url}")
            except Exception as e:
                logging.error(f"Error extracting listing_source with XPath: {e}")
        # END: New fields from user request

        # Method 6: Listing Agent Email
        try:
            # Exact CSS selector provided
            email_selector = "#house-info > div:nth-child(3) > div > div > div.agent-info-container > div.agent-info-content > div > div > span.agent-extra-info--email > div > span:nth-child(2)"
            email_tag = soup.select_one(email_selector)

            if email_tag:
                print(f"Found email tag content: {email_tag.get_text(strip=True)}")
                email_text = email_tag.get_text(strip=True)
                email = extract_email_from_text(email_text) or email_text

                if email and '@' in email:
                    data['listing_agent_email'] = email
                    data['agent_email'] = email  # Also set the main agent_email field
                    print(f"Set listing_agent_email to {email}")
                    logging.info(f"Found listing_agent_email: {email} for {url}")
        except Exception as e:
            logging.error(f"Error extracting listing_agent_email with CSS: {e}")

        # Method 7: Listing Agent Email - XPath approach
        if not data.get('listing_agent_email'):
            try:
                email_xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/div/div[1]/div[2]/div/div/span[6]/div/span[2]'
                email_text = extract_by_xpath(resp.content, email_xpath)

                if email_text:
                    print(f"Found email XPath content: {email_text}")
                    email = extract_email_from_text(email_text) or email_text

                    if email and '@' in email:
                        data['listing_agent_email'] = email
                        data['agent_email'] = email  # Also set the main agent_email field
                        print(f"Set listing_agent_email to {email} from XPath")
                        logging.info(f"Found listing_agent_email from XPath: {email} for {url}")
            except Exception as e:
                logging.error(f"Error extracting listing_agent_email with XPath: {e}")

        # Method 8: Last resort - look for any email pattern in the page
        if not data.get('listing_agent_email'):
            try:
                # Look for email addresses in specific areas first
                potential_email_containers = [
                    soup.select_one('.agent-info-content'),
                    soup.select_one('.listingContactSection'),
                    soup.select_one('.agentInfo'),
                    soup.select_one('.contactInfo'),
                    soup.select_one('span.email')
                ]

                for container in potential_email_containers:
                    if not container:
                        continue

                    container_text = container.get_text(strip=True)
                    email = extract_email_from_text(container_text)

                    if email:
                        data['listing_agent_email'] = email
                        data['agent_email'] = email
                        print(f"Set listing_agent_email to {email} from container search")
                        logging.info(f"Found listing_agent_email from container search: {email} for {url}")
                        break
            except Exception as e:
                logging.error(f"Error extracting email from containers: {e}")

        # Last resort - scan all a tags with mailto: href
        if not data.get('listing_agent_email'):
            try:
                mailto_links = soup.select('a[href^="mailto:"]')
                for link in mailto_links:
                    href = link.get('href', '')
                    if href.startswith('mailto:'):
                        email = href[7:]  # Remove 'mailto:' prefix
                        data['listing_agent_email'] = email
                        data['agent_email'] = email
                        print(f"Set listing_agent_email to {email} from mailto: link")
                        logging.info(f"Found listing_agent_email from mailto: link: {email} for {url}")
                        break
            except Exception as e:
                logging.error(f"Error extracting email from mailto links: {e}")

        # Method 5: Last resort - look for any phone number pattern in the page
        if not phone_found:
            try:
                # Look for phone numbers in specific areas first
                potential_phone_containers = [
                    soup.select_one('.PhoneNumberDisplay'),
                    soup.select_one('.agentInfo'),
                    soup.select_one('.contactInfo'),
                    soup.select_one('.agent-phone'),
                    soup.select_one('[data-rf-test-name="agentPhoneValue"]')
                ]

                for container in potential_phone_containers:
                    if not container:
                        continue

                    container_text = container.get_text(strip=True)
                    phone_number = extract_phone_from_text(container_text)

                    if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                        data['agent_phone'] = phone_number
                        phone_found = True
                        print(f"Set agent_phone to {phone_number} from container search")
                        logging.info(f"Found agent_phone from container search: {phone_number} for {url}")
                        break
            except Exception as e:
                logging.error(f"Error extracting phone from containers: {e}")

        # Last resort - scan all a tags with tel: href
        if not phone_found:
            try:
                tel_links = soup.select('a[href^="tel:"]')
                for link in tel_links:
                    href = link.get('href', '')
                    if href.startswith('tel:'):
                        phone_number = normalize_phone(href[4:])  # Remove 'tel:' prefix
                        if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                            data['agent_phone'] = phone_number
                            phone_found = True
                            print(f"Set agent_phone to {phone_number} from tel: link")
                            logging.info(f"Found agent_phone from tel: link: {phone_number} for {url}")
                            break
            except Exception as e:
                logging.error(f"Error extracting phone from tel links: {e}")

        # Extract from JSON if available and still not found
        if not phone_found and detailed_json:
            try:
                phone = deep_get(detailed_json, ["payload", "propertyData", "listingAgent", "phoneNumber"]) or \
                        deep_get(detailed_json, ["propertyData", "listingAgent", "phoneNumber"]) or \
                        deep_get(detailed_json, ["agentInfo", "phone"]) or \
                        deep_get(page_json, ["propertyDetails", "listing", "agentPhone"])

                if phone:
                    phone_number = normalize_phone(phone)
                    if phone_number and phone_number not in BLACKLISTED_PHONE_NUMBERS:
                        data['agent_phone'] = phone_number
                        phone_found = True
                        print(f"Set agent_phone to {phone_number} from JSON data")
                        logging.info(f"Found agent_phone from JSON data: {phone_number} for {url}")
            except Exception as e:
                logging.error(f"Error extracting phone from JSON: {e}")

        if not phone_found:
            log_missing("agent_phone", url)
            print(f"WARNING: Failed to find agent_phone for {url}")

        # Agent Name: try each (CSS, XPath) pair until one returns a value
        html_bytes = resp.content if hasattr(resp, 'content') else (resp.encode("utf-8") if isinstance(resp, str) else resp)
        for css_sel, xpath in AGENT_NAME_SELECTORS:
            agent_name_tag = soup.select_one(css_sel)
            if agent_name_tag:
                text = agent_name_tag.get_text(strip=True)
                if text:
                    data['agent_name'] = text
                    logging.info(f"Found agent_name using CSS for {url}")
                    break
            if not data.get('agent_name') and xpath:
                agent_name = extract_by_xpath(html_bytes, xpath)
                if agent_name and (agent_name := agent_name.strip()):
                    data['agent_name'] = agent_name
                    logging.info(f"Found agent_name using XPath for {url}")
                    break

        # Listing Source Name: try each (CSS, XPath) pair until one returns a value
        for css_sel, xpath in LISTING_SOURCE_NAME_SELECTORS:
            source_name_tag = soup.select_one(css_sel)
            if source_name_tag:
                text = source_name_tag.get_text(strip=True)
                if text:
                    data['listing_source_name'] = text
                    logging.info(f"Found listing_source_name using CSS for {url}")
                    break
            if not data.get('listing_source_name') and xpath:
                source_name = extract_by_xpath(html_bytes, xpath)
                if source_name and (source_name := source_name.strip()):
                    data['listing_source_name'] = source_name
                    logging.info(f"Found listing_source_name using XPath for {url}")
                    break

        # Listing Source ID
        source_id_tag = soup.select_one(
            '#house-info > div:nth-child(3) > div > div > div.listingInfoSection > div > div.ListingSource > span.ListingSource--mlsId')
        if source_id_tag:
            data['listing_source_id'] = source_id_tag.get_text(strip=True)
            logging.info(f"Found listing_source_id using CSS for {url}")

        return data

    except Exception as e:
        logging.error(f"Error scraping listing {url}: {e}")
        return None


async def scrape_redfin_listing_async(url, session):
    """Async version of scrape_redfin_listing for better performance."""
    try:
        async with session.get(url, timeout=aiohttp.ClientTimeout(total=30)) as resp:
            if resp.status != 200:
                logging.warning(f"Failed to fetch {url}: {resp.status}")
                return None

            html_content = await resp.text()
            soup = BeautifulSoup(html_content, "html.parser")

            data = dict.fromkeys(FIELDS, "")
            data['scrape_date'] = time.strftime("%Y-%m-%d")
            data['property_url'] = url
            data['property_id'] = url.split("/")[-1]
            data['permalink'] = url

            # Try to extract embedded JSON for hidden fields
            page_json = extract_json_from_html(soup, url)
            detailed_json = extract_detailed_json(soup, url)

            # Extract monthly payment estimate
            data['monthly_payment_estimate'] = extract_monthly_payment(soup, html_content)

            # ENHANCED ADDRESS EXTRACTION (same logic as sync version)
            street_found = False

            # Method 1: Original method with data-rf-test-id
            street_tag = soup.find("span", {"data-rf-test-id": "abp-streetLine"})
            if street_tag:
                data['street'] = street_tag.get_text(strip=True)
                street_found = True

            # Method 2: Try specific CSS selector for streetAddress class
            if not street_found:
                street_tag = soup.select_one('h1.streetAddress, .streetAddress, h1.addressBannerRevamp')
                if street_tag:
                    data['street'] = street_tag.get_text(strip=True)
                    street_found = True

            # Method 3: Try the specific selectors from your requirements
            if not street_found:
                street_tag = soup.select_one(
                    '#content > div.detailsContent > div.theRailSection > div.alongTheRail > div:nth-child(1) > section > div > div > div > div.flex-1 > div.AddressBannerV2.deskto[...]')
                if street_tag:
                    data['street'] = street_tag.get_text(strip=True)
                    street_found = True

            # Method 4: More generic heading patterns
            if not street_found:
                address_candidates = [
                    soup.select_one('.address h1'),
                    soup.select_one('.address-container h1'),
                    soup.select_one('.AddressBannerV2 h1'),
                    soup.select_one('.address'),
                    soup.select_one('[data-rf-test-name="address-value"]'),
                    soup.find('h1', string=lambda s: s and any(char.isdigit() for char in s))
                ]

                for candidate in address_candidates:
                    if candidate:
                        data['street'] = candidate.get_text(strip=True)
                        street_found = True
                        break

            # Method 5: Try to extract from JSON
            if not street_found and detailed_json:
                try:
                    street = deep_get(detailed_json, ["payload", "propertyData", "address", "streetLine"]) or \
                             deep_get(detailed_json, ["propertyData", "address", "streetLine"]) or \
                             deep_get(detailed_json, ["address", "streetLine"]) or \
                             deep_get(detailed_json, ["payload", "property", "streetAddress"])

                    if street:
                        data['street'] = street
                        street_found = True
                except Exception as e:
                    logging.error(f"Error extracting street from JSON for {url}: {e}")

            # City extraction
            city_tag = soup.find("span", {"data-rf-test-id": "abp-cityStateZip"})
            if city_tag:
                data['city'] = city_tag.get_text(strip=True)
            else:
                city_candidates = [
                    soup.select_one('.cityStateZip'),
                    soup.select_one('.address-city'),
                    soup.select_one('[data-rf-test-name="city-value"]')
                ]

                for candidate in city_candidates:
                    if candidate:
                        data['city'] = candidate.get_text(strip=True)
                        break

                if not data['city'] and detailed_json:
                    try:
                        city = deep_get(detailed_json, ["payload", "propertyData", "address", "city"]) or \
                               deep_get(detailed_json, ["propertyData", "address", "city"]) or \
                               deep_get(detailed_json, ["address", "city"])

                        if city:
                            data['city'] = city
                    except Exception:
                        pass

            # Parse state/zip from URL
            url_parts = url.split("/")
            if len(url_parts) > 4:
                data['state'] = url_parts[3]
                if len(url_parts) > 5:
                    zip_match = re.search(r'(\d{5})', url_parts[5])
                    if zip_match:
                        data['zip_code'] = normalize_zip(zip_match.group(1))
                    else:
                        any_digits = re.search(r'(\d+)', url_parts[5])
                        if any_digits:
                            data['zip_code'] = normalize_zip(any_digits.group(1))

            # Try to get ZIP from JSON as well
            if detailed_json and (not data.get('zip_code') or data.get('zip_code') == ""):
                zip_val = deep_get(detailed_json, ["payload", "propertyData", "address", "zipcode"]) or \
                          deep_get(detailed_json, ["propertyData", "address", "zipcode"]) or \
                          deep_get(detailed_json, ["address", "zipcode"]) or \
                          deep_get(detailed_json, ["zipCode"])

                if zip_val:
                    data['zip_code'] = normalize_zip(zip_val)

            # Extract beds, baths, sqft, price
            beds_tag = soup.find("div", {"data-rf-test-id": "abp-beds"})
            baths_tag = soup.find("div", {"data-rf-test-id": "abp-baths"})
            sqft_tag = soup.find("div", {"data-rf-test-id": "abp-sqFt"})
            price_tag = soup.find("div", {"data-rf-test-id": "abp-price"})

            data['beds'] = beds_tag.get_text(strip=True) if beds_tag else ""
            data['full_baths'] = baths_tag.get_text(strip=True) if baths_tag else ""
            data['sqft'] = sqft_tag.get_text(strip=True) if sqft_tag else ""

            # Complete fsbo_pagination scrape. Full scrape (FSBO_Leads + fsbo_pagination) is
            # complete before we return; do not push to Supabase until caller has this data.
            pagination_fields = extract_fsbo_pagination_fields(soup, html_content, url)
            data.update(pagination_fields)
            data.setdefault("bedrooms", data.get("beds", ""))
            data.setdefault("bathrooms", data.get("full_baths", ""))
            if data.get("living_area") == "" and data.get("sqft"):
                data["living_area"] = data["sqft"]

            # Clean price text
            if price_tag:
                raw_price = price_tag.get_text(strip=True)
                data['list_price'] = clean_price_text(raw_price)

            # Get description text
            desc_tag = soup.find("div", {"class": "remarks"})
            data['text'] = desc_tag.get_text(strip=True) if desc_tag else ""

            # Extract photos from JSON (simplified version)
            if detailed_json:
                try:
                    media_items = deep_get(detailed_json, ["payload", "propertyData", "media", "photos"]) or \
                                  deep_get(detailed_json, ["propertyData", "media", "photos"])

                    if media_items and isinstance(media_items, list) and len(media_items) > 0:
                        photo_urls = []
                        for item in media_items[:10]:  # Limit to first 10 photos
                            if isinstance(item, dict):
                                url_val = item.get('url') or item.get('photoUrl')
                                if url_val:
                                    photo_urls.append(url_val)

                        if photo_urls:
                            data['photos'] = ",".join(photo_urls)
                            data['primary_photo'] = photo_urls[0]

                            # Fill individual image slots
                            for i, photo_url in enumerate(photo_urls[:4]):
                                data[f'image{i+1}_url'] = photo_url
                except Exception as e:
                    logging.error(f"Error extracting photos for {url}: {e}")

            # Extract agent info (simplified)
            agent_name_tag = soup.find("span", {"data-rf-test-id": "agent-name"})
            if agent_name_tag:
                data['agent_name'] = agent_name_tag.get_text(strip=True)
            if not data.get('agent_name'):
                html_bytes = html_content.encode("utf-8") if isinstance(html_content, str) else html_content
                for css_sel, xpath in AGENT_NAME_SELECTORS:
                    tag = soup.select_one(css_sel)
                    if tag:
                        text = tag.get_text(strip=True)
                        if text:
                            data['agent_name'] = text
                            break
                    if not data.get('agent_name') and xpath:
                        name = extract_by_xpath(html_bytes, xpath)
                        if name and (name := name.strip()):
                            data['agent_name'] = name
                            break

            agent_phone_tag = soup.find("a", {"data-rf-test-id": "agent-phone"})
            if agent_phone_tag:
                data['agent_phone'] = agent_phone_tag.get_text(strip=True)

            # Listing source name: try each (CSS, XPath) pair until one returns a value
            _html_bytes = html_content.encode("utf-8") if isinstance(html_content, str) else html_content
            for css_sel, xpath in LISTING_SOURCE_NAME_SELECTORS:
                tag = soup.select_one(css_sel)
                if tag:
                    text = tag.get_text(strip=True)
                    if text:
                        data['listing_source_name'] = text
                        break
                if not data.get('listing_source_name') and xpath:
                    name = extract_by_xpath(_html_bytes, xpath)
                    if name and (name := name.strip()):
                        data['listing_source_name'] = name
                        break

            return data

    except requests.exceptions.Timeout:
        logging.warning(f"Timeout scraping listing {url}")
        return None
    except requests.exceptions.RequestException as e:
        logging.warning(f"Request error scraping {url}: {e}")
        return None
    except Exception as e:
        logging.error(f"Error scraping listing {url}: {e}")
        return None


def _push_listing_to_supabase(data):
    """
    Push one fully-scraped listing to Supabase (fsbo_leads only). All lead and pagination
    fields are written to fsbo_leads; fsbo_pagination table is no longer used.
    Returns True if save succeeded, False otherwise.
    """
    if not data:
        return False
    if save_lead_to_fsbo_leads:
        try:
            return save_lead_to_fsbo_leads(data)
        except Exception as e:
            logging.warning(f"fsbo_leads save failed for {data.get('property_url')}: {e}")
            return False
    return False


def _save_listing_result(data, mode="a"):
    """
    Persist one scraped listing only after the full scrape is complete (both FSBO_Leads and
    fsbo_pagination fields are in `data`). Order: CSV, then push to Supabase (fsbo_leads)
    via _push_listing_to_supabase. Returns True if Supabase save succeeded.
    """
    if not data:
        return False

    # Compute and attach completeness metrics for this listing
    present, total, pct, missing = compute_completeness(data)
    data["completeness_present_required"] = present
    data["completeness_total_required"] = total
    data["completeness_ratio"] = round(pct, 4)
    data["completeness_missing_required"] = ",".join(missing) if missing else ""
    logging.info(
        f"Completeness for {data.get('property_url')}: "
        f"{present}/{total} required fields present ({pct*100:.1f}%), "
        f"missing={missing if missing else '[]'}"
    )

    save_to_csv(data, mode)
    return _push_listing_to_supabase(data)


def _save_listing_results_batch(data_list, mode="a"):
    """
    Persist a batch of scraped listings only after each listing's full scrape is complete
    (both FSBO_Leads and fsbo_pagination data). Order: CSV batch, then for each listing
    push to Supabase (fsbo_leads, then fsbo_pagination).
    """
    if not data_list:
        return

    # Compute completeness for each listing before persisting
    for data in data_list:
        if not data:
            continue
        present, total, pct, missing = compute_completeness(data)
        data["completeness_present_required"] = present
        data["completeness_total_required"] = total
        data["completeness_ratio"] = round(pct, 4)
        data["completeness_missing_required"] = ",".join(missing) if missing else ""
        logging.info(
            f"Completeness for {data.get('property_url')}: "
            f"{present}/{total} required fields present ({pct*100:.1f}%), "
            f"missing={missing if missing else '[]'}"
        )

    save_batch_to_csv(data_list, mode)
    for data in data_list:
        _push_listing_to_supabase(data)


def save_to_csv(data, mode="a"):
    """Save data to a CSV file with proper handling of ZIP codes and price formatting."""
    try:
        if pd is None:
            logging.error("pandas is not available; skipping CSV write.")
            return
        # ensure zip is normalized
        if data and 'zip_code' in data:
            data['zip_code'] = normalize_zip(data['zip_code'])

        # Clean price text again to ensure no "Price," or "—Est." text
        if data and 'list_price' in data and data['list_price']:
            data['list_price'] = clean_price_text(data['list_price'])

        df = pd.DataFrame([data])

        # Explicitly ensure dtype is string for zip_code column
        if 'zip_code' in df.columns:
            df['zip_code'] = df['zip_code'].astype(str).apply(lambda x: x.zfill(5) if x and x.isdigit() else x)

        if mode == "w":
            df.to_csv(CSV_PATH, index=False, columns=FIELDS)
        else:
            df.to_csv(CSV_PATH, mode=mode, header=False, index=False, columns=FIELDS)
        logging.info(f"Saved data for {data['property_url']} to CSV")
    except Exception as e:
        logging.error(f"Failed to write to CSV: {e}")


def save_batch_to_csv(data_list, mode="a"):
    """Save batch of scraped data to CSV file for better performance."""
    try:
        if pd is None:
            logging.error("pandas is not available; skipping batch CSV write.")
            return
        if not data_list:
            return

        # Process all data in the batch
        processed_data = []
        for data in data_list:
            if data:
                # Ensure zip is normalized
                if 'zip_code' in data:
                    data['zip_code'] = normalize_zip(data['zip_code'])

                # Clean price text
                if 'list_price' in data and data['list_price']:
                    data['list_price'] = clean_price_text(data['list_price'])

                processed_data.append(data)

        if not processed_data:
            return

        df = pd.DataFrame(processed_data)

        # Ensure zip_code column is properly formatted
        if 'zip_code' in df.columns:
            df['zip_code'] = df['zip_code'].astype(str).apply(lambda x: x.zfill(5) if x and x.isdigit() else x)

        if mode == "w":
            df.to_csv(CSV_PATH, index=False, columns=FIELDS)
        else:
            df.to_csv(CSV_PATH, mode=mode, header=False, index=False, columns=FIELDS)

        logging.info(f"Saved batch of {len(processed_data)} listings to CSV")
    except Exception as e:
        logging.error(f"Failed to write batch to CSV: {e}")


def main():
    """Main function to orchestrate the scraping process."""
    logging.info("Starting Redfin FSBO scraper.")

    target_domain = "https://www.redfin.com"

    # Create a direct session for sitemap requests
    direct_session = requests.Session()
    direct_session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
    })

    try:
        # Measure total runtime for throughput metrics
        overall_start = time.time()

        # First fetch sitemap URLs directly (no API Gateway)
        listing_urls = fetch_sitemap_urls(direct_session)
        logging.info(f"Found {len(listing_urls)} listings from sitemaps")

        if not listing_urls:
            logging.warning("No listing URLs found. Check if sitemap parsing worked correctly.")
            return

        # Now initialize API Gateway for individual property requests
        gateway = ApiGateway(target_domain, regions=["us-east-1", "us-west-2", "us-east-2", "eu-west-1"])
        gateway.start()
        logging.info("Started API Gateway for property page requests")

        # One session per thread (requests.Session is not thread-safe). Each thread gets
        # its own session mounted on the same gateway to avoid connection corruption.
        _tl = threading.local()
        def get_session():
            if not hasattr(_tl, "session"):
                s = requests.Session()
                s.mount(target_domain, gateway)
                s.headers.update({
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
                })
                _tl.session = s
            return _tl.session

        # Per-request jitter (seconds) to avoid bursts and improve data accuracy / reduce rate limits
        REQUEST_JITTER_MIN = 0.3
        REQUEST_JITTER_MAX = 1.2

        def scrape_one(url):
            time.sleep(random.uniform(REQUEST_JITTER_MIN, REQUEST_JITTER_MAX))
            return scrape_redfin_listing(url, get_session())

        # Shuffle the URLs to avoid sequential scraping patterns
        random.shuffle(listing_urls)
        if LISTING_IMPORT_LIMIT is not None:
            listing_urls = listing_urls[:LISTING_IMPORT_LIMIT]
            logging.info(f"Limited to {LISTING_IMPORT_LIMIT} listings (import limit).")

        is_first_run = True
        scraped_ok = 0
        supabase_saved = 0
        max_workers = 10
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = []
            for url in listing_urls:
                futures.append(executor.submit(scrape_one, url))

            for future in tqdm(futures, total=len(futures), desc="Scraping listings"):
                data = future.result()
                if data:
                    scraped_ok += 1
                    if _save_listing_result(data, "w" if is_first_run else "a"):
                        supabase_saved += 1
                    is_first_run = False

        total_duration = time.time() - overall_start
        listings_per_second = scraped_ok / total_duration if total_duration > 0 else 0

        summary_msg = (
            f"Scrape summary: {scraped_ok}/{len(listing_urls)} listings scraped successfully, "
            f"{supabase_saved} pushed to Supabase. "
            f"Total time: {total_duration:.2f}s, "
            f"Throughput: {listings_per_second:.2f} listings/second."
        )
        logging.info(summary_msg)
        print(summary_msg)

    except Exception as e:
        logging.error(f"An error occurred during scraping: {e}")
    finally:
        # Always shut down the gateway to avoid AWS charges
        try:
            if 'gateway' in locals():
                logging.info("Shutting down API Gateways...")
                gateway.shutdown()
                logging.info("API Gateways shut down.")
        except Exception as e:
            logging.error(f"Error shutting down API Gateway: {e}")


async def main_async(listing_limit=None, concurrency=None, batch_size=None, urls_file=None):
    """Async main function using aiohttp for high-performance scraping."""
    logging.info("Starting Redfin FSBO scraper (ASYNC MODE).")

    # Resolve async tuning parameters
    if concurrency is None:
        concurrency = DEFAULT_ASYNC_CONCURRENCY
    if batch_size is None:
        batch_size = DEFAULT_ASYNC_BATCH_SIZE

    # Determine URL source: file (step 1 output) or live sitemaps
    if urls_file:
        listing_urls = load_urls_from_file(urls_file)
    else:
        # Create a direct session for sitemap requests (still synchronous for sitemaps)
        direct_session = requests.Session()
        direct_session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
        })

        # Fetch listing URLs from sitemaps
        listing_urls = fetch_sitemap_urls(direct_session)
        logging.info(f"Found {len(listing_urls)} listings from sitemaps")

    if not listing_urls:
        logging.warning("No listing URLs found. Check if sitemap parsing worked correctly.")
        return

    # Apply explicit listing_limit (CLI/env) first, then legacy LISTING_IMPORT_LIMIT fallback
    effective_limit = listing_limit
    if effective_limit is None and LISTING_IMPORT_LIMIT is not None:
        effective_limit = LISTING_IMPORT_LIMIT
    if effective_limit is not None:
        listing_urls = listing_urls[:effective_limit]
        logging.info(f"Limited to {effective_limit} listings (import limit).")
    logging.info(f"Processing {len(listing_urls)} listings...")

    # Create aiohttp session with connection pooling
    connector = aiohttp.TCPConnector(
        limit=concurrency,  # Max concurrent connections
        ttl_dns_cache=300,
        keepalive_timeout=60,
        enable_cleanup_closed=True
    )

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Accept-Encoding": "gzip, deflate",
        "Connection": "keep-alive",
        "Upgrade-Insecure-Requests": "1",
    }

    try:
        async with aiohttp.ClientSession(
            connector=connector,
            headers=headers,
            timeout=aiohttp.ClientTimeout(total=30, sock_read=10)
        ) as session:

            # Shuffle URLs to avoid patterns
            random.shuffle(listing_urls)

            # Process in batches for memory efficiency
            total_processed = 0

            start_time = time.time()

            for i in range(0, len(listing_urls), batch_size):
                batch_urls = listing_urls[i:i + batch_size]
                batch_num = i//batch_size + 1
                total_batches = (len(listing_urls) + batch_size - 1) // batch_size

                logging.info(f"Processing batch {batch_num}/{total_batches} ({len(batch_urls)} URLs)")

                # Create async tasks for this batch
                tasks = [scrape_redfin_listing_async(url, session) for url in batch_urls]

                # Execute batch concurrently
                batch_results = await asyncio.gather(*tasks, return_exceptions=True)

                # Filter out exceptions and None results
                valid_results = []
                for j, result in enumerate(batch_results):
                    if isinstance(result, Exception):
                        logging.error(f"Batch {batch_num}, URL {j} failed: {result}")
                    elif result is not None:
                        valid_results.append(result)
                    else:
                        logging.debug(f"Batch {batch_num}, URL {j} returned None")

                total_processed += len(valid_results)
                success_rate = len(valid_results) / len(batch_urls) * 100

                logging.info(f"Batch {batch_num} completed: {len(valid_results)}/{len(batch_urls)} successful ({success_rate:.1f}%)")

                # Save batch results (CSV + fsbo_pagination in lockstep)
                if valid_results:
                    _save_listing_results_batch(valid_results, "w" if i == 0 else "a")

                # Small delay between batches to be respectful
                await asyncio.sleep(0.5)

            total_duration = time.time() - start_time
            listings_per_second = total_processed / total_duration if total_duration > 0 else 0

            logging.info("+" * 60)
            logging.info(f"ASYNC SCRAPING COMPLETED!")
            logging.info(f"Total listings processed: {total_processed}")
            logging.info(f"Total time: {total_duration:.2f} seconds")
            logging.info(f"Throughput: {listings_per_second:.2f} listings/second")
            logging.info("+" * 60)

    except Exception as e:
        logging.error(f"An error occurred during async scraping: {e}")
        raise


def _parse_async_cli_args(argv):
    """
    Lightweight parser for async CLI options.
    Supported:
      --limit=N
      --concurrency=N
      --batch-size=N
      --urls-file=PATH
    """
    listing_limit = None
    concurrency = None
    batch_size = None
    urls_file = None

    for arg in argv:
        if arg.startswith("--limit="):
            try:
                listing_limit = int(arg.split("=", 1)[1])
            except ValueError:
                logging.warning(f"Ignoring invalid --limit value: {arg}")
        elif arg.startswith("--concurrency="):
            try:
                concurrency = int(arg.split("=", 1)[1])
            except ValueError:
                logging.warning(f"Ignoring invalid --concurrency value: {arg}")
        elif arg.startswith("--batch-size="):
            try:
                batch_size = int(arg.split("=", 1)[1])
            except ValueError:
                logging.warning(f"Ignoring invalid --batch-size value: {arg}")
        elif arg.startswith("--urls-file="):
            urls_file = arg.split("=", 1)[1]

    return listing_limit, concurrency, batch_size, urls_file


def run_async_main():
    """Entry point for async scraping (configurable via CLI flags)."""
    # sys.argv[0] = script, [1] = --async, everything after is async config
    argv = sys.argv[2:] if len(sys.argv) > 2 else []
    listing_limit, concurrency, batch_size, urls_file = _parse_async_cli_args(argv)
    asyncio.run(
        main_async(
            listing_limit=listing_limit,
            concurrency=concurrency,
            batch_size=batch_size,
            urls_file=urls_file,
        )
    )


def run_amend_pagination(limit=5000, source_table="listings", missing_only=True, max_workers=20):
    """
    Load existing lead URLs from Supabase (listings or fsbo_leads), then concurrently
    scrape pagination for each and upsert into fsbo_pagination so every listing has both.
    """
    try:
        from supabase_client import get_listing_urls_for_pagination_backfill
    except ImportError as e:
        logging.error(f"Cannot run amend-pagination: supabase_client not available: {e}")
        return
    logging.info("Amending existing leads: backfilling fsbo_pagination so each listing has both.")
    rows = get_listing_urls_for_pagination_backfill(limit=limit, source_table=source_table, missing_only=missing_only)
    if not rows:
        logging.info("No listing URLs to amend (all may already have fsbo_pagination).")
        return
    urls = [r["property_url"] for r in rows]
    logging.info(f"Found {len(urls)} listing URLs to amend (missing_only={missing_only}).")
    amend_existing_leads_pagination(urls, session=None, max_workers=max_workers)


if __name__ == "__main__":
    # Choose which version to run
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--amend-pagination":
        run_amend_pagination()
    elif len(sys.argv) > 1 and sys.argv[1] == "--async":
        run_async_main()
    elif len(sys.argv) > 1 and sys.argv[1] == "--export-urls":
        # Optional second argument: custom export path
        export_path = URL_EXPORT_PATH
        if len(sys.argv) > 2:
            export_path = sys.argv[2]
        export_listing_urls(export_path)
    else:
        main()
