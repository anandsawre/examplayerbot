import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import {
  getUserMistakes,
  getUserMistakeStats,
  clearResolvedMistakes,
  getUser,
} from '../db/queries';
import { handleStartQuiz } from './quizPlay';

/**
 * Displays the Candidate's Mistake Vault & Weak Area Dossier
 */
export async function handleMistakesCommand(ctx: Context, supabase: SupabaseClient) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const user = await getUser(supabase, userId);
  const studentName = user?.first_name || ctx.from?.first_name || 'Candidate';
  const { totalUnresolved, totalResolved } = await getUserMistakeStats(supabase, userId);

  const text =
    `📒 *CANDIDATE MISTAKE VAULT & WEAK AREA NOTEBOOK*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Candidate: *${studentName}*\n` +
    `Vault Status: ${totalUnresolved > 0 ? `⚠️ *${totalUnresolved} Unresolved Errors Recorded*` : `✅ *Zero Weak Points Detected*`}\n\n` +
    `📊 *Academic Accuracy Audit:*\n` +
    `• 📌 *Unresolved Weak Questions:* ${totalUnresolved} item(s)\n` +
    `• ✨ *Mastered / Cleared in Revision:* ${totalResolved} item(s)\n\n` +
    `💡 *Intelligent Revision Engine:*\n` +
    `Questions missed or skipped during mock tests are cataloged here. ` +
    `Launching a *Weak Area Revision Drill* presents these exact questions for targeted practice. ` +
    `Answering correctly marks them as resolved and removes them from this vault.\n\n` +
    `Select an option below to initiate revision:`;

  const keyboard = new InlineKeyboard();

  if (totalUnresolved > 0) {
    keyboard.text('🎯 Launch Weak Area Revision Drill', 'menu_start_revision').row();
  } else {
    keyboard.text('📚 Browse All Mock Examinations', 'menu_quizzes').row();
  }

  if (totalResolved > 0) {
    keyboard.text('🧹 Clear Mastered History', 'menu_clear_resolved').row();
  }

  keyboard.text('🔙 Back to Platform Dashboard', 'menu_start');

  if (ctx.callbackQuery) {
    try {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      await ctx.answerCallbackQuery();
      return;
    } catch {}
  }

  await ctx.reply(text, {
    parse_mode: 'Markdown',
    reply_markup: keyboard,
  });
}

/**
 * Initiates targeted Weak Area Revision Test
 */
export async function handleStartRevisionTest(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const userId = ctx.from?.id;
  if (!userId) return;

  if (ctx.chat?.type !== 'private') {
    const botUsername = ctx.me.username;
    const url = `https://t.me/${botUsername}?start=revision`;
    const keyboard = new InlineKeyboard().url('📝 Attempt Revision in Direct Message', url);
    if (ctx.callbackQuery) await ctx.answerCallbackQuery();
    return ctx.reply(
      `⚠️ *Revision Drills are restricted to Direct Messages.* Please access via private chat:`,
      { reply_markup: keyboard }
    );
  }

  const mistakes = await getUserMistakes(supabase, userId, 10);
  if (!mistakes || mistakes.length === 0) {
    const text =
      `🎉 *MISTAKE VAULT IS CURRENTLY EMPTY!*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `Outstanding discipline! You currently have no pending unresolved errors.\n\n` +
      `Continue attempting standard mock examinations to discover and eliminate knowledge gaps!`;
    const keyboard = new InlineKeyboard()
      .text('📚 Browse Mock Examinations', 'menu_quizzes')
      .row()
      .text('🔙 Platform Dashboard', 'menu_start');

    if (ctx.callbackQuery) {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      await ctx.answerCallbackQuery();
      return;
    }
    return ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }

  // Pick first quizId that has mistakes, or dispatch via regular solo test
  const firstQuizId = mistakes[0].mistake.quiz_id;
  if (firstQuizId) {
    if (ctx.callbackQuery) await ctx.answerCallbackQuery({ text: 'Launching targeted revision test...' });
    return handleStartQuiz(ctx, supabase, env, firstQuizId);
  }

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: 'Opening exam catalog...' });
  }
  return ctx.reply(
    `📚 *Select an examination below to re-attempt and eliminate weak areas:*`,
    {
      reply_markup: new InlineKeyboard().text('📚 View All Mock Examinations', 'menu_quizzes'),
    }
  );
}

/**
 * Clears resolved mistakes history
 */
export async function handleClearResolvedMistakes(ctx: Context, supabase: SupabaseClient) {
  const userId = ctx.from?.id;
  if (!userId) return;

  await clearResolvedMistakes(supabase, userId);

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({
      text: 'Cleared all mastered question records from history.',
      show_alert: true,
    });
  }
  return handleMistakesCommand(ctx, supabase);
}
