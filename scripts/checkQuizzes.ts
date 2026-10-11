import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_KEY!);

async function run() {
  const { data: quizzes } = await supabase.from('quizzes').select('id, title, category');
  console.log('Total Quizzes:', quizzes?.length);
  for (const q of (quizzes || [])) {
    const { data: qs } = await supabase.from('questions').select('id, question_text').eq('quiz_id', q.id);
    console.log(`Quiz [${q.title}] (cat: ${q.category}) has ${qs?.length || 0} questions`);
  }
}

run().catch(console.error);
