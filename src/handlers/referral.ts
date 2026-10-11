import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import {
  getUser,
  getUserReferralStats,
  processReferral,
} from '../db/queries';

/**
 * Renders Candidate's Referral & Ambassador Hub
 */
export async function handleReferralCommand(ctx: Context, supabase: SupabaseClient) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const botUsername = ctx.me?.username || 'Examplayer_bot';
  const referralLink = `https://t.me/${botUsername}?start=ref_${userId}`;
  const stats = await getUserReferralStats(supabase, userId);

  const shareText = encodeURIComponent(
    `🏛️ Join me on Examplayer — the official AI examination platform for UPSC, SSC, Railways & State PSC mock tests with live timers, negative marking, and rank lists! Join here: ${referralLink}`
  );
  const shareUrl = `https://t.me/share/url?url=${encodeURIComponent(referralLink)}&text=${shareText}`;

  const text =
    `👥 *CANDIDATE REFERRAL & AMBASSADOR PROGRAM*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Invite fellow aspirants to prepare together, earn bonus All-India merit marks, and unlock complimentary Scholar Passes!\n\n` +
    `🔗 *Your Official Referral Link:*\n` +
    `\`${referralLink}\`\n\n` +
    `📊 *Your Ambassador Records:*\n` +
    `• 🤝 *Total Candidates Enrolled:* ${stats.totalReferrals} aspirant(s)\n` +
    `• 🏆 *Bonus Merit Marks Earned:* +${stats.bonusPoints}.00 Marks\n` +
    `• 🌟 *Scholar Pass Status:* ${stats.isPremium ? '🔓 *Active / Premium*' : '🔒 *Standard Pass*'}\n\n` +
    `🎁 *Milestone Ladder:*\n` +
    `• 🎯 *1 Referral:* +5 Bonus Merit Points\n` +
    `• 🔓 *3 Referrals:* 7-Day Complimentary Scholar Pass (All Mock Tests)\n` +
    `• 👑 *10 Referrals:* Golden Ambassador Shield on All-India Leaderboard\n\n` +
    `Tap the button below to share directly with your study groups and friends:`;

  const keyboard = new InlineKeyboard()
    .url('📤 Share Invitation Link to Telegram', shareUrl)
    .row()
    .text('🏆 All-India Leaderboard', 'menu_global_lb')
    .row()
    .text('🔙 Back to Platform Dashboard', 'menu_start');

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
 * Handles incoming referral deep link on /start ref_<referrerId>
 */
export async function handleIncomingReferral(
  ctx: Context,
  supabase: SupabaseClient,
  referrerIdStr: string
) {
  const newUserId = ctx.from?.id;
  if (!newUserId) return;

  const referrerId = parseInt(referrerIdStr, 10);
  if (isNaN(referrerId) || referrerId === newUserId) return;

  const res = await processReferral(supabase, referrerId, newUserId);
  if (res.success) {
    const newUserName = ctx.from?.first_name || 'A candidate';
    const notifyMsg =
      `🎉 *NEW CANDIDATE ENROLLED VIA YOUR REFERRAL LINK!*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `*${newUserName}* has registered using your invitation link.\n\n` +
      `• 🏆 *Bonus Earned:* +5.00 All-India Merit Points\n` +
      `• 👥 *Total Enrolled:* ${res.totalReferrals} Candidate(s)\n\n` +
      (res.totalReferrals >= 3
        ? `🌟 *MILESTONE UNLOCKED:* You have reached 3 referrals! Your *Scholar Pass* has been unlocked!`
        : `_Only ${3 - res.totalReferrals} more referral(s) needed to unlock a free 7-Day Scholar Pass!_`);

    try {
      await ctx.api.sendMessage(referrerId, notifyMsg, { parse_mode: 'Markdown' });
    } catch (err) {
      console.warn(`Could not notify referrer ${referrerId}:`, err);
    }
  }
}
