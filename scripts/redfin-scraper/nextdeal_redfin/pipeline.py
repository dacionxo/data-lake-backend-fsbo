"""
FSBO Scraper Pipeline Abstraction

World-class pipeline abstraction with clear stages:
1. Sitemap Discovery
2. Fetch
3. Parse
4. Normalize
5. Upsert + Log

This module provides a clean, testable, and extensible pipeline for scraping FSBO listings.
"""
import logging
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Set, Any
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
import json

logger = logging.getLogger(__name__)


class PipelineStage(Enum):
    """Pipeline stages for tracking progress."""
    SITEMAP_DISCOVERY = "sitemap_discovery"
    FETCH = "fetch"
    PARSE = "parse"
    NORMALIZE = "normalize"
    UPSERT = "upsert"
    COMPLETE = "complete"
    ERROR = "error"


@dataclass
class PipelineConfig:
    """Configuration for the FSBO pipeline."""
    source: str  # e.g., 'redfin', 'zillow', 'craigslist'
    target_states: List[str]
    sitemap_urls: List[str]
    incremental: bool = True
    retry_budget: int = 3
    timeout: int = 30
    max_workers: int = 10
    batch_size: int = 100
    min_leads_per_region: Optional[int] = None
    regions: List[str] = None


@dataclass
class ListingMetadata:
    """Metadata for a single listing."""
    listing_id: str
    property_url: str
    source: str
    sitemap_timestamp: Optional[datetime] = None
    scrape_date: Optional[datetime] = None
    raw_response_id: Optional[str] = None  # ID in raw_ingest storage


@dataclass
class PipelineResult:
    """Result of a pipeline run."""
    stage: PipelineStage
    listings_found: int = 0
    listings_fetched: int = 0
    listings_parsed: int = 0
    listings_normalized: int = 0
    listings_upserted: int = 0
    errors: List[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    
    def __post_init__(self):
        if self.errors is None:
            self.errors = []
        if self.start_time is None:
            self.start_time = datetime.utcnow()
    
    @property
    def duration(self) -> timedelta:
        """Get pipeline duration."""
        end = self.end_time or datetime.utcnow()
        return end - self.start_time
    
    @property
    def success_rate(self) -> float:
        """Calculate success rate."""
        if self.listings_found == 0:
            return 0.0
        return (self.listings_upserted / self.listings_found) * 100


class FSBOPipeline:
    """
    World-class FSBO scraping pipeline with clear stage separation.
    
    Stages:
    1. Sitemap Discovery - Find all listing URLs from sitemaps
    2. Fetch - Download listing pages (with retry/error handling)
    3. Parse - Extract data from HTML/JSON
    4. Normalize - Clean and standardize data
    5. Upsert - Save to database with idempotent semantics
    """
    
    def __init__(
        self,
        config: PipelineConfig,
        sitemap_discoverer,
        fetcher,
        parser,
        normalizer,
        upsert_handler,
        raw_storage_handler=None,
        health_checker=None,
    ):
        """
        Initialize the pipeline.
        
        Args:
            config: Pipeline configuration
            sitemap_discoverer: Handler for sitemap discovery stage
            fetcher: Handler for fetch stage (with retry logic)
            parser: Handler for parse stage
            normalizer: Handler for normalize stage
            upsert_handler: Handler for upsert stage
            raw_storage_handler: Handler for storing raw responses
            health_checker: Handler for volume/coverage checks
        """
        self.config = config
        self.sitemap_discoverer = sitemap_discoverer
        self.fetcher = fetcher
        self.parser = parser
        self.normalizer = normalizer
        self.upsert_handler = upsert_handler
        self.raw_storage_handler = raw_storage_handler
        self.health_checker = health_checker
        
        self.result = PipelineResult(stage=PipelineStage.SITEMAP_DISCOVERY)
    
    def run(self) -> PipelineResult:
        """
        Execute the full pipeline.
        
        Returns:
            PipelineResult with statistics and errors
        """
        logger.info(f"Starting FSBO pipeline for source: {self.config.source}")
        self.result.start_time = datetime.utcnow()
        
        try:
            # Stage 1: Sitemap Discovery
            self.result.stage = PipelineStage.SITEMAP_DISCOVERY
            listing_urls = self._discover_sitemaps()
            self.result.listings_found = len(listing_urls)
            logger.info(f"Discovered {len(listing_urls)} listings from sitemaps")
            
            if not listing_urls:
                logger.warning("No listings found in sitemaps")
                self.result.stage = PipelineStage.ERROR
                self.result.end_time = datetime.utcnow()
                return self.result
            
            # Stage 2: Fetch (with incremental filtering)
            self.result.stage = PipelineStage.FETCH
            raw_responses = self._fetch_listings(listing_urls)
            self.result.listings_fetched = len(raw_responses)
            logger.info(f"Fetched {len(raw_responses)} listing pages")
            
            # Stage 3: Parse
            self.result.stage = PipelineStage.PARSE
            parsed_data = self._parse_responses(raw_responses)
            self.result.listings_parsed = len(parsed_data)
            logger.info(f"Parsed {len(parsed_data)} listings")
            
            # Stage 4: Normalize
            self.result.stage = PipelineStage.NORMALIZE
            normalized_data = self._normalize_data(parsed_data)
            self.result.listings_normalized = len(normalized_data)
            logger.info(f"Normalized {len(normalized_data)} listings")
            
            # Stage 5: Upsert
            self.result.stage = PipelineStage.UPSERT
            upserted_count = self._upsert_listings(normalized_data)
            self.result.listings_upserted = upserted_count
            logger.info(f"Upserted {upserted_count} listings")
            
            # Health checks
            if self.health_checker:
                health_issues = self.health_checker.check_volume_coverage(self.result)
                if health_issues:
                    self.result.errors.extend(health_issues)
            
            self.result.stage = PipelineStage.COMPLETE
            logger.info(f"Pipeline completed successfully. Success rate: {self.result.success_rate:.1f}%")
            
        except Exception as e:
            logger.error(f"Pipeline error: {e}", exc_info=True)
            self.result.stage = PipelineStage.ERROR
            self.result.errors.append(f"Pipeline error: {str(e)}")
        
        finally:
            self.result.end_time = datetime.utcnow()
            duration = self.result.duration
            logger.info(f"Pipeline duration: {duration.total_seconds():.1f} seconds")
        
        return self.result
    
    def _discover_sitemaps(self) -> List[str]:
        """Stage 1: Discover listing URLs from sitemaps."""
        try:
            return self.sitemap_discoverer.discover(
                sitemap_urls=self.config.sitemap_urls,
                target_states=self.config.target_states,
                incremental=self.config.incremental,
            )
        except Exception as e:
            logger.error(f"Sitemap discovery error: {e}", exc_info=True)
            self.result.errors.append(f"Sitemap discovery error: {str(e)}")
            return []
    
    def _fetch_listings(self, listing_urls: List[str]) -> List[Dict[str, Any]]:
        """Stage 2: Fetch listing pages with retry logic."""
        raw_responses = []
        
        for url in listing_urls:
            try:
                response_data = self.fetcher.fetch(
                    url=url,
                    source=self.config.source,
                    retry_budget=self.config.retry_budget,
                    timeout=self.config.timeout,
                )
                
                if response_data:
                    # Store raw response if handler available
                    if self.raw_storage_handler:
                        raw_response_id = self.raw_storage_handler.store(
                            url=url,
                            response_data=response_data,
                            source=self.config.source,
                        )
                        response_data['raw_response_id'] = raw_response_id
                    
                    raw_responses.append(response_data)
                    
            except Exception as e:
                logger.error(f"Fetch error for {url}: {e}")
                self.result.errors.append(f"Fetch error for {url}: {str(e)}")
        
        return raw_responses
    
    def _parse_responses(self, raw_responses: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Stage 3: Parse data from raw responses."""
        parsed_data = []
        
        for response_data in raw_responses:
            try:
                parsed = self.parser.parse(
                    html_content=response_data.get('html', ''),
                    json_data=response_data.get('json', {}),
                    url=response_data.get('url', ''),
                    source=self.config.source,
                )
                
                if parsed:
                    # Attach raw response ID for debugging
                    if 'raw_response_id' in response_data:
                        parsed['raw_response_id'] = response_data['raw_response_id']
                    parsed_data.append(parsed)
                    
            except Exception as e:
                logger.error(f"Parse error for {response_data.get('url', 'unknown')}: {e}")
                self.result.errors.append(f"Parse error: {str(e)}")
        
        return parsed_data
    
    def _normalize_data(self, parsed_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Stage 4: Normalize and clean data."""
        normalized_data = []
        
        for data in parsed_data:
            try:
                normalized = self.normalizer.normalize(
                    data=data,
                    source=self.config.source,
                )
                
                if normalized:
                    normalized_data.append(normalized)
                    
            except Exception as e:
                logger.error(f"Normalize error: {e}")
                self.result.errors.append(f"Normalize error: {str(e)}")
        
        return normalized_data
    
    def _upsert_listings(self, normalized_data: List[Dict[str, Any]]) -> int:
        """Stage 5: Upsert listings with idempotent semantics."""
        upserted_count = 0
        
        # Process in batches
        for i in range(0, len(normalized_data), self.config.batch_size):
            batch = normalized_data[i:i + self.config.batch_size]
            
            try:
                count = self.upsert_handler.upsert_batch(
                    listings=batch,
                    source=self.config.source,
                )
                upserted_count += count
                
            except Exception as e:
                logger.error(f"Upsert batch error: {e}")
                self.result.errors.append(f"Upsert batch error: {str(e)}")
        
        return upserted_count


__all__ = [
    "FSBOPipeline",
    "PipelineStage",
    "PipelineConfig",
    "ListingMetadata",
    "PipelineResult",
]


