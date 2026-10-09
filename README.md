# 🎓 Examplayer Bot - Serverless Telegram Quiz & Exam Platform

An advanced, production-ready, serverless Telegram Quiz & Exam Bot built with **grammY**, **TypeScript**, **Cloudflare Workers (Edge)**, and **Supabase (PostgreSQL)**.

---

## 🌟 Key Features

* ⚡ **100% Serverless & Ultra-Fast:** 0ms cold-start on Cloudflare Workers edge network.
* 💰 **100% Free Tier:** Handles up to 100,000 requests/day (~6,500 full tests/day) at ₹0 cost.
* ⏱️ **Real Exam Simulation:** Per-question timer tracking and instant feedback.
* ⚠️ **Negative Marking:** Accurate competitive exam marking (+Marks for correct, -Penalty for wrong, 0 for skip).
* 🎯 **Smart Anti-Cheat:** Question shuffling for every participant.
* 📊 **Official Scorecards:** Detailed results with accuracy %, total marks, time taken, and performance verdict.
* 🏆 **Leaderboards:** Top 10 Toppers for each test as well as Global Platform rankings.
* 👤 **Student Profiles & Streaks:** Tracks completed tests, score records, and study streaks.

---

## 📁 Project Structure

```
Examplayer Bot/
├── src/
│   ├── bot.ts             # GrammY bot initialization & routing
│   ├── config.ts          # Environment variables & configuration
│   ├── worker.ts          # Cloudflare Workers serverless webhook handler (Production)
│   ├── local.ts           # Local development runner with long-polling (Testing)
│   ├── types/
│   │   └── index.ts       # TypeScript interfaces (Quiz, Question, Attempt, User)
│   ├── db/
│   │   ├── schema.sql     # Supabase SQL script (Tables, indexes, sample quizzes)
│   │   ├── supabase.ts    # Supabase client setup
│   │   └── queries.ts     # PostgreSQL database query functions
│   ├── services/
│   │   ├── quizEngine.ts  # Formats questions, inline buttons, and scorecards
│   │   └── scoring.ts     # Negative marking & accuracy calculation engine
│   └── handlers/
│       ├── start.ts       # /start and /help command handlers
│       ├── quizzes.ts     # /quizzes test catalog & overview
│       ├── quizPlay.ts    # Interactive test taking, question navigation & answers
│       ├── leaderboard.ts # /leaderboard rankings
│       └── profile.ts     # /myprofile statistics
├── wrangler.toml          # Cloudflare Workers config
├── tsconfig.json          # TypeScript config
├── package.json           # Dependencies and scripts
└── .env.example           # Environment template
```

---

## 🚀 Quick Setup Guide (Step-by-Step)

### Step 1: Supabase Database Setup
1. Go to [database.new](https://database.new) and create a free Supabase project.
2. Open the **SQL Editor** tab from the left sidebar.
3. Open [`src/db/schema.sql`](file:///f:/Examplayer%20Bot/src/db/schema.sql), copy all contents, paste it into the SQL Editor, and click **RUN**.
   *(This creates all tables, indexes, and inserts sample tests with questions!)*
4. Go to **Project Settings** ➡️ **API**, and copy:
   - **Project URL** (`SUPABASE_URL`)
   - **anon key** or **service_role key** (`SUPABASE_KEY`)

### Step 2: Get Telegram Bot Token
1. Open Telegram and search for `@BotFather`.
2. Send `/newbot`, choose a name and username (e.g. `MyExamPlayerBot`).
3. Copy the HTTP API token provided by BotFather.

### Step 3: Local Testing (.env)
1. In `f:\Examplayer Bot`, copy `.env.example` to `.env`:
   ```env
   BOT_TOKEN=your_bot_token_here
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_KEY=your_supabase_key_here
   ```
2. Start the bot locally:
   ```bash
   npm run dev
   ```
3. Open Telegram and send `/start` to your bot. Take a test and view your results!

---

## 🌐 Production Deployment (Cloudflare Workers)

Deploying to Cloudflare Workers is free and takes under 2 minutes:

1. Login to Cloudflare:
   ```bash
   npx wrangler login
   ```
2. Deploy the bot:
   ```bash
   npx wrangler deploy
   ```
   Wrangler will output your worker URL, for example: `https://examplayer-bot.<your-subdomain>.workers.dev`

3. Set your production secrets on Cloudflare:
   ```bash
   npx wrangler secret put BOT_TOKEN
   npx wrangler secret put SUPABASE_URL
   npx wrangler secret put SUPABASE_KEY
   ```

4. Set Telegram Webhook:
   Open your browser or run this curl command (replace `<BOT_TOKEN>` and `<WORKER_URL>`):
   ```
   https://api.telegram.org/bot<BOT_TOKEN>/setWebhook?url=https://<WORKER_URL>/
   ```
   Your bot is now 100% serverless and running 24/7 globally at ₹0 cost!
