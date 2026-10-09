import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getUser } from '../db/queries';

export async function handleProfile(ctx: Context, supabase: SupabaseClient) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const user = await getUser(supabase, userId);

  let text = `👤 *STUDENT PROFILE & STATS*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `📛 *Name:* ${ctx.from.first_name || 'Student'}\n`;
  if (ctx.from.username) text += `🔖 *Username:* @${ctx.from.username}\n`;
  text += `🆔 *User ID:* \`${userId}\`\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n\n`;

  text += `📊 *Exam Performance:*\n`;
  text += `  • 🏆 *Total Points:* \`${user?.total_score || 0}\`\n`;
  text += `  • 📝 *Tests Completed:* \`${user?.tests_completed || 0}\`\n`;
  text += `  • 🔥 *Study Streak:* \`${user?.streak_days || 1} Days\`\n\n`;

  text += `_Daily practice karte rahein aur topper leaderboard me rank banayein!_`;

  const keyboard = new InlineKeyboard()
    .text('📚 Take a Test', 'menu_quizzes')
    .text('🏆 Leaderboard', 'menu_global_lb')
    .row()
    .text('🔙 Main Menu', 'menu_start');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}
