import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { webhookCallback } from 'grammy';
import { createBot } from '../src/bot';
import { handleBotError, sanitizeError } from '../src/utils/telegramErrors';

describe('Production HTTP Server & Webhook Smoke Test', () => {
  it('serves /health check with 200 OK and valid JSON', async () => {
    const port = 3991;
    const bot = createBot({
      BOT_TOKEN: '123456789:ABCdef-ghijk_lmnopqrstuvwxyz12345',
      SUPABASE_URL: 'https://example.supabase.co',
      SUPABASE_KEY: 'test-key',
    });

    const handleWebhook = webhookCallback(bot, 'http');

    const server = http.createServer(async (req, res) => {
      try {
        const rawUrl = req.url || '';
        const urlPath = rawUrl.split('?')[0].replace(/\/$/, '');

        if (req.method === 'GET' && (urlPath === '' || urlPath === '/health')) {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(
            JSON.stringify({
              status: 'ok',
              service: 'Examplayer Bot',
              uptimeSeconds: Math.floor(process.uptime()),
            })
          );
          return;
        }

        if (req.method === 'POST' && urlPath === '/webhook') {
          try {
            await handleWebhook(req, res);
          } catch (webhookErr: any) {
            handleBotError(webhookErr);
            if (!res.writableEnded && !res.headersSent) {
              res.writeHead(200, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ ok: true, handled_error: true }));
            }
          }
          return;
        }

        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
      } catch (err) {
        if (!res.writableEnded && !res.headersSent) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Internal Server Error' }));
        }
      }
    });

    await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', resolve));

    try {
      // 1. Test GET /health
      const healthRes = await fetch(`http://127.0.0.1:${port}/health`);
      assert.equal(healthRes.status, 200);
      const healthData = await healthRes.json() as any;
      assert.equal(healthData.status, 'ok');
      assert.equal(healthData.service, 'Examplayer Bot');

      // 2. Test Webhook POST with simulated blocked user update
      // Bot is initialized with test credentials so api calls will fail with mock 403 or handled error
      const mockUpdate = {
        update_id: 99999,
        message: {
          message_id: 1,
          date: Math.floor(Date.now() / 1000),
          chat: { id: 88888, type: 'private' },
          from: { id: 88888, is_bot: false, first_name: 'BlockedStudent' },
          text: '/start',
          entities: [{ type: 'bot_command', offset: 0, length: 6 }],
        },
      };

      const webhookPostRes = await fetch(`http://127.0.0.1:${port}/webhook`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(mockUpdate),
      });

      // Crucial: The webhook endpoint must return 200 OK, never 500, never hanging, never crashing!
      assert.equal(webhookPostRes.status, 200);

      // Verify the server remains fully operational after the webhook request
      const healthCheckAfter = await fetch(`http://127.0.0.1:${port}/health`);
      assert.equal(healthCheckAfter.status, 200);
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  });
});
