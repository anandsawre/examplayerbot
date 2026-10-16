import { SupabaseClient } from '@supabase/supabase-js';
import { User, Quiz, Question, ActiveSession, QuizAttempt, LeaderboardEntry, UserMistake, ReferralRecord, DuelSession, QuizFolder } from '../types';

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

export async function getUserLatestAttempt(
  supabase: SupabaseClient,
  userId: number,
  quizId: string
): Promise<QuizAttempt | null> {
  const { data, error } = await supabase
    .from('quiz_attempts')
    .select('*')
    .eq('user_id', userId)
    .eq('quiz_id', quizId)
    .order('completed_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error || !data) return null;
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
      total_questions,
      correct_count,
      wrong_count,
      skipped_count,
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
    total_questions: item.total_questions,
    correct_count: item.correct_count ?? 0,
    wrong_count: item.wrong_count ?? 0,
    skipped_count: item.skipped_count ?? 0,
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

// ================= PHASE 1A: MISTAKE VAULT & WEAK AREAS =================
const memoryMistakes: Map<string, UserMistake> = new Map(); // key: `${userId}:${questionId}`

export async function recordMistake(
  supabase: SupabaseClient,
  userId: number,
  questionId: string,
  quizId: string
): Promise<void> {
  const now = new Date().toISOString();
  try {
    const { data: existing, error } = await supabase
      .from('user_mistakes')
      .select('*')
      .eq('user_id', userId)
      .eq('question_id', questionId)
      .single();

    if (!error && existing) {
      await supabase
        .from('user_mistakes')
        .update({
          wrong_count: (existing.wrong_count || 1) + 1,
          is_resolved: false,
          last_attempted_at: now,
        })
        .eq('id', existing.id);
      return;
    } else if (!error || error.code === 'PGRST116') {
      const { error: insErr } = await supabase.from('user_mistakes').insert({
        user_id: userId,
        question_id: questionId,
        quiz_id: quizId,
        wrong_count: 1,
        is_resolved: false,
        last_attempted_at: now,
      });
      if (!insErr) return;
    }
  } catch {}

  // Resilient memory fallback
  const key = `${userId}:${questionId}`;
  const cur = memoryMistakes.get(key);
  if (cur) {
    cur.wrong_count++;
    cur.is_resolved = false;
    cur.last_attempted_at = now;
  } else {
    memoryMistakes.set(key, {
      user_id: userId,
      question_id: questionId,
      quiz_id: quizId,
      wrong_count: 1,
      is_resolved: false,
      last_attempted_at: now,
    });
  }
}

export async function resolveMistake(
  supabase: SupabaseClient,
  userId: number,
  questionId: string
): Promise<void> {
  try {
    await supabase
      .from('user_mistakes')
      .update({ is_resolved: true })
      .eq('user_id', userId)
      .eq('question_id', questionId);
  } catch {}

  const key = `${userId}:${questionId}`;
  const cur = memoryMistakes.get(key);
  if (cur) cur.is_resolved = true;
}

export async function getUserMistakes(
  supabase: SupabaseClient,
  userId: number,
  limit = 15
): Promise<{ mistake: UserMistake; question: Question }[]> {
  try {
    const { data, error } = await supabase
      .from('user_mistakes')
      .select('*, question:questions(*)')
      .eq('user_id', userId)
      .eq('is_resolved', false)
      .order('last_attempted_at', { ascending: false })
      .limit(limit);

    if (!error && data && data.length > 0) {
      const valid = data
        .filter((d: any) => d.question)
        .map((d: any) => ({
          mistake: d as UserMistake,
          question: d.question as Question,
        }));
      if (valid.length > 0) return valid;
    }
  } catch {}

  // Fallback to memory
  const results: { mistake: UserMistake; question: Question }[] = [];
  for (const m of memoryMistakes.values()) {
    if (m.user_id === userId && !m.is_resolved) {
      const q = await getQuestionById(supabase, m.question_id);
      if (q) results.push({ mistake: m, question: q });
      if (results.length >= limit) break;
    }
  }
  return results;
}

export async function getUserMistakeStats(
  supabase: SupabaseClient,
  userId: number
): Promise<{ totalUnresolved: number; totalResolved: number }> {
  try {
    const { data, error } = await supabase
      .from('user_mistakes')
      .select('is_resolved')
      .eq('user_id', userId);

    if (!error && data) {
      let unresolved = 0;
      let resolved = 0;
      for (const row of data) {
        if (row.is_resolved) resolved++;
        else unresolved++;
      }
      return { totalUnresolved: unresolved, totalResolved: resolved };
    }
  } catch {}

  let unresolved = 0;
  let resolved = 0;
  for (const m of memoryMistakes.values()) {
    if (m.user_id === userId) {
      if (m.is_resolved) resolved++;
      else unresolved++;
    }
  }
  return { totalUnresolved: unresolved, totalResolved: resolved };
}

export async function clearResolvedMistakes(
  supabase: SupabaseClient,
  userId: number
): Promise<number> {
  try {
    await supabase
      .from('user_mistakes')
      .delete()
      .eq('user_id', userId)
      .eq('is_resolved', true);
  } catch {}

  for (const [k, m] of memoryMistakes.entries()) {
    if (m.user_id === userId && m.is_resolved) {
      memoryMistakes.delete(k);
    }
  }
  return 1;
}

// ================= PHASE 1B: DAILY QUESTION & STREAKS =================
const memoryDailyAttempts: Set<string> = new Set(); // `${userId}:${date}`

export async function getDailyQuestion(supabase: SupabaseClient): Promise<Question | null> {
  const today = new Date().toISOString().slice(0, 10);
  const { data: questions } = await supabase.from('questions').select('*').limit(50);
  if (!questions || questions.length === 0) return null;

  let hash = 0;
  for (let i = 0; i < today.length; i++) {
    hash = (hash << 5) - hash + today.charCodeAt(i);
    hash |= 0;
  }
  const index = Math.abs(hash) % questions.length;
  return questions[index];
}

export async function hasAttemptedDailyToday(
  supabase: SupabaseClient,
  userId: number
): Promise<boolean> {
  const today = new Date().toISOString().slice(0, 10);
  const key = `${userId}:${today}`;
  if (memoryDailyAttempts.has(key)) return true;

  try {
    const { data } = await supabase
      .from('daily_attempts')
      .select('id')
      .eq('user_id', userId)
      .eq('attempt_date', today)
      .single();
    if (data) return true;
  } catch {}

  const user = await getUser(supabase, userId);
  return user?.last_daily_date === today;
}

export async function recordDailyAttempt(
  supabase: SupabaseClient,
  userId: number,
  questionId: string,
  isCorrect: boolean
): Promise<{ currentStreak: number; longestStreak: number; isNewStreak: boolean }> {
  const today = new Date().toISOString().slice(0, 10);
  memoryDailyAttempts.add(`${userId}:${today}`);

  try {
    await supabase.from('daily_attempts').upsert({
      user_id: userId,
      attempt_date: today,
      question_id: questionId,
      is_correct: isCorrect,
    });
  } catch {}

  const user = await getUser(supabase, userId);
  let streak = user?.streak_days || 1;
  let longest = user?.longest_streak || streak;

  if (user?.last_daily_date) {
    const lastDate = new Date(user.last_daily_date);
    const currentDate = new Date(today);
    const diffDays = Math.round((currentDate.getTime() - lastDate.getTime()) / (1000 * 3600 * 24));
    if (diffDays === 1) {
      streak += 1;
    } else if (diffDays > 1) {
      streak = 1;
    }
  } else {
    streak = 1;
  }

  if (streak > longest) longest = streak;

  try {
    await supabase.from('users').update({
      streak_days: streak,
      longest_streak: longest,
      last_daily_date: today,
    }).eq('id', userId);
  } catch {}

  return { currentStreak: streak, longestStreak: longest, isNewStreak: true };
}

// ================= PHASE 2A: REFERRAL SYSTEM =================
const memoryReferrals: Map<number, Set<number>> = new Map();

export async function processReferral(
  supabase: SupabaseClient,
  referrerId: number,
  referredId: number
): Promise<{ success: boolean; totalReferrals: number; rewardGranted: boolean }> {
  if (referrerId === referredId) {
    return { success: false, totalReferrals: 0, rewardGranted: false };
  }

  let alreadyReferred = false;
  try {
    const { data } = await supabase
      .from('referrals')
      .select('id')
      .eq('referred_id', referredId)
      .single();
    if (data) alreadyReferred = true;
  } catch {}

  const memSet = memoryReferrals.get(referrerId) || new Set();
  if (memSet.has(referredId)) alreadyReferred = true;

  if (alreadyReferred) {
    return { success: false, totalReferrals: memSet.size, rewardGranted: false };
  }

  try {
    await supabase.from('referrals').insert({
      referrer_id: referrerId,
      referred_id: referredId,
      reward_granted: true,
    });
  } catch {}

  memSet.add(referredId);
  memoryReferrals.set(referrerId, memSet);

  const referrer = await getUser(supabase, referrerId);
  const newCount = (referrer?.referrals_count || 0) + 1;
  const newScore = (referrer?.total_score || 0) + 5;
  const grantPass = newCount >= 3;

  try {
    await supabase.from('users').update({
      referrals_count: newCount,
      total_score: newScore,
      is_premium: grantPass || referrer?.is_premium,
    }).eq('id', referrerId);
  } catch {}

  return {
    success: true,
    totalReferrals: newCount,
    rewardGranted: true,
  };
}

export async function getUserReferralStats(
  supabase: SupabaseClient,
  userId: number
): Promise<{ totalReferrals: number; bonusPoints: number; isPremium: boolean }> {
  const user = await getUser(supabase, userId);
  const memSet = memoryReferrals.get(userId);
  const total = user?.referrals_count || (memSet ? memSet.size : 0);
  return {
    totalReferrals: total,
    bonusPoints: total * 5,
    isPremium: !!user?.is_premium,
  };
}

// ================= PHASE 2B: 1V1 DUELS =================
export const activeDuels: Map<string, DuelSession> = new Map();
export const duelPollToIdMap: Map<string, string> = new Map(); // pollId -> duelId

export async function createDuelSession(
  duel: DuelSession
): Promise<DuelSession> {
  activeDuels.set(duel.id, duel);
  return duel;
}

export function getDuelSession(duelId: string): DuelSession | undefined {
  return activeDuels.get(duelId);
}

export async function updateDuelUserStats(
  supabase: SupabaseClient,
  userId: number,
  isWinner: boolean
): Promise<{ newRating: number }> {
  const user = await getUser(supabase, userId);
  const curRating = user?.duel_rating || 1200;
  const wins = user?.duel_wins || 0;
  const losses = user?.duel_losses || 0;

  const delta = isWinner ? 25 : -15;
  const newRating = Math.max(800, curRating + delta);

  try {
    await supabase.from('users').update({
      duel_rating: newRating,
      duel_wins: isWinner ? wins + 1 : wins,
      duel_losses: !isWinner ? losses + 1 : losses,
    }).eq('id', userId);
  } catch {}

  return { newRating };
}

// ================= HIERARCHICAL FOLDERS & SUBFOLDERS =================
export const memoryFolders: Map<string, QuizFolder> = new Map();

export async function getFolders(
  supabase: SupabaseClient,
  parentId: string | null = null
): Promise<QuizFolder[]> {
  try {
    let query = supabase.from('quiz_folders').select('*').order('name', { ascending: true });
    if (parentId) {
      query = query.eq('parent_id', parentId);
    } else {
      query = query.is('parent_id', null);
    }
    const { data, error } = await query;
    if (!error && data) return data;
  } catch {}

  // Memory fallback
  const list: QuizFolder[] = [];
  for (const f of memoryFolders.values()) {
    if (parentId ? f.parent_id === parentId : !f.parent_id) {
      list.push(f);
    }
  }
  return list.sort((a, b) => a.name.localeCompare(b.name));
}

export async function getAllFolders(supabase: SupabaseClient): Promise<QuizFolder[]> {
  try {
    const { data, error } = await supabase
      .from('quiz_folders')
      .select('*')
      .order('name', { ascending: true });
    if (!error && data) return data;
  } catch {}

  return Array.from(memoryFolders.values()).sort((a, b) => a.name.localeCompare(b.name));
}

export async function getFolderById(
  supabase: SupabaseClient,
  folderId: string
): Promise<QuizFolder | null> {
  try {
    const { data, error } = await supabase
      .from('quiz_folders')
      .select('*')
      .eq('id', folderId)
      .single();
    if (!error && data) return data;
  } catch {}

  return memoryFolders.get(folderId) || null;
}

export async function getFolderPath(
  supabase: SupabaseClient,
  folderId: string
): Promise<QuizFolder[]> {
  const path: QuizFolder[] = [];
  let currentId: string | null = folderId;

  // Maximum depth safety: 10 levels
  let depth = 0;
  while (currentId && depth < 10) {
    const folder = await getFolderById(supabase, currentId);
    if (!folder) break;
    path.unshift(folder);
    currentId = folder.parent_id || null;
    depth++;
  }

  return path;
}

export async function createFolder(
  supabase: SupabaseClient,
  name: string,
  parentId: string | null = null
): Promise<QuizFolder | null> {
  const id = `fldr_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
  const now = new Date().toISOString();
  const folder: QuizFolder = {
    id,
    name: name.trim(),
    parent_id: parentId,
    order_index: 0,
    created_at: now,
    updated_at: now,
  };

  try {
    const { data, error } = await supabase
      .from('quiz_folders')
      .insert({
        name: folder.name,
        parent_id: folder.parent_id,
        order_index: 0,
      })
      .select()
      .single();

    if (!error && data) {
      memoryFolders.set(data.id, data);
      return data;
    }
  } catch {}

  memoryFolders.set(id, folder);
  return folder;
}

export async function updateFolder(
  supabase: SupabaseClient,
  folderId: string,
  name: string
): Promise<boolean> {
  const now = new Date().toISOString();
  try {
    const { error } = await supabase
      .from('quiz_folders')
      .update({ name: name.trim(), updated_at: now })
      .eq('id', folderId);
    if (!error) {
      const cur = memoryFolders.get(folderId);
      if (cur) {
        cur.name = name.trim();
        cur.updated_at = now;
      }
      return true;
    }
  } catch {}

  const cur = memoryFolders.get(folderId);
  if (cur) {
    cur.name = name.trim();
    cur.updated_at = now;
    return true;
  }
  return false;
}

export async function deleteFolder(
  supabase: SupabaseClient,
  folderId: string
): Promise<boolean> {
  try {
    // 1. Unassign quizzes in this folder
    await supabase.from('quizzes').update({ folder_id: null }).eq('folder_id', folderId);

    // 2. Unassign quizzes in any subfolders
    const subfolders = await getFolders(supabase, folderId);
    for (const sf of subfolders) {
      await supabase.from('quizzes').update({ folder_id: null }).eq('folder_id', sf.id);
      memoryQuizFolderMap.delete(sf.id);
      memoryFolders.delete(sf.id);
    }

    // 3. Delete folder from database
    const { error } = await supabase.from('quiz_folders').delete().eq('id', folderId);
    if (!error) {
      memoryFolders.delete(folderId);
      memoryQuizFolderMap.delete(folderId);
      return true;
    } else {
      console.error('Supabase deleteFolder error:', error);
    }
  } catch (err) {
    console.error('deleteFolder exception:', err);
  }

  memoryFolders.delete(folderId);
  memoryQuizFolderMap.delete(folderId);
  return true;
}

export const memoryQuizFolderMap: Map<string, string | null> = new Map();

export async function getQuizzesByFolder(
  supabase: SupabaseClient,
  folderId: string | null
): Promise<Quiz[]> {
  try {
    let query = supabase.from('quizzes').select('*').eq('is_active', true);
    if (folderId) {
      query = query.eq('folder_id', folderId);
    } else {
      query = query.is('folder_id', null);
    }
    const { data, error } = await query.order('created_at', { ascending: false });
    if (!error && data) {
      const merged = data.map((q) => {
        if (memoryQuizFolderMap.has(q.id)) {
          return { ...q, folder_id: memoryQuizFolderMap.get(q.id) };
        }
        return q;
      });
      return merged.filter((q) => (folderId ? q.folder_id === folderId : !q.folder_id));
    }
  } catch {}

  // Fallback: fetch all active quizzes
  const all = await getActiveQuizzes(supabase);
  const mapped = all.map((q) => {
    if (memoryQuizFolderMap.has(q.id)) {
      return { ...q, folder_id: memoryQuizFolderMap.get(q.id) };
    }
    return q;
  });

  if (folderId) {
    return mapped.filter((q) => q.folder_id === folderId);
  }
  const filtered = mapped.filter((q) => !q.folder_id);
  return filtered.length > 0 ? filtered : mapped;
}

export async function moveQuizToFolder(
  supabase: SupabaseClient,
  quizId: string,
  folderId: string | null
): Promise<boolean> {
  memoryQuizFolderMap.set(quizId, folderId);
  try {
    const { error } = await supabase
      .from('quizzes')
      .update({ folder_id: folderId })
      .eq('id', quizId);
    if (!error) return true;
  } catch {}
  return true;
}


