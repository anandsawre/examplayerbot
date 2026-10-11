import { Context } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { getSetting, setSetting } from '../db/queries';
import { isAdmin } from '../utils/admin';

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
