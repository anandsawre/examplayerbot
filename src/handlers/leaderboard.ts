import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getGlobalLeaderboard, getQuizLeaderboard, getQuizById } from '../db/queries';

const MEDALS = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];

export async function handleGlobalLeaderboard(ctx: Context, supabase: SupabaseClient) {
  const topUsers = await getGlobalLeaderboard(supabase, 10);

  let text = `🏆 *GLOBAL EXAMPLAYER TOPPERS*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `Overall platform ke top students:\n\n`;

  if (topUsers.length === 0) {
    text += `_Abhi koi scores record nahi hue hain. Pehla test dekar top rank lijiye!_`;
  } else {
    topUsers.forEach((user, idx) => {
      const medal = MEDALS[idx] || `${idx + 1}.`;
      const name = user.username ? `@${user.username}` : user.first_name;
      text += `${medal} *${escapeMarkdown(name)}* — \`${user.score} pts\`\n`;
    });
  }

  const keyboard = new InlineKeyboard()
    .text('📚 Take a Quiz', 'menu_quizzes')
    .row()
    .text('🔙 Main Menu', 'menu_start');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

export async function handleQuizLeaderboard(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string
) {
  const quiz = await getQuizById(supabase, quizId);
  const attempts = await getQuizLeaderboard(supabase, quizId, 10);

  let text = `🏆 *TOPPERS: ${escapeMarkdown(quiz?.title || 'Quiz')}*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n\n`;

  if (attempts.length === 0) {
    text += `_Is test me abhi kisi ne attempt nahi kiya hai. Pehle ranker bano!_`;
  } else {
    attempts.forEach((att, idx) => {
      const medal = MEDALS[idx] || `${idx + 1}.`;
      const name = att.username ? `@${att.username}` : att.first_name;
      text += `${medal} *${escapeMarkdown(name)}*\n`;
      text += `   Score: \`${att.score}\` | Acc: \`${att.accuracy_percent}%\` | Time: \`${att.time_taken_seconds}s\`\n`;
    });
  }

  const keyboard = new InlineKeyboard()
    .text('🚀 Attempt This Test', `start_quiz:${quizId}`)
    .row()
    .text('🌍 Global Leaderboard', 'menu_global_lb')
    .text('🔙 Back to Quizzes', 'menu_quizzes');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

function escapeMarkdown(text: string): string {
  if (!text) return '';
  return text
    .replace(/_/g, '\\_')
    .replace(/\*/g, '\\*')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]')
    .replace(/`/g, '\\`');
}
