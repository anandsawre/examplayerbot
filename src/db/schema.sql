-- ==========================================================
-- EXAMPLAYER BOT - SUPABASE DATABASE SCHEMA
-- Copy and paste this script into your Supabase SQL Editor and click RUN.
-- ==========================================================

-- 1. Users Table
CREATE TABLE IF NOT EXISTS public.users (
    id BIGINT PRIMARY KEY, -- Telegram User ID
    first_name TEXT NOT NULL,
    last_name TEXT,
    username TEXT,
    total_score NUMERIC DEFAULT 0,
    tests_completed INTEGER DEFAULT 0,
    streak_days INTEGER DEFAULT 1,
    is_premium BOOLEAN DEFAULT FALSE,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Quizzes / Tests Table
CREATE TABLE IF NOT EXISTS public.quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

-- Run these if updating an existing database:
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;
ALTER TABLE public.quizzes ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;

-- 2.1 Bot Settings (Dynamic In-Bot Admin Configuration)
CREATE TABLE IF NOT EXISTS public.bot_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Questions Table
CREATE TABLE IF NOT EXISTS public.questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    options JSONB NOT NULL, -- e.g. ["New Delhi", "Mumbai", "Kolkata", "Chennai"]
    correct_option_index INTEGER NOT NULL, -- 0 to 3
    explanation TEXT,
    image_url TEXT,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Active Sessions (Serverless State Management)
CREATE TABLE IF NOT EXISTS public.active_sessions (
    user_id BIGINT PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
    current_index INTEGER DEFAULT 0,
    question_ids JSONB NOT NULL, -- list of question IDs in this test run
    answers JSONB DEFAULT '[]'::jsonb, -- recorded answers
    started_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Completed Quiz Attempts / Results History
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

-- 6. Authorized Groups (Access Control for Groups)
CREATE TABLE IF NOT EXISTS public.authorized_groups (
    group_id BIGINT PRIMARY KEY, -- Telegram Group Chat ID (e.g. -100...)
    group_title TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    authorized_by BIGINT, -- Telegram Admin User ID
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for lightning fast queries
CREATE INDEX IF NOT EXISTS idx_questions_quiz_id ON public.questions(quiz_id);
CREATE INDEX IF NOT EXISTS idx_attempts_quiz_id ON public.quiz_attempts(quiz_id);
CREATE INDEX IF NOT EXISTS idx_attempts_user_id ON public.quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_attempts_score ON public.quiz_attempts(score DESC);
CREATE INDEX IF NOT EXISTS idx_users_score ON public.users(total_score DESC);

-- ==========================================================
-- SAMPLE DEMO DATA (Run this to have instant quizzes ready!)
-- ==========================================================

DO $$
DECLARE
    gk_quiz_id UUID;
    science_quiz_id UUID;
BEGIN
    -- Only insert if quizzes table is empty
    IF NOT EXISTS (SELECT 1 FROM public.quizzes LIMIT 1) THEN
        -- Insert Quiz 1: General Knowledge
        INSERT INTO public.quizzes (title, category, description, total_questions, marks_per_question, negative_marks, time_limit_seconds)
        VALUES ('India & World GK Challenge', 'General Knowledge', 'Test your knowledge on Indian geography, polity, and world history.', 3, 2.0, 0.5, 30)
        RETURNING id INTO gk_quiz_id;

        -- Questions for Quiz 1
        INSERT INTO public.questions (quiz_id, question_text, options, correct_option_index, explanation, order_index)
        VALUES
        (gk_quiz_id, 'Which is the largest fresh water lake in India?', '["Wular Lake", "Chilika Lake", "Sambhar Lake", "Dal Lake"]'::jsonb, 0, 'Wular Lake in Jammu and Kashmir is the largest freshwater lake in India.', 1),
        (gk_quiz_id, 'Who is known as the Father of the Indian Constitution?', '["Mahatma Gandhi", "Dr. B.R. Ambedkar", "Jawaharlal Nehru", "Sardar Patel"]'::jsonb, 1, 'Dr. B.R. Ambedkar was the Chairman of the Drafting Committee of the Constitution.', 2),
        (gk_quiz_id, 'What is the capital of Australia?', '["Sydney", "Melbourne", "Canberra", "Perth"]'::jsonb, 2, 'Canberra is the federal capital of Australia.', 3);

        -- Insert Quiz 2: Science & Tech
        INSERT INTO public.quizzes (title, category, description, total_questions, marks_per_question, negative_marks, time_limit_seconds)
        VALUES ('General Science & Everyday Physics', 'Science', 'Essential physics, chemistry and biology questions for competitive exams.', 3, 2.0, 0.5, 30)
        RETURNING id INTO science_quiz_id;

        -- Questions for Quiz 2
        INSERT INTO public.questions (quiz_id, question_text, options, correct_option_index, explanation, order_index)
        VALUES
        (science_quiz_id, 'Which gas is most abundant in the Earth atmosphere?', '["Oxygen", "Carbon Dioxide", "Nitrogen", "Argon"]'::jsonb, 2, 'Nitrogen accounts for approximately 78% of Earth atmosphere.', 1),
        (science_quiz_id, 'What is the chemical formula of common salt?', '["NaCl", "KCl", "NaOH", "HCl"]'::jsonb, 0, 'Sodium chloride (NaCl) is the chemical name for common table salt.', 2),
        (science_quiz_id, 'Which organelle is called the Powerhouse of the Cell?', '["Nucleus", "Ribosome", "Mitochondria", "Golgi body"]'::jsonb, 2, 'Mitochondria generates most of the chemical energy needed by the cell.', 3);
    END IF;
END $$;
