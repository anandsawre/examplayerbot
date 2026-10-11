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
    return ctx.reply('⚠️ Yeh command sirf Bot Admin (@Anandsawre) ke liye arakshit hai.');
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
        `📢 *ADMIN GLOBAL BROADCAST TOOL*\n━━━━━━━━━━━━━━━━━━━━━\n` +
        `Broadcast message bhejne ke 2 aasan tareeqe hain:\n\n` +
        `1️⃣ *Direct Message:* Type kijiye:\n` +
        `\`/broadcast Priya students, kal subah 10 baje naya mock test live hoga!\`\n\n` +
        `2️⃣ *Photo / Post Broadcast:* Kisi bhi Photo, Poster ya Formatted message ko send karein, fir usko *Reply* karke type karein \`/broadcast\`!\n\n` +
        `Broadcast shuru karne se pehle bot aapse confirmation aur target audience puchega.`,
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
    .text(`👤 All Students (${totalUsers})`, `bcast_send:users:${broadcastId}`)
    .text(`🏛️ All Groups (${totalGroups})`, `bcast_send:groups:${broadcastId}`)
    .row()
    .text(`🌐 Everyone (Users + Groups)`, `bcast_send:all:${broadcastId}`)
    .row()
    .text(`❌ Cancel Broadcast`, `bcast_cancel:${broadcastId}`);

  await ctx.reply(
    `📢 *BROADCAST DISPATCH CONTROLLER*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `🎯 *Potential Reach:*\n` +
    `  • 👤 Registered Students: \`${totalUsers}\`\n` +
    `  • 🏛️ Authorized Groups: \`${totalGroups}\`\n\n` +
    `📝 *Content Preview:*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `${previewContent}\n━━━━━━━━━━━━━━━━━━━━━\n\n` +
    `Kripya select kijiye ki yeh message kinhe dispatch karna hai:`,
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
    await ctx.answerCallbackQuery({ text: 'Broadcast cancel kar diya gaya.' });
    return ctx.editMessageText('❌ *Broadcast Cancelled.* Koi bhi message send nahi kiya gaya.', {
      parse_mode: 'Markdown',
    });
  }

  if (!broadcast) {
    return ctx.answerCallbackQuery({
      text: 'Yeh broadcast session expire ho chuka hai. Kripya fir se /broadcast karein.',
      show_alert: true,
    });
  }

  await ctx.answerCallbackQuery({ text: '🚀 Broadcast shuru ho gaya!' });
  pendingBroadcasts.delete(broadcastId);

  const statusMsg = await ctx.editMessageText(
    `🚀 *Broadcasting In Progress...*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `⏳ Dispatch shuru ho gaya hai, kripya intezar karein...`,
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
      `✅ *BROADCAST DISPATCH COMPLETED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `🎯 *Audience:* ${targetType.toUpperCase()}\n` +
      `👥 *Total Targeted:* \`${total}\`\n` +
      `✅ *Successfully Delivered:* \`${delivered}\`\n` +
      `🚫 *Blocked / Deactivated:* \`${blocked}\`\n` +
      `⚠️ *Failed:* \`${failed}\`\n` +
      `⏱️ *Time Taken:* \`${durationSec} seconds\``,
      { parse_mode: 'Markdown' }
    );
  } catch {
    await ctx.reply(
      `✅ *Broadcast Complete!*\nDelivered: ${delivered}/${total} in ${durationSec}s.`,
      { parse_mode: 'Markdown' }
    );
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
