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
      `👋 *Hello Everyone!*\n` +
      `Main *Examplayer Bot* hoon. Yeh group pehle se authorized hai.\n` +
      `Test shuru karne ke liye Admin \`/groupquiz\` run kar sakte hain! 🎯`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  // Group is not authorized -> Notify Group
  await ctx.reply(
    `👋 *Hello Everyone!*\n` +
    `Main *Examplayer Bot* hoon. Is group ko use karne ke liye pehle Admin Authorization zaroori hai.\n` +
    `⏳ Bot Admin ko approval request bhej di gayi hai...`,
    { parse_mode: 'Markdown' }
  );

  // Notify Bot Admin in Private Chat if ADMIN_USER_ID is configured
  if (env.ADMIN_USER_ID) {
    const adminChatId = parseInt(env.ADMIN_USER_ID, 10);
    const addedByName = ctx.from?.first_name || 'Anonymous';
    const addedByUsername = ctx.from?.username ? `@${ctx.from.username}` : '';

    const text =
      `🔔 *NAYE GROUP NE BOT KO ADD KIYA HAI!*\n` +
      `━━━━━━━━━━━━━━━━━━━━━\n` +
      `👥 *Group Title:* ${chat.title}\n` +
      `🆔 *Group ID:* \`${chat.id}\`\n` +
      `👤 *Added By:* ${addedByName} ${addedByUsername}\n\n` +
      `Kya aap is group ko permission dena chahte hain?`;

    const keyboard = new InlineKeyboard()
      .text('✅ Approve Group', `grp_appr:${chat.id}:${encodeURIComponent(chat.title || 'Group')}`)
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
      `✅ *Group Approved!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `👥 Group: *${groupTitle}*\n` +
      `🆔 ID: \`${groupId}\`\n\n` +
      `Yeh group ab authorized hai. Yahan tests chalenge! 🚀`,
      { parse_mode: 'Markdown' }
    );

    // Notify the group
    try {
      await ctx.api.sendMessage(
        groupId,
        `🎉 *CONGRATULATIONS!*\n` +
        `━━━━━━━━━━━━━━━━━━━━━\n` +
        `Is group ko *Examplayer Bot* use karne ki permission mil gayi hai!\n` +
        `Admin ab \`/groupquiz\` run karke live battle shuru kar sakte hain. 🎯`,
        { parse_mode: 'Markdown' }
      );
    } catch {}
  } else {
    await revokeGroup(supabase, groupId);

    await ctx.editMessageText(
      `❌ *Group Rejected & Removed!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Group \`${groupId}\` ko reject kar diya gaya hai aur bot leave kar gaya hai.`,
      { parse_mode: 'Markdown' }
    );

    // Send parting message and leave
    try {
      await ctx.api.sendMessage(
        groupId,
        '⚠️ *Sorry, this group is not authorized to use Examplayer Bot.* Goodbye!'
      );
      await ctx.api.leaveChat(groupId);
    } catch {}
  }
}

// /auth command (run inside a group by bot admin)
export async function handleAuthCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const chat = ctx.chat;
  if (!chat || (chat.type !== 'group' && chat.type !== 'supergroup')) {
    await ctx.reply('⚠️ Yeh command kisi group ke andar run kijiye.');
    return;
  }

  // Security check: Strict bot admin only
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied! Sirf Bot Admin hi kisi group ko authorize kar sakta hai.');
    return;
  }

  await authorizeGroup(supabase, chat.id, chat.title || 'Group', ctx.from?.id);

  await ctx.reply(
    `✅ *GROUP AUTHORIZED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `👥 Group: *${chat.title}*\n` +
    `🆔 ID: \`${chat.id}\`\n\n` +
    `Ab is group me live quizzes chalenge! Type \`/groupquiz\` to start. 🚀`,
    { parse_mode: 'Markdown' }
  );
}

// /unauth command (run inside a group by bot admin)
export async function handleUnauthCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const chat = ctx.chat;
  if (!chat || (chat.type !== 'group' && chat.type !== 'supergroup')) {
    await ctx.reply('⚠️ Yeh command kisi group ke andar run kijiye.');
    return;
  }

  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied!');
    return;
  }

  await revokeGroup(supabase, chat.id);

  await ctx.reply(
    `🚫 *GROUP PERMISSION REVOKED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `Is group ki permission hata di gayi hai. Ab yahan quizzes nahi chalenge.`,
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
    await ctx.reply('⚠️ Access Denied! Sirf Bot Admin hi groups list dekh sakta hai.');
    return;
  }

  const groups = await getAuthorizedGroups(supabase);

  if (groups.length === 0) {
    await ctx.reply('ℹ️ Abhi koi bhi group authorized nahi hai.');
    return;
  }

  let text = `📋 *AUTHORIZED GROUPS LIST*\n━━━━━━━━━━━━━━━━━━━━━\n\n`;
  const keyboard = new InlineKeyboard();

  groups.forEach((g) => {
    const status = g.is_active ? '🟢 Active' : '🔴 Inactive';
    text += `👥 *${g.group_title}*\n`;
    text += `   ID: \`${g.group_id}\` | Status: ${status}\n\n`;

    if (g.is_active) {
      keyboard.text(`🔴 Revoke ${g.group_title.slice(0, 15)}`, `grp_rev:${g.group_id}`).row();
    } else {
      keyboard.text(`🟢 Activate ${g.group_title.slice(0, 15)}`, `grp_act:${g.group_id}:${encodeURIComponent(g.group_title)}`).row();
    }
  });

  await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
}
