# EXAMPLAYER BOT — PRODUCTION DEPLOYMENT & OPERATIONS GUIDE

**Hosting Platform:** Render ([https://render.com](https://render.com))  
**Production URL:** [https://examplayerbot.onrender.com](https://examplayerbot.onrender.com)  
**Admin Portal:** [https://examplayerbot.onrender.com/admin/](https://examplayerbot.onrender.com/admin/)  
**Health Check Endpoint:** `https://examplayerbot.onrender.com/health`

---

## 1. Render Web Service Architecture

The application is deployed on Render as a **Web Service** running Node.js 20+.

```
Render Cloud
┌────────────────────────────────────────────────────────┐
│  Port 3000 / $PORT                                     │
│  ├─► /health          (HTTP 200 OK health check)       │
│  ├─► /webhook         (Telegram updates from Cloud)    │
│  ├─► /admin/          (Flutter Web Admin Console)      │
│  └─► /api/admin/*     (HMAC-protected REST APIs)       │
└────────────────────────────────────────────────────────┘
```

---

## 2. Service Settings & Build Commands

| Setting | Value | Description |
|---|---|---|
| **Environment** | `Node` | Runtime environment |
| **Build Command** | `npm install && npm run typecheck && npm run portal:build` | Installs packages, checks TypeScript types, and compiles Flutter Web release bundle to `portal/dist` |
| **Start Command** | `npm run start` (`tsx src/server.ts`) | Starts production HTTP server immediately for instant health checks |
| **Health Check Path**| `/health` | Ensures zero-downtime rolling deploys |
| **Auto-Deploy** | `Yes` (on push to `main`) | Deploys automatically upon Git commit |

---

## 3. Environment Variables Reference

Configure these in the **Render Dashboard -> Environment** tab.

> [!IMPORTANT]
> Never commit actual secret values to version control. The list below documents the required variables and their purpose.

| Variable Name | Required | Default / Example | Purpose |
|---|---|---|---|
| `BOT_TOKEN` | **Yes** | `123456789:ABCdef-ghijk_lmn...` | Telegram Bot API token from `@BotFather` |
| `SUPABASE_URL` | **Yes** | `https://xyzproject.supabase.co` | Supabase project REST API endpoint |
| `SUPABASE_KEY` | **Yes** | `eyJhbGciOiJIUzI1NiIsIn...` | Supabase `anon` / `service_role` API key |
| `ADMIN_USER_ID` | **Yes** | `613840274,747573651` | Comma-separated numerical Telegram User IDs of Root Super Admins |
| `ADMIN_PASSWORD`| **Yes** | `ExamPlayer@Admin2026` | Master password used for cryptographic HMAC token signing & fallback login |
| `RENDER_EXTERNAL_URL` | Optional | `https://examplayerbot.onrender.com` | Webhook base URL (Render sets this automatically) |
| `PORT` | Optional | `3000` | Port assigned by Render runtime |
| `UPI_ID` | Optional | `examplayer@upi` | Default UPI VPA ID displayed on payments tab |
| `PREMIUM_PRICE` | Optional | `99` | Default price for Scholar VIP monthly plan |

---

## 4. Zero-Downtime Deployment Procedure

1. **Verify Local Checks:**
   ```bash
   npm run typecheck
   npm test
   cd portal && flutter analyze
   ```
2. **Commit and Push to GitHub:**
   ```bash
   git add .
   git commit -m "feat: production hardening and enterprise audit updates"
   git push origin main
   ```
3. **Monitor Render Deployment:**
   - Render detects the push to `main` and initiates the build pipeline.
   - The old container continues serving traffic until the new container passes the `/health` check.
   - Once `/health` responds with `200 OK`, Render switches traffic instantly with zero downtime.

---

## 5. Post-Deployment Smoke Test Checklist

- [ ] **Health Endpoint:** Visit `https://examplayerbot.onrender.com/health` -> verify JSON response `{ "status": "ok", "service": "Examplayer Bot" }`.
- [ ] **Admin Portal Load:** Visit `https://examplayerbot.onrender.com/admin/` -> verify high-res branding and auto-login restore.
- [ ] **Telegram Bot Responsive:** Open Telegram chat `@Examplayer_bot` -> send `/start` -> verify dashboard response.
- [ ] **Slash Commands:** Type `/` in Telegram -> verify full command catalog displays.
- [ ] **Telemetry Latency:** In Admin Portal, verify DB latency and bot uptime indicators display real values.
