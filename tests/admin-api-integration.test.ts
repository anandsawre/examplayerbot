import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import crypto from 'node:crypto';
import { handleAdminApiRequest } from '../src/admin/adminApi';
import { Env } from '../src/config';

describe('Admin API Comprehensive Integration Test Suite', () => {
  const mockEnv: Env = {
    BOT_TOKEN: '123456789:ABCdef-ghijk_lmnopqrstuvwxyz12345',
    SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_KEY: 'test-key',
    ADMIN_USER_ID: '613840274',
    ADMIN_PASSWORD: 'TestMasterPassword@2026',
  };

  // Mock Supabase Client for offline testing
  const mockSupabase: any = {
    from: (table: string) => {
      const result = { data: [{ id: 'mock-uuid', title: 'Test Quiz' }], count: 42, error: null };
      const builder: any = {
        then: (onfulfilled: any) => Promise.resolve(result).then(onfulfilled),
        select: () => builder,
        insert: (data: any) => Promise.resolve({ data: { id: 'mock-uuid', ...data }, error: null }),
        update: (data: any) => Promise.resolve({ data: { id: 'mock-uuid', ...data }, error: null }),
        delete: () => Promise.resolve({ data: null, error: null }),
        upsert: (data: any) => Promise.resolve({ data: Array.isArray(data) ? data : [data], error: null }),
        eq: () => builder,
        in: () => builder,
        gte: () => builder,
        order: () => builder,
        limit: () => Promise.resolve({ data: [], error: null }),
        single: () => Promise.resolve({ data: { id: 'mock-uuid', title: 'Test Quiz' }, error: null }),
      };
      return builder;
    },
  };

  const mockBot: any = {
    api: {
      getMe: () => Promise.resolve({ id: 5739131290, first_name: 'Examplayer Bot', username: 'Examplayer_bot' }),
      getWebhookInfo: () => Promise.resolve({ url: 'https://examplayerbot.onrender.com/webhook', pending_update_count: 0 }),
      getMyDescription: () => Promise.resolve({ description: 'India Best Quiz Bot' }),
      setMyCommands: () => Promise.resolve(true),
      sendMessage: () => Promise.resolve({ message_id: 101 }),
    },
  };

  // Helper to generate a valid HMAC token for tests
  function generateTestToken(): string {
    const ts = Date.now();
    const random = crypto.randomBytes(8).toString('hex');
    const secret = mockEnv.ADMIN_PASSWORD;
    const payload = `adm_${ts}_${random}`;
    const sig = crypto.createHmac('sha256', secret).update(payload).digest('hex').slice(0, 16);
    return `${payload}_${sig}`;
  }

  it('rejects unauthenticated requests to protected endpoints with 401 Unauthorized', async () => {
    const port = 3992;
    const server = http.createServer(async (req, res) => {
      process.env.ADMIN_PASSWORD = mockEnv.ADMIN_PASSWORD;
      const handled = await handleAdminApiRequest(req, res, mockSupabase, mockBot, mockEnv);
      if (!handled) {
        res.writeHead(404);
        res.end();
      }
    });

    await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', resolve));

    try {
      const res = await fetch(`http://127.0.0.1:${port}/api/admin/stats`);
      assert.equal(res.status, 401);
      const data = await res.json() as any;
      assert.equal(data.success, false);
      assert.match(data.error, /Unauthorized/i);
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  });

  it('authenticates valid HMAC signed admin token and serves /api/admin/auth/verify', async () => {
    const port = 3993;
    const server = http.createServer(async (req, res) => {
      process.env.ADMIN_PASSWORD = mockEnv.ADMIN_PASSWORD;
      const handled = await handleAdminApiRequest(req, res, mockSupabase, mockBot, mockEnv);
      if (!handled) {
        res.writeHead(404);
        res.end();
      }
    });

    await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', resolve));

    try {
      const validToken = generateTestToken();
      const res = await fetch(`http://127.0.0.1:${port}/api/admin/auth/verify`, {
        headers: {
          Authorization: `Bearer ${validToken}`,
        },
      });
      assert.equal(res.status, 200);
      const data = await res.json() as any;
      assert.equal(data.success, true);
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  });

  it('authenticates requests with x-admin-key master header', async () => {
    const port = 3994;
    const server = http.createServer(async (req, res) => {
      process.env.ADMIN_PASSWORD = mockEnv.ADMIN_PASSWORD;
      const handled = await handleAdminApiRequest(req, res, mockSupabase, mockBot, mockEnv);
      if (!handled) {
        res.writeHead(404);
        res.end();
      }
    });

    await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', resolve));

    try {
      const res = await fetch(`http://127.0.0.1:${port}/api/admin/stats`, {
        headers: {
          'x-admin-key': mockEnv.ADMIN_PASSWORD,
        },
      });
      assert.equal(res.status, 200);
      const data = await res.json() as any;
      assert.equal(data.success, true);
      assert.ok(data.stats);
      assert.equal(data.stats.totalUsers, 42);
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  });

  it('handles /api/admin/bot/controls restart action with zero downtime', async () => {
    const port = 3995;
    const server = http.createServer(async (req, res) => {
      process.env.ADMIN_PASSWORD = mockEnv.ADMIN_PASSWORD;
      const handled = await handleAdminApiRequest(req, res, mockSupabase, mockBot, mockEnv);
      if (!handled) {
        res.writeHead(404);
        res.end();
      }
    });

    await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', resolve));

    try {
      const res = await fetch(`http://127.0.0.1:${port}/api/admin/bot/controls`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-admin-key': mockEnv.ADMIN_PASSWORD,
        },
        body: JSON.stringify({ action: 'restart' }),
      });
      assert.equal(res.status, 200);
      const data = await res.json() as any;
      assert.equal(data.success, true);
      assert.match(data.message, /re-synced successfully/i);
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  });

  it('handles /api/admin/plans and /api/admin/transactions ledger endpoints', async () => {
    const port = 3996;
    const server = http.createServer(async (req, res) => {
      process.env.ADMIN_PASSWORD = mockEnv.ADMIN_PASSWORD;
      const handled = await handleAdminApiRequest(req, res, mockSupabase, mockBot, mockEnv);
      if (!handled) {
        res.writeHead(404);
        res.end();
      }
    });

    await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', resolve));

    try {
      // 1. Fetch Subscription Plans
      const plansRes = await fetch(`http://127.0.0.1:${port}/api/admin/plans`, {
        headers: { 'x-admin-key': mockEnv.ADMIN_PASSWORD },
      });
      assert.equal(plansRes.status, 200);
      const plansData = await plansRes.json() as any;
      assert.equal(plansData.success, true);
      assert.ok(Array.isArray(plansData.plans));
      assert.ok(plansData.plans.length >= 3);

      // 2. Fetch Transactions Ledger
      const txRes = await fetch(`http://127.0.0.1:${port}/api/admin/transactions`, {
        headers: { 'x-admin-key': mockEnv.ADMIN_PASSWORD },
      });
      assert.equal(txRes.status, 200);
      const txData = await txRes.json() as any;
      assert.equal(txData.success, true);
      assert.ok(Array.isArray(txData.transactions));
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  });
});
