import { webhookCallback } from 'grammy';
import { createBot } from './bot';
import { Env, getConfig } from './config';

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
      console.error('Error handling webhook update:', err);
      return new Response(`Internal Error: ${err.message}`, { status: 500 });
    }
  },
};
