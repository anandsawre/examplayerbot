import 'dotenv/config';
import { Api } from 'grammy';
import { registerBotCommands } from '../src/utils/setCommands';

async function main() {
  const token = process.env.BOT_TOKEN;
  if (!token) {
    throw new Error('BOT_TOKEN not found in environment');
  }

  const api = new Api(token);
  console.log('🔄 Registering slash commands with Telegram API...');
  await registerBotCommands(api);
  console.log('🎉 Done! Commands have been registered.');
}

main().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
