import { Context } from 'grammy';
import { Env } from '../config';

/**
 * Strict Admin Check:
 * Only returns true if the user's Telegram ID is explicitly listed in ADMIN_USER_ID.
 * Supports single ID or comma-separated list of IDs (e.g. "12345,67890").
 * Returns FALSE for everyone else. Never allows unauthorized users!
 */
export function isAdmin(ctx: Context, env: Env): boolean {
  const userId = ctx.from?.id;
  if (!userId || !env.ADMIN_USER_ID) {
    return false;
  }

  const allowedAdmins = env.ADMIN_USER_ID.split(',').map((id) => id.trim());
  return allowedAdmins.includes(String(userId));
}

/**
 * Checks if user is an administrator in the current chat.
 * Returns true if private chat, or if user is bot super admin, or if user has admin/creator status in group.
 */
export async function isGroupAdmin(ctx: Context, env?: Env): Promise<boolean> {
  if (!ctx.chat || ctx.chat.type === 'private') return true;
  const userId = ctx.from?.id;
  if (!userId) return false;

  // Bot Super Admin check
  if (env && isAdmin(ctx, env)) return true;
  const adminId = process.env.ADMIN_USER_ID;
  if (adminId && adminId.split(',').map((s) => s.trim()).includes(String(userId))) {
    return true;
  }

  try {
    const member = await ctx.api.getChatMember(ctx.chat.id, userId);
    return member.status === 'administrator' || member.status === 'creator';
  } catch (err) {
    console.error('Failed to get chat member status:', err);
    return false;
  }
}

