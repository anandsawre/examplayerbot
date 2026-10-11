import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import {
  getActiveQuizzes,
  getQuizById,
  deleteQuiz,
  updateQuiz,
  getFolders,
  getAllFolders,
  getFolderById,
  getFolderPath,
  getQuizzesByFolder,
} from '../db/queries';
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

export async function handleQuizzesList(
  ctx: Context,
  supabase: SupabaseClient,
  folderId?: string | null
) {
  const adminMode = isAdmin(ctx);

  if (folderId) {
    // INSIDE A FOLDER / SUBFOLDER
    const currentFolder = await getFolderById(supabase, folderId);
    if (!currentFolder) {
      return handleQuizzesList(ctx, supabase, null);
    }

    const breadcrumbs = await getFolderPath(supabase, folderId);
    const breadcrumbStr = breadcrumbs.map((b) => b.name).join(' ➔ ');
    const subFolders = await getFolders(supabase, folderId);
    const quizzes = await getQuizzesByFolder(supabase, folderId);

    let text = `📂 *DIRECTORY: ${escapeMarkdown(breadcrumbStr)}*\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `📁 *Subfolders:* ${subFolders.length} | 📝 *Examination Papers:* ${quizzes.length}\n\n`;

    const keyboard = new InlineKeyboard();

    // 1. Subfolders
    subFolders.forEach((sf) => {
      keyboard.text(`📁 ${sf.name}`, `fldr:${sf.id}`).row();
    });

    // 2. Quizzes inside this folder
    quizzes.forEach((quiz) => {
      const badge = quiz.is_premium ? '🔒 [PREMIUM]' : '🟢 [FREE]';
      keyboard.text(`${badge} ${quiz.title}`, `view_quiz:${quiz.id}`).row();
    });

    if (adminMode) {
      keyboard
        .text('➕ New Subfolder', `fldr_new:${folderId}`)
        .text('✏️ Rename', `fldr_ren:${folderId}`)
        .text('🗑️ Delete', `fldr_del:${folderId}`)
        .row()
        .text('📥 Import Quiz to this Folder', `fldr_imp:${folderId}`)
        .row();
    }

    // Navigation: Back to parent or root
    if (currentFolder.parent_id) {
      keyboard.text('🔙 Back to Parent Folder', `fldr:${currentFolder.parent_id}`);
    } else {
      keyboard.text('🔙 Back to Directory Root', 'menu_quizzes');
    }
    keyboard.row().text('🏠 Platform Dashboard', 'menu_start');

    if (ctx.callbackQuery) {
      try {
        await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      } catch {
        await ctx.editMessageText(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
      }
      ctx.answerCallbackQuery().catch(() => {});
    } else {
      try {
        await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      } catch {
        await ctx.reply(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
      }
    }
    return;
  }

  // AT DIRECTORY ROOT
  const rootFolders = await getFolders(supabase, null);
  const rootQuizzes = await getQuizzesByFolder(supabase, null);
  const totalQuizzes = await getActiveQuizzes(supabase);

  // If NO folders exist at all, preserve the classic flat quiz catalog
  const allFoldersCount = (await getAllFolders(supabase)).length;
  if (rootFolders.length === 0 && allFoldersCount === 0) {
    if (totalQuizzes.length === 0) {
      const text = '⚠️ Abhi koi test active nahi hai. Kripya thodi der baad check karein ya admin se contact karein.';
      const keyboard = new InlineKeyboard().text('🔙 Main Menu', 'menu_start');
      if (adminMode) keyboard.row().text('📁 Create First Folder', 'fldr_new:root');

      if (ctx.callbackQuery) {
        await ctx.editMessageText(text, { reply_markup: keyboard });
        ctx.answerCallbackQuery().catch(() => {});
      } else {
        await ctx.reply(text, { reply_markup: keyboard });
      }
      return;
    }

    let text = `📚 *OFFICIAL MOCK EXAMINATIONS CATALOG*\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `Kripya attempt karne ke liye examination paper select karein:\n\n`;

    const keyboard = new InlineKeyboard();
    totalQuizzes.forEach((quiz) => {
      const badge = quiz.is_premium ? '🔒 [PREMIUM]' : '🟢 [FREE]';
      keyboard.text(`${badge} ${quiz.title}`, `view_quiz:${quiz.id}`).row();
    });

    if (adminMode) {
      keyboard
        .text('📁 Create Examination Folder', 'fldr_new:root')
        .text('📥 Import Quiz', 'fldr_imp:root')
        .row();
    }
    keyboard.text('🔙 Platform Dashboard', 'menu_start');

    if (ctx.callbackQuery) {
      try {
        await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      } catch {
        await ctx.editMessageText(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
      }
      ctx.answerCallbackQuery().catch(() => {});
    } else {
      try {
        await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
      } catch {
        await ctx.reply(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
      }
    }
    return;
  }

  // FOLDERS EXIST: Render hierarchical root
  let text = `📚 *OFFICIAL EXAMINATION DIRECTORY (ROOT)*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `Kripya subject category ya examination folder chunein:\n\n`;

  const keyboard = new InlineKeyboard();

  rootFolders.forEach((f) => {
    keyboard.text(`📁 ${f.name}`, `fldr:${f.id}`).row();
  });

  if (rootQuizzes.length > 0) {
    rootQuizzes.forEach((quiz) => {
      const badge = quiz.is_premium ? '🔒 [PREMIUM]' : '🟢 [FREE]';
      keyboard.text(`${badge} ${quiz.title}`, `view_quiz:${quiz.id}`).row();
    });
  }

  if (adminMode) {
    keyboard
      .text('➕ Create New Folder', 'fldr_new:root')
      .text('📥 Import Quiz (Root)', 'fldr_imp:root')
      .row();
  }
  keyboard.text('🔙 Platform Dashboard', 'menu_start');

  if (ctx.callbackQuery) {
    try {
      await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    } catch {
      await ctx.editMessageText(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
    }
    ctx.answerCallbackQuery().catch(() => {});
  } else {
    try {
      await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    } catch {
      await ctx.reply(text.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
    }
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
      await ctx.answerCallbackQuery({ text: 'Examination record not found!', show_alert: true });
    }
    return;
  }

  const marksPerQ = Number(quiz.marks_per_question) || 2;
  const negMarks = Number(quiz.negative_marks) || 0.5;
  const maxMarks = Number(quiz.total_questions || 0) * marksPerQ;

  let text = `📋 *EXAMINATION OVERVIEW & SCHEME*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `🏷️ *Paper Title:* ${escapeMarkdown(quiz.title)}\n`;
  text += `📂 *Subject / Category:* ${escapeMarkdown(quiz.category)}\n`;
  text += `👑 *Access Tier:* ${quiz.is_premium ? '🔒 *Premium Scholar Pass Required*' : '🟢 *Open Access (Free)*'}\n`;
  if (quiz.description) text += `ℹ️ *Description:* ${escapeMarkdown(quiz.description)}\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n`;

  text += `📊 *Examination Pattern:*\n`;
  text += `  • Total Questions: \`${quiz.total_questions}\`\n`;
  text += `  • Total Marks: \`${maxMarks}\` (\`+${marksPerQ}\` per correct response)\n`;
  text += `  • Negative Penalty: \`-${negMarks}\` per incorrect response\n`;
  text += `  • Time Allowance: \`${quiz.time_limit_seconds}s\` per question\n\n`;

  text += `⚡ *Instructions:* Test start hone ke baad timer continuously chalega. Kripya dhyan se attempt karein.`;

  const botUsername = ctx.me.username;
  const shareUrl = `https://t.me/share/url?url=https://t.me/${botUsername}?start=quiz_${quiz.id}&text=Attempt%20${encodeURIComponent(quiz.title)}%20Mock%20Examination%20on%20Examplayer!`;

  const isGroup = ctx.chat?.type === 'group' || ctx.chat?.type === 'supergroup';
  const keyboard = new InlineKeyboard();

  if (isGroup) {
    keyboard
      .text('👥 Launch Group Live Battle', `launch_grp:${quiz.id}`)
      .row()
      .url('🎯 Attempt Solo Test in DM', `https://t.me/${botUsername}?start=quiz_${quiz.id}`)
      .row();
  } else {
    keyboard
      .text('🚀 Begin Examination Now', `start_quiz:${quiz.id}`)
      .row();
  }

  keyboard
    .url('📢 Share to Channels / Groups', shareUrl)
    .text('🏆 Merit List & Rankings', `lb:${quiz.id}`)
    .row()
    .text('📄 Download Question Paper & Solutions (PDF)', `pdf_scorecard:${quiz.id}`)
    .row();

  // Admin Controls (Toggle Premium, Edit Quiz, Delete Quiz) - ONLY in Private Chat
  if (!isGroup && isAdmin(ctx, env)) {
    const toggleLabel = quiz.is_premium ? '🔓 Set as Free Access' : '🔒 Set as Premium Access';
    keyboard
      .text(toggleLabel, `toggle_prem:${quiz.id}`)
      .text('✏️ Edit Examination Scheme', `edit_quiz:${quiz.id}`)
      .row()
      .text('🗑️ Delete Examination', `ask_del_quiz:${quiz.id}`)
      .row();
  }

  if (!isGroup) {
    keyboard.text('🔙 All Examination Papers', 'menu_quizzes');
  } else {
    keyboard.url('📚 Browse All Papers in Bot DM', `https://t.me/${botUsername}?start=quizzes`);
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
    `⚠️ *CONFIRM EXAMINATION DELETION*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Are you sure you wish to delete *"${escapeMarkdown(quiz.title)}"*?\n\n` +
    `🚨 *Warning:* All questions, question options, and recorded candidate attempts for this paper will be permanently expunged. This action cannot be reversed.`;

  const keyboard = new InlineKeyboard()
    .text('🚨 Confirm Permanent Deletion', `confirm_del_quiz:${quiz.id}`)
    .row()
    .text('🔙 Cancel & Return', `view_quiz:${quiz.id}`);

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
    await ctx.answerCallbackQuery({ text: '❌ Failed to delete examination.', show_alert: true });
    return;
  }

  await ctx.answerCallbackQuery({ text: `🗑️ "${quizTitle}" deleted successfully.`, show_alert: true });
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

    let folderName = 'Directory Root';
    if (quiz.folder_id) {
      const f = await getFolderById(supabase, quiz.folder_id);
      if (f) folderName = f.name;
    }

  const text =
    `⚙️ *EXAMINATION CONFIGURATION EDITOR*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Title:* ${escapeMarkdown(quiz.title)}\n` +
    `📂 *Category:* ${escapeMarkdown(quiz.category)}\n` +
    `📁 *Current Folder:* ${escapeMarkdown(folderName)}\n` +
    `⏱️ *Time Limit:* \`${quiz.time_limit_seconds}s\` per question\n` +
    `🎯 *Marking Scheme:* \`+${quiz.marks_per_question}\` / \`-${quiz.negative_marks}\`\n` +
    `👑 *Access Tier:* ${quiz.is_premium ? '🔒 Premium Pass' : '🟢 Open Access'}\n` +
    `🆔 *Paper ID:* \`${quiz.id}\`\n\n` +
    `Select a property below to modify configuration:`;

  const keyboard = new InlineKeyboard()
    .text('⏱️ Configure Timer', `ed_timer_opt:${quiz.id}`)
    .text('🎯 Configure Marking', `ed_marks_opt:${quiz.id}`)
    .row()
    .text('🏷️ Rename Examination Title', `ed_title_prompt:${quiz.id}`)
    .text('📂 Change Subject Category', `ed_cat_prompt:${quiz.id}`)
    .row()
    .text('📁 Move / Assign to Folder', `ed_move_fldr:${quiz.id}`)
    .row()
    .text('🔙 Return to Examination', `view_quiz:${quiz.id}`);

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

  const text = `⏱️ *Select Question Time Limit:*\n\nSelect the time allocation permitted per question:`;
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
  await ctx.answerCallbackQuery({ text: `⏱️ Time limit set to ${seconds}s.` });
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
    `🎯 *Select Marking Scheme:*\n\n` +
    `Configure marks awarded for correct answers and negative penalty:`;

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
  await ctx.answerCallbackQuery({ text: `🎯 Marking scheme updated to +${marks} / -${neg}.` });
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
    `🏷️ *RENAME EXAMINATION TITLE*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Current Title: *${escapeMarkdown(quiz?.title || '')}*\n\n` +
    `To update the title, execute:\n` +
    `\`/edittitle ${quizId} New Examination Title\``;

  const keyboard = new InlineKeyboard().text('🔙 Return to Editor', `edit_quiz:${quizId}`);
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
    `📂 *CHANGE SUBJECT CATEGORY*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Current Category: *${escapeMarkdown(quiz?.category || '')}*\n\n` +
    `To update the subject category, execute:\n` +
    `\`/editcat ${quizId} New Category Name\``;

  const keyboard = new InlineKeyboard().text('🔙 Return to Editor', `edit_quiz:${quizId}`);
  await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  await ctx.answerCallbackQuery();
}

// ================= ADMIN: COMMAND HANDLERS =================

export async function handleEditTitleCommand(ctx: Context, supabase: SupabaseClient, env: Env) {
  if (!isAdmin(ctx, env)) return;

  const text = ctx.message?.text || '';
  const parts = text.split(' ');
  if (parts.length < 3) {
    await ctx.reply('⚠️ Syntax: `/edittitle <quiz_id> <New Title>`', { parse_mode: 'Markdown' });
    return;
  }

  const quizId = parts[1];
  const newTitle = parts.slice(2).join(' ').trim();

  const success = await updateQuiz(supabase, quizId, { title: newTitle });
  if (!success) {
    await ctx.reply('❌ Failed to update title. Please verify the Examination ID.');
    return;
  }

  await ctx.reply(`✅ *Title Updated Successfully*\nNew Title: *${escapeMarkdown(newTitle)}*`, { parse_mode: 'Markdown' });
}

export async function handleEditCategoryCommand(ctx: Context, supabase: SupabaseClient, env: Env) {
  if (!isAdmin(ctx, env)) return;

  const text = ctx.message?.text || '';
  const parts = text.split(' ');
  if (parts.length < 3) {
    await ctx.reply('⚠️ Syntax: `/editcat <quiz_id> <New Category>`', { parse_mode: 'Markdown' });
    return;
  }

  const quizId = parts[1];
  const newCat = parts.slice(2).join(' ').trim();

  const success = await updateQuiz(supabase, quizId, { category: newCat });
  if (!success) {
    await ctx.reply('❌ Failed to update category. Please verify the Examination ID.');
    return;
  }

  await ctx.reply(`✅ *Category Updated Successfully*\nNew Category: *${escapeMarkdown(newCat)}*`, { parse_mode: 'Markdown' });
}

export async function handleDeleteQuizCommand(ctx: Context, supabase: SupabaseClient, env: Env) {
  if (!isAdmin(ctx, env)) return;

  const text = ctx.message?.text || '';
  const parts = text.split(' ');
  if (parts.length < 2) {
    await ctx.reply('⚠️ Syntax: `/delquiz <quiz_id>`', { parse_mode: 'Markdown' });
    return;
  }

  const quizId = parts[1].trim();
  const success = await deleteQuiz(supabase, quizId);
  if (!success) {
    await ctx.reply('❌ Failed to delete examination. Verify the Examination ID.');
    return;
  }

  await ctx.reply(`✅ Examination \`${quizId}\` has been permanently deleted.`, { parse_mode: 'Markdown' });
}
