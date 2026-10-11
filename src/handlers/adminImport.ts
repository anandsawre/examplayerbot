import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { isAdmin } from '../utils/admin';
import { getFolderById, memoryQuizFolderMap } from '../db/queries';

function escapeMarkdown(text: string): string {
  if (!text) return '';
  return text
    .replace(/_/g, '\\_')
    .replace(/\*/g, '\\*')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]')
    .replace(/`/g, '\\`');
}

export interface AdminImportSession {
  folderId: string | null;
  folderName: string;
}

// In-memory session tracking for active folder import target
export const adminImportSessions: Map<number, AdminImportSession> = new Map();

/**
 * Triggered when admin clicks "📥 Import Quiz Here" from within any folder or root
 */
export async function handlePromptFolderImport(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  folderIdStr: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true }).catch(() => {});
  }

  const userId = ctx.from?.id;
  const isSubfolder = folderIdStr && folderIdStr !== 'root';
  let targetFolderId: string | null = null;
  let targetFolderName = 'Directory Root';

  if (isSubfolder) {
    const folder = await getFolderById(supabase, folderIdStr);
    if (folder) {
      targetFolderId = folder.id;
      targetFolderName = folder.name;
    }
  }

  if (userId) {
    adminImportSessions.set(userId, {
      folderId: targetFolderId,
      folderName: targetFolderName,
    });
  }

  const text =
    `📥 *IMPORT QUIZ INTO: "${escapeMarkdown(targetFolderName)}"*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📍 Target Folder: *${escapeMarkdown(targetFolderName)}*\n\n` +
    `Is folder ke andar direct quiz import karne ke liye:\n` +
    `1️⃣ Apni formatted \`.json\` file is chat me upload karein, YA\n` +
    `2️⃣ Direct JSON text payload is chat me paste kar dein!\n\n` +
    `Yeh quiz create hote hi seedhe *"${escapeMarkdown(targetFolderName)}"* folder me save ho jayega.`;

  const keyboard = new InlineKeyboard();
  keyboard.text('ℹ️ View JSON Format / Template', 'import_help').row();
  if (isSubfolder) {
    keyboard.text('❌ Cancel', `fldr:${folderIdStr}`);
  } else {
    keyboard.text('❌ Cancel', 'menu_quizzes');
  }

  if (ctx.callbackQuery) {
    try {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    } catch {
      await ctx.editMessageText(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
    }
    ctx.answerCallbackQuery().catch(() => {});
  } else {
    try {
      await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    } catch {
      await ctx.reply(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
    }
  }
}

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
    await ctx.reply('⚠️ Access Denied: Test import operations restricted to Platform Administrators.');
    return;
  }

  const waitMsg = await ctx.reply('⏳ Downloading and parsing JSON payload...');

  try {
    // 1. Get file path from Telegram
    const file = await ctx.getFile();
    if (!file.file_path) {
      throw new Error('Telegram file retrieval failed.');
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
      `❌ Document Import Error: ${err.message || 'Timeout'}\n\n💡 *Tip:* You can also directly paste JSON text payload into this chat!`
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
    await ctx.reply('⚠️ Access Denied: Test import operations restricted to Platform Administrators.');
    return;
  }

  const waitMsg = await ctx.reply('⏳ Parsing raw JSON examination payload...');

  try {
    const quizData = JSON.parse(text);
    await insertQuizToDatabase(quizData, supabase, ctx, waitMsg.message_id);
  } catch (err: any) {
    console.error('Text JSON import error:', err);
    await ctx.api.editMessageText(
      ctx.chat!.id,
      waitMsg.message_id,
      `❌ Invalid JSON Payload: ${err.message}`
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
      '❌ Invalid Schema: JSON must specify "title" and a non-empty "questions" array.'
    );
    return;
  }

  const userId = ctx.from?.id;
  const session = userId ? adminImportSessions.get(userId) : undefined;
  if (userId) {
    adminImportSessions.delete(userId);
  }

  // Determine folder_id: from session if set, or from payload if specified, or null
  const targetFolderId: string | null = session?.folderId || quizData.folder_id || null;
  let targetFolderName: string = session?.folderName || '';

  if (targetFolderId && !targetFolderName) {
    const f = await getFolderById(supabase, targetFolderId);
    if (f) targetFolderName = f.name;
  }

  // 1. Insert Quiz with folder_id
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
      folder_id: targetFolderId,
    })
    .select()
    .single();

  if (quizError || !quiz) {
    throw new Error(quizError?.message || 'Database me quiz save nahi hua.');
  }

  // Sync with memory map
  if (targetFolderId) {
    memoryQuizFolderMap.set(quiz.id, targetFolderId);
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
  const locationLine = targetFolderId && targetFolderName
    ? `📁 *Folder:* ${escapeMarkdown(targetFolderName)}\n`
    : `📁 *Location:* Directory Root\n`;

  const successText =
    `🎉 *EXAMINATION SUCCESSFULLY IMPORTED*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Title:* ${escapeMarkdown(quiz.title)}\n` +
    `📂 *Category:* ${escapeMarkdown(quiz.category)}\n` +
    locationLine +
    `❓ *Total Questions:* \`${questionsToInsert.length}\`\n` +
    `⏱️ *Time Limit:* \`${quiz.time_limit_seconds}s\` per question\n` +
    `⚠️ *Negative Marking:* \`-${quiz.negative_marks}\`\n\n` +
    `This examination paper is now active and ready for candidates! 🚀`;

  const keyboard = new InlineKeyboard();
  if (targetFolderId) {
    keyboard.text(`📂 Open Folder: ${targetFolderName}`, `fldr:${targetFolderId}`).row();
  } else {
    keyboard.text('📂 Browse All Examinations', 'menu_quizzes').row();
  }
  keyboard.text('👁️ View Examination Scheme', `view_quiz:${quiz.id}`).row();

  try {
    await ctx.api.editMessageText(ctx.chat!.id, statusMsgId, successText, {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    });
  } catch {
    await ctx.api.editMessageText(ctx.chat!.id, statusMsgId, successText.replace(/[*_`\[\]]/g, ''), {
      reply_markup: keyboard,
    });
  }
}

export async function handleImportHelp(ctx: Context) {
  const guide =
    `📥 *EXAMINATION IMPORT PROTOCOL*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Two ingestion methods are supported for examination papers:\n\n` +
    `*Method 1: JSON File Upload*\n` +
    `Upload your formatted \`.json\` file directly as a Document in this chat.\n\n` +
    `*Method 2: Raw JSON Text Ingestion*\n` +
    `Paste your JSON payload adhering to the canonical specification:\n\n` +
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

  const keyboard = new InlineKeyboard().text('🔙 Back to Examinations', 'menu_quizzes');

  if (ctx.callbackQuery) {
    try {
      await ctx.editMessageText(guide, { parse_mode: 'Markdown', reply_markup: keyboard });
    } catch {
      await ctx.reply(guide, { parse_mode: 'Markdown', reply_markup: keyboard });
    }
    ctx.answerCallbackQuery().catch(() => {});
  } else {
    await ctx.reply(guide, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}
