"""
AWS API Gateway IP Rotation Manager

Features:
- Shared configuration
- Health checks of endpoints
- Fallback when a region's IP pool is blocked
- Automatic region switching
"""
import logging
import time
from typing import List, Optional, Dict, Any
from dataclasses import dataclass
from requests_ip_rotator import ApiGateway
import requests

logger = logging.getLogger(__name__)


@dataclass
class IPRotationConfig:
    """Configuration for IP rotation."""
    target_domain: str
    regions: List[str]
    health_check_url: Optional[str] = None
    health_check_timeout: int = 5
    max_failures_per_region: int = 5
    failure_window_seconds: int = 300  # 5 minutes


class IPRotationManager:
    """
    Manages AWS API Gateway IP rotation with health checks and fallback.
    """
    
    def __init__(self, config: IPRotationConfig):
        """
        Initialize the IP rotation manager.
        
        Args:
            config: IP rotation configuration
        """
        self.config = config
        self.gateways: Dict[str, ApiGateway] = {}
        self.active_gateway: Optional[ApiGateway] = None
        self.active_region: Optional[str] = None
        self.session: Optional[requests.Session] = None
        self.region_failures: Dict[str, List[float]] = {}  # Track failure timestamps
        
        # Initialize gateways for all regions
        for region in config.regions:
            try:
                gateway = ApiGateway(config.target_domain, regions=[region])
                gateway.start()
                self.gateways[region] = gateway
                logger.info(f"Started API Gateway for region: {region}")
            except Exception as e:
                logger.error(f"Failed to start API Gateway for region {region}: {e}")
        
        # Set initial active gateway
        self._select_active_gateway()
    
    def _select_active_gateway(self) -> bool:
        """
        Select the best available gateway based on health checks.
        
        Returns:
            True if a gateway was selected, False otherwise
        """
        # Check health of each gateway
        for region, gateway in self.gateways.items():
            if self._is_region_healthy(region):
                try:
                    # Create test session
                    test_session = requests.Session()
                    test_session.mount(self.config.target_domain, gateway)
                    
                    # Perform health check
                    if self.config.health_check_url:
                        try:
                            response = test_session.get(
                                self.config.health_check_url,
                                timeout=self.config.health_check_timeout
                            )
                            if response.status_code == 200:
                                self.active_gateway = gateway
                                self.active_region = region
                                logger.info(f"Selected gateway for region: {region}")
                                return True
                        except Exception as e:
                            logger.warning(f"Health check failed for region {region}: {e}")
                            self._record_region_failure(region)
                    else:
                        # No health check URL, just use first available
                        self.active_gateway = gateway
                        self.active_region = region
                        logger.info(f"Selected gateway for region: {region} (no health check)")
                        return True
                        
                except Exception as e:
                    logger.warning(f"Failed to create session for region {region}: {e}")
                    self._record_region_failure(region)
        
        # No healthy gateway found
        logger.error("No healthy gateway found")
        return False
    
    def _is_region_healthy(self, region: str) -> bool:
        """
        Check if a region is healthy (not blocked).
        
        Args:
            region: AWS region name
            
        Returns:
            True if region is healthy
        """
        if region not in self.region_failures:
            return True
        
        # Check failures in the current window
        now = time.time()
        recent_failures = [
            t for t in self.region_failures[region]
            if now - t < self.config.failure_window_seconds
        ]
        
        # Update failure list
        self.region_failures[region] = recent_failures
        
        # Region is healthy if failures are below threshold
        return len(recent_failures) < self.config.max_failures_per_region
    
    def _record_region_failure(self, region: str):
        """Record a failure for a region."""
        if region not in self.region_failures:
            self.region_failures[region] = []
        self.region_failures[region].append(time.time())
    
    def get_session(self) -> Optional[requests.Session]:
        """
        Get a requests session with active gateway mounted.
        
        Returns:
            requests.Session with gateway, or None if no healthy gateway
        """
        if not self.active_gateway:
            if not self._select_active_gateway():
                return None
        
        # Create session if not exists
        if not self.session:
            self.session = requests.Session()
            self.session.mount(self.config.target_domain, self.active_gateway)
            self.session.headers.update({
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            })
        
        return self.session
    
    def handle_failure(self, url: Optional[str] = None):
        """
        Handle a failure by switching to a different region.
        
        Args:
            url: URL that failed (for logging)
        """
        if self.active_region:
            logger.warning(f"Recording failure for region {self.active_region} (URL: {url})")
            self._record_region_failure(self.active_region)
            
            # Try to switch to a different region
            old_region = self.active_region
            self.active_gateway = None
            self.active_region = None
            self.session = None
            
            if self._select_active_gateway():
                logger.info(f"Switched from region {old_region} to {self.active_region}")
            else:
                logger.error("Failed to switch to a healthy region")
    
    def shutdown(self):
        """Shutdown all gateways."""
        for region, gateway in self.gateways.items():
            try:
                gateway.shutdown()
                logger.info(f"Shut down gateway for region: {region}")
            except Exception as e:
                logger.error(f"Error shutting down gateway for region {region}: {e}")
        
        self.active_gateway = None
        self.active_region = None
        self.session = None


__all__ = [
    "IPRotationManager",
    "IPRotationConfig",
]


