import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { getSetting, setSetting, getUser } from '../db/queries';
import {
  isAdmin,
  getRootAdmins,
  getAppointedAdmins,
  addAppointedAdmin,
  removeAppointedAdmin,
  syncAdminCache,
} from '../utils/admin';

// /admin or /settings command
export async function handleSettingsCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied: Administrative console restricted to Platform Administrators.');
    return;
  }

  const upiId = await getSetting(supabase, 'upi_id', env.UPI_ID || 'Not Set');
  const price = await getSetting(supabase, 'premium_price', env.PREMIUM_PRICE || '99');
  const channel = await getSetting(supabase, 'required_channel', env.REQUIRED_CHANNEL || '');

  const channelText = channel ? channel : '❌ Disabled (No subscription required)';

  const text =
    `⚙️ *ADMINISTRATIVE CONFIGURATION DASHBOARD*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n` +
    `💳 *Active UPI VPA:* \`${upiId}\`\n` +
    `💰 *Scholar Pass Tariff:* \`₹${price}\`\n` +
    `📢 *Mandatory Channel:* \`${channelText}\`\n\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `🛠️ *Administrative Console Commands:*\n\n` +
    `• \`/setupi <new_vpa>\`\n` +
    `  Configure settlement UPI VPA address.\n\n` +
    `• \`/setprice <amount>\`\n` +
    `  Update Scholar Pass registration fee.\n\n` +
    `• \`/setchannel <@channel>\`\n` +
    `  Enforce mandatory broadcast channel subscription.\n\n` +
    `• \`/unsetchannel\`\n` +
    `  Deactivate mandatory channel requirement.\n\n` +
    `• \`/unlock <user_id>\`\n` +
    `  Manually grant Premium Scholar Pass to a candidate.\n\n` +
    `• \`/admins\`\n` +
    `  View, Appoint & Remove Bot Administrators.\n\n` +
    `• \`/addadmin <user_id>\`\n` +
    `  Promote user to Platform Administrator.\n\n` +
    `• \`/removeadmin <user_id>\`\n` +
    `  Revoke administrator privileges from user.\n\n` +
    `• \`/groups\`\n` +
    `  Manage authorized community groups.\n\n` +
    `• \`/broadcast\`\n` +
    `  Dispatch platform-wide announcements.`;

  await ctx.reply(text, { parse_mode: 'Markdown' });
}

// /setupi <new_upi>
export async function handleSetUpi(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  const parts = ctx.message?.text?.trim().split(' ') || [];
  if (parts.length < 2) {
    await ctx.reply('⚠️ Syntax: `/setupi <upi_vpa>`\nExample: `/setupi examplayer@okhdfcbank`', {
      parse_mode: 'Markdown',
    });
    return;
  }

  const newUpi = parts[1].trim();
  await setSetting(supabase, 'upi_id', newUpi);

  await ctx.reply(
    `✅ *UPI VPA Address Updated*\n━━━━━━━━━━━━━━━━━━━━━\nSettlement VPA: \`${newUpi}\`\nThis address will be displayed on student payment invoices.`,
    { parse_mode: 'Markdown' }
  );
}

// /setprice <amount>
export async function handleSetPrice(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  const parts = ctx.message?.text?.trim().split(' ') || [];
  if (parts.length < 2) {
    await ctx.reply('⚠️ Syntax: `/setprice <amount>`\nExample: `/setprice 149`', {
      parse_mode: 'Markdown',
    });
    return;
  }

  const newPrice = parts[1].trim();
  if (isNaN(Number(newPrice))) {
    await ctx.reply('❌ Please enter a valid numerical amount (e.g. 99, 149, 199).');
    return;
  }

  await setSetting(supabase, 'premium_price', newPrice);

  await ctx.reply(
    `✅ *Scholar Pass Tariff Updated*\n━━━━━━━━━━━━━━━━━━━━━\nRegistration Fee: \`₹${newPrice}\``,
    { parse_mode: 'Markdown' }
  );
}

// /setchannel <@channel>
export async function handleSetChannel(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  const parts = ctx.message?.text?.trim().split(' ') || [];
  if (parts.length < 2) {
    await ctx.reply(
      '⚠️ Syntax: `/setchannel @ChannelUsername`\nExample: `/setchannel @ExamplayerAnnouncements`',
      { parse_mode: 'Markdown' }
    );
    return;
  }

  let channel = parts[1].trim();
  if (!channel.startsWith('@')) channel = `@${channel}`;

  await setSetting(supabase, 'required_channel', channel);

  await ctx.reply(
    `✅ *Mandatory Channel Updated*\n━━━━━━━━━━━━━━━━━━━━━\nChannel: \`${channel}\`\nNew candidates will be prompted to join before accessing tests. 📢`,
    { parse_mode: 'Markdown' }
  );
}

// /unsetchannel
export async function handleUnsetChannel(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  await setSetting(supabase, 'required_channel', '');

  await ctx.reply(
    `✅ *Channel Subscription Requirement Disabled*\n━━━━━━━━━━━━━━━━━━━━━\nCandidates may now access examinations directly without mandatory channel membership.`,
    { parse_mode: 'Markdown' }
  );
}

// ================= BOT ADMINISTRATOR MANAGEMENT =================

/**
 * /admins command or 'adm_list' callback
 * Displays the current list of primary and appointed administrators with interactive buttons.
 */
export async function handleListAdminsCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  isEdit = false
) {
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied: Administrative console restricted to Platform Administrators.');
    return;
  }

  // Ensure cache is freshly synchronized
  await syncAdminCache(supabase);

  const rootAdmins = getRootAdmins(env);
  const appointedAdmins = getAppointedAdmins();

  let text = `🛡️ *PLATFORM ADMINISTRATORS DIRECTORY*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

  text += `👑 *Primary Owner / Root Admin (Permanent):*\n`;
  for (const rootId of rootAdmins) {
    const user = await getUser(supabase, Number(rootId));
    const nameStr = user?.first_name ? `${user.first_name}${user.username ? ` (@${user.username})` : ''}` : 'Primary Creator';
    text += `• \`${rootId}\` — *${nameStr}*\n`;
  }
  text += `\n`;

  text += `👥 *Appointed Administrators (${appointedAdmins.length}):*\n`;
  if (appointedAdmins.length === 0) {
    text += `• _(Abhi koi appointed admin nahi hai. Naya admin jodte hi list yahan dikhegi.)_\n`;
  } else {
    for (const admId of appointedAdmins) {
      const user = await getUser(supabase, Number(admId));
      const nameStr = user?.first_name ? `${user.first_name}${user.username ? ` (@${user.username})` : ''}` : 'Active Admin';
      text += `• \`${admId}\` — *${nameStr}*\n`;
    }
  }

  text += `\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `🛠️ *Admin Management Commands:*\n`;
  text += `• \`/addadmin <user_id>\` — Grant admin access\n`;
  text += `  _(Tip: Kisi user ka message reply ya forward karke bhi \`/addadmin\` likh sakte hain)_\n`;
  text += `• \`/removeadmin <user_id>\` — Revoke admin access\n`;

  const keyboard = new InlineKeyboard();

  // Create 1-click remove buttons for each appointed admin
  appointedAdmins.forEach((admId) => {
    keyboard.text(`🗑️ Revoke ID: ${admId}`, `adm_rem:${admId}`).row();
  });

  keyboard
    .text('➕ How to Add Admin', 'adm_help_add')
    .text('🔄 Refresh List', 'adm_list')
    .row();

  if (isEdit && ctx.callbackQuery) {
    try {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    } catch {
      await ctx.editMessageText(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
    }
    ctx.answerCallbackQuery().catch(() => {});
  } else {
    try {
      await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    } catch {
      await ctx.reply(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
    }
  }
}

/**
 * /addadmin <user_id>
 * Promotes a Telegram user to full administrator.
 */
export async function handleAddAdminCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied: Only administrators can appoint other administrators.');
    return;
  }

  let targetIdStr = '';

  // 1. Check if replied to a message or forwarded message
  const replyMsg = ctx.message?.reply_to_message as any;
  if (replyMsg) {
    if (replyMsg.forward_origin?.type === 'user' && replyMsg.forward_origin?.sender_user?.id) {
      targetIdStr = String(replyMsg.forward_origin.sender_user.id);
    } else if (replyMsg.forward_from?.id) {
      targetIdStr = String(replyMsg.forward_from.id);
    } else if (replyMsg.from?.id) {
      targetIdStr = String(replyMsg.from.id);
    }
  }

  // 2. Check if user passed arguments: /addadmin 123456789
  if (!targetIdStr) {
    const parts = ctx.message?.text?.trim().split(/\s+/) || [];
    if (parts.length >= 2) {
      targetIdStr = parts[1].trim();
    }
  }

  if (!targetIdStr || isNaN(Number(targetIdStr))) {
    const helpText =
      `⚠️ *Admin Promotion Syntax:*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `1. *Direct ID Se:*\n` +
      `   \`/addadmin <user_id>\`\n` +
      `   Example: \`/addadmin 1234567890\`\n\n` +
      `2. *Message Reply / Forward Se:*\n` +
      `   Jis vyakti ko admin banana hai, unke message ya forwarded message ka reply karke \`/addadmin\` bhejein.\n\n` +
      `💡 *User ID kaise milegi:* User se bole ki wo @userinfobot par /id check karein.`;
    await ctx.reply(helpText, { parse_mode: 'Markdown' });
    return;
  }

  const rootAdmins = getRootAdmins(env);
  const appointedAdmins = getAppointedAdmins();

  if (rootAdmins.includes(targetIdStr)) {
    await ctx.reply(`ℹ️ User ID \`${targetIdStr}\` pehle se hi Primary Root Admin hai!`, {
      parse_mode: 'Markdown',
    });
    return;
  }

  if (appointedAdmins.includes(targetIdStr)) {
    await ctx.reply(`ℹ️ User ID \`${targetIdStr}\` pehle se hi Appointed Admin list me active hai!`, {
      parse_mode: 'Markdown',
    });
    return;
  }

  const success = await addAppointedAdmin(supabase, targetIdStr);
  if (!success) {
    await ctx.reply(`❌ Failed to update administrator records in database. Please check connection.`);
    return;
  }

  const user = await getUser(supabase, Number(targetIdStr));
  const nameStr = user?.first_name ? `${user.first_name}${user.username ? ` (@${user.username})` : ''}` : `User ID ${targetIdStr}`;

  const confirmText =
    `✅ *ADMINISTRATOR APPOINTED SUCCESSFULLY*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `👤 *User:* *${nameStr}*\n` +
    `🆔 *Telegram ID:* \`${targetIdStr}\`\n\n` +
    `🛡️ Inhe Examplayer Platform ke sabhi Administrative Privileges de diye gaye hain:\n` +
    `• Test Papers & Questions Import karna\n` +
    `• Examination Folders & Categories manage karna\n` +
    `• Students ke Payment Approvals (/unlock) karna\n` +
    `• Broadcast Messages dispatch karna\n\n` +
    `_Admin rights revoke karne ke liye \`/removeadmin ${targetIdStr}\` use karein._`;

  await ctx.reply(confirmText, { parse_mode: 'Markdown' });
}

/**
 * /removeadmin <user_id>
 * Revokes administrator privileges from a user.
 */
export async function handleRemoveAdminCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied: Only administrators can revoke admin privileges.');
    return;
  }

  let targetIdStr = '';

  const replyMsg = ctx.message?.reply_to_message;
  if (replyMsg?.from) {
    targetIdStr = String(replyMsg.from.id);
  }

  if (!targetIdStr) {
    const parts = ctx.message?.text?.trim().split(/\s+/) || [];
    if (parts.length >= 2) {
      targetIdStr = parts[1].trim();
    }
  }

  if (!targetIdStr || isNaN(Number(targetIdStr))) {
    await ctx.reply(
      `⚠️ *Admin Revocation Syntax:*\n\`/removeadmin <user_id>\`\nExample: \`/removeadmin 1234567890\``,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  const rootAdmins = getRootAdmins(env);
  if (rootAdmins.includes(targetIdStr)) {
    await ctx.reply(
      `❌ *Action Prohibited:* User ID \`${targetIdStr}\` Primary Bot Owner / Root Admin hai. Inhe remove nahi kiya ja sakta.`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  const appointedAdmins = getAppointedAdmins();
  if (!appointedAdmins.includes(targetIdStr)) {
    await ctx.reply(
      `⚠️ User ID \`${targetIdStr}\` appointed administrators list me nahi mila.`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  const success = await removeAppointedAdmin(supabase, targetIdStr);
  if (!success) {
    await ctx.reply(`❌ Failed to update administrator records. Please try again.`);
    return;
  }

  await ctx.reply(
    `✅ *Administrator Rights Revoked*\n━━━━━━━━━━━━━━━━━━━━━\nUser ID \`${targetIdStr}\` ko admin list se hata diya gaya hai. Ab wo kewal regular candidate access rakh sakte hain.`,
    { parse_mode: 'Markdown' }
  );
}

/**
 * Callback handler for interactive admin buttons (adm_list, adm_rem:<id>, adm_help_add)
 */
export async function handleAdminCallbackQuery(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const data = ctx.callbackQuery?.data;
  if (!data) return;

  if (!isAdmin(ctx, env)) {
    await ctx.answerCallbackQuery({
      text: '⚠️ Access Denied: Administrator console only.',
      show_alert: true,
    });
    return;
  }

  if (data === 'adm_list') {
    return handleListAdminsCommand(ctx, supabase, env, true);
  }

  if (data === 'adm_help_add') {
    await ctx.answerCallbackQuery({
      text: '💡 Naya admin appoint karne ke liye:\n/addadmin <user_id> send karein, ya user ke message ka reply karein.',
      show_alert: true,
    });
    return;
  }

  if (data.startsWith('adm_rem:')) {
    const targetIdStr = data.replace('adm_rem:', '').trim();
    const rootAdmins = getRootAdmins(env);
    if (rootAdmins.includes(targetIdStr)) {
      await ctx.answerCallbackQuery({
        text: '❌ Primary Owner cannot be removed!',
        show_alert: true,
      });
      return;
    }

    await removeAppointedAdmin(supabase, targetIdStr);
    await ctx.answerCallbackQuery({
      text: `✅ Admin rights revoked for ID: ${targetIdStr}`,
    });
    return handleListAdminsCommand(ctx, supabase, env, true);
  }
}

