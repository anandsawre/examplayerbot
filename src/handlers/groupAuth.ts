import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import {
  isGroupAuthorized,
  authorizeGroup,
  revokeGroup,
  getAuthorizedGroups,
} from '../db/queries';
import { isAdmin } from '../utils/admin';

export async function handleBotAddedToGroup(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const chat = ctx.chat;
  if (!chat || (chat.type !== 'group' && chat.type !== 'supergroup')) return;

  const isAuth = await isGroupAuthorized(supabase, chat.id);
  if (isAuth) {
    await ctx.reply(
      `🏛️ *EXAMPLAYER EXAMINATION BOT*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `This community group is officially authorized.\n` +
      `Group Administrators may execute \`/groupquiz\` to initiate a live assessment battle! 🎯`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  // Group is not authorized -> Notify Group
  await ctx.reply(
    `🏛️ *EXAMPLAYER EXAMINATION BOT*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `Welcome! Group authorization is required before hosting examination battles.\n` +
    `⏳ An administrative authorization request has been dispatched to the platform administrator.`,
    { parse_mode: 'Markdown' }
  );

  // Notify Bot Admin in Private Chat if ADMIN_USER_ID is configured
  if (env.ADMIN_USER_ID) {
    const adminChatId = parseInt(env.ADMIN_USER_ID, 10);
    const addedByName = ctx.from?.first_name || 'Anonymous';
    const addedByUsername = ctx.from?.username ? `@${ctx.from.username}` : '';

    const text =
      `🔔 *NEW COMMUNITY ACCESS REQUEST*\n` +
      `━━━━━━━━━━━━━━━━━━━━━\n` +
      `👥 *Community Title:* ${chat.title}\n` +
      `🆔 *Group ID:* \`${chat.id}\`\n` +
      `👤 *Added By:* ${addedByName} ${addedByUsername}\n\n` +
      `Authorize this community group to host live examination battles?`;

    const keyboard = new InlineKeyboard()
      .text('✅ Authorize Group', `grp_appr:${chat.id}:${encodeURIComponent(chat.title || 'Group')}`)
      .text('❌ Reject & Leave', `grp_rejc:${chat.id}`);

    try {
      await ctx.api.sendMessage(adminChatId, text, {
        parse_mode: 'Markdown',
        reply_markup: keyboard,
      });
    } catch (err) {
      console.error('Failed to notify admin about new group:', err);
    }
  }
}

export async function handleGroupApprovalCallback(
  ctx: Context,
  supabase: SupabaseClient,
  action: 'appr' | 'rejc',
  groupIdStr: string,
  groupTitleStr?: string
) {
  const groupId = parseInt(groupIdStr, 10);
  const groupTitle = groupTitleStr ? decodeURIComponent(groupTitleStr) : 'Group';

  if (action === 'appr') {
    await authorizeGroup(supabase, groupId, groupTitle, ctx.from?.id);

    await ctx.editMessageText(
      `✅ *Group Authorization Approved*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `👥 Group: *${groupTitle}*\n` +
      `🆔 ID: \`${groupId}\`\n\n` +
      `Group status set to Active. Examinations enabled! 🚀`,
      { parse_mode: 'Markdown' }
    );

    // Notify the group
    try {
      await ctx.api.sendMessage(
        groupId,
        `🎉 *COMMUNITY ACCESS AUTHORIZED!*\n` +
        `━━━━━━━━━━━━━━━━━━━━━\n` +
        `This group has been granted full access to the *Examplayer Examination Platform*.\n` +
        `Administrators may now launch live assessments using \`/groupquiz\` or schedule sessions via \`/schedule\`. 🎯`,
        { parse_mode: 'Markdown' }
      );
    } catch {}
  } else {
    await revokeGroup(supabase, groupId);

    await ctx.editMessageText(
      `❌ *Group Access Rejected*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Authorization declined for Group \`${groupId}\`. Bot has departed the chat.`,
      { parse_mode: 'Markdown' }
    );

    // Send parting message and leave
    try {
      await ctx.api.sendMessage(
        groupId,
        '⚠️ *Notice: This group is not authorized to use Examplayer Bot.* Goodbye.'
      );
      await ctx.api.leaveChat(groupId);
    } catch {}
  }
}

// /auth command (run inside a group OR in private chat with group ID)
export async function handleAuthCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied: Group authorization is restricted to Platform Administrators.');
    return;
  }

  const chat = ctx.chat;
  const text = ctx.message?.text || '';
  const parts = text.split(' ').filter(Boolean);

  let targetGroupId: number | null = null;
  let targetGroupTitle = 'Group';

  if (chat && (chat.type === 'group' || chat.type === 'supergroup')) {
    targetGroupId = chat.id;
    targetGroupTitle = chat.title || 'Group';
  } else if (parts.length >= 2) {
    targetGroupId = parseInt(parts[1], 10);
    if (isNaN(targetGroupId)) {
      await ctx.reply('⚠️ Invalid syntax. Format: `/auth <group_id> [Optional Group Title]`', { parse_mode: 'Markdown' });
      return;
    }
    if (parts.length >= 3) {
      targetGroupTitle = parts.slice(2).join(' ');
    }
  } else {
    await ctx.reply(
      `ℹ️ *Group Authorization Syntax:*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `1. Within the target group, execute directly: \`/auth\`\n` +
      `2. Or in this chat, submit: \`/auth <group_id> [Group Title]\`\n\n` +
      `Example:\n\`/auth -100123456789 Railway Batch\``,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  await authorizeGroup(supabase, targetGroupId, targetGroupTitle, ctx.from?.id);

  await ctx.reply(
    `✅ *COMMUNITY GROUP AUTHORIZED*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `👥 Group: *${targetGroupTitle}*\n` +
    `🆔 ID: \`${targetGroupId}\`\n\n` +
    `Group is now authorized to run live examination battles via \`/groupquiz\`. 🚀`,
    { parse_mode: 'Markdown' }
  );

  // If authorized from private chat, try sending a notification to that group
  if (chat?.type === 'private') {
    try {
      await ctx.api.sendMessage(
        targetGroupId,
        `🎉 *COMMUNITY ACCESS AUTHORIZED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
        `This group has been authorized to access the *Examplayer Examination Platform*.\n` +
        `Administrators may launch live assessments using \`/groupquiz\`. 🎯`,
        { parse_mode: 'Markdown' }
      );
    } catch {}
  }
}

// /unauth command (run inside a group OR in private chat with group ID)
export async function handleUnauthCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied: Administrator privileges required.');
    return;
  }

  const chat = ctx.chat;
  const text = ctx.message?.text || '';
  const parts = text.split(' ').filter(Boolean);

  let targetGroupId: number | null = null;

  if (chat && (chat.type === 'group' || chat.type === 'supergroup')) {
    targetGroupId = chat.id;
  } else if (parts.length >= 2) {
    targetGroupId = parseInt(parts[1], 10);
    if (isNaN(targetGroupId)) {
      await ctx.reply('⚠️ Invalid Group ID. Syntax: `/unauth <group_id>`', { parse_mode: 'Markdown' });
      return;
    }
  } else {
    await ctx.reply('⚠️ Syntax: `/unauth` (inside group) or `/unauth <group_id>` (direct chat)');
    return;
  }

  await revokeGroup(supabase, targetGroupId);

  await ctx.reply(
    `🚫 *AUTHORIZATION REVOKED*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `Group authorization for \`${targetGroupId}\` has been revoked.`,
    { parse_mode: 'Markdown' }
  );
}

// /groups command (run in private chat by admin)
export async function handleListGroupsCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied: Group directory is restricted to Platform Administrators.');
    return;
  }

  const groups = await getAuthorizedGroups(supabase);

  if (groups.length === 0) {
    await ctx.reply('ℹ️ No community groups currently authorized.');
    return;
  }

  let text = `📋 *AUTHORIZED COMMUNITY GROUPS*\n━━━━━━━━━━━━━━━━━━━━━\n\n`;
  const keyboard = new InlineKeyboard();

  groups.forEach((g) => {
    const status = g.is_active ? '🟢 Active' : '🔴 Inactive';
    text += `👥 *${g.group_title}*\n`;
    text += `   ID: \`${g.group_id}\` | Status: ${status}\n\n`;

    if (g.is_active) {
      keyboard.text(`🔴 Revoke ${g.group_title.slice(0, 15)}`, `grp_rev:${g.group_id}`).row();
    } else {
      keyboard.text(`🟢 Authorize ${g.group_title.slice(0, 15)}`, `grp_act:${g.group_id}:${encodeURIComponent(g.group_title)}`).row();
    }
  });

  await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
}
