"""
FSBO Enrichment Module

Wrapper around the Enrichment.py skip tracing functionality.
"""
import sys
import os
import asyncio
import logging
from pathlib import Path
from typing import Optional

# Add parent directory to path to import Enrichment module
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

# Import from Enrichment.py (will be refactored later)
try:
    from Enrichment import (
        run_enrichment_pipeline,
        CSV_PATH,
        ENRICHED_CSV_PATH,
        LOG_PATH,
    )
except ImportError:
    run_enrichment_pipeline = None
    logging.warning("Could not import Enrichment module - some functionality may be limited")


class FSBOEnrichment:
    """
    FSBO Lead Enrichment Engine.
    
    This class provides enrichment capabilities for FSBO leads using
    skip tracing and contact information lookup.
    """
    
    def __init__(
        self,
        csv_path: Optional[str] = None,
        enriched_csv_path: Optional[str] = None,
        log_path: Optional[str] = None,
    ):
        """
        Initialize the enrichment engine.
        
        Args:
            csv_path: Path to input CSV file with leads to enrich.
            enriched_csv_path: Path to output CSV file for enriched leads.
            log_path: Path to log file.
        """
        self.csv_path = csv_path or CSV_PATH
        self.enriched_csv_path = enriched_csv_path or ENRICHED_CSV_PATH
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
        Execute the enrichment pipeline.
        
        This method runs the full enrichment process:
        1. Load leads from CSV
        2. Enrich each lead with skip tracing
        3. Save enriched results to CSV
        4. Upload to Supabase
        """
        if run_enrichment_pipeline is None:
            raise RuntimeError("Enrichment module not available")
        
        # Temporarily override global config
        import Enrichment
        original_csv_path = Enrichment.CSV_PATH
        original_enriched_csv_path = Enrichment.ENRICHED_CSV_PATH
        original_log_path = Enrichment.LOG_PATH
        
        try:
            if self.csv_path:
                Enrichment.CSV_PATH = self.csv_path
            if self.enriched_csv_path:
                Enrichment.ENRICHED_CSV_PATH = self.enriched_csv_path
            if self.log_path:
                Enrichment.LOG_PATH = self.log_path
            
            self.logger.info("Starting enrichment pipeline...")
            asyncio.run(run_enrichment_pipeline(self.csv_path))
            self.logger.info("Enrichment pipeline completed")
        finally:
            # Restore original config
            Enrichment.CSV_PATH = original_csv_path
            Enrichment.ENRICHED_CSV_PATH = original_enriched_csv_path
            Enrichment.LOG_PATH = original_log_path


__all__ = ["FSBOEnrichment"]


