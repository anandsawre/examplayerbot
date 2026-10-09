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
    await ctx.reply('⚠️ Sirf Bot Admin hi settings access kar sakta hai.');
    return;
  }

  const upiId = await getSetting(supabase, 'upi_id', env.UPI_ID || 'Not Set');
  const price = await getSetting(supabase, 'premium_price', env.PREMIUM_PRICE || '99');
  const channel = await getSetting(supabase, 'required_channel', env.REQUIRED_CHANNEL || '');

  const channelText = channel ? channel : '❌ Disabled (Koi channel join zaroori nahi)';

  const text =
    `⚙️ *EXAMPLAYER BOT ADMIN DASHBOARD*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n\n` +
    `💳 *Current UPI ID:* \`${upiId}\`\n` +
    `💰 *Test Series Price:* \`₹${price}\`\n` +
    `📢 *Required Channel:* \`${channelText}\`\n\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `🛠️ *Settings Badalane Ke Liye Commands:*\n\n` +
    `• \`/setupi <new_upi>\`\n` +
    `  Example: \`/setupi rahul@okhdfcbank\`\n\n` +
    `• \`/setprice <amount>\`\n` +
    `  Example: \`/setprice 149\`\n\n` +
    `• \`/setchannel <@channel>\`\n` +
    `  Example: \`/setchannel @MyExamNotes\`\n\n` +
    `• \`/unsetchannel\`\n` +
    `  (Channel requirement band karne ke liye)\n\n` +
    `• \`/unlock <user_id>\`\n` +
    `  (Kisi student ko manual access dene ke liye)\n\n` +
    `• \`/groups\`\n` +
    `  (Authorized Telegram groups manage karne ke liye)`;

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
    await ctx.reply('⚠️ Format: `/setupi yourname@upi`\nExample: `/setupi rahul@okhdfcbank`', {
      parse_mode: 'Markdown',
    });
    return;
  }

  const newUpi = parts[1].trim();
  await setSetting(supabase, 'upi_id', newUpi);

  await ctx.reply(
    `✅ *UPI ID Successfully Updated!*\n━━━━━━━━━━━━━━━━━━━━━\nNaya UPI ID: \`${newUpi}\`\nAb students ko yahi UPI dikhega.`,
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
    await ctx.reply('⚠️ Format: `/setprice <amount>`\nExample: `/setprice 149`', {
      parse_mode: 'Markdown',
    });
    return;
  }

  const newPrice = parts[1].trim();
  if (isNaN(Number(newPrice))) {
    await ctx.reply('❌ Please valid number daaliye (jaise 99, 149, 199).');
    return;
  }

  await setSetting(supabase, 'premium_price', newPrice);

  await ctx.reply(
    `✅ *Test Series Price Successfully Updated!*\n━━━━━━━━━━━━━━━━━━━━━\nNaya Price: \`₹${newPrice}\``,
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
      '⚠️ Format: `/setchannel @ChannelUsername`\nExample: `/setchannel @TopperNotes`',
      { parse_mode: 'Markdown' }
    );
    return;
  }

  let channel = parts[1].trim();
  if (!channel.startsWith('@')) channel = `@${channel}`;

  await setSetting(supabase, 'required_channel', channel);

  await ctx.reply(
    `✅ *Required Channel Successfully Updated!*\n━━━━━━━━━━━━━━━━━━━━━\nChannel: \`${channel}\`\nAb naye students ko test dene se pehle is channel ko join karna hoga. 📢`,
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
    `✅ *Channel Requirement Removed!*\n━━━━━━━━━━━━━━━━━━━━━\nAb students bina kisi channel join kiye direct tests de sakenge.`,
    { parse_mode: 'Markdown' }
  );
}
