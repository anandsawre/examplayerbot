import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

async function main() {
  const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_KEY!);
  const { data, error } = await supabase.from('authorized_groups').select('*').limit(1);
  if (error) {
    console.log('TABLE_STATUS: NOT_EXISTS ->', error.message);
  } else {
    console.log('TABLE_STATUS: EXISTS');
  }
}

main().catch(console.error);
