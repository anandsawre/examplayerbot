-- =============================================================================
-- Migration 001: Initial Core Schema for Examplayer Telegram Bot
-- Target: Supabase / PostgreSQL
-- =============================================================================

-- 1. Users Table
CREATE TABLE IF NOT EXISTS public.users (
    id BIGINT PRIMARY KEY, -- Telegram User ID
    first_name TEXT NOT NULL,
    last_name TEXT,
    username TEXT,
    total_score NUMERIC DEFAULT 0,
    tests_completed INTEGER DEFAULT 0,
    streak_days INTEGER DEFAULT 1,
    longest_streak INTEGER DEFAULT 1,
    referrals_count INTEGER DEFAULT 0,
    referrer_id BIGINT,
    duel_rating INTEGER DEFAULT 1200,
    duel_wins INTEGER DEFAULT 0,
    duel_losses INTEGER DEFAULT 0,
    last_daily_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    is_premium BOOLEAN DEFAULT FALSE,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Hierarchical Examination Folders & Subfolders
CREATE TABLE IF NOT EXISTS public.quiz_folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    parent_id UUID REFERENCES public.quiz_folders(id) ON DELETE CASCADE,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_folders_parent_id ON public.quiz_folders(parent_id);

-- 3. Quizzes / Examinations Table
CREATE TABLE IF NOT EXISTS public.quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    folder_id UUID REFERENCES public.quiz_folders(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    total_questions INTEGER DEFAULT 5,
    marks_per_question NUMERIC DEFAULT 2.0,
    negative_marks NUMERIC DEFAULT 0.5,
    time_limit_seconds INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT TRUE,
    is_premium BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_quizzes_folder_id ON public.quizzes(folder_id);
CREATE INDEX IF NOT EXISTS idx_quizzes_category ON public.quizzes(category);

-- 4. Questions Table
CREATE TABLE IF NOT EXISTS public.questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    options JSONB NOT NULL,
    correct_option_index INTEGER NOT NULL,
    explanation TEXT,
    image_url TEXT,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_questions_quiz_id ON public.questions(quiz_id);

-- 5. Active Sessions (Serverless State Machine)
CREATE TABLE IF NOT EXISTS public.active_sessions (
    user_id BIGINT PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
    current_index INTEGER DEFAULT 0,
    question_ids JSONB NOT NULL,
    answers JSONB DEFAULT '[]'::jsonb,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Completed Quiz Attempts / Results History
CREATE TABLE IF NOT EXISTS public.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
    total_questions INTEGER NOT NULL,
    correct_count INTEGER DEFAULT 0,
    wrong_count INTEGER DEFAULT 0,
    skipped_count INTEGER DEFAULT 0,
    score NUMERIC DEFAULT 0,
    accuracy_percent NUMERIC DEFAULT 0,
    time_taken_seconds INTEGER DEFAULT 0,
    completed_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_attempts_quiz_id ON public.quiz_attempts(quiz_id);
CREATE INDEX IF NOT EXISTS idx_attempts_user_id ON public.quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_attempts_score ON public.quiz_attempts(score DESC);
CREATE INDEX IF NOT EXISTS idx_attempts_completed_at ON public.quiz_attempts(completed_at DESC);

-- 7. Authorized Groups (Access Control for Study Communities)
CREATE TABLE IF NOT EXISTS public.authorized_groups (
    group_id BIGINT PRIMARY KEY,
    group_title TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    authorized_by BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Candidate Mistake Vault & Weak Area Bank
CREATE TABLE IF NOT EXISTS public.user_mistakes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
    wrong_count INTEGER DEFAULT 1,
    is_resolved BOOLEAN DEFAULT FALSE,
    last_attempted_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_question_mistake UNIQUE (user_id, question_id)
);
CREATE INDEX IF NOT EXISTS idx_mistakes_user_id ON public.user_mistakes(user_id);
CREATE INDEX IF NOT EXISTS idx_mistakes_unresolved ON public.user_mistakes(user_id, is_resolved);

-- 9. Daily Question of the Day & Activity Drills
CREATE TABLE IF NOT EXISTS public.daily_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    attempt_date DATE NOT NULL DEFAULT CURRENT_DATE,
    question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE,
    is_correct BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_daily_attempt UNIQUE (user_id, attempt_date)
);
CREATE INDEX IF NOT EXISTS idx_daily_user_date ON public.daily_attempts(user_id, attempt_date);

-- 10. Candidate Referral & Rewards Program
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    referred_id BIGINT NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
    reward_granted BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals(referrer_id);

-- 11. 1v1 Live Candidate Duels & Face-Off Battles
CREATE TABLE IF NOT EXISTS public.duels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    creator_name TEXT NOT NULL,
    opponent_id BIGINT REFERENCES public.users(id) ON DELETE CASCADE,
    opponent_name TEXT,
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
    question_ids JSONB NOT NULL,
    creator_score NUMERIC DEFAULT 0,
    opponent_score NUMERIC DEFAULT 0,
    creator_time_ms INTEGER DEFAULT 0,
    opponent_time_ms INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending', -- 'pending', 'in_progress', 'completed', 'cancelled'
    winner_id BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_duels_creator ON public.duels(creator_id);
CREATE INDEX IF NOT EXISTS idx_duels_opponent ON public.duels(opponent_id);

-- 12. Dynamic Bot & Platform Settings
CREATE TABLE IF NOT EXISTS public.bot_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
