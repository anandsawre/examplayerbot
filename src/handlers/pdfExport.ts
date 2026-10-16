import { Context, InputFile } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getQuizById, getQuestionsForQuiz, getUser, getUserLatestAttempt } from '../db/queries';
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
 * Handles generating and sending the official PDF Scorecard & Solutions booklet to a user.
 * Automatically routes the PDF directly to the user's personal chat (DM) if requested from a group,
 * keeping community chats clean and preventing group clutter.
 */
export async function handleDownloadPdfScorecard(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string
) {
  const userId = ctx.from?.id;
  if (!userId) return;

  const isGroup = ctx.chat?.type === 'group' || ctx.chat?.type === 'supergroup';
  let botUsername = 'Examplayer_bot';
  try {
    botUsername = ctx.me?.username || 'Examplayer_bot';
  } catch {}

  // If clicked in group, answer callback immediately so button doesn't spin
  if (ctx.callbackQuery) {
    await ctx.answerCallbackQuery({
      text: isGroup
        ? `📩 Official PDF Scorecard & Solutions aapke personal chat (@${botUsername}) me bheja ja raha hai...`
        : '📄 Compiling official examination report and solutions... Please wait.',
    }).catch(() => {});
  }

  // The PDF must ALWAYS be delivered to the user's personal chat (DM)
  const targetChatId = isGroup ? userId : ctx.chat!.id;

  let waitMsgId: number | null = null;
  if (!isGroup) {
    const waitMsg = await ctx.reply(
      '⏳ *Generating Official Examination Booklet...*\n_Compiling your high-resolution Scorecard & Solutions PDF document..._',
      { parse_mode: 'Markdown' }
    ).catch(() => null);
    if (waitMsg) waitMsgId = waitMsg.message_id;
  }

  let studentName = 'Candidate';
  try {
    const quiz = await getQuizById(supabase, quizId);
    if (!quiz) {
      if (!isGroup && waitMsgId) {
        await ctx.api.editMessageText(targetChatId, waitMsgId, '❌ Examination module not found.').catch(() => {});
      } else if (isGroup && ctx.callbackQuery) {
        await ctx.answerCallbackQuery({ text: '❌ Examination module not found.', show_alert: true }).catch(() => {});
      }
      return;
    }

    const questions = await getQuestionsForQuiz(supabase, quizId);
    if (!questions || questions.length === 0) {
      if (!isGroup && waitMsgId) {
        await ctx.api.editMessageText(targetChatId, waitMsgId, '❌ No questions recorded for this examination module.').catch(() => {});
      } else if (isGroup && ctx.callbackQuery) {
        await ctx.answerCallbackQuery({ text: '❌ No questions recorded for this examination module.', show_alert: true }).catch(() => {});
      }
      return;
    }

    const user = await getUser(supabase, userId);
    studentName = `${user?.first_name || ctx.from?.first_name || 'Student'}${user?.last_name ? ' ' + user.last_name : ''}`;
    const studentInfo: StudentInfo = {
      id: userId,
      name: studentName,
      username: user?.username || ctx.from?.username,
    };

    // 1. Check if user has a cached recent attempt with their specific score and choices
    const cached = recentUserAttempts.get(userId);
    let result: ScoreResult | undefined = undefined;
    let userAnswers: UserAnswerRecord[] | undefined = undefined;

    if (cached && cached.quizId === quizId) {
      result = cached.result;
      userAnswers = cached.answers;
    } else {
      // 2. Fallback: Query Supabase quiz_attempts for user's latest recorded score on this quiz
      const dbAttempt = await getUserLatestAttempt(supabase, userId, quizId);
      if (dbAttempt) {
        const marksPerQ = Number(quiz.marks_per_question) || 2;
        const negMarks = Number(quiz.negative_marks) || 0;
        const maxScore = (dbAttempt.total_questions || questions.length) * marksPerQ;
        const finalScore = Number(dbAttempt.score) || 0;
        const percentage = maxScore > 0 ? Math.round((finalScore / maxScore) * 100) : 0;
        const accuracy = dbAttempt.accuracy_percent ?? (
          (dbAttempt.correct_count + dbAttempt.wrong_count) > 0
            ? Math.round((dbAttempt.correct_count / (dbAttempt.correct_count + dbAttempt.wrong_count)) * 100)
            : 0
        );

        let remark = 'Completed';
        if (accuracy >= 90) remark = 'Outstanding Mastery';
        else if (accuracy >= 75) remark = 'Excellent Performance';
        else if (accuracy >= 50) remark = 'Good Attempt';
        else remark = 'Needs Thorough Revision';

        result = {
          correctCount: dbAttempt.correct_count ?? 0,
          wrongCount: dbAttempt.wrong_count ?? 0,
          skippedCount: dbAttempt.skipped_count ?? Math.max(0, questions.length - ((dbAttempt.correct_count ?? 0) + (dbAttempt.wrong_count ?? 0))),
          totalQuestions: dbAttempt.total_questions || questions.length,
          marksPerQuestion: marksPerQ,
          negativeMarksPerWrong: negMarks,
          maxScore,
          finalScore,
          accuracy,
          percentage,
          timeTakenSeconds: dbAttempt.time_taken_seconds || 0,
          remark,
        };
      }
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
    const filename = `${safeTitle}_Scorecard_Solutions.pdf`;

    const negPenaltyStr = result ? (result.wrongCount * Number(quiz.negative_marks)).toFixed(1) : '0.0';

    // Send PDF document via Telegram to targetChatId (User's Private Chat)
    await ctx.api.sendDocument(
      targetChatId,
      new InputFile(pdfBuffer, filename),
      {
        caption:
          `📄 *Official Examination Document*\n` +
          `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
          `📚 *Examination:* ${quiz.title}\n` +
          `👤 *Candidate:* ${studentInfo.name}\n` +
          (result
            ? `🎯 *Obtained Marks:* \`${result.finalScore} / ${result.maxScore}\` (${result.percentage}%)\n` +
              `✅ *Correct:* \`${result.correctCount}\` | ❌ *Wrong:* \`${result.wrongCount}\` (Penalty: \`-${negPenaltyStr}\`)\n` +
              `📊 *Accuracy:* \`${result.accuracy}%\` | 🎖️ *Evaluation:* ${result.remark}\n`
            : '') +
          `❓ *Total Questions:* \`${questions.length}\`\n\n` +
          `✨ Yeh document aapke personal chat me bheja gaya hai. Isme answer keys, candidate responses aur detailed solutions shamil hain.`,
        parse_mode: 'Markdown',
      }
    );

    // If invoked from group, notify user with confirmation alert
    if (isGroup && ctx.callbackQuery) {
      await ctx.answerCallbackQuery({
        text: `✅ Scorecard PDF aapke personal message (@${botUsername}) me bhej diya gaya hai!`,
        show_alert: true,
      }).catch(() => {});
    }

    // Delete temporary loading message in DM
    if (!isGroup && waitMsgId) {
      await ctx.api.deleteMessage(targetChatId, waitMsgId).catch(() => {});
    }
  } catch (error: any) {
    console.error('Error generating PDF scorecard:', error);

    // Handle Telegram 403: Bot cannot initiate conversation with user who hasn't started it
    const isForbidden =
      error?.error_code === 403 ||
      error?.description?.includes('bot was blocked') ||
      error?.description?.includes("can't initiate conversation") ||
      error?.message?.includes('403');

    if (isGroup && isForbidden) {
      if (ctx.callbackQuery) {
        await ctx.answerCallbackQuery({
          text: `⚠️ Kripya pehle bot ko direct message me START karein: @${botUsername}`,
          show_alert: true,
        }).catch(() => {});
      } else {
        await ctx.reply(
          `⚠️ [${studentName}](tg://user?id=${userId}), bot ko direct message me start karein taaki PDF bheja ja sake:\n👉 https://t.me/${botUsername}?start=pdf_${quizId}`,
          { parse_mode: 'Markdown' }
        ).catch(() => {});
      }
      return;
    }

    if (!isGroup && waitMsgId) {
      await ctx.api.editMessageText(
        targetChatId,
        waitMsgId,
        '⚠️ An error occurred during PDF generation. Please retry in a few moments.'
      ).catch(() => {});
    }
  }
}
