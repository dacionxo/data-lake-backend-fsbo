from supabase import create_client, Client
import os
from typing import Dict, Any, Optional
import logging
from datetime import datetime
import json
import re
import pandas as pd

# Configure logging to use the same logger instance as the other modules
logger = logging.getLogger('FSBOScraper')

# Supabase credentials from environment variables
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://bqkucdaefpfkunceftye.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxa3VjZGFlZnBma3VuY2VmdHllIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjExMDY2MTUsImV4cCI6MjA3NjY4MjYxNX0.Vc4IR0dfpY_qwRaSQIoZrHcTHUQPb4PWWT6YgiXw5GE")

try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
except Exception as e:
    logger.critical(f"Failed to create Supabase client: {e}")
    supabase = None

# UPDATED: Comprehensive mapping to match the new case-sensitive Supabase schema.
FIELD_MAPPINGS = {
    # Core listing fields (lowercase)
    'listing_id': ['listing_id', 'property_id'],
    'property_url': ['property_url'],
    'permalink': ['permalink'],
    'street': ['address', 'street'],
    'unit': ['unit'],
    'city': ['city'],
    'state': ['state'],
    'zip_code': ['zip_code'],
    'beds': ['beds'],
    'full_baths': ['full_baths'],
    'half_baths': ['half_baths'],
    'sqft': ['sqft'],
    'year_built': ['year_built'], # Maps to the integer column
    'list_price': ['list_price'],
    'list_price_min': ['list_price_min'],
    'list_price_max': ['list_price_max'],
    'status': ['status', 'mls_status'],
    'mls': ['mls', 'mls_id'],
    'agent_name': ['agent_name'],
    'agent_email': ['agent_email', 'listing_agent_email'],
    'agent_phone': ['agent_phone', 'agent_phone_1', 'listing_agent_phone'],
    'photos': ['photos'],
    'price_per_sqft': ['price_per_sqft'],
    'listing_source_name': ['listing_source_name', 'listing_source'],
    'listing_source_id': ['listing_source_id'],
    'monthly_payment_estimate': ['monthly_payment_estimate'],
    'ai_investment_score': ['ai_investment_score'],
    'time_listed': ['time_listed'],
    'agent_phone_2': ['agent_phone_2'],
    'listing_agent_phone_2': ['listing_agent_phone_2'],
    'listing_agent_phone_4': ['listing_agent_phone_4'],
    'estimated_value': ['estimated_value'],

    # Enrichment Fields (Capitalized as per new schema)
    'Estimated_Equity': ['estimated_equity'],
    'Last_Sale_Date': ['last_sale_date'],
    'Last_Sale_Amount': ['last_sale_amount'],
    'Year_Built': ['year_built_enriched'], # Maps to the text column
    'Ownership_Type': ['ownership_type'],
    'Occupancy_Type': ['occupancy_type'],
    'Property_Class': ['property_class'],
    'Land_Use': ['land_use'],
    'Full_Name': ['full_name'],
    'Age': ['age'],
    'Other_Observed_Names': ['other_observed_names'],
    'Relatives': ['relatives'],
    'Resident_Phone_Number': ['resident_phone_number'],
    'Other_Resident_Phone_Number': ['other_resident_phone_number'],
}


def get_field_value(lead_data: Dict[str, Any], field_keys: list) -> Optional[Any]:
    """Retrieve the first non-empty value from a list of possible field keys."""
    for key in field_keys:
        value = lead_data.get(key)
        if value is not None and value != '':
            return value
    return None


def parse_integer(value: Any) -> Optional[int]:
    """Safely parse integer values from strings or numbers."""
    if value is None or value == "":
        return None
    try:
        clean_value = str(value).split('.')[0]
        return int(re.sub(r'[^\d-]', '', clean_value))
    except (ValueError, TypeError):
        logger.debug(f"Could not parse integer from: {value}")
        return None


def parse_price(value: Any) -> Optional[int]:
    """Parse price values from strings, converting to integer (bigint)."""
    if value is None or value == "":
        return None
    try:
        clean_value = str(value).replace("$", "").replace(",", "").strip()
        numeric_part = re.match(r'[\d.]+', clean_value)
        if numeric_part:
            return int(float(numeric_part.group(0)))
        return None
    except (ValueError, TypeError):
        logger.debug(f"Could not parse price from: {value}")
        return None


def parse_float(value: Any) -> Optional[float]:
    """Safely parse float values from strings or numbers (numeric)."""
    if value is None or value == "":
        return None
    try:
        return float(str(value).replace(",", "").strip())
    except (ValueError, TypeError):
        logger.debug(f"Could not parse float from: {value}")
        return None


def parse_photos_json(photos_str: Optional[str]) -> Optional[list]:
    """Convert comma-separated photo URLs into a JSON array."""
    if not photos_str:
        return None
    try:
        urls = [url.strip() for url in photos_str.split(",") if url.strip().startswith('http')]
        return urls if urls else None
    except Exception as e:
        logger.debug(f"Could not parse photos JSON: {e}")
        return None


def parse_datetime(value: Any) -> Optional[str]:
    """Safely parse datetime values and return in ISO format."""
    if not value:
        return None
    try:
        return pd.to_datetime(value).isoformat()
    except (ValueError, TypeError):
        logger.debug(f"Could not parse datetime from: {value}")
        return None


def build_other_json(lead_data: Dict[str, Any], mapped_keys: set) -> Optional[Dict[str, Any]]:
    """Build a JSON object containing all fields not mapped to main table columns."""
    unmapped_keys = set(lead_data.keys()) - mapped_keys

    other_data = {
        k: lead_data[k] for k in unmapped_keys
        if lead_data.get(k) is not None and lead_data.get(k) != ""
    }

    # Ensure all values are JSON serializable
    for key, value in other_data.items():
        if isinstance(value, (datetime, pd.Timestamp)):
            other_data[key] = value.isoformat()
        elif not isinstance(value, (bool, int, float, str, list, dict, type(None))):
            other_data[key] = str(value)

    return other_data if other_data else None


def save_lead_to_supabase(lead_data: Dict[str, Any]) -> bool:
    """
    Upserts a single lead record into the 'listings' table in Supabase.
    This function is robust and handles both scraped and enriched data.
    """
    if not supabase:
        logger.error("Supabase client is not initialized. Cannot save lead.")
        return False

    if not lead_data or not lead_data.get('property_url'):
        logger.warning("Skipping Supabase save: lead_data is empty or missing 'property_url'.")
        return False

    # Clean data from pandas types (e.g., NaN, NaT) to Python-native types
    for key, value in lead_data.items():
        if pd.isna(value):
            lead_data[key] = None
        elif isinstance(value, pd.Timestamp):
            lead_data[key] = value.to_pydatetime().isoformat()

    try:
        property_url = lead_data['property_url']
        supabase_payload = {}

        # Dynamically build the payload using the comprehensive FIELD_MAPPINGS
        for supabase_col, source_keys in FIELD_MAPPINGS.items():
            supabase_payload[supabase_col] = get_field_value(lead_data, source_keys)

        # --- Handle specific data type conversions ---
        price_cols = ['list_price', 'list_price_min', 'list_price_max', 'estimated_value', 'Estimated_Equity', 'Last_Sale_Amount']
        for col in price_cols:
            if supabase_payload.get(col):
                supabase_payload[col] = parse_price(supabase_payload[col])

        int_cols = ['year_built', 'half_baths'] # 'Age' is text in the new schema
        for col in int_cols:
            if supabase_payload.get(col):
                supabase_payload[col] = parse_integer(supabase_payload[col])

        float_cols = ['price_per_sqft', 'ai_investment_score']
        for col in float_cols:
            if supabase_payload.get(col):
                 supabase_payload[col] = parse_float(supabase_payload[col])

        # Handle timestamp fields - validate and skip invalid values
        # Values like "34 minutes", "4 days", "Single-family" are not valid timestamps
        timestamp_fields = ['time_listed', 'Last_Sale_Date']
        for field in timestamp_fields:
            if field in supabase_payload and supabase_payload[field]:
                field_value = str(supabase_payload[field]).strip()
                
                # Skip if it's a relative time string (e.g., "34 minutes", "4 days")
                if re.match(r'^\d+\s+(minute|hour|day|week|month|year)', field_value, re.I):
                    logger.debug(f"Skipping invalid {field} value (relative time): {field_value}")
                    supabase_payload.pop(field, None)
                    continue
                
                # Skip if it's clearly not a date (e.g., "Single-family", property types, etc.)
                # Check if it contains no year digits and has common non-date keywords
                non_date_keywords = ['single-family', 'family', 'condo', 'townhouse', 'apartment', 'commercial']
                if not re.search(r'\d{4}', field_value) and any(kw in field_value.lower() for kw in non_date_keywords):
                    logger.debug(f"Skipping invalid {field} value (non-date): {field_value}")
                    supabase_payload.pop(field, None)
                    continue
                
                # Try to parse as datetime
                parsed_time = parse_datetime(field_value)
                if parsed_time:
                    supabase_payload[field] = parsed_time
                else:
                    logger.debug(f"Skipping invalid {field} value (parse failed): {field_value}")
                    supabase_payload.pop(field, None)

        # Add timestamps and special fields
        supabase_payload['scrape_date'] = lead_data.get('scrape_date', datetime.utcnow().strftime("%Y-%m-%d"))
        supabase_payload['last_scraped_at'] = datetime.utcnow().isoformat()
        supabase_payload['active'] = True
        supabase_payload['photos_json'] = parse_photos_json(get_field_value(lead_data, ['photos']))

        # Build the 'other' JSONB field for any data not directly mapped
        all_mapped_source_keys = {item for sublist in FIELD_MAPPINGS.values() for item in sublist}
        supabase_payload['other'] = build_other_json(lead_data, all_mapped_source_keys)

        # Final cleanup: remove keys with None values to let Supabase handle defaults
        final_payload = {k: v for k, v in supabase_payload.items() if v is not None}

        if 'property_url' not in final_payload:
             logger.error(f"Cannot save lead for {property_url} without a property_url in the final payload.")
             return False

        # Perform the upsert operation, using 'property_url' as the unique key
        response = supabase.table('listings').upsert(final_payload, on_conflict='property_url').execute()

        if hasattr(response, 'error') and response.error:
            logger.error(f"Supabase upsert failed for {property_url}: {response.error}")
            return False

        logger.info(f"✓ Successfully saved/updated lead to Supabase: {property_url}")
        return True

    except Exception as e:
        import traceback
        logger.error(f"A critical exception occurred in save_lead_to_supabase for {lead_data.get('property_url')}: {e}")
        logger.error(traceback.format_exc())
        return False