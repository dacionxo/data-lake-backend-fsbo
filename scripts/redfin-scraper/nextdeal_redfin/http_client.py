"""
Robust HTTP Client with Error Handling

Features:
- Timeout handling
- 4xx/5xx retries with exponential backoff
- Configurable retry budgets
- Request logging
"""
import time
import logging
import requests
from typing import Optional, Dict, Any
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

logger = logging.getLogger(__name__)


class HTTPError(Exception):
    """Custom HTTP error exception."""
    pass


class RetryBudgetExceeded(Exception):
    """Raised when retry budget is exhausted."""
    pass


def exponential_backoff(attempt: int, base_delay: float = 1.0, max_delay: float = 60.0) -> float:
    """
    Calculate exponential backoff delay.
    
    Args:
        attempt: Current attempt number (0-indexed)
        base_delay: Base delay in seconds
        max_delay: Maximum delay in seconds
        
    Returns:
        Delay in seconds
    """
    delay = base_delay * (2 ** attempt)
    return min(delay, max_delay)


def is_retryable_status(status_code: int) -> bool:
    """
    Determine if a status code should trigger a retry.
    
    Retries on:
    - 429 (Too Many Requests)
    - 500-599 (Server Errors)
    - Some 4xx errors that are transient
    
    Args:
        status_code: HTTP status code
        
    Returns:
        True if status code is retryable
    """
    # Retry on rate limiting
    if status_code == 429:
        return True
    
    # Retry on server errors
    if 500 <= status_code < 600:
        return True
    
    # Retry on some client errors (e.g., 408 Request Timeout)
    if status_code == 408:
        return True
    
    return False


class RobustHTTPClient:
    """
    Robust HTTP client with retry logic and error handling.
    """
    
    def __init__(
        self,
        timeout: int = 30,
        retry_budget: int = 3,
        backoff_base: float = 1.0,
        backoff_max: float = 60.0,
        session: Optional[requests.Session] = None,
    ):
        """
        Initialize the HTTP client.
        
        Args:
            timeout: Request timeout in seconds
            retry_budget: Maximum number of retries
            backoff_base: Base delay for exponential backoff
            backoff_max: Maximum delay for exponential backoff
            session: Optional requests.Session to use
        """
        self.timeout = timeout
        self.retry_budget = retry_budget
        self.backoff_base = backoff_base
        self.backoff_max = backoff_max
        self.session = session or self._create_session()
    
    def _create_session(self) -> requests.Session:
        """Create a session with retry strategy."""
        session = requests.Session()
        
        # Configure retry strategy
        retry_strategy = Retry(
            total=self.retry_budget,
            backoff_factor=self.backoff_base,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST"],
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        
        return session
    
    def fetch(
        self,
        url: str,
        method: str = "GET",
        headers: Optional[Dict[str, str]] = None,
        params: Optional[Dict[str, Any]] = None,
        data: Optional[Any] = None,
        json_data: Optional[Dict[str, Any]] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Fetch a URL with robust error handling and retries.
        
        Args:
            url: URL to fetch
            method: HTTP method
            headers: Optional request headers
            params: Optional query parameters
            data: Optional request body
            json_data: Optional JSON request body
            
        Returns:
            Dictionary with 'html', 'json', 'status_code', 'headers', 'url', or None on failure
        """
        attempt = 0
        last_exception = None
        
        while attempt <= self.retry_budget:
            try:
                logger.debug(f"Fetching {url} (attempt {attempt + 1}/{self.retry_budget + 1})")
                
                response = self.session.request(
                    method=method,
                    url=url,
                    headers=headers,
                    params=params,
                    data=data,
                    json=json_data,
                    timeout=self.timeout,
                )
                
                # Check for retryable errors
                if is_retryable_status(response.status_code):
                    if attempt < self.retry_budget:
                        delay = exponential_backoff(attempt, self.backoff_base, self.backoff_max)
                        logger.warning(
                            f"Retryable status {response.status_code} for {url}. "
                            f"Retrying in {delay:.1f}s (attempt {attempt + 1}/{self.retry_budget})"
                        )
                        time.sleep(delay)
                        attempt += 1
                        continue
                    else:
                        logger.error(f"Retry budget exceeded for {url} with status {response.status_code}")
                        raise HTTPError(f"HTTP {response.status_code} after {self.retry_budget} retries")
                
                # Check for non-retryable client errors
                if 400 <= response.status_code < 500 and response.status_code != 429:
                    logger.warning(f"Client error {response.status_code} for {url} (not retryable)")
                    return None
                
                # Success
                response.raise_for_status()
                
                result = {
                    'html': response.text,
                    'status_code': response.status_code,
                    'headers': dict(response.headers),
                    'url': response.url,
                }
                
                # Try to parse JSON if present
                try:
                    result['json'] = response.json()
                except (ValueError, json.JSONDecodeError):
                    result['json'] = {}
                
                logger.debug(f"Successfully fetched {url}")
                return result
                
            except requests.exceptions.Timeout as e:
                last_exception = e
                if attempt < self.retry_budget:
                    delay = exponential_backoff(attempt, self.backoff_base, self.backoff_max)
                    logger.warning(f"Timeout for {url}. Retrying in {delay:.1f}s")
                    time.sleep(delay)
                    attempt += 1
                else:
                    logger.error(f"Timeout budget exceeded for {url}")
                    raise HTTPError(f"Timeout after {self.retry_budget} retries") from e
                    
            except requests.exceptions.RequestException as e:
                last_exception = e
                if attempt < self.retry_budget:
                    delay = exponential_backoff(attempt, self.backoff_base, self.backoff_max)
                    logger.warning(f"Request error for {url}: {e}. Retrying in {delay:.1f}s")
                    time.sleep(delay)
                    attempt += 1
                else:
                    logger.error(f"Request failed after {self.retry_budget} retries for {url}: {e}")
                    raise HTTPError(f"Request failed after {self.retry_budget} retries") from e
        
        # Should never reach here, but handle edge case
        raise RetryBudgetExceeded(f"Retry budget exceeded for {url}") from last_exception
    
    def get(self, url: str, **kwargs) -> Optional[Dict[str, Any]]:
        """Convenience method for GET requests."""
        return self.fetch(url, method="GET", **kwargs)
    
    def post(self, url: str, **kwargs) -> Optional[Dict[str, Any]]:
        """Convenience method for POST requests."""
        return self.fetch(url, method="POST", **kwargs)


__all__ = [
    "RobustHTTPClient",
    "HTTPError",
    "RetryBudgetExceeded",
    "exponential_backoff",
    "is_retryable_status",
]


