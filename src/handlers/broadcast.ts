import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { isAdmin } from '../utils/admin';

export interface PendingBroadcast {
  id: string;
  adminId: number;
  text?: string;
  photoFileId?: string;
  documentFileId?: string;
  caption?: string;
  replyToMessageId?: number;
  fromChatId: number;
}

// In-memory cache for pending broadcasts awaiting admin confirmation
export const pendingBroadcasts = new Map<string, PendingBroadcast>();

/**
 * Initiates the /broadcast command with preview and recipient selection
 */
export async function handleBroadcastCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) {
    return ctx.reply('⚠️ Access Denied: Broadcast console restricted to Platform Administrators.');
  }
  const userId = ctx.from!.id;

  const repliedMsg = ctx.message?.reply_to_message;
  let broadcastText: string | undefined;
  let photoFileId: string | undefined;
  let documentFileId: string | undefined;
  let caption: string | undefined;

  if (repliedMsg) {
    if (repliedMsg.text) {
      broadcastText = repliedMsg.text;
    } else if (repliedMsg.photo && repliedMsg.photo.length > 0) {
      // Pick highest resolution photo
      photoFileId = repliedMsg.photo[repliedMsg.photo.length - 1].file_id;
      caption = repliedMsg.caption;
    } else if (repliedMsg.document) {
      documentFileId = repliedMsg.document.file_id;
      caption = repliedMsg.caption;
    }
  } else {
    // Check if text was provided directly: /broadcast <message>
    const fullText = ctx.message?.text || '';
    const parts = fullText.split(' ');
    parts.shift(); // Remove /broadcast
    const messageContent = parts.join(' ').trim();

    if (!messageContent) {
      return ctx.reply(
        `📢 *ADMINISTRATIVE BROADCAST CONSOLE*\n━━━━━━━━━━━━━━━━━━━━━\n` +
        `Two broadcast dispatch methodologies are supported:\n\n` +
        `1️⃣ *Inline Transmission:*\n` +
        `\`/broadcast Attention Candidates: New National Mock Examination is now live!\`\n\n` +
        `2️⃣ *Media / Document Dispatch:*\n` +
        `Upload any announcement image, poster, or document, then *Reply* to that message with \`/broadcast\`.\n\n` +
        `An audience selector dialog will be presented before transmission begins.`,
        { parse_mode: 'Markdown' }
      );
    }
    broadcastText = messageContent;
  }

  // Count recipients in database
  const { count: usersCount } = await supabase
    .from('users')
    .select('id', { count: 'exact', head: true });

  const { count: groupsCount } = await supabase
    .from('authorized_groups')
    .select('group_id', { count: 'exact', head: true })
    .eq('is_active', true);

  const totalUsers = usersCount || 0;
  const totalGroups = groupsCount || 0;

  // Generate broadcast tracking ID
  const broadcastId = `bc_${Date.now()}`;
  pendingBroadcasts.set(broadcastId, {
    id: broadcastId,
    adminId: userId,
    text: broadcastText,
    photoFileId,
    documentFileId,
    caption,
    fromChatId: ctx.chat!.id,
  });

  let previewContent = '';
  if (photoFileId) {
    previewContent = `📸 *[Photo Attachment]*\n${caption ? `_${caption}_` : '_(No caption)_'}`;
  } else if (documentFileId) {
    previewContent = `📁 *[Document Attachment]*\n${caption ? `_${caption}_` : '_(No caption)_'}`;
  } else {
    previewContent = `💬 *Message:* \n"${broadcastText}"`;
  }

  const confirmKeyboard = new InlineKeyboard()
    .text(`👤 Registered Candidates (${totalUsers})`, `bcast_send:users:${broadcastId}`)
    .text(`🏛️ Authorized Groups (${totalGroups})`, `bcast_send:groups:${broadcastId}`)
    .row()
    .text(`🌐 All Channels (Users + Groups)`, `bcast_send:all:${broadcastId}`)
    .row()
    .text(`❌ Abort Transmission`, `bcast_cancel:${broadcastId}`);

  await ctx.reply(
    `📢 *BROADCAST DISPATCH CONTROLLER*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `🎯 *Audience Reach:*\n` +
    `  • 👤 Registered Candidates: \`${totalUsers}\`\n` +
    `  • 🏛️ Authorized Communities: \`${totalGroups}\`\n\n` +
    `📝 *Payload Preview:*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `${previewContent}\n━━━━━━━━━━━━━━━━━━━━━\n\n` +
    `Select the intended distribution audience to initialize transmission:`,
    {
      parse_mode: 'Markdown',
      reply_markup: confirmKeyboard,
    }
  );
}

/**
 * Handles confirmation click and runs background broadcast dispatch
 */
export async function handleBroadcastCallback(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  action: string,
  targetType: string,
  broadcastId: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: 'Unauthorized!', show_alert: true });
  }

  const broadcast = pendingBroadcasts.get(broadcastId);

  if (action === 'cancel') {
    pendingBroadcasts.delete(broadcastId);
    await ctx.answerCallbackQuery({ text: 'Transmission aborted.' });
    return ctx.editMessageText('❌ *Broadcast Aborted.* No outbound messages were dispatched.', {
      parse_mode: 'Markdown',
    });
  }

  if (!broadcast) {
    return ctx.answerCallbackQuery({
      text: 'Broadcast session expired. Please reinitiate via /broadcast.',
      show_alert: true,
    });
  }

  await ctx.answerCallbackQuery({ text: '🚀 Transmission in progress...' });
  pendingBroadcasts.delete(broadcastId);

  const statusMsg = await ctx.editMessageText(
    `🚀 *Broadcasting In Progress...*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `⏳ Dispatch sequence active. Processing batch queue...`,
    { parse_mode: 'Markdown' }
  );

  const statusMessageId = typeof statusMsg === 'object' && 'message_id' in statusMsg
    ? statusMsg.message_id
    : ctx.callbackQuery?.message?.message_id || 0;

  // Run dispatch in background so webhook responds immediately
  dispatchBroadcastInBackground(ctx, supabase, broadcast, targetType, statusMessageId).catch((err) => {
    console.error('Error in background broadcast:', err);
  });
}

async function dispatchBroadcastInBackground(
  ctx: Context,
  supabase: SupabaseClient,
  broadcast: PendingBroadcast,
  targetType: string,
  statusMessageId: number
) {
  const startTime = Date.now();
  const targetIds: number[] = [];

  // Fetch recipients based on selected audience
  if (targetType === 'users' || targetType === 'all') {
    const { data: users } = await supabase.from('users').select('id');
    if (users) {
      users.forEach((u) => targetIds.push(Number(u.id)));
    }
  }

  if (targetType === 'groups' || targetType === 'all') {
    const { data: groups } = await supabase
      .from('authorized_groups')
      .select('group_id')
      .eq('is_active', true);
    if (groups) {
      groups.forEach((g) => targetIds.push(Number(g.group_id)));
    }
  }

  const total = targetIds.length;
  let delivered = 0;
  let blocked = 0;
  let failed = 0;

  for (let i = 0; i < total; i++) {
    const targetChatId = targetIds[i];

    try {
      if (broadcast.photoFileId) {
        await ctx.api.sendPhoto(targetChatId, broadcast.photoFileId, {
          caption: broadcast.caption,
          parse_mode: 'Markdown',
        });
      } else if (broadcast.documentFileId) {
        await ctx.api.sendDocument(targetChatId, broadcast.documentFileId, {
          caption: broadcast.caption,
          parse_mode: 'Markdown',
        });
      } else if (broadcast.text) {
        await ctx.api.sendMessage(targetChatId, broadcast.text, {
          parse_mode: 'Markdown',
        });
      }
      delivered++;
    } catch (err: any) {
      const errStr = String(err?.message || err);
      if (errStr.includes('blocked') || errStr.includes('deactivated') || errStr.includes('403')) {
        blocked++;
      } else {
        failed++;
      }
    }

    // Rate-limiting delay: 40ms (~25 msgs/second)
    await sleep(40);

    // Live progress update every 30 messages
    if ((i + 1) % 30 === 0 && i + 1 < total) {
      try {
        await ctx.api.editMessageText(
          broadcast.fromChatId,
          statusMessageId,
          `🚀 *Broadcasting In Progress...*\n━━━━━━━━━━━━━━━━━━━━━\n` +
          `📤 Progress: \`${i + 1} / ${total}\`\n` +
          `✅ Delivered: \`${delivered}\` | 🚫 Blocked: \`${blocked}\``,
          { parse_mode: 'Markdown' }
        );
      } catch {}
    }
  }

  const durationSec = ((Date.now() - startTime) / 1000).toFixed(1);

  // Send final report
  try {
    await ctx.api.editMessageText(
      broadcast.fromChatId,
      statusMessageId,
      `✅ *BROADCAST DISPATCH COMPLETED*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `🎯 *Audience Sector:* ${targetType.toUpperCase()}\n` +
      `👥 *Recipients Targeted:* \`${total}\`\n` +
      `✅ *Successfully Delivered:* \`${delivered}\`\n` +
      `🚫 *Unreachable / Blocked:* \`${blocked}\`\n` +
      `⚠️ *Transmission Errors:* \`${failed}\`\n` +
      `⏱️ *Elapsed Duration:* \`${durationSec} seconds\``,
      { parse_mode: 'Markdown' }
    );
  } catch {
    await ctx.reply(
      `✅ *Broadcast Complete*\nDelivered: ${delivered}/${total} in ${durationSec}s.`,
      { parse_mode: 'Markdown' }
    );
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
