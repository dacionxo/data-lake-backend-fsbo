"""
World-Class Skip Tracing Engine - TruePeopleSearch + AWS IP Rotation (FINAL FIX)

- Uses 'address' column for streetaddress and separate city/state/zip columns.
- Correct URL format: /resultaddress?streetaddress=...&citystatezip=City,%20ST%20ZIP
- Fixed logging setup (defines formatters properly).

Author: Built for dacionxo
Date: 2025-10-29
"""

# --- Standard Library Imports ---
import asyncio
import logging
import re
import urllib.parse
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

# --- Third-Party Imports ---
import pandas as pd
from playwright.async_api import async_playwright, Page
from bs4 import BeautifulSoup
from tqdm.asyncio import tqdm_asyncio

# --- Local Application Imports ---
from supabase_client import save_lead_to_supabase

# --- AWS PROXY CONFIGURATION ---
AWS_PROXY_ENDPOINT = "https://ghpab8ll90.execute-api.us-east-2.amazonaws.com/default/aws_lamda_proxy"

# --- Global Configuration ---
CSV_PATH = "C:/Users/jackt/Documents/redfin_leads/fsbo_leads.csv"
ENRICHED_CSV_PATH = "C:/Users/jackt/Documents/redfin_leads/fsbo_leads_enriched.csv"
LOG_PATH = "C:/Users/jackt/Documents/redfin_leads/scraper.log"
DEBUG_DIR = "C:/Users/jackt/Documents/redfin_leads/debug_truepeoplesearch"
CONCURRENCY_LIMIT = 8
USE_AWS_ROTATION = True  # Set to False to disable AWS proxy and use direct connections only
SAVE_DEBUG_SAMPLES = True
MAX_DEBUG_SAMPLES = 5

# --- Logging Setup ---
def setup_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    # Clear existing handlers to avoid duplicates
    if logger.hasHandlers():
        logger.handlers.clear()

    # Define formatters (FIX)
    file_formatter = logging.Formatter('%(asctime)s - %(levelname)-8s - %(message)s')
    console_formatter = logging.Formatter('%(levelname)-8s: %(message)s')

    # File handler
    file_handler = logging.FileHandler(LOG_PATH, mode='w', encoding='utf-8')
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)

    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    # Quiet noisy libs
    for lib in ["httpx", "httpcore", "playwright"]:
        logging.getLogger(lib).setLevel(logging.WARNING)

    # Ensure debug directory exists
    if SAVE_DEBUG_SAMPLES:
        Path(DEBUG_DIR).mkdir(parents=True, exist_ok=True)

setup_logging()

debug_sample_count = 0

# --- Address Parsing Functions ---

def parse_full_address(address_string: str) -> Dict[str, Optional[str]]:
    """
    Parse a full address string into components: street, city, state, zipcode.

    Handles formats like:
    - "123 Main St, City, ST 12345"
    - "123 Main St, City, ST"
    - "123 Main St City ST 12345"
    - "123 Main St, City, State 12345"

    Returns dict with keys: 'street', 'city', 'state', 'zip_code'
    """
    if not address_string or not address_string.strip():
        return {'street': None, 'city': None, 'state': None, 'zip_code': None}

    address = address_string.strip()
    result = {'street': None, 'city': None, 'state': None, 'zip_code': None}

    # Pattern 1: "Street, City, ST ZIP" or "Street, City, ST"
    # Matches: "123 Main St, New York, NY 10001" or "123 Main St, New York, NY"
    pattern1 = r'^(.+?),\s*([^,]+),\s*([A-Z]{2})(?:\s+(\d{5}(?:-\d{4})?))?$'
    match = re.match(pattern1, address, re.IGNORECASE)
    if match:
        result['street'] = match.group(1).strip()
        result['city'] = match.group(2).strip()
        result['state'] = match.group(3).strip().upper()
        result['zip_code'] = match.group(4).strip() if match.group(4) else None
        return result

    # Pattern 2: "Street City ST ZIP" (no commas)
    # Matches: "123 Main St New York NY 10001"
    pattern2 = r'^(.+?)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+([A-Z]{2})\s+(\d{5}(?:-\d{4})?)$'
    match = re.match(pattern2, address, re.IGNORECASE)
    if match:
        # Extract street (everything before the last state abbreviation)
        # This is tricky - we need to find where city starts
        # Try to find a pattern like "Street City ST ZIP"
        parts = address.split()
        if len(parts) >= 4:
            # Look for state abbreviation (2 letters)
            state_idx = None
            for i in range(len(parts) - 1, 0, -1):
                if len(parts[i]) == 2 and parts[i].isalpha():
                    state_idx = i
                    break

            if state_idx and state_idx > 1:
                # Everything before city is street
                city_start = state_idx - 1
                result['street'] = ' '.join(parts[:city_start]).strip()
                result['city'] = parts[city_start].strip()
                result['state'] = parts[state_idx].strip().upper()
                if state_idx + 1 < len(parts):
                    result['zip_code'] = parts[state_idx + 1].strip()
                return result

    # Pattern 3: "Street, City, State ZIP" (full state name)
    # Matches: "123 Main St, New York, New York 10001"
    pattern3 = r'^(.+?),\s*([^,]+),\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(\d{5}(?:-\d{4})?)$'
    match = re.match(pattern3, address, re.IGNORECASE)
    if match:
        result['street'] = match.group(1).strip()
        result['city'] = match.group(2).strip()
        # Try to convert full state name to abbreviation (basic list)
        state_name = match.group(3).strip()
        state_abbr = convert_state_name_to_abbr(state_name)
        result['state'] = state_abbr if state_abbr else state_name.upper()
        result['zip_code'] = match.group(4).strip() if match.group(4) else None
        return result

    # If no pattern matches, try to extract zip code at the end
    # Pattern: ends with "ST ZIP" or just "ZIP"
    zip_pattern = r'\b(\d{5}(?:-\d{4})?)\s*$'
    zip_match = re.search(zip_pattern, address)
    if zip_match:
        result['zip_code'] = zip_match.group(1).strip()
        # Remove zip from address
        address = re.sub(zip_pattern, '', address).strip()

    # Try to extract state abbreviation (2 letters) before zip
    state_pattern = r'\b([A-Z]{2})\s+(?=\d{5})'
    state_match = re.search(state_pattern, address)
    if state_match:
        result['state'] = state_match.group(1).upper()
        # Remove state from address
        address = re.sub(state_pattern, '', address).strip()

    # Whatever is left is likely street + city
    # Try to split by comma if present
    if ',' in address:
        parts = [p.strip() for p in address.split(',')]
        if len(parts) >= 2:
            result['street'] = parts[0].strip()
            result['city'] = parts[-1].strip()
        else:
            result['street'] = address
    else:
        # No comma - everything is street
        result['street'] = address

    return result


def convert_state_name_to_abbr(state_name: str) -> Optional[str]:
    """Convert full state name to abbreviation."""
    state_map = {
        'alabama': 'AL', 'alaska': 'AK', 'arizona': 'AZ', 'arkansas': 'AR', 'california': 'CA',
        'colorado': 'CO', 'connecticut': 'CT', 'delaware': 'DE', 'florida': 'FL', 'georgia': 'GA',
        'hawaii': 'HI', 'idaho': 'ID', 'illinois': 'IL', 'indiana': 'IN', 'iowa': 'IA',
        'kansas': 'KS', 'kentucky': 'KY', 'louisiana': 'LA', 'maine': 'ME', 'maryland': 'MD',
        'massachusetts': 'MA', 'michigan': 'MI', 'minnesota': 'MN', 'mississippi': 'MS', 'missouri': 'MO',
        'montana': 'MT', 'nebraska': 'NE', 'nevada': 'NV', 'new hampshire': 'NH', 'new jersey': 'NJ',
        'new mexico': 'NM', 'new york': 'NY', 'north carolina': 'NC', 'north dakota': 'ND', 'ohio': 'OH',
        'oklahoma': 'OK', 'oregon': 'OR', 'pennsylvania': 'PA', 'rhode island': 'RI', 'south carolina': 'SC',
        'south dakota': 'SD', 'tennessee': 'TN', 'texas': 'TX', 'utah': 'UT', 'vermont': 'VT',
        'virginia': 'VA', 'washington': 'WA', 'west virginia': 'WV', 'wisconsin': 'WI', 'wyoming': 'WY',
        'district of columbia': 'DC'
    }
    return state_map.get(state_name.lower())


# --- CORRECTED URL Builder ---

def build_truepeoplesearch_url(address: str, city: str, state: str, zip_code: str) -> str:
    """
    Builds a TruePeopleSearch URL using address data from CSV.
    This function ONLY creates TruePeopleSearch URLs - it does NOT use property_url or any Redfin URLs.

    Parameters:
      - address: Street address from CSV (e.g., "3424 Firestone #155")
      - city: City from CSV
      - state: State from CSV
      - zip_code: ZIP code from CSV

    Returns:
      - Fully encoded TruePeopleSearch URL (https://www.truepeoplesearch.com/resultaddress?...)
    """
    if not all([address, city, state]):
        raise ValueError("Address, city, and state are required")

    street_address = address.strip()
    city_state_zip = f"{city}, {state} {zip_code}".strip()

    params = {
        'streetaddress': street_address,
        'citystatezip': city_state_zip
    }

    encoded_params = urllib.parse.urlencode(params)
    # HARDCODED: Always use TruePeopleSearch base URL - never Redfin or other sites
    base_url = "https://www.truepeoplesearch.com/resultaddress"
    return f"{base_url}?{encoded_params}"


# --- AWS Proxy Integration ---

async def fetch_via_aws_proxy(page: Page, url: str) -> bool:
    """
    Fetches URL through AWS Lambda for IP rotation.
    
    Returns True if successful, False if failed (403, timeout, etc.)
    The caller should handle fallback to direct connection.
    """
    # Validate URL is TruePeopleSearch before proxying
    if 'truepeoplesearch.com' not in url.lower():
        logging.error(f"AWS Proxy: Refusing to proxy non-TruePeopleSearch URL: {url}")
        return False

    try:
        encoded_url = urllib.parse.quote(url, safe='')
        proxy_url = f"{AWS_PROXY_ENDPOINT}?url={encoded_url}"
        logging.debug(f"AWS routing TruePeopleSearch URL: {url}")
        
        # Use 'load' instead of 'domcontentloaded' for better reliability
        response = await page.goto(proxy_url, timeout=90000, wait_until="load")
        
        if response:
            status = response.status
            if status == 200:
                # Verify final URL is still TruePeopleSearch
                final_url = response.url
                if 'truepeoplesearch.com' not in final_url.lower():
                    logging.warning(f"AWS Proxy redirected away from TruePeopleSearch! Final: {final_url}")
                    return False
                # Wait for content to load
                await page.wait_for_timeout(3000)
                return True
            else:
                if status == 403:
                    logging.debug(f"AWS Proxy returned 403 Forbidden - will fallback to direct connection")
                elif status == 429:
                    logging.debug(f"AWS Proxy returned 429 Too Many Requests - will fallback to direct connection")
                elif status == 502 or status == 503:
                    logging.debug(f"AWS Proxy returned {status} (Bad Gateway/Service Unavailable) - will fallback to direct connection")
                else:
                    logging.debug(f"AWS Proxy returned status {status} - will fallback to direct connection")
                return False
        else:
            logging.debug(f"AWS Proxy returned no response - will fallback to direct connection")
            return False
    except Exception as e:
        error_msg = str(e).lower()
        if 'timeout' in error_msg:
            logging.debug(f"AWS Proxy timeout - will fallback to direct connection")
        else:
            logging.warning(f"AWS Proxy error for TruePeopleSearch URL: {e}")
        return False


# --- TruePeopleSearch Data Parser ---

class TruePeopleSearchParser:
    """Parser for TruePeopleSearch.com HTML structure."""

    @staticmethod
    def safe_text(element) -> str:
        if not element:
            return ""
        return element.get_text(strip=True) if hasattr(element, 'get_text') else str(element).strip()

    @staticmethod
    def extract_by_xpath(html_content: str, xpath_expression: str) -> Optional[str]:
        """Extract text using XPath expression."""
        try:
            from lxml import html
            tree = html.fromstring(html_content.encode('utf-8'))
            elements = tree.xpath(xpath_expression)
            if elements:
                if hasattr(elements[0], 'text_content'):
                    return elements[0].text_content().strip()
                elif isinstance(elements[0], str):
                    return elements[0].strip()
        except ImportError:
            logging.debug("lxml not available for XPath extraction")
        except Exception as e:
            logging.debug(f"XPath extraction error: {e}")
        return None

    @staticmethod
    def normalize_phone(phone: str) -> str:
        if not phone:
            return ""
        digits = re.sub(r'\D', '', phone)
        if len(digits) == 10:
            return f"({digits[:3]}) {digits[3:6]}-{digits[6:]}"
        elif len(digits) == 11 and digits[0] == '1':
            return f"({digits[1:4]}) {digits[4:7]}-{digits[7:]}"
        return phone.strip()

    @classmethod
    def extract_resident_data(cls, soup: BeautifulSoup, target_address: str) -> Dict:
        """Extracts resident information from TruePeopleSearch results."""
        data = {}

        try:
            person_cards = soup.select('div.card, div.card-block, div.shadow, div[class*="result"]')
            if not person_cards:
                logging.warning("No person cards found")
                return data

            target_street_number = ""
            if target_address:
                match = re.match(r'^(\d+)', target_address.strip())
                if match:
                    target_street_number = match.group(1)

            matched_card = None
            for card in person_cards:
                address_sections = card.select('a[href*="address"], div.detail-box, p, span')
                for elem in address_sections:
                    elem_text = cls.safe_text(elem).lower()
                    if target_street_number and target_street_number in elem_text:
                        matched_card = card
                        break
                if matched_card:
                    break

            working_card = matched_card if matched_card else person_cards[0]
            if not working_card:
                return data

            # Full name
            for selector in ['h2', 'h3', 'a[data-link-to-more]', '.h4', '[class*="name"]', 'strong']:
                name_elem = working_card.select_one(selector)
                if name_elem:
                    name_text = cls.safe_text(name_elem)
                    name_text = re.sub(r'\s*,?\s*age\s+\d+', '', name_text, flags=re.I)
                    name_text = re.sub(r'\s*\(\d+\)', '', name_text)
                    name_text = re.sub(r'\s*\d+\s*$', '', name_text)
                    if name_text and len(name_text) > 2:
                        data['full_name'] = name_text
                        break

            # Age
            card_text = working_card.get_text()
            for pattern in [r'\bage[:\s]+(\d+)', r'\((\d+)\)', r'(\d+)\s*years?\s*old']:
                age_match = re.search(pattern, card_text, re.I)
                if age_match:
                    age_value = age_match.group(1)
                    if age_value.isdigit() and 18 <= int(age_value) <= 120:
                        data['age'] = age_value
                        break

            # AKA
            aka_indicators = working_card.find_all(string=re.compile(r'\bAKA\b|\bAlso Known As\b', re.I))
            for indicator in aka_indicators:
                parent = indicator.find_parent(['div', 'p', 'span', 'li'])
                if parent:
                    aka_text = cls.safe_text(parent)
                    aka_text = re.sub(r'\b(AKA|Also Known As):?\s*', '', aka_text, flags=re.I).strip()
                    if aka_text and aka_text != data.get('full_name', ''):
                        data['other_observed_names'] = aka_text
                        break

            # Relatives
            relatives_indicators = working_card.find_all(string=re.compile(r'\b(Relatives?|Related\s+to|Associated)\b', re.I))
            for indicator in relatives_indicators:
                parent = indicator.find_parent(['div', 'section', 'ul', 'p'])
                if parent:
                    rel_links = parent.select('a, span, li')
                    relatives = []
                    for rel_elem in rel_links:
                        rel_text = cls.safe_text(rel_elem)
                        if rel_text and len(rel_text.split()) >= 2:
                            if rel_text[0].isupper() and rel_text != data.get('full_name', ''):
                                relatives.append(rel_text)
                    if relatives:
                        data['relatives'] = ", ".join(relatives[:10])
                        break

            # Phones
            phones_found = []
            phone_types = []

            phone_links = working_card.select('a[href^="tel:"]')
            for phone_link in phone_links:
                phone_text = cls.safe_text(phone_link)
                normalized = cls.normalize_phone(phone_text)
                if normalized and normalized not in phones_found:
                    phones_found.append(normalized)
                    phone_type = ""
                    title = phone_link.get('title', '').lower()
                    parent_text = phone_link.parent.get_text().lower() if phone_link.parent else ""
                    type_keywords = {
                        'Wireless': ['wireless', 'mobile', 'cell'],
                        'Landline': ['landline', 'home'],
                        'VoIP': ['voip', 'internet']
                    }
                    for phone_type_name, keywords in type_keywords.items():
                        if any(kw in title or kw in parent_text for kw in keywords):
                            phone_type = phone_type_name
                            break
                    phone_types.append(phone_type)

            if len(phones_found) >= 1:
                data['resident_phone_number'] = phones_found[0]
                if phone_types and phone_types[0]:
                    data['resident_phone_number_type'] = phone_types[0]
            if len(phones_found) >= 2:
                data['other_resident_phone_number'] = phones_found[1]

        except Exception as e:
            logging.error(f"Extraction error: {e}")

        return data

    @classmethod
    def extract_property_data(cls, soup: BeautifulSoup, html_content: str) -> Dict:
        """Extract property information using XPaths, CSS selectors, and text-based fallbacks."""
        data = {}

        # Field mappings: (field_name, label_text, xpath, css_selector, alternative_selectors)
        property_fields = [
            ('estimated_value', 'Estimated Value',
             '/html/body/div[2]/div/div[2]/div[5]/div[2]/div[1]/b',
             'body > div:nth-child(2) > div > div.content-center > div.card.card-body.shadow-form.pt-3.mb-4.mt-3 > div:nth-child(2) > div:nth-child(1) > b',
             ['div.card-body b', 'div.shadow-form b']),
            ('estimated_equity', 'Estimated Equity',
             '/html/body/div[2]/div/div[2]/div[5]/div[2]/div[2]/b',
             'body > div:nth-child(2) > div > div.content-center > div.card.card-body.shadow-form.pt-3.mb-4.mt-3 > div:nth-child(2) > div:nth-child(2) > b',
             ['div.card-body b']),
            ('last_sale_date', 'Last Sale Date',
             '/html/body/div[2]/div/div[2]/div[5]/div[2]/div[4]/b',
             'body > div:nth-child(2) > div > div.content-center > div.card.card-body.shadow-form.pt-3.mb-4.mt-3 > div:nth-child(2) > div:nth-child(4) > b',
             ['div.card-body b']),
            ('last_sale_amount', 'Last Sale Amount',
             '/html/body/div[2]/div/div[2]/div[5]/div[2]/div[3]/b',
             'body > div:nth-child(2) > div > div.content-center > div.card.card-body.shadow-form.pt-3.mb-4.mt-3 > div:nth-child(2) > div:nth-child(3) > b',
             ['div.card-body b']),
            ('year_built_enriched', 'Year Built',  # Maps to Year_Built in Supabase
             '/html/body/div[2]/div/div[2]/div[5]/div[1]/div[4]/b',
             'body > div:nth-child(2) > div > div.content-center > div.card.card-body.shadow-form.pt-3.mb-4.mt-3 > div:nth-child(1) > div:nth-child(4) > b',
             ['div.card-body b']),
            ('ownership_type', 'Ownership Type',
             '/html/body/div[2]/div/div[2]/div[5]/div[3]/div[2]/b',
             'body > div:nth-child(2) > div > div.content-center > div.card.card-body.shadow-form.pt-3.mb-4.mt-3 > div:nth-child(3) > div:nth-child(2) > b',
             ['div.card-body b']),
            ('occupancy_type', 'Occupancy Type',
             '/html/body/div[2]/div/div[2]/div[5]/div[3]/div[1]/b',
             'body > div:nth-child(2) > div > div.content-center > div.card.card-body.shadow-form.pt-3.mb-4.mt-3 > div:nth-child(3) > div:nth-child(1) > b',
             ['div.card-body b']),
            ('property_class', 'Property Class',
             '/html/body/div[2]/div/div[2]/div[5]/div[3]/div[4]/b',
             'body > div:nth-child(2) > div > div.content-center > div.card.card-body.shadow-form.pt-3.mb-4.mt-3 > div:nth-child(3) > div:nth-child(4) > b',
             ['div.card-body b']),
            ('land_use', 'Land Use',
             '/html/body/div[2]/div/div[2]/div[5]/div[3]/div[3]/b',
             'body > div:nth-child(2) > div > div.content-center > div.card.card-body.shadow-form.pt-3.mb-4.mt-3 > div:nth-child(3) > div:nth-child(3) > b',
             ['div.card-body b']),
        ]

        # First, try to find the property card section to verify page structure
        property_card = soup.select_one('div.card.card-body.shadow-form, div.shadow-form, div.card-body')
        if not property_card:
            logging.debug("Property card section not found - page structure may be different")
            # Try to find any property-related content
            if 'estimated value' not in soup.get_text().lower():
                logging.debug("No property data indicators found in page")
                return data

        for field_name, label_text, xpath, css_selector, alt_selectors in property_fields:
            value = None

            # Method 1: Try primary CSS selector first
            try:
                element = soup.select_one(css_selector)
                if element:
                    value = cls.safe_text(element)
                    if value and value.lower() not in ['n/a', 'na', 'not available', '']:
                        logging.debug(f"Found {field_name} using CSS selector: {value}")
            except Exception as e:
                logging.debug(f"CSS selector error for {field_name}: {e}")

            # Method 2: Try XPath if CSS didn't work
            if not value:
                try:
                    value = cls.extract_by_xpath(html_content, xpath)
                    if value and value.lower() not in ['n/a', 'na', 'not available', '']:
                        logging.debug(f"Found {field_name} using XPath: {value}")
                except Exception as e:
                    logging.debug(f"XPath error for {field_name}: {e}")

            # Method 3: Text-based fallback - search by label text
            if not value:
                try:
                    # Find element containing the label text, then get the following <b> tag
                    label_elements = soup.find_all(string=re.compile(label_text, re.I))
                    for label_elem in label_elements:
                        parent = label_elem.find_parent(['div', 'p', 'span'])
                        if parent:
                            # Look for <b> tag in the same parent or next sibling
                            bold_elem = parent.find('b')
                            if bold_elem:
                                value = cls.safe_text(bold_elem)
                                if value and value.lower() not in ['n/a', 'na', 'not available', '']:
                                    logging.debug(f"Found {field_name} using text-based search: {value}")
                                    break
                except Exception as e:
                    logging.debug(f"Text-based search error for {field_name}: {e}")

            # Method 4: Try alternative CSS selectors
            if not value:
                for alt_selector in alt_selectors:
                    try:
                        elements = soup.select(alt_selector)
                        for elem in elements:
                            # Check if this element is near the label text
                            parent_text = elem.find_parent().get_text() if elem.find_parent() else ''
                            if label_text.lower() in parent_text.lower():
                                value = cls.safe_text(elem)
                                if value and value.lower() not in ['n/a', 'na', 'not available', '']:
                                    logging.debug(f"Found {field_name} using alternative selector: {value}")
                                    break
                        if value:
                            break
                    except Exception as e:
                        logging.debug(f"Alternative selector error for {field_name}: {e}")
                        continue

            # Clean and store the value
            if value:
                value = value.strip()
                # Skip if it's clearly not valid data
                if value.lower() in ['n/a', 'na', 'not available', '', 'none']:
                    value = None
                else:
                    # Clean price values (remove $, commas, but keep decimal points)
                    if field_name in ['estimated_value', 'estimated_equity', 'last_sale_amount']:
                        # Remove currency symbols and formatting, keep numbers and decimal point
                        cleaned = re.sub(r'[^\d.]', '', value)
                        # Only store if we have digits
                        if cleaned and re.search(r'\d', cleaned):
                            value = cleaned
                        else:
                            value = None
                    # Clean year_built - ensure it's a valid year
                    elif field_name == 'year_built_enriched':
                        # Extract year digits (should be 4 digits)
                        year_match = re.search(r'\b(19|20)\d{2}\b', value)
                        if year_match:
                            value = year_match.group(0)
                        else:
                            value = None
                    # Clean date values - keep as is, will be parsed by supabase_client
                    elif field_name == 'last_sale_date':
                        # Keep as is, will be parsed by supabase_client
                        pass

                    # Only add to data if value is not None
                    if value is not None:
                        data[field_name] = value

        return data

    @classmethod
    def extract_all(cls, html_content: str, lead_data: Dict) -> Dict:
        """Main extraction method."""
        if not html_content:
            logging.debug("Empty HTML content")
            return {}
        soup = BeautifulSoup(html_content, 'html.parser')
        page_text = soup.get_text().lower()
        if any(kw in page_text for kw in ['captcha', 'robot', 'access denied']):
            logging.warning("Blocking detected in TruePeopleSearch response")
            return {}
        if 'no results found' in page_text or 'we found 0' in page_text:
            logging.debug("TruePeopleSearch returned no results")
            return {}
        target_address = lead_data.get('address', '')

        # Extract both resident data and property data
        resident_data = cls.extract_resident_data(soup, target_address)
        property_data = cls.extract_property_data(soup, html_content)

        # Log what each extraction found
        if resident_data:
            logging.debug(f"Resident data extracted: {list(resident_data.keys())}")
        if property_data:
            logging.debug(f"Property data extracted: {list(property_data.keys())}")

        # Merge both datasets
        combined_data = {**resident_data, **property_data}
        return combined_data


# --- Main Task ---

async def enrich_lead_task(lead_data: Dict, browser, semaphore, stats: Dict):
    """
    Enriches a single lead by scraping TruePeopleSearch.com.

    IMPORTANT: This function ONLY scrapes TruePeopleSearch.com using the address from the CSV.
    It does NOT scrape Redfin URLs or property_url from the CSV.
    """
    global debug_sample_count

    async with semaphore:
        page, context = None, None
        property_url = lead_data.get('property_url', 'Unknown')  # Only used for logging/reference

        try:
            # Step 1: Try to extract separate columns first (fallback approach)
            city = None
            for key in ['city', 'City', 'CITY']:
                value = lead_data.get(key, '')
                if value and str(value).strip():
                    city = str(value).strip()
                    break
            if not city:
                city = ''

            state = None
            for key in ['state', 'State', 'STATE']:
                value = lead_data.get(key, '')
                if value and str(value).strip():
                    state = str(value).strip()
                    break
            if not state:
                state = ''

            zip_code = None
            for key in ['zip_code', 'zip', 'Zip', 'ZIP', 'zipcode', 'ZipCode', 'ZIPCODE']:
                value = lead_data.get(key, '')
                if value and str(value).strip():
                    zip_code = str(value).strip()
                    break
            if not zip_code:
                zip_code = ''

            # Step 2: Extract address/street column
            address = None
            address_source = None
            full_address_string = None

            # First try common exact matches
            for key in ['address', 'street', 'Address', 'Street', 'ADDRESS', 'STREET']:
                value = lead_data.get(key, '')
                if value and str(value).strip():
                    full_address_string = str(value).strip()
                    address_source = key
                    break

            # Also check case-insensitive by iterating through all keys
            if not full_address_string:
                for key, value in lead_data.items():
                    if key and value and key.lower() in ['address', 'street']:
                        full_address_string = str(value).strip()
                        if full_address_string:
                            address_source = key
                            break

            # Step 3: Parse the address string
            # If we have separate columns (city, state), use them and extract street from address
            # If we don't have separate columns, try to parse the full address string
            if full_address_string:
                if city and state:
                    # We have separate city/state columns, so address column is likely just street
                    address = full_address_string
                    logging.debug(f"Using separate columns: Street='{address[:50]}...', City='{city}', State='{state}'")
                else:
                    # Try to parse full address string into components
                    parsed = parse_full_address(full_address_string)
                    logging.debug(f"Parsed full address from '{address_source}': {parsed}")

                    # Use parsed values if separate columns don't exist
                    if parsed['street']:
                        address = parsed['street']
                    if not city and parsed['city']:
                        city = parsed['city']
                    if not state and parsed['state']:
                        state = parsed['state']
                    if not zip_code and parsed['zip_code']:
                        zip_code = parsed['zip_code']

                    logging.debug(f"After parsing: Street='{address}', City='{city}', State='{state}', Zip='{zip_code}'")
            else:
                address = ''

            # Log what we found for debugging
            if address:
                logging.debug(f"Final address components - Street: '{address[:50]}...', City: '{city}', State: '{state}', Zip: '{zip_code}'")
            else:
                logging.warning(f"No address found in CSV. Available columns: {list(lead_data.keys())}")

            if not all([address, city, state]):
                missing_fields = []
                if not address:
                    missing_fields.append('address/street')
                if not city:
                    missing_fields.append('city')
                if not state:
                    missing_fields.append('state')
                logging.warning(f"Skipping (missing {', '.join(missing_fields)}): {property_url}")
                stats['skipped'] += 1
                return lead_data

            # Update lead_data with address for consistency
            if not lead_data.get('address') and address:
                lead_data['address'] = address

            # Build TruePeopleSearch URL from address data (NOT from property_url)
            try:
                search_url = build_truepeoplesearch_url(address, city, state, zip_code)
                # Validate that we're using TruePeopleSearch, not Redfin or other sites
                if 'truepeoplesearch.com' not in search_url.lower():
                    logging.error(f"ERROR: Generated URL is not TruePeopleSearch! URL: {search_url}")
                    stats['failed'] += 1
                    return lead_data
                logging.info(f"TruePeopleSearch URL: {search_url} (for property: {property_url})")
            except ValueError as e:
                logging.error(f"URL error for {property_url}: {e}")
                stats['skipped'] += 1
                return lead_data

            # Create browser context with realistic headers to avoid detection
            context = await browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                viewport={'width': 1920, 'height': 1080},
                locale='en-US',
                timezone_id='America/New_York',
                extra_http_headers={
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.9',
                    'Accept-Encoding': 'gzip, deflate, br',
                    'Connection': 'keep-alive',
                    'Upgrade-Insecure-Requests': '1',
                    'Sec-Fetch-Dest': 'document',
                    'Sec-Fetch-Mode': 'navigate',
                    'Sec-Fetch-Site': 'none',
                    'Cache-Control': 'max-age=0'
                }
            )
            page = await context.new_page()

            # Ensure we're only navigating to TruePeopleSearch URLs
            if 'truepeoplesearch.com' not in search_url.lower():
                logging.error(f"CRITICAL: Refusing to navigate to non-TruePeopleSearch URL: {search_url}")
                stats['failed'] += 1
                return lead_data

            # Try AWS proxy first if enabled, with fallback to direct connection
            # Use retry logic with exponential backoff
            fetch_success = False
            max_retries = 2
            retry_delay = 1000  # Start with 1 second
            
            for attempt in range(max_retries):
                try:
                    if USE_AWS_ROTATION and attempt == 0:
                        # First attempt: try AWS proxy
                        success = await fetch_via_aws_proxy(page, search_url)
                        if success:
                            fetch_success = True
                            logging.debug(f"Successfully fetched via AWS proxy for {property_url}")
                            break
                        else:
                            # AWS proxy failed, try direct connection
                            logging.debug(f"AWS proxy failed (attempt {attempt + 1}), trying direct connection for {property_url}")
                            await page.wait_for_timeout(retry_delay)
                    
                    # Direct connection (either as fallback or primary method)
                    # Use 'load' instead of 'networkidle' - more reliable for Cloudflare-protected sites
                    response = await page.goto(search_url, timeout=90000, wait_until="load")
                    
                    if response:
                        # Check response status
                        if response.status >= 400:
                            logging.warning(f"HTTP {response.status} error for {property_url}")
                            if attempt < max_retries - 1:
                                await page.wait_for_timeout(retry_delay * (attempt + 1))
                                continue
                        
                        final_url = response.url
                        if 'truepeoplesearch.com' not in final_url.lower():
                            logging.warning(f"Redirected away from TruePeopleSearch! Final URL: {final_url}")
                            if 'cloudflare' in final_url.lower() or 'challenge' in final_url.lower():
                                logging.warning(f"Cloudflare challenge detected for {property_url}")
                                if attempt < max_retries - 1:
                                    await page.wait_for_timeout(retry_delay * (attempt + 1) * 2)
                                    continue
                        
                        fetch_success = True
                        break
                    else:
                        logging.warning(f"No response received for {property_url} (attempt {attempt + 1})")
                        if attempt < max_retries - 1:
                            await page.wait_for_timeout(retry_delay * (attempt + 1))
                            continue
                    
                except Exception as e:
                    error_msg = str(e).lower()
                    if 'timeout' in error_msg or 'navigation' in error_msg:
                        logging.warning(f"Navigation timeout for {property_url} (attempt {attempt + 1}): {e}")
                        if attempt < max_retries - 1:
                            await page.wait_for_timeout(retry_delay * (attempt + 1))
                            continue
                    else:
                        logging.error(f"Navigation error for {property_url} (attempt {attempt + 1}): {e}")
                        if attempt < max_retries - 1:
                            await page.wait_for_timeout(retry_delay * (attempt + 1))
                            continue
            
            if not fetch_success:
                logging.error(f"Failed to fetch TruePeopleSearch URL for {property_url} after {max_retries} attempts")
                stats['failed'] += 1
                return lead_data

            # Wait for page content to fully load (important for Cloudflare-protected sites)
            # Use multiple wait strategies for maximum reliability
            try:
                # Strategy 1: Wait for property card section (preferred)
                await page.wait_for_selector('div.card.card-body.shadow-form, div.shadow-form, div.card-body', timeout=15000)
                logging.debug(f"Property card section found for {property_url}")
            except Exception as e:
                logging.debug(f"Property card selector not found immediately: {e}")
                try:
                    # Strategy 2: Wait for any content that suggests page loaded
                    await page.wait_for_selector('body', timeout=5000)
                    # Check if page has loaded content
                    page_text = await page.inner_text('body')
                    if not page_text or len(page_text) < 100:
                        logging.warning(f"Page content seems empty for {property_url}")
                except Exception:
                    pass
            
            # Additional wait for JavaScript-rendered content and Cloudflare challenges
            await page.wait_for_timeout(3000)

            html_content = await page.content()
            
            # Verify page loaded correctly by checking for key indicators
            page_text_lower = html_content.lower()
            if 'estimated value' not in page_text_lower and 'property' not in page_text_lower:
                # Check for blocking indicators
                if any(kw in page_text_lower for kw in ['cloudflare', 'challenge', 'checking your browser', 'access denied', 'blocked']):
                    logging.warning(f"Page appears to be blocked or showing Cloudflare challenge for {property_url}")
                    # Try one more time with longer wait
                    await page.wait_for_timeout(5000)
                    html_content = await page.content()
                    page_text_lower = html_content.lower()
                    if 'estimated value' not in page_text_lower:
                        logging.warning(f"Still blocked after extended wait for {property_url}")
                elif 'no results' not in page_text_lower:
                    logging.warning(f"Page may not have loaded correctly for {property_url} - missing expected content")
            extracted_data = TruePeopleSearchParser.extract_all(html_content, lead_data)

            # Log what was extracted for debugging
            if extracted_data:
                logging.debug(f"Extracted {len(extracted_data)} fields for {property_url}: {list(extracted_data.keys())}")
            else:
                logging.debug(f"No data extracted for {property_url}")

            # Save debug samples for both successful and failed extractions (to help diagnose)
            if SAVE_DEBUG_SAMPLES and debug_sample_count < MAX_DEBUG_SAMPLES:
                status = "SUCCESS" if extracted_data and len(extracted_data) >= 1 else "INSUFFICIENT"
                debug_file = Path(DEBUG_DIR) / f"sample_{debug_sample_count:02d}_{status}.html"
                with open(debug_file, 'w', encoding='utf-8') as f:
                    f.write(f"<!-- URL: {search_url} -->\n")
                    f.write(f"<!-- Address: {address} -->\n")
                    f.write(f"<!-- Status: {status} -->\n")
                    f.write(f"<!-- Extracted: {extracted_data} -->\n")
                    f.write(f"<!-- Fields count: {len(extracted_data) if extracted_data else 0} -->\n\n")
                    f.write(html_content)
                debug_sample_count += 1

            # Accept any extracted data (even just 1 field) - it's still enrichment
            if extracted_data and len(extracted_data) >= 1:
                lead_data.update(extracted_data)
                logging.info(f"✓ SUCCESS: {property_url} ({len(extracted_data)} fields: {', '.join(extracted_data.keys())})")
                stats['enriched'] += 1
            else:
                # Log what fields were attempted to help diagnose
                if extracted_data and len(extracted_data) > 0:
                    logging.warning(f"✗ INSUFFICIENT: {property_url} (only {len(extracted_data)} field(s): {', '.join(extracted_data.keys())})")
                else:
                    logging.warning(f"✗ INSUFFICIENT: {property_url} (no data extracted - page may have no results or different structure)")
                stats['failed'] += 1

            return lead_data

        except Exception as e:
            logging.error(f"✗ Error: {e}")
            stats['failed'] += 1
            return lead_data

        finally:
            if page:
                await page.close()
            if context:
                await context.close()


# --- Pipeline ---

async def run_enrichment_pipeline(csv_path_override=None):
    """Main pipeline."""
    start_time = datetime.now()

    logging.info("=" * 80)
    logging.info("  TRUEPEOPLESEARCH.COM ENRICHMENT (ADDRESS COLUMN)")
    logging.info(f"  User: dacionxo | {start_time.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    logging.info("=" * 80)

    target_csv_path = csv_path_override or CSV_PATH

    try:
        df = pd.read_csv(target_csv_path, dtype=str).fillna('')
        # Normalize column names to lowercase for easier access, but keep originals too
        # This helps handle variations like 'Street' vs 'street' vs 'address'
        df.columns = df.columns.str.strip()  # Remove any whitespace from column names
        leads = df.to_dict('records')
        logging.info(f"Loaded {len(leads)} leads")
        # Log available columns for debugging
        if leads:
            logging.debug(f"Available CSV columns: {list(leads[0].keys())}")
    except FileNotFoundError:
        logging.critical("File not found")
        return

    stats = {'enriched': 0, 'failed': 0, 'skipped': 0, 'saved_to_db': 0}
    total_leads = len(leads)
    semaphore = asyncio.Semaphore(CONCURRENCY_LIMIT)

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)

        tasks = [enrich_lead_task(lead, browser, semaphore, stats) for lead in leads]
        enriched_results = await tqdm_asyncio.gather(*tasks, desc="Enriching")

        await browser.close()

    # Log stats after enrichment phase
    logging.info(f"Enrichment phase complete: {stats['enriched']} enriched, {stats['failed']} failed, {stats['skipped']} skipped")

    if enriched_results:
        pd.DataFrame(enriched_results).to_csv(ENRICHED_CSV_PATH, index=False, encoding='utf-8-sig')
        logging.info(f"✓ Saved: {ENRICHED_CSV_PATH}")

        for lead in tqdm_asyncio(enriched_results, desc="Uploading"):
            if save_lead_to_supabase(lead):
                stats['saved_to_db'] += 1

    duration = datetime.now() - start_time
    total_processed = stats['enriched'] + stats['failed'] + stats['skipped']
    total_attempted = stats['enriched'] + stats['failed']
    rate = (stats['enriched'] / total_attempted * 100) if total_attempted > 0 else 0

    logging.info("=" * 80)
    logging.info(f"  COMPLETED in {duration}")
    logging.info(f"  Total Leads Processed: {total_leads}")
    logging.info(f"  ┌─ Enriched (with data): {stats['enriched']}")
    logging.info(f"  ├─ Failed (no data found): {stats['failed']}")
    logging.info(f"  ├─ Skipped (missing address/city/state): {stats['skipped']}")
    logging.info(f"  └─ Total Attempted: {total_attempted}")
    if total_attempted > 0:
        logging.info(f"  Success Rate: {rate:.1f}% ({stats['enriched']}/{total_attempted} of attempted)")
    logging.info(f"  Database Saves: {stats['saved_to_db']}/{total_leads}")
    logging.info("=" * 80)


if __name__ == "__main__":
    asyncio.run(run_enrichment_pipeline())