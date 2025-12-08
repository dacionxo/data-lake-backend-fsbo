import pandas as pd
import redis
import json
import logging

# --- Configuration ---
CSV_PATH = "C:/Users/test/Documents/Buisness/fsbo_leads.csv"
REDIS_HOST = 'localhost'  # Or your cloud Redis IP
REDIS_PORT = 6379
REDIS_QUEUE_NAME = 'enrichment_jobs'

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def main():
    """
    Loads leads from the CSV and pushes them as jobs into a Redis queue.
    """
    logging.info("--- Starting Orchestrator ---")
    
    try:
        df = pd.read_csv(CSV_PATH, dtype=str).fillna('')
        leads = df.to_dict('records')
        logging.info(f"Loaded {len(leads)} leads from {CSV_PATH}.")
    except FileNotFoundError:
        logging.error(f"FATAL: Input file not found at {CSV_PATH}. Aborting.")
        return

    try:
        r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)
        r.ping()
        logging.info("Successfully connected to Redis.")
    except redis.exceptions.ConnectionError as e:
        logging.error(f"FATAL: Could not connect to Redis at {REDIS_HOST}:{REDIS_PORT}. Error: {e}")
        return

    # Clear any old jobs from the queue to start fresh
    r.delete(REDIS_QUEUE_NAME)
    logging.info(f"Cleared old jobs from queue: '{REDIS_QUEUE_NAME}'.")

    # Push new jobs to the queue
    with r.pipeline() as pipe:
        for lead in leads:
            # Each lead becomes a JSON string message in the queue
            job_payload = json.dumps(lead)
            pipe.lpush(REDIS_QUEUE_NAME, job_payload)
        pipe.execute()
    
    job_count = r.llen(REDIS_QUEUE_NAME)
    logging.info(f"Successfully pushed {job_count} jobs to the Redis queue.")
    logging.info("--- Orchestrator Finished. Workers can now begin processing. ---")

if __name__ == "__main__":
    main()