"""
Type-safe models for Data Lake tables.

These models map directly to Supabase tables and provide validation.
"""
from typing import Optional, List, Dict, Any
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field


class RawRedfinResponse(BaseModel):
    """Model for raw_redfin_responses table (RAW ZONE)."""
    id: Optional[UUID] = None
    response_data: Dict[str, Any]
    url: str
    status_code: Optional[int] = None
    response_headers: Optional[Dict[str, Any]] = None
    scraped_at: Optional[datetime] = Field(default_factory=datetime.now)
    pipeline_run_id: Optional[UUID] = None
    processed: bool = False
    processed_at: Optional[datetime] = None
    error_message: Optional[str] = None
    created_at: Optional[datetime] = Field(default_factory=datetime.now)

    class Config:
        json_schema_extra = {
            "example": {
                "response_data": {"property": "data"},
                "url": "https://www.redfin.com/CA/Los-Angeles/123-Main-St",
            }
        }


class FsboRaw(BaseModel):
    """Model for fsbo_raw table (STAGING ZONE)."""
    id: Optional[UUID] = None
    listing_id: Optional[str] = None
    property_url: Optional[str] = None
    raw_response_id: Optional[UUID] = None
    pipeline_run_id: Optional[UUID] = None
    street: Optional[str] = None
    unit: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zip_code: Optional[str] = None
    beds: Optional[int] = None
    full_baths: Optional[int] = None
    half_baths: Optional[int] = None
    sqft: Optional[int] = None
    year_built: Optional[int] = None
    list_price: Optional[int] = None
    status: Optional[str] = None
    mls: Optional[str] = None
    agent_name: Optional[str] = None
    agent_email: Optional[str] = None
    agent_phone: Optional[str] = None
    raw_data: Optional[Dict[str, Any]] = None
    normalized: bool = False
    normalized_at: Optional[datetime] = None
    enriched: bool = False
    enriched_at: Optional[datetime] = None
    validated: bool = False
    validated_at: Optional[datetime] = None
    error_message: Optional[str] = None
    created_at: Optional[datetime] = Field(default_factory=datetime.now)
    updated_at: Optional[datetime] = Field(default_factory=datetime.now)


class FsboLead(BaseModel):
    """Model for fsbo_leads table (CURATED ZONE)."""
    # This would map to the actual fsbo_leads table structure
    # Simplified for now - expand based on actual schema
    listing_id: str
    property_url: str
    # Add other fields from complete_schema.sql as needed
    created_at: Optional[datetime] = Field(default_factory=datetime.now)
    updated_at: Optional[datetime] = Field(default_factory=datetime.now)


class Pipeline(BaseModel):
    """Model for pipelines table."""
    id: Optional[UUID] = None
    name: str
    description: Optional[str] = None
    pipeline_type: str = Field(..., pattern="^(scraper|enrichment|geocoding|import|transformation|validation|sync)$")
    source_zone: str = Field(..., pattern="^(raw|staging|curated|external)$")
    target_zone: str = Field(..., pattern="^(raw|staging|curated)$")
    source_tables: Optional[List[str]] = None
    target_tables: Optional[List[str]] = None
    config: Optional[Dict[str, Any]] = None
    enabled: bool = True
    schedule_cron: Optional[str] = None
    created_at: Optional[datetime] = Field(default_factory=datetime.now)
    updated_at: Optional[datetime] = Field(default_factory=datetime.now)
    created_by: Optional[UUID] = None


class PipelineRun(BaseModel):
    """Model for pipeline_runs table."""
    id: Optional[UUID] = None
    pipeline_id: UUID
    status: str = Field(default="running", pattern="^(queued|running|completed|failed|cancelled|timeout)$")
    started_at: Optional[datetime] = Field(default_factory=datetime.now)
    completed_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    records_processed: int = 0
    records_succeeded: int = 0
    records_failed: int = 0
    error_message: Optional[str] = None
    error_stack: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    triggered_by: Optional[str] = None
    triggered_by_user_id: Optional[UUID] = None
    created_at: Optional[datetime] = Field(default_factory=datetime.now)


class PipelineRunEvent(BaseModel):
    """Model for pipeline_run_events table."""
    id: Optional[UUID] = None
    pipeline_run_id: UUID
    event_type: str = Field(..., pattern="^(start|progress|milestone|warning|error|checkpoint|complete|fail|cancel)$")
    event_level: str = Field(default="info", pattern="^(debug|info|warning|error|critical)$")
    message: str
    details: Optional[Dict[str, Any]] = None
    occurred_at: Optional[datetime] = Field(default_factory=datetime.now)


