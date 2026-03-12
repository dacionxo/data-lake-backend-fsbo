/**
 * Type-safe models for Data Lake tables.
 * 
 * These models map directly to Supabase tables and provide validation.
 */
import { z } from 'zod';

export const RawRedfinResponseSchema = z.object({
  id: z.string().uuid().optional(),
  response_data: z.record(z.any()),
  url: z.string(),
  status_code: z.number().optional(),
  response_headers: z.record(z.any()).optional(),
  scraped_at: z.string().datetime().optional(),
  pipeline_run_id: z.string().uuid().optional(),
  processed: z.boolean().default(false),
  processed_at: z.string().datetime().optional(),
  error_message: z.string().optional(),
  created_at: z.string().datetime().optional(),
});

export type RawRedfinResponse = z.infer<typeof RawRedfinResponseSchema>;

export const FsboRawSchema = z.object({
  id: z.string().uuid().optional(),
  listing_id: z.string().optional(),
  property_url: z.string().optional(),
  raw_response_id: z.string().uuid().optional(),
  pipeline_run_id: z.string().uuid().optional(),
  street: z.string().optional(),
  unit: z.string().optional(),
  city: z.string().optional(),
  state: z.string().optional(),
  zip_code: z.string().optional(),
  beds: z.number().optional(),
  full_baths: z.number().optional(),
  half_baths: z.number().optional(),
  sqft: z.number().optional(),
  year_built: z.number().optional(),
  list_price: z.number().optional(),
  status: z.string().optional(),
  mls: z.string().optional(),
  agent_name: z.string().optional(),
  agent_email: z.string().optional(),
  agent_phone: z.string().optional(),
  raw_data: z.record(z.any()).optional(),
  normalized: z.boolean().default(false),
  normalized_at: z.string().datetime().optional(),
  enriched: z.boolean().default(false),
  enriched_at: z.string().datetime().optional(),
  validated: z.boolean().default(false),
  validated_at: z.string().datetime().optional(),
  error_message: z.string().optional(),
  created_at: z.string().datetime().optional(),
  updated_at: z.string().datetime().optional(),
});

export type FsboRaw = z.infer<typeof FsboRawSchema>;

export const PipelineRunSchema = z.object({
  id: z.string().uuid().optional(),
  pipeline_id: z.string().uuid(),
  status: z.enum(['queued', 'running', 'completed', 'failed', 'cancelled', 'timeout']).default('running'),
  started_at: z.string().datetime().optional(),
  completed_at: z.string().datetime().optional(),
  duration_seconds: z.number().optional(),
  records_processed: z.number().default(0),
  records_succeeded: z.number().default(0),
  records_failed: z.number().default(0),
  error_message: z.string().optional(),
  error_stack: z.string().optional(),
  metadata: z.record(z.any()).optional(),
  triggered_by: z.string().optional(),
  triggered_by_user_id: z.string().uuid().optional(),
  created_at: z.string().datetime().optional(),
});

export type PipelineRun = z.infer<typeof PipelineRunSchema>;

export const PipelineRunEventSchema = z.object({
  id: z.string().uuid().optional(),
  pipeline_run_id: z.string().uuid(),
  event_type: z.enum(['start', 'progress', 'milestone', 'warning', 'error', 'checkpoint', 'complete', 'fail', 'cancel']),
  event_level: z.enum(['debug', 'info', 'warning', 'error', 'critical']).default('info'),
  message: z.string(),
  details: z.record(z.any()).optional(),
  occurred_at: z.string().datetime().optional(),
});

export type PipelineRunEvent = z.infer<typeof PipelineRunEventSchema>;


