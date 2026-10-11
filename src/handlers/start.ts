import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { upsertUser } from '../db/queries';
import { handleViewQuiz, handleQuizzesList } from './quizzes';
import { handleProfile } from './profile';

export async function handleStart(ctx: Context, supabase: SupabaseClient, env?: Env) {
  const from = ctx.from;
  if (!from) return;

  // Auto register or update user profile
  await upsertUser(supabase, {
    id: from.id,
    first_name: from.first_name || 'Student',
    last_name: from.last_name,
    username: from.username,
  });

  // Check Deep Linking payload (e.g. /start quiz_<quiz_id> or /start profile or /start quizzes)
  const payload = ctx.match as string | undefined;
  if (payload) {
    if (payload.startsWith('quiz_')) {
      const quizId = payload.replace('quiz_', '');
      return handleViewQuiz(ctx, supabase, env || ({} as any), quizId);
    }
    if (payload === 'profile') {
      return handleProfile(ctx, supabase);
    }
    if (payload === 'quizzes') {
      return handleQuizzesList(ctx, supabase);
    }
  }

  const welcomeText =
    `🏛️ *EXAMPLAYER — ADVANCED EXAMINATION PLATFORM*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Namaste *${from.first_name}*! \n` +
    `Yeh competitive examinations (UPSC, SSC, State PSC, Railways, Banking) ke liye ek official AI-powered mock testing & live battle platform hai.\n\n` +
    `🎯 *Platform Highlights:*\n` +
    `• ⏱️ Real-Time Examination Timer & Speed Analytics\n` +
    `• ⚠️ Precision Negative Marking & Accuracy Tracking\n` +
    `• 📄 Downloadable PDF Solution Booklets & Detailed Explanations\n` +
    `• 🏆 Dynamic Merit Lists & All-India Rank System\n` +
    `• 👥 Automated Group Live Battles & Schedule Launcher (/schedule)\n\n` +
    `Kripya shuru karne ke liye neeche vikalp chunein:`;

  const keyboard = new InlineKeyboard()
    .text('📚 All Mock Examinations', 'menu_quizzes')
    .text('🏆 All-India Leaderboard', 'menu_global_lb')
    .row()
    .text('👤 Candidate Profile & Analytics', 'menu_profile')
    .text('ℹ️ User Manual & Commands', 'menu_help');

  await ctx.reply(welcomeText, {
    parse_mode: 'Markdown',
    reply_markup: keyboard,
  });
}

export async function handleHelp(ctx: Context) {
  const text =
    `📖 *EXAMPLAYER PLATFORM — USER GUIDE & COMMANDS*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `1. *Solo Examinations:* /quizzes enter karein aur apna vishay chunein. Timer aur negative marking ke saath test start hoga.\n` +
    `2. *PDF Solution Booklets:* Har test attempt ke baad aap official PDF question paper with detailed explanation booklet download kar sakte hain.\n` +
    `3. *Group Live Battles:* Apne Telegram Group me bot ko Admin banayein aur \`/groupquiz\` run karein.\n` +
    `4. *Automated Scheduling:* Kisi specific samay par test auto-start karne ke liye group me \`/schedule\` ya \`/scheduletime 19:30\` use karein.\n` +
    `5. *Evaluation Scheme:* Har correct response par full marks aur galat response par negative marking deduction apply hoga.\n\n` +
    `📋 *System Command Reference:*\n` +
    `• /start — Platform Dashboard\n` +
    `• /quizzes — Browse Mock Examination Papers\n` +
    `• /groupquiz — Launch Group Live Battle\n` +
    `• /schedule — Automated Group Quiz Scheduler\n` +
    `• /stopquiz — Terminate Active Group Battle\n` +
    `• /leaderboard — All-India Merit List\n` +
    `• /myprofile — Candidate Performance & Accuracy Stats\n` +
    `• /broadcast — Admin Global Broadcast Controller\n` +
    `• /import — Test Question JSON Importer Guide`;

  const keyboard = new InlineKeyboard().text('🔙 Back to Platform Dashboard', 'menu_start');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}
