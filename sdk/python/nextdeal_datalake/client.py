"""
Data Lake Client

Main client for interacting with the NextDeal Data Lake on Supabase.
Provides zone-based operations and pipeline tracking.
"""
import os
from typing import Optional, Dict, Any, List
from uuid import UUID
from supabase import create_client, Client

from nextdeal_datalake.models import (
    RawRedfinResponse,
    FsboRaw,
    FsboLead,
    Pipeline,
    PipelineRun,
    PipelineRunEvent,
)
from nextdeal_datalake.zones import RawZone, StagingZone, CuratedZone
from nextdeal_datalake.pipelines import PipelineManager


class DataLakeClient:
    """
    Unified client for Data Lake operations.
    
    Provides zone-based operations and pipeline tracking.
    """
    
    def __init__(
        self,
        supabase_url: Optional[str] = None,
        supabase_key: Optional[str] = None,
    ):
        """
        Initialize the Data Lake client.
        
        Args:
            supabase_url: Supabase project URL. If None, uses SUPABASE_URL env var.
            supabase_key: Supabase service role key. If None, uses SUPABASE_KEY env var.
        """
        url = supabase_url or os.environ.get("SUPABASE_URL")
        key = supabase_key or os.environ.get("SUPABASE_KEY")
        
        if not url or not key:
            raise ValueError(
                "Supabase URL and key must be provided either as parameters "
                "or via SUPABASE_URL and SUPABASE_KEY environment variables"
            )
        
        self._client: Client = create_client(url, key)
        
        # Initialize zone managers
        self.raw = RawZone(self._client)
        self.staging = StagingZone(self._client)
        self.curated = CuratedZone(self._client)
        
        # Initialize pipeline manager
        self.pipelines = PipelineManager(self._client)
    
    @property
    def client(self) -> Client:
        """Get the underlying Supabase client."""
        return self._client


