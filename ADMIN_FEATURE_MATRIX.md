# EXAMPLAYER BOT — ADMIN FEATURE MATRIX

Comprehensive mapping of every interactive element, frontend event handler, backend API endpoint, database operation, permission requirement, and automated test.

---

## 1. Global Navigation & Session Controls

| Interactive Element | Location / Component | Frontend Event Handler | Backend API Endpoint | Database Operation | Permission Level | Automated Test |
|---|---|---|---|---|---|---|
| **Telegram OTP Login** | `AuthScreen` | `_requestOtp()`, `_verifyOtp()` | `POST /api/admin/auth/request-otp`, `POST /api/admin/auth/login` | Queries `users` & `bot_settings`, verifies OTP | Admin / Root Admin | `tests/admin-api-integration.test.ts` |
| **Master Password Login** | `AuthScreen` | `_loginWithPassword()` | `POST /api/admin/auth/login` | Cryptographic HMAC validation | Master Key | `tests/admin-api-integration.test.ts` |
| **Session Auto-Restore** | `main.dart` | `_restoreSavedSession()` | `GET /api/admin/auth/verify` | HMAC-SHA256 signature verification | Active Token | `tests/admin-api-integration.test.ts` |
| **Logout** | Sidebar / Navbar | `onLogout()`, `_api.logout()` | `POST /api/admin/auth/logout` | Token invalidation & localStorage flush | Any Authenticated | `tests/admin-api-integration.test.ts` |
| **Theme Toggle (Dark/Light)**| Navbar | `_toggleTheme()` | Client Local State | Persisted to `localStorage` | All Users | Visual Smoke Check |
| **Sidebar Collapse/Expand** | Navbar | `_onToggleSidebar()` | Client Animated Container | Responsive width transition | All Users | Visual Smoke Check |
| **Mobile Drawer Menu** | Top Navbar | `_scaffoldKey.openDrawer()` | Material Scaffold Drawer | Navigation state switch | All Users | Visual Smoke Check |

---

## 2. Operational Overview (Dashboard)

| Interactive Element | Location / Component | Frontend Event Handler | Backend API Endpoint | Database Operation | Permission Level | Automated Test |
|---|---|---|---|---|---|---|
| **KPI: Total Registered Users** | `OverviewTab` | `_buildKpiSection()` | `GET /api/admin/stats` | `SELECT COUNT(*) FROM users` | Admin | `tests/admin-api-integration.test.ts` |
| **KPI: Total Examinations** | `OverviewTab` | `_buildKpiSection()` | `GET /api/admin/stats` | `SELECT COUNT(*) FROM quizzes` | Admin | `tests/admin-api-integration.test.ts` |
| **KPI: Total Questions** | `OverviewTab` | `_buildKpiSection()` | `GET /api/admin/stats` | `SELECT COUNT(*) FROM questions` | Admin | `tests/admin-api-integration.test.ts` |
| **KPI: Quiz Attempts Completed**| `OverviewTab` | `_buildKpiSection()` | `GET /api/admin/stats` | `SELECT COUNT(*) FROM quiz_attempts` | Admin | `tests/admin-api-integration.test.ts` |
| **Action: Create Test** | Quick Actions Card | `_openCreateTestDialog()` | `POST /api/admin/quizzes` | `INSERT INTO quizzes (...)` | Admin | `tests/admin-api-integration.test.ts` |
| **Action: Import JSON** | Quick Actions Card | `_openImportJsonDialog()` | `POST /api/admin/quizzes/import` | `INSERT INTO quizzes` & `questions` | Admin | `tests/admin-api-integration.test.ts` |
| **Action: Refresh Telemetry** | Quick Actions Card | `_loadAllData()` | `GET /api/admin/stats` | Non-blocking background sync | Admin | `tests/admin-api-integration.test.ts` |
| **Action: Restart Bot Core** | Hero Section Card | `_api.triggerBotControl('restart')`| `POST /api/admin/bot/controls` | Re-syncs admin cache & Telegram slash commands | Super Admin | `tests/admin-api-integration.test.ts` |
| **Table: View / Launch Quiz** | Recent Quizzes Card | `onLaunchQuiz()` | `POST /api/admin/groups/battle` | Triggers Telegram group battle | Admin | `tests/admin-api-integration.test.ts` |
| **Table: View Leaderboard** | Top Students Card | `onNavigateNav(4)` | `GET /api/admin/leaderboard/global` | `SELECT * FROM users ORDER BY total_score DESC` | Admin | `tests/admin-api-integration.test.ts` |

---

## 3. Hierarchical Folders & Category Management

| Interactive Element | Component | Frontend Event Handler | Backend API Endpoint | Database Operation | Permission Level | Automated Test |
|---|---|---|---|---|---|---|
| **Create Root Folder** | `FoldersTab` | `_openCreateFolderDialog()` | `POST /api/admin/folders` | `INSERT INTO quiz_folders (name)` | Admin | API Integration |
| **Create Subfolder** | `FoldersTab` | `_openCreateFolderDialog(parentId)` | `POST /api/admin/folders` | `INSERT INTO quiz_folders (parent_id)` | Admin | API Integration |
| **Rename Folder** | `FoldersTab` | `_openRenameFolderDialog()` | `PUT /api/admin/folders/:id` | `UPDATE quiz_folders SET name = ...` | Admin | API Integration |
| **Delete Folder** | `FoldersTab` | `_confirmDeleteFolder()` | `DELETE /api/admin/folders/:id` | `DELETE FROM quiz_folders` (cascade unassigns) | Admin | API Integration |
| **Duplicate Folder** | `FoldersTab` | `_duplicateFolder()` | `POST /api/admin/folders` | Clones folder record in `quiz_folders` | Admin | API Integration |
| **Move Quiz to Folder** | `FoldersTab` | `_moveQuizToFolder()` | `PUT /api/admin/quizzes/:id` | `UPDATE quizzes SET folder_id = ...` | Admin | API Integration |
| **Toggle Quiz Publish** | `FoldersTab` | `_toggleQuizPublish()` | `PUT /api/admin/quizzes/:id` | `UPDATE quizzes SET is_active = ...` | Admin | API Integration |

---

## 4. Tests & Questions Management

| Interactive Element | Component | Frontend Event Handler | Backend API Endpoint | Database Operation | Permission Level | Automated Test |
|---|---|---|---|---|---|---|
| **Create Quiz Paper** | `TestsQuestionsTab` | `_openCreateQuizDialog()` | `POST /api/admin/quizzes` | `INSERT INTO quizzes (...)` | Admin | API Integration |
| **Edit Quiz Paper** | `TestsQuestionsTab` | `_openEditQuizDialog()` | `PUT /api/admin/quizzes/:id` | `UPDATE quizzes SET ... WHERE id = ...` | Admin | API Integration |
| **Delete Quiz Paper** | `TestsQuestionsTab` | `_confirmDeleteQuiz()` | `DELETE /api/admin/quizzes/:id` | `DELETE FROM quizzes WHERE id = ...` | Admin | API Integration |
| **Duplicate Quiz Paper**| `TestsQuestionsTab` | `_duplicateQuiz()` | `POST /api/admin/quizzes/:id/duplicate`| Deep clones quiz + all questions | Admin | API Integration |
| **Add Single Question** | `TestsQuestionsTab` | `_openAddQuestionDialog()` | `POST /api/admin/questions` | `INSERT INTO questions (...)` | Admin | API Integration |
| **Bulk Import Questions**| `TestsQuestionsTab` | `_openBulkImportDialog()` | `POST /api/admin/quizzes/:id/questions/bulk` | Batch `INSERT INTO questions` | Admin | API Integration |
| **Delete Question** | `TestsQuestionsTab` | `_deleteQuestion()` | `DELETE /api/admin/questions/:id` | `DELETE FROM questions WHERE id = ...` | Admin | API Integration |
| **Search & Filter Quizzes**| `TestsQuestionsTab` | `_onSearchChanged()` | In-Memory / API Query | Filters active list by title/category | All | UI Filter Test |

---

## 5. Students & Candidates Directory

| Interactive Element | Component | Frontend Event Handler | Backend API Endpoint | Database Operation | Permission Level | Automated Test |
|---|---|---|---|---|---|---|
| **Search by Name/Username/ID**| `UsersTab` | `_onSearchChanged()` | `GET /api/admin/users?query=...` | `SELECT * FROM users WHERE ...` | Admin | API Integration |
| **Filter by Tier (All/Free/VIP)**| `UsersTab` | `_onFilterTier()` | `GET /api/admin/users?tier=...` | Filters on `is_premium` | Admin | API Integration |
| **Toggle VIP Scholar Status** | `UsersTab` | `_togglePremium()` | `POST /api/admin/users/:id/toggle-premium`| `UPDATE users SET is_premium = ...` | Super Admin / Admin | API Integration |
| **Send Telegram DM Message** | `UsersTab` | `_openSendMessageDialog()` | `POST /api/admin/users/:id/message` | Dispatches Telegram message via bot API | Admin | API Integration |
| **Reset Candidate Progress** | `UsersTab` | `_resetUserProgress()` | `POST /api/admin/users/:id/reset-progress`| Resets scores and clears attempts/mistakes | Admin | API Integration |
| **Persistent Ban / Block User**| `UsersTab` | `_toggleUserBlock()` | `POST /api/admin/users/:id/toggle-block` | `UPDATE users SET is_active = false` + memory set | Admin | API Integration |
| **Delete Candidate Account** | `UsersTab` | `_deleteUser()` | `DELETE /api/admin/users/:id` | `DELETE FROM users WHERE id = ...` | Super Admin | API Integration |
| **View Quiz Attempts History**| `UsersTab` | `_openAttemptsDialog()` | `GET /api/admin/users/:id/attempts` | `SELECT * FROM quiz_attempts WHERE user_id = ...` | Admin | API Integration |

---

## 6. Administrators Hub

| Interactive Element | Component | Frontend Event Handler | Backend API Endpoint | Database Operation | Permission Level | Automated Test |
|---|---|---|---|---|---|---|
| **Appoint New Administrator** | `AdminsTab` | `_openAddAdminDialog()` | `POST /api/admin/admins/add` | Adds Telegram ID to `bot_settings` & cache | Super Admin | API Integration |
| **Revoke Administrator** | `AdminsTab` | `_removeAdmin()` | `POST /api/admin/admins/remove` | Removes appointed admin (protects Root) | Super Admin | API Integration |
| **Update Role & Permissions** | `AdminsTab` | `_updateRole()` | `POST /api/admin/admins/update-role`| Updates permissions in `admin_hub_accounts` | Super Admin | API Integration |
| **View Audit Trail Logs** | `AdminsTab` | `_loadAuditLogs()` | `GET /api/admin/admins/hub` | `SELECT * FROM admin_audit_logs` | Admin | API Integration |

---

## 7. Community Groups & Live Battles

| Interactive Element | Component | Frontend Event Handler | Backend API Endpoint | Database Operation | Permission Level | Automated Test |
|---|---|---|---|---|---|---|
| **Authorize Community Group** | `BattlesTab` | `_openAuthorizeGroupDialog()`| `POST /api/admin/groups` | `INSERT INTO authorized_groups (...)` | Admin | API Integration |
| **Toggle Group Active State** | `BattlesTab` | `_toggleGroupActive()` | `PUT /api/admin/groups/:id` | `UPDATE authorized_groups SET is_active = ...` | Admin | API Integration |
| **Create Group Invite Link** | `BattlesTab` | `_createInviteLink()` | `POST /api/admin/groups/invite-link`| `bot.api.createChatInviteLink` | Admin | API Integration |
| **Launch Live Group Battle** | `BattlesTab` | `_launchQuizInGroup()` | `POST /api/admin/groups/battle` | Initiates realtime multi-user quiz battle | Admin | API Integration |
| **Revoke Group Authorization**| `BattlesTab` | `_deleteGroup()` | `DELETE /api/admin/groups/:id` | `DELETE FROM authorized_groups WHERE group_id = ...`| Admin | API Integration |

---

## 8. Announcement Broadcast Studio

| Interactive Element | Component | Frontend Event Handler | Backend API Endpoint | Database Operation | Permission Level | Automated Test |
|---|---|---|---|---|---|---|
| **Target Audience Selector** | `BroadcastTab` | `_onTargetChanged()` | Client State | Segments users/groups for delivery | Admin | UI Test |
| **Send Test Preview Broadcast**| `BroadcastTab` | `_sendTestBroadcast()` | `POST /api/admin/broadcast` (isTest: true) | Dispatches single test DM to admin chat | Admin | API Integration |
| **Send Live Broadcast Blast** | `BroadcastTab` | `_sendLiveBroadcast()` | `POST /api/admin/broadcast` | Controlled pacing (35ms batch) + DB history | Super Admin / Admin | API Integration |
| **Delete Broadcast Log** | `BroadcastTab` | `_deleteBroadcastRecord()` | `DELETE /api/admin/broadcast/:id` | Deletes campaign record | Admin | API Integration |

---

## 9. Payments & Financial Transactions

| Interactive Element | Component | Frontend Event Handler | Backend API Endpoint | Database Operation | Permission Level | Automated Test |
|---|---|---|---|---|---|---|
| **View Revenue Metrics** | `PaymentsTab` | `_loadPaymentData()` | `GET /api/admin/payments/stats` | Aggregates revenue, success, pending, failed | Admin | `tests/admin-api-integration.test.ts` |
| **View Transactions Ledger** | `PaymentsTab` | `_loadPaymentData()` | `GET /api/admin/transactions` | `SELECT * FROM payments` | Admin | `tests/admin-api-integration.test.ts` |
| **Process Transaction Refund** | `PaymentsTab` | `_refundTransaction()` | `POST /api/admin/transactions/refund`| `UPDATE payments SET status = 'Refunded'` | Super Admin | `tests/admin-api-integration.test.ts` |
| **Save Subscription Plan** | `PaymentsTab` | `_savePlanDialog()` | `POST /api/admin/plans` | `UPSERT INTO subscription_plans (...)` | Super Admin | `tests/admin-api-integration.test.ts` |
| **Update Gateway Config** | `PaymentsTab` | `_saveGateways()` | `POST /api/admin/payment-methods` | Saves gateway flags & keys | Super Admin | API Integration |
