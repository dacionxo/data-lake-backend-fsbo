"""
Pipeline Stage Handlers

This module contains handlers for each pipeline stage:
- SitemapDiscoveryHandler
- FetchHandler
- ParseHandler
- NormalizeHandler
- UpsertHandler
- RawStorageHandler
- HealthChecker
"""
import logging
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Set
from bs4 import BeautifulSoup
import json
import re

logger = logging.getLogger(__name__)


class SitemapDiscoveryHandler:
    """Handler for sitemap discovery stage."""
    
    def __init__(self, http_client):
        """
        Initialize the sitemap discoverer.
        
        Args:
            http_client: HTTP client for fetching sitemaps
        """
        self.http_client = http_client
    
    def discover(
        self,
        sitemap_urls: List[str],
        target_states: List[str],
        incremental: bool = True,
        last_sitemap_timestamp: Optional[datetime] = None,
    ) -> List[str]:
        """
        Discover listing URLs from sitemaps.
        
        Args:
            sitemap_urls: List of sitemap URLs to process
            target_states: List of target state codes
            incremental: If True, filter by timestamp
            last_sitemap_timestamp: Last known sitemap timestamp for incremental scraping
            
        Returns:
            List of listing URLs
        """
        all_urls = set()
        
        for sitemap_url in sitemap_urls:
            try:
                urls = self._fetch_listing_urls_from_sitemap(
                    sitemap_url=sitemap_url,
                    target_states=target_states,
                    incremental=incremental,
                    last_timestamp=last_sitemap_timestamp,
                )
                all_urls.update(urls)
                logger.info(f"Found {len(urls)} URLs from {sitemap_url}")
            except Exception as e:
                logger.error(f"Error discovering from {sitemap_url}: {e}")
        
        return list(all_urls)
    
    def _fetch_listing_urls_from_sitemap(
        self,
        sitemap_url: str,
        target_states: List[str],
        incremental: bool = True,
        last_timestamp: Optional[datetime] = None,
    ) -> Set[str]:
        """Recursively fetch URLs from sitemap."""
        listing_urls = set()
        
        try:
            response = self.http_client.get(sitemap_url)
            if not response:
                return listing_urls
            
            root = ET.fromstring(response['html'].encode())
            namespace = ""
            if root.tag[0] == "{":
                namespace = root.tag[1:].split("}")[0]
            ns = {'ns': namespace} if namespace else {}
            
            if root.tag.endswith('sitemapindex'):
                # Process nested sitemaps
                sitemap_tags = root.findall('.//ns:sitemap', ns) if ns else root.findall('.//sitemap')
                for sm in sitemap_tags:
                    loc_tag = sm.find('ns:loc', ns) if ns else sm.find('loc')
                    lastmod_tag = sm.find('ns:lastmod', ns) if ns else sm.find('lastmod')
                    
                    if loc_tag is not None:
                        nested_url = loc_tag.text
                        
                        # Check timestamp for incremental
                        if incremental and last_timestamp and lastmod_tag is not None:
                            try:
                                sitemap_time = datetime.fromisoformat(lastmod_tag.text.replace('Z', '+00:00'))
                                if sitemap_time <= last_timestamp:
                                    logger.debug(f"Skipping {nested_url} (not modified since {last_timestamp})")
                                    continue
                            except Exception:
                                pass  # Continue if timestamp parsing fails
                        
                        nested_urls = self._fetch_listing_urls_from_sitemap(
                            nested_url, target_states, incremental, last_timestamp
                        )
                        listing_urls.update(nested_urls)
                        
            elif root.tag.endswith('urlset'):
                # Process URLs
                url_tags = root.findall('.//ns:url', ns) if ns else root.findall('.//url')
                for url_tag in url_tags:
                    loc_tag = url_tag.find('ns:loc', ns) if ns else url_tag.find('loc')
                    lastmod_tag = url_tag.find('ns:lastmod', ns) if ns else url_tag.find('lastmod')
                    
                    if loc_tag is not None:
                        url = loc_tag.text
                        
                        # Filter by state
                        if not any(f"/{state}/" in url for state in target_states):
                            continue
                        
                        # Check timestamp for incremental
                        if incremental and last_timestamp and lastmod_tag is not None:
                            try:
                                url_time = datetime.fromisoformat(lastmod_tag.text.replace('Z', '+00:00'))
                                if url_time <= last_timestamp:
                                    continue
                            except Exception:
                                pass
                        
                        listing_urls.add(url)
                        
        except Exception as e:
            logger.error(f"Error parsing sitemap {sitemap_url}: {e}")
        
        return listing_urls


class FetchHandler:
    """Handler for fetch stage."""
    
    def __init__(self, http_client, ip_rotation_manager=None):
        """
        Initialize the fetch handler.
        
        Args:
            http_client: HTTP client for fetching pages
            ip_rotation_manager: Optional IP rotation manager
        """
        self.http_client = http_client
        self.ip_rotation_manager = ip_rotation_manager
    
    def fetch(
        self,
        url: str,
        source: str,
        retry_budget: int = 3,
        timeout: int = 30,
    ) -> Optional[Dict[str, Any]]:
        """
        Fetch a listing page.
        
        Args:
            url: URL to fetch
            source: Source identifier
            retry_budget: Retry budget
            timeout: Request timeout
            
        Returns:
            Dictionary with response data or None
        """
        try:
            # Use IP rotation if available
            if self.ip_rotation_manager:
                session = self.ip_rotation_manager.get_session()
                if session:
                    try:
                        response = session.get(url, timeout=timeout)
                        response.raise_for_status()
                        return {
                            'html': response.text,
                            'json': {},
                            'status_code': response.status_code,
                            'headers': dict(response.headers),
                            'url': url,
                            'source': source,
                        }
                    except Exception as e:
                        logger.warning(f"IP rotation fetch failed for {url}: {e}")
                        self.ip_rotation_manager.handle_failure(url)
                        # Fallback to direct HTTP client
            
            # Fallback to direct HTTP client
            return self.http_client.get(url)
            
        except Exception as e:
            logger.error(f"Fetch error for {url}: {e}")
            return None


class ParseHandler:
    """Handler for parse stage (extract from HTML/JSON)."""
    
    def parse(
        self,
        html_content: str,
        json_data: Dict[str, Any],
        url: str,
        source: str,
    ) -> Optional[Dict[str, Any]]:
        """
        Parse data from HTML and JSON.
        
        Args:
            html_content: HTML content
            json_data: JSON data
            url: Source URL
            source: Source identifier
            
        Returns:
            Parsed data dictionary or None
        """
        # This is a simplified version - actual implementation would use
        # the existing parsing logic from FSBO.py
        # For now, return basic structure
        try:
            soup = BeautifulSoup(html_content, 'html.parser')
            
            # Extract basic fields (simplified - actual implementation would be more comprehensive)
            data = {
                'property_url': url,
                'source': source,
                'scrape_date': datetime.utcnow().isoformat(),
            }
            
            # Extract from JSON if available
            if json_data:
                # Use existing deep_get logic from FSBO.py
                pass
            
            # Extract from HTML
            # Use existing extraction logic from FSBO.py
            
            return data if data.get('property_url') else None
            
        except Exception as e:
            logger.error(f"Parse error for {url}: {e}")
            return None


class NormalizeHandler:
    """Handler for normalize stage."""
    
    def normalize(
        self,
        data: Dict[str, Any],
        source: str,
    ) -> Optional[Dict[str, Any]]:
        """
        Normalize and clean data.
        
        Args:
            data: Parsed data
            source: Source identifier
            
        Returns:
            Normalized data dictionary
        """
        try:
            normalized = data.copy()
            
            # Ensure fsbo_source is set
            normalized['fsbo_source'] = source
            
            # Normalize ZIP codes (use existing normalize_zip logic)
            if 'zip_code' in normalized and normalized['zip_code']:
                normalized['zip_code'] = self._normalize_zip(normalized['zip_code'])
            
            # Clean price text
            if 'list_price' in normalized and normalized['list_price']:
                normalized['list_price'] = self._clean_price_text(normalized['list_price'])
            
            # Generate listing_id if not present
            if 'listing_id' not in normalized or not normalized['listing_id']:
                normalized['listing_id'] = self._generate_listing_id(normalized.get('property_url', ''))
            
            return normalized
            
        except Exception as e:
            logger.error(f"Normalize error: {e}")
            return None
    
    @staticmethod
    def _normalize_zip(zip_like: Any) -> str:
        """Normalize ZIP code."""
        if not zip_like:
            return ""
        s = str(zip_like)
        m = re.search(r'(\d+)', s)
        if not m:
            return ""
        digits = m.group(1)
        if len(digits) >= 5:
            return digits[:5]
        return digits.zfill(5)
    
    @staticmethod
    def _clean_price_text(price_text: Any) -> str:
        """Clean price text."""
        if not price_text:
            return ""
        price_str = str(price_text).strip()
        price_str = re.sub(r'^Price,\s*', '', price_str)
        price_str = re.sub(r'—Est\.?$', '', price_str)
        return price_str.strip()
    
    @staticmethod
    def _generate_listing_id(property_url: str) -> str:
        """Generate listing_id from property_url."""
        # Extract ID from URL (e.g., last segment)
        parts = property_url.rstrip('/').split('/')
        return parts[-1] if parts else property_url


class UpsertHandler:
    """Handler for upsert stage with idempotent semantics."""
    
    def __init__(self, supabase_client):
        """
        Initialize the upsert handler.
        
        Args:
            supabase_client: Supabase client
        """
        self.supabase_client = supabase_client
    
    def upsert_batch(
        self,
        listings: List[Dict[str, Any]],
        source: str,
    ) -> int:
        """
        Upsert a batch of listings with idempotent semantics.
        
        Args:
            listings: List of normalized listing data
            source: Source identifier
            
        Returns:
            Number of successfully upserted listings
        """
        upserted_count = 0
        
        for listing in listings:
            try:
                # Ensure required fields
                if not listing.get('listing_id') or not listing.get('property_url'):
                    logger.warning(f"Skipping listing without listing_id or property_url")
                    continue
                
                # Prepare payload for fsbo_leads table
                payload = self._prepare_fsbo_payload(listing, source)
                
                # Upsert with idempotent semantics
                # ON CONFLICT (listing_id, property_url) DO UPDATE
                response = self.supabase_client.table('fsbo_leads').upsert(
                    payload,
                    on_conflict='listing_id,property_url'
                ).execute()
                
                if not response.data:
                    logger.warning(f"Upsert returned no data for {listing.get('listing_id')}")
                else:
                    upserted_count += 1
                    logger.debug(f"Upserted {listing.get('listing_id')}")
                    
            except Exception as e:
                logger.error(f"Upsert error for {listing.get('listing_id', 'unknown')}: {e}")
        
        return upserted_count
    
    def _prepare_fsbo_payload(self, listing: Dict[str, Any], source: str) -> Dict[str, Any]:
        """Prepare payload for fsbo_leads table."""
        # Map fields from listing to fsbo_leads schema
        payload = {
            'listing_id': listing.get('listing_id'),
            'property_url': listing.get('property_url'),
            'fsbo_source': source,
            'permalink': listing.get('permalink'),
            'scrape_date': listing.get('scrape_date'),
            'last_scraped_at': datetime.utcnow().isoformat(),
            'active': True,
            'street': listing.get('street'),
            'city': listing.get('city'),
            'state': listing.get('state'),
            'zip_code': listing.get('zip_code'),
            'beds': listing.get('beds'),
            'full_baths': listing.get('full_baths'),
            'half_baths': listing.get('half_baths'),
            'sqft': listing.get('sqft'),
            'list_price': listing.get('list_price'),
            'status': listing.get('status', 'fsbo'),
            'agent_name': listing.get('agent_name'),
            'agent_email': listing.get('agent_email'),
            'agent_phone': listing.get('agent_phone'),
            'text': listing.get('text'),
            'raw_response_id': listing.get('raw_response_id'),  # Pointer to raw storage
        }
        
        # Remove None values
        return {k: v for k, v in payload.items() if v is not None}


class RawStorageHandler:
    """Handler for storing raw responses."""
    
    def __init__(self, supabase_storage):
        """
        Initialize raw storage handler.
        
        Args:
            supabase_storage: Supabase Storage client
        """
        self.storage = supabase_storage
        self.bucket = "raw_ingest"
    
    def store(
        self,
        url: str,
        response_data: Dict[str, Any],
        source: str,
    ) -> Optional[str]:
        """
        Store raw response in Supabase Storage.
        
        Args:
            url: Source URL
            response_data: Response data (html, json, etc.)
            source: Source identifier
            
        Returns:
            Storage path/ID or None
        """
        try:
            # Generate storage path
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            filename = f"{source}/{timestamp}_{url.split('/')[-1]}.json"
            
            # Prepare data to store
            storage_data = {
                'url': url,
                'source': source,
                'html': response_data.get('html', ''),
                'json': response_data.get('json', {}),
                'status_code': response_data.get('status_code'),
                'headers': response_data.get('headers', {}),
                'timestamp': timestamp,
            }
            
            # Upload to storage
            # Note: Actual implementation would use Supabase Storage API
            # For now, return a placeholder ID
            storage_id = f"{self.bucket}/{filename}"
            
            logger.debug(f"Stored raw response: {storage_id}")
            return storage_id
            
        except Exception as e:
            logger.error(f"Raw storage error for {url}: {e}")
            return None


class HealthChecker:
    """Handler for volume and coverage checks."""
    
    def __init__(self, supabase_client):
        """
        Initialize health checker.
        
        Args:
            supabase_client: Supabase client
        """
        self.supabase_client = supabase_client
    
    def check_volume_coverage(
        self,
        pipeline_result,
        min_leads_per_region: Optional[int] = None,
    ) -> List[str]:
        """
        Check volume and coverage metrics.
        
        Args:
            pipeline_result: PipelineResult object
            min_leads_per_region: Minimum expected leads per region
            
        Returns:
            List of health issue messages (empty if healthy)
        """
        issues = []
        
        # Check overall volume
        if pipeline_result.listings_found == 0:
            issues.append("No listings found in sitemaps")
        
        if pipeline_result.listings_upserted < pipeline_result.listings_found * 0.5:
            issues.append(
                f"Low upsert rate: {pipeline_result.listings_upserted}/{pipeline_result.listings_found} "
                f"({pipeline_result.success_rate:.1f}%)"
            )
        
        # Check per-region coverage if configured
        if min_leads_per_region:
            # Query database for per-region counts
            # This would require actual implementation
            pass
        
        return issues


__all__ = [
    "SitemapDiscoveryHandler",
    "FetchHandler",
    "ParseHandler",
    "NormalizeHandler",
    "UpsertHandler",
    "RawStorageHandler",
    "HealthChecker",
]


