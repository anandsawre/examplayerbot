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
    `📢 *MANDATORY CHANNEL SUBSCRIPTION REQUIRED*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Access to the examination repository requires verified membership in our official platform announcement channel.\n\n` +
    `👉 *After joining, select "Verify Membership Status" below to proceed:*`;

  const keyboard = new InlineKeyboard()
    .url('📢 Join Official Broadcast Channel', channelUrl)
    .row()
    .text('🔄 Verify Membership Status', targetAction ? `check_fsub:${targetAction}` : 'check_fsub:menu_quizzes');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}
