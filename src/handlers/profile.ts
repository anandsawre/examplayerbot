import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getUser, getUserMistakeStats, getUserReferralStats } from '../db/queries';

export async function handleProfile(ctx: Context, supabase: SupabaseClient) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const user = await getUser(supabase, userId);
  const mistakeStats = await getUserMistakeStats(supabase, userId);
  const referralStats = await getUserReferralStats(supabase, userId);

  const streak = user?.streak_days || 1;
  const longestStreak = user?.longest_streak || streak;
  const duelRating = user?.duel_rating || 1200;
  const duelWins = user?.duel_wins || 0;
  const duelLosses = user?.duel_losses || 0;

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
  text += `  • 🔥 *Current Study Streak:* \`${streak} Days\` _(Peak: ${longestStreak} Days)_\n`;
  text += `  • 📒 *Mistake Vault Status:* \`${mistakeStats.totalUnresolved} Unresolved Errors\`\n`;
  text += `  • ⚔️ *1v1 Duel Battle Record:* \`${duelRating} ELO\` _(${duelWins}W - ${duelLosses}L)_\n`;
  text += `  • 👥 *Peers Enrolled via Link:* \`${referralStats.totalReferrals} Students\`\n\n`;

  text += `💡 _Consistent daily testing and targeted mistake revision lead to top percentiles in competitive exams._`;

  const keyboard = new InlineKeyboard()
    .text('📒 Mistake Vault', 'menu_mistakes')
    .text('🔥 Daily Streak', 'menu_streak')
    .row()
    .text('⚔️ 1v1 Live Duel', 'menu_duel')
    .text('👥 Referrals', 'menu_refer')
    .row()
    .text('📚 Attempt Mock Test', 'menu_quizzes')
    .text('🏆 Rankings', 'menu_global_lb')
    .row()
    .text('🔙 Platform Dashboard', 'menu_start');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

