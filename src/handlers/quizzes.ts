import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { getActiveQuizzes, getQuizById } from '../db/queries';
import { isAdmin } from '../utils/admin';

export async function handleQuizzesList(ctx: Context, supabase: SupabaseClient) {
  const quizzes = await getActiveQuizzes(supabase);

  if (!quizzes || quizzes.length === 0) {
    const text = '⚠️ Abhi koi test active nahi hai. Kripya thodi der baad check karein ya admin se contact karein.';
    const keyboard = new InlineKeyboard().text('🔙 Main Menu', 'menu_start');

    if (ctx.callbackQuery) {
      await ctx.editMessageText(text, { reply_markup: keyboard });
      await ctx.answerCallbackQuery();
    } else {
      await ctx.reply(text, { reply_markup: keyboard });
    }
    return;
  }

  let text = `📚 *AVAILABLE MOCK TESTS & QUIZZES*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `Apna pasandeeda topic choose kijiye aur practice shuru kijiye:\n\n`;

  const keyboard = new InlineKeyboard();

  quizzes.forEach((quiz) => {
    const badge = quiz.is_premium ? '🔒 [PREMIUM]' : '🟢 [FREE]';
    keyboard.text(`${badge} ${quiz.title}`, `view_quiz:${quiz.id}`).row();
  });

  keyboard.text('🔙 Back to Main Menu', 'menu_start');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

export async function handleViewQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({ text: 'Quiz not found!', show_alert: true });
    }
    return;
  }

  let text = `📋 *TEST OVERVIEW*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `🏷️ *Title:* ${quiz.title}\n`;
  text += `📂 *Category:* ${quiz.category}\n`;
  text += `👑 *Access:* ${quiz.is_premium ? '🔒 *Premium Pass Required*' : '🟢 *Free for All Students*'}\n`;
  if (quiz.description) text += `ℹ️ *Description:* ${quiz.description}\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n\n`;

  text += `📊 *Pattern Details:*\n`;
  text += `  • Total Questions: \`${quiz.total_questions}\`\n`;
  text += `  • Marks per Question: \`+${quiz.marks_per_question}\`\n`;
  text += `  • Negative Marking: \`-${quiz.negative_marks}\`\n`;
  text += `  • Time per Question: \`${quiz.time_limit_seconds}s\`\n\n`;

  text += `Ready hain? "Start Test" dabate hi first question open ho jayega!`;

  const botUsername = ctx.me.username;
  const shareUrl = `https://t.me/share/url?url=https://t.me/${botUsername}?start=quiz_${quiz.id}&text=Join%20${encodeURIComponent(quiz.title)}%20Mock%20Test%20on%20Examplayer%20Bot!`;

  const keyboard = new InlineKeyboard()
    .text('🚀 Start Test Now', `start_quiz:${quiz.id}`)
    .row()
    .url('📢 Share to Channel / Group', shareUrl)
    .text('🏆 Leaderboard', `lb:${quiz.id}`)
    .row();

  // Admin Only: 1-Click Toggle Free / Premium button!
  if (isAdmin(ctx, env)) {
    const toggleLabel = quiz.is_premium ? '🔓 Make Free (Admin)' : '🔒 Make Premium (Admin)';
    keyboard.text(toggleLabel, `toggle_prem:${quiz.id}`).row();
  }

  keyboard.text('🔙 All Tests', 'menu_quizzes');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

export async function handleToggleQuizPremium(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) {
    await ctx.answerCallbackQuery({ text: '⚠️ Access Denied! Only Admin can toggle.', show_alert: true });
    return;
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) return;

  const newStatus = !quiz.is_premium;
  const { error } = await supabase.from('quizzes').update({ is_premium: newStatus }).eq('id', quizId);

  if (error) {
    console.error('Failed to toggle quiz premium in Supabase:', error);
    await ctx.answerCallbackQuery({
      text: `❌ DB Error: ${error.message}\nSupabase SQL Editor me ALTER TABLE run karein!`,
      show_alert: true,
    });
    return;
  }

  await ctx.answerCallbackQuery({
    text: `Test is now ${newStatus ? '🔒 PREMIUM' : '🟢 FREE'}!`,
  });

  return handleViewQuiz(ctx, supabase, env, quizId);
}
