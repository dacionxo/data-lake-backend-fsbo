"""
NextDeal Data Lake SDK

Unified SDK for Data Lake operations on Supabase.
"""

__version__ = "0.1.0"

from nextdeal_datalake.client import DataLakeClient
from nextdeal_datalake.models import (
    RawRedfinResponse,
    FsboRaw,
    FsboLead,
    Pipeline,
    PipelineRun,
    PipelineRunEvent,
)

__all__ = [
    "DataLakeClient",
    "RawRedfinResponse",
    "FsboRaw",
    "FsboLead",
    "Pipeline",
    "PipelineRun",
    "PipelineRunEvent",
    "__version__",
]


