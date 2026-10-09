import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

async function main() {
  const url = process.env.SUPABASE_URL || '';
  const key = process.env.SUPABASE_KEY || '';

  console.log('Testing connection to:', url);
  const supabase = createClient(url, key);

  const { data, error } = await supabase.from('quizzes').select('*');
  if (error) {
    console.log('RESULT: ERROR ->', error.message);
  } else {
    console.log('RESULT: SUCCESS! Total quizzes in DB:', data.length);
  }
}

main().catch(console.error);
