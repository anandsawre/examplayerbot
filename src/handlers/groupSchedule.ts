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
      `⏰ *Group Quiz Scheduler*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Yeh feature Telegram Groups ke liye hai!\n\n` +
      `Apne group me automatic live quiz schedule karne ke liye:\n` +
      `1. Bot ko group me Admin banayein.\n` +
      `2. Group me type kijiye: \`/schedule\`\n\n` +
      `Aap delay (e.g. 15 min) ya exact custom time (e.g. 07:00 PM) par quiz auto-start karwa sakte hain! 🎯`,
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

  // Check if a quiz is currently running
  if (activeGroupBattles.has(chatId)) {
    return ctx.reply('⚠️ Is group me pehle se ek quiz chal raha hai! Pehle use pura hone dein.');
  }

  // Check if already scheduled
  if (scheduledGroupQuizzes.has(chatId)) {
    const existing = scheduledGroupQuizzes.get(chatId)!;
    const remainingMs = existing.targetTime.getTime() - Date.now();
    const remainingMins = Math.max(1, Math.round(remainingMs / 60000));
    const timeFormatted = formatISTTime(existing.targetTime);
    const dateFormatted = formatISTDate(existing.targetTime);

    return ctx.reply(
      `⏰ *Quiz Pehle Se Scheduled Hai!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `📝 *Test:* ${existing.quizTitle}\n` +
      `📅 *Date:* ${dateFormatted}\n` +
      `🕒 *Start Time:* ${timeFormatted} (IST)\n` +
      `⏳ *Remaining:* ~${remainingMins} minutes\n\n` +
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
    .text('🕒 Tonight 08:00 PM', `sch_preset:${quiz.id}:20:00`)
    .text('🕒 Tonight 09:00 PM', `sch_preset:${quiz.id}:21:00`)
    .row()
    .text('✏️ Custom Date / Time (Enter manually)', `sch_custom:${quiz.id}`)
    .row()
    .text('❌ Cancel', 'sch_cancel');

  await ctx.editMessageText(
    `⏰ *Select Start Time for Quiz:*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n\n` +
    `Yeh quiz group me kab automatically shuru hona chahiye? Preset chunein ya custom time enter karein:`,
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
    return ctx.answerCallbackQuery({ text: '⚠️ Sirf Group Admin hi time set kar sakte hain!', show_alert: true });
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    return ctx.answerCallbackQuery({ text: 'Quiz nahi mila!', show_alert: true });
  }

  await ctx.answerCallbackQuery();

  // Save pending quiz for this group
  pendingCustomScheduleQuiz.set(chatId, { quizId, adminId: ctx.from!.id });

  const cancelKeyboard = new InlineKeyboard().text('❌ Cancel', 'sch_cancel');

  await ctx.editMessageText(
    `🕒 *ENTER CUSTOM DATE & TIME (IST)*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n\n` +
    `Aap kisi bhi convenient format me time set kar sakte hain:\n\n` +
    `1️⃣ *Aaj ka Time (HH:MM):*\n` +
    `Type: \`/scheduletime 18:30\` _(Shaam 6:30 baje)_\n` +
    `Type: \`/scheduletime 7:30 PM\` _(Shaam 7:30 baje)_\n` +
    `Type: \`/scheduletime 21:00\` _(Raat 9:00 baje)_\n\n` +
    `2️⃣ *Specific Date & Time (DD/MM HH:MM):*\n` +
    `Type: \`/scheduletime 12/10 10:00\` _(12 Oct subah 10:00 baje)_\n\n` +
    `3️⃣ *Minutes baad:*\n` +
    `Type: \`/scheduletime 45\` _(45 minute baad)_\n\n` +
    `Kripya is chat me command type karke send karein! ⬇️`,
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
    return ctx.reply('⚠️ Yeh command Telegram groups ke liye hai.');
  }

  const chatId = ctx.chat.id;

  const isAuth = await isGroupAuthorized(supabase, chatId);
  if (!isAuth) {
    return ctx.reply('⚠️ Yeh group authorized nahi hai.');
  }

  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.reply('⚠️ Sirf Group Admins hi schedule set kar sakte hain.');
  }

  const text = ctx.message?.text || '';
  const parts = text.split(' ');
  parts.shift(); // remove /scheduletime
  const rawInput = parts.join(' ').trim();

  if (!rawInput) {
    return ctx.reply(
      `🕒 *Custom Schedule Format:*\n\n` +
      `Type kijiye: \`/scheduletime <time>\`\n\n` +
      `Examples:\n` +
      `• \`/scheduletime 18:30\` (Shaam 6:30 baje)\n` +
      `• \`/scheduletime 7:00 PM\` (Shaam 7:00 baje)\n` +
      `• \`/scheduletime 12/10 10:00\` (12 Oct subah 10 baje)\n` +
      `• \`/scheduletime 45\` (45 minute baad)`,
      { parse_mode: 'Markdown' }
    );
  }

  // Find which quiz to schedule: check pendingCustomScheduleQuiz first, or use first active quiz
  let pending = pendingCustomScheduleQuiz.get(chatId);
  let quizId = pending?.quizId;

  if (!quizId) {
    const quizzes = await getActiveQuizzes(supabase);
    if (!quizzes || quizzes.length === 0) {
      return ctx.reply('⚠️ Abhi koi test active nahi hai.');
    }
    quizId = quizzes[0].id;
  }

  const parsed = parseIndianDateTime(rawInput);
  if (!parsed) {
    return ctx.reply(
      `⚠️ *Invalid Time Format!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Ham aapka time recognize nahi kar sake: "${rawInput}"\n\n` +
      `Kripya inme se kisi format me likhein:\n` +
      `• \`/scheduletime 18:30\` (24-hour)\n` +
      `• \`/scheduletime 6:30 PM\` (12-hour)\n` +
      `• \`/scheduletime 12/10 10:00\` (Date + Time)\n` +
      `• \`/scheduletime 45\` (Minutes)`,
      { parse_mode: 'Markdown' }
    );
  }

  if (parsed.delayMs < 30 * 1000) {
    return ctx.reply('⚠️ Schedule time vartaman samay se kam se kam 1 minute aage hona chahiye.');
  }

  if (parsed.delayMs > 7 * 24 * 60 * 60 * 1000) {
    return ctx.reply('⚠️ Test ko maximum 7 din tak ke liye hi schedule kiya ja sakta hai.');
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

  // Main automated launch timer using executeGroupQuizBattle
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
  const cancelKeyboard = new InlineKeyboard().text('🛑 Cancel Schedule', 'sch_cancel');

  const announcement =
    `⏰ *QUIZ SCHEDULED SUCCESSFULLY!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n` +
    `📅 *Date:* ${dateFormatted}\n` +
    `🕒 *Auto Start Time:* ${timeFormatted} (IST)\n` +
    `⏳ *Starting in:* ~${remainingMins} Minutes\n` +
    `👤 *Scheduled By:* ${adminName}\n\n` +
    `⚡ Test shuru hone se 1 minute pehle reminder aayega. Admin chahein to neeche diye gaye button ya \`/cancel_schedule\` se kabhi bhi cancel kar sakte hain.`;

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
    return ctx.reply('⚠️ Yeh command Telegram groups ke liye hai.');
  }

  const chatId = ctx.chat.id;
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.reply('⚠️ Sirf Group Admins hi schedule cancel kar sakte hain.');
  }

  const wasCancelled = cancelGroupSchedule(chatId);
  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: 'Schedule cancelled!' }).catch(() => {});
  }

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
    return ctx.reply('ℹ️ Is group me abhi koi quiz scheduled nahi hai. Schedule karne ke liye `/schedule` type karein.', {
      parse_mode: 'Markdown',
    });
  }

  const remainingMs = existing.targetTime.getTime() - Date.now();
  const remainingMins = Math.max(1, Math.round(remainingMs / 60000));
  const timeFormatted = formatISTTime(existing.targetTime);
  const dateFormatted = formatISTDate(existing.targetTime);

  const cancelKeyboard = new InlineKeyboard().text('🛑 Cancel Schedule', 'sch_cancel');

  await ctx.reply(
    `⏰ *CURRENT SCHEDULED QUIZ:*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${existing.quizTitle}\n` +
    `📅 *Date:* ${dateFormatted}\n` +
    `🕒 *Start Time:* ${timeFormatted} (IST)\n` +
    `⏳ *Remaining:* ~${remainingMins} Minutes\n` +
    `👤 *Scheduled By:* ${existing.scheduledBy}`,
    {
      parse_mode: 'Markdown',
      reply_markup: cancelKeyboard,
    }
  );
}
