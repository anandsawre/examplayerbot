# EXAMPLAYER BOT — DATABASE MIGRATION GUIDE

**Database:** Supabase PostgreSQL  
**Directory:** `migrations/`  
**Execution Order:** Sequential (`001` -> `002`)

---

## 1. Migration Inventory & Execution Sequence

| Order | Migration File | Description | Destructive? | Downtime? |
|---|---|---|---|---|
| **001** | `migrations/001_initial_schema.sql` | Baseline tables (`users`, `quizzes`, `questions`, `active_sessions`, `quiz_attempts`, `authorized_groups`, `quiz_folders`, `user_mistakes`, `daily_attempts`, `referrals`, `duels`, `bot_settings`). | No (`IF NOT EXISTS`) | Zero Downtime |
| **002** | `migrations/002_admin_portal_enterprise.sql` | Enterprise portal tables (`subscription_plans`, `payments`, `admin_audit_logs`, `broadcast_campaigns`, and `v_admin_dashboard_metrics`). | No (`IF NOT EXISTS`) | Zero Downtime |

---

## 2. Step-by-Step Execution Instructions

### Option A: Via Supabase Web Dashboard (Recommended & Safest)
1. Log in to your [Supabase Dashboard](https://supabase.com/dashboard).
2. Select your Examplayer Bot project.
3. Open the **SQL Editor** from the left navigation menu.
4. Click **New Query**.
5. Copy and paste the contents of [`migrations/001_initial_schema.sql`](file:///f:/Examplayer%20Bot/migrations/001_initial_schema.sql).
6. Click **Run** (Ctrl + Enter). Confirm `Success. No rows returned`.
7. Click **New Query** again.
8. Copy and paste the contents of [`migrations/002_admin_portal_enterprise.sql`](file:///f:/Examplayer%20Bot/migrations/002_admin_portal_enterprise.sql).
9. Click **Run**. Confirm `Success. No rows returned`.

### Option B: Via Supabase CLI / psql
```bash
# Set your Supabase connection string
export DATABASE_URL="postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres"

# Execute migrations in order
psql "$DATABASE_URL" -f migrations/001_initial_schema.sql
psql "$DATABASE_URL" -f migrations/002_admin_portal_enterprise.sql
```

---

## 3. Post-Migration Verification Queries

Run the following SQL snippet in your Supabase SQL Editor to verify that all tables, views, and indexes exist:

```sql
SELECT 
    table_name, 
    (SELECT count(*) FROM information_schema.columns WHERE table_name = t.table_name) AS column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
```

**Expected Result (16 Core Tables):**
- `active_sessions`
- `admin_audit_logs`
- `authorized_groups`
- `bot_settings`
- `broadcast_campaigns`
- `daily_attempts`
- `duels`
- `payments`
- `questions`
- `quiz_attempts`
- `quiz_folders`
- `quizzes`
- `referrals`
- `subscription_plans`
- `user_mistakes`
- `users`

---

## 4. Rollback Strategy & Contingency Plans

All migrations use additive `CREATE TABLE IF NOT EXISTS` and `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` clauses, meaning they **never drop existing tables or delete existing user data**.

If a rollback of Migration 002 is ever required:
```sql
-- Safe Rollback of Enterprise Extensions (Only if required):
DROP VIEW IF EXISTS public.v_admin_dashboard_metrics;
DROP TABLE IF EXISTS public.broadcast_campaigns CASCADE;
DROP TABLE IF EXISTS public.admin_audit_logs CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.subscription_plans CASCADE;
```
*Note: The Node.js backend includes resilient in-memory and `bot_settings` fallbacks so that even if these tables are dropped, core bot features and existing endpoints will not crash.*
