import { Context } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { isAdmin } from '../utils/admin';

export async function handleDocumentImport(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const document = ctx.message?.document;
  if (!document) return;

  const fileName = document.file_name || '';

  // Check if it's a JSON file
  if (!fileName.endsWith('.json') && document.mime_type !== 'application/json') {
    return;
  }

  // Security check: Strict Admin only
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied! Sirf Admin hi quizzes import kar sakta hai.');
    return;
  }

  const waitMsg = await ctx.reply('⏳ JSON file download aur process ho rahi hai...');

  try {
    // 1. Get file path from Telegram
    const file = await ctx.getFile();
    if (!file.file_path) {
      throw new Error('Telegram file path nahi mil paya.');
    }

    const downloadUrl = `https://api.telegram.org/file/bot${env.BOT_TOKEN}/${file.file_path}`;

    // Download with 15s timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000);

    const response = await fetch(downloadUrl, { signal: controller.signal });
    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`Download status: ${response.status}`);
    }

    const jsonText = await response.text();
    const quizData = JSON.parse(jsonText);

    await insertQuizToDatabase(quizData, supabase, ctx, waitMsg.message_id);
  } catch (err: any) {
    console.error('File import error:', err);
    await ctx.api.editMessageText(
      ctx.chat!.id,
      waitMsg.message_id,
      `❌ File Download Error: ${err.message || 'Timeout'}\n\n💡 *Tip:* Aap seedhe JSON text copy karke yahan chat me paste bhi kar sakte hain!`
    );
  }
}

// Support direct JSON text paste in chat
export async function handleTextImport(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const text = ctx.message?.text?.trim();
  if (!text) return;

  // Check if text looks like JSON
  if (!text.startsWith('{') || !text.includes('"title"') || !text.includes('"questions"')) {
    return; // Not a quiz JSON
  }

  // Security check: Strict Admin only
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied! Sirf Admin hi quizzes import kar sakta hai.');
    return;
  }

  const waitMsg = await ctx.reply('⏳ JSON text process ho raha hai...');

  try {
    const quizData = JSON.parse(text);
    await insertQuizToDatabase(quizData, supabase, ctx, waitMsg.message_id);
  } catch (err: any) {
    console.error('Text JSON import error:', err);
    await ctx.api.editMessageText(
      ctx.chat!.id,
      waitMsg.message_id,
      `❌ Invalid JSON Text: ${err.message}`
    );
  }
}

async function insertQuizToDatabase(
  quizData: any,
  supabase: SupabaseClient,
  ctx: Context,
  statusMsgId: number
) {
  // Validate JSON structure
  if (!quizData.title || !Array.isArray(quizData.questions) || quizData.questions.length === 0) {
    await ctx.api.editMessageText(
      ctx.chat!.id,
      statusMsgId,
      '❌ Invalid format! JSON me "title" aur "questions" array hona zaroori hai.'
    );
    return;
  }

  // 1. Insert Quiz
  const { data: quiz, error: quizError } = await supabase
    .from('quizzes')
    .insert({
      title: quizData.title,
      category: quizData.category || 'General',
      description: quizData.description || '',
      total_questions: quizData.questions.length,
      marks_per_question: Number(quizData.marks_per_question) || 1.0,
      negative_marks: Number(quizData.negative_marks) || 0.0,
      time_limit_seconds: Number(quizData.time_limit_seconds) || 30,
      is_active: true,
      is_premium: Boolean(quizData.is_premium),
    })
    .select()
    .single();

  if (quizError || !quiz) {
    throw new Error(quizError?.message || 'Database me quiz save nahi hua.');
  }

  // 2. Insert Questions
  const questionsToInsert = quizData.questions.map((q: any, index: number) => ({
    quiz_id: quiz.id,
    question_text: q.question_text,
    options: q.options,
    correct_option_index: Number(q.correct_option_index) || 0,
    explanation: q.explanation || null,
    order_index: index + 1,
  }));

  const { error: questionsError } = await supabase
    .from('questions')
    .insert(questionsToInsert);

  if (questionsError) {
    throw new Error(questionsError.message);
  }

  // 3. Success Announcement
  const successText =
    `🎉 *QUIZ SUCCESSFULLY IMPORTED!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Title:* ${quiz.title}\n` +
    `📂 *Category:* ${quiz.category}\n` +
    `❓ *Total Questions:* \`${questionsToInsert.length}\`\n` +
    `⏱️ *Time Limit:* \`${quiz.time_limit_seconds}s\` per question\n` +
    `⚠️ *Negative Marking:* \`-${quiz.negative_marks}\`\n\n` +
    `Yeh quiz ab students ke liye /quizzes me live ho chuka hai! 🚀`;

  await ctx.api.editMessageText(ctx.chat!.id, statusMsgId, successText, {
    parse_mode: 'Markdown',
  });
}

export async function handleImportHelp(ctx: Context) {
  const guide =
    `📥 *HOW TO IMPORT QUIZ VIA BOT*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `Aap do tareeqon se quiz import kar sakte hain:\n\n` +
    `*Option 1: JSON File Send Karein*\n` +
    `Apni \`.json\` file yahan chat me as a Document bhej dijiye.\n\n` +
    `*Option 2: Direct JSON Text Paste Karein*\n` +
    `Neeche diye gaye format me JSON text copy karke yahan chat me paste kar dijiye:\n\n` +
    `\`\`\`json\n` +
    `{\n` +
    `  "title": "Science Mock Test",\n` +
    `  "category": "Science",\n` +
    `  "marks_per_question": 2,\n` +
    `  "negative_marks": 0.5,\n` +
    `  "time_limit_seconds": 30,\n` +
    `  "questions": [\n` +
    `    {\n` +
    `      "question_text": "What is H2O?",\n` +
    `      "options": ["Water", "Salt", "Acid", "Gas"],\n` +
    `      "correct_option_index": 0,\n` +
    `      "explanation": "H2O is chemical formula of water."\n` +
    `    }\n` +
    `  ]\n` +
    `}\n` +
    `\`\`\``;

  await ctx.reply(guide, { parse_mode: 'Markdown' });
}
