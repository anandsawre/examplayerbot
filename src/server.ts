import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import dns from 'node:dns';

try {
  dns.setDefaultResultOrder('ipv4first');
} catch {}

import 'dotenv/config';
import { webhookCallback } from 'grammy';
import { createBot } from './bot';
import { getConfig } from './config';
import { registerBotCommands } from './utils/setCommands';
import { getSupabase } from './db/supabase';
import { handleAdminApiRequest } from './admin/adminApi';
import { getAdminHtml } from './admin/adminUi';

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
  let botUsername = 'Examplayer_bot';

  // Detect whether to run in Webhook mode or Long Polling mode
  // Render provides RENDER_EXTERNAL_URL (e.g. https://examplayer-bot.onrender.com)
  const externalUrl = process.env.RENDER_EXTERNAL_URL || process.env.WEBHOOK_URL;
  const isWebhookMode = Boolean(externalUrl);
  const webhookPath = '/webhook';
  const handleWebhook = webhookCallback(bot, 'http');

  const supabase = getSupabase(config);

  // 1. START HTTP SERVER IMMEDIATELY so Render health check always passes on boot!
  const server = http.createServer(async (req, res) => {
    const rawUrl = req.url || '';
    const rawPath = rawUrl.split('?')[0];
    const urlPath = rawPath.replace(/\/$/, '');

    // Health check endpoint for Render & Uptime monitoring
    if (req.method === 'GET' && (urlPath === '' || urlPath === '/health')) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          status: 'ok',
          service: 'Examplayer Bot',
          bot: `@${botUsername}`,
          mode: isWebhookMode ? 'webhook' : 'polling',
          uptimeSeconds: Math.floor(process.uptime()),
        })
      );
      return;
    }

    // Webhook payload from Telegram
    if (req.method === 'POST' && urlPath === webhookPath) {
      handleWebhook(req, res);
      return;
    }

    // Legacy HTML portal direct access
    if (req.method === 'GET' && (urlPath === '/admin/legacy' || urlPath === '/admin/legacy/index.html')) {
      res.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-cache',
      });
      res.end(getAdminHtml());
      return;
    }

    // Admin Web Portal Frontend UI (Flutter Web App with SPA routing)
    if (req.method === 'GET' && (rawPath === '/admin' || rawPath.startsWith('/admin/'))) {
      if (rawPath === '/admin') {
        const query = rawUrl.includes('?') ? '?' + rawUrl.split('?')[1] : '';
        res.writeHead(301, { 'Location': `/admin/${query}` });
        res.end();
        return;
      }

      const distDir = path.join(process.cwd(), 'portal', 'dist');
      const relPath = rawPath.replace(/^\/admin\//, '');
      let filePath = path.join(distDir, relPath);

      // Security: Prevent directory traversal outside distDir
      const resolvedDist = path.resolve(distDir);
      if (!path.resolve(filePath).startsWith(resolvedDist)) {
        filePath = path.join(distDir, 'index.html');
      }

      if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
        filePath = path.join(filePath, 'index.html');
      }

      // SPA fallback to index.html if specific file not found
      if (!fs.existsSync(filePath)) {
        filePath = path.join(distDir, 'index.html');
      }

      if (fs.existsSync(filePath)) {
        const ext = path.extname(filePath).toLowerCase();
        const mimeTypes: Record<string, string> = {
          '.html': 'text/html; charset=utf-8',
          '.js': 'text/javascript; charset=utf-8',
          '.css': 'text/css; charset=utf-8',
          '.json': 'application/json',
          '.png': 'image/png',
          '.jpg': 'image/jpeg',
          '.jpeg': 'image/jpeg',
          '.gif': 'image/gif',
          '.svg': 'image/svg+xml',
          '.wasm': 'application/wasm',
          '.ttf': 'font/ttf',
          '.otf': 'font/otf',
          '.woff': 'font/woff',
          '.woff2': 'font/woff2',
          '.ico': 'image/x-icon',
        };
        const contentType = mimeTypes[ext] || 'application/octet-stream';
        res.writeHead(200, {
          'Content-Type': contentType,
          'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=86400',
        });
        fs.createReadStream(filePath).pipe(res);
        return;
      }

      // Fallback to legacy HTML if portal/dist doesn't exist
      res.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-cache',
      });
      res.end(getAdminHtml());
      return;
    }

    // Admin Web Portal Backend REST API
    if (urlPath.startsWith('/api/admin')) {
      const handled = await handleAdminApiRequest(req, res, supabase, bot, config);
      if (handled) return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  });

  server.listen(port, '0.0.0.0', () => {
    console.log(`🎯 HTTP Webhook server running on port ${port} (Health check active)`);
  });

  // 2. CONNECT TO TELEGRAM IN BACKGROUND WITH AUTOMATIC RETRY (Resilient against cold network timeouts)
  async function connectTelegram() {
    let connected = false;
    let attempts = 0;
    const maxAttempts = 10;
    let delay = 2000;

    while (!connected && attempts < maxAttempts) {
      attempts++;
      try {
        console.log(`📡 Connecting to Telegram API (Attempt ${attempts}/${maxAttempts})...`);
        const botInfo = await bot.api.getMe();
        botUsername = botInfo.username;
        console.log(`🤖 Logged in as Telegram Bot: @${botInfo.username} (ID: ${botInfo.id})`);
        connected = true;

        // Register command hints and menu button with Telegram API
        try {
          await registerBotCommands(bot.api);
          console.log('✅ Bot command hints registered successfully.');
        } catch (cmdErr: any) {
          console.warn('⚠️ Warning registering bot commands:', cmdErr?.message);
        }

        // Webhook registration
        if (externalUrl) {
          const cleanUrl = externalUrl.replace(/\/$/, '');
          const fullWebhookUrl = `${cleanUrl}${webhookPath}`;

          const registerWebhook = async () => {
            try {
              console.log(`🌐 Setting Telegram Webhook to: ${fullWebhookUrl}`);
              await bot.api.setWebhook(fullWebhookUrl, {
                drop_pending_updates: false,
                allowed_updates: ['message', 'callback_query', 'poll_answer', 'poll', 'chat_member', 'my_chat_member'],
              });
              console.log(`✅ Webhook registered successfully!`);
            } catch (err: any) {
              console.error('Error setting Telegram webhook:', err?.message || err);
            }
          };

          await registerWebhook();

          // Auto-healing: Check every 2 minutes
          setInterval(async () => {
            try {
              const info = await bot.api.getWebhookInfo();
              if (info.url !== fullWebhookUrl) {
                console.log(`⚠️ Telegram webhook was modified ("${info.url}"). Auto-healing to: ${fullWebhookUrl}`);
                await registerWebhook();
              }
            } catch (e: any) {
              console.error('Periodic webhook verification warning:', e?.message || e);
            }
          }, 120_000);
        } else {
          // Fallback: Long Polling
          console.log('🔄 Long Polling fallback mode enabled...');
          try {
            await bot.api.deleteWebhook({ drop_pending_updates: false });
          } catch {}
          bot.start({
            onStart: () => console.log('✅ Bot long-polling started! Ready to receive messages.'),
          });
        }
      } catch (err: any) {
        console.warn(`⚠️ Telegram connection attempt ${attempts} timed out or failed (${err?.message || err?.code}). Retrying in ${delay / 1000}s...`);
        await new Promise((resolve) => setTimeout(resolve, delay));
        delay = Math.min(delay * 1.5, 10000);
      }
    }

    if (!connected) {
      console.error('❌ Could not connect to Telegram API during boot. Background reconnect will continue.');
      const interval = setInterval(async () => {
        try {
          const info = await bot.api.getMe();
          botUsername = info.username;
          console.log(`🤖 Background connection succeeded: @${info.username}!`);
          clearInterval(interval);
          connectTelegram();
        } catch {}
      }, 10000);
    }
  }

  // Start Telegram connection asynchronously (non-blocking)
  connectTelegram();

  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM received. Shutting down gracefully...');
    server.close(() => process.exit(0));
  });
}

main().catch((err) => {
  console.error('❌ Fatal error in server startup:', err);
});
