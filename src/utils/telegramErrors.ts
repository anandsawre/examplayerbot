import { Context, GrammyError, HttpError, BotError } from 'grammy';

/**
 * Checks whether an error is a Telegram 403 Forbidden error:
 * - Bot was blocked by the user
 * - User was deactivated
 * - Bot was kicked from group / supergroup
 * - Bot is not a member of the group/channel
 * - Chat was deleted / not found
 * - Bot can't initiate conversation with the user
 */
export function isTelegramForbidden(error: unknown): boolean {
  if (!error) return false;

  // Direct GrammyError check
  if (error instanceof GrammyError && error.error_code === 403) {
    return true;
  }

  // Wrapped inside BotError
  if (error instanceof BotError && error.error instanceof GrammyError && error.error.error_code === 403) {
    return true;
  }

  const errObj = error as any;
  const code = errObj?.error_code || errObj?.statusCode || errObj?.status || errObj?.code;
  if (code === 403) {
    return true;
  }

  const message = String(errObj?.description || errObj?.message || error || '').toLowerCase();
  return (
    message.includes('403') ||
    message.includes('bot was blocked by the user') ||
    message.includes('user is deactivated') ||
    message.includes('bot was kicked') ||
    message.includes('not a member of the') ||
    message.includes("can't initiate conversation") ||
    message.includes('chat not found') ||
    message.includes('chat was deleted') ||
    message.includes('forbidden')
  );
}

/**
 * Checks whether an error is an expected, recoverable Telegram Bot API error:
 * - 403 Forbidden (blocked/kicked/deactivated)
 * - 400 Bad Request: message is not modified, message to edit not found, query is too old
 * - 429 Too Many Requests (rate limiting)
 */
export function isTelegramExpectedError(error: unknown): boolean {
  if (isTelegramForbidden(error)) {
    return true;
  }

  const errObj = (error instanceof BotError ? error.error : error) as any;

  if (errObj instanceof GrammyError || (typeof errObj === 'object' && errObj?.error_code)) {
    const code = errObj.error_code;
    const desc = String(errObj.description || errObj.message || '').toLowerCase();

    // 400 Bad Request that are benign/expected
    if (code === 400) {
      if (
        desc.includes('message is not modified') ||
        desc.includes('message to edit not found') ||
        desc.includes('query is too old') ||
        desc.includes('have no rights to send') ||
        desc.includes('chat not found') ||
        desc.includes('replied message not found') ||
        desc.includes('button_data_invalid')
      ) {
        return true;
      }
    }

    // 429 Rate limiting is expected/recoverable
    if (code === 429) {
      return true;
    }
  }

  return false;
}

/**
 * Sanitizes errors and log messages to ensure bot tokens, API keys,
 * and sensitive URLs are never leaked in production logs.
 */
export function sanitizeError(error: unknown): string {
  if (!error) return 'Unknown error';

  let raw = '';
  if (typeof error === 'string') {
    raw = error;
  } else if (error instanceof Error) {
    raw = `${error.name}: ${error.message}${error.stack ? `\n${error.stack}` : ''}`;
  } else {
    try {
      raw = JSON.stringify(error, null, 2);
    } catch {
      raw = String(error);
    }
  }

  // Redact Telegram Bot tokens: format is digits:base64-alphanumeric (e.g. 123456789:ABCdef-xyz)
  raw = raw.replace(/\b\d{8,12}:[A-Za-z0-9_-]{32,}\b/g, '[REDACTED_BOT_TOKEN]');

  // Redact Telegram API URLs
  raw = raw.replace(/https?:\/\/api\.telegram\.org\/bot[^\/\s"'`]+/gi, 'https://api.telegram.org/bot[REDACTED]');

  // Redact JWT tokens (Supabase keys or authorization bearer tokens)
  raw = raw.replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_.-]*\b/g, '[REDACTED_JWT_KEY]');

  // Redact database passwords if in URI format: postgres://user:password@host
  raw = raw.replace(/(postgres(?:ql)?:\/\/[^:]+:)([^@]+)(@)/gi, '$1[REDACTED_PWD]$3');

  return raw;
}

/**
 * Safely executes a Telegram API call. Catches 403 Forbidden and expected
 * Telegram errors, logging them at an appropriate level without throwing.
 */
export async function safeTelegramCall<T>(
  operation: () => Promise<T>,
  fallbackValue?: T,
  contextDesc?: string
): Promise<T | undefined> {
  try {
    return await operation();
  } catch (err: any) {
    const desc = contextDesc ? ` [${contextDesc}]` : '';

    if (isTelegramForbidden(err)) {
      console.warn(`[Telegram API 403 Forbidden]${desc} Target user or chat is inaccessible / blocked bot. Skipped cleanly.`);
      return fallbackValue;
    }

    if (isTelegramExpectedError(err)) {
      const errDetail = err?.description || err?.message || 'Recoverable Telegram error';
      console.info(`[Telegram API Expected]${desc} ${errDetail}`);
      return fallbackValue;
    }

    console.error(`[Telegram API Error]${desc} Unexpected failure: ${sanitizeError(err)}`);
    return fallbackValue;
  }
}

/**
 * Centralized grammY error handler for bot.catch and webhook error catching.
 * Safely classifies and logs errors without crashing the server.
 */
export function handleBotError(err: unknown, ctx?: Context): void {
  // If wrapped in grammY's BotError, extract the inner error
  const underlying = (err instanceof BotError ? err.error : err) as any;
  const updateId = ctx?.update?.update_id || (err instanceof BotError ? err.ctx?.update?.update_id : undefined);
  const chatId = ctx?.chat?.id || (err instanceof BotError ? err.ctx?.chat?.id : undefined);
  const fromId = ctx?.from?.id || (err instanceof BotError ? err.ctx?.from?.id : undefined);
  const target = chatId ? `chat ${chatId}` : fromId ? `user ${fromId}` : 'unknown target';

  if (isTelegramForbidden(underlying)) {
    console.warn(
      `⚠️ [Bot] Handled Telegram 403 Forbidden for update #${updateId || 'N/A'} (${target}): User blocked the bot or chat is inaccessible.`
    );
    return;
  }

  if (underlying instanceof GrammyError) {
    const desc = underlying.description || '';
    if (underlying.error_code === 400) {
      if (desc.includes('message is not modified') || desc.includes('query is too old')) {
        // Expected benign user action (e.g. repeated button click)
        return;
      }
      console.warn(`⚠️ [Bot] Telegram 400 Bad Request for update #${updateId || 'N/A'} (${target}): ${desc}`);
      return;
    }

    if (underlying.error_code === 429) {
      const retryAfter = underlying.parameters?.retry_after ?? 'a few';
      console.warn(`⏳ [Bot] Telegram 429 Rate Limit for update #${updateId || 'N/A'}: Retry after ${retryAfter}s`);
      return;
    }

    console.error(`❌ [Bot] Telegram API Error (${underlying.error_code}) for update #${updateId || 'N/A'}: ${sanitizeError(desc)}`);
    return;
  }

  if (underlying instanceof HttpError) {
    console.warn(`🌐 [Bot] Telegram Network/HTTP Error for update #${updateId || 'N/A'}: ${sanitizeError(underlying.message)}`);
    return;
  }

  // Any other error: log safely with sanitized trace
  console.error(`❌ [Bot] Unhandled error during update #${updateId || 'N/A'} (${target}):\n${sanitizeError(underlying)}`);
}
