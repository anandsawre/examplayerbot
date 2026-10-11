import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import {
  getFolders,
  getAllFolders,
  getFolderById,
  getFolderPath,
  createFolder,
  updateFolder,
  deleteFolder,
  getQuizzesByFolder,
  moveQuizToFolder,
  getQuizById,
} from '../db/queries';
import { isAdmin } from '../utils/admin';
import { handleQuizzesList, handleEditQuizPanel } from './quizzes';

function escapeMarkdown(text: string): string {
  if (!text) return '';
  return text
    .replace(/_/g, '\\_')
    .replace(/\*/g, '\\*')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]')
    .replace(/`/g, '\\`');
}

/**
 * Prompt to create a new folder or subfolder
 */
export async function handleCreateFolderPrompt(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  parentIdStr: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: '⚠️ Platform Administrator access required.', show_alert: true });
  }

  const isSubfolder = parentIdStr && parentIdStr !== 'root';
  let parentName = 'Directory Root';
  if (isSubfolder) {
    const parent = await getFolderById(supabase, parentIdStr);
    if (parent) parentName = parent.name;
  }

  const text =
    `📁 *CREATE ${isSubfolder ? 'SUBFOLDER' : 'EXAMINATION FOLDER'}*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📍 Target Location: *${escapeMarkdown(parentName)}*\n\n` +
    `Naya folder banane ke liye chat me yeh command bhejein:\n` +
    (isSubfolder
      ? `\`/newfolder ${parentIdStr} Folder Ka Naam\``
      : `\`/newfolder Folder Ka Naam\`\n\n_Example: \`/newfolder UPSC Civil Services\`_`);

  const keyboard = new InlineKeyboard();
  if (isSubfolder) {
    keyboard.text('🔙 Back to Folder', `fldr:${parentIdStr}`);
  } else {
    keyboard.text('🔙 Back to Directory', 'menu_quizzes');
  }

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

/**
 * Command: /newfolder [parentId] <FolderName>
 */
export async function handleCreateFolderCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  const raw = ctx.message?.text || '';
  const parts = raw.trim().split(/\s+/);
  if (parts.length < 2) {
    return ctx.reply(
      `⚠️ *Command Format:*\n` +
      `• Root Folder: \`/newfolder <Folder Name>\`\n` +
      `• Subfolder: \`/newfolder <parent_id> <Subfolder Name>\``,
      { parse_mode: 'Markdown' }
    );
  }

  let parentId: string | null = null;
  let name = '';

  // Check if first arg is an existing folder ID
  const potentialParentId = parts[1];
  const existingParent = await getFolderById(supabase, potentialParentId);
  if (existingParent) {
    parentId = existingParent.id;
    name = parts.slice(2).join(' ').trim();
  } else {
    name = parts.slice(1).join(' ').trim();
  }

  if (!name) {
    return ctx.reply('⚠️ Kripya folder ka naam provide karein.');
  }

  const folder = await createFolder(supabase, name, parentId);
  if (!folder) {
    return ctx.reply('❌ Failed to create folder.');
  }

  const notifyText =
    `✅ *FOLDER SUCCESSFULLY CREATED!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📁 *Name:* ${escapeMarkdown(folder.name)}\n` +
    `🆔 *Folder ID:* \`${folder.id}\`\n` +
    (parentId ? `📍 *Parent:* \`${parentId}\`\n\n` : `📍 *Location:* Directory Root\n\n`) +
    `You can now move examination papers into this folder!`;

  const keyboard = new InlineKeyboard().text('📂 Open Folder in Directory', `fldr:${folder.id}`);
  return ctx.reply(notifyText, { parse_mode: 'Markdown', reply_markup: keyboard });
}

/**
 * Prompt to rename an existing folder
 */
export async function handleRenameFolderPrompt(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  folderId: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true });
  }

  const folder = await getFolderById(supabase, folderId);
  if (!folder) {
    return ctx.answerCallbackQuery({ text: 'Folder not found.', show_alert: true });
  }

  const text =
    `✏️ *RENAME EXAMINATION FOLDER*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Current Folder Name: *${escapeMarkdown(folder.name)}*\n` +
    `Folder ID: \`${folder.id}\`\n\n` +
    `Folder ka naam badalne ke liye chat me yeh command enter karein:\n` +
    `\`/renamefolder ${folder.id} Naya Folder Name\``;

  const keyboard = new InlineKeyboard().text('🔙 Back to Folder', `fldr:${folder.id}`);

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

/**
 * Command: /renamefolder <folder_id> <New Name>
 */
export async function handleRenameFolderCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  const raw = ctx.message?.text || '';
  const parts = raw.trim().split(/\s+/);
  if (parts.length < 3) {
    return ctx.reply('⚠️ *Syntax:* `/renamefolder <folder_id> <New Name>`', { parse_mode: 'Markdown' });
  }

  const folderId = parts[1];
  const newName = parts.slice(2).join(' ').trim();

  const success = await updateFolder(supabase, folderId, newName);
  if (!success) {
    return ctx.reply('❌ Failed to rename folder. Verify Folder ID.');
  }

  const keyboard = new InlineKeyboard().text('📂 Open Folder', `fldr:${folderId}`);
  return ctx.reply(
    `✅ *Folder Renamed Successfully!*\nNew Name: *${escapeMarkdown(newName)}*`,
    { parse_mode: 'Markdown', reply_markup: keyboard }
  );
}

/**
 * Confirmation dialog before deleting folder
 */
export async function handleDeleteFolderPrompt(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  folderId: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true });
  }

  const folder = await getFolderById(supabase, folderId);
  if (!folder) {
    return ctx.answerCallbackQuery({ text: 'Folder not found.', show_alert: true });
  }

  const text =
    `⚠️ *CONFIRM FOLDER DELETION*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Are you sure you want to delete folder *"${escapeMarkdown(folder.name)}"*?\n\n` +
    `• Any subfolders within will be deleted.\n` +
    `• Examination papers inside will be moved safely to the Directory Root (tests will not be deleted).\n\n` +
    `Do you wish to proceed?`;

  const keyboard = new InlineKeyboard()
    .text('🗑️ Yes, Delete Folder', `fldr_del_confirm:${folderId}`)
    .text('❌ Cancel', `fldr:${folderId}`);

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

/**
 * Confirms and executes folder deletion
 */
export async function handleConfirmDeleteFolder(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  folderId: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true });
  }

  const folder = await getFolderById(supabase, folderId);
  const parentId = folder?.parent_id;

  await deleteFolder(supabase, folderId);
  await ctx.answerCallbackQuery({ text: 'Folder deleted successfully.', show_alert: true });

  return handleQuizzesList(ctx, supabase, parentId || null);
}

/**
 * Command: /delfolder <folder_id>
 */
export async function handleDeleteFolderCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  const raw = ctx.message?.text || '';
  const parts = raw.trim().split(/\s+/);
  if (parts.length < 2) {
    return ctx.reply('⚠️ *Syntax:* `/delfolder <folder_id>`', { parse_mode: 'Markdown' });
  }

  const folderId = parts[1].trim();
  const folder = await getFolderById(supabase, folderId);
  if (!folder) {
    return ctx.reply('❌ Folder not found.');
  }

  await deleteFolder(supabase, folderId);
  return ctx.reply(`✅ Folder *"${escapeMarkdown(folder.name)}"* deleted. Contained tests moved to root.`, {
    parse_mode: 'Markdown',
  });
}

/**
 * Shows interactive folder assignment picker for a Quiz (in Admin Edit Panel)
 */
export async function handleMoveQuizPicker(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true });
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) return;

  const folders = await getAllFolders(supabase);

  const text =
    `📂 *ASSIGN EXAMINATION TO FOLDER*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Paper: *${escapeMarkdown(quiz.title)}*\n\n` +
    `Select the target destination folder below:`;

  const keyboard = new InlineKeyboard();

  keyboard.text('🚫 No Folder (Directory Root)', `move_q_do:${quizId}:root`).row();

  folders.forEach((f) => {
    keyboard.text(`📁 ${f.name}`, `move_q_do:${quizId}:${f.id}`).row();
  });

  keyboard.text('🔙 Back to Editor', `edit_quiz:${quizId}`);

  if (ctx.callbackQuery) {
    await ctx.editMessageText(text, { parse_mode: 'Markdown', reply_markup: keyboard });
    await ctx.answerCallbackQuery();
  } else {
    await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
  }
}

/**
 * Executes moving quiz to target folder
 */
export async function handleExecuteMoveQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  quizId: string,
  targetFolderIdStr: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true });
  }

  const targetFolderId = targetFolderIdStr === 'root' ? null : targetFolderIdStr;
  await moveQuizToFolder(supabase, quizId, targetFolderId);

  await ctx.answerCallbackQuery({
    text: targetFolderId ? '✅ Examination assigned to folder!' : '✅ Examination moved to Directory Root!',
    show_alert: true,
  });

  return handleEditQuizPanel(ctx, supabase, env, quizId);
}
