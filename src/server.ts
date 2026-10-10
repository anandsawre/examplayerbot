import http from 'node:http';
import dns from 'node:dns';
dns.setDefaultResultOrder('ipv4first');

import 'dotenv/config';
import { webhookCallback } from 'grammy';
import { createBot } from './bot';
import { getConfig } from './config';

async function main() {
  console.log('🚀 Initializing Examplayer Bot Server (Render / Production Node.js)...');

  const config = getConfig();

  if (!config.BOT_TOKEN) {
    console.error('❌ Error: BOT_TOKEN is missing in environment variables!');
    process.exit(1);
  }

  if (!config.SUPABASE_URL || !config.SUPABASE_KEY) {
    console.error('❌ Error: SUPABASE_URL or SUPABASE_KEY is missing in environment variables!');
    process.exit(1);
  }

  const port = parseInt(process.env.PORT || '3000', 10);
  const bot = createBot(config);

  const botInfo = await bot.api.getMe();
  console.log(`🤖 Logged in as Telegram Bot: @${botInfo.username} (ID: ${botInfo.id})`);

  // Detect whether to run in Webhook mode or Long Polling mode
  // Render provides RENDER_EXTERNAL_URL (e.g. https://examplayer-bot.onrender.com)
  const externalUrl = process.env.RENDER_EXTERNAL_URL || process.env.WEBHOOK_URL;

  if (externalUrl) {
    const cleanUrl = externalUrl.replace(/\/$/, '');
    const webhookPath = '/webhook';
    const fullWebhookUrl = `${cleanUrl}${webhookPath}`;

    console.log(`🌐 Webhook mode enabled. Setting Telegram Webhook to: ${fullWebhookUrl}`);
    await bot.api.setWebhook(fullWebhookUrl);
    console.log(`✅ Webhook registered successfully!`);

    const handleWebhook = webhookCallback(bot, 'http');

    const server = http.createServer((req, res) => {
      // Health check endpoint for Render & Uptime monitoring
      if (req.method === 'GET' && (req.url === '/' || req.url === '/health')) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(
          JSON.stringify({
            status: 'ok',
            service: 'Examplayer Bot',
            bot: `@${botInfo.username}`,
            mode: 'webhook',
            uptimeSeconds: Math.floor(process.uptime()),
          })
        );
        return;
      }

      // Webhook payload from Telegram
      if (req.method === 'POST' && req.url === webhookPath) {
        handleWebhook(req, res);
        return;
      }

      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not Found');
    });

    server.listen(port, '0.0.0.0', () => {
      console.log(`🎯 HTTP Webhook server running on port ${port}`);
    });

    // Graceful shutdown
    process.on('SIGTERM', () => {
      console.log('SIGTERM received. Shutting down gracefully...');
      server.close(() => process.exit(0));
    });
  } else {
    // Fallback: Long Polling mode + HTTP Health Check server (satisfies Render port binding)
    console.log(`🔄 Long Polling mode enabled with HTTP Health Check on port ${port}...`);

    try {
      await bot.api.deleteWebhook({ drop_pending_updates: true });
      console.log(`🗑️ Removed existing webhook to enable Long Polling.`);
    } catch (e) {
      console.error('Warning deleting webhook:', e);
    }

    const server = http.createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          status: 'ok',
          service: 'Examplayer Bot',
          bot: `@${botInfo.username}`,
          mode: 'polling',
          uptimeSeconds: Math.floor(process.uptime()),
        })
      );
    });

    server.listen(port, '0.0.0.0', () => {
      console.log(`🎯 HTTP Health-check server running on port ${port}`);
    });

    // Start grammY long polling
    bot.start({
      onStart: () => {
        console.log(`✅ Bot long-polling started! Ready to receive messages.`);
      },
    });

    // Graceful shutdown
    process.on('SIGTERM', () => {
      console.log('SIGTERM received. Shutting down gracefully...');
      bot.stop();
      server.close(() => process.exit(0));
    });
  }
}

main().catch((err) => {
  console.error('❌ Fatal error running bot server:', err);
  process.exit(1);
});
