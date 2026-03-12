"""
NextDeal Redfin Scraper Package

A world-class Redfin FSBO lead scraper for the NextDeal data lake.
"""

__version__ = "0.1.0"
__author__ = "NextDeal"
__email__ = "dev@nextdeal.com"

# Import order matters - avoid circular dependencies
try:
    from nextdeal_redfin.scraper import FSBOScraper
except ImportError:
    FSBOScraper = None

try:
    from nextdeal_redfin.enrichment import FSBOEnrichment
except ImportError:
    FSBOEnrichment = None

try:
    from nextdeal_redfin.supabase_client import SupabaseClient
except ImportError:
    SupabaseClient = None

__all__ = [
    "FSBOScraper",
    "FSBOEnrichment",
    "SupabaseClient",
    "__version__",
]

