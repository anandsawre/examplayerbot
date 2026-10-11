import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getUser } from '../db/queries';

export async function handleProfile(ctx: Context, supabase: SupabaseClient) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const user = await getUser(supabase, userId);

  let text = `👤 *CANDIDATE ACADEMIC PROFILE & ANALYTICS*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `📛 *Candidate:* ${ctx.from.first_name || 'Aspirant'}${ctx.from.last_name ? ' ' + ctx.from.last_name : ''}\n`;
  if (ctx.from.username) text += `🔖 *Telegram Handle:* @${ctx.from.username}\n`;
  text += `🆔 *Candidate Roll ID:* \`${userId}\`\n`;
  text += `👑 *Access Tier:* ${user?.is_premium ? '🌟 *Premium Scholar Pass Active*' : '⚪ *Standard Aspirant*'}\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

  text += `📊 *Cumulative Performance Analytics:*\n`;
  text += `  • 🏆 *Total Marks Earned:* \`${user?.total_score || 0} pts\`\n`;
  text += `  • 📝 *Completed Examinations:* \`${user?.tests_completed || 0} Mock Tests\`\n`;
  text += `  • 🔥 *Continuous Practice Streak:* \`${user?.streak_days || 1} Days Active\`\n\n`;

  text += `💡 _Consistent daily testing improves recall speed and eliminates negative marking mistakes._`;

  const keyboard = new InlineKeyboard()
    .text('📚 Attempt Mock Examination', 'menu_quizzes')
    .text('🏆 All-India Rankings', 'menu_global_lb')
    .row()
    .text('🔙 Platform Dashboard', 'menu_start');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}
