export interface User {
  id: number; // Telegram user id
  first_name: string;
  last_name?: string | null;
  username?: string | null;
  total_score: number;
  tests_completed: number;
  streak_days: number;
  is_premium?: boolean;
  longest_streak?: number;
  referrals_count?: number;
  duel_rating?: number;
  duel_wins?: number;
  duel_losses?: number;
  last_daily_date?: string | null;
  last_active_at: string;
  created_at: string;
}

export interface UserMistake {
  id?: string;
  user_id: number;
  question_id: string;
  quiz_id: string;
  wrong_count: number;
  is_resolved: boolean;
  last_attempted_at: string;
  question?: Question;
}

export interface ReferralRecord {
  id?: string;
  referrer_id: number;
  referred_id: number;
  reward_granted: boolean;
  created_at: string;
}

export interface DuelSession {
  id: string;
  chat_id: number;
  creator_id: number;
  creator_name: string;
  opponent_id?: number;
  opponent_name?: string;
  quiz_id: string;
  quiz_title?: string;
  is_dm?: boolean;
  question_ids: string[];
  questions: Question[];
  current_q_index: number;
  creator_answers: { is_correct: boolean; time_ms: number }[];
  opponent_answers: { is_correct: boolean; time_ms: number }[];
  current_poll_id?: string;
  current_poll_ids?: string[]; // for DM duels where 2 separate polls are sent to player 1 and player 2
  status: 'pending' | 'in_progress' | 'completed' | 'cancelled';
  winner_id?: number;
  created_at: string;
}

export interface QuizFolder {
  id: string;
  name: string;
  parent_id?: string | null;
  order_index?: number;
  created_at: string;
  updated_at?: string;
}

export interface Quiz {
  id: string;
  title: string;
  category: string;
  description: string;
  total_questions: number;
  marks_per_question: number;
  negative_marks: number;
  time_limit_seconds: number;
  is_active: boolean;
  is_premium?: boolean;
  folder_id?: string | null;
  created_at: string;
}

export interface Question {
  id: string;
  quiz_id: string;
  question_text: string;
  options: string[];
  correct_option_index: number;
  explanation?: string | null;
  image_url?: string | null;
  order_index: number;
  created_at: string;
}

export interface AnswerRecord {
  question_id: string;
  selected_option_index: number; // -1 if skipped
  is_correct: boolean;
  time_spent_seconds?: number;
}

export interface ActiveSession {
  user_id: number;
  quiz_id: string;
  current_index: number;
  question_ids: string[];
  answers: AnswerRecord[];
  started_at: string;
  updated_at: string;
}

export interface QuizAttempt {
  id?: string;
  user_id: number;
  quiz_id: string;
  total_questions: number;
  correct_count: number;
  wrong_count: number;
  skipped_count: number;
  score: number;
  accuracy_percent: number;
  time_taken_seconds: number;
  completed_at?: string;
}

export interface LeaderboardEntry {
  user_id: number;
  first_name: string;
  username?: string | null;
  score: number;
  accuracy_percent?: number;
  time_taken_seconds?: number;
  total_questions?: number;
  correct_count?: number;
  wrong_count?: number;
  skipped_count?: number;
}

