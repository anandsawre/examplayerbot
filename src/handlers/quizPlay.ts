import { Context } from 'grammy';
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
} from '../db/queries';
import { renderQuestionMessage, renderScorecardMessage } from '../services/quizEngine';
import { calculateQuizResult } from '../services/scoring';
import { AnswerRecord } from '../types';
import { checkChannelMembership, sendJoinChannelPrompt } from './membership';
import { showPaymentPrompt } from './payment';

export async function handleStartQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  const userId = ctx.from?.id;
  if (!userId) return;

  // 1. Force Channel Subscription Check
  const { isMember, channelUrl } = await checkChannelMembership(ctx, supabase, env);
  if (!isMember && channelUrl) {
    return sendJoinChannelPrompt(ctx, channelUrl, `start_quiz:${quizId}`);
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({ text: 'Quiz not found!', show_alert: true });
    }
    return;
  }

  // 2. Premium Test Check
  if (quiz.is_premium) {
    const user = await getUser(supabase, userId);
    if (!user?.is_premium) {
      return showPaymentPrompt(ctx, supabase, env);
    }
  }

  const questions = await getQuestionsForQuiz(supabase, quizId);
  if (!questions || questions.length === 0) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: 'Is quiz me abhi questions add nahi kiye gaye hain.',
        show_alert: true,
      });
    }
    return;
  }

  // Shuffle question IDs for fairness / anti-cheat
  const shuffledIds = [...questions.map((q) => q.id)].sort(() => Math.random() - 0.5);

  // Initialize session in Supabase
  const sessionSuccess = await createActiveSession(supabase, {
    user_id: userId,
    quiz_id: quizId,
    current_index: 0,
    question_ids: shuffledIds,
    answers: [],
    started_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });

  if (!sessionSuccess) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: 'Session shuru karne me error aayi. Please dobara try karein.',
        show_alert: true,
      });
    }
    return;
  }

  // Fetch the first question
  const firstQuestion = questions.find((q) => q.id === shuffledIds[0]) || questions[0];
  const { text, keyboard } = renderQuestionMessage(quiz, firstQuestion, 0, shuffledIds.length);

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery({ text: 'Test shuru ho gaya! All the best 🎯' });
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

export async function handleAnswerCallback(
  ctx: Context,
  supabase: SupabaseClient,
  questionId: string,
  optionIndex: number
) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const session = await getActiveSession(supabase, userId);
  if (!session) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: 'Aapka test session expire ho chuka hai. Kripya naya test shuru karein.',
        show_alert: true,
      });
    }
    return;
  }

  const quiz = await getQuizById(supabase, session.quiz_id);
  if (!quiz) return;

  const question = await getQuestionById(supabase, questionId);
  if (!question) return;

  // Evaluate Answer
  const isSkip = optionIndex === -1;
  const isCorrect = !isSkip && optionIndex === question.correct_option_index;

  let toastText = '';
  if (isSkip) {
    toastText = '⏭️ Question Skipped (0 Marks)';
  } else if (isCorrect) {
    toastText = `✅ Sahi Jawab! (+${quiz.marks_per_question} Marks)`;
  } else {
    const correctLetter = ['A', 'B', 'C', 'D'][question.correct_option_index] || '';
    toastText = `❌ Galat Jawab! (-${quiz.negative_marks} Penalty) Sahi tha: Option ${correctLetter}`;
  }

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: toastText, show_alert: !isCorrect && !isSkip });
  }

  // Save answer record
  const currentAnswers: AnswerRecord[] = session.answers || [];
  currentAnswers.push({
    question_id: questionId,
    selected_option_index: optionIndex,
    is_correct: isCorrect,
  });

  const nextIndex = session.current_index + 1;
  const totalQuestions = session.question_ids.length;

  if (nextIndex < totalQuestions) {
    // Test continues -> Render Next Question
    await updateActiveSession(supabase, userId, nextIndex, currentAnswers);

    const nextQuestionId = session.question_ids[nextIndex];
    const nextQuestion = await getQuestionById(supabase, nextQuestionId);

    if (nextQuestion) {
      const { text, keyboard } = renderQuestionMessage(quiz, nextQuestion, nextIndex, totalQuestions);
      try {
        await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      } catch (e) {
        // Fallback if edit fails
        await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      }
    }
  } else {
    // Test Finished! Calculate Final Score
    const result = calculateQuizResult(quiz, currentAnswers, session.started_at);

    // Save attempt in database
    await recordQuizAttempt(supabase, {
      user_id: userId,
      quiz_id: quiz.id,
      total_questions: result.totalQuestions,
      correct_count: result.correctCount,
      wrong_count: result.wrongCount,
      skipped_count: result.skippedCount,
      score: result.finalScore,
      accuracy_percent: result.accuracy,
      time_taken_seconds: result.timeTakenSeconds,
    });

    // Cleanup active session
    await deleteActiveSession(supabase, userId);

    // Render Scorecard
    const studentName = ctx.from.first_name || 'Student';
    const { text, keyboard } = renderScorecardMessage(quiz, studentName, result);

    try {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    } catch {
      await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    }
  }
}

export async function handleQuitQuiz(ctx: Context, supabase: SupabaseClient) {
  const userId = ctx.from?.id;
  if (!userId) return;

  await deleteActiveSession(supabase, userId);

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({ text: 'Test cancel kar diya gaya.' });
    await ctx.editMessageText('❌ Test cancel kar diya gaya hai.\nNaya test lene ke liye /quizzes type karein.');
  }
}
