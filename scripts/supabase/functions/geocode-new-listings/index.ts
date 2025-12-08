/**
 * Supabase Edge Function to geocode new listings
 * 
 * This function:
 * 1. Finds listings with missing lat/lng coordinates
 * 2. Geocodes their addresses using Mapbox or Google Geocoding API
 * 3. Updates the listings with coordinates
 * 
 * Can be called:
 * - Manually via API
 * - Scheduled via Supabase Cron (pg_cron)
 * 
 * Usage:
 *   supabase functions invoke geocode-new-listings
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface GeocodeResult {
  lat: number;
  lng: number;
}

/**
 * Build address string from listing data
 */
function buildAddress(listing: any): string {
  const parts = [
    listing.address || listing.street,
    listing.unit,
    listing.city,
    listing.state,
    listing.zip || listing.zip_code || listing.postal_code,
  ]
    .filter(Boolean)
    .map((v) => String(v).trim());

  return parts.join(', ');
}

/**
 * Geocode using Mapbox
 */
async function geocodeWithMapbox(
  address: string,
  mapboxToken: string
): Promise<GeocodeResult | null> {
  try {
    const query = encodeURIComponent(address.trim());
    const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${query}.json?access_token=${mapboxToken}&limit=1`;

    const res = await fetch(url);
    if (!res.ok) return null;

    const data = await res.json();
    if (!data.features?.length) return null;

    const [lng, lat] = data.features[0].center;
    return { lat, lng };
  } catch (error) {
    console.error('Mapbox geocoding error:', error);
    return null;
  }
}

/**
 * Geocode using Google
 */
async function geocodeWithGoogle(
  address: string,
  apiKey: string
): Promise<GeocodeResult | null> {
  try {
    const query = encodeURIComponent(address.trim());
    const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${query}&key=${apiKey}`;

    const res = await fetch(url);
    if (!res.ok) return null;

    const data = await res.json();
    if (data.status !== 'OK' || !data.results?.length) return null;

    const location = data.results[0].geometry.location;
    return { lat: location.lat, lng: location.lng };
  } catch (error) {
    console.error('Google geocoding error:', error);
    return null;
  }
}

/**
 * Geocode an address using available provider
 */
async function geocodeAddress(
  address: string,
  mapboxToken?: string,
  googleApiKey?: string
): Promise<GeocodeResult | null> {
  if (mapboxToken) {
    const result = await geocodeWithMapbox(address, mapboxToken);
    if (result) return result;
  }

  if (googleApiKey) {
    const result = await geocodeWithGoogle(address, googleApiKey);
    if (result) return result;
  }

  return null;
}

/**
 * Process a single table
 */
async function processTable(
  supabase: any,
  table: string,
  primaryKey: string,
  mapboxToken?: string,
  googleApiKey?: string,
  limit: number = 50
): Promise<{ processed: number; updated: number; failed: number }> {
  let processed = 0;
  let updated = 0;
  let failed = 0;

  // Get rows missing coordinates
  const { data, error } = await supabase
    .from(table)
    .select('*')
    .or('lat.is.null,lng.is.null')
    .not('street', 'is', null)
    .not('city', 'is', null)
    .limit(limit);

  if (error) {
    console.error(`Error fetching from ${table}:`, error);
    return { processed, updated, failed };
  }

  if (!data || data.length === 0) {
    return { processed, updated, failed };
  }

  for (const row of data) {
    processed++;

    const address = buildAddress(row);
    if (!address || address.trim().length === 0) {
      failed++;
      continue;
    }

    try {
      const coords = await geocodeAddress(address, mapboxToken, googleApiKey);
      if (!coords) {
        failed++;
        continue;
      }

      const idField = row[primaryKey] ? primaryKey : 'id';
      const idValue = row[idField];

      if (!idValue) {
        failed++;
        continue;
      }

      const { error: updateError } = await supabase
        .from(table)
        .update({
          lat: coords.lat,
          lng: coords.lng,
        })
        .eq(idField, idValue);

      if (updateError) {
        console.error(`Update failed for ${table} ${idField}=${idValue}:`, updateError);
        failed++;
      } else {
        updated++;
      }

      // Rate limiting: 100ms delay
      await new Promise((r) => setTimeout(r, 100));
    } catch (e) {
      console.error(`Geocode error for ${address}:`, e);
      failed++;
    }
  }

  return { processed, updated, failed };
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const mapboxToken = Deno.env.get('NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN');
    const googleApiKey = Deno.env.get('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration');
    }

    if (!mapboxToken && !googleApiKey) {
      throw new Error('Missing geocoding API key (Mapbox or Google)');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const tables = [
      { name: 'listings', primaryKey: 'listing_id' },
      { name: 'expired_listings', primaryKey: 'listing_id' },
      { name: 'fsbo_leads', primaryKey: 'listing_id' },
      { name: 'frbo_leads', primaryKey: 'listing_id' },
      { name: 'foreclosure_listings', primaryKey: 'listing_id' },
      { name: 'imports', primaryKey: 'listing_id' },
      { name: 'probate_leads', primaryKey: 'listing_id' },
      { name: 'trash', primaryKey: 'listing_id' },
    ];

    const results: Record<string, any> = {};
    let totalProcessed = 0;
    let totalUpdated = 0;
    let totalFailed = 0;

    for (const table of tables) {
      const result = await processTable(
        supabase,
        table.name,
        table.primaryKey,
        mapboxToken,
        googleApiKey,
        50 // Process 50 rows per table per run
      );

      results[table.name] = result;
      totalProcessed += result.processed;
      totalUpdated += result.updated;
      totalFailed += result.failed;
    }

    return new Response(
      JSON.stringify({
        success: true,
        summary: {
          totalProcessed,
          totalUpdated,
          totalFailed,
        },
        details: results,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});

