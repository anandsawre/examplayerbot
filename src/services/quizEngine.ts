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
  result: ScoreResult,
  botUsername: string = 'Examplayer_bot'
): { text: string; keyboard: InlineKeyboard } {
  const timeFormatted = formatTime(result.timeTakenSeconds);

  let text = `🎓 *EXAMPLAYER OFFICIAL SCORECARD*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `👤 *Candidate:* ${escapeMarkdown(userName)}\n`;
  text += `📚 *Examination:* ${escapeMarkdown(quiz.title)}\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

  text += `🎯 *Total Marks Scored:* \`${result.finalScore} / ${result.maxScore}\` (${result.percentage}%)\n`;
  text += `📊 *Examination Accuracy:* \`${result.accuracy}%\`\n`;
  text += `⏱️ *Total Time Consumed:* \`${timeFormatted}\`\n\n`;

  text += `*Sectional Performance Breakdown:*\n`;
  text += `  • ✅ Correct Responses: \`${result.correctCount}\`\n`;
  text += `  • ❌ Incorrect Responses: \`${result.wrongCount}\` (Penalty: -${result.wrongCount * Number(quiz.negative_marks)})\n`;
  text += `  • ⏭️ Unattempted / Skipped: \`${result.skippedCount}\`\n\n`;

  text += `🎖️ *Evaluation Status:* ${result.remark}\n`;

  const keyboard = new InlineKeyboard()
    .url('🔄 Retake Examination', `https://t.me/${botUsername}?start=quiz_${quiz.id}`)
    .text('🏆 Merit List & Rankings', `lb:${quiz.id}`)
    .row()
    .text('📄 Download Official PDF Report & Solutions', `pdf_scorecard:${quiz.id}`)
    .row()
    .url('📋 All Examinations', `https://t.me/${botUsername}?start=quizzes`)
    .url('👤 Candidate Profile', `https://t.me/${botUsername}?start=profile`);

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
