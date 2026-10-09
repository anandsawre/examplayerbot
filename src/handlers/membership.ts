import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { getSetting } from '../db/queries';

export async function checkChannelMembership(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
): Promise<{ isMember: boolean; channelUsername?: string; channelUrl?: string }> {
  const dynamicChannel = await getSetting(supabase, 'required_channel', env.REQUIRED_CHANNEL || '');
  const channel = dynamicChannel.trim();
  if (!channel) {
    return { isMember: true }; // Channel check not configured
  }

  const userId = ctx.from?.id;
  if (!userId) {
    return { isMember: false };
  }

  const channelUsername = channel.startsWith('@') ? channel.slice(1) : channel;
  const channelUrl = `https://t.me/${channelUsername}`;

  try {
    const member = await ctx.api.getChatMember(channel.startsWith('@') ? channel : `@${channel}`, userId);
    const validStatuses = ['creator', 'administrator', 'member', 'restricted'];

    if (validStatuses.includes(member.status)) {
      return { isMember: true, channelUsername, channelUrl };
    }
    return { isMember: false, channelUsername, channelUrl };
  } catch (err) {
    // If bot is not admin in the channel yet, avoid blocking users
    console.error('Channel check error (Ensure bot is Admin in the channel):', err);
    return { isMember: true, channelUsername, channelUrl };
  }
}

export async function sendJoinChannelPrompt(
  ctx: Context,
  channelUrl: string,
  targetAction?: string
) {
  const text =
    `📢 *OFFICIAL STUDY CHANNEL JOIN ZAROORI HAI!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `Examplayer Bot ke sabhi high-quality Mock Tests unlock karne ke liye pehle hamara Official Telegram Channel join kijiye.\n\n` +
    `👉 *Channel join karne ke baad "Verify Membership" button dabaiye:*`;

  const keyboard = new InlineKeyboard()
    .url('📢 Join Official Channel', channelUrl)
    .row()
    .text('🔄 Verify Membership', targetAction ? `check_fsub:${targetAction}` : 'check_fsub:menu_quizzes');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}
