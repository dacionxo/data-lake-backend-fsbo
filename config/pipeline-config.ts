/**
 * NextDeal Data Lake Pipeline Configuration
 * 
 * This TypeScript config ensures type safety and can be used by Next.js API routes.
 * Loads from YAML/JSON and environment variables.
 */

export interface PipelineConfig {
  regions: {
    aws: string[];
    target_states: string[];
  };
  batch: {
    scraper: {
      fetch_batch_size: number;
      save_batch_size: number;
      max_workers: number;
    };
    enrichment: {
      concurrency_limit: number;
      batch_size: number;
    };
    geocoding: {
      batch_size: number;
      max_concurrent: number;
    };
  };
  delays: {
    scraper: {
      between_requests: number;
      between_batches: number;
      retry_delay: number;
    };
    enrichment: {
      between_requests: number;
      rate_limit_window: number;
      rate_limit_requests: number;
    };
    geocoding: {
      between_requests: number;
      free_tier_delay: number;
      paid_tier_delay: number;
    };
  };
  tables: {
    raw: {
      redfin_responses: string;
      csv_imports: string;
      apollo_imports: string;
    };
    staging: {
      fsbo_raw: string;
      import_staging: string;
    };
    curated: {
      listings: string;
      fsbo_leads: string;
      expired_listings: string;
      frbo_leads: string;
      foreclosure_listings: string;
      imports: string;
      contacts: string;
      deals: string;
      tasks: string;
      lists: string;
      list_items: string;
    };
  };
  pipelines: Record<
    string,
    {
      name: string;
      type: string;
      source_zone: string;
      target_zone: string;
      source_tables: string[];
      target_tables: string[];
      enabled: boolean;
      schedule: string | null;
    }
  >;
  features: {
    enable_ip_rotation: boolean;
    enable_aws_proxy: boolean;
    enable_enrichment: boolean;
    enable_geocoding: boolean;
    enable_skip_tracing: boolean;
    enable_batch_processing: boolean;
    enable_error_retry: boolean;
    enable_debug_logging: boolean;
  };
  logging: {
    level: string;
    file_path: string;
    max_file_size_mb: number;
    backup_count: number;
    console_output: boolean;
  };
  errors: {
    max_retries: number;
    retry_exponential_backoff: boolean;
    retry_base_delay: number;
    max_error_rate: number;
    error_notification_threshold: number;
  };
}

// Default configuration
export const defaultConfig: PipelineConfig = {
  regions: {
    aws: ["us-east-1", "us-west-2", "us-east-2", "eu-west-1"],
    target_states: [
      "MN", "IA", "MO", "AR", "DC", "ME", "NH", "VT", "MA", "RI", "CT",
      "NY", "NJ", "PA", "DE", "MD", "VA", "WV", "NC", "SC", "GA",
      "FL", "AL", "MS", "TN", "KY", "OH", "IN", "IL", "WI", "MI", "TX",
    ],
  },
  batch: {
    scraper: {
      fetch_batch_size: parseInt(process.env.SCRAPER_FETCH_BATCH_SIZE || "10"),
      save_batch_size: parseInt(process.env.SCRAPER_SAVE_BATCH_SIZE || "100"),
      max_workers: parseInt(process.env.SCRAPER_MAX_WORKERS || "10"),
    },
    enrichment: {
      concurrency_limit: parseInt(process.env.ENRICHMENT_CONCURRENCY || "8"),
      batch_size: parseInt(process.env.ENRICHMENT_BATCH_SIZE || "50"),
    },
    geocoding: {
      batch_size: parseInt(process.env.GEOCODING_BATCH_SIZE || "100"),
      max_concurrent: parseInt(process.env.GEOCODING_MAX_CONCURRENT || "5"),
    },
  },
  delays: {
    scraper: {
      between_requests: parseFloat(process.env.SCRAPER_DELAY || "1.0"),
      between_batches: parseFloat(process.env.SCRAPER_BATCH_DELAY || "5.0"),
      retry_delay: parseFloat(process.env.SCRAPER_RETRY_DELAY || "30.0"),
    },
    enrichment: {
      between_requests: parseFloat(process.env.ENRICHMENT_DELAY || "2.0"),
      rate_limit_window: parseInt(process.env.ENRICHMENT_RATE_WINDOW || "60"),
      rate_limit_requests: parseInt(process.env.ENRICHMENT_RATE_REQUESTS || "20"),
    },
    geocoding: {
      between_requests: parseFloat(process.env.GEOCODING_DELAY || "1.0"),
      free_tier_delay: parseFloat(process.env.GEOCODING_FREE_DELAY || "1.0"),
      paid_tier_delay: parseFloat(process.env.GEOCODING_PAID_DELAY || "0.1"),
    },
  },
  tables: {
    raw: {
      redfin_responses: process.env.TABLE_RAW_REDFIN || "raw_redfin_responses",
      csv_imports: process.env.TABLE_RAW_CSV || "raw_csv_imports",
      apollo_imports: process.env.TABLE_RAW_APOLLO || "raw_apollo_imports",
    },
    staging: {
      fsbo_raw: process.env.TABLE_STAGING_FSBO || "fsbo_raw",
      import_staging: process.env.TABLE_STAGING_IMPORT || "import_staging",
    },
    curated: {
      listings: process.env.TABLE_CURATED_LISTINGS || "listings",
      fsbo_leads: process.env.TABLE_CURATED_FSBO || "fsbo_leads",
      expired_listings: process.env.TABLE_CURATED_EXPIRED || "expired_listings",
      frbo_leads: process.env.TABLE_CURATED_FRBO || "frbo_leads",
      foreclosure_listings: process.env.TABLE_CURATED_FORECLOSURE || "foreclosure_listings",
      imports: process.env.TABLE_CURATED_IMPORTS || "imports",
      contacts: process.env.TABLE_CURATED_CONTACTS || "contacts",
      deals: process.env.TABLE_CURATED_DEALS || "deals",
      tasks: process.env.TABLE_CURATED_TASKS || "tasks",
      lists: process.env.TABLE_CURATED_LISTS || "lists",
      list_items: process.env.TABLE_CURATED_LIST_ITEMS || "list_items",
    },
  },
  pipelines: {
    redfin_fsbo_scraper: {
      name: "redfin_fsbo_scraper",
      type: "scraper",
      source_zone: "external",
      target_zone: "raw",
      source_tables: [],
      target_tables: ["raw_redfin_responses"],
      enabled: process.env.PIPELINE_REDFIN_ENABLED !== "false",
      schedule: process.env.PIPELINE_REDFIN_SCHEDULE || null,
    },
    fsbo_enrichment: {
      name: "fsbo_enrichment",
      type: "enrichment",
      source_zone: "raw",
      target_zone: "staging",
      source_tables: ["raw_redfin_responses"],
      target_tables: ["fsbo_raw"],
      enabled: process.env.PIPELINE_ENRICHMENT_ENABLED !== "false",
      schedule: process.env.PIPELINE_ENRICHMENT_SCHEDULE || null,
    },
    geocoding_backfill: {
      name: "geocoding_backfill",
      type: "geocoding",
      source_zone: "staging",
      target_zone: "curated",
      source_tables: ["fsbo_raw", "listings"],
      target_tables: ["fsbo_leads", "listings"],
      enabled: process.env.PIPELINE_GEOCODING_ENABLED !== "false",
      schedule: process.env.PIPELINE_GEOCODING_SCHEDULE || "0 2 * * *",
    },
    csv_import: {
      name: "csv_import",
      type: "import",
      source_zone: "external",
      target_zone: "raw",
      source_tables: [],
      target_tables: ["raw_csv_imports"],
      enabled: process.env.PIPELINE_CSV_ENABLED !== "false",
      schedule: process.env.PIPELINE_CSV_SCHEDULE || null,
    },
    apollo_import: {
      name: "apollo_import",
      type: "import",
      source_zone: "external",
      target_zone: "raw",
      source_tables: [],
      target_tables: ["raw_apollo_imports"],
      enabled: process.env.PIPELINE_APOLLO_ENABLED !== "false",
      schedule: process.env.PIPELINE_APOLLO_SCHEDULE || null,
    },
  },
  features: {
    enable_ip_rotation: process.env.FEATURE_IP_ROTATION !== "false",
    enable_aws_proxy: process.env.FEATURE_AWS_PROXY !== "false",
    enable_enrichment: process.env.FEATURE_ENRICHMENT !== "false",
    enable_geocoding: process.env.FEATURE_GEOCODING !== "false",
    enable_skip_tracing: process.env.FEATURE_SKIP_TRACING !== "false",
    enable_batch_processing: process.env.FEATURE_BATCH_PROCESSING !== "false",
    enable_error_retry: process.env.FEATURE_ERROR_RETRY !== "false",
    enable_debug_logging: process.env.FEATURE_DEBUG_LOGGING === "true",
  },
  logging: {
    level: process.env.LOG_LEVEL || "INFO",
    file_path: process.env.LOG_FILE_PATH || "logs/pipeline.log",
    max_file_size_mb: parseInt(process.env.LOG_MAX_SIZE_MB || "100"),
    backup_count: parseInt(process.env.LOG_BACKUP_COUNT || "5"),
    console_output: process.env.LOG_CONSOLE !== "false",
  },
  errors: {
    max_retries: parseInt(process.env.ERROR_MAX_RETRIES || "3"),
    retry_exponential_backoff: process.env.ERROR_EXPONENTIAL_BACKOFF !== "false",
    retry_base_delay: parseFloat(process.env.ERROR_BASE_DELAY || "1.0"),
    max_error_rate: parseFloat(process.env.ERROR_MAX_RATE || "0.1"),
    error_notification_threshold: parseInt(process.env.ERROR_NOTIFICATION_THRESHOLD || "10"),
  },
};

// Export helper function to load config (can be enhanced to load from Supabase feature flags)
export function getConfig(): PipelineConfig {
  // TODO: Load from Supabase feature_flags table to override defaults
  return defaultConfig;
}


