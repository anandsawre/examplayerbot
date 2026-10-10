import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { getActiveQuizzes, getQuizById, deleteQuiz, updateQuiz } from '../db/queries';
import { isAdmin } from '../utils/admin';

function escapeMarkdown(text: string): string {
  if (!text) return '';
  return text
    .replace(/_/g, '\\_')
    .replace(/\*/g, '\\*')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]')
    .replace(/`/g, '\\`');
}

export async function handleQuizzesList(ctx: Context, supabase: SupabaseClient) {
  const quizzes = await getActiveQuizzes(supabase);

  if (!quizzes || quizzes.length === 0) {
    const text = '⚠️ Abhi koi test active nahi hai. Kripya thodi der baad check karein ya admin se contact karein.';
    const keyboard = new InlineKeyboard().text('🔙 Main Menu', 'menu_start');

    if (ctx.callbackQuery) {
      await ctx.editMessageText(text, { reply_markup: keyboard });
      await ctx.answerCallbackQuery();
    } else {
      await ctx.reply(text, { reply_markup: keyboard });
    }
    return;
  }

  let text = `📚 *AVAILABLE MOCK TESTS*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `Kripya apna manpasand mock test choose karein:\n\n`;

  const keyboard = new InlineKeyboard();

  quizzes.forEach((quiz) => {
    const badge = quiz.is_premium ? '🔒 [PREMIUM]' : '🟢 [FREE]';
    keyboard.text(`${badge} ${quiz.title}`, `view_quiz:${quiz.id}`).row();
  });

  keyboard.text('🔙 Main Menu', 'menu_start');

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

export async function handleViewQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  const quiz = await getQuizById(supabase, quizId);

  if (!quiz) {
    if (ctx.callbackQuery) {
      await ctx.answerCallbackQuery({ text: 'Quiz nahi mila!', show_alert: true });
    }
    return;
  }

  let text = `📋 *TEST OVERVIEW*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `🏷️ *Title:* ${escapeMarkdown(quiz.title)}\n`;
  text += `📂 *Category:* ${escapeMarkdown(quiz.category)}\n`;
  text += `👑 *Access:* ${quiz.is_premium ? '🔒 *Premium Pass Required*' : '🟢 *Free for All Students*'}\n`;
  if (quiz.description) text += `ℹ️ *Description:* ${escapeMarkdown(quiz.description)}\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n\n`;

  text += `📊 *Pattern Details:*\n`;
  text += `  • Total Questions: \`${quiz.total_questions}\`\n`;
  text += `  • Marks per Question: \`+${quiz.marks_per_question}\`\n`;
  text += `  • Negative Marking: \`-${quiz.negative_marks}\`\n`;
  text += `  • Time per Question: \`${quiz.time_limit_seconds}s\`\n\n`;

  text += `Ready hain? "Start Test" dabate hi first question open ho jayega!`;

  const botUsername = ctx.me.username;
  const shareUrl = `https://t.me/share/url?url=https://t.me/${botUsername}?start=quiz_${quiz.id}&text=Join%20${encodeURIComponent(quiz.title)}%20Mock%20Test%20on%20Examplayer%20Bot!`;

  const isGroup = ctx.chat?.type === 'group' || ctx.chat?.type === 'supergroup';
  const keyboard = new InlineKeyboard();

  if (isGroup) {
    keyboard
      .text('👥 Launch Group Battle Here', `launch_grp:${quiz.id}`)
      .row()
      .url('🎯 Play Solo in Bot DM', `https://t.me/${botUsername}?start=quiz_${quiz.id}`)
      .row();
  } else {
    keyboard
      .text('🚀 Start Test Now', `start_quiz:${quiz.id}`)
      .row();
  }

  keyboard
    .url('📢 Share to Channel / Group', shareUrl)
    .text('🏆 Leaderboard', `lb:${quiz.id}`)
    .row();

  // Admin Controls (Toggle Premium, Edit Quiz, Delete Quiz) - ONLY in Private Chat
  if (!isGroup && isAdmin(ctx, env)) {
    const toggleLabel = quiz.is_premium ? '🔓 Make Free' : '🔒 Make Premium';
    keyboard
      .text(toggleLabel, `toggle_prem:${quiz.id}`)
      .text('✏️ Edit Test', `edit_quiz:${quiz.id}`)
      .row()
      .text('🗑️ Delete Test', `ask_del_quiz:${quiz.id}`)
      .row();
  }

  if (!isGroup) {
    keyboard.text('🔙 All Tests', 'menu_quizzes');
  } else {
    keyboard.url('📚 Browse All Tests in Bot DM', `https://t.me/${botUsername}?start=quizzes`);
  }

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

export async function handleToggleQuizPremium(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) {
    await ctx.answerCallbackQuery({ text: '⚠️ Access Denied! Only Admin can toggle.', show_alert: true });
    return;
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) return;

  const newStatus = !quiz.is_premium;
  const { error } = await supabase.from('quizzes').update({ is_premium: newStatus }).eq('id', quizId);

  if (error) {
    console.error('Failed to toggle quiz premium in Supabase:', error);
    await ctx.answerCallbackQuery({
      text: `❌ DB Error: ${error.message}\nSupabase SQL Editor me ALTER TABLE run karein!`,
      show_alert: true,
    });
    return;
  }

  await ctx.answerCallbackQuery({
    text: `Test is now ${newStatus ? '🔒 PREMIUM' : '🟢 FREE'}!`,
  });

  return handleViewQuiz(ctx, supabase, env, quizId);
}

// ================= ADMIN: DELETE QUIZ =================

export async function handleAskDeleteQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) {
    await ctx.answerCallbackQuery({ text: '⚠️ Access Denied! Only Admin can delete.', show_alert: true });
    return;
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) return;

  const text =
    `⚠️ *DANGER ZONE: DELETE QUIZ*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `Kya aap sach me *"${escapeMarkdown(quiz.title)}"* ko delete karna chahte hain?\n\n` +
    `🚨 *Dhyan dein:* Is test ke sabhi questions aur student attempts permanently delete ho jayenge! Yeh action undo nahi kiya ja sakta.`;

  const keyboard = new InlineKeyboard()
    .text('🚨 Haan, Permanently Delete Karein', `confirm_del_quiz:${quiz.id}`)
    .row()
    .text('❌ Cancel (Wapas Jayein)', `view_quiz:${quiz.id}`);

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  }
}

export async function handleConfirmDeleteQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) {
    await ctx.answerCallbackQuery({ text: '⚠️ Access Denied!', show_alert: true });
    return;
  }

  const quiz = await getQuizById(supabase, quizId);
  const quizTitle = quiz?.title || 'Test';

  const success = await deleteQuiz(supabase, quizId);
  if (!success) {
    await ctx.answerCallbackQuery({ text: '❌ Delete karne me error aayi.', show_alert: true });
    return;
  }

  await ctx.answerCallbackQuery({ text: `🗑️ "${quizTitle}" delete ho gaya!`, show_alert: true });
  return handleQuizzesList(ctx, supabase);
}

// ================= ADMIN: EDIT QUIZ PANEL =================

export async function handleEditQuizPanel(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) {
    await ctx.answerCallbackQuery({ text: '⚠️ Access Denied!', show_alert: true });
    return;
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) return;

  const text =
    `⚙️ *QUIZ SETTINGS EDITOR*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Title:* ${escapeMarkdown(quiz.title)}\n` +
    `📂 *Category:* ${escapeMarkdown(quiz.category)}\n` +
    `⏱️ *Time Limit:* \`${quiz.time_limit_seconds}s\` per question\n` +
    `🎯 *Marks Scheme:* \`+${quiz.marks_per_question}\` / \`-${quiz.negative_marks}\`\n` +
    `👑 *Access:* ${quiz.is_premium ? '🔒 Premium' : '🟢 Free'}\n` +
    `🆔 *Quiz ID:* \`${quiz.id}\`\n\n` +
    `Neeche button select karke setting change karein:`;

  const keyboard = new InlineKeyboard()
    .text('⏱️ Change Timer', `ed_timer_opt:${quiz.id}`)
    .text('🎯 Change Marks', `ed_marks_opt:${quiz.id}`)
    .row()
    .text('🏷️ Rename Title', `ed_title_prompt:${quiz.id}`)
    .text('📂 Change Category', `ed_cat_prompt:${quiz.id}`)
    .row()
    .text('🔙 Back to Test', `view_quiz:${quiz.id}`);

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  }
}

export async function handleEditTimerOptions(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) return;

  const text = `⏱️ *Naya Question Timer Select Karein:*\n\nHar question ke liye kitna time dena hai?`;
  const keyboard = new InlineKeyboard()
    .text('15s', `set_q_time:${quizId}:15`)
    .text('20s', `set_q_time:${quizId}:20`)
    .text('30s', `set_q_time:${quizId}:30`)
    .row()
    .text('45s', `set_q_time:${quizId}:45`)
    .text('60s', `set_q_time:${quizId}:60`)
    .text('90s', `set_q_time:${quizId}:90`)
    .row()
    .text('🔙 Cancel', `edit_quiz:${quizId}`);

  await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  await ctx.answerCallbackQuery();
}

export async function handleSetQuizTimer(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string,
  seconds: number
) {
  if (!isAdmin(ctx, env)) return;

  await updateQuiz(supabase, quizId, { time_limit_seconds: seconds });
  await ctx.answerCallbackQuery({ text: `⏱️ Timer ${seconds}s set ho gaya!` });
  return handleEditQuizPanel(ctx, supabase, env, quizId);
}

export async function handleEditMarksOptions(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) return;

  const text =
    `🎯 *Marking Scheme Select Karein:*\n\n` +
    `Har correct question ke marks aur negative penalty chunein:`;

  const keyboard = new InlineKeyboard()
    .text('+1 Marks (0 Penalty)', `set_q_marks:${quizId}:1:0`)
    .text('+1 Marks (-0.25)', `set_q_marks:${quizId}:1:0.25`)
    .row()
    .text('+2 Marks (-0.5)', `set_q_marks:${quizId}:2:0.5`)
    .text('+2 Marks (-0.66)', `set_q_marks:${quizId}:2:0.66`)
    .row()
    .text('+4 Marks (-1.0)', `set_q_marks:${quizId}:4:1`)
    .text('+2 Marks (0 Penalty)', `set_q_marks:${quizId}:2:0`)
    .row()
    .text('🔙 Cancel', `edit_quiz:${quizId}`);

  await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  await ctx.answerCallbackQuery();
}

export async function handleSetQuizMarks(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string,
  marks: number,
  neg: number
) {
  if (!isAdmin(ctx, env)) return;

  await updateQuiz(supabase, quizId, { marks_per_question: marks, negative_marks: neg });
  await ctx.answerCallbackQuery({ text: `🎯 Marking +${marks} / -${neg} set ho gayi!` });
  return handleEditQuizPanel(ctx, supabase, env, quizId);
}

export async function handleEditTitlePrompt(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) return;
  const quiz = await getQuizById(supabase, quizId);

  const text =
    `🏷️ *RENAME QUIZ TITLE*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `Current Title: *${escapeMarkdown(quiz?.title || '')}*\n\n` +
    `Naya title set karne ke liye type kijiye:\n` +
    `\`/edittitle ${quizId} Aapka Naya Test Title\``;

  const keyboard = new InlineKeyboard().text('🔙 Back to Editor', `edit_quiz:${quizId}`);
  await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  await ctx.answerCallbackQuery();
}

export async function handleEditCategoryPrompt(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) return;
  const quiz = await getQuizById(supabase, quizId);

  const text =
    `📂 *CHANGE QUIZ CATEGORY*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `Current Category: *${escapeMarkdown(quiz?.category || '')}*\n\n` +
    `Nayi category set karne ke liye type kijiye:\n` +
    `\`/editcat ${quizId} Nayi Category Name\``;

  const keyboard = new InlineKeyboard().text('🔙 Back to Editor', `edit_quiz:${quizId}`);
  await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  await ctx.answerCallbackQuery();
}

// ================= ADMIN: COMMAND HANDLERS =================

export async function handleEditTitleCommand(ctx: Context, supabase: SupabaseClient, env: Env) {
  if (!isAdmin(ctx, env)) return;

  const text = ctx.message?.text || '';
  const parts = text.split(' ');
  if (parts.length < 3) {
    await ctx.reply('⚠️ Format: `/edittitle <quiz_id> <Naya Title>`', { parse_mode: 'Markdown' });
    return;
  }

  const quizId = parts[1];
  const newTitle = parts.slice(2).join(' ').trim();

  const success = await updateQuiz(supabase, quizId, { title: newTitle });
  if (!success) {
    await ctx.reply('❌ Title update karne me error aayi. Check karein ki Quiz ID sahi hai ya nahi.');
    return;
  }

  await ctx.reply(`✅ *Title Updated!* Naya title: *${escapeMarkdown(newTitle)}*`, { parse_mode: 'Markdown' });
}

export async function handleEditCategoryCommand(ctx: Context, supabase: SupabaseClient, env: Env) {
  if (!isAdmin(ctx, env)) return;

  const text = ctx.message?.text || '';
  const parts = text.split(' ');
  if (parts.length < 3) {
    await ctx.reply('⚠️ Format: `/editcat <quiz_id> <Nayi Category>`', { parse_mode: 'Markdown' });
    return;
  }

  const quizId = parts[1];
  const newCat = parts.slice(2).join(' ').trim();

  const success = await updateQuiz(supabase, quizId, { category: newCat });
  if (!success) {
    await ctx.reply('❌ Category update karne me error aayi. Check karein ki Quiz ID sahi hai ya nahi.');
    return;
  }

  await ctx.reply(`✅ *Category Updated!* Nayi Category: *${escapeMarkdown(newCat)}*`, { parse_mode: 'Markdown' });
}

export async function handleDeleteQuizCommand(ctx: Context, supabase: SupabaseClient, env: Env) {
  if (!isAdmin(ctx, env)) return;

  const text = ctx.message?.text || '';
  const parts = text.split(' ');
  if (parts.length < 2) {
    await ctx.reply('⚠️ Format: `/delquiz <quiz_id>`', { parse_mode: 'Markdown' });
    return;
  }

  const quizId = parts[1].trim();
  const success = await deleteQuiz(supabase, quizId);
  if (!success) {
    await ctx.reply('❌ Delete karne me error aayi. Quiz ID verify karein.');
    return;
  }

  await ctx.reply(`✅ Quiz \`${quizId}\` successfully delete ho gaya hai!`, { parse_mode: 'Markdown' });
}
