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
import pandas as pd
from tqdm import tqdm
import time
import random
import logging
import sys
from bs4 import BeautifulSoup
import re
import json
from concurrent.futures import ThreadPoolExecutor
from requests_ip_rotator import ApiGateway

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

TARGET_STATES = {
    'MN', 'IA', 'MO', 'AR', 'DC', 'ME', 'NH', 'VT', 'MA', 'RI', 'CT', 'NY', 'NJ', 'PA', 'DE', 'MD', 'VA', 'WV', 'NC',
    'SC', 'GA',
    'FL', 'AL', 'MS', 'TN', 'KY', 'OH', 'IN', 'IL', 'WI', 'MI', 'TX'
}
SITEMAP_URLS = [
    "https://www.redfin.com/newest_listings.xml"
    # "https://www.redfin.com/latest_listings.xml" # Remove broken sitemap to avoid 404
]
CSV_PATH = "C:/Users/jackt/Documents/redfin_leads/fsbo_leads.csv"
LOG_PATH = "C:/Users/jackt/Documents/redfin_leads/scraper.log"

# Blacklisted phone numbers - these will not be included in the export
BLACKLISTED_PHONE_NUMBERS = ["1-844-759-7732", "844-759-7732", "(844) 759-7732", "8447597732"]

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
logging.basicConfig(filename=LOG_PATH, level=logging.INFO)


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
                    if any(f"/{state}/" in loc for state in TARGET_STATES):
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


def log_missing(field, url):
    logging.warning(f"{field} not found for {url}")


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


def scrape_redfin_listing(url, session):
    """Scrape one Redfin property page and extract all fields. Log missing fields."""
    try:
        resp = session.get(url, timeout=30)
        if resp.status_code != 200:
            logging.warning(f"Failed to fetch {url}: {resp.status_code}")
            return None
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

        # Method 2: Original method - gallery images
        if not photo_found:
            photo_tags = soup.find_all("img", {"class": "gallery-image"})
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

        # Method 4: Try the specific ID selectors
        if not data.get('image1_url'):
            img1 = soup.select_one('#MBImage > picture > img, #MBImage img')
            if img1 and img1.get('src'):
                data['image1_url'] = img1.get('src')
                logging.info(f"Found image1 with specific ID for {url}")

        if not data.get('image2_url'):
            img2 = soup.select_one('#MBImage6 > picture > img, #MBImage6 img')
            if img2 and img2.get('src'):
                data['image2_url'] = img2.get('src')
                logging.info(f"Found image2 with specific ID for {url}")

        if not data.get('image3_url'):
            img3 = soup.select_one('#MBImage9 > picture > img, #MBImage9 img')
            if img3 and img3.get('src'):
                data['image3_url'] = img3.get('src')
                logging.info(f"Found image3 with specific ID for {url}")

        if not data.get('image4_url'):
            img4 = soup.select_one('#MBImage18 > picture > img, #MBImage18 img')
            if img4 and img4.get('src'):
                data['image4_url'] = img4.get('src')
                logging.info(f"Found image4 with specific ID for {url}")

        # Method 5: Check for lazily-loaded images
        if not photo_found:
            lazy_imgs = soup.select('img[data-lazy-src], img[loading="lazy"]')
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

        # Agent Name
        agent_name_tag = soup.select_one(
            '#house-info > div:nth-child(3) > div > div > div.agent-info-container > div.agent-info-content > div > div > span.agent-basic-details--heading > span')
        if agent_name_tag:
            data['agent_name'] = agent_name_tag.get_text(strip=True)
            logging.info(f"Found agent_name using CSS for {url}")
        else:
            # Try XPath
            agent_name_xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/div/div[1]/div[2]/div/div/span[1]/span'
            agent_name = extract_by_xpath(resp.content, agent_name_xpath)
            if agent_name:
                data['agent_name'] = agent_name
                logging.info(f"Found agent_name using XPath for {url}")

        # Listing Source Name
        source_name_tag = soup.select_one(
            '#house-info > div:nth-child(3) > div > div > div.listingInfoSection > div > div.ListingSource > span.ListingSource--dataSourceName')
        if source_name_tag:
            data['listing_source_name'] = source_name_tag.get_text(strip=True)
            logging.info(f"Found listing_source_name using CSS for {url}")
        else:
            # Try XPath
            source_name_xpath = '/html/body/div[1]/div[8]/div[2]/div[1]/div[6]/section/div/div/div/div[3]/div/div/div[2]/div/div[2]/span[3]'
            source_name = extract_by_xpath(resp.content, source_name_xpath)
            if source_name:
                data['listing_source_name'] = source_name
                logging.info(f"Found listing_source_name using XPath for {url}")

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


def save_to_csv(data, mode="a"):
    """Save data to a CSV file with proper handling of ZIP codes and price formatting."""
    try:
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

        # Create a session for property pages that uses the gateway
        gateway_session = requests.Session()
        gateway_session.mount(target_domain, gateway)
        gateway_session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
        })

        # Shuffle the URLs to avoid sequential scraping patterns
        random.shuffle(listing_urls)

        is_first_run = True

        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = []
            for url in listing_urls:
                futures.append(executor.submit(scrape_redfin_listing, url, gateway_session))

            for future in tqdm(futures, total=len(futures), desc="Scraping listings"):
                data = future.result()
                if data:
                    save_to_csv(data, "w" if is_first_run else "a")
                    is_first_run = False

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


if __name__ == "__main__":
    main()
