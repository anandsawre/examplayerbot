import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getActiveQuizzes, getQuizById, isGroupAuthorized } from '../db/queries';
import { isGroupAdmin } from '../utils/admin';
import { activeGroupBattles, executeGroupQuizBattle } from './groupQuiz';

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

// In-memory cache for groups currently picking a custom date/time for a quiz
export const pendingCustomScheduleQuiz = new Map<number, { quizId: string; adminId: number }>();

/**
 * Formats a Date object in Indian Standard Time (IST, UTC+5:30)
 */
export function formatISTTime(date: Date): string {
  return date.toLocaleTimeString('en-IN', {
    timeZone: 'Asia/Kolkata',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  });
}

export function formatISTDate(date: Date): string {
  return date.toLocaleDateString('en-IN', {
    timeZone: 'Asia/Kolkata',
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

/**
 * Parses user input for time in Indian Standard Time (IST)
 * Supports:
 * - Minutes: "45", "45m", "30 mins", "2h", "1 hour"
 * - Daily Time: "18:30", "6:30 pm", "21:00", "9 pm"
 * - Date + Time: "12/10 10:00", "15-10 18:30", "12/10 7:30 pm"
 */
export function parseIndianDateTime(input: string): { target: Date; delayMs: number } | null {
  const str = input.trim().toLowerCase();
  const now = new Date();

  // 1. Check for pure minutes / hours
  const minMatch = str.match(/^(\d+)\s*(m|min|mins|minutes)?$/);
  if (minMatch) {
    const mins = parseInt(minMatch[1], 10);
    if (mins > 0) {
      const delayMs = mins * 60 * 1000;
      return { target: new Date(now.getTime() + delayMs), delayMs };
    }
  }

  const hourMatch = str.match(/^(\d+)\s*(h|hr|hrs|hours|hour)$/);
  if (hourMatch) {
    const hours = parseInt(hourMatch[1], 10);
    if (hours > 0) {
      const delayMs = hours * 60 * 60 * 1000;
      return { target: new Date(now.getTime() + delayMs), delayMs };
    }
  }

  // Get current date parts in IST
  const istFormatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    hour12: false,
  });

  const p: Record<string, string> = {};
  istFormatter.formatToParts(now).forEach((x) => (p[x.type] = x.value));
  const curYear = parseInt(p.year, 10);
  const curMonth = parseInt(p.month, 10) - 1; // 0-indexed
  const curDay = parseInt(p.day, 10);

  // 2. Check for Time Today: "18:30", "6:30 pm", "21:00", "9 pm"
  const timeMatch = str.match(/^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?$/);
  if (timeMatch && (timeMatch[2] !== undefined || timeMatch[3] !== undefined)) {
    let h = parseInt(timeMatch[1], 10);
    const m = timeMatch[2] ? parseInt(timeMatch[2], 10) : 0;
    const ampm = timeMatch[3];

    if (ampm === 'pm' && h < 12) h += 12;
    if (ampm === 'am' && h === 12) h = 0;

    if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
      // In IST (UTC+5:30), UTC hour = h - 5, UTC minute = m - 30
      const targetIST = new Date(Date.UTC(curYear, curMonth, curDay, h - 5, m - 30));

      // If the target time today has already passed, schedule for tomorrow at that time
      if (targetIST.getTime() <= now.getTime()) {
        targetIST.setUTCDate(targetIST.getUTCDate() + 1);
      }

      const delayMs = targetIST.getTime() - now.getTime();
      return { target: targetIST, delayMs };
    }
  }

  // 3. Check for Date + Time: "12/10 10:00", "12-10 18:30", "12/10 7:30 pm"
  const dateTimeMatch = str.match(/^(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?\s+(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?$/);
  if (dateTimeMatch) {
    const day = parseInt(dateTimeMatch[1], 10);
    const month = parseInt(dateTimeMatch[2], 10) - 1; // 0-indexed
    let year = dateTimeMatch[3] ? parseInt(dateTimeMatch[3], 10) : curYear;
    if (year < 100) year += 2000;

    let h = parseInt(dateTimeMatch[4], 10);
    const m = dateTimeMatch[5] ? parseInt(dateTimeMatch[5], 10) : 0;
    const ampm = dateTimeMatch[6];

    if (ampm === 'pm' && h < 12) h += 12;
    if (ampm === 'am' && h === 12) h = 0;

    if (h >= 0 && h <= 23 && m >= 0 && m <= 59 && day >= 1 && day <= 31) {
      const targetIST = new Date(Date.UTC(year, month, day, h - 5, m - 30));
      const delayMs = targetIST.getTime() - now.getTime();
      return { target: targetIST, delayMs };
    }
  }

  return null;
}

/**
 * Handles /schedule command in Telegram Groups
 */
export async function handleScheduleCommand(ctx: Context, supabase: SupabaseClient) {
  if (!ctx.chat) return;

  if (ctx.chat.type === 'private') {
    return ctx.reply(
      `⏰ *EXAMINATION SCHEDULER*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `This operational feature is designed specifically for authorized Community Groups.\n\n` +
      `*Setup Instructions:*\n` +
      `1. Add Examplayer Bot to your community group with Administrator privileges.\n` +
      `2. In the group, execute: \`/schedule\`\n\n` +
      `You may configure express launch delays (e.g. 15 mins) or target specific Indian Standard Time (IST) examination slots! 🎯`,
      { parse_mode: 'Markdown' }
    );
  }

  const chatId = ctx.chat.id;

  // Authorization check
  const isAuth = await isGroupAuthorized(supabase, chatId);
  if (!isAuth) {
    return ctx.reply('⚠️ Community group not authorized. Please contact the platform administrator to activate group privileges.');
  }

  // Admin permission check
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.reply('⚠️ Access Denied: Group quiz scheduling is restricted to Community Administrators.');
  }

  // Check if a quiz is currently running
  if (activeGroupBattles.has(chatId)) {
    return ctx.reply('⚠️ An active live examination battle is already in progress. Please await its conclusion.');
  }

  // Check if already scheduled
  if (scheduledGroupQuizzes.has(chatId)) {
    const existing = scheduledGroupQuizzes.get(chatId)!;
    const remainingMs = existing.targetTime.getTime() - Date.now();
    const remainingMins = Math.max(1, Math.round(remainingMs / 60000));
    const timeFormatted = formatISTTime(existing.targetTime);
    const dateFormatted = formatISTDate(existing.targetTime);

    return ctx.reply(
      `⏰ *ACTIVE SCHEDULE DETECTED*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `📝 *Examination:* ${existing.quizTitle}\n` +
      `📅 *Scheduled Date:* ${dateFormatted}\n` +
      `🕒 *Target Time:* ${timeFormatted} (IST)\n` +
      `⏳ *Time Remaining:* ~${remainingMins} minutes\n\n` +
      `To abort this scheduled session, execute: \`/cancel_schedule\``,
      { parse_mode: 'Markdown' }
    );
  }

  const quizzes = await getActiveQuizzes(supabase);
  if (!quizzes || quizzes.length === 0) {
    return ctx.reply('⚠️ No active examinations found in the repository.');
  }

  const keyboard = new InlineKeyboard();
  quizzes.forEach((quiz) => {
    keyboard.text(`📝 ${quiz.title}`, `sch_pick:${quiz.id}`).row();
  });

  await ctx.reply(
    `⏰ *SCHEDULE GROUP EXAMINATION*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `Select the examination module to schedule for this community group:`,
    {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    }
  );
}

/**
 * Handles user picking a quiz, then displays preset delays & custom date/time options
 */
export async function handleSchedulePickQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string
) {
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.answerCallbackQuery({
      text: '⚠️ Action restricted to Group Administrators.',
      show_alert: true,
    });
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    return ctx.answerCallbackQuery({ text: 'Examination not found.', show_alert: true });
  }

  await ctx.answerCallbackQuery();

  const keyboard = new InlineKeyboard()
    .text('⏱️ 2 Mins (Express)', `sch_set:${quiz.id}:2`)
    .text('⏱️ 5 Mins', `sch_set:${quiz.id}:5`)
    .row()
    .text('⏱️ 15 Mins', `sch_set:${quiz.id}:15`)
    .text('⏱️ 30 Mins', `sch_set:${quiz.id}:30`)
    .row()
    .text('⏱️ 1 Hour', `sch_set:${quiz.id}:60`)
    .text('⏱️ 2 Hours', `sch_set:${quiz.id}:120`)
    .row()
    .text('🕒 Today 08:00 PM IST', `sch_preset:${quiz.id}:20:00`)
    .text('🕒 Today 09:00 PM IST', `sch_preset:${quiz.id}:21:00`)
    .row()
    .text('📅 Custom Date & Time Slot', `sch_custom:${quiz.id}`)
    .row()
    .text('❌ Abort Scheduler', 'sch_cancel');

  await ctx.editMessageText(
    `⏰ *Select Examination Slot:*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n\n` +
    `Select an automated launch preset or specify a custom Indian Standard Time (IST) slot:`,
    {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    }
  );
}

/**
 * Prompts the admin to enter a custom date and time
 */
export async function handleScheduleCustomPrompt(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string
) {
  const chatId = ctx.chat?.id;
  if (!chatId) return;

  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.answerCallbackQuery({ text: '⚠️ Action restricted to Group Administrators.', show_alert: true });
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    return ctx.answerCallbackQuery({ text: 'Examination not found.', show_alert: true });
  }

  await ctx.answerCallbackQuery();

  // Save pending quiz for this group
  pendingCustomScheduleQuiz.set(chatId, { quizId, adminId: ctx.from!.id });

  const cancelKeyboard = new InlineKeyboard().text('❌ Abort', 'sch_cancel');

  await ctx.editMessageText(
    `🕒 *ENTER CUSTOM DATE & TIME (IST)*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n\n` +
    `You can schedule via any standard Indian Standard Time format:\n\n` +
    `1️⃣ *Today's Slot (HH:MM / 12-hour):*\n` +
    `• Command: \`/scheduletime 18:30\` _(06:30 PM IST)_\n` +
    `• Command: \`/scheduletime 7:30 PM\` _(07:30 PM IST)_\n` +
    `• Command: \`/scheduletime 21:00\` _(09:00 PM IST)_\n\n` +
    `2️⃣ *Specific Date & Time (DD/MM HH:MM):*\n` +
    `• Command: \`/scheduletime 12/10 10:00\` _(12 Oct at 10:00 AM IST)_\n\n` +
    `3️⃣ *Relative Minutes Delay:*\n` +
    `• Command: \`/scheduletime 45\` _(45 minutes delay)_\n\n` +
    `Submit your desired command in this group chat to confirm scheduling.`,
    {
      parse_mode: 'Markdown',
      reply_markup: cancelKeyboard,
    }
  );
}

/**
 * Handles preset time buttons like Tonight 08:00 PM
 */
export async function handleSchedulePresetTime(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string,
  timeStr: string
) {
  const parsed = parseIndianDateTime(timeStr);
  if (!parsed) {
    return ctx.answerCallbackQuery({ text: 'Invalid time preset', show_alert: true });
  }

  return setupGroupSchedule(ctx, supabase, quizId, parsed.target, parsed.delayMs);
}

/**
 * Confirms schedule by minutes delay (e.g. 2, 5, 15 mins)
 */
export async function handleScheduleSetTime(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string,
  delayMinutes: number
) {
  const delayMs = delayMinutes * 60 * 1000;
  const targetTime = new Date(Date.now() + delayMs);
  return setupGroupSchedule(ctx, supabase, quizId, targetTime, delayMs);
}

/**
 * Handles /scheduletime command for custom date and time
 */
export async function handleCustomTimeCommand(ctx: Context, supabase: SupabaseClient) {
  if (!ctx.chat || ctx.chat.type === 'private') {
    return ctx.reply('⚠️ Command restricted to Telegram community groups.');
  }

  const chatId = ctx.chat.id;

  const isAuth = await isGroupAuthorized(supabase, chatId);
  if (!isAuth) {
    return ctx.reply('⚠️ Community group not authorized.');
  }

  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.reply('⚠️ Access Denied: Group scheduling is restricted to Group Administrators.');
  }

  const text = ctx.message?.text || '';
  const parts = text.split(' ');
  parts.shift(); // remove /scheduletime
  const rawInput = parts.join(' ').trim();

  if (!rawInput) {
    return ctx.reply(
      `🕒 *Custom Schedule Command Syntax:*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Execute: \`/scheduletime <time_expression>\`\n\n` +
      `*Accepted Formats:*\n` +
      `• \`/scheduletime 18:30\` (24-Hour IST format)\n` +
      `• \`/scheduletime 7:00 PM\` (12-Hour IST format)\n` +
      `• \`/scheduletime 12/10 10:00\` (Date + Time)\n` +
      `• \`/scheduletime 45\` (Relative minutes delay)`,
      { parse_mode: 'Markdown' }
    );
  }

  // Find which quiz to schedule: check pendingCustomScheduleQuiz first, or use first active quiz
  let pending = pendingCustomScheduleQuiz.get(chatId);
  let quizId = pending?.quizId;

  if (!quizId) {
    const quizzes = await getActiveQuizzes(supabase);
    if (!quizzes || quizzes.length === 0) {
      return ctx.reply('⚠️ No active examinations found in the repository.');
    }
    quizId = quizzes[0].id;
  }

  const parsed = parseIndianDateTime(rawInput);
  if (!parsed) {
    return ctx.reply(
      `⚠️ *Unrecognized Time Expression*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Could not parse target time: "${rawInput}"\n\n` +
      `Please provide input adhering to standard formats:\n` +
      `• \`/scheduletime 18:30\` (24-Hour IST)\n` +
      `• \`/scheduletime 6:30 PM\` (12-Hour IST)\n` +
      `• \`/scheduletime 12/10 10:00\` (DD/MM HH:MM)\n` +
      `• \`/scheduletime 45\` (Relative minutes delay)`,
      { parse_mode: 'Markdown' }
    );
  }

  if (parsed.delayMs < 30 * 1000) {
    return ctx.reply('⚠️ Scheduled time must be at least 1 minute into the future.');
  }

  if (parsed.delayMs > 7 * 24 * 60 * 60 * 1000) {
    return ctx.reply('⚠️ Examinations may be scheduled up to a maximum of 7 days in advance.');
  }

  // Clear pending
  pendingCustomScheduleQuiz.delete(chatId);

  return setupGroupSchedule(ctx, supabase, quizId, parsed.target, parsed.delayMs);
}

/**
 * Internal shared worker to setup in-memory timers and group announcements
 */
async function setupGroupSchedule(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string,
  targetTime: Date,
  delayMs: number
) {
  const chatId = ctx.chat?.id;
  if (!chatId) return;

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({ text: 'Quiz nahi mila!', show_alert: true });
    } else {
      await ctx.reply('❌ Quiz nahi mila.');
    }
    return;
  }

  // Cancel any existing schedule for this group
  cancelGroupSchedule(chatId);

  const timeFormatted = formatISTTime(targetTime);
  const dateFormatted = formatISTDate(targetTime);
  const adminName = ctx.from?.first_name || 'Admin';
  const botUsername = ctx.me?.username || 'Examplayer_bot';

  // 1-minute reminder timer if delay >= 2 mins
  let reminderTimer: NodeJS.Timeout | undefined;
  if (delayMs >= 120 * 1000) {
    const reminderDelayMs = delayMs - 60 * 1000;
    reminderTimer = setTimeout(async () => {
      try {
        await ctx.api.sendMessage(
          chatId,
          `🚨 *1-MINUTE EXAMINATION NOTICE* 🚨\n━━━━━━━━━━━━━━━━━━━━━\n` +
          `Live assessment battle *${quiz.title}* will commence in exactly 60 seconds!\n` +
          `All participating candidates please prepare your screens. 🎯`,
          { parse_mode: 'Markdown' }
        );
      } catch (err) {
        console.error('Error sending 1-minute schedule reminder:', err);
      }
    }, reminderDelayMs);
  }

  // Main automated launch timer using executeGroupQuizBattle
  const timer = setTimeout(async () => {
    scheduledGroupQuizzes.delete(chatId);

    // Verify group still authorized
    const isAuth = await isGroupAuthorized(supabase, chatId);
    if (!isAuth) {
      await ctx.api.sendMessage(chatId, '⚠️ Group authorization has expired. Scheduled examination could not be initiated.');
      return;
    }

    if (activeGroupBattles.has(chatId)) {
      await ctx.api.sendMessage(chatId, '⚠️ An active assessment is currently running in this group. Scheduled launch skipped.');
      return;
    }

    // Launch group quiz with pure execution engine
    executeGroupQuizBattle(ctx.api, supabase, chatId, quizId, botUsername).catch((err) => {
      console.error('Error in executeGroupQuizBattle from schedule timer:', err);
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

  const remainingMins = Math.max(1, Math.round(delayMs / 60000));
  const cancelKeyboard = new InlineKeyboard().text('🛑 Cancel Scheduled Session', 'sch_cancel');

  const announcement =
    `⏰ *EXAMINATION SCHEDULED SUCCESSFULLY*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n` +
    `📅 *Scheduled Date:* ${dateFormatted}\n` +
    `🕒 *Auto-Launch Time:* ${timeFormatted} (IST)\n` +
    `⏳ *Countdown:* ~${remainingMins} Minutes\n` +
    `👤 *Scheduled By:* ${adminName}\n\n` +
    `⚡ A 1-minute alert will be dispatched prior to commencement. Group Administrators may cancel at any time via the button below or \`/cancel_schedule\`.`;

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: `Scheduled for ${timeFormatted} IST!` }).catch(() => {});
    try {
      await ctx.editMessageText(announcement, {
        parse_mode: 'Markdown',
        reply_markup: cancelKeyboard,
      });
    } catch {
      await ctx.reply(announcement, {
        parse_mode: 'Markdown',
        reply_markup: cancelKeyboard,
      });
    }
  } else {
    await ctx.reply(announcement, {
      parse_mode: 'Markdown',
      reply_markup: cancelKeyboard,
    });
  }
}

/**
 * Cancels a group schedule
 */
export function cancelGroupSchedule(chatId: number): boolean {
  const existing = scheduledGroupQuizzes.get(chatId);
  pendingCustomScheduleQuiz.delete(chatId);
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
    return ctx.reply('⚠️ Command restricted to Telegram community groups.');
  }

  const chatId = ctx.chat.id;
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.reply('⚠️ Access Denied: Only Group Administrators can cancel scheduled sessions.');
  }

  const wasCancelled = cancelGroupSchedule(chatId);
  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: 'Scheduled session cancelled.' }).catch(() => {});
  }

  if (wasCancelled) {
    await ctx.reply(
      `🛑 *SCHEDULED SESSION CANCELLED*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `The scheduled examination battle has been cancelled by an administrator.`,
      { parse_mode: 'Markdown' }
    );
  } else {
    await ctx.reply('ℹ️ No active scheduled examination session exists for this group.');
  }
}

/**
 * Handles /scheduled status check command
 */
export async function handleScheduledStatusCommand(ctx: Context) {
  if (!ctx.chat || ctx.chat.type === 'private') {
    return ctx.reply('⚠️ Command restricted to Telegram community groups.');
  }

  const chatId = ctx.chat.id;
  const existing = scheduledGroupQuizzes.get(chatId);

  if (!existing) {
    return ctx.reply('ℹ️ No examination currently scheduled. Administrators may initiate scheduling via `/schedule`.', {
      parse_mode: 'Markdown',
    });
  }

  const remainingMs = existing.targetTime.getTime() - Date.now();
  const remainingMins = Math.max(1, Math.round(remainingMs / 60000));
  const timeFormatted = formatISTTime(existing.targetTime);
  const dateFormatted = formatISTDate(existing.targetTime);

  const cancelKeyboard = new InlineKeyboard().text('🛑 Cancel Scheduled Session', 'sch_cancel');

  await ctx.reply(
    `⏰ *SCHEDULED EXAMINATION STATUS*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${existing.quizTitle}\n` +
    `📅 *Date:* ${dateFormatted}\n` +
    `🕒 *Target Time:* ${timeFormatted} (IST)\n` +
    `⏳ *Time Remaining:* ~${remainingMins} Minutes\n` +
    `👤 *Configured By:* ${existing.scheduledBy}`,
    {
      parse_mode: 'Markdown',
      reply_markup: cancelKeyboard,
    }
  );
}
