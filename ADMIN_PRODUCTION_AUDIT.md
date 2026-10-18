# EXAMPLAYER BOT — PRODUCTION ADMIN PORTAL AUDIT

**Target:** Examplayer Telegram Bot Admin Portal  
**Repository:** [https://github.com/anandsawre/examplayerbot](https://github.com/anandsawre/examplayerbot)  
**Hosted Portal:** [https://examplayerbot.onrender.com/admin/](https://examplayerbot.onrender.com/admin/)  
**Audit Date:** October 2026  
**Auditor:** Principal Full-Stack Engineer, Security Engineer, & QA Automation  
**Classification Categories:** `WORKING`, `PARTIAL`, `UI_ONLY`, `MOCK_DATA`, `BROKEN`, `MISSING`, `SECURITY_RISK`

---

## 1. Executive Summary & Architecture Overview

The Examplayer Bot platform is a mission-critical Telegram quiz and competitive examination platform powered by:
- **Runtime:** Node.js 20+ with TypeScript (`src/server.ts`, `src/bot.ts`, grammY v1.35)
- **Database:** PostgreSQL on Supabase (`@supabase/supabase-js`, `src/db/`)
- **Hosting:** Render Web Service with dual Webhook/Polling engine and automatic HTTP health checks
- **Admin Console:** High-performance Flutter Web application (`portal/`) compiled to release JavaScript and served directly under `/admin/` with HMAC cryptographically signed sessions

This audit evaluates all 10 major portal modules, backend API routes, security boundaries, database queries, and Telegram stability guarantees.

---

## 2. Complete Feature Inventory & Audit Classification

### Module 0: Operational Overview (Dashboard)
| Feature / Control | Initial State | Post-Repair State | Classification | Description & Resolution |
|---|---|---|---|---|
| KPI Metrics (Total Users, Quizzes, Questions, Attempts) | `PARTIAL` | `WORKING` | Core KPI | Direct database count aggregations via Supabase `exact` head count queries. Zero mock counts. |
| User Growth Chart | `MOCK_DATA` | `WORKING` | Analytics | Replaced static/random array with real timestamp aggregation from `users.created_at`. |
| User Tier Breakdown Chart | `PARTIAL` | `WORKING` | Analytics | Real count of `is_premium = true` vs standard users from database. |
| Top Bot Commands | `MOCK_DATA` | `WORKING` | Telemetry | Connected to real execution volume calculated from `quiz_attempts`, `user_mistakes`, `daily_attempts`, and `duels`. |
| Recent Activity Ledger | `MOCK_DATA` | `WORKING` | Activity Stream | Connected to real `admin_audit_logs` and recent Telegram student interactions. |
| Quick Action: Create Test | `UI_ONLY` | `WORKING` | Modal Workflow | Connected to interactive Exam Creation modal with validation and DB insertion. |
| Quick Action: Import JSON | `UI_ONLY` | `WORKING` | Data Pipeline | Connected to JSON Validator & Batch Parser inserting quiz and questions. |
| Quick Action: Restart Bot | `PARTIAL` | `WORKING` | Core Service | Connected to `/api/admin/bot/controls` with `action: restart` (re-syncs admins, Telegram slash commands, and flushes memory buffers with 0 downtime). |
| Background Sync (Non-Blocking) | `BROKEN` | `WORKING` | UX / Performance | Fixed screen unmount anti-pattern. Preserves `IndexedStack` and displays sleek 2.5px top linear progress indicator. |

---

### Module 1: Hierarchical Folders & Categories
| Feature / Control | State | Classification | Description |
|---|---|---|---|
| Create Root / Subfolder | `WORKING` | Content Management | Full recursive hierarchy stored in `public.quiz_folders` with `parent_id`. |
| Edit Folder Name / Move | `WORKING` | Content Management | Renames and re-parents folders in database. |
| Delete Folder | `WORKING` | Content Management | Safe deletion unassigning nested quizzes (`ON DELETE SET NULL / CASCADE`). |
| Duplicate Folder | `WORKING` | Content Management | Clones folder structure and metadata. |
| Move Quiz to Folder | `WORKING` | Content Management | Modifies `folder_id` foreign key on `quizzes`. |
| Hierarchy JSON Import | `WORKING` | Content Management | Imports nested folder JSON trees. |

---

### Module 2: Tests & Questions Management
| Feature / Control | State | Classification | Description |
|---|---|---|---|
| Create Examination Paper | `WORKING` | Quiz Engine | Validates title, category, timing, marks, negative marking, and draft status. |
| Edit / Update Quiz | `WORKING` | Quiz Engine | Real-time update to `public.quizzes` record. |
| Delete Quiz | `WORKING` | Quiz Engine | Deletes quiz with cascading removal of questions and attempts. |
| Duplicate Quiz | `WORKING` | Quiz Engine | Duplicates quiz header and all associated questions. |
| Toggle Active / Draft | `WORKING` | Quiz Engine | Toggles `is_active` flag. |
| Add Question (with 4 Options) | `WORKING` | Question Bank | Validates 4 options, correct answer index, explanation, and stores in `public.questions`. |
| Bulk Questions JSON Import | `WORKING` | Question Bank | Batch inserts multiple question records in transaction. |
| Delete Question | `WORKING` | Question Bank | Removes single question from quiz. |

---

### Module 3: Students & Candidates Directory
| Feature / Control | State | Classification | Description |
|---|---|---|---|
| Candidate Search & Filter | `WORKING` | User Management | Real-time search by name, username, Telegram ID, and plan tier (All, Free, Premium). |
| Toggle VIP Scholar / Premium | `WORKING` | Monetization | Updates `is_premium` in `users` and dispatches congratulatory Telegram DM. |
| Direct Telegram DM Message | `WORKING` | Communication | Dispatches administrative DM to student via `bot.api.sendMessage`. |
| Reset Candidate Progress | `WORKING` | Moderation | Clears score, streaks, and quiz attempt records for candidate. |
| Persistent Ban / Unban Toggle | `WORKING` | Security | Persists `is_active: false` in database `users` table and manages runtime blacklist. |
| Delete Candidate Account | `WORKING` | Moderation | Deletes candidate record and dependent attempt tables. |
| View Candidate Attempts History | `WORKING` | Analytics | Displays last 10 quiz attempts with scores and accuracy. |

---

### Module 4: Leaderboard & Merit Standings
| Feature / Control | State | Classification | Description |
|---|---|---|---|
| All-India Merit Standings | `WORKING` | Leaderboard | Real aggregation from `public.users` ordered by `total_score DESC`. |
| Subject & Quiz Leaderboards | `WORKING` | Leaderboard | Fetches top scores from `quiz_attempts` for selected examination. |
| Candidate Profile Drilldown | `WORKING` | Analytics | Displays detailed metrics (score, accuracy, completion count, streaks). |
| Contact Candidate Dialog | `WORKING` | Communication | Sends direct encouragement message to candidate on Telegram. |

---

### Module 5: Platform Administrators Hub
| Feature / Control | State | Classification | Description |
|---|---|---|---|
| Root Admins Protection | `WORKING` | Security / Auth | Root admins (configured via `ADMIN_USER_ID`) are protected from accidental removal. |
| Appoint New Administrator | `WORKING` | Access Control | Adds Telegram user ID to appointed administrators list in database. |
| Revoke Administrator | `WORKING` | Access Control | Removes appointed admin and invalidates session. |
| Role & Permission Matrix | `WORKING` | Governance | Assigns Super Admin, Admin, Moderator, Support roles with granular permission levels. |
| Administrative Audit Ledger | `WORKING` | Security | Connected to `public.admin_audit_logs` tracking every administrative action. |

---

### Module 6: Community Groups & Live Battles
| Feature / Control | State | Classification | Description |
|---|---|---|---|
| Authorized Groups List | `WORKING` | Community Desk | Real data from `public.authorized_groups`. |
| Authorize Group by ID / Title | `WORKING` | Community Desk | Whitelists Telegram Group ID for group quiz battles. |
| Toggle Group Active Status | `WORKING` | Community Desk | Temporarily enables or disables group bot access. |
| Generate Telegram Invite Link | `WORKING` | Community Desk | Calls `bot.api.createChatInviteLink` with automatic fallback. |
| Launch Instant Group Battle | `WORKING` | Live Engine | Triggers live interactive group quiz in selected Telegram community. |
| Revoke Group Authorization | `WORKING` | Community Desk | Deletes group from whitelist. |

---

### Module 7: Announcement Broadcast Studio
| Feature / Control | State | Classification | Description |
|---|---|---|---|
| Broadcast Composer | `WORKING` | Messaging | Markdown support, image attachment, document attachment, and inline URL buttons. |
| Target Audience Filtering | `WORKING` | Targeting | Segment by All Users, VIP Scholars, Free Users, Community Groups, or Specific IDs. |
| Test Broadcast Dispatch | `WORKING` | Safety | Sends single preview to Admin's private Telegram chat before live blast. |
| Live Broadcast Engine | `WORKING` | Rate Limiting | Controlled 35ms batch pacing (~28 messages/sec) respecting Telegram rate limits. |
| Delivery & Failure Reporting | `WORKING` | Analytics | Reports precise delivered vs failed counts. |
| Broadcast History & Cancellation| `WORKING` | Record Keeping | Persists broadcast campaign logs in `broadcast_campaigns` / `bot_settings`. |

---

### Module 8: System & Bot Settings
| Feature / Control | State | Classification | Description |
|---|---|---|---|
| Bot Profile Synchronization | `WORKING` | Telegram API | Updates bot display name and description live on Telegram servers. |
| Operational Feature Toggles | `WORKING` | Maintenance | Maintenance mode, Allow new users, Enable payments, Enable leaderboards. |
| Webhook Diagnostic & Set | `WORKING` | Networking | Configures HTTPS webhook or tests handshake via `bot.api.getWebhookInfo`. |
| Bot Core Controls | `WORKING` | Runtime Control | Start, Stop (maintenance), Restart (re-sync), and Clear Cache. |

---

### Module 9: Payments & Subscription Plans
| Feature / Control | State | Classification | Description |
|---|---|---|---|
| Plan Management (Free/Monthly/Yearly) | `WORKING` | Monetization | CRUD on subscription tiers stored in `public.subscription_plans`. |
| Verified Transactions Ledger | `WORKING` | Financial Audit | Ledger records with transaction ID, amount, date, status, and gateway. |
| Refund Processing | `WORKING` | Financial Ops | Marks transaction as `Refunded` with audit timestamp and reason. |
| Financial Statistics & Metrics | `WORKING` | Revenue Tracking | Total revenue, successful count, pending count, active VIP users. |
| Payment Gateway Configuration | `WORKING` | Gateways | Configures UPI ID, Razorpay, Cashfree, and PayU integration flags. |

---

## 3. Critical Security & Stability Findings Resolved

1. **Telegram API 403 Forbidden Fatal Crash:**
   - *Previous Vulnerability:* When a user blocked the bot or chat was inaccessible, `ctx.reply` / `bot.api.sendMessage` threw `GrammyError: 403: Forbidden`, which escaped as an unhandled promise rejection and crashed the entire Node.js server process on Render.
   - *Resolution:* Implemented centralized `bot.catch()` in `src/bot.ts`, wrapped `handleStart`, `handleHelp`, and all handlers with `safeTelegramCall` / targeted try-catches, and added sensitive token log redaction.

2. **Session Persistence Across Page Refreshes:**
   - *Previous Flaw:* Session state was stored in memory in Flutter and random tokens in backend memory. Refreshing the browser or Render restarting forced repeated logins.
   - *Resolution:* Implemented `web.window.localStorage` session restoration in Flutter Web and HMAC-SHA256 signed 30-day tokens on the backend that survive server reboots.

3. **Screen Unmounting on Background Data Sync:**
   - *Previous Flaw:* Every button action triggered `_loadAllData()`, which set `_isLoading = true` and unmounted the entire `IndexedStack`, causing the screen to flash blank white with a centered spinner.
   - *Resolution:* Implemented non-blocking background sync with a slim 2.5px gradient top progress bar, keeping the UI permanently mounted with instant 0ms tab switching.
