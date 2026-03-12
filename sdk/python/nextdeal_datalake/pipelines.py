"""
Pipeline management operations.

Provides functionality for tracking pipeline runs and events.
"""
from typing import Optional, Dict, Any
from uuid import UUID
from supabase import Client

from nextdeal_datalake.models import Pipeline, PipelineRun, PipelineRunEvent


class PipelineManager:
    """Manages pipeline runs and events."""
    
    def __init__(self, client: Client):
        self._client = client
    
    def start_run(
        self,
        pipeline_name: str,
        triggered_by: str = "manual",
        user_id: Optional[UUID] = None,
    ) -> PipelineRun:
        """
        Start a new pipeline run.
        
        Args:
            pipeline_name: Name of the pipeline
            triggered_by: How it was triggered (manual, scheduled, api, etc.)
            user_id: Optional user ID who triggered it
            
        Returns:
            PipelineRun instance
        """
        # Get pipeline ID
        pipeline_result = self._client.table("pipelines") \
            .select("id") \
            .eq("name", pipeline_name) \
            .single() \
            .execute()
        
        pipeline_id = UUID(pipeline_result.data["id"])
        
        # Create run
        run_data = {
            "pipeline_id": str(pipeline_id),
            "status": "running",
            "triggered_by": triggered_by,
            "triggered_by_user_id": str(user_id) if user_id else None,
        }
        
        result = self._client.table("pipeline_runs").insert(run_data).execute()
        
        # Log start event
        self.log_event(
            UUID(result.data[0]["id"]),
            "start",
            f"Pipeline run started: {pipeline_name}",
            level="info",
        )
        
        return PipelineRun(**result.data[0])
    
    def log_event(
        self,
        pipeline_run_id: UUID,
        event_type: str,
        message: str,
        level: str = "info",
        details: Optional[Dict[str, Any]] = None,
    ) -> PipelineRunEvent:
        """
        Log an event for a pipeline run.
        
        Args:
            pipeline_run_id: ID of the pipeline run
            event_type: Type of event
            message: Event message
            level: Event level (debug, info, warning, error, critical)
            details: Optional additional details
            
        Returns:
            PipelineRunEvent instance
        """
        event_data = {
            "pipeline_run_id": str(pipeline_run_id),
            "event_type": event_type,
            "event_level": level,
            "message": message,
            "details": details or {},
        }
        
        result = self._client.table("pipeline_run_events").insert(event_data).execute()
        return PipelineRunEvent(**result.data[0])
    
    def update_progress(
        self,
        pipeline_run_id: UUID,
        records_processed: int,
        records_succeeded: int = 0,
        records_failed: int = 0,
    ) -> None:
        """Update progress for a pipeline run."""
        self._client.table("pipeline_runs") \
            .update({
                "records_processed": records_processed,
                "records_succeeded": records_succeeded,
                "records_failed": records_failed,
            }) \
            .eq("id", str(pipeline_run_id)) \
            .execute()
    
    def complete_run(
        self,
        pipeline_run_id: UUID,
        records_processed: Optional[int] = None,
        records_succeeded: Optional[int] = None,
        records_failed: Optional[int] = None,
    ) -> None:
        """
        Mark a pipeline run as completed.
        
        Args:
            pipeline_run_id: ID of the pipeline run
            records_processed: Total records processed
            records_succeeded: Records that succeeded
            records_failed: Records that failed
        """
        update_data = {"status": "completed"}
        
        if records_processed is not None:
            update_data["records_processed"] = records_processed
        if records_succeeded is not None:
            update_data["records_succeeded"] = records_succeeded
        if records_failed is not None:
            update_data["records_failed"] = records_failed
        
        self._client.table("pipeline_runs") \
            .update(update_data) \
            .eq("id", str(pipeline_run_id)) \
            .execute()
        
        self.log_event(
            pipeline_run_id,
            "complete",
            "Pipeline run completed successfully",
            level="info",
        )
    
    def fail_run(
        self,
        pipeline_run_id: UUID,
        error_message: str,
        error_stack: Optional[str] = None,
    ) -> None:
        """
        Mark a pipeline run as failed.
        
        Args:
            pipeline_run_id: ID of the pipeline run
            error_message: Error message
            error_stack: Optional error stack trace
        """
        update_data = {
            "status": "failed",
            "error_message": error_message,
        }
        if error_stack:
            update_data["error_stack"] = error_stack
        
        self._client.table("pipeline_runs") \
            .update(update_data) \
            .eq("id", str(pipeline_run_id)) \
            .execute()
        
        self.log_event(
            pipeline_run_id,
            "fail",
            f"Pipeline run failed: {error_message}",
            level="error",
            details={"error_stack": error_stack} if error_stack else None,
        )


