"""
Supabase Client Module

Wrapper around the supabase_client.py functionality.
This module will be enhanced as part of the unified Data Lake SDK.
"""
import sys
from pathlib import Path
from typing import Dict, Any, Optional

# Add parent directory to path to import supabase_client module
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    # Import the existing supabase_client module
    import supabase_client as _supabase_client
    from supabase_client import (
        supabase,
        SUPABASE_URL,
        SUPABASE_KEY,
        FIELD_MAPPINGS,
        save_lead_to_supabase,
    )
except ImportError:
    _supabase_client = None
    supabase = None
    SUPABASE_URL = None
    SUPABASE_KEY = None
    FIELD_MAPPINGS = {}
    save_lead_to_supabase = None


class SupabaseClient:
    """
    Supabase Client wrapper for Data Lake operations.
    
    This class provides a programmatic interface to Supabase database
    operations. It will be enhanced as part of the unified Data Lake SDK.
    """
    
    def __init__(self, url: Optional[str] = None, key: Optional[str] = None):
        """
        Initialize Supabase client.
        
        Args:
            url: Supabase project URL. If None, uses environment variable.
            key: Supabase service role key. If None, uses environment variable.
        """
        if url:
            self.url = url
        else:
            self.url = SUPABASE_URL
        
        if key:
            self.key = key
        else:
            self.key = SUPABASE_KEY
        
        self._client = supabase
        self.field_mappings = FIELD_MAPPINGS
    
    def save_lead(self, lead_data: Dict[str, Any]) -> bool:
        """
        Save a lead to Supabase.
        
        Args:
            lead_data: Dictionary containing lead information
            
        Returns:
            True if successful, False otherwise
        """
        if save_lead_to_supabase is None:
            raise RuntimeError("Supabase client module not available")
        
        return save_lead_to_supabase(lead_data)
    
    @property
    def client(self):
        """Get the underlying Supabase client."""
        return self._client


__all__ = ["SupabaseClient", "supabase", "save_lead_to_supabase"]


