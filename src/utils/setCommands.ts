import { Api } from 'grammy';

/**
 * Registers Telegram Bot commands so that typing '/' or clicking the Menu button
 * immediately displays all command suggestions with professional descriptions.
 */
export async function registerBotCommands(api: Api): Promise<void> {
  try {
    // 1. Private Chat Scope (Individual Candidates in Bot DM)
    await api.setMyCommands(
      [
        { command: 'start', description: '🏛️ Platform Dashboard & Main Menu' },
        { command: 'quizzes', description: '📖 Browse Mock Examination Catalog' },
        { command: 'leaderboard', description: '🏆 All-India Merit Standings' },
        { command: 'myprofile', description: '👤 Candidate Academic Profile & Analytics' },
        { command: 'premium', description: '💎 Premium Scholar Pass Access' },
        { command: 'pdf', description: '📄 Export Official Scorecard PDF' },
        { command: 'help', description: 'ℹ️ Candidate User Guide & Instructions' },
      ],
      { scope: { type: 'all_private_chats' } }
    );

    // 2. Group Chat Scope (Community Study Groups)
    await api.setMyCommands(
      [
        { command: 'groupquiz', description: '⚔️ Launch Live Group Examination' },
        { command: 'schedule', description: '⏰ Schedule Examination Slot (IST)' },
        { command: 'scheduled', description: '📋 View Active Group Schedule' },
        { command: 'cancelschedule', description: '🛑 Cancel Scheduled Session' },
        { command: 'stopquiz', description: '⏹️ Terminate Active Battle (Admin)' },
        { command: 'leaderboard', description: '🏆 Community Merit List' },
      ],
      { scope: { type: 'all_group_chats' } }
    );

    // 3. Fallback Default Scope
    await api.setMyCommands([
      { command: 'start', description: '🏛️ Platform Dashboard' },
      { command: 'quizzes', description: '📖 Examination Catalog' },
      { command: 'groupquiz', description: '⚔️ Launch Group Quiz' },
      { command: 'schedule', description: '⏰ Schedule Group Quiz' },
      { command: 'leaderboard', description: '🏆 Merit Standings' },
      { command: 'myprofile', description: '👤 Candidate Profile' },
      { command: 'premium', description: '💎 Premium Scholar Pass' },
      { command: 'help', description: 'ℹ️ User Guide' },
    ]);

    console.log('✅ Bot slash commands successfully registered with Telegram API.');
  } catch (err) {
    console.error('Failed to register Telegram bot commands:', err);
  }
}
