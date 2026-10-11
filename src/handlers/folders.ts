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

export interface FolderInputSession {
  type: 'create' | 'rename';
  parentId?: string | null;
  parentName?: string;
  folderId?: string;
  folderName?: string;
}

// In-memory session tracking for active admin prompts (No UUID needed!)
export const folderInputSessions: Map<number, FolderInputSession> = new Map();

/**
 * Prompt to create a new folder or subfolder.
 * Admin can simply type the name directly in chat — NO UUID required!
 */
export async function handleCreateFolderPrompt(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  parentIdStr: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: '⚠️ Platform Administrator access required.', show_alert: true }).catch(() => {});
  }

  const userId = ctx.from?.id;
  const isSubfolder = parentIdStr && parentIdStr !== 'root';
  let parentName = 'Directory Root';
  if (isSubfolder) {
    const parent = await getFolderById(supabase, parentIdStr);
    if (parent) parentName = parent.name;
  }

  if (userId) {
    folderInputSessions.set(userId, {
      type: 'create',
      parentId: isSubfolder ? parentIdStr : null,
      parentName,
    });
  }

  const text =
    `✍️ *CREATE ${isSubfolder ? 'SUBFOLDER' : 'FOLDER'}*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📍 Target Location: *${escapeMarkdown(parentName)}*\n\n` +
    `Bas chat me naye folder ka naam likhkar bhej dijiye:\n` +
    `_Example: \`Prelims 2026\` ya \`Indian Polity\`_\n\n` +
    `*(Kisi bhi lambi ID ko copy karne ki bilkul jarurat nahi hai!)*`;

  const keyboard = new InlineKeyboard();
  if (isSubfolder) {
    keyboard.text('❌ Cancel', `fldr:${parentIdStr}`);
  } else {
    keyboard.text('❌ Cancel', 'menu_quizzes');
  }

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

/**
 * Intercepts plain text message when an admin is creating or renaming a folder.
 */
export async function handleFolderTextInput(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
): Promise<boolean> {
  const userId = ctx.from?.id;
  if (!userId) return false;

  const session = folderInputSessions.get(userId);
  if (!session) return false;

  const text = ctx.message?.text?.trim();
  if (!text) return false;

  // If user enters a command, cancel the active session and let the command run
  if (text.startsWith('/')) {
    folderInputSessions.delete(userId);
    return false;
  }

  folderInputSessions.delete(userId);

  if (session.type === 'create') {
    const folder = await createFolder(supabase, text, session.parentId || null);
    if (!folder) {
      await ctx.reply('❌ Folder create karne me samasya aayi. Kripya punah prayas karein.');
      return true;
    }

    const notifyText =
      `✅ *FOLDER SUCCESSFULLY CREATED!*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `📁 *Name:* ${escapeMarkdown(folder.name)}\n` +
      `📍 *Location:* ${escapeMarkdown(session.parentName || 'Directory Root')}\n\n` +
      `Aap is folder ke andar tests rakh sakte hain ya subfolders bana sakte hain!`;

    const keyboard = new InlineKeyboard().text('📂 Open Folder', `fldr:${folder.id}`).row();
    if (session.parentId) {
      keyboard.text('🔙 Back to Parent', `fldr:${session.parentId}`);
    } else {
      keyboard.text('🔙 Directory Root', 'menu_quizzes');
    }

    try {
      await ctx.reply(notifyText, { parse_mode: 'Markdown', reply_markup: keyboard });
    } catch {
      await ctx.reply(notifyText.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
    }
    return true;
  }

  if (session.type === 'rename' && session.folderId) {
    const success = await updateFolder(supabase, session.folderId, text);
    if (!success) {
      await ctx.reply('❌ Folder rename karne me samasya aayi.');
      return true;
    }

    const keyboard = new InlineKeyboard().text('📂 Open Folder', `fldr:${session.folderId}`);
    try {
      await ctx.reply(
        `✅ *Folder Ka Naam Badal Diya Gaya!*\nNew Name: *${escapeMarkdown(text)}*`,
        { parse_mode: 'Markdown', reply_markup: keyboard }
      );
    } catch {
      await ctx.reply(`✅ Folder Ka Naam Badal Diya Gaya!\nNew Name: ${text}`, { reply_markup: keyboard });
    }
    return true;
  }

  return false;
}

/**
 * Command: /newfolder [ParentName/Subfolder] or [FolderName]
 */
export async function handleCreateFolderCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  const raw = ctx.message?.text || '';
  const match = raw.replace(/^\/newfolder\s*/i, '').trim();
  if (!match) {
    return ctx.reply(
      `📁 *Naya Folder Banane Ke Tareeqe:*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `1️⃣ *Sabse Aasaan:* /quizzes me jaakar *[➕ New Subfolder]* button dabayein aur direct naam likhkar bhej dein (No ID needed).\n\n` +
      `2️⃣ *Command (Root Folder):* \`/newfolder UPSC Civil Services\`\n` +
      `3️⃣ *Command (Subfolder Name Se):* \`/newfolder UPSC / Prelims\`\n` +
      `4️⃣ *Command (ID Se):* \`/newfolder <folder_id> Prelims\``,
      { parse_mode: 'Markdown' }
    );
  }

  let parentId: string | null = null;
  let name = match;

  // Check if syntax has '/' or '>' e.g. "UPSC / Prelims"
  if (match.includes('/') || match.includes('>')) {
    const sep = match.includes('/') ? '/' : '>';
    const parts = match.split(sep).map((p) => p.trim());
    const parentQuery = parts[0];
    name = parts.slice(1).join(sep).trim();

    const all = await getAllFolders(supabase);
    const found = all.find(
      (f) => f.name.toLowerCase() === parentQuery.toLowerCase() || f.id === parentQuery
    );
    if (found) {
      parentId = found.id;
    } else {
      return ctx.reply(`⚠️ Parent folder *"${escapeMarkdown(parentQuery)}"* nahi mila. Kripya folder ka sahi naam check karein.`, {
        parse_mode: 'Markdown',
      });
    }
  } else {
    // Check if first token is an existing folder ID
    const parts = match.split(/\s+/);
    if (parts.length >= 2) {
      const potentialId = parts[0];
      const existing = await getFolderById(supabase, potentialId);
      if (existing) {
        parentId = existing.id;
        name = parts.slice(1).join(' ').trim();
      }
    }
  }

  const folder = await createFolder(supabase, name, parentId);
  if (!folder) {
    return ctx.reply('❌ Failed to create folder.');
  }

  const notifyText =
    `✅ *FOLDER SUCCESSFULLY CREATED!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `📁 *Name:* ${escapeMarkdown(folder.name)}\n` +
    (parentId ? `📍 *Inside Parent Folder*\n\n` : `📍 *Location:* Directory Root\n\n`) +
    `You can now move examination papers into this folder!`;

  const keyboard = new InlineKeyboard().text('📂 Open Folder in Directory', `fldr:${folder.id}`);
  try {
    return ctx.reply(notifyText, { parse_mode: 'Markdown', reply_markup: keyboard });
  } catch {
    return ctx.reply(notifyText.replace(/[*_`\[\]]/g, ''), { reply_markup: keyboard });
  }
}

/**
 * Prompt to rename an existing folder (No UUID needed!).
 */
export async function handleRenameFolderPrompt(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env,
  folderId: string
) {
  if (!isAdmin(ctx, env)) {
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true }).catch(() => {});
  }

  const userId = ctx.from?.id;
  const folder = await getFolderById(supabase, folderId);
  if (!folder) {
    return ctx.answerCallbackQuery({ text: 'Folder not found.', show_alert: true }).catch(() => {});
  }

  if (userId) {
    folderInputSessions.set(userId, {
      type: 'rename',
      folderId,
      folderName: folder.name,
    });
  }

  const text =
    `✏️ *RENAME FOLDER: "${escapeMarkdown(folder.name)}"*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `Kripya is folder ka naya naam chat me likhkar bhej dijiye (e.g. \`IAS Prelims 2026\`):\n\n` +
    `*(Kisi bhi ID ko copy karne ki jarurat nahi hai!)*`;

  const keyboard = new InlineKeyboard().text('❌ Cancel', `fldr:${folderId}`);

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

/**
 * Command: /renamefolder <Folder/ID> <New Name>
 */
export async function handleRenameFolderCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  const raw = ctx.message?.text || '';
  const match = raw.replace(/^\/renamefolder\s*/i, '').trim();

  if (!match) {
    return ctx.reply(
      `✏️ *Folder Rename Syntax:*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `1️⃣ *Button Se:* /quizzes me folder kholkar *[✏️ Rename Folder]* dabayein aur direct naya naam chat me bhej dein.\n\n` +
      `2️⃣ *Command Se:* \`/renamefolder Purana Naam / Naya Naam\`\n` +
      `_Example: \`/renamefolder Railway Science / Railway Exam GK\`_\n\n` +
      `3️⃣ *ID Se:* \`/renamefolder <folder_id> Naya Naam\``,
      { parse_mode: 'Markdown' }
    );
  }

  let folderId = '';
  let newName = '';

  const all = await getAllFolders(supabase);

  // 1. Check if separated by '/', '>', or ' to '
  let sep: string | null = null;
  if (match.includes('/')) sep = '/';
  else if (match.includes('>')) sep = '>';
  else if (match.toLowerCase().includes(' to ')) sep = ' to ';

  if (sep) {
    const parts = match.split(sep).map((p) => p.trim());
    const oldQuery = parts[0];
    newName = parts.slice(1).join(sep).trim();

    const found = all.find(
      (f) => f.name.toLowerCase() === oldQuery.toLowerCase() || f.id === oldQuery
    );
    if (found) {
      folderId = found.id;
    } else {
      return ctx.reply(`⚠️ Folder *"${escapeMarkdown(oldQuery)}"* nahi mila.`);
    }
  } else {
    // 2. Check if first word is a known folder ID
    const parts = match.split(/\s+/);
    const potentialId = parts[0];
    const foundById = all.find((f) => f.id === potentialId);
    if (foundById && parts.length >= 2) {
      folderId = foundById.id;
      newName = parts.slice(1).join(' ').trim();
    } else {
      // 3. Try to match an existing folder by name prefix
      let matchedFolder: any = null;
      let matchedLen = 0;
      for (const f of all) {
        if (match.toLowerCase().startsWith(f.name.toLowerCase())) {
          if (f.name.length > matchedLen) {
            matchedFolder = f;
            matchedLen = f.name.length;
          }
        }
      }

      if (matchedFolder) {
        folderId = matchedFolder.id;
        newName = match.slice(matchedLen).trim();
      } else if (parts.length >= 2) {
        folderId = parts[0];
        newName = parts.slice(1).join(' ').trim();
      }
    }
  }

  if (!folderId || !newName) {
    return ctx.reply(
      `⚠️ *Folder nahi mila ya naya naam missing hai.*\n` +
      `Kripya yeh format use karein:\n\`/renamefolder Purana Naam / Naya Naam\``,
      { parse_mode: 'Markdown' }
    );
  }

  const success = await updateFolder(supabase, folderId, newName);
  if (!success) {
    return ctx.reply('❌ Failed to rename folder. Verify Folder Name/ID.');
  }

  const keyboard = new InlineKeyboard().text('📂 Open Folder', `fldr:${folderId}`);
  try {
    return ctx.reply(
      `✅ *Folder Renamed Successfully!*\nNew Name: *${escapeMarkdown(newName)}*`,
      { parse_mode: 'Markdown', reply_markup: keyboard }
    );
  } catch {
    return ctx.reply(`✅ Folder Renamed Successfully!\nNew Name: ${newName}`, { reply_markup: keyboard });
  }
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
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true }).catch(() => {});
  }

  const folder = await getFolderById(supabase, folderId);
  if (!folder) {
    return ctx.answerCallbackQuery({ text: 'Folder not found.', show_alert: true }).catch(() => {});
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
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true }).catch(() => {});
  }

  const folder = await getFolderById(supabase, folderId);
  const parentId = folder?.parent_id;

  const success = await deleteFolder(supabase, folderId);
  if (!success) {
    return ctx.answerCallbackQuery({ text: '❌ Failed to delete folder.', show_alert: true }).catch(() => {});
  }

  ctx.answerCallbackQuery({ text: '🗑️ Folder deleted successfully!' }).catch(() => {});

  return handleQuizzesList(ctx, supabase, parentId || null);
}

/**
 * Command: /delfolder <folder_name_or_id>
 */
export async function handleDeleteFolderCommand(
  ctx: Context,
  supabase: SupabaseClient,
  env: Env
) {
  if (!isAdmin(ctx, env)) return;

  const raw = ctx.message?.text || '';
  const query = raw.replace(/^\/delfolder\s*/i, '').trim();
  if (!query) {
    return ctx.reply(
      `🗑️ *Folder Delete Syntax:*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `1️⃣ *Button Se:* /quizzes me folder kholkar *[🗑️ Delete Folder]* dabayein aur confirm karein.\n` +
      `2️⃣ *Command Se:* \`/delfolder Folder Ka Naam\`\n` +
      `_Example: \`/delfolder Science\`_`,
      { parse_mode: 'Markdown' }
    );
  }

  const all = await getAllFolders(supabase);
  let folder = all.find((f) => f.id === query) || null;
  if (!folder) {
    folder = all.find((f) => f.name.toLowerCase() === query.toLowerCase()) || null;
  }
  if (!folder) {
    folder = all.find((f) => f.name.toLowerCase().includes(query.toLowerCase())) || null;
  }

  if (!folder) {
    return ctx.reply(`❌ Folder *"${escapeMarkdown(query)}"* nahi mila.`);
  }

  const folderName = folder.name;
  await deleteFolder(supabase, folder.id);
  return ctx.reply(`✅ Folder *"${escapeMarkdown(folderName)}"* deleted. Contained tests moved to root.`, {
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
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true }).catch(() => {});
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
    return ctx.answerCallbackQuery({ text: '⚠️ Administrator access required.', show_alert: true }).catch(() => {});
  }

  const targetFolderId = targetFolderIdStr === 'root' ? null : targetFolderIdStr;
  await moveQuizToFolder(supabase, quizId, targetFolderId);

  await ctx.answerCallbackQuery({
    text: targetFolderId ? '✅ Examination assigned to folder!' : '✅ Examination moved to Directory Root!',
    show_alert: true,
  }).catch(() => {});

  return handleEditQuizPanel(ctx, supabase, env, quizId);
}
