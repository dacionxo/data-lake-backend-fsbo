"""
Configuration Loader for Data-Lake-Backend

Loads pipeline configuration from YAML/JSON files and environment variables.
Can also fetch feature flags from Supabase.
"""
import os
import json
import yaml
from typing import Dict, Any, Optional
from pathlib import Path


def load_yaml_config(config_path: Optional[str] = None) -> Dict[str, Any]:
    """
    Load configuration from YAML file.
    
    Args:
        config_path: Path to config file. Defaults to config/pipeline-config.yaml
        
    Returns:
        Configuration dictionary
    """
    if config_path is None:
        config_path = Path(__file__).parent / "pipeline-config.yaml"
    
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)


def load_json_config(config_path: Optional[str] = None) -> Dict[str, Any]:
    """
    Load configuration from JSON file.
    
    Args:
        config_path: Path to config file. Defaults to config/pipeline-config.json
        
    Returns:
        Configuration dictionary
    """
    if config_path is None:
        config_path = Path(__file__).parent / "pipeline-config.json"
    
    with open(config_path, 'r') as f:
        return json.load(f)


def get_config(use_yaml: bool = True) -> Dict[str, Any]:
    """
    Get pipeline configuration.
    
    Args:
        use_yaml: If True, load from YAML, else from JSON
        
    Returns:
        Configuration dictionary with environment variable overrides
    """
    # Load base config
    if use_yaml:
        config = load_yaml_config()
    else:
        config = load_json_config()
    
    # Override with environment variables if they exist
    # Regions
    if os.getenv("AWS_REGIONS"):
        config["regions"]["aws"] = os.getenv("AWS_REGIONS").split(",")
    if os.getenv("TARGET_STATES"):
        config["regions"]["target_states"] = os.getenv("TARGET_STATES").split(",")
    
    # Batch sizes
    if os.getenv("SCRAPER_FETCH_BATCH_SIZE"):
        config["batch"]["scraper"]["fetch_batch_size"] = int(os.getenv("SCRAPER_FETCH_BATCH_SIZE"))
    if os.getenv("SCRAPER_SAVE_BATCH_SIZE"):
        config["batch"]["scraper"]["save_batch_size"] = int(os.getenv("SCRAPER_SAVE_BATCH_SIZE"))
    if os.getenv("SCRAPER_MAX_WORKERS"):
        config["batch"]["scraper"]["max_workers"] = int(os.getenv("SCRAPER_MAX_WORKERS"))
    
    # Feature flags from env
    if os.getenv("FEATURE_IP_ROTATION"):
        config["features"]["enable_ip_rotation"] = os.getenv("FEATURE_IP_ROTATION").lower() == "true"
    if os.getenv("FEATURE_ENRICHMENT"):
        config["features"]["enable_enrichment"] = os.getenv("FEATURE_ENRICHMENT").lower() == "true"
    
    return config


def get_feature_flag(
    flag_key: str,
    supabase_client=None,
    user_id: Optional[str] = None,
    environment: str = "production"
) -> bool:
    """
    Get feature flag value from Supabase.
    
    Args:
        flag_key: Feature flag key
        supabase_client: Supabase client instance (optional)
        user_id: User ID for targeting (optional)
        environment: Environment name (default: production)
        
    Returns:
        True if feature is enabled, False otherwise
    """
    if supabase_client is None:
        # Fallback to environment variable
        env_key = f"FEATURE_{flag_key.upper()}"
        if os.getenv(env_key):
            return os.getenv(env_key).lower() == "true"
        return False
    
    try:
        result = supabase_client.rpc(
            'is_feature_enabled',
            {
                'p_flag_key': flag_key,
                'p_user_id': user_id,
                'p_environment': environment
            }
        ).execute()
        return result.data if isinstance(result.data, bool) else False
    except Exception:
        # Fallback to False if query fails
        return False


# Convenience function for common config access
def get_pipeline_config(pipeline_name: str) -> Dict[str, Any]:
    """Get configuration for a specific pipeline."""
    config = get_config()
    return config.get("pipelines", {}).get(pipeline_name, {})


def get_table_name(zone: str, table_key: str) -> str:
    """Get table name from configuration."""
    config = get_config()
    return config.get("tables", {}).get(zone, {}).get(table_key, table_key)


