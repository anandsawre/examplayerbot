import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import {
  getUser,
  getDailyQuestion,
  hasAttemptedDailyToday,
  recordDailyAttempt,
  recordMistake,
} from '../db/queries';

// Tracking map for daily polls: pollId -> { userId, questionId, correctOptionIndex }
export const dailyPollMap: Map<string, { userId: number; questionId: string; correctIndex: number }> = new Map();

/**
 * Renders the Candidate's Academic Streak Dossier
 */
export async function handleStreakCommand(ctx: Context, supabase: SupabaseClient) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const user = await getUser(supabase, userId);
  const studentName = user?.first_name || ctx.from?.first_name || 'Candidate';
  const streak = user?.streak_days || 1;
  const longest = user?.longest_streak || streak;
  const attemptedToday = await hasAttemptedDailyToday(supabase, userId);

  let tier = '🥉 Beginner Aspirant';
  if (streak >= 30) tier = '👑 Grandmaster Scholar';
  else if (streak >= 15) tier = '💎 Elite Scholar';
  else if (streak >= 7) tier = '🥇 Dedicated Aspirant';
  else if (streak >= 3) tier = '🥈 Active Aspirant';

  const text =
    `🔥 *CANDIDATE STUDY STREAK & DISCIPLINE DOSSIER*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Candidate: *${studentName}*\n` +
    `Tier Classification: *${tier}*\n\n` +
    `📈 *Current Daily Streak:* 🔥 *${streak} Day(s) Active*\n` +
    `🏆 *Peak All-Time Streak:* ⭐ *${longest} Day(s)*\n` +
    `📅 *Today's Daily Drill:* ${attemptedToday ? '✅ *Completed*' : '⏳ *Pending Attempt*'}\n\n` +
    `🎯 *Streak Milestone Rewards:*\n` +
    `• 🥉 *3-Day Streak:* Base Discipline Badge\n` +
    `• 🥈 *7-Day Streak:* +10 All-India Merit Points Bonus\n` +
    `• 💎 *15-Day Streak:* Complimentary 3-Day Scholar Pass\n` +
    `• 👑 *30-Day Streak:* Permanent All-India Hall of Fame Badge\n\n` +
    `${attemptedToday ? '_Your streak is secured for today. Next Question unlocks at 05:30 AM IST._' : '_Attempt today\'s Question of the Day now to maintain your active streak!_'}`;

  const keyboard = new InlineKeyboard();

  if (!attemptedToday) {
    keyboard.text('📅 Attempt Today\'s Question of the Day', 'menu_daily_qotd').row();
  }
  keyboard.text('📚 Browse Mock Examinations', 'menu_quizzes').row();
  keyboard.text('🔙 Back to Platform Dashboard', 'menu_start');

  if (ctx.callbackQuery) {
    try {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      await ctx.answerCallbackQuery();
      return;
    } catch {}
  }

  await ctx.reply(text, {
    parse_mode: 'Markdown',
    reply_markup: keyboard,
  });
}

/**
 * Serves Today's Official Question of the Day (QOTD)
 */
export async function handleDailyQotdCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const userId = ctx.from?.id;
  if (!userId) return;

  if (ctx.chat?.type !== 'private') {
    const botUsername = ctx.me.username;
    const url = `https://t.me/${botUsername}?start=daily`;
    const keyboard = new InlineKeyboard().url('📝 Attempt in Direct Message', url);
    if (ctx.callbackQuery) await ctx.answerCallbackQuery();
    return ctx.reply(
      `⚠️ *Question of the Day must be attempted in private chat.* Tap below to access:`,
      { reply_markup: keyboard }
    );
  }

  const alreadyAttempted = await hasAttemptedDailyToday(supabase, userId);
  if (alreadyAttempted) {
    const user = await getUser(supabase, userId);
    const text =
      `✅ *TODAY'S QUESTION ALREADY ATTEMPTED*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `You have already completed today's official drill.\n\n` +
      `🔥 *Current Streak:* ${user?.streak_days || 1} Day(s)\n` +
      `⏰ *Next Question Available:* Tomorrow at 00:00 UTC (05:30 AM IST).\n\n` +
      `Feel free to attempt complete mock examinations via /quizzes!`;

    const keyboard = new InlineKeyboard()
      .text('📚 Browse Full Mock Tests', 'menu_quizzes')
      .row()
      .text('🔥 View Streak Dossier', 'menu_streak');

    if (ctx.callbackQuery) {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      await ctx.answerCallbackQuery();
      return;
    }
    return ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }

  const question = await getDailyQuestion(supabase);
  if (!question) {
    if (ctx.callbackQuery) await ctx.answerCallbackQuery({ text: 'No questions available.' });
    return ctx.reply('⚠️ No questions currently available in the examination vault.');
  }

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery();
  }

  const todayStr = new Date().toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });

  const rawOptions = Array.isArray(question.options)
    ? question.options
    : typeof question.options === 'string'
    ? JSON.parse(question.options)
    : [];

  const cleanOptions = rawOptions.map((opt: any) =>
    String(opt).replace(/<[^>]*>?/gm, '').trim().slice(0, 100)
  );

  const pollHeader = `📅 [DAILY QUESTION OF THE DAY — ${todayStr.toUpperCase()}]\n\n${question.question_text}`;

  try {
    const pollMessage = await ctx.api.sendPoll(
      userId,
      pollHeader,
      cleanOptions,
      {
        type: 'quiz',
        correct_option_id: question.correct_option_index,
        is_anonymous: false,
        open_period: 45, // 45 seconds timer
        explanation: question.explanation ? question.explanation.slice(0, 200) : undefined,
      } as any
    );

    // Track poll in map
    dailyPollMap.set(pollMessage.poll.id, {
      userId,
      questionId: question.id,
      correctIndex: question.correct_option_index,
    });
  } catch (err) {
    console.error('Error sending Daily QOTD poll:', err);
    await ctx.reply('⚠️ Unable to deliver today\'s question. Please try again later.');
  }
}

/**
 * Handles user answering the Daily QOTD Poll
 */
export async function handleDailyPollAnswer(
  ctx: Context,
  supabase: SupabaseClient
): Promise<boolean> {
  const pollAnswer = ctx.pollAnswer;
  if (!pollAnswer || !pollAnswer.user) return false;

  const entry = dailyPollMap.get(pollAnswer.poll_id);
  if (!entry) return false;

  dailyPollMap.delete(pollAnswer.poll_id);

  const userId = pollAnswer.user.id;
  const selectedIndex = pollAnswer.option_ids[0];
  const isCorrect = selectedIndex === entry.correctIndex;

  // Record daily attempt and update streak
  const streakRes = await recordDailyAttempt(supabase, userId, entry.questionId, isCorrect);

  // If wrong, also record into Mistake Vault!
  if (!isCorrect) {
    await recordMistake(supabase, userId, entry.questionId, '');
  }

  const resultBanner = isCorrect
    ? `🎉 *CORRECT RESPONSE! (+2.0 Marks)*`
    : `❌ *INCORRECT RESPONSE*\n_This question has been added to your Mistake Vault (/mistakes) for targeted revision._`;

  const streakMsg =
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `${resultBanner}\n\n` +
    `🔥 *ACTIVE STUDY STREAK: ${streakRes.currentStreak} CONSECUTIVE DAYS!*\n` +
    `🏆 *Peak Streak:* ${streakRes.longestStreak} Day(s)\n\n` +
    `_Outstanding commitment! Your daily discipline has been registered in the All-India database._`;

  const keyboard = new InlineKeyboard()
    .text('🔥 View Streak Dossier', 'menu_streak')
    .text('📚 Browse All Mock Tests', 'menu_quizzes');

  try {
    await ctx.api.sendMessage(userId, streakMsg, {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    });
  } catch (err) {
    console.error('Error sending streak confirmation:', err);
  }

  return true;
}
