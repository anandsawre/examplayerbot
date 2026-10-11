import { Context, InputFile } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getQuizById, getQuestionsForQuiz, getUser } from '../db/queries';
import { generateScorecardPdf, StudentInfo, UserAnswerRecord } from '../services/pdfGenerator';
import { ScoreResult } from '../services/scoring';

// Cache latest completed attempt results per user for instant PDF attachment
export interface CachedAttempt {
  quizId: string;
  result: ScoreResult;
  answers: UserAnswerRecord[];
  completedAt: Date;
}

export const recentUserAttempts = new Map<number, CachedAttempt>();

/**
 * Handles generating and sending the official PDF Scorecard & Solutions booklet to a user
 */
export async function handleDownloadPdfScorecard(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string
) {
  const userId = ctx.from?.id;
  if (!userId) return;

  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({
      text: '📄 Compiling official examination report and solutions... Please wait.',
    });
  }

  const waitMsg = await ctx.reply('⏳ *Generating Official Examination Booklet...*\n_Compiling your high-resolution Scorecard & Solutions PDF document..._', {
    parse_mode: 'Markdown',
  });

  try {
    const quiz = await getQuizById(supabase, quizId);
    if (!quiz) {
      await ctx.api.editMessageText(
        ctx.chat!.id,
        waitMsg.message_id,
        '❌ Examination module not found.'
      );
      return;
    }

    const questions = await getQuestionsForQuiz(supabase, quizId);
    if (!questions || questions.length === 0) {
      await ctx.api.editMessageText(
        ctx.chat!.id,
        waitMsg.message_id,
        '❌ No questions recorded for this examination module.'
      );
      return;
    }

    const user = await getUser(supabase, userId);
    const studentInfo: StudentInfo = {
      id: userId,
      name: `${user?.first_name || 'Student'}${user?.last_name ? ' ' + user.last_name : ''}`,
      username: user?.username || ctx.from?.username,
    };

    // Check if user has a cached recent attempt with their specific score and choices
    const cached = recentUserAttempts.get(userId);
    let result: ScoreResult | undefined = undefined;
    let userAnswers: UserAnswerRecord[] | undefined = undefined;

    if (cached && cached.quizId === quizId) {
      result = cached.result;
      userAnswers = cached.answers;
    }

    // Generate PDF buffer
    const pdfBuffer = await generateScorecardPdf(
      quiz,
      questions,
      studentInfo,
      result,
      userAnswers
    );

    // Sanitize title for filename
    const safeTitle = quiz.title.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 30);
    const filename = `${safeTitle}_Solutions.pdf`;

    // Send PDF document via Telegram
    await ctx.api.sendDocument(
      ctx.chat!.id,
      new InputFile(pdfBuffer, filename),
      {
        caption:
          `📄 *Official Examination Document*\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
          `📚 *Examination:* ${quiz.title}\n` +
          `👤 *Candidate:* ${studentInfo.name}\n` +
          (result ? `🎯 *Final Score:* ${result.finalScore} / ${result.maxScore} (${result.accuracy}% Accuracy)\n` : '') +
          `❓ *Total Questions:* ${questions.length}\n\n` +
          `✨ This document contains complete verified answer keys, candidate responses, and detailed question-by-question explanations for revision.`,
        parse_mode: 'Markdown',
      }
    );

    // Delete temporary loading message
    await ctx.api.deleteMessage(ctx.chat!.id, waitMsg.message_id).catch(() => {});
  } catch (error: any) {
    console.error('Error generating PDF scorecard:', error);
    try {
      await ctx.api.editMessageText(
        ctx.chat!.id,
        waitMsg.message_id,
        '⚠️ An error occurred during PDF generation. Please retry in a few moments.'
      );
    } catch {}
  }
}
