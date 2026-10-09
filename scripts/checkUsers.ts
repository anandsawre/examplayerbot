import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

async function main() {
  const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_KEY!);
  const { data, error } = await supabase.from('users').select('id, first_name, username');
  if (error) {
    console.error('Error fetching users:', error);
  } else {
    console.log('USERS_FOUND:', JSON.stringify(data, null, 2));
  }
}

main().catch(console.error);
