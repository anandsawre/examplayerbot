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
  username?: string;
  correctCount: number;
  wrongCount: number;
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
  const username = pollAnswer.user.username;
  const selectedOption = Array.isArray(pollAnswer.option_ids) ? pollAnswer.option_ids[0] : -1;
  const isCorrect = selectedOption === battle.currentCorrectIndex;

  let participant = battle.participants.get(userId);
  if (!participant) {
    participant = { userId, name, username, correctCount: 0, wrongCount: 0 };
    battle.participants.set(userId, participant);
  }

  if (isCorrect) {
    participant.correctCount++;
  } else if (selectedOption !== -1) {
    participant.wrongCount++;
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

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: 'Starting group quiz!' }).catch(() => {});
  }

  const botUsername = ctx.me?.username || 'Examplayer_bot';
  executeGroupQuizBattle(ctx.api, supabase, chatId, quizId, botUsername).catch((err) => {
    console.error('Error executing group quiz battle:', err);
  });
}

/**
 * Pure execution engine for group quiz battle (used by direct launch & background scheduler)
 */
export async function executeGroupQuizBattle(
  api: import('grammy').Api,
  supabase: SupabaseClient,
  chatId: number,
  quizId: string,
  botUsername: string = 'Examplayer_bot'
) {
  if (activeGroupBattles.has(chatId)) {
    return;
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) return;

  const questions = await getQuestionsForQuiz(supabase, quizId);
  if (!questions || questions.length === 0) return;

  const timeLimit = Math.min(600, Math.max(20, Number(quiz.time_limit_seconds) || 30));

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

  await api.sendMessage(chatId, introMsg, { parse_mode: 'Markdown' }).catch((err) => {
    console.error('Failed to send group intro msg:', err);
  });

  await sleep(5000);

  // 2. Loop through questions and send as Telegram Native Quiz Polls
  for (let i = 0; i < questions.length; i++) {
    if (battle.isCancelled) {
      break;
    }

    const q = questions[i];
    const options = Array.isArray(q.options) ? q.options : [];
    const cleanQuestionText = q.question_text.replace(/^(Q\.?\s*\d+[\.\)]?\s*|\d+[\.\)]\s*)/i, '').trim();
    const escapedText = cleanQuestionText.slice(0, 260)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
    const pollQuestion = `<b>Q</b>${i + 1}. ${escapedText}`;
    const cleanOptions = options.map((opt) => String(opt).slice(0, 100));

    let sentPollMessage: any = null;
    try {
      battle.currentCorrectIndex = q.correct_option_index;

      sentPollMessage = await api.sendPoll(chatId, pollQuestion, cleanOptions, {
        type: 'quiz',
        correct_option_id: q.correct_option_index,
        is_anonymous: false,
        open_period: timeLimit,
        question_parse_mode: 'HTML',
        explanation: q.explanation ? q.explanation.slice(0, 200) : undefined,
      } as any);

      battle.currentPollId = sentPollMessage.poll.id;
      groupPollToChatMap.set(sentPollMessage.poll.id, chatId);
    } catch (err: any) {
      console.error(`Error sending poll for question ${i + 1}:`, err);
    }

    // Wait for the question timer to expire
    await sleep(timeLimit * 1000);

    // Explicitly stop the poll on Telegram: locks answers and reveals correct checkmark & explanation!
    if (sentPollMessage && sentPollMessage.message_id) {
      try {
        await api.stopPoll(chatId, sentPollMessage.message_id);
      } catch (err) {
        // Poll may have already closed, safe to ignore
      }
    }

    if (battle.currentPollId) {
      groupPollToChatMap.delete(battle.currentPollId);
    }

    if (battle.isCancelled) {
      break;
    }

    // 3-second pause so group members can see the correct answer & explanation before next Q
    if (i + 1 < questions.length) {
      await sleep(3000);
    }
  }

  if (battle.isCancelled) {
    activeGroupBattles.delete(chatId);
    return;
  }

  // 3. Quiz Completion Announcement with Professional Merit List
  const finalBattle = activeGroupBattles.get(chatId);
  activeGroupBattles.delete(chatId);

  const marksPerQ = Number(quiz.marks_per_question) || 2;
  const negMarksPerWrong = Number(quiz.negative_marks) || 0.5;

  let meritListSection = '';
  const contestantsCount = finalBattle ? finalBattle.participants.size : 0;

  if (finalBattle && contestantsCount > 0) {
    // Calculate accurate test scores with positive marks and negative penalty
    const participantsList = Array.from(finalBattle.participants.values()).map((p) => {
      const positive = p.correctCount * marksPerQ;
      const negative = p.wrongCount * negMarksPerWrong;
      const score = Math.max(0, Math.round((positive - negative) * 100) / 100);
      const totalAnswered = p.correctCount + p.wrongCount;
      const accuracy = totalAnswered > 0 ? Math.round((p.correctCount / totalAnswered) * 100) : 0;
      return {
        ...p,
        score,
        accuracy,
        negPenalty: Math.round(negative * 100) / 100,
      };
    });

    // Rank participants: highest score first, then highest correct answers
    const ranked = participantsList
      .sort((a, b) => b.score - a.score || b.correctCount - a.correctCount)
      .slice(0, 15);

    // Top 3 Podium Highlights
    const medals = ['🥇', '🥈', '🥉', '🎖️', '🎖️'];
    let podiumText = `🏆 *TOP BATTLE PERFORMERS:*\n`;
    ranked.slice(0, 3).forEach((p, idx) => {
      podiumText += `${medals[idx]} *${escapeMarkdown(p.name)}* — \`${p.score} pts\` (✅ ${p.correctCount}/${questions.length} | 🎯 ${p.accuracy}% Acc)\n`;
    });

    // Monospace Aligned Merit List Table
    let table = `Rank Name        ✅  ❌  -Neg   Score\n`;
    table += `─────────────────────────────────────\n`;
    ranked.forEach((p, idx) => {
      const rankStr = `${idx + 1}.`.padEnd(5, ' ');
      const rawName = p.name || 'Candidate';
      const nameStr = rawName.length > 10 ? rawName.slice(0, 9) + '…' : rawName;
      const paddedName = nameStr.padEnd(11, ' ');
      const correctStr = String(p.correctCount).padStart(3, ' ');
      const wrongStr = String(p.wrongCount).padStart(3, ' ');
      const negStr = (p.negPenalty > 0 ? `-${p.negPenalty}` : ' 0.0').padStart(6, ' ');
      const scoreStr = String(p.score).padStart(7, ' ');
      table += `${rankStr}${paddedName}${correctStr} ${wrongStr} ${negStr} ${scoreStr}\n`;
    });

    meritListSection = `\n\n${podiumText}\n📊 *OFFICIAL BATTLE SCOREBOARD:*\n\`\`\`\n${table}\`\`\``;
  } else {
    meritListSection = `\n\n_Is battle me kisi candidate ne questions attempt nahi kiye._`;
  }

  const finishKeyboard = new InlineKeyboard()
    .text('📄 Download Solutions Booklet (PDF)', `pdf_scorecard:${quiz.id}`)
    .row()
    .url('👤 My Profile & Stats', `https://t.me/${botUsername}?start=profile`)
    .url('📚 Solo Mock Test in DM', `https://t.me/${botUsername}?start=quiz_${quiz.id}`);

  const completionMessage =
    `🎓 *EXAMPLAYER LIVE BATTLE — OFFICIAL RESULT*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📚 *Exam:* ${escapeMarkdown(quiz.title)}\n` +
    `❓ *Questions:* \`${questions.length}\` | ⏱️ *Time Limit:* \`${timeLimit}s\`\n` +
    `🎯 *Marking:* \`+${marksPerQ}\` / \`-${negMarksPerWrong}\` Negative Marking\n` +
    `👥 *Total Participants:* \`${contestantsCount}\` Aspirants\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━` +
    meritListSection +
    `\n\n✨ *Badhai ho sabhi participants ko!* Detailed solutions aur explanations ke liye neeche diye gaye PDF button par tap karein:`;

  await api.sendMessage(chatId, completionMessage, {
    parse_mode: 'Markdown',
    reply_markup: finishKeyboard,
  }).catch((err) => {
    console.error('Failed to send group completion message:', err);
  });
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
