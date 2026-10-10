import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getActiveQuizzes, getQuizById, getQuestionsForQuiz, isGroupAuthorized } from '../db/queries';
import { isGroupAdmin } from '../utils/admin';

export async function handleGroupQuizCommand(ctx: Context, supabase: SupabaseClient) {
  if (!ctx.chat) return;
  const chatType = ctx.chat.type;

  // If used in private chat
  if (chatType === 'private') {
    await ctx.reply(
      `👥 *Group Quiz Feature*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Yeh feature Telegram Groups ke liye hai!\n\n` +
      `1. Bot ko apne Telegram Group me add kijiye.\n` +
      `2. Bot ko *Admin* permissions dijiye (Send Polls & Pin messages).\n` +
      `3. Group me type kijiye: \`/groupquiz\`\n\n` +
      `Aur pure group ke saath live countdown battle kheliye! 🎯`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  // Check if this group is authorized
  const isAuth = await isGroupAuthorized(supabase, ctx.chat.id);
  if (!isAuth) {
    await ctx.reply(
      `⚠️ *Group Not Authorized!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Is group ko Examplayer Bot use karne ki permission nahi hai.\n` +
      `Permission enable karne ke liye Bot Admin se sampark karein.`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  // Verify that the caller is an Admin in the group
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    await ctx.reply('⚠️ Sirf Group Admins hi group quiz launch kar sakte hain.');
    return;
  }

  // Check if a quiz is already in progress
  if (activeGroupBattles.has(ctx.chat.id)) {
    await ctx.reply('⚠️ Is group me pehle se ek quiz chal raha hai! Pehle use pura hone dein ya /stopquiz karein.');
    return;
  }

  const quizzes = await getActiveQuizzes(supabase);
  if (!quizzes || quizzes.length === 0) {
    await ctx.reply('⚠️ Abhi koi test active nahi hai.');
    return;
  }

  let text = `👥 *GROUP LIVE QUIZ LAUNCHER*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `Kripya choose kijiye ki is group me kaun sa mock test live chalana hai:\n`;

  const keyboard = new InlineKeyboard();
  quizzes.forEach((quiz) => {
    keyboard.text(`🚀 ${quiz.title}`, `launch_grp:${quiz.id}`).row();
  });

  await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
}

export interface GroupParticipant {
  userId: number;
  name: string;
  correctCount: number;
}

export interface GroupQuizBattle {
  chatId: number;
  quizId: string;
  currentPollId?: string;
  currentCorrectIndex: number;
  participants: Map<number, GroupParticipant>;
  isCancelled?: boolean;
}

export const activeGroupBattles = new Map<number, GroupQuizBattle>(); // chatId -> battle
export const groupPollToChatMap = new Map<string, number>(); // pollId -> chatId

function escapeMarkdown(text: string): string {
  if (!text) return '';
  return text
    .replace(/_/g, '\\_')
    .replace(/\*/g, '\\*')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]')
    .replace(/`/g, '\\`');
}

export function handleGroupPollAnswer(pollAnswer: any) {
  if (!pollAnswer || !pollAnswer.poll_id || !pollAnswer.user) return;
  const chatId = groupPollToChatMap.get(pollAnswer.poll_id);
  if (!chatId) return;

  const battle = activeGroupBattles.get(chatId);
  if (!battle || battle.currentPollId !== pollAnswer.poll_id) return;

  const userId = pollAnswer.user.id;
  const name = pollAnswer.user.first_name || 'Participant';
  const selectedOption = Array.isArray(pollAnswer.option_ids) ? pollAnswer.option_ids[0] : -1;
  const isCorrect = selectedOption === battle.currentCorrectIndex;

  let participant = battle.participants.get(userId);
  if (!participant) {
    participant = { userId, name, correctCount: 0 };
    battle.participants.set(userId, participant);
  }

  if (isCorrect) {
    participant.correctCount++;
  }
}

export async function handleLaunchGroupQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string
) {
  const chatId = ctx.chat?.id;
  if (!chatId) return;

  // Check if caller is admin
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: '⚠️ Sirf Group Admin test launch kar sakta hai!',
        show_alert: true,
      });
    } else {
      await ctx.reply('⚠️ Sirf Group Admin test launch kar sakta hai.');
    }
    return;
  }

  // Prevent duplicate concurrent quizzes in the same group
  if (activeGroupBattles.has(chatId)) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: '⚠️ Is group me pehle se ek quiz chal raha hai! Pehle use pura hone dein ya /stopquiz karein.',
        show_alert: true,
      });
    } else {
      await ctx.reply('⚠️ Is group me pehle se ek quiz chal raha hai! Pehle use pura hone dein ya /stopquiz karein.');
    }
    return;
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({ text: 'Quiz nahi mila!', show_alert: true });
    }
    return;
  }

  const questions = await getQuestionsForQuiz(supabase, quizId);
  if (!questions || questions.length === 0) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({ text: 'Is quiz me questions nahi hain!', show_alert: true });
    }
    return;
  }

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: 'Starting group quiz!' });
  }

  const timeLimit = Math.min(600, Math.max(10, Number(quiz.time_limit_seconds) || 30));

  // Initialize group battle state
  const battle: GroupQuizBattle = {
    chatId,
    quizId,
    currentCorrectIndex: 0,
    participants: new Map(),
    isCancelled: false,
  };
  activeGroupBattles.set(chatId, battle);

  // 1. Send 5-second countdown warning
  const introMsg =
    `🔔 *GROUP QUIZ STARTING IN 5 SECONDS!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n` +
    `❓ *Total Questions:* \`${questions.length}\`\n` +
    `⏱️ *Time per Question:* \`${timeLimit}s\` (Sabhi ke liye pura timer chalega!)\n\n` +
    `⚡ Sabhi members screen par ready rahein! Confetti & Polls aane wale hain...`;

  if (ctx.callbackQuery) {
    try {
      await ctx.editMessageText(introMsg, { parse_mode: 'Markdown' });
    } catch {
      await ctx.reply(introMsg, { parse_mode: 'Markdown' });
    }
  } else {
    await ctx.reply(introMsg, { parse_mode: 'Markdown' });
  }

  await sleep(5000);

  // 2. Loop through questions and send as Telegram Native Quiz Polls
  for (let i = 0; i < questions.length; i++) {
    // Check if admin stopped the quiz
    if (battle.isCancelled) {
      break;
    }

    const q = questions[i];
    const options = Array.isArray(q.options) ? q.options : [];

    // Clean existing leading numbers if present in JSON text
    const cleanQuestionText = q.question_text.replace(/^(Q\.?\s*\d+[\.\)]?\s*|\d+[\.\)]\s*)/i, '').trim();

    // Escape HTML for safe parsing
    const escapedText = cleanQuestionText.slice(0, 260)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');

    // Question poll title with bold Q
    const pollQuestion = `<b>Q</b>${i + 1}. ${escapedText}`;

    // Ensure options don't exceed Telegram limit of 100 chars each
    const cleanOptions = options.map((opt) => String(opt).slice(0, 100));

    try {
      battle.currentCorrectIndex = q.correct_option_index;

      const pollMessage = await ctx.api.sendPoll(chatId, pollQuestion, cleanOptions, {
        type: 'quiz',
        correct_option_id: q.correct_option_index,
        is_anonymous: false, // Let students see who got it right
        open_period: timeLimit,
        question_parse_mode: 'HTML',
        explanation: q.explanation ? q.explanation.slice(0, 200) : undefined,
      } as any);

      battle.currentPollId = pollMessage.poll.id;
      groupPollToChatMap.set(pollMessage.poll.id, chatId);
    } catch (err: any) {
      console.error(`Error sending poll for question ${i + 1}:`, err);
    }

    // Wait for the poll countdown timer to finish before sending the next question
    // Group members have the full timeLimit seconds to answer!
    await sleep((timeLimit + 3) * 1000);

    // Clean up mapping for this poll
    if (battle.currentPollId) {
      groupPollToChatMap.delete(battle.currentPollId);
    }

    if (battle.isCancelled) {
      break;
    }
  }

  // If quiz was stopped mid-way by an admin
  if (battle.isCancelled) {
    activeGroupBattles.delete(chatId);
    return;
  }

  // 3. Quiz Completion Announcement with Group Battle Leaderboard Podium!
  const finalBattle = activeGroupBattles.get(chatId);
  activeGroupBattles.delete(chatId);

  let leaderboardText = '';
  if (finalBattle && finalBattle.participants.size > 0) {
    const ranked = Array.from(finalBattle.participants.values())
      .sort((a, b) => b.correctCount - a.correctCount)
      .slice(0, 10);

    const medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];
    leaderboardText = `\n\n🏆 *GROUP LIVE BATTLE TOPPERS:*\n━━━━━━━━━━━━━━━━━━━━━\n`;
    ranked.forEach((p, idx) => {
      leaderboardText += `${medals[idx] || '🎖️'} *${escapeMarkdown(p.name)}* — \`${p.correctCount}/${questions.length}\` Sahi\n`;
    });
  }

  const botUsername = ctx.me.username;
  const finishKeyboard = new InlineKeyboard()
    .url('👤 Check My Profile & Score', `https://t.me/${botUsername}?start=profile`)
    .url('📚 Take Solo Test in DM', `https://t.me/${botUsername}?start=quiz_${quiz.id}`);

  await ctx.reply(
    `🏁 *GROUP QUIZ COMPLETE!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `🎉 *${quiz.title}* khatam ho chuka hai!${leaderboardText}\n\n` +
    `Sabhi participants ko badhai! Apna detailed scorecard dekhne ke liye neeche button par tap karein:`,
    { parse_mode: 'Markdown', reply_markup: finishKeyboard }
  );
}

/**
 * Stops an ongoing group quiz (Group Admin only)
 */
export async function handleStopGroupQuiz(ctx: Context, supabase: SupabaseClient) {
  if (!ctx.chat || ctx.chat.type === 'private') {
    return ctx.reply('⚠️ Yeh command Telegram groups ke liye hai.');
  }

  const chatId = ctx.chat.id;
  const battle = activeGroupBattles.get(chatId);
  if (!battle) {
    return ctx.reply('ℹ️ Is group me abhi koi quiz nahi chal raha hai.');
  }

  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.reply('⚠️ Sirf Group Admins hi chal rahe quiz ko rok sakte hain.');
  }

  battle.isCancelled = true;
  activeGroupBattles.delete(chatId);

  const adminName = ctx.from?.first_name || 'Admin';
  await ctx.reply(
    `🛑 *GROUP QUIZ STOPPED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `Group Admin *${escapeMarkdown(adminName)}* dwara test ko rok diya gaya hai.`,
    { parse_mode: 'Markdown' }
  );
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
