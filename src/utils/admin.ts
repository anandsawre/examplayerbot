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
