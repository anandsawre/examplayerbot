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
      text: '📄 Generating your official PDF document... Kripya 2 second wait karein!',
    });
  }

  const waitMsg = await ctx.reply('⏳ *Generating your PDF Document...*\n_Ham aapka high-resolution Scorecard & Solutions PDF taiyar kar rahe hain..._', {
    parse_mode: 'Markdown',
  });

  try {
    const quiz = await getQuizById(supabase, quizId);
    if (!quiz) {
      await ctx.api.editMessageText(
        ctx.chat!.id,
        waitMsg.message_id,
        '❌ Quiz nahi mila.'
      );
      return;
    }

    const questions = await getQuestionsForQuiz(supabase, quizId);
    if (!questions || questions.length === 0) {
      await ctx.api.editMessageText(
        ctx.chat!.id,
        waitMsg.message_id,
        '❌ Is quiz me questions uplabdh nahi hain.'
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
          `📄 *Official Examplayer PDF Booklet*\n` +
          `━━━━━━━━━━━━━━━━━━━━━\n` +
          `📚 *Test:* ${quiz.title}\n` +
          `👤 *Candidate:* ${studentInfo.name}\n` +
          (result ? `🎯 *Your Score:* ${result.finalScore} / ${result.maxScore} (${result.accuracy}% Accuracy)\n` : '') +
          `❓ *Total Questions:* ${questions.length}\n\n` +
          `✨ Is PDF me sabhi questions ke correct answers aur detailed explanations shaamil hain. Revision ke liye save karein!`,
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
        '⚠️ PDF generate karne me takleef hui. Kripya thodi der baad prayas karein.'
      );
    } catch {}
  }
}
