import { Context, InlineKeyboard, Api } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import {
  getUser,
  getActiveQuizzes,
  getQuestionsForQuiz,
  createDuelSession,
  getDuelSession,
  activeDuels,
  duelPollToIdMap,
  updateDuelUserStats,
} from '../db/queries';
import { DuelSession, Question } from '../types';

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// In-memory poll tracking for active duels
// key: pollId -> { duelId, qIndex, question, startTime }
export const duelPollTracker: Map<
  string,
  { duelId: string; qIndex: number; question: Question; startTime: number }
> = new Map();

/**
 * Handles /duel command in Group or Direct Chat
 */
export async function handleDuelCommand(ctx: Context, supabase: SupabaseClient) {
  const userId = ctx.from?.id;
  const chatId = ctx.chat?.id;
  if (!userId || !chatId) return;

  const user = await getUser(supabase, userId);
  const challengerName = user?.first_name || ctx.from?.first_name || 'Candidate';

  // Fetch available quizzes to pick a question bank
  const quizzes = await getActiveQuizzes(supabase);
  if (!quizzes || quizzes.length === 0) {
    return ctx.reply('⚠️ No active examination papers available for dueling at this moment.');
  }

  // Pick a quiz with questions
  let selectedQuiz = quizzes[0];
  let questions: Question[] = [];
  for (const q of quizzes) {
    const list = await getQuestionsForQuiz(supabase, q.id);
    if (list && list.length >= 3) {
      selectedQuiz = q;
      questions = list.slice(0, 5); // 5 rapid fire questions
      break;
    }
  }

  if (questions.length === 0) {
    // If no quiz has >= 3 questions, take whatever is available
    questions = await getQuestionsForQuiz(supabase, selectedQuiz.id);
    if (questions.length === 0) {
      return ctx.reply('⚠️ Sufficient questions not found to initiate a 1v1 duel.');
    }
  }

  const duelId = `duel_${Date.now()}_${userId}`;
  const duel: DuelSession = {
    id: duelId,
    chat_id: chatId,
    creator_id: userId,
    creator_name: challengerName,
    quiz_id: selectedQuiz.id,
    question_ids: questions.map((q) => q.id),
    questions,
    current_q_index: 0,
    creator_answers: [],
    opponent_answers: [],
    status: 'pending',
    created_at: new Date().toISOString(),
  };

  await createDuelSession(duel);

  if (ctx.chat?.type === 'private') {
    // In Direct Chat: Provide shareable challenge link
    const botUsername = ctx.me?.username || 'Examplayer_bot';
    const challengeUrl = `https://t.me/${botUsername}?start=duel_${duelId}`;
    const shareText = encodeURIComponent(
      `⚔️ ${challengerName} has challenged you to a 1v1 Rapid Examination Duel on Examplayer! Tap to accept: ${challengeUrl}`
    );
    const shareUrl = `https://t.me/share/url?url=${encodeURIComponent(challengeUrl)}&text=${shareText}`;

    const text =
      `⚔️ *1v1 CANDIDATE DUEL LOBBY CREATED*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `Challenger: *${challengerName}*\n` +
      `Examination Domain: *${selectedQuiz.title}*\n` +
      `Format: *5 Rapid-Fire Questions (15s per question)*\n\n` +
      `🔗 *Shareable Duel Challenge Link:*\n` +
      `\`${challengeUrl}\`\n\n` +
      `Share this link with a peer or post it in a study group. As soon as your opponent taps accept, the battle will begin!`;

    const keyboard = new InlineKeyboard()
      .url('📤 Share Duel Challenge to Telegram', shareUrl)
      .row()
      .text('❌ Cancel Duel', `cancel_duel:${duelId}`);

    return ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }

  // In Group Chat: Post live lobby
  const text =
    `⚔️ *1v1 CANDIDATE LIVE DUEL CHALLENGE*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Challenger: *${challengerName}* (ELO: ${user?.duel_rating || 1200})\n` +
    `Paper: *${selectedQuiz.title}*\n` +
    `Rounds: *${questions.length} Rapid-Fire Questions (15s Timer)*\n\n` +
    `⚡ *Rules of Engagement:*\n` +
    `• Head-to-head speed & accuracy duel\n` +
    `• Winner receives +25 ELO Points on the All-India Leaderboard\n\n` +
    `_Who dares to accept the challenge? Tap below to start!_`;

  const keyboard = new InlineKeyboard()
    .text('⚔️ Accept Challenge (Player 2)', `accept_duel:${duelId}`)
    .row()
    .text('❌ Withdraw Challenge', `cancel_duel:${duelId}`);

  await ctx.reply(text, {
    parse_mode: 'Markdown',
    reply_markup: keyboard,
  });
}

/**
 * Handles opponent tapping "Accept Challenge"
 */
export async function handleAcceptDuel(ctx: Context, supabase: SupabaseClient) {
  const cbData = ctx.callbackQuery?.data;
  if (!cbData || !cbData.startsWith('accept_duel:')) return;

  const duelId = cbData.replace('accept_duel:', '');
  const duel = getDuelSession(duelId);

  if (!duel || duel.status !== 'pending') {
    return ctx.answerCallbackQuery({
      text: 'This duel is no longer available or already completed.',
      show_alert: true,
    });
  }

  const opponentId = ctx.from?.id;
  if (!opponentId) return;

  if (opponentId === duel.creator_id) {
    return ctx.answerCallbackQuery({
      text: 'You cannot duel yourself! A peer must accept your challenge.',
      show_alert: true,
    });
  }

  const oppUser = await getUser(supabase, opponentId);
  const opponentName = oppUser?.first_name || ctx.from?.first_name || 'Opponent';

  duel.opponent_id = opponentId;
  duel.opponent_name = opponentName;
  duel.status = 'in_progress';

  await ctx.answerCallbackQuery({ text: 'Duel accepted! Initiating face-off...' });

  const startMsg =
    `🥊 *1v1 DUEL CONFIRMED: THE BATTLE BEGINS!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `🔴 *Player 1:* ${duel.creator_name}\n` +
    `🔵 *Player 2:* ${opponentName}\n\n` +
    `⏱️ Questions will be dispatched every 15 seconds. May the best candidate prevail!\n` +
    `_Question 1 loading in 3 seconds..._`;

  try {
    await ctx.editMessageText(startMsg, { parse_mode: 'Markdown' });
  } catch {}

  await sleep(3000);
  await dispatchNextDuelQuestion(ctx.api, supabase, duel);
}

/**
 * Dispatches the next question in the active duel
 */
async function dispatchNextDuelQuestion(
  api: Api,
  supabase: SupabaseClient,
  duel: DuelSession
) {
  if (duel.current_q_index >= duel.questions.length) {
    return finishDuel(api, supabase, duel);
  }

  const qIndex = duel.current_q_index;
  const question = duel.questions[qIndex];
  const qNum = qIndex + 1;
  const total = duel.questions.length;

  const rawOptions = Array.isArray(question.options)
    ? question.options
    : typeof question.options === 'string'
    ? JSON.parse(question.options)
    : [];

  const cleanOptions = rawOptions.map((opt: any) =>
    String(opt).replace(/<[^>]*>?/gm, '').trim().slice(0, 100)
  );

  const pollHeader = `⚔️ [1v1 DUEL — ROUND ${qNum}/${total}]\n\n${question.question_text}`;

  try {
    const pollMsg = await api.sendPoll(
      duel.chat_id,
      pollHeader,
      cleanOptions,
      {
        type: 'quiz',
        correct_option_id: question.correct_option_index,
        is_anonymous: false,
        open_period: 15, // 15-second rapid timer
        explanation: question.explanation ? question.explanation.slice(0, 200) : undefined,
      } as any
    );

    duel.current_poll_id = pollMsg.poll.id;
    duelPollToIdMap.set(pollMsg.poll.id, duel.id);
    duelPollTracker.set(pollMsg.poll.id, {
      duelId: duel.id,
      qIndex,
      question,
      startTime: Date.now(),
    });

    // Wait 17 seconds (15s poll + 2s margin) before triggering next question
    setTimeout(async () => {
      const curDuel = getDuelSession(duel.id);
      if (!curDuel || curDuel.current_q_index !== qIndex) return;

      // If either player hasn't answered, record timeout (false, 15000ms)
      if (curDuel.creator_answers.length <= qIndex) {
        curDuel.creator_answers.push({ is_correct: false, time_ms: 15000 });
      }
      if (curDuel.opponent_answers.length <= qIndex) {
        curDuel.opponent_answers.push({ is_correct: false, time_ms: 15000 });
      }

      curDuel.current_q_index++;
      await sleep(1000);
      await dispatchNextDuelQuestion(api, supabase, curDuel);
    }, 17000);

  } catch (err) {
    console.error('Error dispatching duel question:', err);
    duel.current_q_index++;
    await dispatchNextDuelQuestion(api, supabase, duel);
  }
}

/**
 * Handles incoming poll answer for an active duel
 */
export async function handleDuelPollAnswer(pollAnswer: any): Promise<boolean> {
  const pollId = pollAnswer.poll_id;
  const tracker = duelPollTracker.get(pollId);
  if (!tracker) return false;

  const duel = getDuelSession(tracker.duelId);
  if (!duel || duel.status !== 'in_progress') return false;

  const userId = pollAnswer.user?.id;
  if (!userId) return false;

  // Only evaluate Player 1 or Player 2
  if (userId !== duel.creator_id && userId !== duel.opponent_id) {
    return false;
  }

  const selectedIndex = pollAnswer.option_ids[0];
  const isCorrect = selectedIndex === tracker.question.correct_option_index;
  const responseTimeMs = Math.max(500, Date.now() - tracker.startTime);

  if (userId === duel.creator_id) {
    if (duel.creator_answers.length <= tracker.qIndex) {
      duel.creator_answers[tracker.qIndex] = { is_correct: isCorrect, time_ms: responseTimeMs };
    }
  } else if (userId === duel.opponent_id) {
    if (duel.opponent_answers.length <= tracker.qIndex) {
      duel.opponent_answers[tracker.qIndex] = { is_correct: isCorrect, time_ms: responseTimeMs };
    }
  }

  return true;
}

/**
 * Concludes the duel, calculates score and speed, updates ratings, and displays victor card
 */
async function finishDuel(
  api: Api,
  supabase: SupabaseClient,
  duel: DuelSession
) {
  duel.status = 'completed';
  activeDuels.delete(duel.id);

  // Calculate scores (2 marks per correct, -0.5 per wrong, 0 if skipped)
  let p1Correct = 0;
  let p1TotalTime = 0;
  for (const a of duel.creator_answers) {
    if (a?.is_correct) p1Correct++;
    p1TotalTime += a?.time_ms || 15000;
  }

  let p2Correct = 0;
  let p2TotalTime = 0;
  for (const a of duel.opponent_answers) {
    if (a?.is_correct) p2Correct++;
    p2TotalTime += a?.time_ms || 15000;
  }

  const totalQ = duel.questions.length;
  const p1Score = p1Correct * 2.0;
  const p2Score = p2Correct * 2.0;
  const p1Sec = (p1TotalTime / 1000).toFixed(1);
  const p2Sec = (p2TotalTime / 1000).toFixed(1);

  let winnerId: number | undefined;
  let winnerText = '';

  if (p1Score > p2Score) {
    winnerId = duel.creator_id;
    winnerText = `👑 *VICTOR: ${duel.creator_name}* (+25 ELO)`;
  } else if (p2Score > p1Score) {
    winnerId = duel.opponent_id;
    winnerText = `👑 *VICTOR: ${duel.opponent_name}* (+25 ELO)`;
  } else {
    // Tie-break by fastest response time
    if (p1TotalTime < p2TotalTime) {
      winnerId = duel.creator_id;
      winnerText = `👑 *VICTOR BY SPEED: ${duel.creator_name}* (+25 ELO)`;
    } else if (p2TotalTime < p1TotalTime) {
      winnerId = duel.opponent_id;
      winnerText = `👑 *VICTOR BY SPEED: ${duel.opponent_name}* (+25 ELO)`;
    } else {
      winnerText = `🤝 *HONORABLE TIE: DRAW MATCH* (+10 ELO to both)`;
    }
  }

  // Update ELO stats in DB
  let p1Rating = 1200;
  let p2Rating = 1200;
  if (winnerId === duel.creator_id) {
    const res1 = await updateDuelUserStats(supabase, duel.creator_id, true);
    p1Rating = res1.newRating;
    if (duel.opponent_id) {
      const res2 = await updateDuelUserStats(supabase, duel.opponent_id, false);
      p2Rating = res2.newRating;
    }
  } else if (winnerId === duel.opponent_id) {
    if (duel.opponent_id) {
      const res2 = await updateDuelUserStats(supabase, duel.opponent_id, true);
      p2Rating = res2.newRating;
    }
    const res1 = await updateDuelUserStats(supabase, duel.creator_id, false);
    p1Rating = res1.newRating;
  }

  const resultText =
    `🏆 *OFFICIAL 1v1 CANDIDATE DUEL RESULTS*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `${winnerText}\n\n` +
    `🔴 *${duel.creator_name} (Player 1)*\n` +
    `• Correct Answers: ${p1Correct} / ${totalQ}\n` +
    `• Final Score: ${p1Score.toFixed(2)} Marks\n` +
    `• Cumulative Speed: ⏱️ ${p1Sec}s\n` +
    `• Rating: ⭐ ${p1Rating} ELO\n\n` +
    `🔵 *${duel.opponent_name} (Player 2)*\n` +
    `• Correct Answers: ${p2Correct} / ${totalQ}\n` +
    `• Final Score: ${p2Score.toFixed(2)} Marks\n` +
    `• Cumulative Speed: ⏱️ ${p2Sec}s\n` +
    `• Rating: ⭐ ${p2Rating} ELO\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `_Challenge another peer with /duel to climb the All-India Leaderboard!_`;

  const keyboard = new InlineKeyboard()
    .text('⚔️ Challenge New Duel', 'menu_duel')
    .row()
    .text('🏆 All-India Leaderboard', 'menu_global_lb');

  try {
    await api.sendMessage(duel.chat_id, resultText, {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    });
  } catch (err) {
    console.error('Error posting duel results:', err);
  }
}

/**
 * Handles duel cancellation
 */
export async function handleCancelDuel(ctx: Context) {
  const cbData = ctx.callbackQuery?.data;
  if (!cbData || !cbData.startsWith('cancel_duel:')) return;

  const duelId = cbData.replace('cancel_duel:', '');
  const duel = getDuelSession(duelId);

  if (!duel) {
    return ctx.answerCallbackQuery({ text: 'Duel already closed.' });
  }

  if (ctx.from?.id !== duel.creator_id) {
    return ctx.answerCallbackQuery({
      text: 'Only the challenger can cancel this duel.',
      show_alert: true,
    });
  }

  duel.status = 'cancelled';
  activeDuels.delete(duelId);

  await ctx.answerCallbackQuery({ text: 'Duel cancelled.' });
  try {
    await ctx.editMessageText('❌ *1v1 Duel challenge was cancelled by the host.*', {
      parse_mode: 'Markdown',
    });
  } catch {}
}
