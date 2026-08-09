import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const isSupabaseConfigured = Boolean(
  supabaseUrl &&
    supabaseAnonKey &&
    !supabaseAnonKey.includes('replace-with')
);

export const supabase = createClient(
  supabaseUrl ?? 'https://zptyyrunbshsxdhiuuhq.supabase.co',
  supabaseAnonKey ?? 'missing-anon-key'
);
