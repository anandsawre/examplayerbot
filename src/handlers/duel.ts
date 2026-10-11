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
// key: pollId -> { duelId, qIndex, question, startTime, forUserId? }
export const duelPollTracker: Map<
  string,
  { duelId: string; qIndex: number; question: Question; startTime: number; forUserId?: number }
> = new Map();

/**
 * Displays the Question Count Selection Panel for 1v1 Duels
 */
export async function showDuelCountPicker(ctx: Context) {
  const text =
    `⚔️ *1v1 CANDIDATE DUEL CONFIGURATION*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Challenger: *${ctx.from?.first_name || 'Candidate'}*\n\n` +
    `Chunein ki aapko is 1v1 face-off battle me kitne questions ka challenge rakhna hai:\n\n` +
    `• *⚡ 5 Questions:* Rapid Blitz (~1.5 Mins)\n` +
    `• *🎯 10 Questions:* Standard Face-Off (~3 Mins)\n` +
    `• *🔥 15 Questions:* Intensive Drill (~4.5 Mins)\n` +
    `• *🏆 25 Questions:* Half Mock Marathon (~7 Mins)\n` +
    `• *👑 50 Questions:* Grandmaster Full Mock (~15 Mins)\n\n` +
    `💡 _Tip: Aap chat me directly bhi likh sakte hain: \`/duel 10\` ya \`/duel 25\`_`;

  const keyboard = new InlineKeyboard()
    .text('⚡ 5 Questions', 'duel_count:5')
    .text('🎯 10 Questions', 'duel_count:10')
    .row()
    .text('🔥 15 Questions', 'duel_count:15')
    .text('🏆 25 Questions', 'duel_count:25')
    .row()
    .text('👑 50 Questions (Full Mock)', 'duel_count:50')
    .row()
    .text('🔙 Platform Dashboard', 'menu_start');

  if (ctx.callbackQuery) {
    try {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      await ctx.answerCallbackQuery();
      return;
    } catch {}
  }

  return ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
}

/**
 * Handles /duel command in Group or Direct Chat
 */
export async function handleDuelCommand(ctx: Context, supabase: SupabaseClient) {
  const text = ctx.message?.text || '';
  const parts = text.trim().split(/\s+/);

  // Check if user passed count directly: e.g. /duel 10 or /duel 25
  if (parts.length > 1) {
    const requested = parseInt(parts[1], 10);
    if (!isNaN(requested) && requested >= 3 && requested <= 50) {
      return launchDuelWithCount(ctx, supabase, requested);
    }
  }

  // Otherwise, prompt user with interactive picker
  return showDuelCountPicker(ctx);
}

/**
 * Launches a 1v1 duel with the chosen number of questions (3 to 50)
 */
export async function launchDuelWithCount(
  ctx: Context,
  supabase: SupabaseClient,
  questionCount = 5
) {
  const userId = ctx.from?.id;
  const chatId = ctx.chat?.id;
  if (!userId || !chatId) return;

  const targetCount = Math.min(50, Math.max(3, questionCount));
  const user = await getUser(supabase, userId);
  const challengerName = user?.first_name || ctx.from?.first_name || 'Candidate';
  const isDm = ctx.chat?.type === 'private';

  // Fetch available quizzes to source questions
  const quizzes = await getActiveQuizzes(supabase);
  if (!quizzes || quizzes.length === 0) {
    if (ctx.callbackQuery) await ctx.answerCallbackQuery({ text: 'No active quizzes found.' });
    return ctx.reply('⚠️ No active examination papers available for dueling at this moment.');
  }

  // Find all quizzes that have questions
  const quizzesWithQuestions: { quiz: any; questions: Question[] }[] = [];
  for (const q of quizzes) {
    const list = await getQuestionsForQuiz(supabase, q.id);
    if (list && list.length > 0) {
      quizzesWithQuestions.push({ quiz: q, questions: list });
    }
  }

  if (quizzesWithQuestions.length === 0) {
    if (ctx.callbackQuery) await ctx.answerCallbackQuery({ text: 'No questions found.' });
    return ctx.reply('⚠️ Sufficient questions not found in the examination vault to initiate a duel.');
  }

  // Try to find a single quiz that has >= targetCount questions
  let selectedTitle = 'General Awareness & Mixed Mock';
  let selectedQuizId = quizzesWithQuestions[0].quiz.id;
  let questions: Question[] = [];

  const largeQuizzes = quizzesWithQuestions.filter((item) => item.questions.length >= targetCount);
  if (largeQuizzes.length > 0) {
    const pick = largeQuizzes[Math.floor(Math.random() * largeQuizzes.length)];
    selectedTitle = pick.quiz.title;
    selectedQuizId = pick.quiz.id;
    const shuffled = [...pick.questions].sort(() => Math.random() - 0.5);
    questions = shuffled.slice(0, targetCount);
  } else {
    // Pool questions across all active quizzes
    const allPool: Question[] = [];
    for (const item of quizzesWithQuestions) {
      allPool.push(...item.questions);
    }
    const shuffled = allPool.sort(() => Math.random() - 0.5);
    questions = shuffled.slice(0, targetCount);
    selectedTitle = 'All-India Mixed Mock Challenge';
  }

  if (questions.length === 0) {
    if (ctx.callbackQuery) await ctx.answerCallbackQuery({ text: 'Insufficient questions.' });
    return ctx.reply('⚠️ Insufficient questions available for this round size.');
  }

  const duelId = `duel_${Date.now()}_${userId}`;
  const duel: DuelSession = {
    id: duelId,
    chat_id: chatId,
    creator_id: userId,
    creator_name: challengerName,
    quiz_id: selectedQuizId,
    quiz_title: selectedTitle,
    is_dm: isDm,
    question_ids: questions.map((q) => q.id),
    questions,
    current_q_index: 0,
    creator_answers: [],
    opponent_answers: [],
    status: 'pending',
    created_at: new Date().toISOString(),
  };

  await createDuelSession(duel);

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery();
  }

  if (isDm) {
    // In Direct Chat: Provide shareable challenge link
    const botUsername = ctx.me?.username || 'Examplayer_bot';
    const challengeUrl = `https://t.me/${botUsername}?start=${duelId}`;
    const shareText = encodeURIComponent(
      `⚔️ ${challengerName} has challenged you to a 1v1 Rapid Examination Duel (${questions.length} Questions) on Examplayer! Tap to accept: ${challengeUrl}`
    );
    const shareUrl = `https://t.me/share/url?url=${encodeURIComponent(challengeUrl)}&text=${shareText}`;

    const text =
      `⚔️ *1v1 CANDIDATE DUEL LOBBY CREATED*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `Challenger: *${challengerName}* (ELO: ${user?.duel_rating || 1200})\n` +
      `Format: *${questions.length} Rapid Questions (15s per question)*\n\n` +
      `🔗 *Shareable Duel Challenge Link:*\n` +
      `\`${challengeUrl}\`\n\n` +
      `Share this link with a peer or in your study group. As soon as your opponent taps accept, the battle will begin!`;

    const keyboard = new InlineKeyboard()
      .url('📤 Share Duel Challenge to Telegram', shareUrl)
      .row()
      .text('❌ Cancel Duel', `cancel_duel:${duelId}`);

    if (ctx.callbackQuery) {
      try {
        await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
        return;
      } catch {}
    }
    return ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }

  // In Group Chat: Post live lobby
  const text =
    `⚔️ *1v1 CANDIDATE LIVE DUEL CHALLENGE*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Challenger: *${challengerName}* (ELO: ${user?.duel_rating || 1200})\n` +
    `Format: *${questions.length} Rapid-Fire Questions (15s Timer)*\n\n` +
    `⚡ *Rules of Engagement:*\n` +
    `• Head-to-head speed & accuracy duel\n` +
    `• Winner receives +25 ELO Points on the All-India Leaderboard\n\n` +
    `_Who dares to accept the challenge? Tap below to start!_`;

  const keyboard = new InlineKeyboard()
    .text('⚔️ Accept Challenge (Player 2)', `accept_duel:${duelId}`)
    .row()
    .text('❌ Withdraw Challenge', `cancel_duel:${duelId}`);

  if (ctx.callbackQuery) {
    try {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      return;
    } catch {}
  }

  await ctx.reply(text, {
    parse_mode: 'Markdown',
    reply_markup: keyboard,
  });
}


/**
 * Handles incoming shared duel link: /start duel_<duelId>
 */
export async function handleIncomingDuelInvite(
  ctx: Context,
  supabase: SupabaseClient,
  duelId: string
) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const duel = getDuelSession(duelId);
  if (!duel) {
    return ctx.reply(
      `⚠️ *This 1v1 duel challenge has expired or does not exist.*\n\n` +
      `You can launch a new challenge anytime using /duel!`,
      { parse_mode: 'Markdown' }
    );
  }

  if (duel.status !== 'pending') {
    return ctx.reply(
      `⚠️ *This duel is already ${duel.status === 'in_progress' ? 'in progress' : 'completed'}.*\n\n` +
      `You can start a new duel anytime using /duel!`,
      { parse_mode: 'Markdown' }
    );
  }

  if (duel.creator_id === userId) {
    const botUsername = ctx.me?.username || 'Examplayer_bot';
    const challengeUrl = `https://t.me/${botUsername}?start=${duel.id}`;
    return ctx.reply(
      `⚠️ *You cannot accept your own duel challenge!*\n\n` +
      `Please share this link with a peer or in your study group so another candidate can accept it:\n` +
      `\`${challengeUrl}\``,
      { parse_mode: 'Markdown' }
    );
  }

  const oppUser = await getUser(supabase, userId);
  const oppName = oppUser?.first_name || ctx.from?.first_name || 'Candidate';

  const text =
    `⚔️ *1v1 CANDIDATE LIVE DUEL INVITATION!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Challenger: *${duel.creator_name}*\n` +
    `Format: *${duel.questions.length} Rapid Questions (15s per question)*\n\n` +
    `⚡ *Match Regulations:*\n` +
    `• Real-time speed and accuracy scoring\n` +
    `• Winner earns +25 ELO Points on the All-India Leaderboard\n` +
    `• Both candidates will answer simultaneously in direct messages\n\n` +
    `_Namaste ${oppName}! Tap below to accept the challenge and begin the duel immediately:_`;

  const keyboard = new InlineKeyboard()
    .text('⚔️ Accept Challenge & Start Duel', `accept_duel:${duelId}`)
    .row()
    .text('❌ Decline Challenge', `decline_duel:${duelId}`);

  return ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
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

  const confirmMsg =
    `🥊 *1v1 DUEL CONFIRMED: THE BATTLE BEGINS!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `🔴 *Player 1:* ${duel.creator_name}\n` +
    `🔵 *Player 2:* ${opponentName}\n\n` +
    `⏱️ Questions will be dispatched every 15 seconds. May the best candidate prevail!\n` +
    `_Question 1 loading in 3 seconds..._`;

  if (duel.is_dm) {
    // In DM duel: edit opponent's message and notify creator
    try {
      await ctx.editMessageText(confirmMsg, { parse_mode: 'Markdown' });
    } catch {}

    try {
      await ctx.api.sendMessage(duel.creator_id, confirmMsg, { parse_mode: 'Markdown' });
    } catch (err) {
      console.warn('Could not notify creator of duel start:', err);
    }
  } else {
    // In Group duel: edit group message
    try {
      await ctx.editMessageText(confirmMsg, { parse_mode: 'Markdown' });
    } catch {}
  }

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
    if (duel.is_dm && duel.opponent_id) {
      // DM Duel: Send identical poll to both creator's DM and opponent's DM
      const [pollMsgCreator, pollMsgOpponent] = await Promise.all([
        api.sendPoll(duel.creator_id, pollHeader, cleanOptions, {
          type: 'quiz',
          correct_option_id: question.correct_option_index,
          is_anonymous: false,
          open_period: 15,
          explanation: question.explanation ? question.explanation.slice(0, 200) : undefined,
        } as any),
        api.sendPoll(duel.opponent_id, pollHeader, cleanOptions, {
          type: 'quiz',
          correct_option_id: question.correct_option_index,
          is_anonymous: false,
          open_period: 15,
          explanation: question.explanation ? question.explanation.slice(0, 200) : undefined,
        } as any),
      ]);

      duel.current_poll_ids = [pollMsgCreator.poll.id, pollMsgOpponent.poll.id];
      duelPollToIdMap.set(pollMsgCreator.poll.id, duel.id);
      duelPollToIdMap.set(pollMsgOpponent.poll.id, duel.id);

      duelPollTracker.set(pollMsgCreator.poll.id, {
        duelId: duel.id,
        qIndex,
        question,
        startTime: Date.now(),
        forUserId: duel.creator_id,
      });

      duelPollTracker.set(pollMsgOpponent.poll.id, {
        duelId: duel.id,
        qIndex,
        question,
        startTime: Date.now(),
        forUserId: duel.opponent_id,
      });
    } else {
      // Group Duel: Send single poll to group
      const pollMsg = await api.sendPoll(duel.chat_id, pollHeader, cleanOptions, {
        type: 'quiz',
        correct_option_id: question.correct_option_index,
        is_anonymous: false,
        open_period: 15,
        explanation: question.explanation ? question.explanation.slice(0, 200) : undefined,
      } as any);

      duel.current_poll_id = pollMsg.poll.id;
      duelPollToIdMap.set(pollMsg.poll.id, duel.id);
      duelPollTracker.set(pollMsg.poll.id, {
        duelId: duel.id,
        qIndex,
        question,
        startTime: Date.now(),
      });
    }

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

  // Calculate scores (2 marks per correct, 0 if wrong/skipped)
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

  if (duel.is_dm && duel.opponent_id) {
    // Send to both players' DMs
    try {
      await api.sendMessage(duel.creator_id, resultText, {
        parse_mode: 'Markdown',
        reply_markup: keyboard,
      });
    } catch {}

    try {
      await api.sendMessage(duel.opponent_id, resultText, {
        parse_mode: 'Markdown',
        reply_markup: keyboard,
      });
    } catch {}
  } else {
    // Send to group chat
    try {
      await api.sendMessage(duel.chat_id, resultText, {
        parse_mode: 'Markdown',
        reply_markup: keyboard,
      });
    } catch (err) {
      console.error('Error posting duel results in group:', err);
    }
  }
}

/**
 * Handles duel cancellation by host
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

/**
 * Handles opponent declining the duel invitation
 */
export async function handleDeclineDuel(ctx: Context) {
  const cbData = ctx.callbackQuery?.data;
  if (!cbData || !cbData.startsWith('decline_duel:')) return;

  const duelId = cbData.replace('decline_duel:', '');
  const duel = getDuelSession(duelId);

  await ctx.answerCallbackQuery({ text: 'Duel invitation declined.' });
  try {
    await ctx.editMessageText('❌ *You have declined this 1v1 duel invitation.*', {
      parse_mode: 'Markdown',
    });
  } catch {}

  if (duel && duel.creator_id) {
    const oppName = ctx.from?.first_name || 'The opponent';
    try {
      await ctx.api.sendMessage(
        duel.creator_id,
        `ℹ️ *${oppName}* declined your 1v1 duel challenge. You can share your invite link with another candidate!`,
        { parse_mode: 'Markdown' }
      );
    } catch {}
  }
}
