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
    `🎯 *Welcome to Examplayer Bot!*\n\n` +
    `Hello *${from.first_name}*! Aapka competitive exam preparation bot ready hai.\n\n` +
    `✨ *Key Features:*\n` +
    `• ⏱️ Real exam simulation with timer\n` +
    `• ⚠️ Negative marking calculation\n` +
    `• 📄 Instant Downloadable PDF Scorecards & Solutions\n` +
    `• 🏆 Live leaderboards & rank tracking\n` +
    `• 👥 Group Live Battles (/groupquiz) & Scheduling (/schedule)\n` +
    `• 📊 Monospace Performance Scorecard\n\n` +
    `Neeche diye gaye buttons se shuru kijiye:`;

  const keyboard = new InlineKeyboard()
    .text('📚 Browse Quizzes', 'menu_quizzes')
    .text('🏆 Leaderboard', 'menu_global_lb')
    .row()
    .text('👤 My Profile & Stats', 'menu_profile')
    .text('ℹ️ Help & Rules', 'menu_help');

  await ctx.reply(welcomeText, {
    parse_mode: 'Markdown',
    reply_markup: keyboard,
  });
}

export async function handleHelp(ctx: Context) {
  const text =
    `📖 *Examplayer Bot Rules & Guide:*\n\n` +
    `1. *Solo Tests:* /quizzes dabayein aur apna pasandeeda test chunein.\n` +
    `2. *PDF Scorecards:* Test khatam hone par pure test ka detailed PDF solution booklet download karein!\n` +
    `3. *Group Battles:* Group me /groupquiz run karke live battle shuru karein.\n` +
    `4. *Scheduled Quizzes:* Group me /schedule command se kisi bhi time ke liye automated test schedule karein.\n` +
    `5. *Scoring:* Correct answer par full marks milenge aur galat par penalty cut hogi.\n\n` +
    `Commands:\n` +
    `• /start - Main menu\n` +
    `• /quizzes - All mock tests & PDF papers\n` +
    `• /groupquiz - Start live battle in group\n` +
    `• /schedule - Schedule automated quiz in group\n` +
    `• /stopquiz - Stop group battle\n` +
    `• /leaderboard - Top merit list rankings\n` +
    `• /myprofile - Your stats, accuracy & streak\n` +
    `• /broadcast - Admin Announcement Dispatcher\n` +
    `• /import - JSON format guide`;

  const keyboard = new InlineKeyboard().text('🔙 Back to Main Menu', 'menu_start');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}
