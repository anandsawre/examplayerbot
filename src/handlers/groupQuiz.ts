import { Context, InlineKeyboard, InputFile } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getActiveQuizzes, getQuizById, getQuestionsForQuiz, isGroupAuthorized, recordQuizAttempt } from '../db/queries';
import { isGroupAdmin } from '../utils/admin';
import { recentUserAttempts } from './pdfExport';
import { UserAnswerRecord } from '../services/pdfGenerator';
import { generateLeaderboardImage, LeaderboardCardEntry } from '../services/leaderboardImage';
import { isTelegramForbidden, sanitizeError } from '../utils/telegramErrors';

// In-memory pending selection for admins launching quiz from DM for a group
export const pendingGroupQuizSelection = new Map<number, { groupChatId: number; groupTitle: string }>();

export async function handleGroupQuizCommand(ctx: Context, supabase: SupabaseClient) {
  if (!ctx.chat) return;
  const chatType = ctx.chat.type;

  // If used in private chat
  if (chatType === 'private') {
    await ctx.reply(
      `👥 *GROUP LIVE BATTLE CONSOLE*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `This operational feature is designed for authorized Community Groups.\n\n` +
      `1. Add Examplayer Bot to your Telegram Community Group.\n` +
      `2. Grant the bot *Administrator* permissions (Manage Polls & Pin messages).\n` +
      `3. Execute in the group: \`/groupquiz\`\n\n` +
      `Host live real-time competitive examination battles for your group members! 🎯`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  // Check if this group is authorized
  const isAuth = await isGroupAuthorized(supabase, ctx.chat.id);
  if (!isAuth) {
    await ctx.reply(
      `⚠️ *Group Not Authorized*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `This community group is not authorized to host examination battles.\n` +
      `Please contact the platform administrator to activate authorization.`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  // Verify that the caller is an Admin in the group
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    await ctx.reply('⚠️ Access Denied: Group live examination battles can only be launched by Community Administrators.');
    return;
  }

  // Check if a quiz is already in progress
  if (activeGroupBattles.has(ctx.chat.id)) {
    await ctx.reply('⚠️ An active live examination battle is already in progress. Please await its conclusion or execute /stopquiz.');
    return;
  }

  const quizzes = await getActiveQuizzes(supabase);
  if (!quizzes || quizzes.length === 0) {
    await ctx.reply('⚠️ No active examinations found in the repository.');
    return;
  }

  const adminId = ctx.from?.id;
  if (!adminId) return;

  const groupTitle = ctx.chat.title || 'Community Group';
  pendingGroupQuizSelection.set(adminId, {
    groupChatId: ctx.chat.id,
    groupTitle,
  });

  let botUsername = 'Examplayer_bot';
  try {
    const me = await ctx.api.getMe();
    botUsername = me.username;
  } catch {}

  const keyboard = new InlineKeyboard();
  quizzes.forEach((quiz) => {
    keyboard.text(`🚀 ${quiz.title}`, `launch_grp:${quiz.id}`).row();
  });

  const dmText =
    `👥 *GROUP LIVE BATTLE CONSOLE*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `🏛️ *Target Group:* ${escapeMarkdown(groupTitle)}\n\n` +
    `Select the examination module you wish to launch live for this community:`;

  let sentDm = false;
  try {
    await ctx.api.sendMessage(adminId, dmText, {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    });
    sentDm = true;
  } catch {
    sentDm = false;
  }

  const adminName = ctx.from?.first_name || 'Admin';

  if (sentDm) {
    await ctx.reply(
      `🔒 *Admin Console:* Test selection console sent to Administrator [${escapeMarkdown(adminName)}](tg://user?id=${adminId}) in private chat.\n` +
      `⚡ Group live battle will commence here once selected.`,
      { parse_mode: 'Markdown' }
    );
  } else {
    const deepLinkKeyboard = new InlineKeyboard().url(
      '👉 Select Test Paper (Admin Only)',
      `https://t.me/${botUsername}?start=launch_${ctx.chat.id}`
    );
    await ctx.reply(
      `🔒 *Admin Console:* Administrator [${escapeMarkdown(adminName)}](tg://user?id=${adminId}), please tap the button below to pick the examination paper privately:`,
      { parse_mode: 'Markdown', reply_markup: deepLinkKeyboard }
    );
  }
}

export async function handleStartGroupQuizFromDm(
  ctx: Context,
  supabase: SupabaseClient,
  groupId: number
) {
  if (!ctx.from) return;

  const isAuth = await isGroupAuthorized(supabase, groupId);
  if (!isAuth) {
    return ctx.reply('⚠️ The target community group is not authorized to host examination battles.');
  }

  if (activeGroupBattles.has(groupId)) {
    return ctx.reply('⚠️ An active examination battle is already running in that group.');
  }

  const quizzes = await getActiveQuizzes(supabase);
  if (!quizzes || quizzes.length === 0) {
    return ctx.reply('⚠️ No active examinations found in the repository.');
  }

  pendingGroupQuizSelection.set(ctx.from.id, {
    groupChatId: groupId,
    groupTitle: 'Community Group',
  });

  const keyboard = new InlineKeyboard();
  quizzes.forEach((quiz) => {
    keyboard.text(`🚀 ${quiz.title}`, `launch_grp:${quiz.id}`).row();
  });

  await ctx.reply(
    `👥 *LAUNCH GROUP LIVE BATTLE*\n━━━━━━━━━━━━━━━━━━━━━\n` +
    `Select an examination module to launch live in your community group:`,
    { parse_mode: 'Markdown', reply_markup: keyboard }
  );
}

export interface GroupParticipant {
  userId: number;
  name: string;
  username?: string;
  correctCount: number;
  wrongCount: number;
  totalTimeMs?: number;
  answers: UserAnswerRecord[];
}

export interface GroupQuizBattle {
  chatId: number;
  quizId: string;
  currentPollId?: string;
  currentCorrectIndex: number;
  currentQuestionId?: string;
  currentPollStartTime?: number;
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
    participant = { userId, name, username, correctCount: 0, wrongCount: 0, totalTimeMs: 0, answers: [] };
    battle.participants.set(userId, participant);
  }

  const responseTimeMs = battle.currentPollStartTime
    ? Math.max(500, Date.now() - battle.currentPollStartTime)
    : 3000;
  participant.totalTimeMs = (participant.totalTimeMs || 0) + responseTimeMs;

  if (isCorrect) {
    participant.correctCount++;
  } else if (selectedOption !== -1) {
    participant.wrongCount++;
  }

  if (battle.currentQuestionId) {
    participant.answers.push({
      question_id: battle.currentQuestionId,
      selected_option_index: selectedOption,
      is_correct: isCorrect,
    });
  }
}

export async function handleLaunchGroupQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string
) {
  const isPrivate = ctx.chat?.type === 'private';
  const callerId = ctx.from?.id;
  if (!callerId) return;

  let targetChatId = ctx.chat?.id;

  if (isPrivate) {
    const pending = pendingGroupQuizSelection.get(callerId);
    if (!pending) {
      if (ctx.callbackQuery) {
        await ctx.answerCallbackQuery({
          text: '⚠️ Selection session expired. Please run /groupquiz in your group.',
          show_alert: true,
        });
      } else {
        await ctx.reply('⚠️ Selection session expired. Please run /groupquiz in your group.');
      }
      return;
    }

    targetChatId = pending.groupChatId;
    pendingGroupQuizSelection.delete(callerId);

    if (activeGroupBattles.has(targetChatId)) {
      if (ctx.callbackQuery) {
        await ctx.answerCallbackQuery({
          text: '⚠️ An active battle is already in progress in that group.',
          show_alert: true,
        });
      } else {
        await ctx.reply('⚠️ An active battle is already in progress in that group.');
      }
      return;
    }

    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({ text: 'Launching group examination...' }).catch(() => {});
    }

    try {
      await ctx.editMessageText(
        `✅ *LIVE BATTLE LAUNCHED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
        `The examination battle has been triggered in *${escapeMarkdown(pending.groupTitle)}*.\n` +
        `Countdown notice is now live in the group! 🚀`,
        { parse_mode: 'Markdown' }
      );
    } catch {}

    const botUsername = ctx.me?.username || 'Examplayer_bot';
    executeGroupQuizBattle(ctx.api, supabase, targetChatId, quizId, botUsername).catch((err) => {
      console.error('Error executing group quiz battle:', err);
    });
    return;
  }

  // Fallback: If launched directly inside group
  if (!targetChatId) return;
  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: '⚠️ Action restricted to Group Administrators.',
        show_alert: true,
      });
    } else {
      await ctx.reply('⚠️ Action restricted to Group Administrators.');
    }
    return;
  }

  if (activeGroupBattles.has(targetChatId)) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: '⚠️ An active examination battle is already in progress.',
        show_alert: true,
      });
    } else {
      await ctx.reply('⚠️ An active live examination battle is already in progress.');
    }
    return;
  }

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: 'Launching group examination...' }).catch(() => {});
    // Delete the selection message in group to keep group clean
    try {
      await ctx.deleteMessage();
    } catch {}
  }

  const botUsername = ctx.me?.username || 'Examplayer_bot';
  executeGroupQuizBattle(ctx.api, supabase, targetChatId, quizId, botUsername).catch((err) => {
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
    `🔔 *GROUP EXAMINATION BATTLE COMMENCING IN 5 SECONDS*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Examination:* ${quiz.title}\n` +
    `❓ *Total Questions:* \`${questions.length}\`\n` +
    `⏱️ *Time Limit:* \`${timeLimit}s\` per question\n\n` +
    `⚡ All participating candidates please prepare your screens. Polls loading...`;

  await api.sendMessage(chatId, introMsg, { parse_mode: 'Markdown' }).catch((err) => {
    if (!isTelegramForbidden(err)) {
      console.error('Failed to send group intro msg:', sanitizeError(err));
    }
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
      battle.currentQuestionId = q.id;

      sentPollMessage = await api.sendPoll(chatId, pollQuestion, cleanOptions, {
        type: 'quiz',
        correct_option_id: q.correct_option_index,
        is_anonymous: false,
        open_period: timeLimit,
        question_parse_mode: 'HTML',
        explanation: q.explanation ? q.explanation.slice(0, 200) : undefined,
      } as any);

      battle.currentPollId = sentPollMessage.poll.id;
      battle.currentPollStartTime = Date.now();
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
  const contestantsCount = finalBattle ? finalBattle.participants.size : 0;

  const finishKeyboard = new InlineKeyboard()
    .url('📄 Download Official PDF (in DM)', `https://t.me/${botUsername}?start=pdf_${quiz.id}`)
    .row()
    .url('👤 Candidate Profile & Analytics', `https://t.me/${botUsername}?start=profile`)
    .url('📝 Attempt Solo in Direct Message', `https://t.me/${botUsername}?start=quiz_${quiz.id}`);

  if (finalBattle && contestantsCount > 0) {
    // 1. Calculate detailed scores with positive marks and negative penalty
    const participantsList = Array.from(finalBattle.participants.values()).map((p) => {
      const positive = p.correctCount * marksPerQ;
      const negative = p.wrongCount * negMarksPerWrong;
      const score = Math.max(0, Math.round((positive - negative) * 100) / 100);
      const totalAnswered = p.correctCount + p.wrongCount;
      const accuracy = totalAnswered > 0 ? Math.round((p.correctCount / totalAnswered) * 100) : 0;
      const timeSeconds = Math.round((p.totalTimeMs || (timeLimit * totalAnswered * 1000)) / 1000);
      return {
        ...p,
        score,
        accuracy,
        negPenalty: Math.round(negative * 100) / 100,
        timeSeconds,
      };
    });

    // 2. Rank all participants: highest score first, then highest correct, then fastest time
    participantsList.sort((a, b) => b.score - a.score || b.correctCount - a.correctCount || a.timeSeconds - b.timeSeconds);

    const cardEntries: LeaderboardCardEntry[] = participantsList.map((p, idx) => ({
      rank: idx + 1,
      name: p.name || 'Candidate',
      correctCount: p.correctCount,
      wrongCount: p.wrongCount,
      negPenalty: p.negPenalty,
      score: p.score,
      timeTakenSeconds: p.timeSeconds,
      accuracy: p.accuracy,
    }));

    // Cache candidate attempt results for instant personal PDF generation and record in database
    const maxScore = questions.length * marksPerQ;
    for (const p of participantsList) {
      const skippedCount = Math.max(0, questions.length - (p.correctCount + p.wrongCount));
      const percentage = maxScore > 0 ? Math.round((p.score / maxScore) * 100) : 0;

      let remark = 'Completed';
      if (p.accuracy >= 90) remark = 'Outstanding Mastery';
      else if (p.accuracy >= 75) remark = 'Excellent Performance';
      else if (p.accuracy >= 50) remark = 'Good Attempt';
      else remark = 'Needs Thorough Revision';

      recentUserAttempts.set(p.userId, {
        quizId: quiz.id,
        result: {
          totalQuestions: questions.length,
          correctCount: p.correctCount,
          wrongCount: p.wrongCount,
          skippedCount,
          finalScore: p.score,
          maxScore,
          percentage,
          accuracy: p.accuracy,
          timeTakenSeconds: p.timeSeconds,
          remark,
        },
        answers: p.answers || [],
        completedAt: new Date(),
      });

      recordQuizAttempt(supabase, {
        user_id: p.userId,
        quiz_id: quiz.id,
        total_questions: questions.length,
        correct_count: p.correctCount,
        wrong_count: p.wrongCount,
        skipped_count: skippedCount,
        score: p.score,
        accuracy_percent: p.accuracy,
        time_taken_seconds: p.timeSeconds,
      }).catch((err) => console.error('Error recording battle attempt:', err));
    }

    const imgBuffer = generateLeaderboardImage(quiz.title, cardEntries);

    const completionMessage =
      `🎓 *EXAMPLAYER LIVE BATTLE — OFFICIAL RESULT*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `📚 *Exam:* ${escapeMarkdown(quiz.title)}\n` +
      `❓ *Questions:* \`${questions.length}\` | ⏱️ *Time Limit:* \`${timeLimit}s\`\n` +
      `🎯 *Marking Scheme:* \`+${marksPerQ}\` / \`-${negMarksPerWrong}\` Negative Penalty\n` +
      `👥 *Total Participants Ranked:* \`${contestantsCount}\` Aspirants\n\n` +
      `Tap the button below to download your personal scorecard & solutions PDF directly in DM.`;

    await api.sendPhoto(chatId, new InputFile(imgBuffer, 'leaderboard.png'), {
      caption: completionMessage,
      parse_mode: 'Markdown',
      reply_markup: finishKeyboard,
    }).catch(async (err) => {
      if (isTelegramForbidden(err)) {
        console.warn(`[GroupQuiz] Bot was kicked from group ${chatId} (403 Forbidden). Leaderboard omitted.`);
        return;
      }
      console.error('Failed to send leaderboard photo, falling back to text:', sanitizeError(err));
      try {
        await api.sendMessage(chatId, completionMessage, {
          parse_mode: 'Markdown',
          reply_markup: finishKeyboard,
        });
      } catch (fallbackErr: any) {
        if (!isTelegramForbidden(fallbackErr)) {
          console.error('Failed to send group completion message fallback:', sanitizeError(fallbackErr));
        }
      }
    });
  } else {
    const emptyMsg =
      `🎓 *EXAMPLAYER LIVE BATTLE — OFFICIAL RESULT*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `📚 *Exam:* ${escapeMarkdown(quiz.title)}\n\n` +
      `_No candidate attempts were recorded during this session._`;
    await api.sendMessage(chatId, emptyMsg, {
      parse_mode: 'Markdown',
      reply_markup: finishKeyboard,
    }).catch((err) => {
      if (!isTelegramForbidden(err)) {
        console.error('Failed to send group completion message:', sanitizeError(err));
      }
    });
  }
}

/**
 * Stops an ongoing group quiz (Group Admin only)
 */
export async function handleStopGroupQuiz(ctx: Context, supabase: SupabaseClient) {
  if (!ctx.chat || ctx.chat.type === 'private') {
    return ctx.reply('⚠️ Command restricted to Telegram community groups.');
  }

  const chatId = ctx.chat.id;
  const battle = activeGroupBattles.get(chatId);
  if (!battle) {
    return ctx.reply('ℹ️ No live examination battle is currently active in this group.');
  }

  const userIsAdmin = await isGroupAdmin(ctx);
  if (!userIsAdmin) {
    return ctx.reply('⚠️ Access Denied: Only Group Administrators may abort an active examination battle.');
  }

  battle.isCancelled = true;
  activeGroupBattles.delete(chatId);

  const adminName = ctx.from?.first_name || 'Admin';
  await ctx.reply(
    `🛑 *GROUP EXAMINATION BATTLE TERMINATED*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `The active session was terminated by Administrator *${escapeMarkdown(adminName)}*.`,
    { parse_mode: 'Markdown' }
  );
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
