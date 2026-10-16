import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { upsertUser } from '../db/queries';
import { handleViewQuiz, handleQuizzesList } from './quizzes';
import { handleProfile } from './profile';
import { handleIncomingReferral, handleReferralCommand } from './referral';
import { handleMistakesCommand, handleStartRevisionTest } from './mistakes';
import { handleDailyQotdCommand, handleStreakCommand } from './streak';
import { handleDuelCommand, handleIncomingDuelInvite } from './duel';
import { handleStartGroupQuizFromDm } from './groupQuiz';
import { handleStartGroupScheduleFromDm } from './groupSchedule';
import { handleDownloadPdfScorecard } from './pdfExport';
import { handleQuizLeaderboard } from './leaderboard';

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

  // Check Deep Linking payload
  const payload = ctx.match as string | undefined;
  if (payload) {
    if (payload.startsWith('ref_')) {
      const referrerId = payload.replace('ref_', '');
      await handleIncomingReferral(ctx, supabase, referrerId);
    } else if (payload.startsWith('quiz_')) {
      const quizId = payload.replace('quiz_', '');
      return handleViewQuiz(ctx, supabase, env || ({} as any), quizId);
    } else if (payload === 'profile') {
      return handleProfile(ctx, supabase);
    } else if (payload === 'quizzes') {
      return handleQuizzesList(ctx, supabase);
    } else if (payload === 'mistakes') {
      return handleMistakesCommand(ctx, supabase);
    } else if (payload === 'revision') {
      return handleStartRevisionTest(ctx, supabase, env || ({} as any));
    } else if (payload === 'daily' || payload === 'streak') {
      return handleDailyQotdCommand(ctx, supabase, env || ({} as any));
    } else if (payload.startsWith('duel_')) {
      return handleIncomingDuelInvite(ctx, supabase, payload);
    } else if (payload === 'duel') {
      return handleDuelCommand(ctx, supabase);
    } else if (payload === 'refer') {
      return handleReferralCommand(ctx, supabase);
    } else if (payload.startsWith('launch_')) {
      const groupId = Number(payload.replace('launch_', ''));
      if (!isNaN(groupId)) {
        return handleStartGroupQuizFromDm(ctx, supabase, groupId);
      }
    } else if (payload.startsWith('sch_')) {
      const groupId = Number(payload.replace('sch_', ''));
      if (!isNaN(groupId)) {
        return handleStartGroupScheduleFromDm(ctx, supabase, groupId);
      }
    } else if (payload.startsWith('pdf_')) {
      const qId = payload.replace('pdf_', '');
      return handleDownloadPdfScorecard(ctx, supabase, qId);
    } else if (payload.startsWith('lb_')) {
      const qId = payload.replace('lb_', '');
      return handleQuizLeaderboard(ctx, supabase, qId);
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
    `• 📒 Intelligent Mistake Vault & Targeted Revision Bank (/mistakes)\n` +
    `• 🔥 Daily Question of the Day & Streak Habit Dossier (/streak)\n` +
    `• ⚔️ 1v1 Live Candidate Duels & ELO Rating System (/duel)\n` +
    `• 👥 Ambassador Referral Program & Free Pass Rewards (/refer)\n` +
    `• 📄 Downloadable PDF Solution Booklets & Rank Lists\n\n` +
    `Kripya shuru karne ke liye neeche vikalp chunein:`;

  const keyboard = new InlineKeyboard()
    .text('📚 All Mock Examinations', 'menu_quizzes')
    .text('🏆 All-India Leaderboard', 'menu_global_lb')
    .row()
    .text('📒 Mistake Vault', 'menu_mistakes')
    .text('🔥 Daily Streak & QOTD', 'menu_streak')
    .row()
    .text('⚔️ 1v1 Live Duel', 'menu_duel')
    .text('👥 Invite & Earn Pass', 'menu_refer')
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
    `2. *Mistake Vault & Revision:* Galat kiye gaye questions /mistakes me save hote hain. Unhe re-attempt karke weak areas master karein.\n` +
    `3. *Daily Habit Loop:* Roz subah /daily se aaj ka Question of the Day solve karein aur /streak badhayein.\n` +
    `4. *1v1 Live Duels:* Kisi peer ko rapid-fire face-off challenge dene ke liye /duel run karein.\n` +
    `5. *Ambassador Referrals:* Doston ko invite karne ke liye /refer use karein aur free Scholar Pass unlock karein.\n` +
    `6. *Group Live Battles:* Apne Telegram Group me bot ko Admin banayein aur \`/groupquiz\` ya \`/schedule\` run karein.\n` +
    `7. *PDF Solution Booklets:* Har test attempt ke baad official PDF question paper with detailed explanation booklet download karein.\n\n` +
    `📋 *System Command Reference:*\n` +
    `• /start — Platform Dashboard\n` +
    `• /quizzes — Browse Mock Examination Papers\n` +
    `• /mistakes — Candidate Mistake Vault & Weak Areas\n` +
    `• /revision — Launch Weak Area Revision Drill\n` +
    `• /streak — Daily Study Streak & Habit Dossier\n` +
    `• /daily — Today's Question of the Day (QOTD)\n` +
    `• /duel — 1v1 Live Candidate Face-Off Duel\n` +
    `• /refer — Candidate Referral & Rewards Hub\n` +
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

