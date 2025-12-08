import asyncio
import json
import base64
import httpx
import redis
import os
import logging
from playwright.async_api import async_playwright
from supabase_client import save_lead_to_supabase

# --- Configuration (Loaded from Environment Variables in a real deployment) ---
REDIS_HOST = os.environ.get('REDIS_HOST', 'localhost')
REDIS_PORT = int(os.environ.get('REDIS_PORT', 6379))
REDIS_QUEUE_NAME = 'enrichment_jobs'
OLLAMA_API_URL = os.environ.get('OLLAMA_API_URL', 'http://localhost:11434/api/generate')
OLLAMA_MODEL = "llava"

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# The AI extraction function (same as before)
async def extract_data_with_ollama(page, lead_data):
    # ... (This function is identical to the one in the previous Enrichment.py response)
    # ... It takes a screenshot, builds the prompt, calls the Ollama API, and returns JSON.
    try:
        screenshot_bytes = await page.screenshot(full_page=True)
        base64_image = base64.b64encode(screenshot_bytes).decode('utf-8')
        prompt = f"""
        You are an expert data extraction AI. Analyze the provided screenshot of a webpage from cyberbackgroundchecks.com.
        The original property address I searched for is approximately: {lead_data.get('street', 'N/A')}, {lead_data.get('city', 'N/A')}.
        Your task is to locate the correct resident card that matches this address and extract the following details as a single, clean JSON object.
        If a piece of information is not found, omit the key or set its value to null.
        JSON Structure to fill: {{ "estimated_value": "...", "estimated_equity": "...", "last_sale_date": "...", "last_sale_amount": "...", "year_built": "...", "ownership_type": "...", "occupancy_type": "...", "property_class": "...", "land_use": "...", "full_name": "...", "age": "...", "other_observed_names": "...", "relatives": "...", "resident_phone_number": "...", "resident_phone_number_type": "...", "other_resident_phone_number": "..." }}
        """
        payload = {"model": OLLAMA_MODEL, "prompt": prompt, "images": [base64_image], "format": "json", "stream": False}
        async with httpx.AsyncClient(timeout=180.0) as client:
            response = await client.post(OLLAMA_API_URL, json=payload)
            response.raise_for_status()
            ollama_data = response.json().get("response", "{}")
            return json.loads(ollama_data)
    except Exception as e:
        logging.error(f"Ollama extraction failed for {lead_data.get('property_url')}: {e}")
        return {}


async def process_job(job_payload, browser):
    """
    Processes a single lead from the queue.
    """
    lead_data = json.loads(job_payload)
    page, context = None, None
    try:
        street = str(lead_data.get('street', '')).lower().replace(' ', '-')
        city = str(lead_data.get('city', '')).lower().replace(' ', '-')
        state = str(lead_data.get('state', '')).lower()
        if not all([street, city, state]): return

        search_url = f"https://www.cyberbackgroundchecks.com/address/{street}/{city}/{state}"
        
        context = await browser.new_context(user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) ...")
        page = await context.new_page()
        await page.goto(search_url, timeout=60000, wait_until="domcontentloaded")

        ai_extracted_data = await extract_data_with_ollama(page, lead_data)
        if ai_extracted_data:
            lead_data.update(ai_extracted_data)
        
        save_lead_to_supabase(lead_data)
        logging.info(f"Successfully processed and saved lead: {lead_data.get('property_url')}")

    except Exception as e:
        logging.error(f"Failed to process job for {lead_data.get('property_url')}: {e}")
    finally:
        if page: await page.close()
        if context: await context.close()


async def main():
    """
    The main worker loop. Connects to Redis and continuously processes jobs.
    """
    worker_id = os.environ.get('HOSTNAME', 'local-worker') # Get a unique ID in a containerized environment
    logging.info(f"--- Starting Worker {worker_id} ---")

    try:
        r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)
        r.ping()
    except redis.exceptions.ConnectionError:
        logging.error(f"Worker {worker_id} could not connect to Redis. Shutting down.")
        return

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        logging.info(f"Worker {worker_id} launched browser.")

        while True:
            try:
                # Atomically pop a job from the right of the list (FIFO)
                # The '10' is a timeout, so it waits 10s for a job before looping
                job = r.brpop(REDIS_QUEUE_NAME, timeout=10)
                if job is None:
                    logging.info(f"Worker {worker_id}: No jobs in queue. Shutting down.")
                    break
                
                _, job_payload = job
                await process_job(job_payload, browser)

            except Exception as e:
                logging.error(f"Worker {worker_id} encountered an unhandled error: {e}")
                await asyncio.sleep(5) # Wait before retrying

        await browser.close()
    logging.info(f"--- Worker {worker_id} Finished ---")

if __name__ == "__main__":
    asyncio.run(main())