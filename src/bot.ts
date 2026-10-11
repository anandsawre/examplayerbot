import { Bot } from 'grammy';
import { Env } from './config';
import { getSupabase } from './db/supabase';
import { handleStart, handleHelp } from './handlers/start';
import {
  handleQuizzesList,
  handleViewQuiz,
  handleToggleQuizPremium,
  handleAskDeleteQuiz,
  handleConfirmDeleteQuiz,
  handleEditQuizPanel,
  handleEditTimerOptions,
  handleSetQuizTimer,
  handleEditMarksOptions,
  handleSetQuizMarks,
  handleEditTitlePrompt,
  handleEditCategoryPrompt,
  handleEditTitleCommand,
  handleEditCategoryCommand,
  handleDeleteQuizCommand,
} from './handlers/quizzes';
import { handleStartQuiz, handleAnswerCallback, handleQuitQuiz, handleSoloPollAnswer, handlePollClosed, handleSkipQuestion } from './handlers/quizPlay';
import { handleGlobalLeaderboard, handleQuizLeaderboard } from './handlers/leaderboard';
import { handleProfile } from './handlers/profile';
import { handleDocumentImport, handleImportHelp, handleTextImport } from './handlers/adminImport';
import {
  handleGroupQuizCommand,
  handleLaunchGroupQuiz,
  handleGroupPollAnswer,
  handleStopGroupQuiz,
} from './handlers/groupQuiz';
import {
  handleAuthCommand,
  handleUnauthCommand,
  handleListGroupsCommand,
  handleBotAddedToGroup,
  handleGroupApprovalCallback,
} from './handlers/groupAuth';
import {
  handlePaymentPhotoUpload,
  handlePaymentApprovalCallback,
  handleUnlockCommand,
  handleRedeemCommand,
  showPaymentPrompt,
} from './handlers/payment';
import { checkChannelMembership } from './handlers/membership';
import {
  handleSettingsCommand,
  handleSetUpi,
  handleSetPrice,
  handleSetChannel,
  handleUnsetChannel,
} from './handlers/adminSettings';
import { handleDownloadPdfScorecard } from './handlers/pdfExport';
import { handleBroadcastCommand, handleBroadcastCallback } from './handlers/broadcast';
import {
  handleScheduleCommand,
  handleSchedulePickQuiz,
  handleScheduleSetTime,
  handleScheduleCustomPrompt,
  handleSchedulePresetTime,
  handleCustomTimeCommand,
  handleCancelScheduleCommand,
  handleScheduledStatusCommand,
} from './handlers/groupSchedule';
import {
  handleMistakesCommand,
  handleStartRevisionTest,
  handleClearResolvedMistakes,
} from './handlers/mistakes';
import {
  handleStreakCommand,
  handleDailyQotdCommand,
  handleDailyPollAnswer,
} from './handlers/streak';
import { handleReferralCommand } from './handlers/referral';
import {
  handleDuelCommand,
  launchDuelWithCount,
  handleAcceptDuel,
  handleCancelDuel,
  handleDeclineDuel,
  handleDuelPollAnswer,
} from './handlers/duel';


export function createBot(env: Env): Bot {
  if (!env.BOT_TOKEN) {
    throw new Error('BOT_TOKEN is required to initialize Telegram Bot!');
  }

  const bot = new Bot(env.BOT_TOKEN);
  const supabase = getSupabase(env);

  // Global Error Handler
  bot.catch((err) => {
    console.error('Unhandled error in Examplayer Bot:', err);
  });

  // ================= COMMANDS =================
  bot.command('start', (ctx) => handleStart(ctx, supabase, env));
  bot.command('help', (ctx) => handleHelp(ctx));
  bot.command('quizzes', (ctx) => handleQuizzesList(ctx, supabase));
  bot.command('groupquiz', (ctx) => handleGroupQuizCommand(ctx, supabase));
  bot.command('leaderboard', (ctx) => handleGlobalLeaderboard(ctx, supabase));
  bot.command('myprofile', (ctx) => handleProfile(ctx, supabase));
  bot.command('import', (ctx) => handleImportHelp(ctx));

  // Phase 1: Mistake Notebook & Daily Streak
  bot.command('mistakes', (ctx) => handleMistakesCommand(ctx, supabase));
  bot.command('revision', (ctx) => handleStartRevisionTest(ctx, supabase, env));
  bot.command('streak', (ctx) => handleStreakCommand(ctx, supabase));
  bot.command('daily', (ctx) => handleDailyQotdCommand(ctx, supabase, env));
  bot.command('qotd', (ctx) => handleDailyQotdCommand(ctx, supabase, env));

  // Phase 2: Referral Ambassador Program & 1v1 Live Duels
  bot.command('refer', (ctx) => handleReferralCommand(ctx, supabase));
  bot.command('invite', (ctx) => handleReferralCommand(ctx, supabase));
  bot.command('duel', (ctx) => handleDuelCommand(ctx, supabase));

  // Premium & Monetization Commands
  bot.command('unlock', (ctx) => handleUnlockCommand(ctx, supabase, env));
  bot.command('redeem', (ctx) => handleRedeemCommand(ctx, supabase));
  bot.command('premium', (ctx) => showPaymentPrompt(ctx, supabase, env));

  // In-Bot Admin Settings Commands
  bot.command('admin', (ctx) => handleSettingsCommand(ctx, supabase, env));
  bot.command('settings', (ctx) => handleSettingsCommand(ctx, supabase, env));
  bot.command('setupi', (ctx) => handleSetUpi(ctx, supabase, env));
  bot.command('setprice', (ctx) => handleSetPrice(ctx, supabase, env));
  bot.command('setchannel', (ctx) => handleSetChannel(ctx, supabase, env));
  bot.command('unsetchannel', (ctx) => handleUnsetChannel(ctx, supabase, env));

  // Group Authorization Commands
  bot.command('auth', (ctx) => handleAuthCommand(ctx, supabase, env));
  bot.command('unauth', (ctx) => handleUnauthCommand(ctx, supabase, env));
  bot.command('stopquiz', (ctx) => handleStopGroupQuiz(ctx, supabase));
  bot.command('quit', async (ctx) => {
    if (ctx.chat?.type !== 'private') {
      return handleStopGroupQuiz(ctx, supabase);
    }
    return handleQuitQuiz(ctx, supabase);
  });
  bot.command('delquiz', (ctx) => handleDeleteQuizCommand(ctx, supabase, env));
  bot.command('edittitle', (ctx) => handleEditTitleCommand(ctx, supabase, env));
  bot.command('editcat', (ctx) => handleEditCategoryCommand(ctx, supabase, env));

  // Admin Global Broadcast Tool
  bot.command('broadcast', (ctx) => handleBroadcastCommand(ctx, supabase, env));

  // Group Quiz Scheduling
  bot.command('schedule', (ctx) => handleScheduleCommand(ctx, supabase));
  bot.command('scheduletime', (ctx) => handleCustomTimeCommand(ctx, supabase));
  bot.command('schedule_time', (ctx) => handleCustomTimeCommand(ctx, supabase));
  bot.command('cancel_schedule', (ctx) => handleCancelScheduleCommand(ctx));
  bot.command('cancelschedule', (ctx) => handleCancelScheduleCommand(ctx));
  bot.command('scheduled', (ctx) => handleScheduledStatusCommand(ctx));
  bot.command('pdf', async (ctx) => {
    const text = ctx.message?.text || '';
    const qId = text.split(' ')[1];
    if (qId) return handleDownloadPdfScorecard(ctx, supabase, qId);
    return ctx.reply('ℹ️ *Scorecard Export Format:* `/pdf <quiz_id>` or select the *"Download Official PDF"* button beneath your completed examination scorecard.', { parse_mode: 'Markdown' });
  });

  // ================= EVENTS =================
  // Quiz Poll Answer Event (Duel, Daily QOTD, Group Battle, or Solo Test)
  bot.on('poll_answer', async (ctx) => {
    // 1. Check if 1v1 Live Duel poll
    const isDuel = await handleDuelPollAnswer(ctx.pollAnswer);
    if (isDuel) return;

    // 2. Check if Daily Question of the Day (QOTD) poll
    const isDaily = await handleDailyPollAnswer(ctx, supabase);
    if (isDaily) return;

    // 3. Group Live Battle poll
    handleGroupPollAnswer(ctx.pollAnswer);

    // 4. Solo Quiz poll
    return handleSoloPollAnswer(ctx, supabase, env);
  });
  // Solo Quiz Poll Expiration Event (Timer ended without answer on Serverless)
  bot.on('poll', (ctx) => handlePollClosed(ctx, supabase, env));
  // Bot Added to Group Event
  bot.on(':new_chat_members', async (ctx) => {
    const newMembers = ctx.message?.new_chat_members || [];
    const botWasAdded = newMembers.some((m) => m.id === ctx.me.id);
    if (botWasAdded) {
      await handleBotAddedToGroup(ctx, supabase, env);
    }
  });

  // Payment Screenshot Photo Upload Event
  bot.on(':photo', (ctx) => handlePaymentPhotoUpload(ctx, supabase, env));

  // Admin Import (File or Text JSON)
  bot.on('message:document', (ctx) => handleDocumentImport(ctx, supabase, env));
  bot.on('message:text', (ctx) => handleTextImport(ctx, supabase, env));

  // ================= STATIC CALLBACK QUERIES =================
  bot.callbackQuery('menu_start', async (ctx) => {
    if (ctx.chat?.type !== 'private') {
      return ctx.answerCallbackQuery({
        text: '⚠️ Navigation Dashboard is accessible exclusively via private direct message.',
        show_alert: true,
      });
    }
    return handleStart(ctx, supabase, env);
  });
  bot.callbackQuery('menu_help', (ctx) => handleHelp(ctx));
  bot.callbackQuery('menu_quizzes', (ctx) => handleQuizzesList(ctx, supabase));
  bot.callbackQuery('menu_global_lb', (ctx) => handleGlobalLeaderboard(ctx, supabase));
  bot.callbackQuery('menu_profile', async (ctx) => {
    if (ctx.chat?.type !== 'private') {
      return ctx.answerCallbackQuery({
        text: '⚠️ Candidate Profile is accessible exclusively via private direct message.',
        show_alert: true,
      });
    }
    return handleProfile(ctx, supabase);
  });

  // Phase 1: Mistake Notebook & Daily Streak Callbacks
  bot.callbackQuery('menu_mistakes', (ctx) => handleMistakesCommand(ctx, supabase));
  bot.callbackQuery('menu_start_revision', (ctx) => handleStartRevisionTest(ctx, supabase, env));
  bot.callbackQuery('menu_clear_resolved', (ctx) => handleClearResolvedMistakes(ctx, supabase));
  bot.callbackQuery('menu_streak', (ctx) => handleStreakCommand(ctx, supabase));
  bot.callbackQuery('menu_daily_qotd', (ctx) => handleDailyQotdCommand(ctx, supabase, env));

  // Phase 2: Referral Ambassador & 1v1 Duel Callbacks
  bot.callbackQuery('menu_refer', (ctx) => handleReferralCommand(ctx, supabase));
  bot.callbackQuery('menu_duel', (ctx) => handleDuelCommand(ctx, supabase));


  // Payment UI callbacks
  bot.callbackQuery('pay_send_ss', async (ctx) => {
    await ctx.answerCallbackQuery();
    await ctx.reply(
      '📸 *Submit Proof of Transaction:*\n━━━━━━━━━━━━━━━━━━━━━\n' +
      'Following your payment via PhonePe, Google Pay, or Paytm, upload your transaction receipt image directly in this chat for administrative verification.',
      { parse_mode: 'Markdown' }
    );
  });

  bot.callbackQuery('menu_redeem_prompt', async (ctx) => {
    await ctx.answerCallbackQuery();
    await ctx.reply(
      '🎟️ *Redeem Access Voucher:*\n━━━━━━━━━━━━━━━━━━━━━\n' +
      'To redeem an authorized access pass or coupon voucher, submit:\n' +
      '`/redeem <CODE>`\n\n' +
      'Example: `/redeem SCHOLAR2026`',
      { parse_mode: 'Markdown' }
    );
  });

  // Dynamic Callbacks
  bot.on('callback_query:data', async (ctx) => {
    const data = ctx.callbackQuery.data;

    // View quiz details: "view_quiz:<quiz_id>"
    if (data.startsWith('view_quiz:')) {
      const quizId = data.replace('view_quiz:', '');
      return handleViewQuiz(ctx, supabase, env, quizId);
    }

    // Toggle Free/Premium (Admin): "toggle_prem:<quiz_id>"
    if (data.startsWith('toggle_prem:')) {
      const quizId = data.replace('toggle_prem:', '');
      return handleToggleQuizPremium(ctx, supabase, env, quizId);
    }

    // Ask Delete Quiz (Admin): "ask_del_quiz:<quiz_id>"
    if (data.startsWith('ask_del_quiz:')) {
      const quizId = data.replace('ask_del_quiz:', '');
      return handleAskDeleteQuiz(ctx, supabase, env, quizId);
    }

    // Confirm Delete Quiz (Admin): "confirm_del_quiz:<quiz_id>"
    if (data.startsWith('confirm_del_quiz:')) {
      const quizId = data.replace('confirm_del_quiz:', '');
      return handleConfirmDeleteQuiz(ctx, supabase, env, quizId);
    }

    // Edit Quiz Panel (Admin): "edit_quiz:<quiz_id>"
    if (data.startsWith('edit_quiz:')) {
      const quizId = data.replace('edit_quiz:', '');
      return handleEditQuizPanel(ctx, supabase, env, quizId);
    }

    // Edit Timer Options (Admin): "ed_timer_opt:<quiz_id>"
    if (data.startsWith('ed_timer_opt:')) {
      const quizId = data.replace('ed_timer_opt:', '');
      return handleEditTimerOptions(ctx, supabase, env, quizId);
    }

    // Set Timer Value (Admin): "set_q_time:<quiz_id>:<seconds>"
    if (data.startsWith('set_q_time:')) {
      const parts = data.split(':');
      return handleSetQuizTimer(ctx, supabase, env, parts[1], parseInt(parts[2], 10));
    }

    // Edit Marks Options (Admin): "ed_marks_opt:<quiz_id>"
    if (data.startsWith('ed_marks_opt:')) {
      const quizId = data.replace('ed_marks_opt:', '');
      return handleEditMarksOptions(ctx, supabase, env, quizId);
    }

    // Set Marks Value (Admin): "set_q_marks:<quiz_id>:<marks>:<neg>"
    if (data.startsWith('set_q_marks:')) {
      const parts = data.split(':');
      return handleSetQuizMarks(ctx, supabase, env, parts[1], parseFloat(parts[2]), parseFloat(parts[3]));
    }

    // Edit Title Prompt (Admin): "ed_title_prompt:<quiz_id>"
    if (data.startsWith('ed_title_prompt:')) {
      const quizId = data.replace('ed_title_prompt:', '');
      return handleEditTitlePrompt(ctx, supabase, env, quizId);
    }

    // Edit Category Prompt (Admin): "ed_cat_prompt:<quiz_id>"
    if (data.startsWith('ed_cat_prompt:')) {
      const quizId = data.replace('ed_cat_prompt:', '');
      return handleEditCategoryPrompt(ctx, supabase, env, quizId);
    }

    // Start quiz: "start_quiz:<quiz_id>"
    if (data.startsWith('start_quiz:')) {
      if (ctx.chat?.type !== 'private') {
        const qId = data.replace('start_quiz:', '');
        const botUsername = ctx.me.username;
        return ctx.answerCallbackQuery({
          text: '⚠️ Solo examinations must be taken individually in direct message.',
          show_alert: true,
        });
      }
      const quizId = data.replace('start_quiz:', '');
      return handleStartQuiz(ctx, supabase, env, quizId);
    }

    // Answer click: "ans:<question_id>:<option_index>"
    if (data.startsWith('ans:')) {
      const parts = data.split(':');
      const questionId = parts[1];
      const optionIndex = parseInt(parts[2], 10);
      return handleAnswerCallback(ctx, supabase, questionId, optionIndex);
    }

    // Quit test: "quit_test:<quiz_id>"
    if (data.startsWith('quit_test:')) {
      return handleQuitQuiz(ctx, supabase);
    }

    // Skip / Next Question: "skip_q:<quiz_id>:<target_index>"
    if (data.startsWith('skip_q:')) {
      const parts = data.split(':');
      const quizId = parts[1];
      const targetIndex = parseInt(parts[2], 10);
      return handleSkipQuestion(ctx, supabase, env, quizId, targetIndex);
    }

    // Per-quiz leaderboard: "lb:<quiz_id>"
    if (data.startsWith('lb:')) {
      const quizId = data.replace('lb:', '');
      return handleQuizLeaderboard(ctx, supabase, quizId);
    }

    // Launch group quiz: "launch_grp:<quiz_id>"
    if (data.startsWith('launch_grp:')) {
      const quizId = data.replace('launch_grp:', '');
      ctx.answerCallbackQuery().catch(() => {});
      handleLaunchGroupQuiz(ctx, supabase, quizId).catch((err) => {
        console.error('Error in background group quiz execution:', err);
      });
      return;
    }

    // Group Authorization callbacks
    if (data.startsWith('grp_appr:')) {
      const parts = data.split(':');
      return handleGroupApprovalCallback(ctx, supabase, 'appr', parts[1], parts[2]);
    }
    if (data.startsWith('grp_rejc:')) {
      const parts = data.split(':');
      return handleGroupApprovalCallback(ctx, supabase, 'rejc', parts[1]);
    }
    if (data.startsWith('grp_rev:')) {
      const parts = data.split(':');
      const groupId = parseInt(parts[1], 10);
      const { revokeGroup } = await import('./db/queries');
      await revokeGroup(supabase, groupId);
      await ctx.answerCallbackQuery({ text: 'Group authorization revoked.' });
      return handleListGroupsCommand(ctx, supabase, env);
    }
    if (data.startsWith('grp_act:')) {
      const parts = data.split(':');
      const groupId = parseInt(parts[1], 10);
      const title = decodeURIComponent(parts[2] || 'Group');
      const { authorizeGroup } = await import('./db/queries');
      await authorizeGroup(supabase, groupId, title, ctx.from?.id);
      await ctx.answerCallbackQuery({ text: 'Group authorization approved.' });
      return handleListGroupsCommand(ctx, supabase, env);
    }

    // PDF Scorecard & Solutions Download
    if (data.startsWith('pdf_scorecard:')) {
      const quizId = data.replace('pdf_scorecard:', '');
      return handleDownloadPdfScorecard(ctx, supabase, quizId);
    }

    // Admin Broadcast callbacks
    if (data.startsWith('bcast_send:')) {
      const parts = data.split(':');
      return handleBroadcastCallback(ctx, supabase, env, 'send', parts[1], parts[2]);
    }
    if (data.startsWith('bcast_cancel:')) {
      const bcastId = data.replace('bcast_cancel:', '');
      return handleBroadcastCallback(ctx, supabase, env, 'cancel', '', bcastId);
    }

    // Group Quiz Scheduling callbacks
    if (data.startsWith('sch_pick:')) {
      const quizId = data.replace('sch_pick:', '');
      return handleSchedulePickQuiz(ctx, supabase, quizId);
    }
    if (data.startsWith('sch_set:')) {
      const parts = data.split(':');
      const quizId = parts[1];
      const minutes = parseInt(parts[2], 10);
      return handleScheduleSetTime(ctx, supabase, quizId, minutes);
    }
    if (data.startsWith('sch_preset:')) {
      const parts = data.split(':');
      const quizId = parts[1];
      const timeStr = `${parts[2]}:${parts[3]}`;
      return handleSchedulePresetTime(ctx, supabase, quizId, timeStr);
    }
    if (data.startsWith('sch_custom:')) {
      const quizId = data.replace('sch_custom:', '');
      return handleScheduleCustomPrompt(ctx, supabase, quizId);
    }
    if (data === 'sch_cancel') {
      return handleCancelScheduleCommand(ctx);
    }

    // Payment Approval callbacks
    if (data.startsWith('pay_appr:')) {
      const parts = data.split(':');
      return handlePaymentApprovalCallback(ctx, supabase, env, 'appr', parts[1]);
    }
    if (data.startsWith('pay_rejc:')) {
      const parts = data.split(':');
      return handlePaymentApprovalCallback(ctx, supabase, env, 'rejc', parts[1]);
    }

    // Force Channel Join Verification Callback
    if (data.startsWith('check_fsub:')) {
      const targetAction = data.replace('check_fsub:', '');
      const { isMember } = await checkChannelMembership(ctx, supabase, env);
      if (isMember) {
        await ctx.answerCallbackQuery({ text: '✅ Channel verified successfully!' });
        if (targetAction.startsWith('start_quiz:')) {
          const qId = targetAction.replace('start_quiz:', '');
          return handleStartQuiz(ctx, supabase, env, qId);
        }
        return handleQuizzesList(ctx, supabase);
      } else {
        await ctx.answerCallbackQuery({
          text: '❌ Mandatory channel membership not verified. Please subscribe and try again.',
          show_alert: true,
        });
      }
    }

    // 1v1 Live Candidate Duel callbacks
    if (data.startsWith('accept_duel:')) {
      return handleAcceptDuel(ctx, supabase);
    }
    if (data.startsWith('cancel_duel:')) {
      return handleCancelDuel(ctx);
    }
    if (data.startsWith('decline_duel:')) {
      return handleDeclineDuel(ctx);
    }
    if (data.startsWith('duel_count:')) {
      const count = parseInt(data.replace('duel_count:', ''), 10);
      return launchDuelWithCount(ctx, supabase, count);
    }
  });

  return bot;
}
