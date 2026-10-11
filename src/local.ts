import dns from 'node:dns';
dns.setDefaultResultOrder('ipv4first');

import 'dotenv/config';
import { createBot } from './bot';
import { getConfig } from './config';
import { registerBotCommands } from './utils/setCommands';

async function runLocalBot() {
  console.log('🚀 Starting Examplayer Bot locally (Long Polling Mode)...');

  const config = getConfig();

  if (!config.BOT_TOKEN) {
    console.error('❌ Error: BOT_TOKEN is missing in .env file!');
    console.error('👉 Please copy .env.example to .env and set your BOT_TOKEN and Supabase keys.');
    process.exit(1);
  }

  if (!config.SUPABASE_URL || !config.SUPABASE_KEY) {
    console.error('❌ Error: SUPABASE_URL or SUPABASE_KEY is missing in .env file!');
    console.error('👉 Please configure Supabase credentials in your .env file.');
    process.exit(1);
  }

  try {
    const bot = createBot(config);

    // Delete any active webhook before starting long polling
    try {
      await bot.api.deleteWebhook({ drop_pending_updates: true });
    } catch {
      // Ignore transient network errors on deleteWebhook
    }

    const botInfo = await bot.api.getMe();
    console.log(`✅ Examplayer Bot is online as @${botInfo.username}!`);

    // Register command hints and menu button with Telegram API
    await registerBotCommands(bot.api);
    console.log('📱 Telegram open karein aur bot ko /start bhej kar test karein.');

    await bot.start();
  } catch (error) {
    console.error('Fatal error starting local bot:', error);
    process.exit(1);
  }
}

runLocalBot();
