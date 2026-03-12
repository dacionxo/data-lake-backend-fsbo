/**
 * Configuration loader for LeadMap-main
 * 
 * Loads pipeline configuration and feature flags from Supabase.
 */

import { SupabaseClient } from '@supabase/supabase-js';
import { defaultConfig, PipelineConfig, getConfig } from '../../config/pipeline-config';

export interface FeatureFlagResult {
  enabled: boolean;
  flag_key: string;
  category?: string;
}

/**
 * Get pipeline configuration with environment variable overrides
 */
export function getPipelineConfig(): PipelineConfig {
  return getConfig();
}

/**
 * Check if a feature flag is enabled
 */
export async function isFeatureEnabled(
  flagKey: string,
  supabase: SupabaseClient,
  userId?: string,
  userRole?: string,
  environment: string = 'production'
): Promise<boolean> {
  try {
    const { data, error } = await supabase.rpc('is_feature_enabled', {
      p_flag_key: flagKey,
      p_user_id: userId || null,
      p_user_role: userRole || null,
      p_environment: environment,
    });

    if (error) {
      console.error(`Error checking feature flag ${flagKey}:`, error);
      // Fallback to environment variable
      const envKey = `FEATURE_${flagKey.toUpperCase()}`;
      return process.env[envKey] === 'true';
    }

    return data === true;
  } catch (error) {
    console.error(`Exception checking feature flag ${flagKey}:`, error);
    // Fallback to environment variable
    const envKey = `FEATURE_${flagKey.toUpperCase()}`;
    return process.env[envKey] === 'true';
  }
}

/**
 * Get all enabled feature flags for an environment
 */
export async function getEnabledFeatures(
  supabase: SupabaseClient,
  userId?: string,
  userRole?: string,
  environment: string = 'production'
): Promise<FeatureFlagResult[]> {
  try {
    const { data, error } = await supabase.rpc('get_enabled_features', {
      p_environment: environment,
      p_user_id: userId || null,
      p_user_role: userRole || null,
    });

    if (error) {
      console.error('Error getting enabled features:', error);
      return [];
    }

    return (data || []).map((item: any) => ({
      enabled: item.flag_value === true,
      flag_key: item.flag_key,
      category: item.category,
    }));
  } catch (error) {
    console.error('Exception getting enabled features:', error);
    return [];
  }
}

/**
 * Get configuration for a specific pipeline
 */
export function getPipelineConfigByName(pipelineName: string) {
  const config = getPipelineConfig();
  return config.pipelines[pipelineName] || null;
}

/**
 * Get table name from configuration
 */
export function getTableName(zone: 'raw' | 'staging' | 'curated', tableKey: string): string {
  const config = getPipelineConfig();
  return config.tables[zone]?.[tableKey] || tableKey;
}


