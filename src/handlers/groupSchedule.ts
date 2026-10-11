import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getActiveQuizzes, getQuizById, isGroupAuthorized } from '../db/queries';
import { isGroupAdmin } from '../utils/admin';
import { activeGroupBattles, handleLaunchGroupQuiz } from './groupQuiz';

export interface ScheduledQuiz {
  chatId: number;
  quizId: string;
  quizTitle: string;
  targetTime: Date;
  timer: NodeJS.Timeout;
  reminderTimer?: NodeJS.Timeout;
  scheduledBy: string;
}

// In-memory registry of scheduled quizzes per group chat
export const scheduledGroupQuizzes = new Map<number, ScheduledQuiz>();

/**
 * Handles /schedule command in Telegram Groups
 */
export async function handleScheduleCommand(ctx: Context, supabase: SupabaseClient) {
  if (!ctx.chat) return;

  if (ctx.chat.type === 'private') {
    return ctx.reply(
      `⏰ *Group Quiz Scheduler*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Yeh feature Telegram Groups ke liye hai!\n\n` +
      `Apne group me automatic live quiz schedule karne ke liye:\n` +
      `1. Bot ko group me Admin banayein.\n` +
      `2. Group me type kijiye: \`/schedule\`\n\n` +
      `Aap 5 min, 15 min, 1 ghante baad quiz auto-start karwa sakte hain! 🎯`,
      { parse_mode: 'Markdown' }
    );
  }

  const chatId = ctx.chat.id;

  // Authorization check
  const isAuth = await isGroupAuthorized(supabase, chatId);
  if (!isAuth) {
    return ctx.reply('⚠️ Yeh group authorized nahi hai. Quiz schedule karne ke liye Bot Admin se sampark karein.');
  }

  // Admin permission check
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.reply('⚠️ Sirf Group Admins hi quiz schedule kar sakte hain.');
  }

  // Check if a quiz is already scheduled or currently running
  if (activeGroupBattles.has(chatId)) {
    return ctx.reply('⚠️ Is group me pehle se ek quiz chal raha hai! Pehle use pura hone dein.');
  }

  if (scheduledGroupQuizzes.has(chatId)) {
    const existing = scheduledGroupQuizzes.get(chatId)!;
    const remainingMs = existing.targetTime.getTime() - Date.now();
    const remainingMins = Math.max(1, Math.round(remainingMs / 60000));
    return ctx.reply(
      `⏰ *Quiz Pehle Se Scheduled Hai!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `📝 *Test:* ${existing.quizTitle}\n` +
      `⏳ *Shuru hone me bacha samay:* ~${remainingMins} minutes\n\n` +
      `Cancel karne ke liye type kijiye: \`/cancel_schedule\``,
      { parse_mode: 'Markdown' }
    );
  }

  const quizzes = await getActiveQuizzes(supabase);
  if (!quizzes || quizzes.length === 0) {
    return ctx.reply('⚠️ Abhi koi test active nahi hai.');
  }

  const keyboard = new InlineKeyboard();
  quizzes.forEach((quiz) => {
    keyboard.text(`📝 ${quiz.title}`, `sch_pick:${quiz.id}`).row();
  });

  await ctx.reply(
    `⏰ *SCHEDULE GROUP QUIZ*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `Kripya select kijiye ki kaun sa test group me schedule karna hai:`,
    {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    }
  );
}

/**
 * Handles user picking a quiz, then displays time delay options
 */
export async function handleSchedulePickQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string
) {
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.answerCallbackQuery({
      text: '⚠️ Sirf Group Admin hi schedule set kar sakta hai!',
      show_alert: true,
    });
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    return ctx.answerCallbackQuery({ text: 'Quiz nahi mila!', show_alert: true });
  }

  await ctx.answerCallbackQuery();

  const keyboard = new InlineKeyboard()
    .text('⏳ 2 Mins (Quick Demo)', `sch_set:${quiz.id}:2`)
    .text('⏳ 5 Mins', `sch_set:${quiz.id}:5`)
    .row()
    .text('⏳ 15 Mins', `sch_set:${quiz.id}:15`)
    .text('⏳ 30 Mins', `sch_set:${quiz.id}:30`)
    .row()
    .text('⏳ 1 Hour', `sch_set:${quiz.id}:60`)
    .text('⏳ 2 Hours', `sch_set:${quiz.id}:120`)
    .row()
    .text('❌ Cancel', 'sch_cancel');

  await ctx.editMessageText(
    `⏰ *Select Start Time for Quiz:*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n\n` +
    `Yeh quiz group me kitni der baad automatically start hona chahiye?`,
    {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    }
  );
}

/**
 * Confirms the schedule, sets up in-memory timers, and sends the group announcement
 */
export async function handleScheduleSetTime(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string,
  delayMinutes: number
) {
  const chatId = ctx.chat?.id;
  if (!chatId) return;

  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.answerCallbackQuery({
      text: '⚠️ Sirf Group Admin hi schedule set kar sakta hai!',
      show_alert: true,
    });
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    return ctx.answerCallbackQuery({ text: 'Quiz nahi mila!', show_alert: true });
  }

  // Cancel any previous scheduled quiz in this group
  cancelGroupSchedule(chatId);

  const delayMs = delayMinutes * 60 * 1000;
  const targetTime = new Date(Date.now() + delayMs);
  const timeFormatted = targetTime.toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
  });

  const adminName = ctx.from?.first_name || 'Admin';

  // 1-minute reminder timer if delay >= 2 mins
  let reminderTimer: NodeJS.Timeout | undefined;
  if (delayMinutes >= 2) {
    const reminderDelayMs = delayMs - 60 * 1000;
    reminderTimer = setTimeout(async () => {
      try {
        await ctx.api.sendMessage(
          chatId,
          `🚨 *1 MINUTE REMINDER!* 🚨\n━━━━━━━━━━━━━━━━━━━━━\n` +
          `Group quiz *${quiz.title}* theek 60 seconds me live shuru hoga!\n` +
          `Sabhi participants screen par ready rahein! 🎯`,
          { parse_mode: 'Markdown' }
        );
      } catch (err) {
        console.error('Error sending 1-minute schedule reminder:', err);
      }
    }, reminderDelayMs);
  }

  // Main start timer
  const timer = setTimeout(async () => {
    scheduledGroupQuizzes.delete(chatId);

    // Verify group still authorized
    const isAuth = await isGroupAuthorized(supabase, chatId);
    if (!isAuth) {
      await ctx.api.sendMessage(chatId, '⚠️ Group authorization expire ho chuki hai. Scheduled quiz start nahi ho paya.');
      return;
    }

    if (activeGroupBattles.has(chatId)) {
      await ctx.api.sendMessage(chatId, '⚠️ Dusra quiz pehle se chal raha hone ke karan scheduled quiz start nahi ho saka.');
      return;
    }

    // Launch group quiz automatically
    handleLaunchGroupQuiz(ctx, supabase, quizId).catch((err) => {
      console.error('Error auto-launching scheduled group quiz:', err);
    });
  }, delayMs);

  scheduledGroupQuizzes.set(chatId, {
    chatId,
    quizId,
    quizTitle: quiz.title,
    targetTime,
    timer,
    reminderTimer,
    scheduledBy: adminName,
  });

  await ctx.answerCallbackQuery({ text: `Quiz scheduled for ${delayMinutes} mins!` });

  const cancelKeyboard = new InlineKeyboard().text('🛑 Cancel Schedule', 'sch_cancel');

  await ctx.editMessageText(
    `⏰ *QUIZ SCHEDULED SUCCESSFULLY!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n` +
    `⏳ *Start Delay:* ${delayMinutes} Minutes\n` +
    `🕒 *Auto Start Time:* ${timeFormatted} (IST)\n` +
    `👤 *Scheduled By:* ${adminName}\n\n` +
    `⚡ Test shuru hone se 1 minute pehle reminder aayega. Admin chahein to neeche diye gaye button ya \`/cancel_schedule\` se kabhi bhi cancel kar sakte hain.`,
    {
      parse_mode: 'Markdown',
      reply_markup: cancelKeyboard,
    }
  );
}

/**
 * Cancels a group schedule
 */
export function cancelGroupSchedule(chatId: number): boolean {
  const existing = scheduledGroupQuizzes.get(chatId);
  if (!existing) return false;

  if (existing.timer) clearTimeout(existing.timer);
  if (existing.reminderTimer) clearTimeout(existing.reminderTimer);
  scheduledGroupQuizzes.delete(chatId);
  return true;
}

/**
 * Handles /cancel_schedule command
 */
export async function handleCancelScheduleCommand(ctx: Context) {
  if (!ctx.chat || ctx.chat.type === 'private') {
    return ctx.reply('⚠️ Yeh command Telegram groups ke liye hai.');
  }

  const chatId = ctx.chat.id;
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.reply('⚠️ Sirf Group Admins hi schedule cancel kar sakte hain.');
  }

  const wasCancelled = cancelGroupSchedule(chatId);
  if (wasCancelled) {
    await ctx.reply(
      `🛑 *SCHEDULED QUIZ CANCELLED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Admin dwara aane wala scheduled quiz cancel kar diya gaya hai.`,
      { parse_mode: 'Markdown' }
    );
  } else {
    await ctx.reply('ℹ️ Is group me koi quiz scheduled nahi hai.');
  }
}

/**
 * Handles /scheduled status check command
 */
export async function handleScheduledStatusCommand(ctx: Context) {
  if (!ctx.chat || ctx.chat.type === 'private') {
    return ctx.reply('⚠️ Yeh command Telegram groups ke liye hai.');
  }

  const chatId = ctx.chat.id;
  const existing = scheduledGroupQuizzes.get(chatId);

  if (!existing) {
    return ctx.reply('ℹ️ Is group me abhi koi quiz scheduled nahi hai. Schedule karne ke liye \`/schedule\` type karein.', {
      parse_mode: 'Markdown',
    });
  }

  const remainingMs = existing.targetTime.getTime() - Date.now();
  const remainingMins = Math.max(1, Math.round(remainingMs / 60000));
  const timeFormatted = existing.targetTime.toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
  });

  const cancelKeyboard = new InlineKeyboard().text('🛑 Cancel Schedule', 'sch_cancel');

  await ctx.reply(
    `⏰ *CURRENT SCHEDULED QUIZ:*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${existing.quizTitle}\n` +
    `🕒 *Start Time:* ${timeFormatted}\n` +
    `⏳ *Remaining:* ~${remainingMins} Minutes\n` +
    `👤 *Scheduled By:* ${existing.scheduledBy}`,
    {
      parse_mode: 'Markdown',
      reply_markup: cancelKeyboard,
    }
  );
}
