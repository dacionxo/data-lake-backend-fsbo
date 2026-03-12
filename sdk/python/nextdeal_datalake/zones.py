"""
Zone-based operations for Data Lake.

Each zone (raw, staging, curated) has its own operations manager.
"""
from typing import Optional, Dict, Any, List
from uuid import UUID
from supabase import Client

from nextdeal_datalake.models import RawRedfinResponse, FsboRaw, FsboLead


class RawZone:
    """Operations for RAW ZONE tables."""
    
    def __init__(self, client: Client):
        self._client = client
    
    def save_redfin_response(
        self,
        response_data: Dict[str, Any],
        url: str,
        pipeline_run_id: Optional[UUID] = None,
    ) -> RawRedfinResponse:
        """
        Save a raw Redfin response to the raw zone.
        
        Args:
            response_data: Raw JSON response from Redfin
            url: URL that was scraped
            pipeline_run_id: Optional pipeline run ID for tracking
            
        Returns:
            Saved RawRedfinResponse record
        """
        data = {
            "response_data": response_data,
            "url": url,
            "pipeline_run_id": str(pipeline_run_id) if pipeline_run_id else None,
        }
        
        result = self._client.table("raw_redfin_responses").insert(data).execute()
        return RawRedfinResponse(**result.data[0])
    
    def get_unprocessed_responses(self, limit: int = 100) -> List[RawRedfinResponse]:
        """Get unprocessed raw responses."""
        result = self._client.table("raw_redfin_responses") \
            .select("*") \
            .eq("processed", False) \
            .limit(limit) \
            .execute()
        
        return [RawRedfinResponse(**item) for item in result.data]
    
    def mark_processed(self, response_id: UUID, error: Optional[str] = None) -> None:
        """Mark a raw response as processed."""
        update_data = {
            "processed": True,
            "processed_at": "now()",
        }
        if error:
            update_data["error_message"] = error
        
        self._client.table("raw_redfin_responses") \
            .update(update_data) \
            .eq("id", str(response_id)) \
            .execute()


class StagingZone:
    """Operations for STAGING ZONE tables."""
    
    def __init__(self, client: Client):
        self._client = client
    
    def save_fsbo_raw(
        self,
        data: Dict[str, Any],
        pipeline_run_id: Optional[UUID] = None,
        raw_response_id: Optional[UUID] = None,
    ) -> FsboRaw:
        """
        Save normalized FSBO data to staging.
        
        Args:
            data: Normalized FSBO data
            pipeline_run_id: Optional pipeline run ID
            raw_response_id: Optional link to raw response
            
        Returns:
            Saved FsboRaw record
        """
        insert_data = {**data}
        if pipeline_run_id:
            insert_data["pipeline_run_id"] = str(pipeline_run_id)
        if raw_response_id:
            insert_data["raw_response_id"] = str(raw_response_id)
        
        result = self._client.table("fsbo_raw").insert(insert_data).execute()
        return FsboRaw(**result.data[0])
    
    def get_unenriched(self, limit: int = 100) -> List[FsboRaw]:
        """Get FSBO raw records that haven't been enriched."""
        result = self._client.table("fsbo_raw") \
            .select("*") \
            .eq("enriched", False) \
            .limit(limit) \
            .execute()
        
        return [FsboRaw(**item) for item in result.data]


class CuratedZone:
    """Operations for CURATED ZONE tables."""
    
    def __init__(self, client: Client):
        self._client = client
    
    def save_fsbo_lead(self, lead_data: Dict[str, Any]) -> FsboLead:
        """
        Save an enriched FSBO lead to curated zone.
        
        Args:
            lead_data: Enriched lead data
            
        Returns:
            Saved FsboLead record
        """
        result = self._client.table("fsbo_leads").insert(lead_data).execute()
        # Note: This will need to be adjusted based on actual fsbo_leads schema
        return FsboLead(**result.data[0])


