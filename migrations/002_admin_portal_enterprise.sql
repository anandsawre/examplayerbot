-- =============================================================================
-- Migration 002: Enterprise Admin Portal Extensions
-- Adds: Payments, Subscription Plans, Admin Audit Logs, and Broadcast Campaigns
-- Target: Supabase / PostgreSQL
-- =============================================================================

-- 1. Subscription Plans Table
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id TEXT PRIMARY KEY, -- e.g. 'plan_free', 'plan_monthly', 'plan_quarterly', 'plan_yearly'
    name TEXT NOT NULL,
    price NUMERIC NOT NULL DEFAULT 0,
    billing_period TEXT NOT NULL DEFAULT 'month', -- 'lifetime', 'month', 'quarter', 'year'
    price_display TEXT,
    period_display TEXT,
    features JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'Active', -- 'Active', 'Disabled'
    is_popular BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed Default Subscription Plans if empty
INSERT INTO public.subscription_plans (id, name, price, billing_period, price_display, period_display, features, status, is_popular)
VALUES
    ('plan_free', 'Free Plan', 0, 'lifetime', '₹0', 'Lifetime', '["Limited tests", "Basic access", "Community support"]'::jsonb, 'Active', false),
    ('plan_monthly', 'Monthly Plan', 99, 'month', '₹99', 'per month', '["All mock tests", "Previous year papers", "1v1 quiz battles", "Priority support"]'::jsonb, 'Active', true),
    ('plan_quarterly', 'Quarterly Plan', 249, 'quarter', '₹249', 'for 3 months', '["All premium tests", "Detailed analytics", "No ads", "Priority support"]'::jsonb, 'Active', false),
    ('plan_yearly', 'Yearly Plan', 799, 'year', '₹799', 'per year', '["Everything in Quarterly", "Exclusive test series", "Early access to new tests", "Dedicated support"]'::jsonb, 'Active', false)
ON CONFLICT (id) DO NOTHING;

-- 2. Financial Payments & Transactions Ledger Table
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id TEXT NOT NULL UNIQUE,
    user_id BIGINT REFERENCES public.users(id) ON DELETE SET NULL,
    plan_id TEXT REFERENCES public.subscription_plans(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'INR',
    gateway TEXT NOT NULL DEFAULT 'UPI', -- 'UPI', 'Razorpay', 'Cashfree', 'PayU'
    status TEXT NOT NULL DEFAULT 'Pending', -- 'Success', 'Pending', 'Failed', 'Refunded'
    payment_method TEXT, -- 'UPI_APP', 'CREDIT_CARD', 'NETBANKING', 'MANUAL_VERIFY'
    customer_name TEXT,
    customer_phone TEXT,
    receipt_url TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    refund_reason TEXT,
    refunded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON public.payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_id ON public.payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON public.payments(created_at DESC);

-- 3. Administrative Audit Logs Table (Security & Governance)
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id BIGINT NOT NULL,
    admin_name TEXT NOT NULL,
    action TEXT NOT NULL, -- e.g. 'CREATE_QUIZ', 'DELETE_QUIZ', 'BAN_USER', 'REFUND_TRANSACTION'
    target_type TEXT, -- e.g. 'QUIZ', 'USER', 'PAYMENT', 'BROADCAST', 'SETTING'
    target_id TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_admin_id ON public.admin_audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON public.admin_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON public.admin_audit_logs(created_at DESC);

-- 4. Broadcast Campaigns Table
CREATE TABLE IF NOT EXISTS public.broadcast_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    media_url TEXT,
    buttons JSONB DEFAULT '[]'::jsonb,
    target TEXT NOT NULL DEFAULT 'all', -- 'all', 'users', 'groups', 'plans', 'specific'
    target_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'Delivered', -- 'Delivered', 'Failed', 'Sending', 'Scheduled'
    created_by BIGINT,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_broadcast_created_at ON public.broadcast_campaigns(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_broadcast_status ON public.broadcast_campaigns(status);

-- 5. Helper Views for Rapid Reporting
CREATE OR REPLACE VIEW public.v_admin_dashboard_metrics AS
SELECT
    (SELECT COUNT(*) FROM public.users) AS total_users,
    (SELECT COUNT(*) FROM public.users WHERE is_premium = true) AS premium_users,
    (SELECT COUNT(*) FROM public.quizzes) AS total_quizzes,
    (SELECT COUNT(*) FROM public.questions) AS total_questions,
    (SELECT COUNT(*) FROM public.quiz_attempts) AS total_attempts,
    (SELECT COUNT(*) FROM public.quiz_folders) AS total_folders,
    (SELECT COUNT(*) FROM public.authorized_groups WHERE is_active = true) AS active_groups,
    COALESCE((SELECT SUM(amount) FROM public.payments WHERE status = 'Success'), 0) AS total_revenue;
