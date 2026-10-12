import { Context } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { Env } from '../config';
import { getSetting, setSetting } from '../db/queries';

// In-memory cache of appointed administrators from database
let appointedAdminsCache: string[] = [];
let cacheInitialized = false;

/**
 * Syncs the appointed administrators list from the Supabase bot_settings table.
 */
export async function syncAdminCache(supabase: SupabaseClient): Promise<string[]> {
  try {
    const rawVal = await getSetting(supabase, 'db_admins', '');
    if (rawVal) {
      appointedAdminsCache = rawVal
        .split(',')
        .map((id) => id.trim())
        .filter(Boolean);
    } else {
      appointedAdminsCache = [];
    }
  } catch (err) {
    console.error('Failed to sync admin cache:', err);
  }
  cacheInitialized = true;
  return appointedAdminsCache;
}

export function getAppointedAdmins(): string[] {
  return [...appointedAdminsCache];
}

export function getRootAdmins(env?: Env): string[] {
  const adminIdStr = env?.ADMIN_USER_ID || process.env.ADMIN_USER_ID || '';
  return adminIdStr
    .split(',')
    .map((id) => id.trim())
    .filter(Boolean);
}

export function isRootAdmin(ctx: Context, env?: Env): boolean {
  const userId = ctx.from?.id;
  if (!userId) return false;
  return getRootAdmins(env).includes(String(userId));
}

/**
 * Strict Admin Check:
 * Returns true if the user's Telegram ID is in ADMIN_USER_ID (Root) OR in appointed DB admins.
 */
export function isAdmin(ctx: Context, env?: Env): boolean {
  const userId = ctx.from?.id;
  if (!userId) return false;

  const idStr = String(userId);
  if (getRootAdmins(env).includes(idStr)) {
    return true;
  }

  return appointedAdminsCache.includes(idStr);
}

/**
 * Adds a new administrator to the database and refreshes the cache.
 */
export async function addAppointedAdmin(
  supabase: SupabaseClient,
  userId: string | number
): Promise<boolean> {
  const idStr = String(userId).trim();
  if (!idStr || isNaN(Number(idStr))) return false;

  if (!appointedAdminsCache.includes(idStr)) {
    appointedAdminsCache.push(idStr);
  }

  const serialized = appointedAdminsCache.join(',');
  return await setSetting(supabase, 'db_admins', serialized);
}

/**
 * Removes an administrator from the database and refreshes the cache.
 */
export async function removeAppointedAdmin(
  supabase: SupabaseClient,
  userId: string | number
): Promise<boolean> {
  const idStr = String(userId).trim();
  appointedAdminsCache = appointedAdminsCache.filter((id) => id !== idStr);

  const serialized = appointedAdminsCache.join(',');
  return await setSetting(supabase, 'db_admins', serialized);
}

/**
 * Checks if user is an administrator in the current chat.
 * Returns true if private chat, or if user is bot super admin, or if user has admin/creator status in group.
 */
export async function isGroupAdmin(ctx: Context, env?: Env): Promise<boolean> {
  if (!ctx.chat || ctx.chat.type === 'private') return true;
  const userId = ctx.from?.id;
  if (!userId) return false;

  // Bot Admin check (Root or Appointed)
  if (isAdmin(ctx, env)) return true;

  try {
    const member = await ctx.api.getChatMember(ctx.chat.id, userId);
    return member.status === 'administrator' || member.status === 'creator';
  } catch (err) {
    console.error('Failed to get chat member status:', err);
    return false;
  }
}

