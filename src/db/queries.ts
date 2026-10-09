import { SupabaseClient } from '@supabase/supabase-js';
import { User, Quiz, Question, ActiveSession, QuizAttempt, LeaderboardEntry } from '../types';

// ================= USER QUERIES =================
export async function upsertUser(
  supabase: SupabaseClient,
  telegramUser: { id: number; first_name: string; last_name?: string; username?: string }
): Promise<User | null> {
  const { data: existingUser } = await supabase
    .from('users')
    .select('*')
    .eq('id', telegramUser.id)
    .single();

  const now = new Date().toISOString();

  if (existingUser) {
    const { data, error } = await supabase
      .from('users')
      .update({
        first_name: telegramUser.first_name,
        last_name: telegramUser.last_name || null,
        username: telegramUser.username || null,
        last_active_at: now,
      })
      .eq('id', telegramUser.id)
      .select()
      .single();

    if (error) console.error('Error updating user:', error);
    return data;
  } else {
    const { data, error } = await supabase
      .from('users')
      .insert({
        id: telegramUser.id,
        first_name: telegramUser.first_name,
        last_name: telegramUser.last_name || null,
        username: telegramUser.username || null,
        total_score: 0,
        tests_completed: 0,
        streak_days: 1,
        last_active_at: now,
      })
      .select()
      .single();

    if (error) console.error('Error inserting user:', error);
    return data;
  }
}

export async function getUser(supabase: SupabaseClient, userId: number): Promise<User | null> {
  const { data, error } = await supabase.from('users').select('*').eq('id', userId).single();
  if (error) return null;
  return data;
}

export async function setUserPremium(
  supabase: SupabaseClient,
  userId: number,
  isPremium: boolean
): Promise<boolean> {
  const { error } = await supabase
    .from('users')
    .update({ is_premium: isPremium })
    .eq('id', userId);

  if (error) {
    console.error('Error updating premium status:', error);
    return false;
  }
  return true;
}

// ================= QUIZ & QUESTION QUERIES =================
export async function getActiveQuizzes(supabase: SupabaseClient): Promise<Quiz[]> {
  const { data, error } = await supabase
    .from('quizzes')
    .select('*')
    .eq('is_active', true)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching quizzes:', error);
    return [];
  }
  return data || [];
}

export async function getQuizById(supabase: SupabaseClient, quizId: string): Promise<Quiz | null> {
  const { data, error } = await supabase.from('quizzes').select('*').eq('id', quizId).single();
  if (error) return null;
  return data;
}

export async function deleteQuiz(
  supabase: SupabaseClient,
  quizId: string
): Promise<boolean> {
  const { error } = await supabase.from('quizzes').delete().eq('id', quizId);
  if (error) {
    console.error('Error deleting quiz:', error);
    return false;
  }
  return true;
}

export async function updateQuiz(
  supabase: SupabaseClient,
  quizId: string,
  updates: Partial<Quiz>
): Promise<boolean> {
  const { error } = await supabase.from('quizzes').update(updates).eq('id', quizId);
  if (error) {
    console.error('Error updating quiz:', error);
    return false;
  }
  return true;
}

export async function getQuestionsForQuiz(
  supabase: SupabaseClient,
  quizId: string
): Promise<Question[]> {
  const { data, error } = await supabase
    .from('questions')
    .select('*')
    .eq('quiz_id', quizId)
    .order('order_index', { ascending: true });

  if (error) {
    console.error('Error fetching questions:', error);
    return [];
  }
  return data || [];
}

export async function getQuestionById(
  supabase: SupabaseClient,
  questionId: string
): Promise<Question | null> {
  const { data, error } = await supabase
    .from('questions')
    .select('*')
    .eq('id', questionId)
    .single();

  if (error) return null;
  return data;
}

// ================= SESSION MANAGEMENT (SERVERLESS) =================
export async function getActiveSession(
  supabase: SupabaseClient,
  userId: number
): Promise<ActiveSession | null> {
  const { data, error } = await supabase
    .from('active_sessions')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (error) return null;
  return data;
}

export async function createActiveSession(
  supabase: SupabaseClient,
  session: ActiveSession
): Promise<boolean> {
  const { error } = await supabase.from('active_sessions').upsert({
    user_id: session.user_id,
    quiz_id: session.quiz_id,
    current_index: session.current_index,
    question_ids: session.question_ids,
    answers: session.answers,
    started_at: session.started_at,
    updated_at: session.updated_at,
  });

  if (error) {
    console.error('Error creating active session:', error);
    return false;
  }
  return true;
}

export async function updateActiveSession(
  supabase: SupabaseClient,
  userId: number,
  currentIndex: number,
  answers: any[]
): Promise<boolean> {
  const { error } = await supabase
    .from('active_sessions')
    .update({
      current_index: currentIndex,
      answers,
      updated_at: new Date().toISOString(),
    })
    .eq('user_id', userId);

  if (error) {
    console.error('Error updating session:', error);
    return false;
  }
  return true;
}

export async function deleteActiveSession(
  supabase: SupabaseClient,
  userId: number
): Promise<boolean> {
  const { error } = await supabase.from('active_sessions').delete().eq('user_id', userId);
  if (error) {
    console.error('Error deleting session:', error);
    return false;
  }
  return true;
}

// ================= ATTEMPTS & LEADERBOARD =================
export async function recordQuizAttempt(
  supabase: SupabaseClient,
  attempt: QuizAttempt
): Promise<QuizAttempt | null> {
  // 1. Insert attempt record
  const { data, error } = await supabase
    .from('quiz_attempts')
    .insert({
      user_id: attempt.user_id,
      quiz_id: attempt.quiz_id,
      total_questions: attempt.total_questions,
      correct_count: attempt.correct_count,
      wrong_count: attempt.wrong_count,
      skipped_count: attempt.skipped_count,
      score: attempt.score,
      accuracy_percent: attempt.accuracy_percent,
      time_taken_seconds: attempt.time_taken_seconds,
    })
    .select()
    .single();

  if (error) {
    console.error('Error recording quiz attempt:', error);
    return null;
  }

  // 2. Increment user total score and tests completed
  const { data: user } = await supabase.from('users').select('total_score, tests_completed').eq('id', attempt.user_id).single();
  if (user) {
    const updatedScore = Math.max(0, Number(user.total_score || 0) + Number(attempt.score));
    const updatedTests = (user.tests_completed || 0) + 1;
    await supabase.from('users').update({
      total_score: Math.round(updatedScore * 100) / 100,
      tests_completed: updatedTests,
    }).eq('id', attempt.user_id);
  }

  return data;
}

export async function getQuizLeaderboard(
  supabase: SupabaseClient,
  quizId: string,
  limit = 10
): Promise<LeaderboardEntry[]> {
  const { data, error } = await supabase
    .from('quiz_attempts')
    .select(`
      user_id,
      score,
      accuracy_percent,
      time_taken_seconds,
      users:user_id ( first_name, username )
    `)
    .eq('quiz_id', quizId)
    .order('score', { ascending: false })
    .order('time_taken_seconds', { ascending: true })
    .limit(limit);

  if (error || !data) return [];

  return data.map((item: any) => ({
    user_id: item.user_id,
    first_name: item.users?.first_name || 'Anonymous',
    username: item.users?.username,
    score: item.score,
    accuracy_percent: item.accuracy_percent,
    time_taken_seconds: item.time_taken_seconds,
  }));
}

export async function getGlobalLeaderboard(
  supabase: SupabaseClient,
  limit = 10
): Promise<LeaderboardEntry[]> {
  const { data, error } = await supabase
    .from('users')
    .select('id, first_name, username, total_score')
    .order('total_score', { ascending: false })
    .limit(limit);

  if (error || !data) return [];

  return data.map((user: any) => ({
    user_id: user.id,
    first_name: user.first_name || 'Anonymous',
    username: user.username,
    score: user.total_score,
  }));
}

// ================= AUTHORIZED GROUPS =================
export async function isGroupAuthorized(
  supabase: SupabaseClient,
  groupId: number
): Promise<boolean> {
  const { data, error } = await supabase
    .from('authorized_groups')
    .select('is_active')
    .eq('group_id', groupId)
    .single();

  if (error || !data) return false;
  return data.is_active === true;
}

export async function authorizeGroup(
  supabase: SupabaseClient,
  groupId: number,
  groupTitle: string,
  authorizedBy?: number
): Promise<boolean> {
  const { error } = await supabase
    .from('authorized_groups')
    .upsert({
      group_id: groupId,
      group_title: groupTitle,
      is_active: true,
      authorized_by: authorizedBy || null,
      updated_at: new Date().toISOString(),
    });

  if (error) {
    console.error('Error authorizing group:', error);
    return false;
  }
  return true;
}

export async function revokeGroup(
  supabase: SupabaseClient,
  groupId: number
): Promise<boolean> {
  const { error } = await supabase
    .from('authorized_groups')
    .update({
      is_active: false,
      updated_at: new Date().toISOString(),
    })
    .eq('group_id', groupId);

  if (error) {
    console.error('Error revoking group:', error);
    return false;
  }
  return true;
}

export async function getAuthorizedGroups(supabase: SupabaseClient): Promise<any[]> {
  const { data, error } = await supabase
    .from('authorized_groups')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) return [];
  return data || [];
}

// ================= DYNAMIC BOT SETTINGS =================
export async function getSetting(
  supabase: SupabaseClient,
  key: string,
  fallback = ''
): Promise<string> {
  const { data, error } = await supabase
    .from('bot_settings')
    .select('value')
    .eq('key', key)
    .single();

  if (error || !data) return fallback;
  return data.value;
}

export async function setSetting(
  supabase: SupabaseClient,
  key: string,
  value: string
): Promise<boolean> {
  const { error } = await supabase
    .from('bot_settings')
    .upsert({
      key,
      value,
      updated_at: new Date().toISOString(),
    });

  if (error) {
    console.error(`Error saving setting ${key}:`, error);
    return false;
  }
  return true;
}

export async function getAllSettings(supabase: SupabaseClient): Promise<Record<string, string>> {
  const { data, error } = await supabase.from('bot_settings').select('*');
  if (error || !data) return {};

  const map: Record<string, string> = {};
  data.forEach((item: any) => {
    map[item.key] = item.value;
  });
  return map;
}
