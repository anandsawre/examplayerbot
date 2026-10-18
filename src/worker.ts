import { webhookCallback } from 'grammy';
import { createBot } from './bot';
import { Env, getConfig } from './config';
import { isTelegramForbidden, sanitizeError } from './utils/telegramErrors';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);

      // Simple health check endpoint on GET
      if (request.method === 'GET') {
        return new Response(JSON.stringify({ status: 'ok', name: 'Examplayer Bot Serverless' }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Telegram Webhook endpoint
      const config = getConfig(env);
      const bot = createBot(config);

      const handleUpdate = webhookCallback(bot, 'cloudflare-mod', {
        secretToken: config.WEBHOOK_SECRET || undefined,
      });

      return await handleUpdate(request);
    } catch (err: any) {
      if (isTelegramForbidden(err)) {
        console.warn('Recoverable Telegram 403 Forbidden in Worker update');
        return new Response(JSON.stringify({ ok: true, handled: true }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      console.error('Error handling webhook update:', sanitizeError(err));
      return new Response(JSON.stringify({ ok: true, error: 'Handled error' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }
  },
};
