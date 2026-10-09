import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';

let cachedClient: SupabaseClient | null = null;
let lastUrl = '';
let lastKey = '';

export function getSupabase(env: Env): SupabaseClient {
  const url = env.SUPABASE_URL;
  const key = env.SUPABASE_KEY;

  if (!url || !key) {
    throw new Error('SUPABASE_URL and SUPABASE_KEY are required in environment variables!');
  }

  // Reuse instance if parameters haven't changed
  if (cachedClient && lastUrl === url && lastKey === key) {
    return cachedClient;
  }

  cachedClient = createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  lastUrl = url;
  lastKey = key;

  return cachedClient;
}
