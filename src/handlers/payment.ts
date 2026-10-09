import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { getUser, setUserPremium, getSetting } from '../db/queries';
import { isAdmin } from '../utils/admin';

const DEFAULT_COUPONS = ['TOPPER2026', 'PASS2026', 'EXAMPLAYER'];

export async function showPaymentPrompt(ctx: Context, supabase: SupabaseClient, env: Env) {
  const price = await getSetting(supabase, 'premium_price', env.PREMIUM_PRICE || '99');
  const upiId = await getSetting(supabase, 'upi_id', env.UPI_ID || 'your-upi-id@okhdfcbank');

  const text =
    `👑 *EXAMPLAYER PREMIUM PASS (₹${price})*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `🔒 Yeh test sirf *Premium Pass* students ke liye hai.\n\n` +
    `✨ *Premium Pass Benefits:*\n` +
    `• 50+ Full-Length Mock Tests Unlocked\n` +
    `• Negative Marking & Step-by-Step Solutions\n` +
    `• All-India State Rank & Leaderboards\n` +
    `• Lifetime Validity\n\n` +
    `📲 *Pay via UPI (GPay / PhonePe / Paytm):*\n` +
    `UPI ID: \`${upiId}\`\n` +
    `Amount: \`₹${price}\`\n\n` +
    `👉 Payment karne ke baad apna *Payment Screenshot* yahan chat me Photo ke roop me bhej dijiye! 📸`;

  const keyboard = new InlineKeyboard()
    .text('📸 Send Screenshot', 'pay_send_ss')
    .text('🎟️ Redeem Code', 'menu_redeem_prompt')
    .row()
    .text('🔙 Back to Quizzes', 'menu_quizzes');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

// User uploaded a photo (Screenshot)
export async function handlePaymentPhotoUpload(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const photo = ctx.message?.photo;
  if (!photo || photo.length === 0) return;

  const userId = ctx.from?.id;
  if (!userId) return;

  const user = await getUser(supabase, userId);
  if (user?.is_premium) {
    await ctx.reply('ℹ️ Aapka Premium Pass pehle se active hai! Aap sabhi tests bina kisi lock ke de sakte hain.');
    return;
  }

  // Get largest photo file_id
  const largestPhoto = photo[photo.length - 1];

  // Reply to Student
  await ctx.reply(
    `✅ *Screenshot Receive Ho Gaya!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `Admin verification ke baad 2 minute me aapka Premium Pass activate ho jayega. ⏳\n` +
    `Activate hote hi aapko yahan message mil jayega!`,
    { parse_mode: 'Markdown' }
  );

  // Forward to Admin if configured
  if (env.ADMIN_USER_ID) {
    const adminChatId = parseInt(env.ADMIN_USER_ID, 10);
    const studentName = ctx.from?.first_name || 'Student';
    const studentUsername = ctx.from?.username ? `@${ctx.from.username}` : 'No Username';
    const currentPrice = await getSetting(supabase, 'premium_price', env.PREMIUM_PRICE || '99');

    const caption =
      `💳 *NAYA PAYMENT SCREENSHOT AAYA HAI!*\n` +
      `━━━━━━━━━━━━━━━━━━━━━\n` +
      `👤 *Student:* ${studentName} (${studentUsername})\n` +
      `🆔 *User ID:* \`${userId}\`\n` +
      `💰 *Amount:* ₹${currentPrice}\n\n` +
      `Screenshot verify karke approve ya reject kijiye:`;

    const adminKeyboard = new InlineKeyboard()
      .text('✅ Approve & Unlock', `pay_appr:${userId}`)
      .text('❌ Reject Payment', `pay_rejc:${userId}`);

    try {
      await ctx.api.sendPhoto(adminChatId, largestPhoto.file_id, {
        caption,
        parse_mode: 'Markdown',
        reply_markup: adminKeyboard,
      });
    } catch (err) {
      console.error('Failed to send payment photo to admin:', err);
    }
  }
}

// Admin callback to approve or reject payment
export async function handlePaymentApprovalCallback(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  action: 'appr' | 'rejc',
  userIdStr: string
) {
  if (!isAdmin(ctx, env)) {
    await ctx.answerCallbackQuery({ text: '⚠️ Access Denied!', show_alert: true });
    return;
  }

  const targetUserId = parseInt(userIdStr, 10);

  if (action === 'appr') {
    await setUserPremium(supabase, targetUserId, true);

    await ctx.editMessageCaption({
      caption: `✅ *PAYMENT APPROVED & UNLOCKED!*\n━━━━━━━━━━━━━━━━━━━━━\nStudent \`${targetUserId}\` ko Premium access mil gaya hai.`,
      parse_mode: 'Markdown',
    });

    // Notify the Student
    try {
      await ctx.api.sendMessage(
        targetUserId,
        `🎉 *BADHAI HO! PREMIUM PASS ACTIVATED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
        `Aapka payment verify ho chuka hai aur sabhi tests unlock ho gaye hain! 🚀\n\n` +
        `Abhi /quizzes me jaiye aur full mock tests practice shuru kijiye!`
      );
    } catch {}
  } else {
    await ctx.editMessageCaption({
      caption: `❌ *PAYMENT REJECTED!*\n━━━━━━━━━━━━━━━━━━━━━\nUser \`${targetUserId}\` ka payment request reject kar diya gaya hai.`,
      parse_mode: 'Markdown',
    });

    // Notify the Student
    try {
      await ctx.api.sendMessage(
        targetUserId,
        `❌ *Payment Verification Failed!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
        `Aapka payment verify nahi ho paya. Kripya valid transaction screenshot bhejein ya admin se contact karein.`
      );
    } catch {}
  }
}

// /unlock <userId> command for Admin
export async function handleUnlockCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) {
    await ctx.reply('⚠️ Access Denied! Sirf Admin hi kisi user ko unlock kar sakta hai.');
    return;
  }

  const parts = ctx.message?.text?.split(' ') || [];
  if (parts.length < 2) {
    await ctx.reply('⚠️ Format: `/unlock <telegram_user_id>`', { parse_mode: 'Markdown' });
    return;
  }

  const targetId = parseInt(parts[1], 10);
  if (isNaN(targetId)) {
    await ctx.reply('❌ Invalid user ID.');
    return;
  }

  await setUserPremium(supabase, targetId, true);
  await ctx.reply(`✅ User \`${targetId}\` successfully unlocked as Premium!`, { parse_mode: 'Markdown' });

  try {
    await ctx.api.sendMessage(
      targetId,
      `🎉 *PREMIUM PASS ACTIVATED BY ADMIN!*\n━━━━━━━━━━━━━━━━━━━━━\nAapke sabhi tests unlock ho chuke hain. /quizzes type karke practice shuru karein!`
    );
  } catch {}
}

// /redeem <code> command for Students
export async function handleRedeemCommand(ctx: Context, supabase: SupabaseClient) {
  const parts = ctx.message?.text?.split(' ') || [];
  if (parts.length < 2) {
    await ctx.reply('🎟️ Format: `/redeem <coupon_code>`\nExample: `/redeem TOPPER2026`', { parse_mode: 'Markdown' });
    return;
  }

  const code = parts[1].trim().toUpperCase();
  const userId = ctx.from?.id;
  if (!userId) return;

  if (DEFAULT_COUPONS.includes(code)) {
    await setUserPremium(supabase, userId, true);
    await ctx.reply(
      `🎉 *COUPON SUCCESSFULLY REDEEMED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Coupon Code *${code}* apply ho chuka hai! Aapka Premium Pass activate ho gaya hai. 🚀\n` +
      `/quizzes par jakar sabhi mock tests unlock dekhiye!`,
      { parse_mode: 'Markdown' }
    );
  } else {
    await ctx.reply('❌ Invalid Coupon Code! Kripya sahi code enter karein ya admin se sampark karein.');
  }
}
