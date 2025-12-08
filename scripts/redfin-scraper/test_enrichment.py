import os
import logging
import sys
import asyncio
from datetime import datetime

# Import the async function from the enrichment module
from Enrichment import run_enrichment_pipeline

# --- Configuration ---
# Point this to your actual CSV file that has already been created by FSBO.py
EXISTING_CSV_PATH = os.getenv("FSBO_CSV_PATH", "C:/Users/jackt/Documents/redfin_leads/fsbo_leads.csv")

# --- Logger Setup ---
# Set up a logger to see detailed output in the console
def setup_logger():
    """Configures a logger to print detailed info to the console."""
    logger = logging.getLogger() # Get the root logger
    logger.setLevel(logging.INFO)
    
    # Avoid adding duplicate handlers if this is run multiple times
    if any(isinstance(h, logging.StreamHandler) for h in logger.handlers):
        return logger

    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(
        '%(asctime)s - %(levelname)-8s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    return logger

def main():
    """
    Main function to orchestrate the test run on an existing CSV file.
    """
    logger = setup_logger()
    start_time = datetime.now()
    logger.info("======================================================")
    logger.info(f"  STARTING ENRICHMENT TEST at {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"  Target File: {EXISTING_CSV_PATH}")
    logger.info("======================================================")

    if not os.path.exists(EXISTING_CSV_PATH):
        logger.critical(f"TEST FAILED: The file was not found: {EXISTING_CSV_PATH}")
        logger.critical("Please ensure FSBO.py has run successfully to generate the CSV file.")
        return

    try:
        # Since run_enrichment_pipeline is an async function, we must run it
        # within an asyncio event loop.
        asyncio.run(run_enrichment_pipeline(csv_path_override=EXISTING_CSV_PATH))

    except Exception as e:
        logger.critical(f"The test run failed with a critical error: {e}")
        import traceback
        logger.error(traceback.format_exc())
    finally:
        end_time = datetime.now()
        logger.info("======================================================")
        logger.info(f"  ENRICHMENT TEST COMPLETED at {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info(f"  Total Duration: {end_time - start_time}")
        logger.info("======================================================")

if __name__ == "__main__":
    main()