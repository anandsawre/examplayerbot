import { AnswerRecord, Quiz, QuizAttempt } from '../types';

export interface ScoreResult {
  totalQuestions: number;
  correctCount: number;
  wrongCount: number;
  skippedCount: number;
  finalScore: number;
  maxScore: number;
  percentage: number;
  accuracy: number;
  timeTakenSeconds: number;
  remark: string;
}

export function calculateQuizResult(
  quiz: Quiz,
  answers: AnswerRecord[],
  startedAt: string
): ScoreResult {
  const totalQuestions = answers.length;
  let correctCount = 0;
  let wrongCount = 0;
  let skippedCount = 0;

  for (const ans of answers) {
    if (ans.selected_option_index === -1) {
      skippedCount++;
    } else if (ans.is_correct) {
      correctCount++;
    } else {
      wrongCount++;
    }
  }

  const marksPerCorrect = Number(quiz.marks_per_question) || 1.0;
  const negativePerWrong = Number(quiz.negative_marks) || 0.0;

  const rawScore = (correctCount * marksPerCorrect) - (wrongCount * negativePerWrong);
  const finalScore = Math.round(Math.max(0, rawScore) * 100) / 100;
  const maxScore = totalQuestions * marksPerCorrect;

  const percentage = maxScore > 0 ? Math.round((finalScore / maxScore) * 100) : 0;
  const attemptedCount = correctCount + wrongCount;
  const accuracy = attemptedCount > 0 ? Math.round((correctCount / attemptedCount) * 100) : 0;

  const startTime = new Date(startedAt).getTime();
  const endTime = Date.now();
  const timeTakenSeconds = Math.max(1, Math.round((endTime - startTime) / 1000));

  let remark = '📚 Needs Improvement';
  if (percentage >= 90) remark = '🏆 Outstanding! Topper Level';
  else if (percentage >= 75) remark = '🌟 Excellent Performance!';
  else if (percentage >= 60) remark = '👍 Good Job! Passed';
  else if (percentage >= 40) remark = '📈 Average! Keep Practicing';

  return {
    totalQuestions,
    correctCount,
    wrongCount,
    skippedCount,
    finalScore,
    maxScore,
    percentage,
    accuracy,
    timeTakenSeconds,
    remark,
  };
}

export function formatTime(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  if (mins === 0) return `${secs}s`;
  return `${mins}m ${secs}s`;
}
