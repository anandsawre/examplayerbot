import { Context, Api, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import {
  getQuizById,
  getQuestionsForQuiz,
  getActiveSession,
  createActiveSession,
  updateActiveSession,
  deleteActiveSession,
  getQuestionById,
  recordQuizAttempt,
  getUser,
  recordMistake,
  resolveMistake,
} from '../db/queries';
import { renderScorecardMessage } from '../services/quizEngine';
import { calculateQuizResult } from '../services/scoring';
import { AnswerRecord, Question, Quiz } from '../types';
import { checkChannelMembership, sendJoinChannelPrompt } from './membership';
import { isTelegramForbidden, sanitizeError } from '../utils/telegramErrors';
import { showPaymentPrompt } from './payment';
import { isAdmin } from '../utils/admin';
import { groupPollToChatMap } from './groupQuiz';
import { recentUserAttempts } from './pdfExport';

export interface SoloPollSession {
  quizId: string;
  userId: number;
  chatId: number;
  questions: Question[];
  currentIndex: number;
  answers: AnswerRecord[];
  startedAt: string;
  currentPollId?: string;
  questionTimer?: NodeJS.Timeout;
}

// In-memory active solo poll sessions map (keyed by Telegram userId)
export const soloPollSessions = new Map<number, SoloPollSession>();

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function escapeMarkdown(text: string): string {
  if (!text) return '';
  return text
    .replace(/_/g, '\\_')
    .replace(/\*/g, '\\*')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]')
    .replace(/`/g, '\\`');
}

function escapeHtml(text: string): string {
  if (!text) return '';
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

/**
 * Starts a solo quiz in Telegram Native Quiz Poll Mode with live circular timer & confetti!
 */
export async function handleStartQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  const userId = ctx.from?.id;
  const chatId = ctx.chat?.id;
  if (!userId || !chatId) return;

  // Solo test must only run in Private DM chat!
  if (ctx.chat?.type !== 'private') {
    const botUsername = ctx.me.username;
    const soloUrl = `https://t.me/${botUsername}?start=quiz_${quizId}`;
    const keyboard = new InlineKeyboard()
      .text('⚔️ Initiate Group Examination Battle', `launch_grp:${quizId}`)
      .row()
      .url('📝 Attempt Solo in Direct Message', soloUrl);

    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery();
    }
    await ctx.reply(
      `⚠️ *Solo Examination Mode Restricted to Direct Chat*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Individual assessments must be taken privately to ensure individual timing and score accuracy.\n\n` +
      `• *Host for all group members:* Select "⚔️ Initiate Group Examination Battle" below.\n` +
      `• *Take your personal test:* Select "📝 Attempt Solo in Direct Message".`,
      { parse_mode: 'Markdown', reply_markup: keyboard }
    );
    return;
  }

  // 1. Force Channel Subscription Check
  const { isMember, channelUrl } = await checkChannelMembership(ctx, supabase, env);
  if (!isMember && channelUrl) {
    return sendJoinChannelPrompt(ctx, channelUrl, `start_quiz:${quizId}`);
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({ text: 'Examination not found.', show_alert: true });
    }
    return;
  }

  // 2. Premium Test Check (Admin automatically bypasses lock)
  if (quiz.is_premium && !isAdmin(ctx, env)) {
    const user = await getUser(supabase, userId);
    if (!user?.is_premium) {
      return showPaymentPrompt(ctx, supabase, env);
    }
  }

  const questions = await getQuestionsForQuiz(supabase, quizId);
  if (!questions || questions.length === 0) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: 'No questions currently uploaded for this examination module.',
        show_alert: true,
      });
    }
    return;
  }

  // Clear any existing active poll session for this user
  const existingSession = soloPollSessions.get(userId);
  if (existingSession?.questionTimer) {
    clearTimeout(existingSession.questionTimer);
  }
  soloPollSessions.delete(userId);

  // Shuffle questions for fairness
  const shuffledQuestions = [...questions].sort(() => Math.random() - 0.5);
  const timeLimit = Math.min(600, Math.max(10, quiz.time_limit_seconds || 30));

  // Initialize new session
  const newSession: SoloPollSession = {
    quizId,
    userId,
    chatId,
    questions: shuffledQuestions,
    currentIndex: 0,
    answers: [],
    startedAt: new Date().toISOString(),
  };

  soloPollSessions.set(userId, newSession);

  // Also persist in Supabase active_sessions
  await createActiveSession(supabase, {
    user_id: userId,
    quiz_id: quizId,
    current_index: 0,
    question_ids: shuffledQuestions.map((q) => q.id),
    answers: [],
    started_at: newSession.startedAt,
    updated_at: newSession.startedAt,
  });

  const introText =
    `🎯 *EXAMINATION SESSION COMMENCING*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📚 *Examination:* ${escapeMarkdown(quiz.title)}\n` +
    `❓ *Total Questions:* \`${shuffledQuestions.length}\`\n` +
    `⏱️ *Time Limit:* \`${timeLimit}s\` per question\n` +
    `⚠️ *Marking Scheme:* +${quiz.marks_per_question} / -${quiz.negative_marks}\n\n` +
    `⚡ *Examination Guidelines:*\n` +
    `• Questions are rendered via Telegram Interactive Quiz Polls.\n` +
    `• An active circular countdown timer is enforced for each item.\n` +
    `• Instant response feedback and answer key explanations are provided.\n` +
    `• To abort your examination session at any point, submit \`/quit\`.\n\n` +
    `_Question 1 is loading..._`;

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: 'Beginning examination session...' });
    try {
      await ctx.editMessageText(introText, { parse_mode: 'Markdown' });
    } catch {
      await ctx.reply(introText, { parse_mode: 'Markdown' });
    }
  } else {
    await ctx.reply(introText, { parse_mode: 'Markdown' });
  }

  // Brief pause then dispatch first question
  await sleep(2000);
  await sendNextPollQuestion(ctx.api, supabase, env, userId);
}

/**
 * Retrieves the in-memory session or restores it from Supabase active_sessions
 */
export async function getOrRestoreSession(
  supabase: SupabaseClient,
  userId: number
): Promise<SoloPollSession | null> {
  let session = soloPollSessions.get(userId);
  if (session) return session;

  const dbSession = await getActiveSession(supabase, userId);
  if (!dbSession) return null;

  const allQuestions = await getQuestionsForQuiz(supabase, dbSession.quiz_id);
  if (!allQuestions || allQuestions.length === 0) return null;

  const orderedQuestions: Question[] = [];
  if (dbSession.question_ids && dbSession.question_ids.length > 0) {
    for (const qid of dbSession.question_ids) {
      const found = allQuestions.find((q) => q.id === qid);
      if (found) orderedQuestions.push(found);
    }
  }

  session = {
    quizId: dbSession.quiz_id,
    userId,
    chatId: userId,
    questions: orderedQuestions.length > 0 ? orderedQuestions : allQuestions,
    currentIndex: dbSession.current_index,
    answers: dbSession.answers || [],
    startedAt: dbSession.started_at,
  };
  soloPollSessions.set(userId, session);
  return session;
}

/**
 * Sends the next question as a native Telegram Quiz Poll with timer
 */
export async function sendNextPollQuestion(
  api: Api,
  supabase: SupabaseClient,
  env: Env,
  userId: number
) {
  const session = await getOrRestoreSession(supabase, userId);
  if (!session) return;

  // Clear any existing timer
  if (session.questionTimer) {
    clearTimeout(session.questionTimer);
    session.questionTimer = undefined;
  }

  // Check if all questions are finished
  if (session.currentIndex >= session.questions.length) {
    return finishSoloPollQuiz(api, supabase, env, session);
  }

  const q = session.questions[session.currentIndex];
  const quiz = await getQuizById(supabase, session.quizId);
  if (!quiz) return;

  const totalQuestions = session.questions.length;
  const qNum = session.currentIndex + 1;
  const timeLimit = Math.min(600, Math.max(10, quiz.time_limit_seconds || 30));

  // Clean existing leading numbers if present in JSON text to prevent "1. 1."
  const cleanQuestionText = q.question_text.replace(/^(Q\.?\s*\d+[\.\)]?\s*|\d+[\.\)]\s*)/i, '').trim();

  // If question text is long, send full text first
  if (cleanQuestionText.length > 280) {
    try {
      await api.sendMessage(
        session.chatId,
        `📖 *Question ${qNum}:*\n\n${escapeMarkdown(cleanQuestionText)}`,
        { parse_mode: 'Markdown' }
      );
    } catch (msgErr: any) {
      if (isTelegramForbidden(msgErr)) {
        console.warn(`[QuizPlay] User ${userId} blocked bot (403 Forbidden). Aborting assessment session.`);
        soloPollSessions.delete(userId);
        return;
      }
      console.error(`[QuizPlay] Failed to send question text for Q${qNum}:`, sanitizeError(msgErr));
    }
  }

  // If image URL is present, send photo
  if (q.image_url) {
    try {
      await api.sendPhoto(session.chatId, q.image_url);
    } catch (e) {
      console.error('Failed to send question image:', e);
    }
  }

  const pollQuestionText =
    cleanQuestionText.length > 270
      ? `<b>Q</b>${qNum}. Select the correct option:`
      : `<b>Q</b>${qNum}. ${escapeHtml(cleanQuestionText.slice(0, 260))}`;

  const rawOptions = Array.isArray(q.options) ? q.options : [];
  const cleanOptions = rawOptions.map((opt) => String(opt).slice(0, 100));

  // Telegram requires 2-10 options for a poll
  if (cleanOptions.length < 2) {
    cleanOptions.push('Option A', 'Option B');
  }

  const safeCorrectIndex = Math.min(
    cleanOptions.length - 1,
    Math.max(0, q.correct_option_index)
  );

  try {
    const pollMessage = await api.sendPoll(
      session.chatId,
      pollQuestionText,
      cleanOptions,
      {
        type: 'quiz',
        correct_option_id: safeCorrectIndex,
        is_anonymous: false, // Essential to capture user's vote via poll_answer
        open_period: timeLimit,
        question_parse_mode: 'HTML',
        explanation: q.explanation ? q.explanation.slice(0, 200) : undefined,
      } as any
    );
    session.currentPollId = pollMessage.poll.id;

    // Track poll in Supabase bot_settings for serverless timeout expiration
    await supabase.from('bot_settings').upsert({
      key: `poll:${pollMessage.poll.id}`,
      value: JSON.stringify({
        userId,
        quizId: session.quizId,
        qIndex: session.currentIndex,
        questionId: q.id,
      }),
    });

    // Timeout countdown timer: If user doesn't answer within timeLimit seconds
    session.questionTimer = setTimeout(async () => {
      try {
        const curSession = soloPollSessions.get(userId) || (await getOrRestoreSession(supabase, userId));
        if (!curSession || curSession.currentIndex !== session.currentIndex) return;

        // Mark as timed out / skipped (0 marks)
        curSession.answers.push({
          question_id: q.id,
          selected_option_index: -1,
          is_correct: false,
        });
        recordMistake(supabase, userId, q.id, curSession.quizId).catch(() => {});

        try {
          await api.sendMessage(
            curSession.chatId,
            `⏰ *Time Expired! (Question ${qNum})*\n_Allocated duration elapsed. Proceeding to next question..._`,
            { parse_mode: 'Markdown' }
          );
        } catch (timerSendErr: any) {
          if (isTelegramForbidden(timerSendErr)) {
            console.warn(`[QuizPlay] User ${userId} blocked bot during timer alert. Aborting.`);
            soloPollSessions.delete(userId);
            return;
          }
        }

        curSession.currentIndex++;
        await updateActiveSession(supabase, userId, curSession.currentIndex, curSession.answers);
        await sleep(1000);
        await sendNextPollQuestion(api, supabase, env, userId);
      } catch (timerErr) {
        console.error(`Error in questionTimer for user ${userId}:`, timerErr);
      }
    }, (timeLimit + 1) * 1000);

  } catch (err: any) {
    if (isTelegramForbidden(err)) {
      console.warn(`[QuizPlay] User ${userId} blocked bot during poll dispatch (403 Forbidden). Aborting assessment.`);
      soloPollSessions.delete(userId);
      return;
    }

    console.error(`Error sending poll for Q${qNum}:`, sanitizeError(err));
    // If poll fails for non-fatal reason, skip forward once without looping indefinitely
    session.currentIndex++;
    if (session.currentIndex < session.questions.length) {
      await sendNextPollQuestion(api, supabase, env, userId);
    }
  }
}

/**
 * Handles user answering via Telegram Native Quiz Poll
 */
export async function handleSoloPollAnswer(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const pollAnswer = ctx.pollAnswer;
  if (!pollAnswer || !pollAnswer.user) return;

  // If this poll belongs to an active group battle, ignore it here!
  if (groupPollToChatMap.has(pollAnswer.poll_id)) {
    return;
  }

  const userId = pollAnswer.user.id;
  const session = await getOrRestoreSession(supabase, userId);
  if (!session) return; // Might be a group quiz poll, ignore

  // Ensure this session belongs to a private chat (DM)
  if (session.chatId !== userId) {
    return;
  }

  // Ensure this poll answer matches the user's currently active solo poll
  if (session.currentPollId && session.currentPollId !== pollAnswer.poll_id) {
    return;
  }

  // Clear timeout timer
  if (session.questionTimer) {
    clearTimeout(session.questionTimer);
    session.questionTimer = undefined;
  }

  const currentQ = session.questions[session.currentIndex];
  if (!currentQ) return;

  const selectedOption = pollAnswer.option_ids[0]; // Selected option index
  const isCorrect = selectedOption === currentQ.correct_option_index;

  // Record answer
  session.answers.push({
    question_id: currentQ.id,
    selected_option_index: selectedOption,
    is_correct: isCorrect,
  });

  // Track in Candidate Mistake Vault (Phase 1A)
  if (isCorrect) {
    resolveMistake(supabase, userId, currentQ.id).catch(() => {});
  } else {
    recordMistake(supabase, userId, currentQ.id, session.quizId).catch(() => {});
  }

  // Advance index
  session.currentIndex++;

  // Delete poll tracking from Supabase since user answered
  await supabase.from('bot_settings').delete().eq('key', `poll:${pollAnswer.poll_id}`);

  // Persist session to Supabase active_sessions
  await updateActiveSession(supabase, userId, session.currentIndex, session.answers);

  // Wait 2.5 seconds so user can see their confetti / red highlight & read bulb explanation
  await sleep(2500);

  // Send next question
  await sendNextPollQuestion(ctx.api, supabase, env, userId);
}

/**
 * Handles Telegram Poll timer expiration on Serverless Cloudflare Workers (when poll closes without answer)
 */
export async function handlePollClosed(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  const poll = ctx.poll;
  if (!poll || !poll.is_closed) return;

  // Retrieve tracked poll mapping from bot_settings
  const { data } = await supabase
    .from('bot_settings')
    .select('value')
    .eq('key', `poll:${poll.id}`)
    .single();

  if (!data?.value) return; // Not a tracked solo test poll or already answered

  // Clean up tracking key
  await supabase.from('bot_settings').delete().eq('key', `poll:${poll.id}`);

  let meta: { userId: number; quizId: string; qIndex: number; questionId: string };
  try {
    meta = JSON.parse(data.value);
  } catch {
    return;
  }

  const activeSession = await getActiveSession(supabase, meta.userId);
  if (!activeSession) return;

  // If user already answered, current_index would have advanced past meta.qIndex
  if (activeSession.current_index !== meta.qIndex) return;

  const currentAnswers = activeSession.answers || [];
  // Record timed out / skipped question (0 marks)
  currentAnswers.push({
    question_id: meta.questionId,
    selected_option_index: -1,
    is_correct: false,
  });
  recordMistake(supabase, meta.userId, meta.questionId, activeSession.quiz_id).catch(() => {});

  const nextIndex = activeSession.current_index + 1;
  const totalQuestions = activeSession.question_ids.length;

  // Notify student that time is up for this question
  try {
    await ctx.api.sendMessage(
      meta.userId,
      `⏰ *Time Expired! (Question ${meta.qIndex + 1})*\n_Allocated duration elapsed. Proceeding to next question..._`,
      { parse_mode: 'Markdown' }
    );
  } catch (notifyErr: any) {
    if (isTelegramForbidden(notifyErr)) {
      console.warn(`[QuizPlay] User ${meta.userId} blocked bot. Aborting timeout notice.`);
      soloPollSessions.delete(meta.userId);
      return;
    }
  }

  if (nextIndex < totalQuestions) {
    await updateActiveSession(supabase, meta.userId, nextIndex, currentAnswers);

    // Update in-memory session if present
    const memSession = soloPollSessions.get(meta.userId);
    if (memSession) {
      memSession.currentIndex = nextIndex;
      memSession.answers = currentAnswers;
    }

    await sleep(1500);
    await sendNextPollQuestion(ctx.api, supabase, env, meta.userId);
  } else {
    // All questions done! Finish test
    const quiz = await getQuizById(supabase, activeSession.quiz_id);
    if (!quiz) return;

    const result = calculateQuizResult(quiz, currentAnswers, activeSession.started_at);

    await recordQuizAttempt(supabase, {
      user_id: meta.userId,
      quiz_id: quiz.id,
      total_questions: result.totalQuestions,
      correct_count: result.correctCount,
      wrong_count: result.wrongCount,
      skipped_count: result.skippedCount,
      score: result.finalScore,
      accuracy_percent: result.accuracy,
      time_taken_seconds: result.timeTakenSeconds,
    });

    await deleteActiveSession(supabase, meta.userId);
    soloPollSessions.delete(meta.userId);

    // Cache completed attempt for instant PDF scorecard download
    recentUserAttempts.set(meta.userId, {
      quizId: quiz.id,
      result,
      answers: currentAnswers,
      completedAt: new Date(),
    });

    const user = await getUser(supabase, meta.userId);
    const studentName = user?.first_name || 'Student';

    let botUsername = 'Examplayer_bot';
    try {
      const me = await ctx.api.getMe();
      botUsername = me.username;
    } catch {}

    const { text, keyboard } = renderScorecardMessage(quiz, studentName, result, botUsername);

    await ctx.api.sendMessage(meta.userId, text, {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    });
  }
}

/**
 * Finishes the quiz, records attempts in Supabase, and displays the official scorecard
 */
async function finishSoloPollQuiz(
  api: Api,
  supabase: SupabaseClient,
  env: Env,
  session: SoloPollSession
) {
  soloPollSessions.delete(session.userId);

  const quiz = await getQuizById(supabase, session.quizId);
  if (!quiz) return;

  // Calculate official test result with negative marking
  const result = calculateQuizResult(quiz, session.answers, session.startedAt);

  // Record attempt in database
  await recordQuizAttempt(supabase, {
    user_id: session.userId,
    quiz_id: quiz.id,
    total_questions: result.totalQuestions,
    correct_count: result.correctCount,
    wrong_count: result.wrongCount,
    skipped_count: result.skippedCount,
    score: result.finalScore,
    accuracy_percent: result.accuracy,
    time_taken_seconds: result.timeTakenSeconds,
  });

  // Cleanup active session in Supabase
  await deleteActiveSession(supabase, session.userId);

  // Cache completed attempt for instant PDF scorecard download
  recentUserAttempts.set(session.userId, {
    quizId: quiz.id,
    result,
    answers: session.answers,
    completedAt: new Date(),
  });

  // Get user details
  const user = await getUser(supabase, session.userId);
  const studentName = user?.first_name || 'Student';

  let botUsername = 'Examplayer_bot';
  try {
    const me = await api.getMe();
    botUsername = me.username;
  } catch {}

  // Render official scorecard
  const { text, keyboard } = renderScorecardMessage(quiz, studentName, result, botUsername);

  try {
    await api.sendMessage(session.chatId, text, {
      parse_mode: 'Markdown',
      reply_markup: keyboard,
    });
  } catch (err: any) {
    if (isTelegramForbidden(err)) {
      console.warn(`[QuizPlay] User ${session.userId} blocked bot. Scorecard not delivered (403 Forbidden).`);
      return;
    }
    console.error('Error sending scorecard:', sanitizeError(err));
  }
}

/**
 * Cancels active quiz if user types /quit
 */
export async function handleQuitQuiz(ctx: Context, supabase: SupabaseClient) {
  if (ctx.chat && ctx.chat.type !== 'private') {
    return ctx.reply('⚠️ Solo examination sessions can only be aborted via direct message (/quit). Group battles must be terminated by a Group Administrator via /stopquiz.');
  }

  const userId = ctx.from?.id;
  if (!userId) return;

  const session = soloPollSessions.get(userId);
  if (session) {
    if (session.questionTimer) clearTimeout(session.questionTimer);
    soloPollSessions.delete(userId);
  }

  await deleteActiveSession(supabase, userId);

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: 'Examination session terminated.' });
    await ctx.editMessageText('❌ *Examination Session Terminated.*\nTo browse available tests, submit /quizzes.', { parse_mode: 'Markdown' });
  } else {
    await ctx.reply('❌ *Examination Session Terminated.*\n\nTo begin a new assessment, browse /quizzes.', {
      parse_mode: 'Markdown',
    });
  }
}

/**
 * Backward compatibility handler for any inline callback buttons
 */
export async function handleAnswerCallback(
  ctx: Context,
  supabase: SupabaseClient,
  questionId: string,
  optionIndex: number
) {
  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({
      text: '⚠️ This examination operates via interactive poll. Please cast your vote on the poll directly.',
      show_alert: true,
    });
  }
}

/**
 * Handles user clicking "⏭️ Next / Skip Question" button
 */
export async function handleSkipQuestion(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string,
  targetIndex: number
) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const session = await getOrRestoreSession(supabase, userId);
  if (!session || session.quizId !== quizId) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: 'No active examination session found.',
      });
    }
    return;
  }

  // Prevent skipping if current index doesn't match target index (e.g. already answered or skipped)
  if (session.currentIndex !== targetIndex) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: session.currentIndex > targetIndex
          ? 'This question has already been submitted.'
          : 'Please answer the active question on screen.',
      });
    }
    return;
  }

  // Acknowledge callback immediately
  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({
      text: `⏭️ Question ${targetIndex + 1} skipped.`,
    });
  }

  // Clear timeout timer if running
  if (session.questionTimer) {
    clearTimeout(session.questionTimer);
    session.questionTimer = undefined;
  }

  // Also clean up poll tracking in bot_settings if present
  if (session.currentPollId) {
    await supabase.from('bot_settings').delete().eq('key', `poll:${session.currentPollId}`);
  }

  const currentQ = session.questions[session.currentIndex];
  if (currentQ) {
    session.answers.push({
      question_id: currentQ.id,
      selected_option_index: -1,
      is_correct: false,
    });
    recordMistake(supabase, userId, currentQ.id, session.quizId).catch(() => {});
  }

  // Increment index
  session.currentIndex++;

  // Update DB session
  await updateActiveSession(supabase, userId, session.currentIndex, session.answers);

  // Edit companion message so buttons are no longer clickable
  try {
    await ctx.editMessageText(
      `⏭️ *Question ${targetIndex + 1} Skipped.* _Loading subsequent question..._`,
      { parse_mode: 'Markdown' }
    );
  } catch {
    // In case message can't be edited, safe to ignore
  }

  // Dispatch next question or finish
  if (session.currentIndex < session.questions.length) {
    await sendNextPollQuestion(ctx.api, supabase, env, userId);
  } else {
    await finishSoloPollQuiz(ctx.api, supabase, env, session);
  }
}
