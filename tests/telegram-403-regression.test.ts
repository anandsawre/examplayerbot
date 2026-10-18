import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { GrammyError, Context, Bot } from 'grammy';
import {
  isTelegramForbidden,
  isTelegramExpectedError,
  sanitizeError,
  handleBotError,
  safeTelegramCall,
} from '../src/utils/telegramErrors';
import { handleStart, handleHelp } from '../src/handlers/start';

describe('Telegram 403 Error Handling & Classification', () => {
  it('correctly identifies GrammyError 403 as forbidden', () => {
    const error = new GrammyError(
      "Call to 'sendMessage' failed!",
      {
        ok: false,
        error_code: 403,
        description: 'Forbidden: bot was blocked by the user',
      },
      'sendMessage',
      { chat_id: 123456789, text: 'Hello' }
    );

    assert.equal(isTelegramForbidden(error), true);
    assert.equal(isTelegramExpectedError(error), true);
  });

  it('correctly identifies user deactivated and bot kicked errors', () => {
    const deactivatedErr = new GrammyError(
      "Call to 'sendMessage' failed!",
      {
        ok: false,
        error_code: 403,
        description: 'Forbidden: user is deactivated',
      },
      'sendMessage',
      { chat_id: 999999 }
    );
    assert.equal(isTelegramForbidden(deactivatedErr), true);

    const kickedErr = {
      error_code: 403,
      description: 'Forbidden: bot was kicked from the supergroup chat',
    };
    assert.equal(isTelegramForbidden(kickedErr), true);

    const cannotInitiateErr = {
      message: "403: Forbidden: bot can't initiate conversation with a user",
    };
    assert.equal(isTelegramForbidden(cannotInitiateErr), true);
  });

  it('does not classify non-403 errors as forbidden', () => {
    const badRequestErr = new GrammyError(
      "Call to 'editMessageText' failed!",
      {
        ok: false,
        error_code: 400,
        description: 'Bad Request: message is not modified',
      },
      'editMessageText',
      {}
    );
    assert.equal(isTelegramForbidden(badRequestErr), false);
    // But message is not modified is expected
    assert.equal(isTelegramExpectedError(badRequestErr), true);

    const serverErr = new GrammyError(
      "Call to 'getMe' failed!",
      {
        ok: false,
        error_code: 502,
        description: 'Bad Gateway',
      },
      'getMe',
      {}
    );
    assert.equal(isTelegramForbidden(serverErr), false);
    assert.equal(isTelegramExpectedError(serverErr), false);
  });
});

describe('Sensitive Information Log Sanitization', () => {
  it('redacts Telegram bot tokens from logs and stack traces', () => {
    const raw = 'Error: Call failed with token 747573651:AAFl-xyz1234567890abcdefghijklmnopqr to Telegram';
    const sanitized = sanitizeError(raw);

    assert.equal(sanitized.includes('747573651:AAFl-xyz1234567890abcdefghijklmnopqr'), false);
    assert.equal(sanitized.includes('[REDACTED_BOT_TOKEN]'), true);
  });

  it('redacts Telegram API URLs containing bot tokens', () => {
    const raw = 'Failed at https://api.telegram.org/bot747573651:AAFl-xyz1234567890abcdefghijklmnopqr/sendMessage with code 403';
    const sanitized = sanitizeError(raw);

    assert.equal(sanitized.includes('bot747573651:AAFl'), false);
    assert.equal(sanitized.includes('https://api.telegram.org/bot[REDACTED]/sendMessage'), true);
  });

  it('redacts JWT tokens and database credentials', () => {
    const raw = 'Connected to postgresql://postgres:SuperSecretP@ssw0rd123@db.supabase.co:5432 and key eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.secret';
    const sanitized = sanitizeError(raw);

    assert.equal(sanitized.includes('SuperSecretP@ssw0rd123'), false);
    assert.equal(sanitized.includes('[REDACTED_PWD]'), true);
    assert.equal(sanitized.includes('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'), false);
    assert.equal(sanitized.includes('[REDACTED_JWT_KEY]'), true);
  });
});

describe('handleStart Regression Test (Production 403 reproduction)', () => {
  it('does not crash or rethrow when ctx.reply throws 403 Forbidden (bot was blocked by the user)', async () => {
    const blockedError = new GrammyError(
      "Call to 'sendMessage' failed!",
      {
        ok: false,
        error_code: 403,
        description: 'Forbidden: bot was blocked by the user',
      },
      'sendMessage',
      { chat_id: 12345, text: 'welcome' }
    );

    // Mock Context replicating Telegram start command
    let replyCallCount = 0;
    const mockCtx: any = {
      from: { id: 12345, first_name: 'TestStudent' },
      match: undefined,
      reply: async () => {
        replyCallCount++;
        throw blockedError;
      },
    };

    // Mock Supabase
    const mockSupabase: any = {
      from: () => ({
        select: () => ({
          eq: () => ({
            single: async () => ({ data: null, error: null }),
          }),
        }),
        insert: () => ({
          select: () => ({
            single: async () => ({ data: { id: 12345 }, error: null }),
          }),
        }),
      }),
    };

    // Execution must resolve without throwing an exception!
    await assert.doesNotReject(async () => {
      await handleStart(mockCtx, mockSupabase);
    });

    assert.equal(replyCallCount, 1);
  });

  it('does not crash or rethrow when handleHelp encounters 403 Forbidden', async () => {
    const blockedError = new GrammyError(
      "Call to 'sendMessage' failed!",
      {
        ok: false,
        error_code: 403,
        description: 'Forbidden: bot was blocked by the user',
      },
      'sendMessage',
      { chat_id: 12345, text: 'help' }
    );

    const mockCtx: any = {
      callbackQuery: undefined,
      reply: async () => {
        throw blockedError;
      },
    };

    await assert.doesNotReject(async () => {
      await handleHelp(mockCtx);
    });
  });
});

describe('safeTelegramCall Utility', () => {
  it('returns fallback value and suppresses 403 Forbidden without rethrowing', async () => {
    const blockedError = new GrammyError(
      "Call to 'sendMessage' failed!",
      {
        ok: false,
        error_code: 403,
        description: 'Forbidden: bot was blocked by the user',
      },
      'sendMessage',
      {}
    );

    const result = await safeTelegramCall(
      async () => {
        throw blockedError;
      },
      'fallback_ok',
      'Test operation'
    );

    assert.equal(result, 'fallback_ok');
  });
});

describe('Bot Middleware & Centralized Catch Integration', () => {
  it('intercepts thrown 403 inside bot update middleware without unhandled rejection', async () => {
    const bot = new Bot('123456789:ABCdef-ghijk_lmnopqrstuvwxyz12345');

    // Simulate bot initialization
    bot.botInfo = {
      id: 123456789,
      is_bot: true,
      first_name: 'TestBot',
      username: 'Examplayer_bot',
      can_join_groups: true,
      can_read_all_group_messages: false,
      supports_inline_queries: false,
      can_connect_to_business: false,
      has_main_web_app: false,
    };

    let errorHandled = false;

    // Install top-level error middleware
    bot.use(async (ctx, next) => {
      try {
        await next();
      } catch (err) {
        errorHandled = true;
        handleBotError(err, ctx);
      }
    });

    bot.command('start', async () => {
      throw new GrammyError(
        "Call to 'sendMessage' failed!",
        {
          ok: false,
          error_code: 403,
          description: 'Forbidden: bot was blocked by the user',
        },
        'sendMessage',
        {}
      );
    });

    const update: any = {
      update_id: 10001,
      message: {
        message_id: 1,
        date: Math.floor(Date.now() / 1000),
        chat: { id: 77777, type: 'private' },
        from: { id: 77777, is_bot: false, first_name: 'BlockedUser' },
        text: '/start',
        entities: [{ type: 'bot_command', offset: 0, length: 6 }],
      },
    };

    // Must handle update completely without rejecting
    await assert.doesNotReject(async () => {
      await bot.handleUpdate(update);
    });

    assert.equal(errorHandled, true);
  });
});
