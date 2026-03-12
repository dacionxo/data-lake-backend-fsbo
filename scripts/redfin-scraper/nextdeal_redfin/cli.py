"""
Command-line interface for NextDeal Redfin Scraper.

This module provides console entry points for:
- nextdeal-fsbo-scrape: Run the FSBO scraper
- nextdeal-fsbo-enrich: Run the enrichment pipeline
- nextdeal-fsbo-worker: Run worker process for distributed scraping
"""
import sys
import argparse
import logging
from typing import Optional

from nextdeal_redfin.scraper import FSBOScraper
from nextdeal_redfin.enrichment import FSBOEnrichment


def setup_logging(level: str = "INFO") -> None:
    """Configure logging for CLI commands."""
    log_level = getattr(logging, level.upper(), logging.INFO)
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def scrape_command(args: argparse.Namespace) -> int:
    """Execute the FSBO scraping command."""
    setup_logging(args.log_level)
    logger = logging.getLogger(__name__)
    
    try:
        scraper = FSBOScraper(
            target_states=args.states.split(",") if args.states else None,
            csv_path=args.csv_path,
            log_path=args.log_path,
        )
        
        logger.info("Starting FSBO scraping...")
        scraper.run()
        logger.info("Scraping completed successfully")
        return 0
    except KeyboardInterrupt:
        logger.info("Scraping interrupted by user")
        return 130
    except Exception as e:
        logger.error(f"Scraping failed: {e}", exc_info=True)
        return 1


def enrich_command(args: argparse.Namespace) -> int:
    """Execute the enrichment command."""
    setup_logging(args.log_level)
    logger = logging.getLogger(__name__)
    
    try:
        enrichment = FSBOEnrichment(
            csv_path=args.csv_path,
            enriched_csv_path=args.enriched_csv_path,
            log_path=args.log_path,
        )
        
        logger.info("Starting enrichment pipeline...")
        enrichment.run()
        logger.info("Enrichment completed successfully")
        return 0
    except KeyboardInterrupt:
        logger.info("Enrichment interrupted by user")
        return 130
    except Exception as e:
        logger.error(f"Enrichment failed: {e}", exc_info=True)
        return 1


def worker_command(args: argparse.Namespace) -> int:
    """Execute the worker command for distributed scraping."""
    setup_logging(args.log_level)
    logger = logging.getLogger(__name__)
    
    try:
        # TODO: Implement worker functionality
        logger.warning("Worker command not yet implemented")
        return 0
    except KeyboardInterrupt:
        logger.info("Worker interrupted by user")
        return 130
    except Exception as e:
        logger.error(f"Worker failed: {e}", exc_info=True)
        return 1


def create_scrape_parser(subparsers: argparse._SubParsersAction) -> None:
    """Create parser for scrape command."""
    parser = subparsers.add_parser(
        "scrape",
        help="Scrape Redfin FSBO listings",
        description="Scrape For Sale By Owner listings from Redfin",
    )
    parser.add_argument(
        "--states",
        type=str,
        help="Comma-separated list of state codes (e.g., CA,NY,TX). If not specified, uses default target states.",
    )
    parser.add_argument(
        "--csv-path",
        type=str,
        help="Path to CSV file for output (default: from config)",
    )
    parser.add_argument(
        "--log-path",
        type=str,
        help="Path to log file (default: from config)",
    )
    parser.add_argument(
        "--log-level",
        type=str,
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: INFO)",
    )
    parser.set_defaults(func=scrape_command)


def create_enrich_parser(subparsers: argparse._SubParsersAction) -> None:
    """Create parser for enrich command."""
    parser = subparsers.add_parser(
        "enrich",
        help="Enrich FSBO leads with skip tracing",
        description="Enrich scraped FSBO leads with contact information using skip tracing",
    )
    parser.add_argument(
        "--csv-path",
        type=str,
        help="Path to input CSV file (default: from config)",
    )
    parser.add_argument(
        "--enriched-csv-path",
        type=str,
        help="Path to output enriched CSV file (default: from config)",
    )
    parser.add_argument(
        "--log-path",
        type=str,
        help="Path to log file (default: from config)",
    )
    parser.add_argument(
        "--log-level",
        type=str,
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: INFO)",
    )
    parser.set_defaults(func=enrich_command)


def create_worker_parser(subparsers: argparse._SubParsersAction) -> None:
    """Create parser for worker command."""
    parser = subparsers.add_parser(
        "worker",
        help="Run worker process for distributed scraping",
        description="Run a worker process that processes jobs from a queue",
    )
    parser.add_argument(
        "--log-level",
        type=str,
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: INFO)",
    )
    parser.set_defaults(func=worker_command)


def main() -> int:
    """Main entry point for nextdeal-fsbo command."""
    parser = argparse.ArgumentParser(
        prog="nextdeal-fsbo",
        description="NextDeal Redfin FSBO Lead Scraper",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s scrape --states CA,NY,TX
  %(prog)s enrich --csv-path ./leads.csv
  %(prog)s worker
        """,
    )
    
    subparsers = parser.add_subparsers(
        dest="command",
        help="Available commands",
        required=True,
    )
    
    create_scrape_parser(subparsers)
    create_enrich_parser(subparsers)
    create_worker_parser(subparsers)
    
    args = parser.parse_args()
    return args.func(args)


# Entry points for pyproject.toml
def scrape_entry() -> int:
    """Entry point for nextdeal-fsbo-scrape command."""
    parser = argparse.ArgumentParser(prog="nextdeal-fsbo-scrape")
    create_scrape_parser(parser.add_subparsers(dest="dummy"))
    # Re-parse with just scrape command
    sys.argv.insert(1, "scrape")
    args = parser.parse_args()
    return scrape_command(args)


def enrich_entry() -> int:
    """Entry point for nextdeal-fsbo-enrich command."""
    parser = argparse.ArgumentParser(prog="nextdeal-fsbo-enrich")
    create_enrich_parser(parser.add_subparsers(dest="dummy"))
    # Re-parse with just enrich command
    sys.argv.insert(1, "enrich")
    args = parser.parse_args()
    return enrich_command(args)


def worker_entry() -> int:
    """Entry point for nextdeal-fsbo-worker command."""
    parser = argparse.ArgumentParser(prog="nextdeal-fsbo-worker")
    create_worker_parser(parser.add_subparsers(dest="dummy"))
    # Re-parse with just worker command
    sys.argv.insert(1, "worker")
    args = parser.parse_args()
    return worker_command(args)


if __name__ == "__main__":
    sys.exit(main())


