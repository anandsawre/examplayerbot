import { Context, InlineKeyboard, InputFile } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getGlobalLeaderboard, getQuizLeaderboard, getQuizById } from '../db/queries';
import { formatTime } from '../services/scoring';
import { generateLeaderboardImage, LeaderboardCardEntry } from '../services/leaderboardImage';

const MEDALS = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];

export async function handleGlobalLeaderboard(ctx: Context, supabase: SupabaseClient) {
  const topUsers = await getGlobalLeaderboard(supabase, 20);
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
    // Top 3 Podium Highlights
    topUsers.slice(0, 3).forEach((user, idx) => {
      const name = user.username ? `@${user.username}` : user.first_name;
      text += `${MEDALS[idx]} *${escapeMarkdown(name)}* — \`${user.score} pts\`\n`;
    });
    text += '\n';

    // Aligned Monospace Box Table for Global Leaderboard
    let table = `┌───┬────────────────────┬───────────┐\n`;
    table +=    `│ # │ Candidate          │ Total Pts │\n`;
    table +=    `├───┼────────────────────┼───────────┤\n`;

    topUsers.forEach((user, idx) => {
      const rankStr = idx === 0 ? ' 🥇' : idx === 1 ? ' 🥈' : idx === 2 ? ' 🥉' : String(idx + 1).padStart(2, ' ') + ' ';
      const rawName = user.username ? `@${user.username}` : user.first_name;
      const cleanN = rawName.normalize('NFKD').replace(/[\u{1F300}-\u{1FAFF}]/gu, '').trim();
      const nameStr = (cleanN.length > 18 ? cleanN.slice(0, 17) + '…' : cleanN).padEnd(19, ' ');
      const scoreStr = String(Number(user.score || 0).toFixed(1)).padStart(9, ' ');
      table += `│${rankStr}│ ${nameStr}│${scoreStr} │\n`;
    });

    table +=    `└───┴────────────────────┴───────────┘`;

    text += `\`\`\`\n${table}\`\`\`\n`;
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
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard }).catch(() => {});
    await ctx.answerCallbackQuery().catch(() => {});
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
  const attempts = await getQuizLeaderboard(supabase, quizId, 100);
  const negativeMarkPerWrong = Number(quiz?.negative_marks) || 0;
  const isGroup = ctx.chat?.type === 'group' || ctx.chat?.type === 'supergroup';

  let botUsername = 'Examplayer_bot';
  try {
    const me = await ctx.api.getMe();
    botUsername = me.username;
  } catch {}

  const keyboard = new InlineKeyboard();
  if (isGroup) {
    keyboard
      .url('📄 Download Official PDF (in DM)', `https://t.me/${botUsername}?start=pdf_${quizId}`)
      .row()
      .url('📝 Attempt Solo in DM', `https://t.me/${botUsername}?start=quiz_${quizId}`)
      .text('🌍 Cumulative Standings', 'menu_global_lb');
  } else {
    keyboard
      .url('📄 Download Official PDF', `https://t.me/${botUsername}?start=pdf_${quizId}`)
      .row()
      .text('🚀 Attempt This Examination', `start_quiz:${quizId}`)
      .row()
      .text('🌍 Cumulative Standings', 'menu_global_lb')
      .text('🔙 Return to Catalog', 'menu_quizzes');
  }

  if (!attempts || attempts.length === 0) {
    const emptyText =
      `🏆 *OFFICIAL EXAMINATION MERIT LIST*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `📚 *Examination:* ${escapeMarkdown(quiz?.title || 'Quiz')}\n` +
      `⚠️ *Marking Scheme:* +${quiz?.marks_per_question || 1} / -${negativeMarkPerWrong} per incorrect response\n\n` +
      `_No attempts recorded yet for this examination module._\n` +
      `_Be the first candidate to attempt and lead the standings!_`;

    if (ctx.callbackQuery) {
      await ctx.editMessageText(emptyText, { parse_mode: 'Markdown', reply_markup: keyboard }).catch(() => {});
      await ctx.answerCallbackQuery().catch(() => {});
    } else {
      await ctx.reply(emptyText, { parse_mode: 'Markdown', reply_markup: keyboard });
    }
    return;
  }

  // Map all candidate attempts to LeaderboardCardEntry format
  const cardEntries: LeaderboardCardEntry[] = attempts.map((att, idx) => {
    const rawName = att.first_name || (att.username ? `@${att.username}` : 'Student');
    const attempted = (att.correct_count ?? 0) + (att.wrong_count ?? 0);
    const accuracy = att.accuracy_percent ?? (
      attempted > 0 ? Math.round(((att.correct_count ?? 0) / attempted) * 100) : 0
    );
    const wrong = att.wrong_count ?? 0;
    const negPenalty = Math.round(wrong * negativeMarkPerWrong * 100) / 100;
    return {
      rank: idx + 1,
      name: rawName,
      correctCount: att.correct_count ?? 0,
      wrongCount: wrong,
      negPenalty,
      score: Number(att.score) || 0,
      timeTakenSeconds: att.time_taken_seconds || 0,
      accuracy,
    };
  });

  const imgBuffer = generateLeaderboardImage(quiz?.title || 'Official Merit List', cardEntries);

  const caption =
    `🏆 *OFFICIAL EXAMINATION MERIT LIST*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📚 *Examination:* ${escapeMarkdown(quiz?.title || 'Quiz')}\n` +
    `👥 *Total Candidates Ranked:* \`${attempts.length}\` Aspirants\n` +
    `🎯 *Marking Scheme:* +${quiz?.marks_per_question || 1} / -${negativeMarkPerWrong} per incorrect response\n\n` +
    `Tap the button below to download your personal scorecard & solutions PDF directly in DM.`;

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery().catch(() => {});
    await ctx.replyWithPhoto(new InputFile(imgBuffer, 'leaderboard.png'), {
      caption,
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    });
  } else {
    await ctx.replyWithPhoto(new InputFile(imgBuffer, 'leaderboard.png'), {
      caption,
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    });
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
