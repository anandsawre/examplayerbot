import http from 'node:http';
import { SupabaseClient } from '@supabase/supabase-js';
import { Bot } from 'grammy';
import { Env } from '../config';
import {
  getActiveQuizzes,
  getQuizById,
  deleteQuiz,
  getQuestionsForQuiz,
  getAllFolders,
  createFolder,
  updateFolder,
  deleteFolder,
  getSetting,
  setSetting,
  getUser,
  setUserPremium,
  getAuthorizedGroups,
  authorizeGroup,
  revokeGroup,
  getGlobalLeaderboard,
  getQuizLeaderboard,
} from '../db/queries';
import {
  getRootAdmins,
  getAppointedAdmins,
  addAppointedAdmin,
  removeAppointedAdmin,
  syncAdminCache,
} from '../utils/admin';
import { executeGroupQuizBattle, activeGroupBattles } from '../handlers/groupQuiz';
import {
  registerGroupScheduleDirect,
  cancelGroupSchedule,
  scheduledGroupQuizzes,
  formatISTTime,
  parseIndianDateTime,
} from '../handlers/groupSchedule';

// Simple in-memory session token tracking
const validTokens: Set<string> = new Set();

// In-memory OTP storage for Telegram 2FA
interface OtpRecord {
  code: string;
  expiresAt: number;
  attempts: number;
}
const otpStore: Map<string, OtpRecord> = new Map();

function parseJsonBody(req: http.IncomingMessage): Promise<any> {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 5 * 1024 * 1024) {
        reject(new Error('Payload too large'));
      }
    });
    req.on('end', () => {
      if (!body) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

function sendJson(res: http.ServerResponse, status: number, data: any) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-admin-key',
  });
  res.end(JSON.stringify(data));
}

function verifyAuth(req: http.IncomingMessage, env: Env): boolean {
  const authHeader = req.headers['authorization'] || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (token && validTokens.has(token)) return true;

  // Also allow passing secret key directly
  const secret = req.headers['x-admin-key'] as string;
  if (secret && isMasterSecret(secret, env)) return true;

  return false;
}

function isMasterSecret(input: string, env: Env): boolean {
  if (!input) return false;
  const trimmed = input.trim();
  const configuredPassword = process.env.ADMIN_PASSWORD || 'ExamPlayer@Admin2026';
  return trimmed === configuredPassword.trim();
}

export async function handleAdminApiRequest(
  req: http.IncomingMessage,
  res: http.ServerResponse,
  supabase: SupabaseClient,
  bot: Bot,
  env: Env
): Promise<boolean> {
  const urlObj = new URL(req.url || '/', 'http://localhost');
  const path = urlObj.pathname.replace(/\/$/, '');
  const method = req.method?.toUpperCase() || 'GET';

  // Preflight CORS
  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-admin-key',
    });
    res.end();
    return true;
  }

  if (!path.startsWith('/api/admin')) {
    return false;
  }

  // 1A. REQUEST TELEGRAM OTP ENDPOINT
  if (path === '/api/admin/auth/request-otp' && method === 'POST') {
    try {
      const body = await parseJsonBody(req);
      const idStr = String(body.userId || '').trim();
      if (!idStr || isNaN(Number(idStr))) {
        sendJson(res, 400, { success: false, error: 'Please enter a valid numerical Telegram User ID.' });
        return true;
      }

      await syncAdminCache(supabase);
      const rootAdmins = getRootAdmins(env);
      const appointedAdmins = getAppointedAdmins();
      const allAdmins = [...rootAdmins, ...appointedAdmins];

      if (!allAdmins.includes(idStr)) {
        sendJson(res, 403, {
          success: false,
          error: 'Access Denied: Telegram ID ' + idStr + ' is not registered as an administrator.',
        });
        return true;
      }

      // Rate limit check: 30 seconds
      const existing = otpStore.get(idStr);
      if (existing && Date.now() < existing.expiresAt - 4.5 * 60 * 1000) {
        sendJson(res, 429, {
          success: false,
          error: 'Please wait 30 seconds before requesting another code.',
        });
        return true;
      }

      const code = Math.floor(100000 + Math.random() * 900000).toString();
      otpStore.set(idStr, {
        code,
        expiresAt: Date.now() + 5 * 60 * 1000,
        attempts: 0,
      });

      const otpMsg =
        `🔐 *EXAMPLAYER ADMIN PORTAL LOGIN*\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `A login verification request was initiated for your administrator account.\n\n` +
        `Your 6-Digit One-Time Security Code (OTP) is:\n\n` +
        `👉 *${code}*\n\n` +
        `⏱️ *Validity:* 5 Minutes\n` +
        `⚠️ *Security Notice:* Never share this code with anyone. If you did not initiate this request, your account is secure — just ignore this alert.`;

      try {
        await bot.api.sendMessage(Number(idStr), otpMsg, { parse_mode: 'Markdown' });
      } catch (tgErr: any) {
        console.error('Failed to send Telegram OTP:', tgErr);
        sendJson(res, 500, {
          success: false,
          error: 'Could not deliver message to Telegram. Make sure you have started the bot (/start) in Telegram.',
        });
        return true;
      }

      sendJson(res, 200, {
        success: true,
        message: 'Security code dispatched to your Telegram private chat! 📲',
      });
      return true;
    } catch (err: any) {
      sendJson(res, 400, { success: false, error: err?.message || 'Failed to request OTP.' });
      return true;
    }
  }

  // 1B. LOGIN VERIFICATION ENDPOINT (OTP or Password)
  if (path === '/api/admin/auth/login' && method === 'POST') {
    try {
      const body = await parseJsonBody(req);
      const { type, password, key, userId, otp } = body;

      // Option 1: TELEGRAM OTP LOGIN
      if (type === 'otp' || (userId && otp)) {
        const idStr = String(userId || '').trim();
        const codeInput = String(otp || '').trim();
        const record = otpStore.get(idStr);

        if (!record) {
          sendJson(res, 400, {
            success: false,
            error: 'No active OTP found. Please request a new security code.',
          });
          return true;
        }

        if (Date.now() > record.expiresAt) {
          otpStore.delete(idStr);
          sendJson(res, 400, {
            success: false,
            error: 'Security code has expired. Please request a fresh OTP.',
          });
          return true;
        }

        if (record.attempts >= 5) {
          otpStore.delete(idStr);
          sendJson(res, 429, {
            success: false,
            error: 'Too many incorrect attempts. Please request a new security code.',
          });
          return true;
        }

        if (codeInput !== record.code) {
          record.attempts++;
          sendJson(res, 401, {
            success: false,
            error: 'Incorrect OTP code. Please check your Telegram message and try again.',
          });
          return true;
        }

        // OTP Verified successfully!
        otpStore.delete(idStr);
        const token = `adm_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
        validTokens.add(token);
        sendJson(res, 200, {
          success: true,
          token,
          method: 'telegram_otp',
          message: 'Authenticated via Telegram 2FA',
        });
        return true;
      }

      // Option 2: MASTER PASSWORD LOGIN
      const passInput = (password || key || '').trim();
      if (passInput && isMasterSecret(passInput, env)) {
        const token = `adm_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
        validTokens.add(token);
        sendJson(res, 200, {
          success: true,
          token,
          method: 'password',
          message: 'Authenticated via Master Password',
        });
        return true;
      }

      sendJson(res, 401, {
        success: false,
        error: 'Authentication failed. Please verify your OTP code or Master Password.',
      });
      return true;
    } catch {
      sendJson(res, 400, { success: false, error: 'Malformed JSON payload.' });
      return true;
    }
  }

  // Authenticate all other /api/admin endpoints
  if (!verifyAuth(req, env)) {
    sendJson(res, 401, { success: false, error: 'Unauthorized: Valid admin token required.' });
    return true;
  }

  try {
    // 2. DASHBOARD KPI STATS
    if (path === '/api/admin/stats' && method === 'GET') {
      const { count: usersCount } = await supabase.from('users').select('*', { count: 'exact', head: true });
      const { count: premiumCount } = await supabase.from('users').select('*', { count: 'exact', head: true }).eq('is_premium', true);
      const { count: quizzesCount } = await supabase.from('quizzes').select('*', { count: 'exact', head: true });
      const { count: questionsCount } = await supabase.from('questions').select('*', { count: 'exact', head: true });
      const { count: attemptsCount } = await supabase.from('quiz_attempts').select('*', { count: 'exact', head: true });
      const { count: groupsCount } = await supabase.from('authorized_groups').select('*', { count: 'exact', head: true }).eq('is_active', true);
      const folders = await getAllFolders(supabase);
      await syncAdminCache(supabase);
      const rootAdmins = getRootAdmins(env);
      const appointedAdmins = getAppointedAdmins();

      sendJson(res, 200, {
        success: true,
        stats: {
          totalUsers: usersCount || 0,
          premiumUsers: premiumCount || 0,
          totalQuizzes: quizzesCount || 0,
          totalQuestions: questionsCount || 0,
          totalAttempts: attemptsCount || 0,
          totalFolders: folders.length,
          totalAdmins: rootAdmins.length + appointedAdmins.length,
          authorizedGroups: groupsCount || 0,
        },
      });
      return true;
    }

    // 3. FOLDERS MANAGEMENT
    if (path === '/api/admin/folders') {
      if (method === 'GET') {
        const folders = await getAllFolders(supabase);
        const quizzes = await getActiveQuizzes(supabase);
        // Map quiz counts
        const foldersWithCounts = folders.map((f) => ({
          ...f,
          quizCount: quizzes.filter((q) => q.folder_id === f.id).length,
        }));
        sendJson(res, 200, { success: true, folders: foldersWithCounts });
        return true;
      }
      if (method === 'POST') {
        const body = await parseJsonBody(req);
        if (!body.name || !body.name.trim()) {
          sendJson(res, 400, { success: false, error: 'Folder name is required.' });
          return true;
        }
        const created = await createFolder(supabase, body.name.trim(), body.parentId || null);
        sendJson(res, 200, { success: true, folder: created });
        return true;
      }
    }

    if (path.startsWith('/api/admin/folders/')) {
      const folderId = path.replace('/api/admin/folders/', '');
      if (method === 'PUT') {
        const body = await parseJsonBody(req);
        if (!body.name) {
          sendJson(res, 400, { success: false, error: 'New folder name is required.' });
          return true;
        }
        const ok = await updateFolder(supabase, folderId, body.name);
        sendJson(res, 200, { success: ok });
        return true;
      }
      if (method === 'DELETE') {
        const ok = await deleteFolder(supabase, folderId);
        sendJson(res, 200, { success: ok });
        return true;
      }
    }

    // 4. QUIZZES MANAGEMENT
    if (path === '/api/admin/quizzes') {
      if (method === 'GET') {
        const quizzes = await getActiveQuizzes(supabase);
        const folders = await getAllFolders(supabase);
        const folderMap = new Map(folders.map((f) => [f.id, f.name]));
        const enriched = quizzes.map((q) => ({
          ...q,
          folder_name: q.folder_id ? folderMap.get(q.folder_id) || 'Unknown Folder' : 'Root Directory',
        }));
        sendJson(res, 200, { success: true, quizzes: enriched });
        return true;
      }
      if (method === 'POST') {
        const body = await parseJsonBody(req);
        if (!body.title) {
          sendJson(res, 400, { success: false, error: 'Quiz title is required.' });
          return true;
        }
        const { data, error } = await supabase
          .from('quizzes')
          .insert({
            title: body.title.trim(),
            category: body.category || 'General',
            description: body.description || '',
            total_questions: Number(body.total_questions) || 0,
            marks_per_question: Number(body.marks_per_question) || 2.0,
            negative_marks: Number(body.negative_marks) || 0.5,
            time_limit_seconds: Number(body.time_limit_seconds) || 30,
            is_active: true,
            is_premium: Boolean(body.is_premium),
            folder_id: body.folder_id || null,
          })
          .select()
          .single();

        if (error) {
          sendJson(res, 500, { success: false, error: error.message });
          return true;
        }
        sendJson(res, 200, { success: true, quiz: data });
        return true;
      }
    }

    if (path.startsWith('/api/admin/quizzes/')) {
      const rest = path.replace('/api/admin/quizzes/', '');
      const parts = rest.split('/');
      const quizId = parts[0];

      if (parts.length === 1 && method === 'DELETE') {
        const ok = await deleteQuiz(supabase, quizId);
        sendJson(res, 200, { success: ok });
        return true;
      }
      if (parts.length === 1 && method === 'PUT') {
        const body = await parseJsonBody(req);
        const updateData: any = {};
        if (body.title !== undefined) updateData.title = body.title.trim();
        if (body.category !== undefined) updateData.category = body.category.trim();
        if (body.description !== undefined) updateData.description = body.description.trim();
        if (body.folder_id !== undefined) updateData.folder_id = body.folder_id || null;
        if (body.marks_per_question !== undefined) updateData.marks_per_question = Number(body.marks_per_question);
        if (body.negative_marks !== undefined) updateData.negative_marks = Number(body.negative_marks);
        if (body.time_limit_seconds !== undefined) updateData.time_limit_seconds = Number(body.time_limit_seconds);
        if (body.is_premium !== undefined) updateData.is_premium = Boolean(body.is_premium);

        const { data, error } = await supabase
          .from('quizzes')
          .update(updateData)
          .eq('id', quizId)
          .select()
          .single();

        if (error) {
          sendJson(res, 500, { success: false, error: error.message });
          return true;
        }
        sendJson(res, 200, { success: true, quiz: data });
        return true;
      }

      if (parts[1] === 'questions') {
        if (method === 'GET') {
          const questions = await getQuestionsForQuiz(supabase, quizId);
          sendJson(res, 200, { success: true, questions });
          return true;
        }
        if (method === 'POST') {
          const body = await parseJsonBody(req);
          if (!body.question_text || !Array.isArray(body.options)) {
            sendJson(res, 400, { success: false, error: 'question_text and options array required.' });
            return true;
          }
          const { data, error } = await supabase
            .from('questions')
            .insert({
              quiz_id: quizId,
              question_text: body.question_text,
              options: body.options,
              correct_option_index: Number(body.correct_option_index) || 0,
              explanation: body.explanation || null,
              order_index: Number(body.order_index) || 1,
            })
            .select()
            .single();

          if (error) {
            sendJson(res, 500, { success: false, error: error.message });
            return true;
          }

          // Update quiz total_questions count
          const currentQuestions = await getQuestionsForQuiz(supabase, quizId);
          await supabase
            .from('quizzes')
            .update({ total_questions: currentQuestions.length })
            .eq('id', quizId);

          sendJson(res, 200, { success: true, question: data });
          return true;
        }
      }
    }

    // Question update and deletion
    if (path.startsWith('/api/admin/questions/')) {
      const questionId = path.replace('/api/admin/questions/', '');
      if (method === 'DELETE') {
        const { error } = await supabase.from('questions').delete().eq('id', questionId);
        if (error) {
          sendJson(res, 500, { success: false, error: error.message });
          return true;
        }
        sendJson(res, 200, { success: true });
        return true;
      }
      if (method === 'PUT') {
        const body = await parseJsonBody(req);
        const updateData: any = {};
        if (body.question_text !== undefined) updateData.question_text = body.question_text.trim();
        if (body.options !== undefined && Array.isArray(body.options)) updateData.options = body.options;
        if (body.correct_option_index !== undefined) updateData.correct_option_index = Number(body.correct_option_index);
        if (body.explanation !== undefined) updateData.explanation = body.explanation ? body.explanation.trim() : null;

        const { data, error } = await supabase
          .from('questions')
          .update(updateData)
          .eq('id', questionId)
          .select()
          .single();

        if (error) {
          sendJson(res, 500, { success: false, error: error.message });
          return true;
        }
        sendJson(res, 200, { success: true, question: data });
        return true;
      }
    }

    // 5. BULK JSON IMPORT DIRECTLY FROM UI
    if (path === '/api/admin/quizzes/import' && method === 'POST') {
      const payload = await parseJsonBody(req);
      if (!payload.title || !Array.isArray(payload.questions) || payload.questions.length === 0) {
        sendJson(res, 400, {
          success: false,
          error: 'Invalid schema. Payload must have "title" and a non-empty "questions" array.',
        });
        return true;
      }

      // 1. Insert Quiz
      const { data: quiz, error: quizError } = await supabase
        .from('quizzes')
        .insert({
          title: payload.title.trim(),
          category: payload.category || 'General',
          description: payload.description || '',
          total_questions: payload.questions.length,
          marks_per_question: Number(payload.marks_per_question) || 2.0,
          negative_marks: Number(payload.negative_marks) || 0.5,
          time_limit_seconds: Number(payload.time_limit_seconds) || 30,
          is_active: true,
          is_premium: Boolean(payload.is_premium),
          folder_id: payload.folder_id || null,
        })
        .select()
        .single();

      if (quizError || !quiz) {
        sendJson(res, 500, { success: false, error: quizError?.message || 'Failed to create quiz.' });
        return true;
      }

      // 2. Insert Questions
      const questionsToInsert = payload.questions.map((q: any, idx: number) => ({
        quiz_id: quiz.id,
        question_text: q.question_text,
        options: q.options,
        correct_option_index: Number(q.correct_option_index) || 0,
        explanation: q.explanation || null,
        order_index: idx + 1,
      }));

      const { error: questionsError } = await supabase.from('questions').insert(questionsToInsert);
      if (questionsError) {
        sendJson(res, 500, { success: false, error: questionsError.message });
        return true;
      }

      sendJson(res, 200, { success: true, quiz, count: questionsToInsert.length });
      return true;
    }

    // 6. USERS / STUDENTS MANAGEMENT
    if (path === '/api/admin/users') {
      if (method === 'GET') {
        const query = (urlObj.searchParams.get('q') || '').trim();
        const tier = urlObj.searchParams.get('tier') || '';
        let dbQuery = supabase.from('users').select('*').order('last_active_at', { ascending: false }).limit(100);
        if (query) {
          const isNum = !isNaN(Number(query));
          if (isNum) {
            dbQuery = dbQuery.or(`id.eq.${Number(query)},first_name.ilike.%${query}%,username.ilike.%${query}%`);
          } else {
            dbQuery = dbQuery.or(`first_name.ilike.%${query}%,username.ilike.%${query}%`);
          }
        }
        if (tier === 'premium') {
          dbQuery = dbQuery.eq('is_premium', true);
        } else if (tier === 'free') {
          dbQuery = dbQuery.eq('is_premium', false);
        }
        const { data, error } = await dbQuery;
        if (error) {
          sendJson(res, 500, { success: false, error: error.message });
          return true;
        }
        sendJson(res, 200, { success: true, users: data || [] });
        return true;
      }
    }

    if (path.startsWith('/api/admin/users/') && path.endsWith('/toggle-premium') && method === 'POST') {
      const parts = path.split('/');
      const userId = Number(parts[4]);
      const body = await parseJsonBody(req);
      const isPremium = Boolean(body.is_premium);
      const ok = await setUserPremium(supabase, userId, isPremium);

      if (ok && isPremium) {
        try {
          await bot.api.sendMessage(
            userId,
            `🎉 *BADHAI HO! PREMIUM PASS ACTIVATED!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
            `Aapka payment verify ho chuka hai aur sabhi tests unlock ho gaye hain! 🚀\n\n` +
            `Abhi /quizzes me jaiye aur full mock tests practice shuru kijiye!`,
            { parse_mode: 'Markdown' }
          );
        } catch (notifyErr) {
          console.warn(`Could not send premium activation Telegram message to user ${userId}:`, notifyErr);
        }
      }

      sendJson(res, 200, { success: ok, userId, is_premium: isPremium });
      return true;
    }

    // 7. ADMINISTRATORS MANAGEMENT
    if (path === '/api/admin/admins') {
      if (method === 'GET') {
        await syncAdminCache(supabase);
        const rootAdmins = getRootAdmins(env);
        const appointedAdmins = getAppointedAdmins();

        const rootDetails = await Promise.all(
          rootAdmins.map(async (id) => {
            const u = await getUser(supabase, Number(id));
            return {
              id,
              name: u?.first_name ? `${u.first_name}${u.username ? ` (@${u.username})` : ''}` : 'Primary Creator',
              isRoot: true,
            };
          })
        );

        const appointedDetails = await Promise.all(
          appointedAdmins.map(async (id) => {
            const u = await getUser(supabase, Number(id));
            return {
              id,
              name: u?.first_name ? `${u.first_name}${u.username ? ` (@${u.username})` : ''}` : 'Appointed Admin',
              isRoot: false,
            };
          })
        );

        sendJson(res, 200, {
          success: true,
          admins: [...rootDetails, ...appointedDetails],
        });
        return true;
      }
    }

    if (path === '/api/admin/admins/add' && method === 'POST') {
      const body = await parseJsonBody(req);
      const targetId = String(body.userId || '').trim();
      if (!targetId || isNaN(Number(targetId))) {
        sendJson(res, 400, { success: false, error: 'Valid numerical User ID required.' });
        return true;
      }
      const ok = await addAppointedAdmin(supabase, targetId);
      sendJson(res, 200, { success: ok, userId: targetId });
      return true;
    }

    if (path === '/api/admin/admins/remove' && method === 'POST') {
      const body = await parseJsonBody(req);
      const targetId = String(body.userId || '').trim();
      const rootAdmins = getRootAdmins(env);
      if (rootAdmins.includes(targetId)) {
        sendJson(res, 403, { success: false, error: 'Cannot remove Primary Bot Owner.' });
        return true;
      }
      const ok = await removeAppointedAdmin(supabase, targetId);
      sendJson(res, 200, { success: ok, userId: targetId });
      return true;
    }

    // 8. COMMUNITY GROUPS AUTHORIZATION DESK
    if (path === '/api/admin/groups') {
      if (method === 'GET') {
        const rawGroups = await getAuthorizedGroups(supabase);
        const groups = (rawGroups || []).map((g: any) => {
          const sched = scheduledGroupQuizzes.get(g.group_id);
          const isBattleActive = activeGroupBattles.has(g.group_id);
          return {
            ...g,
            isBattleActive,
            activeSchedule: sched
              ? {
                  quizTitle: sched.quizTitle,
                  quizId: sched.quizId,
                  targetTime: sched.targetTime.toISOString(),
                  timeFormatted: formatISTTime(sched.targetTime),
                  scheduledBy: sched.scheduledBy,
                }
              : null,
          };
        });
        sendJson(res, 200, { success: true, groups });
        return true;
      }
      if (method === 'POST') {
        const body = await parseJsonBody(req);
        const groupId = Number(body.groupId);
        const groupTitle = String(body.groupTitle || 'Community Group').trim();
        if (!groupId || isNaN(groupId)) {
          sendJson(res, 400, { success: false, error: 'Valid numerical Telegram Group ID required.' });
          return true;
        }
        const ok = await authorizeGroup(supabase, groupId, groupTitle, 0);
        sendJson(res, 200, { success: ok, groupId, groupTitle });
        return true;
      }
    }

    if (path.startsWith('/api/admin/groups/')) {
      const rest = path.replace('/api/admin/groups/', '');
      const parts = rest.split('/');
      const groupId = Number(parts[0]);

      if (parts.length === 1 && method === 'DELETE') {
        const { error } = await supabase.from('authorized_groups').delete().eq('group_id', groupId);
        if (error) {
          sendJson(res, 500, { success: false, error: error.message });
          return true;
        }
        sendJson(res, 200, { success: true, groupId });
        return true;
      }

      if (parts[1] === 'toggle' && (method === 'POST' || method === 'PUT')) {
        const body = await parseJsonBody(req);
        const isActive = Boolean(body.isActive);
        let ok = false;
        if (isActive) {
          ok = await authorizeGroup(supabase, groupId, body.groupTitle || 'Community Group');
        } else {
          ok = await revokeGroup(supabase, groupId);
        }
        sendJson(res, 200, { success: ok, groupId, isActive });
        return true;
      }

      // Launch Quiz in Community Group directly from Admin Portal
      if (parts[1] === 'launch' && method === 'POST') {
        const body = await parseJsonBody(req);
        const quizId = String(body.quizId || '').trim();
        if (!quizId) {
          sendJson(res, 400, { success: false, error: 'Examination ID required to launch battle.' });
          return true;
        }

        const quiz = await getQuizById(supabase, quizId);
        if (!quiz) {
          sendJson(res, 404, { success: false, error: 'Examination not found.' });
          return true;
        }

        if (activeGroupBattles.has(groupId)) {
          sendJson(res, 400, { success: false, error: 'An active battle is already running in this group.' });
          return true;
        }

        const botUsername = process.env.BOT_USERNAME || 'Examplayer_bot';
        executeGroupQuizBattle(bot.api, supabase, groupId, quizId, botUsername).catch((err) => {
          console.error('Error executing group quiz battle from web admin:', err);
        });

        sendJson(res, 200, {
          success: true,
          groupId,
          quizTitle: quiz.title,
          message: `Live battle "${quiz.title}" launched successfully!`,
        });
        return true;
      }

      // Schedule Quiz in Community Group directly from Admin Portal
      if (parts[1] === 'schedule' && method === 'POST') {
        const body = await parseJsonBody(req);
        const quizId = String(body.quizId || '').trim();
        if (!quizId) {
          sendJson(res, 400, { success: false, error: 'Examination ID required to schedule.' });
          return true;
        }

        let delayMs = 0;
        let targetTime: Date = new Date();

        if (body.delayMinutes !== undefined && Number(body.delayMinutes) > 0) {
          const mins = Number(body.delayMinutes);
          delayMs = mins * 60 * 1000;
          targetTime = new Date(Date.now() + delayMs);
        } else if (body.timeStr) {
          const parsed = parseIndianDateTime(String(body.timeStr));
          if (!parsed) {
            sendJson(res, 400, {
              success: false,
              error: 'Could not parse target time. Try "20:00", "8:30 PM", or minutes delay like "45".',
            });
            return true;
          }
          delayMs = parsed.delayMs;
          targetTime = parsed.target;
        } else {
          sendJson(res, 400, {
            success: false,
            error: 'Specify delayMinutes (e.g. 15, 30) or timeStr (e.g. "20:00").',
          });
          return true;
        }

        if (delayMs < 30 * 1000) {
          sendJson(res, 400, { success: false, error: 'Scheduled time must be at least 1 minute into the future.' });
          return true;
        }

        const botUsername = process.env.BOT_USERNAME || 'Examplayer_bot';
        const resSched = await registerGroupScheduleDirect(
          bot.api,
          supabase,
          groupId,
          quizId,
          targetTime,
          delayMs,
          'Web Admin Console',
          botUsername
        );

        if (!resSched.success) {
          sendJson(res, 400, { success: false, error: resSched.error || 'Failed to schedule.' });
          return true;
        }

        sendJson(res, 200, {
          success: true,
          groupId,
          quizTitle: resSched.quiz?.title,
          targetTime: resSched.targetTime.toISOString(),
          timeFormatted: resSched.timeFormatted,
          dateFormatted: resSched.dateFormatted,
        });
        return true;
      }

      // Cancel Group Schedule directly from Admin Portal
      if (parts[1] === 'cancel-schedule' && method === 'POST') {
        const wasCancelled = cancelGroupSchedule(groupId);
        if (wasCancelled) {
          try {
            await bot.api.sendMessage(
              groupId,
              `🛑 *SCHEDULED SESSION CANCELLED*\n━━━━━━━━━━━━━━━━━━━━━\n` +
              `The scheduled examination battle was cancelled via the Web Administrative Operations Console.`,
              { parse_mode: 'Markdown' }
            );
          } catch {}
        }
        sendJson(res, 200, { success: true, wasCancelled, groupId });
        return true;
      }
    }

    // 8B. LEADERBOARD & MERIT DIRECTORY
    if (path === '/api/admin/leaderboard/global' && method === 'GET') {
      const { data, error } = await supabase
        .from('users')
        .select('id, first_name, username, total_score, tests_completed, streak_days, is_premium, last_active_at')
        .order('total_score', { ascending: false })
        .limit(100);

      if (error) {
        sendJson(res, 500, { success: false, error: error.message });
        return true;
      }

      sendJson(res, 200, { success: true, leaderboard: data || [] });
      return true;
    }

    if (path.startsWith('/api/admin/leaderboard/quiz/') && method === 'GET') {
      const quizId = path.replace('/api/admin/leaderboard/quiz/', '').trim();
      const quiz = await getQuizById(supabase, quizId);
      if (!quiz) {
        sendJson(res, 404, { success: false, error: 'Examination not found.' });
        return true;
      }

      const attempts = await getQuizLeaderboard(supabase, quizId, 100);
      sendJson(res, 200, { success: true, quiz, attempts });
      return true;
    }

    // 9. SETTINGS MANAGEMENT
    if (path === '/api/admin/settings') {
      if (method === 'GET') {
        const upiId = await getSetting(supabase, 'upi_id', env.UPI_ID || 'examplayer@upi');
        const price = await getSetting(supabase, 'premium_price', env.PREMIUM_PRICE || '99');
        const channel = await getSetting(supabase, 'required_channel', env.REQUIRED_CHANNEL || '');
        sendJson(res, 200, {
          success: true,
          settings: { upiId, price, channel },
        });
        return true;
      }
      if (method === 'POST') {
        const body = await parseJsonBody(req);
        if (body.upiId !== undefined) await setSetting(supabase, 'upi_id', String(body.upiId).trim());
        if (body.price !== undefined) await setSetting(supabase, 'premium_price', String(body.price).trim());
        if (body.channel !== undefined) await setSetting(supabase, 'required_channel', String(body.channel).trim());
        sendJson(res, 200, { success: true, message: 'Settings updated successfully' });
        return true;
      }
    }

    // 10. BROADCAST TOOL (MULTI-TARGET: CANDIDATES, COMMUNITY GROUPS, OR GLOBAL BLAST)
    if (path === '/api/admin/broadcast' && method === 'POST') {
      const body = await parseJsonBody(req);
      const messageText = (body.message || '').trim();
      const target = (body.target || 'users') as 'users' | 'groups' | 'all';
      if (!messageText) {
        sendJson(res, 400, { success: false, error: 'Broadcast message cannot be empty.' });
        return true;
      }

      let usersDelivered = 0;
      let groupsDelivered = 0;
      let failed = 0;
      let totalTargets = 0;

      // 1. Dispatch to Registered Students if target is 'users' or 'all'
      if (target === 'users' || target === 'all') {
        const { data: users } = await supabase.from('users').select('id');
        if (users && users.length > 0) {
          totalTargets += users.length;
          for (const u of users) {
            try {
              await bot.api.sendMessage(u.id, messageText, { parse_mode: 'Markdown' });
              usersDelivered++;
            } catch {
              failed++;
            }
            await new Promise((r) => setTimeout(r, 35));
          }
        }
      }

      // 2. Dispatch to Authorized Groups if target is 'groups' or 'all'
      if (target === 'groups' || target === 'all') {
        const { data: groups } = await supabase
          .from('authorized_groups')
          .select('group_id')
          .eq('is_active', true);
        if (groups && groups.length > 0) {
          totalTargets += groups.length;
          for (const g of groups) {
            try {
              await bot.api.sendMessage(g.group_id, messageText, { parse_mode: 'Markdown' });
              groupsDelivered++;
            } catch {
              failed++;
            }
            await new Promise((r) => setTimeout(r, 45));
          }
        }
      }

      sendJson(res, 200, {
        success: true,
        delivered: usersDelivered + groupsDelivered,
        usersDelivered,
        groupsDelivered,
        failed,
        total: totalTargets,
        target,
      });
      return true;
    }

    sendJson(res, 404, { success: false, error: 'Endpoint not found.' });
    return true;
  } catch (err: any) {
    console.error('Error handling admin API request:', err);
    sendJson(res, 500, { success: false, error: err?.message || 'Internal server error.' });
    return true;
  }
}
