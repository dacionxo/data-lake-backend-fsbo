"""
FSBO Scraper Module

Wrapper around the FSBO.py scraping functionality.
"""
import sys
import os
import logging
from pathlib import Path
from typing import Optional, List, Set

# Add parent directory to path to import FSBO module
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

# Import from FSBO.py (will be refactored later)
try:
    from FSBO import (
        main as fsbo_main,
        fetch_listing_urls_from_sitemap,
        fetch_sitemap_urls,
        scrape_redfin_listing,
        save_to_csv,
        _push_listing_to_supabase,
        TARGET_STATES,
        SITEMAP_URLS,
        CSV_PATH,
        LOG_PATH,
        FIELDS,
    )
except ImportError:
    # Fallback if imports fail
    fsbo_main = None
    _push_listing_to_supabase = None
    logging.warning("Could not import FSBO module - some functionality may be limited")


class FSBOScraper:
    """
    World-Class Redfin FSBO Lead Scraper.
    
    This class provides a programmatic interface to the Redfin FSBO scraping
    functionality.
    """
    
    def __init__(
        self,
        target_states: Optional[List[str]] = None,
        csv_path: Optional[str] = None,
        log_path: Optional[str] = None,
    ):
        """
        Initialize the FSBO scraper.
        
        Args:
            target_states: List of state codes to scrape (e.g., ['CA', 'NY']).
                          If None, uses default TARGET_STATES.
            csv_path: Path to CSV file for output. If None, uses default.
            log_path: Path to log file. If None, uses default.
        """
        self.target_states = set(target_states) if target_states else TARGET_STATES
        self.csv_path = csv_path or CSV_PATH
        self.log_path = log_path or LOG_PATH
        
        # Setup logging
        logging.basicConfig(
            filename=self.log_path,
            level=logging.INFO,
            format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        )
        self.logger = logging.getLogger(__name__)
        
    def run(self) -> None:
        """
        Execute the scraping process.
        
        This method orchestrates the full scraping pipeline:
        1. Fetch listing URLs from sitemaps
        2. Scrape each listing page
        3. Save results to CSV
        """
        if fsbo_main is None:
            raise RuntimeError("FSBO module not available")
        
        # Temporarily override global config
        import FSBO
        original_csv_path = FSBO.CSV_PATH
        original_log_path = FSBO.LOG_PATH
        
        try:
            if self.csv_path:
                FSBO.CSV_PATH = self.csv_path
            if self.log_path:
                FSBO.LOG_PATH = self.log_path
            
            self.logger.info("Starting FSBO scraper...")
            fsbo_main()
            self.logger.info("FSBO scraper completed")
        finally:
            # Restore original config
            FSBO.CSV_PATH = original_csv_path
            FSBO.LOG_PATH = original_log_path
    
    def scrape_url(self, url: str) -> Optional[dict]:
        """
        Scrape a single listing URL.
        
        Args:
            url: The Redfin listing URL to scrape
            
        Returns:
            Dictionary containing scraped data, or None if scraping failed
        """
        import requests
        from requests_ip_rotator import ApiGateway
        
        target_domain = "https://www.redfin.com"
        
        # Create gateway session
        gateway = ApiGateway(target_domain, regions=["us-east-1", "us-west-2"])
        gateway.start()
        
        try:
            session = requests.Session()
            session.mount(target_domain, gateway)
            session.headers.update({
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            })
            
            # Full scrape completes before return (both FSBO_Leads and fsbo_pagination data in data)
            data = scrape_redfin_listing(url, session)
            if data:
                # Push both to Supabase only after scrape is complete (fsbo_leads, then fsbo_pagination)
                if _push_listing_to_supabase:
                    try:
                        _push_listing_to_supabase(data)
                    except Exception as e:
                        self.logger.warning(f"Supabase push failed for {url}: {e}")
            return data
        finally:
            gateway.shutdown()


__all__ = ["FSBOScraper"]


