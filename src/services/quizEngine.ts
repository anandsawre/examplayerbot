import { InlineKeyboard } from 'grammy';
import { Question, Quiz } from '../types';
import { ScoreResult, formatTime } from './scoring';

const OPTION_LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];

export function renderQuestionMessage(
  quiz: Quiz,
  question: Question,
  currentIndex: number,
  totalQuestions: number
): { text: string; keyboard: InlineKeyboard } {
  const options = Array.isArray(question.options) ? question.options : [];

  let text = `📖 *${escapeMarkdown(quiz.title)}*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `❓ *Question ${currentIndex + 1} of ${totalQuestions}*\n\n`;
  text += `${escapeMarkdown(question.question_text)}\n\n`;

  options.forEach((opt, idx) => {
    const letter = OPTION_LETTERS[idx] || `${idx + 1}`;
    text += `*${letter})* ${escapeMarkdown(opt)}\n`;
  });

  text += `\n⏱️ _Time per question: ${quiz.time_limit_seconds}s_ | ⚠️ _Negative: -${quiz.negative_marks}_`;

  const keyboard = new InlineKeyboard();

  // Add Option Buttons (2 per row for clean mobile look)
  for (let i = 0; i < options.length; i += 2) {
    const letter1 = OPTION_LETTERS[i];
    keyboard.text(`🔹 Option ${letter1}`, `ans:${question.id}:${i}`);

    if (i + 1 < options.length) {
      const letter2 = OPTION_LETTERS[i + 1];
      keyboard.text(`🔹 Option ${letter2}`, `ans:${question.id}:${i + 1}`);
    }
    keyboard.row();
  }

  // Row with Skip & Quit button
  keyboard.text('⏭️ Skip Question', `ans:${question.id}:-1`);
  keyboard.text('❌ Quit Test', `quit_test:${quiz.id}`);

  return { text, keyboard };
}

export function renderScorecardMessage(
  quiz: Quiz,
  userName: string,
  result: ScoreResult
): { text: string; keyboard: InlineKeyboard } {
  const timeFormatted = formatTime(result.timeTakenSeconds);

  let text = `🎓 *EXAMPLAYER OFFICIAL SCORECARD*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `👤 *Student:* ${escapeMarkdown(userName)}\n`;
  text += `📚 *Test:* ${escapeMarkdown(quiz.title)}\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n\n`;

  text += `🎯 *Total Score:* \`${result.finalScore} / ${result.maxScore}\` (${result.percentage}%)\n`;
  text += `📊 *Accuracy:* \`${result.accuracy}%\`\n`;
  text += `⏱️ *Time Taken:* \`${timeFormatted}\`\n\n`;

  text += `*Performance Breakdown:*\n`;
  text += `  • ✅ Correct: \`${result.correctCount}\`\n`;
  text += `  • ❌ Incorrect: \`${result.wrongCount}\` (Penalty: -${result.wrongCount * Number(quiz.negative_marks)})\n`;
  text += `  • ⏭️ Skipped: \`${result.skippedCount}\`\n\n`;

  text += `🎖️ *Verdict:* ${result.remark}\n`;

  const keyboard = new InlineKeyboard()
    .text('🏆 Test Leaderboard', `lb:${quiz.id}`)
    .text('🔄 Retake Test', `start_quiz:${quiz.id}`)
    .row()
    .text('📋 All Quizzes', 'menu_quizzes')
    .text('👤 My Profile', 'menu_profile');

  return { text, keyboard };
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
