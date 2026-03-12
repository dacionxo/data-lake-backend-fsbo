from supabase import create_client, Client
import os
from typing import Dict, Any, Optional
import logging
from datetime import datetime
import json
import re
import pandas as pd

# Load .env from script directory or cwd (no extra dependency)
for _env_path in (
    os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"),
    os.path.join(os.getcwd(), ".env"),
):
    if os.path.isfile(_env_path):
        try:
            with open(_env_path, encoding="utf-8") as _f:
                for _line in _f:
                    _line = _line.strip()
                    if _line and not _line.startswith("#") and "=" in _line:
                        _k, _v = _line.split("=", 1)
                        _k, _v = _k.strip(), _v.strip().strip('"').strip("'")
                        if _k and _v and _k not in os.environ:
                            os.environ[_k] = _v
        except Exception:
            pass
        break

# Configure logging to use the same logger instance as the other modules
logger = logging.getLogger('FSBOScraper')

# Supabase credentials from environment variables (and from .env if loaded above).
# Prefer SUPABASE_SERVICE_ROLE_KEY so the scraper can insert into fsbo_leads when RLS
# only allows 'authenticated' or 'service_role' (anon key cannot insert).
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://bqkucdaefpfkunceftye.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxa3VjZGFlZnBma3VuY2VmdHllIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjExMDY2MTUsImV4cCI6MjA3NjY4MjYxNX0.Vc4IR0dfpY_qwRaSQIoZrHcTHUQPb4PWWT6YgiXw5GE")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
_key = SUPABASE_SERVICE_ROLE_KEY if SUPABASE_SERVICE_ROLE_KEY else SUPABASE_KEY

try:
    supabase: Client = create_client(SUPABASE_URL, _key)
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


# URLs and patterns to exclude from photos_json (footer/flag assets, etc.)
PHOTOS_JSON_EXCLUDED_URLS = frozenset([
    "https://ssl.cdn-redfin.com/vLATEST/images/footer/flags/united-states.png",
    "https://ssl.cdn-redfin.com/vLATEST/images/footer/flags/canada.png",
    "https://ssl.cdn-redfin.com/vLATEST/images/footer/equal-housing.png",
])
PHOTOS_JSON_EXCLUDED_SUBSTR = "/images/footer/"


def parse_photos_json(photos_str: Optional[str]) -> Optional[list]:
    """Convert comma-separated photo URLs into a JSON array. Excludes footer/flag assets."""
    if not photos_str:
        return None
    try:
        urls = [url.strip() for url in photos_str.split(",") if url.strip().startswith('http')]
        # Exclude footer/flag URLs from Photos_JSON
        filtered = [
            u for u in urls
            if u not in PHOTOS_JSON_EXCLUDED_URLS and PHOTOS_JSON_EXCLUDED_SUBSTR not in u
        ]
        return filtered if filtered else None
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


def _normalize_bedrooms_for_supabase(value: Any) -> Optional[str]:
    """Strip 'bd' / ' bd' from bedrooms so '4bd' or '4 bd' exports as '4'."""
    if value is None or str(value).strip() == "":
        return None
    s = str(value).strip().replace(" bd", "").replace("bd", "").strip()
    return s if s else None


def _normalize_bathrooms_for_supabase(value: Any) -> Optional[str]:
    """Strip ' ba' / 'ba' from bathrooms so '2.5 ba' or '2.5ba' exports as '2.5'."""
    if value is None or str(value).strip() == "":
        return None
    s = str(value).strip().replace(" ba", "").replace("ba", "").strip()
    return s if s else None


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


def save_lead_to_fsbo_leads(lead_data: Dict[str, Any]) -> bool:
    """
    Upsert one lead into the fsbo_leads table from scraped listing data.
    Includes both main lead fields and pagination/detail columns (if present on table).
    """
    if not supabase:
        logger.error("Supabase client is not initialized. Cannot save to fsbo_leads.")
        return False
    if not lead_data or not lead_data.get("property_url"):
        logger.warning("Skipping fsbo_leads save: data is empty or missing property_url.")
        return False

    for key, value in list(lead_data.items()):
        if pd.isna(value):
            lead_data[key] = None
        elif isinstance(value, (pd.Timestamp, datetime)):
            lead_data[key] = value.isoformat() if hasattr(value, "isoformat") else str(value)

    listing_id = get_field_value(lead_data, ["listing_id", "property_id"]) or ""
    if not listing_id:
        listing_id = (lead_data.get("property_url") or "").rstrip("/").split("/")[-1]
    property_url = lead_data.get("property_url")
    if not property_url or not listing_id:
        logger.warning("fsbo_leads: missing listing_id or property_url.")
        return False

    # Core fsbo_leads columns (match schema: full_baths is numeric(4,2))
    payload = {
        "listing_id": listing_id,
        "property_url": property_url,
        "fsbo_source": "redfin_fsbo",
        "permalink": lead_data.get("permalink"),
        "scrape_date": lead_data.get("scrape_date", datetime.utcnow().strftime("%Y-%m-%d")),
        "last_scraped_at": datetime.utcnow().isoformat(),
        "active": True,
        "street": get_field_value(lead_data, ["street"]),
        "unit": lead_data.get("unit"),
        "city": lead_data.get("city"),
        "state": lead_data.get("state"),
        "zip_code": lead_data.get("zip_code"),
        "beds": parse_integer(get_field_value(lead_data, ["beds"])),
        "full_baths": parse_float(get_field_value(lead_data, ["full_baths"])),  # numeric(4,2)
        "half_baths": parse_integer(lead_data.get("half_baths")),
        "sqft": parse_integer(get_field_value(lead_data, ["sqft"])),
        "year_built": parse_integer(get_field_value(lead_data, ["year_built"])),
        "list_price": parse_price(get_field_value(lead_data, ["list_price"])),
        "list_price_min": parse_price(lead_data.get("list_price_min")),
        "list_price_max": parse_price(lead_data.get("list_price_max")),
        "status": lead_data.get("status") or "fsbo",
        "mls": get_field_value(lead_data, ["mls", "mls_id"]),
        "agent_name": get_field_value(lead_data, ["agent_name"]),
        "agent_email": get_field_value(lead_data, ["agent_email", "listing_agent_email"]),
        "agent_phone": get_field_value(lead_data, ["agent_phone", "agent_phone_1", "listing_agent_phone"]),
        "agent_phone_2": lead_data.get("agent_phone_2"),
        "listing_agent_phone_2": lead_data.get("listing_agent_phone_2"),
        "listing_agent_phone_5": lead_data.get("listing_agent_phone_5"),
        "text": get_field_value(lead_data, ["text"]),
        "last_sale_price": str(lead_data.get("last_sale_price", "") or "").strip() or None,
        "last_sale_date": ((parse_datetime(lead_data.get("last_sale_date")) or "")[:10] or None) if lead_data.get("last_sale_date") else None,
        "photos": get_field_value(lead_data, ["photos"]),
        "photos_json": parse_photos_json(get_field_value(lead_data, ["photos"])),
        "price_per_sqft": parse_float(lead_data.get("price_per_sqft")),
        "listing_source_name": get_field_value(lead_data, ["listing_source_name", "listing_source"]),
        "listing_source_id": lead_data.get("listing_source_id"),
        "monthly_payment_estimate": lead_data.get("monthly_payment_estimate"),
        "ai_investment_score": parse_float(lead_data.get("ai_investment_score")),
        "time_listed": parse_datetime(lead_data.get("time_listed")) if lead_data.get("time_listed") else None,
        "owner_contact_method": lead_data.get("owner_contact_method"),
        "pipeline_status": lead_data.get("pipeline_status") or "new",
        "lat": parse_float(lead_data.get("lat")),
        "lng": parse_float(lead_data.get("lng")),
    }
    # Pagination columns (added to fsbo_leads via add_fsbo_pagination_columns_to_fsbo_leads.sql)
    pagination_cols = {
        "living_area", "year_built_pagination", "bedrooms", "bathrooms", "property_type", "construction_type",
        "building_style", "effective_year_built", "number_of_units", "stories", "garage", "heating_type", "heating_gas",
        "air_conditioning", "basement", "deck", "interior_walls", "exterior_walls", "fireplaces", "flooring_cover",
        "driveway", "pool", "patio", "porch", "roof", "sewer", "water", "apn", "lot_size", "legal_name", "legal_description",
        "property_class", "county_name", "elementary_school_district", "middle_school_district", "high_school_district", "zoning", "flood_zone",
        "tax_year", "tax_amount", "assessment_year", "total_assessed_value", "assessed_improvement_value", "total_market_value",
        "last_sale_price", "amenities",
    }
    for k in pagination_cols:
        v = lead_data.get(k)
        if v is not None and str(v).strip() != "":
            v = str(v).strip()
            if k == "bedrooms":
                v = _normalize_bedrooms_for_supabase(v) or v
            elif k == "bathrooms":
                v = _normalize_bathrooms_for_supabase(v) or v
            payload[k] = v
    # year_built_pagination: text from details section (lead_data may have "year_built" as int from main scrape)
    if "year_built_pagination" not in payload and lead_data.get("year_built") is not None:
        payload["year_built_pagination"] = str(lead_data["year_built"]).strip()

    _mapped_keys = {
        "listing_id", "property_id", "property_url", "permalink", "scrape_date", "street", "unit", "city", "state", "zip_code",
        "beds", "full_baths", "half_baths", "sqft", "year_built", "list_price", "list_price_min", "list_price_max", "status",
        "mls", "mls_id", "agent_name", "agent_email", "listing_agent_email", "agent_phone", "agent_phone_1", "listing_agent_phone", "agent_phone_2",
        "text", "photos", "price_per_sqft", "listing_source_name", "listing_source", "listing_source_id", "monthly_payment_estimate",
    } | pagination_cols
    payload["other"] = build_other_json(lead_data, _mapped_keys)
    final_payload = {k: v for k, v in payload.items() if v is not None and v != ""}

    try:
        # Use property_url for conflict (unique); ensures one row per listing URL
        response = supabase.table("fsbo_leads").upsert(final_payload, on_conflict="property_url").execute()
        if hasattr(response, "error") and response.error:
            logger.error(f"fsbo_leads upsert failed for {property_url}: {response.error}")
            return False
        logger.info(f"✓ Saved fsbo_leads for {property_url}")
        return True
    except Exception as e:
        import traceback
        logger.error(f"fsbo_leads save failed for {property_url}: {e}")
        logger.error(traceback.format_exc())
        return False


# FSBO Pagination Table column names (must match scripts/supabase/fsbo_pagination_schema.sql)
FSBO_PAGINATION_COLUMNS = {
    "property_url", "listing_id", "scrape_date", "last_scraped_at",
    "living_area", "year_built", "bedrooms", "bathrooms", "property_type", "construction_type",
    "building_style", "effective_year_built", "number_of_units", "stories", "garage",
    "heating_type", "heating_gas", "air_conditioning", "basement", "deck", "interior_walls",
    "exterior_walls", "fireplaces", "flooring_cover", "driveway", "pool", "patio", "porch",
    "roof", "sewer", "water", "apn", "lot_size", "legal_name", "legal_description",
    "property_class", "county_name", "elementary_school_district", "middle_school_district", "high_school_district",
    "zoning", "flood_zone", "tax_year", "tax_amount", "assessment_year", "total_assessed_value",
    "assessed_improvement_value", "total_market_value", "last_sale_price", "amenities",
}


def save_fsbo_pagination_to_supabase(data: Dict[str, Any]) -> bool:
    """
    Upsert one row into the fsbo_pagination table from scraped listing data.
    Uses property_url as the unique key. Call after scraping a listing to persist
    property details section fields.
    """
    if not supabase:
        logger.error("Supabase client is not initialized. Cannot save FSBO pagination.")
        return False
    if not data or not data.get("property_url"):
        logger.warning("Skipping FSBO pagination save: data is empty or missing property_url.")
        return False

    for key, value in list(data.items()):
        if pd.isna(value):
            data[key] = None
        elif isinstance(value, (pd.Timestamp, datetime)):
            data[key] = value.isoformat() if hasattr(value, "isoformat") else str(value)

    payload = {k: v for k, v in data.items() if k in FSBO_PAGINATION_COLUMNS and v is not None and v != ""}
    if "bedrooms" in payload:
        payload["bedrooms"] = _normalize_bedrooms_for_supabase(payload["bedrooms"]) or payload["bedrooms"]
    if "bathrooms" in payload:
        payload["bathrooms"] = _normalize_bathrooms_for_supabase(payload["bathrooms"]) or payload["bathrooms"]
    if "property_url" not in payload:
        logger.error("Cannot save FSBO pagination without property_url.")
        return False

    payload["last_scraped_at"] = datetime.utcnow().isoformat()
    payload.setdefault("scrape_date", data.get("scrape_date", datetime.utcnow().strftime("%Y-%m-%d")))
    payload.setdefault("listing_id", data.get("listing_id") or data.get("property_id"))

    try:
        response = supabase.table("fsbo_pagination").upsert(payload, on_conflict="property_url").execute()
        if hasattr(response, "error") and response.error:
            logger.error(f"FSBO pagination upsert failed for {payload.get('property_url')}: {response.error}")
            return False
        logger.info(f"✓ Saved FSBO pagination for {payload.get('property_url')}")
        return True
    except Exception as e:
        logger.error(f"FSBO pagination save failed for {data.get('property_url')}: {e}")
        return False


def get_listing_urls_for_pagination_backfill(
    limit: int = 5000,
    source_table: str = "listings",
    missing_only: bool = True,
) -> list:
    """
    Get property_url (and listing_id) for leads that should have fsbo_pagination.
    Used to amend existing leads so each listing has both main lead data and pagination.

    Args:
        limit: Max URLs to return.
        source_table: 'listings' or 'fsbo_leads' (table that has existing leads).
        missing_only: If True, return only URLs that do not yet have a fsbo_pagination row.

    Returns:
        List of dicts with at least 'property_url'; may include 'listing_id'.
    """
    if not supabase:
        logger.error("Supabase client is not initialized.")
        return []
    try:
        # Fetch property_url (and listing_id) from source table; filter nulls in Python
        try:
            r = supabase.table(source_table).select("property_url, listing_id").limit(limit * 2).execute()
        except Exception:
            r = supabase.table(source_table).select("property_url").limit(limit * 2).execute()
        rows = [x for x in (r.data or []) if x.get("property_url")]
        if not rows:
            return []
        # Optionally filter to URLs missing in fsbo_pagination
        if missing_only:
            existing = set()
            try:
                fp = supabase.table("fsbo_pagination").select("property_url").limit(10000).execute()
                existing = {row["property_url"] for row in (fp.data or []) if row.get("property_url")}
            except Exception as e:
                logger.warning(f"Could not fetch existing fsbo_pagination URLs: {e}")
            rows = [x for x in rows if x.get("property_url") and x["property_url"] not in existing]
        # Dedupe by property_url and cap at limit
        seen = set()
        out = []
        for x in rows:
            url = x.get("property_url")
            if not url or url in seen:
                continue
            seen.add(url)
            out.append({"property_url": url, "listing_id": x.get("listing_id") or url.rstrip("/").split("/")[-1]})
            if len(out) >= limit:
                break
        return out
    except Exception as e:
        logger.error(f"get_listing_urls_for_pagination_backfill failed: {e}")
        return []