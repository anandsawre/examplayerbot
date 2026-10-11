import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getGlobalLeaderboard, getQuizLeaderboard, getQuizById } from '../db/queries';
import { formatTime } from '../services/scoring';

const MEDALS = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];

export async function handleGlobalLeaderboard(ctx: Context, supabase: SupabaseClient) {
  const topUsers = await getGlobalLeaderboard(supabase, 10);
  const isGroup = ctx.chat?.type === 'group' || ctx.chat?.type === 'supergroup';

  let botUsername = 'Examplayer_bot';
  try {
    const me = await ctx.api.getMe();
    botUsername = me.username;
  } catch {}

  let text = `🏆 *ALL-INDIA MERIT STANDINGS*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `Official cumulative rankings of registered candidates across all examinations:\n\n`;

  if (topUsers.length === 0) {
    text += `_No candidate attempts recorded yet. Attempt an examination to establish your rank._`;
  } else {
    // Aligned Monospace Table for Global Leaderboard
    let table = `Rank Candidate            Total Pts\n`;
    table += `──────────────────────────────────\n`;

    topUsers.forEach((user, idx) => {
      const rankStr = `${idx + 1}.`.padEnd(5, ' ');
      const rawName = user.username ? `@${user.username}` : user.first_name;
      const nameStr = rawName.length > 17 ? rawName.slice(0, 16) + '…' : rawName;
      const paddedName = nameStr.padEnd(19, ' ');
      const scoreStr = String(user.score).padStart(8, ' ');
      table += `${rankStr}${paddedName}${scoreStr}\n`;
    });

    text += `\`\`\`\n${table}\`\`\`\n`;

    // Medals for top 3
    topUsers.slice(0, 3).forEach((user, idx) => {
      const name = user.username ? `@${user.username}` : user.first_name;
      text += `${MEDALS[idx]} *${escapeMarkdown(name)}* — \`${user.score} pts\`\n`;
    });
  }

  const keyboard = new InlineKeyboard();
  if (isGroup) {
    keyboard.url('📖 Examination Catalog in DM', `https://t.me/${botUsername}?start=quizzes`);
  } else {
    keyboard
      .text('📝 Attempt Solo Assessment', 'menu_quizzes')
      .row()
      .text('🏛️ Main Dashboard', 'menu_start');
  }

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
  const attempts = await getQuizLeaderboard(supabase, quizId, 15);
  const negativeMarkPerWrong = Number(quiz?.negative_marks) || 0;
  const isGroup = ctx.chat?.type === 'group' || ctx.chat?.type === 'supergroup';

  let botUsername = 'Examplayer_bot';
  try {
    const me = await ctx.api.getMe();
    botUsername = me.username;
  } catch {}

  let text = `🏆 *OFFICIAL EXAMINATION MERIT LIST*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `📚 *Examination:* ${escapeMarkdown(quiz?.title || 'Quiz')}\n`;
  text += `⚠️ *Marking Scheme:* +${quiz?.marks_per_question || 1} / -${negativeMarkPerWrong} per incorrect response\n\n`;

  if (attempts.length === 0) {
    text += `_No attempts recorded yet for this examination module._\n_Be the first candidate to attempt and lead the standings!_`;
  } else {
    // Generate ASCII/Monospace Aligned Table with Correct, Wrong, -Neg, Score
    let table = `Rank Candidate   ✅  ❌  -Neg   Score\n`;
    table += `─────────────────────────────────────\n`;

    attempts.forEach((att, idx) => {
      const rankStr = `${idx + 1}.`.padEnd(5, ' ');
      const rawName = att.first_name || (att.username ? `@${att.username}` : 'Student');
      // Truncate name to 10 chars for clean alignment
      const nameStr = rawName.length > 10 ? rawName.slice(0, 9) + '…' : rawName;
      const paddedName = nameStr.padEnd(11, ' ');

      const correctStr = String(att.correct_count ?? 0).padStart(3, ' ');
      const wrongStr = String(att.wrong_count ?? 0).padStart(3, ' ');

      const negPenalty = Math.round((att.wrong_count ?? 0) * negativeMarkPerWrong * 100) / 100;
      const negStr = (negPenalty > 0 ? `-${negPenalty}` : ' 0.0').padStart(6, ' ');
      const scoreStr = String(att.score).padStart(7, ' ');

      table += `${rankStr}${paddedName}${correctStr} ${wrongStr} ${negStr} ${scoreStr}\n`;
    });

    text += `\`\`\`\n${table}\`\`\`\n`;

    // Detailed highlights for Top 3 Toppers
    text += `🎖️ *Top Performers Breakdown:*\n`;
    attempts.slice(0, 3).forEach((att, idx) => {
      const name = att.username ? `@${att.username}` : att.first_name;
      const timeStr = formatTime(att.time_taken_seconds || 0);
      const acc = att.accuracy_percent ?? 0;
      text += `${MEDALS[idx]} *${escapeMarkdown(name)}* — \`${att.score} pts\` (${acc}% acc | ⏱️ ${timeStr})\n`;
    });
  }

  const keyboard = new InlineKeyboard();
  if (isGroup) {
    keyboard
      .url('📝 Attempt Solo in Direct Message', `https://t.me/${botUsername}?start=quiz_${quizId}`)
      .row()
      .text('🌍 Cumulative Merit Standings', 'menu_global_lb')
      .url('📖 Examination Catalog in DM', `https://t.me/${botUsername}?start=quizzes`);
  } else {
    keyboard
      .text('🚀 Attempt This Examination', `start_quiz:${quizId}`)
      .row()
      .text('🌍 Cumulative Merit Standings', 'menu_global_lb')
      .text('🔙 Return to Catalog', 'menu_quizzes');
  }

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
