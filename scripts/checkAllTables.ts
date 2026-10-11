import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

async function main() {
  const url = process.env.SUPABASE_URL || '';
  const key = process.env.SUPABASE_KEY || '';
  const supabase = createClient(url, key);

  const tables = ['users', 'quizzes', 'questions', 'active_sessions', 'quiz_attempts', 'authorized_groups', 'bot_settings', 'user_mistakes', 'referrals', 'duels', 'user_streaks'];
  for (const t of tables) {
    const { data, error } = await supabase.from(t).select('*').limit(1);
    console.log(`${t}: ${error ? 'MISSING (' + error.code + ' - ' + error.message + ')' : 'EXISTS (count: ' + (data ? data.length : 0) + ')'}`);
  }
}

main().catch(console.error);
