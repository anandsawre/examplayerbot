import { Context, InlineKeyboard } from 'grammy';
import { SupabaseClient } from '@supabase/supabase-js';
import { getActiveQuizzes, getQuizById, getQuestionsForQuiz, isGroupAuthorized } from '../db/queries';

export async function handleGroupQuizCommand(ctx: Context, supabase: SupabaseClient) {
  if (!ctx.chat) return;
  const chatType = ctx.chat.type;

  // If used in private chat
  if (chatType === 'private') {
    await ctx.reply(
      `👥 *Group Quiz Feature*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Yeh feature Telegram Groups ke liye hai!\n\n` +
      `1. Bot ko apne Telegram Group me add kijiye.\n` +
      `2. Bot ko *Admin* permissions dijiye (Send Polls & Pin messages).\n` +
      `3. Group me type kijiye: \`/groupquiz\`\n\n` +
      `Aur pure group ke saath live countdown battle kheliye! 🎯`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  // Check if this group is authorized
  const isAuth = await isGroupAuthorized(supabase, ctx.chat.id);
  if (!isAuth) {
    await ctx.reply(
      `⚠️ *Group Not Authorized!*\n━━━━━━━━━━━━━━━━━━━━━\n` +
      `Is group ko Examplayer Bot use karne ki permission nahi hai.\n` +
      `Permission enable karne ke liye Bot Admin se sampark karein.`,
      { parse_mode: 'Markdown' }
    );
    return;
  }

  // Verify that the person who typed /groupquiz is an Admin in the group
  if (ctx.from) {
    try {
      const member = await ctx.getChatMember(ctx.from.id);
      const isAdmin = member.status === 'administrator' || member.status === 'creator';
      if (!isAdmin) {
        await ctx.reply('⚠️ Sirf Group Admins hi group quiz launch kar sakte hain.');
        return;
      }
    } catch {
      // Continue if permissions check fails
    }
  }

  const quizzes = await getActiveQuizzes(supabase);
  if (!quizzes || quizzes.length === 0) {
    await ctx.reply('⚠️ Abhi koi test active nahi hai.');
    return;
  }

  let text = `👥 *GROUP LIVE QUIZ LAUNCHER*\n`;
  text += `━━━━━━━━━━━━━━━━━━━━━\n`;
  text += `Kripya choose kijiye ki is group me kaun sa mock test live chalana hai:\n`;

  const keyboard = new InlineKeyboard();
  quizzes.forEach((quiz) => {
    keyboard.text(`🚀 ${quiz.title}`, `launch_grp:${quiz.id}`).row();
  });

  await ctx.reply(text, { parse_mode: 'Markdown', reply_markup: keyboard });
}

export async function handleLaunchGroupQuiz(
  ctx: Context,
  supabase: SupabaseClient,
  quizId: string
) {
  const chatId = ctx.chat?.id;
  if (!chatId) return;

  // Check if button clicker is admin
  if (ctx.from) {
    try {
      const member = await ctx.getChatMember(ctx.from.id);
      const isAdmin = member.status === 'administrator' || member.status === 'creator';
      if (!isAdmin) {
        await ctx.answerCallbackQuery({
          text: '⚠️ Sirf Group Admin test launch kar sakta hai.',
          show_alert: true,
        });
        return;
      }
    } catch {
      // Proceed
    }
  }

  const quiz = await getQuizById(supabase, quizId);
  if (!quiz) {
    await ctx.answerCallbackQuery({ text: 'Quiz nahi mila!', show_alert: true });
    return;
  }

  const questions = await getQuestionsForQuiz(supabase, quizId);
  if (!questions || questions.length === 0) {
    await ctx.answerCallbackQuery({ text: 'Is quiz me questions nahi hain!', show_alert: true });
    return;
  }

  await ctx.answerCallbackQuery({ text: 'Starting group quiz!' });

  // 1. Send 5-second countdown warning
  await ctx.editMessageText(
    `🔔 *GROUP QUIZ STARTING IN 5 SECONDS!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `📝 *Test:* ${quiz.title}\n` +
    `❓ *Total Questions:* \`${questions.length}\`\n` +
    `⏱️ *Time per Question:* \`${quiz.time_limit_seconds}s\`\n\n` +
    `⚡ Sabhi members screen par ready rahein! Confetti & Polls aane wale hain...`,
    { parse_mode: 'Markdown' }
  );

  await sleep(5000);

  // 2. Loop through questions and send as Telegram Native Quiz Polls
  for (let i = 0; i < questions.length; i++) {
    const q = questions[i];
    const options = Array.isArray(q.options) ? q.options : [];

    // Question poll title (Telegram poll limit is 300 chars for question)
    const pollQuestion = `[Q ${i + 1}/${questions.length}] ${q.question_text}`;

    // Ensure options don't exceed Telegram limit of 100 chars each
    const cleanOptions = options.map((opt) => opt.slice(0, 100));

    try {
      await ctx.api.sendPoll(chatId, pollQuestion.slice(0, 300), cleanOptions, {
        type: 'quiz',
        correct_option_id: q.correct_option_index,
        is_anonymous: false, // Let students see who got it right
        open_period: Math.min(600, Math.max(10, quiz.time_limit_seconds)),
        explanation: q.explanation ? q.explanation.slice(0, 200) : undefined,
      } as any);
    } catch (err: any) {
      console.error(`Error sending poll for question ${i + 1}:`, err);
    }

    // Wait for the poll countdown timer to finish before sending the next question
    await sleep((quiz.time_limit_seconds + 3) * 1000);
  }

  // 3. Quiz Completion Announcement
  const botUsername = ctx.me.username;
  const finishKeyboard = new InlineKeyboard()
    .url('👤 Check My Profile & Score', `https://t.me/${botUsername}?start=profile`)
    .url('📚 Take Solo Test', `https://t.me/${botUsername}?start=quiz_${quiz.id}`);

  await ctx.reply(
    `🏁 *GROUP QUIZ COMPLETE!*\n` +
    `━━━━━━━━━━━━━━━━━━━━━\n` +
    `🎉 *${quiz.title}* khatam ho chuka hai!\n\n` +
    `Sabhi participants ko badhai! Aap apna personal score aur accuracy check karne ke liye neeche button par tap karein:`,
    { parse_mode: 'Markdown', reply_markup: finishKeyboard }
  );
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
