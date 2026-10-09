import 'dotenv/config';
import fs from 'fs';
import path from 'path';
import { createClient } from '@supabase/supabase-js';

async function importQuiz() {
  const filePath = process.argv[2] || 'sample_quiz.json';
  const fullPath = path.resolve(process.cwd(), filePath);

  if (!fs.existsSync(fullPath)) {
    console.error(`❌ File nahi mili: ${fullPath}`);
    process.exit(1);
  }

  const raw = fs.readFileSync(fullPath, 'utf-8');
  const quizData = JSON.parse(raw);

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    console.error('❌ Supabase credentials .env file me nahi hain!');
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log(`⏳ Importing quiz: "${quizData.title}"...`);

  // 1. Insert Quiz into quizzes table
  const { data: quiz, error: quizError } = await supabase
    .from('quizzes')
    .insert({
      title: quizData.title,
      category: quizData.category || 'General',
      description: quizData.description || '',
      total_questions: quizData.questions?.length || 0,
      marks_per_question: quizData.marks_per_question || 1.0,
      negative_marks: quizData.negative_marks || 0.0,
      time_limit_seconds: quizData.time_limit_seconds || 30,
      is_active: true,
      is_premium: Boolean(quizData.is_premium),
    })
    .select()
    .single();

  if (quizError || !quiz) {
    console.error('❌ Quiz insert error:', quizError?.message);
    process.exit(1);
  }

  console.log(`✅ Quiz created with ID: ${quiz.id}`);

  // 2. Insert Questions
  const questionsToInsert = quizData.questions.map((q: any, index: number) => ({
    quiz_id: quiz.id,
    question_text: q.question_text,
    options: q.options,
    correct_option_index: q.correct_option_index,
    explanation: q.explanation || null,
    order_index: index + 1,
  }));

  const { error: questionsError } = await supabase
    .from('questions')
    .insert(questionsToInsert);

  if (questionsError) {
    console.error('❌ Questions insert error:', questionsError.message);
    process.exit(1);
  }

  console.log(`🎉 SUCCESS! "${quizData.title}" ke ${questionsToInsert.length} questions successfully import ho gaye!`);
  console.log(`👉 Telegram bot me /quizzes type karke check kijiye.`);
}

importQuiz().catch(console.error);
