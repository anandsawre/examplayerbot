export function getAdminHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Examplayer — Administrative Operations Console</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Outfit:wght@500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-base: #080c14;
      --bg-surface: #0f172a;
      --bg-card: rgba(17, 24, 39, 0.75);
      --bg-card-hover: rgba(30, 41, 59, 0.85);
      --border-subtle: rgba(255, 255, 255, 0.08);
      --border-highlight: rgba(99, 102, 241, 0.3);
      --primary: #6366f1;
      --primary-hover: #4f46e5;
      --primary-glow: rgba(99, 102, 241, 0.25);
      --emerald: #10b981;
      --emerald-glow: rgba(16, 185, 129, 0.2);
      --amber: #f59e0b;
      --rose: #f43f5e;
      --cyan: #06b6d4;
      --text-main: #f8fafc;
      --text-muted: #94a3b8;
      --text-dark: #64748b;
      --radius-sm: 8px;
      --radius-md: 14px;
      --radius-lg: 20px;
      --transition-fast: 0.15s ease;
      --transition-smooth: 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: 'Inter', -apple-system, sans-serif;
      background-color: var(--bg-base);
      color: var(--text-main);
      min-height: 100vh;
      display: flex;
      overflow-x: hidden;
      background-image: 
        radial-gradient(circle at 15% 15%, rgba(99, 102, 241, 0.08) 0%, transparent 40%),
        radial-gradient(circle at 85% 85%, rgba(6, 182, 212, 0.06) 0%, transparent 40%);
      background-attachment: fixed;
    }

    /* Scrollbar */
    ::-webkit-scrollbar {
      width: 6px;
      height: 6px;
    }
    ::-webkit-scrollbar-track {
      background: var(--bg-base);
    }
    ::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.15);
      border-radius: 99px;
    }
    ::-webkit-scrollbar-thumb:hover {
      background: rgba(255, 255, 255, 0.25);
    }

    /* App Layout */
    #sidebar {
      width: 270px;
      background: rgba(15, 23, 42, 0.7);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border-right: 1px solid var(--border-subtle);
      display: flex;
      flex-direction: column;
      position: fixed;
      top: 0;
      bottom: 0;
      left: 0;
      z-index: 100;
    }

    #main-content {
      margin-left: 270px;
      flex: 1;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      padding: 28px 36px 60px;
      max-width: 1400px;
    }

    /* Brand Header */
    .brand-box {
      padding: 24px 22px;
      display: flex;
      align-items: center;
      gap: 12px;
      border-bottom: 1px solid var(--border-subtle);
    }
    .brand-logo {
      width: 38px;
      height: 38px;
      border-radius: 10px;
      background: linear-gradient(135deg, #6366f1, #8b5cf6);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      box-shadow: 0 4px 14px var(--primary-glow);
    }
    .brand-title {
      font-family: 'Outfit', sans-serif;
      font-weight: 800;
      font-size: 19px;
      letter-spacing: -0.5px;
      background: linear-gradient(135deg, #ffffff 30%, #a5b4fc 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .badge-admin {
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 0.5px;
      background: rgba(99, 102, 241, 0.15);
      color: #818cf8;
      border: 1px solid rgba(99, 102, 241, 0.3);
      padding: 2px 7px;
      border-radius: 99px;
      text-transform: uppercase;
    }

    /* Nav Links */
    .nav-list {
      list-style: none;
      padding: 18px 12px;
      display: flex;
      flex-direction: column;
      gap: 4px;
      flex: 1;
    }
    .nav-item {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 10px 14px;
      border-radius: var(--radius-sm);
      color: var(--text-muted);
      cursor: pointer;
      font-size: 14px;
      font-weight: 500;
      transition: all var(--transition-fast);
      user-select: none;
    }
    .nav-item:hover {
      background: rgba(255, 255, 255, 0.05);
      color: #fff;
    }
    .nav-item.active {
      background: linear-gradient(90deg, rgba(99, 102, 241, 0.15), rgba(99, 102, 241, 0.04));
      color: #a5b4fc;
      border-left: 3px solid var(--primary);
      font-weight: 600;
    }
    .nav-icon {
      font-size: 17px;
      width: 22px;
      text-align: center;
    }

    /* Sidebar Footer */
    .sidebar-footer {
      padding: 16px 20px;
      border-top: 1px solid var(--border-subtle);
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .live-status {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 12px;
      color: var(--emerald);
      font-weight: 500;
    }
    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--emerald);
      box-shadow: 0 0 8px var(--emerald);
    }
    .btn-logout {
      background: transparent;
      border: 1px solid var(--border-subtle);
      color: var(--text-muted);
      padding: 6px 12px;
      border-radius: var(--radius-sm);
      font-size: 12px;
      cursor: pointer;
      transition: all var(--transition-fast);
    }
    .btn-logout:hover {
      background: rgba(244, 63, 94, 0.15);
      color: #fda4af;
      border-color: rgba(244, 63, 94, 0.3);
    }

    /* Top Navigation / Topbar */
    .topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 30px;
    }
    .topbar-title h1 {
      font-family: 'Outfit', sans-serif;
      font-size: 26px;
      font-weight: 700;
      letter-spacing: -0.5px;
    }
    .topbar-title p {
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 3px;
    }
    .topbar-actions {
      display: flex;
      gap: 12px;
    }

    /* Buttons */
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 9px 16px;
      border-radius: var(--radius-sm);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      border: 1px solid transparent;
      transition: all var(--transition-fast);
      user-select: none;
    }
    .btn-primary {
      background: var(--primary);
      color: white;
      box-shadow: 0 4px 14px var(--primary-glow);
    }
    .btn-primary:hover {
      background: var(--primary-hover);
      transform: translateY(-1px);
    }
    .btn-secondary {
      background: rgba(255, 255, 255, 0.05);
      border-color: var(--border-subtle);
      color: var(--text-main);
    }
    .btn-secondary:hover {
      background: rgba(255, 255, 255, 0.1);
      border-color: rgba(255, 255, 255, 0.15);
    }
    .btn-emerald {
      background: rgba(16, 185, 129, 0.15);
      color: #34d399;
      border-color: rgba(16, 185, 129, 0.3);
    }
    .btn-emerald:hover {
      background: rgba(16, 185, 129, 0.25);
    }
    .btn-danger {
      background: rgba(244, 63, 94, 0.12);
      color: #fb7185;
      border-color: rgba(244, 63, 94, 0.25);
    }
    .btn-danger:hover {
      background: rgba(244, 63, 94, 0.22);
    }

    /* Cards & Glass Containers */
    .card {
      background: var(--bg-card);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-md);
      padding: 24px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
      transition: border-color var(--transition-fast);
    }
    .card:hover {
      border-color: rgba(255, 255, 255, 0.12);
    }

    /* Metric Grid */
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
      gap: 18px;
      margin-bottom: 28px;
    }
    .metric-card {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-md);
      padding: 20px 22px;
      position: relative;
      overflow: hidden;
      transition: all var(--transition-smooth);
    }
    .metric-card:hover {
      transform: translateY(-2px);
      border-color: var(--border-highlight);
    }
    .metric-label {
      font-size: 13px;
      color: var(--text-muted);
      font-weight: 500;
      margin-bottom: 8px;
    }
    .metric-value {
      font-family: 'Outfit', sans-serif;
      font-size: 32px;
      font-weight: 700;
      color: #ffffff;
      line-height: 1;
    }
    .metric-sub {
      font-size: 12px;
      color: var(--emerald);
      margin-top: 8px;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .metric-icon-bg {
      position: absolute;
      right: 18px;
      bottom: 16px;
      font-size: 36px;
      opacity: 0.12;
      pointer-events: none;
    }

    /* Data Tables */
    .table-container {
      overflow-x: auto;
      margin-top: 14px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 13px;
    }
    th {
      padding: 12px 16px;
      color: var(--text-muted);
      font-weight: 600;
      text-transform: uppercase;
      font-size: 11px;
      letter-spacing: 0.5px;
      border-bottom: 1px solid var(--border-subtle);
    }
    td {
      padding: 14px 16px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
      color: #e2e8f0;
    }
    tr:hover td {
      background: rgba(255, 255, 255, 0.02);
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      border-radius: 99px;
      font-size: 11px;
      font-weight: 600;
    }
    .badge-free {
      background: rgba(16, 185, 129, 0.12);
      color: #34d399;
      border: 1px solid rgba(16, 185, 129, 0.25);
    }
    .badge-premium {
      background: rgba(245, 158, 11, 0.12);
      color: #fbbf24;
      border: 1px solid rgba(245, 158, 11, 0.25);
    }
    .badge-root {
      background: rgba(99, 102, 241, 0.15);
      color: #a5b4fc;
      border: 1px solid rgba(99, 102, 241, 0.3);
    }

    /* Forms & Inputs */
    .form-group {
      margin-bottom: 18px;
    }
    .form-label {
      display: block;
      font-size: 13px;
      font-weight: 500;
      color: var(--text-muted);
      margin-bottom: 6px;
    }
    .form-control {
      width: 100%;
      background: rgba(15, 23, 42, 0.8);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-sm);
      padding: 10px 14px;
      color: #fff;
      font-size: 14px;
      font-family: inherit;
      outline: none;
      transition: all var(--transition-fast);
    }
    .form-control:focus {
      border-color: var(--primary);
      box-shadow: 0 0 0 3px var(--primary-glow);
    }
    textarea.form-control {
      resize: vertical;
      min-height: 90px;
    }

    /* File Upload Dropzone */
    .file-dropzone {
      border: 2px dashed rgba(99, 102, 241, 0.4);
      background: rgba(99, 102, 241, 0.05);
      border-radius: var(--radius-md);
      padding: 24px 20px;
      text-align: center;
      cursor: pointer;
      transition: all var(--transition-fast);
      user-select: none;
    }
    .file-dropzone:hover, .file-dropzone.dragover {
      border-color: var(--primary);
      background: rgba(99, 102, 241, 0.12);
      transform: translateY(-2px);
    }

    /* Modals */
    .modal-backdrop {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.75);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      z-index: 1000;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .modal-backdrop.open {
      display: flex;
    }
    .modal-box {
      background: #0f172a;
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: var(--radius-lg);
      width: 100%;
      max-width: 640px;
      max-height: 90vh;
      overflow-y: auto;
      padding: 28px;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
      animation: modalPop 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    }
    .modal-box-lg {
      max-width: 850px;
    }
    @keyframes modalPop {
      from { transform: scale(0.95); opacity: 0; }
      to { transform: scale(1); opacity: 1; }
    }
    .modal-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 22px;
      border-bottom: 1px solid var(--border-subtle);
      padding-bottom: 14px;
    }
    .modal-header h3 {
      font-family: 'Outfit', sans-serif;
      font-size: 20px;
      font-weight: 700;
    }
    .modal-close {
      background: transparent;
      border: none;
      color: var(--text-muted);
      font-size: 20px;
      cursor: pointer;
    }
    .modal-close:hover {
      color: #fff;
    }

    /* Toasts */
    #toast-container {
      position: fixed;
      bottom: 24px;
      right: 24px;
      z-index: 9999;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .toast {
      background: #1e293b;
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: var(--radius-sm);
      padding: 12px 18px;
      color: #fff;
      font-size: 13px;
      display: flex;
      align-items: center;
      gap: 10px;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4);
      animation: toastIn 0.25s ease;
    }
    .toast-success { border-left: 4px solid var(--emerald); }
    .toast-error { border-left: 4px solid var(--rose); }
    @keyframes toastIn {
      from { transform: translateY(20px); opacity: 0; }
      to { transform: translateY(0); opacity: 1; }
    }

    /* Login Screen Overlay */
    #login-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: var(--bg-base);
      background-image: radial-gradient(circle at center, rgba(99, 102, 241, 0.15) 0%, transparent 60%);
      z-index: 2000;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .login-card {
      width: 100%;
      max-width: 420px;
      background: rgba(15, 23, 42, 0.85);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: var(--radius-lg);
      padding: 36px 32px;
      box-shadow: 0 25px 60px rgba(0, 0, 0, 0.5);
      backdrop-filter: blur(20px);
      text-align: center;
    }
    .login-icon {
      width: 58px;
      height: 58px;
      background: linear-gradient(135deg, #6366f1, #a855f7);
      border-radius: 16px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 28px;
      margin: 0 auto 18px;
      box-shadow: 0 8px 24px var(--primary-glow);
    }
    .login-card h2 {
      font-family: 'Outfit', sans-serif;
      font-size: 24px;
      font-weight: 700;
      margin-bottom: 6px;
    }
    .login-card p {
      font-size: 13px;
      color: var(--text-muted);
      margin-bottom: 24px;
    }

    /* Math Formula Live Preview Box */
    .formula-preview {
      background: rgba(0, 0, 0, 0.3);
      border: 1px dashed rgba(255, 255, 255, 0.15);
      border-radius: var(--radius-sm);
      padding: 10px 14px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      color: #38bdf8;
      margin-top: 6px;
    }

    /* Responsive */
    @media (max-width: 900px) {
      #sidebar {
        width: 70px;
      }
      .brand-title, .badge-admin, .nav-item span, .sidebar-footer {
        display: none;
      }
      #main-content {
        margin-left: 70px;
        padding: 20px;
      }
    }
  </style>
</head>
<body>

  <!-- LOGIN SCREEN -->
  <div id="login-overlay">
    <div class="login-card">
      <div class="login-icon">🏛️</div>
      <h2>Examplayer Admin OS</h2>
      <p>Enter Master Secret Key or Telegram Admin ID to manage operations.</p>
      <form id="login-form">
        <div class="form-group" style="text-align: left;">
          <label class="form-label">Master Key / Admin ID</label>
          <input type="password" id="login-key" class="form-control" placeholder="Enter key (e.g. 747573651)" required autofocus>
        </div>
        <button type="submit" class="btn btn-primary" style="width: 100%; justify-content: center; padding: 12px;">
          Authenticate & Unlock Console ⚡
        </button>
      </form>
    </div>
  </div>

  <!-- SIDEBAR NAVIGATION -->
  <aside id="sidebar">
    <div class="brand-box">
      <div class="brand-logo">🏛️</div>
      <div>
        <div class="brand-title">EXAMPLAYER</div>
        <span class="badge-admin">Admin OS</span>
      </div>
    </div>

    <ul class="nav-list">
      <li class="nav-item active" onclick="switchTab('dashboard')">
        <span class="nav-icon">📊</span>
        <span>Dashboard</span>
      </li>
      <li class="nav-item" onclick="switchTab('folders')">
        <span class="nav-icon">📁</span>
        <span>Folders & Hierarchy</span>
      </li>
      <li class="nav-item" onclick="switchTab('quizzes')">
        <span class="nav-icon">📝</span>
        <span>Tests & Questions</span>
      </li>
      <li class="nav-item" onclick="switchTab('users')">
        <span class="nav-icon">👥</span>
        <span>Students Directory</span>
      </li>
      <li class="nav-item" onclick="switchTab('admins')">
        <span class="nav-icon">🛡️</span>
        <span>Admins Hub</span>
      </li>
      <li class="nav-item" onclick="switchTab('broadcast')">
        <span class="nav-icon">📢</span>
        <span>Broadcast Studio</span>
      </li>
      <li class="nav-item" onclick="switchTab('settings')">
        <span class="nav-icon">⚙️</span>
        <span>System Settings</span>
      </li>
    </ul>

    <div class="sidebar-footer">
      <div class="live-status">
        <span class="status-dot"></span>
        <span>Bot Live</span>
      </div>
      <button class="btn-logout" onclick="logout()">Logout</button>
    </div>
  </aside>

  <!-- MAIN VIEWPORT -->
  <main id="main-content">
    <div class="topbar">
      <div class="topbar-title">
        <h1 id="page-title">Operational Dashboard</h1>
        <p id="page-subtitle">Real-time candidate metrics, examinations directory and bot control.</p>
      </div>
      <div class="topbar-actions">
        <button class="btn btn-secondary" onclick="openImportModal()">📥 Import JSON Test</button>
        <button class="btn btn-primary" onclick="openCreateQuizModal()">➕ Create Test</button>
      </div>
    </div>

    <!-- TAB 1: DASHBOARD -->
    <div id="tab-dashboard" class="tab-content">
      <div class="metrics-grid">
        <div class="metric-card">
          <div class="metric-label">Total Candidates</div>
          <div class="metric-value" id="stat-users">0</div>
          <div class="metric-sub">👥 Registered students</div>
          <div class="metric-icon-bg">👥</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Scholar Pass (Premium)</div>
          <div class="metric-value" id="stat-premium" style="color: #fbbf24;">0</div>
          <div class="metric-sub">👑 Active subscribers</div>
          <div class="metric-icon-bg">👑</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Mock Tests Listed</div>
          <div class="metric-value" id="stat-quizzes">0</div>
          <div class="metric-sub">📝 In catalog</div>
          <div class="metric-icon-bg">📝</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Total Question Bank</div>
          <div class="metric-value" id="stat-questions" style="color: #38bdf8;">0</div>
          <div class="metric-sub">⚡ Curated questions</div>
          <div class="metric-icon-bg">⚡</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Tests Completed</div>
          <div class="metric-value" id="stat-attempts">0</div>
          <div class="metric-sub">🎯 Attempts evaluated</div>
          <div class="metric-icon-bg">🎯</div>
        </div>
      </div>

      <div class="card" style="margin-top: 10px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
          <h3 style="font-family: 'Outfit'; font-size: 18px;">Recent Mock Examinations</h3>
          <button class="btn btn-secondary" onclick="switchTab('quizzes')">View All Tests →</button>
        </div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Test Title</th>
                <th>Category</th>
                <th>Folder</th>
                <th>Questions</th>
                <th>Access Tier</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody id="dashboard-recent-quizzes">
              <tr><td colspan="6" style="text-align:center; color: var(--text-dark);">Loading examinations...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 2: FOLDERS & HIERARCHY -->
    <div id="tab-folders" class="tab-content" style="display: none;">
      <div class="card">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px;">
          <div>
            <h3 style="font-family: 'Outfit'; font-size: 19px;">Examination Folders & Categories</h3>
            <p style="font-size: 13px; color: var(--text-muted);">Organize your mock tests into hierarchical subject directories.</p>
          </div>
          <button class="btn btn-primary" onclick="openCreateFolderModal()">📁 Create New Folder</button>
        </div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Folder Name</th>
                <th>Folder ID</th>
                <th>Parent Directory</th>
                <th>Tests Inside</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody id="folders-table-body">
              <tr><td colspan="5" style="text-align: center;">Loading folder tree...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 3: QUIZZES & QUESTIONS -->
    <div id="tab-quizzes" class="tab-content" style="display: none;">
      <div class="card">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px;">
          <div>
            <h3 style="font-family: 'Outfit'; font-size: 19px;">Examinations Catalog & Papers</h3>
            <p style="font-size: 13px; color: var(--text-muted);">Create tests, edit questions, inspect formulas, or delete old papers.</p>
          </div>
          <div style="display:flex; gap:10px;">
            <button class="btn btn-secondary" onclick="openImportModal()">📥 Bulk JSON Import</button>
            <button class="btn btn-primary" onclick="openCreateQuizModal()">➕ Add Examination</button>
          </div>
        </div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Title</th>
                <th>Category</th>
                <th>Folder Location</th>
                <th>Questions</th>
                <th>Marks (+ / -)</th>
                <th>Time (sec)</th>
                <th>Tier</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody id="quizzes-table-body">
              <tr><td colspan="8" style="text-align:center;">Loading mock tests...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 4: STUDENTS DIRECTORY -->
    <div id="tab-users" class="tab-content" style="display: none;">
      <div class="card">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px;">
          <div>
            <h3 style="font-family: 'Outfit'; font-size: 19px;">Candidate Directory & Pass Management</h3>
            <p style="font-size: 13px; color: var(--text-muted);">Inspect candidate performance and grant/revoke Premium Scholar Passes.</p>
          </div>
          <input type="text" id="users-search" class="form-control" placeholder="Search candidate name or username..." style="max-width: 300px;" oninput="debounceUserSearch()">
        </div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Candidate ID</th>
                <th>Name</th>
                <th>Username</th>
                <th>Tests Completed</th>
                <th>Total Score</th>
                <th>Streak</th>
                <th>Scholar Pass</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody id="users-table-body">
              <tr><td colspan="8" style="text-align:center;">Loading candidates...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 5: ADMINS MANAGEMENT -->
    <div id="tab-admins" class="tab-content" style="display: none;">
      <div class="card" style="margin-bottom: 24px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px;">
          <div>
            <h3 style="font-family: 'Outfit'; font-size: 19px;">Platform Administrators</h3>
            <p style="font-size: 13px; color: var(--text-muted);">Users with full administrative rights to upload tests and manage students.</p>
          </div>
          <button class="btn btn-primary" onclick="openAddAdminModal()">🛡️ Appoint New Admin</button>
        </div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Telegram ID</th>
                <th>Name / Username</th>
                <th>Role / Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody id="admins-table-body">
              <tr><td colspan="4" style="text-align:center;">Loading admins list...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 6: BROADCAST STUDIO -->
    <div id="tab-broadcast" class="tab-content" style="display: none;">
      <div class="card">
        <h3 style="font-family: 'Outfit'; font-size: 19px; margin-bottom: 6px;">Announcement Broadcast Studio</h3>
        <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 20px;">Dispatch instant announcements and alerts to all registered candidates via Telegram Bot.</p>
        
        <form id="broadcast-form">
          <div class="form-group">
            <label class="form-label">Announcement Content (Supports Markdown: *bold*, _italics_, &#96;code&#96;)</label>
            <textarea id="broadcast-text" class="form-control" style="min-height: 140px;" placeholder="📢 Important Examination Announcement:&#10;&#10;New All-India UPSC Mock Test Paper 4 is now live! Attempt now via /quizzes." required></textarea>
          </div>
          <div style="background: rgba(99, 102, 241, 0.08); border: 1px solid rgba(99, 102, 241, 0.2); border-radius: var(--radius-sm); padding: 14px; margin-bottom: 18px;">
            <div style="font-weight: 600; font-size: 13px; color: #a5b4fc; margin-bottom: 4px;">⚠️ High-Priority Dispatch Notice:</div>
            <div style="font-size: 12px; color: var(--text-muted);">This message will be dispatched in asynchronous batches to all candidates in the database. Rate limits are handled automatically.</div>
          </div>
          <button type="submit" class="btn btn-primary" id="btn-broadcast">🚀 Dispatch Announcement Now</button>
        </form>
      </div>
    </div>

    <!-- TAB 7: SETTINGS -->
    <div id="tab-settings" class="tab-content" style="display: none;">
      <div class="card" style="max-width: 650px;">
        <h3 style="font-family: 'Outfit'; font-size: 19px; margin-bottom: 6px;">Global Platform Settings</h3>
        <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 24px;">Manage payment coordinates, tariff charges, and compulsory subscription channels.</p>
        
        <form id="settings-form">
          <div class="form-group">
            <label class="form-label">Settlement UPI VPA Address</label>
            <input type="text" id="setting-upi" class="form-control" placeholder="e.g. examplayer@okhdfcbank" required>
            <small style="color:var(--text-dark); font-size:11px;">Displayed on student invoice prompts when upgrading to Scholar Pass.</small>
          </div>
          <div class="form-group">
            <label class="form-label">Scholar Pass Registration Fee (₹)</label>
            <input type="number" id="setting-price" class="form-control" placeholder="99" required>
          </div>
          <div class="form-group">
            <label class="form-label">Mandatory Telegram Announcement Channel</label>
            <input type="text" id="setting-channel" class="form-control" placeholder="e.g. @ExamplayerAnnouncements (Leave blank to disable)">
            <small style="color:var(--text-dark); font-size:11px;">If configured, students must join this channel before tests unlock.</small>
          </div>
          <button type="submit" class="btn btn-primary">💾 Save Configuration</button>
        </form>
      </div>
    </div>
  </main>

  <!-- MODAL: CREATE / EDIT QUIZ -->
  <div id="modal-create-quiz" class="modal-backdrop">
    <div class="modal-box">
      <div class="modal-header">
        <h3>Create New Examination Paper</h3>
        <button class="modal-close" onclick="closeModal('modal-create-quiz')">✕</button>
      </div>
      <form id="create-quiz-form">
        <div class="form-group">
          <label class="form-label">Paper Title</label>
          <input type="text" id="cq-title" class="form-control" placeholder="e.g. UPSC Prelims Mock Paper 2026" required>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
          <div class="form-group">
            <label class="form-label">Subject Category</label>
            <input type="text" id="cq-category" class="form-control" placeholder="e.g. General Studies" required>
          </div>
          <div class="form-group">
            <label class="form-label">Folder Location</label>
            <select id="cq-folder" class="form-control">
              <option value="">📁 Directory Root (No folder)</option>
            </select>
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">Description / Syllabus</label>
          <textarea id="cq-desc" class="form-control" placeholder="Comprehensive test covering Indian Economy & Polity..."></textarea>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label">Marks Per Question</label>
            <input type="number" step="0.5" id="cq-marks" class="form-control" value="2.0" required>
          </div>
          <div class="form-group">
            <label class="form-label">Negative Penalty</label>
            <input type="number" step="0.1" id="cq-neg" class="form-control" value="0.5" required>
          </div>
          <div class="form-group">
            <label class="form-label">Time Per Question (sec)</label>
            <input type="number" id="cq-time" class="form-control" value="30" required>
          </div>
        </div>
        <div class="form-group" style="display:flex; align-items:center; gap:10px; margin-top:6px;">
          <input type="checkbox" id="cq-premium" style="width:18px; height:18px; accent-color: var(--primary);">
          <label for="cq-premium" style="font-size:13px; font-weight:500; cursor:pointer;">Require Premium Scholar Pass (Locked)</label>
        </div>
        <button type="submit" class="btn btn-primary" style="width: 100%; justify-content:center; margin-top:14px;">
          Create Examination Record 🚀
        </button>
      </form>
    </div>
  </div>

  <!-- MODAL: BULK JSON IMPORT -->
  <div id="modal-import" class="modal-backdrop">
    <div class="modal-box modal-box-lg">
      <div class="modal-header">
        <h3>Bulk JSON Examination Import</h3>
        <button class="modal-close" onclick="closeModal('modal-import')">✕</button>
      </div>
      <form id="import-form">
        <div class="form-group">
          <label class="form-label">Assign Target Folder</label>
          <select id="import-folder" class="form-control">
            <option value="">📁 Directory Root</option>
          </select>
        </div>

        <div class="form-group">
          <label class="form-label">Method 1: Select or Drag & Drop .JSON File from Computer</label>
          <div class="file-dropzone" id="json-dropzone" onclick="document.getElementById('json-file-input').click()">
            <input type="file" id="json-file-input" accept=".json,application/json" style="display:none;" onchange="handleFileSelect(event)">
            <div style="font-size: 34px; margin-bottom: 6px;">📄</div>
            <div style="font-weight: 600; font-size: 14px; color: #fff; margin-bottom: 4px;">Click to Choose JSON File, or Drag & Drop Here</div>
            <div style="font-size: 12px; color: var(--text-muted);" id="file-chosen-status">Select any .json examination paper</div>
          </div>
          <div id="import-preview-badge" style="display:none; margin-bottom: 14px; background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: var(--radius-sm); padding: 10px 14px; font-size: 12px; color: #34d399;"></div>
        </div>

        <div class="form-group">
          <label class="form-label">Method 2: Or Paste / Review JSON Text</label>
          <textarea id="import-json" class="form-control" style="min-height: 180px; font-family:'JetBrains Mono', monospace; font-size:12px;" placeholder='{
  "title": "General Science Challenge",
  "category": "Science",
  "is_premium": false,
  "marks_per_question": 2.0,
  "negative_marks": 0.5,
  "time_limit_seconds": 30,
  "questions": [
    {
      "question_text": "What is the chemical formula of Water?",
      "options": ["H2O", "CO2", "NaCl", "CH4"],
      "correct_option_index": 0,
      "explanation": "Water is composed of hydrogen and oxygen."
    }
  ]
}' required></textarea>
        </div>
        <button type="submit" class="btn btn-primary" style="width:100%; justify-content:center; padding:12px;">
          Import & Save to Supabase 🚀
        </button>
      </form>
    </div>
  </div>

  <!-- MODAL: CREATE FOLDER -->
  <div id="modal-create-folder" class="modal-backdrop">
    <div class="modal-box">
      <div class="modal-header">
        <h3>Create Examination Folder</h3>
        <button class="modal-close" onclick="closeModal('modal-create-folder')">✕</button>
      </div>
      <form id="create-folder-form">
        <div class="form-group">
          <label class="form-label">Folder Name</label>
          <input type="text" id="cf-name" class="form-control" placeholder="e.g. UPSC Civil Services" required>
        </div>
        <div class="form-group">
          <label class="form-label">Parent Folder (Optional for subfolder)</label>
          <select id="cf-parent" class="form-control">
            <option value="">📁 Root Level (Top Directory)</option>
          </select>
        </div>
        <button type="submit" class="btn btn-primary" style="width:100%; justify-content:center;">Create Folder 📁</button>
      </form>
    </div>
  </div>

  <!-- MODAL: ADD ADMIN -->
  <div id="modal-add-admin" class="modal-backdrop">
    <div class="modal-box">
      <div class="modal-header">
        <h3>Appoint New Platform Administrator</h3>
        <button class="modal-close" onclick="closeModal('modal-add-admin')">✕</button>
      </div>
      <form id="add-admin-form">
        <div class="form-group">
          <label class="form-label">Candidate Telegram User ID</label>
          <input type="number" id="aa-id" class="form-control" placeholder="e.g. 1234567890" required>
          <small style="color:var(--text-dark); font-size:11px;">User can get their numeric ID by sending /id to @userinfobot.</small>
        </div>
        <button type="submit" class="btn btn-primary" style="width:100%; justify-content:center;">Grant Admin Privileges 🛡️</button>
      </form>
    </div>
  </div>

  <!-- MODAL: QUESTIONS INSPECTOR DRAWER -->
  <div id="modal-questions" class="modal-backdrop">
    <div class="modal-box modal-box-lg">
      <div class="modal-header">
        <h3 id="mq-quiz-title">Test Questions Inspector</h3>
        <button class="modal-close" onclick="closeModal('modal-questions')">✕</button>
      </div>
      
      <div style="margin-bottom: 22px;">
        <h4 style="font-size: 15px; margin-bottom: 12px; color:#a5b4fc;">➕ Add Question to Paper</h4>
        <form id="add-question-form">
          <div class="form-group">
            <label class="form-label">Question Text</label>
            <input type="text" id="aq-text" class="form-control" placeholder="e.g. What is the value of acceleration due to gravity (g)?" oninput="updateFormulaPreview()" required>
            <div id="formula-preview-box" class="formula-preview" style="display:none;"></div>
          </div>
          <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-bottom:12px;">
            <input type="text" id="aq-opt-0" class="form-control" placeholder="Option A" required>
            <input type="text" id="aq-opt-1" class="form-control" placeholder="Option B" required>
            <input type="text" id="aq-opt-2" class="form-control" placeholder="Option C" required>
            <input type="text" id="aq-opt-3" class="form-control" placeholder="Option D" required>
          </div>
          <div style="display:grid; grid-template-columns: 1fr 2fr; gap:12px; margin-bottom:12px;">
            <div>
              <label class="form-label">Correct Option</label>
              <select id="aq-correct" class="form-control">
                <option value="0">Option A</option>
                <option value="1">Option B</option>
                <option value="2">Option C</option>
                <option value="3">Option D</option>
              </select>
            </div>
            <div>
              <label class="form-label">Detailed Explanation</label>
              <input type="text" id="aq-exp" class="form-control" placeholder="Standard gravity is 9.8 m/s²...">
            </div>
          </div>
          <button type="submit" class="btn btn-emerald">Insert Question ➕</button>
        </form>
      </div>

      <hr style="border:0; border-top:1px solid var(--border-subtle); margin:20px 0;">

      <h4 style="font-size: 15px; margin-bottom: 14px;">Existing Questions in this Paper (<span id="mq-count">0</span>)</h4>
      <div id="questions-list-container" style="display:flex; flex-direction:column; gap:12px; max-height:400px; overflow-y:auto;">
        <div style="text-align:center; color:var(--text-dark);">Loading questions...</div>
      </div>
    </div>
  </div>

  <!-- TOAST ALERTS CONTAINER -->
  <div id="toast-container"></div>

  <!-- CLIENT-SIDE APPLICATION SCRIPT -->
  <script>
    let authToken = localStorage.getItem('examplayer_admin_token') || '';
    let currentQuizIdForQuestions = '';
    let globalFolders = [];

    // Init App
    document.addEventListener('DOMContentLoaded', () => {
      if (authToken) {
        verifySession();
      } else {
        document.getElementById('login-overlay').style.display = 'flex';
      }
    });

    async function verifySession() {
      try {
        const res = await apiRequest('/api/admin/stats');
        if (res.success) {
          document.getElementById('login-overlay').style.display = 'none';
          loadDashboard();
        } else {
          logout();
        }
      } catch {
        logout();
      }
    }

    // Login Handler
    document.getElementById('login-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const key = document.getElementById('login-key').value;
      try {
        const res = await fetch('/api/admin/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ key }),
        });
        const data = await res.json();
        if (data.success && data.token) {
          authToken = data.token;
          localStorage.setItem('examplayer_admin_token', authToken);
          document.getElementById('login-overlay').style.display = 'none';
          showToast('Welcome back, Administrator!', 'success');
          loadDashboard();
        } else {
          showToast(data.error || 'Authentication rejected.', 'error');
        }
      } catch (err) {
        showToast('Login network error.', 'error');
      }
    });

    function logout() {
      authToken = '';
      localStorage.removeItem('examplayer_admin_token');
      document.getElementById('login-overlay').style.display = 'flex';
    }

    // Generic API Client
    async function apiRequest(endpoint, method = 'GET', body = null) {
      const opts = {
        method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': \`Bearer \${authToken}\`,
        },
      };
      if (body) opts.body = JSON.stringify(body);
      const res = await fetch(endpoint, opts);
      if (res.status === 401) {
        logout();
        throw new Error('Unauthorized');
      }
      return await res.json();
    }

    // Tab Navigation
    function switchTab(tabId) {
      document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
      document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));

      const target = document.getElementById('tab-' + tabId);
      if (target) target.style.display = 'block';

      // Update Nav active
      const idxMap = { dashboard: 0, folders: 1, quizzes: 2, users: 3, admins: 4, broadcast: 5, settings: 6 };
      const navItems = document.querySelectorAll('.nav-item');
      if (navItems[idxMap[tabId]]) navItems[idxMap[tabId]].classList.add('active');

      // Update Titles
      const titles = {
        dashboard: ['Operational Dashboard', 'Real-time candidate metrics, examinations directory and bot control.'],
        folders: ['Examination Folders & Directories', 'Hierarchical classification of mock tests and question categories.'],
        quizzes: ['Examinations Catalog & Papers', 'Create tests, inspect formulas, build questions or manage syllabus.'],
        users: ['Candidate Directory & Access Pass', 'Review registered students and grant Premium Scholar Passes.'],
        admins: ['Platform Administrators Hub', 'Manage primary and appointed bot administrators.'],
        broadcast: ['Announcement Broadcast Studio', 'Dispatch mass announcements and test notifications to students.'],
        settings: ['Global Platform Settings', 'Configure UPI payment VPA, tariff prices, and mandatory channels.']
      };
      if (titles[tabId]) {
        document.getElementById('page-title').innerText = titles[tabId][0];
        document.getElementById('page-subtitle').innerText = titles[tabId][1];
      }

      // Tab Specific Loaders
      if (tabId === 'dashboard') loadDashboard();
      if (tabId === 'folders') loadFolders();
      if (tabId === 'quizzes') loadQuizzes();
      if (tabId === 'users') loadUsers();
      if (tabId === 'admins') loadAdmins();
      if (tabId === 'settings') loadSettings();
    }

    // 1. DASHBOARD LOADER
    async function loadDashboard() {
      try {
        const statsRes = await apiRequest('/api/admin/stats');
        if (statsRes.success) {
          const s = statsRes.stats;
          document.getElementById('stat-users').innerText = s.totalUsers.toLocaleString();
          document.getElementById('stat-premium').innerText = s.premiumUsers.toLocaleString();
          document.getElementById('stat-quizzes').innerText = s.totalQuizzes.toLocaleString();
          document.getElementById('stat-questions').innerText = s.totalQuestions.toLocaleString();
          document.getElementById('stat-attempts').innerText = s.totalAttempts.toLocaleString();
        }

        const quizRes = await apiRequest('/api/admin/quizzes');
        if (quizRes.success) {
          const tbody = document.getElementById('dashboard-recent-quizzes');
          tbody.innerHTML = '';
          const recents = quizRes.quizzes.slice(0, 5);
          if (recents.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-dark);">No mock tests available. Click "+ Create Test" to begin.</td></tr>';
            return;
          }
          recents.forEach(q => {
            const tr = document.createElement('tr');
            tr.innerHTML = \`
              <td><strong>\${q.title}</strong></td>
              <td>\${q.category}</td>
              <td>📁 \${q.folder_name}</td>
              <td>\${q.total_questions} Qs</td>
              <td><span class="badge \${q.is_premium ? 'badge-premium' : 'badge-free'}">\${q.is_premium ? '🔒 PREMIUM' : '🟢 FREE'}</span></td>
              <td>
                <button class="btn btn-secondary" style="padding:4px 10px; font-size:11px;" onclick="openQuestionsDrawer('\${q.id}', '\${q.title.replace(/'/g, "\\\\'")}')">Questions</button>
              </td>
            \`;
            tbody.appendChild(tr);
          });
        }
      } catch (err) {
        console.error(err);
      }
    }

    // 2. FOLDERS LOADER
    async function loadFolders() {
      try {
        const res = await apiRequest('/api/admin/folders');
        if (res.success) {
          globalFolders = res.folders;
          populateFolderDropdowns(globalFolders);

          const tbody = document.getElementById('folders-table-body');
          tbody.innerHTML = '';
          if (globalFolders.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:var(--text-dark);">No folders created. Click "+ Create New Folder" to organize your tests.</td></tr>';
            return;
          }
          globalFolders.forEach(f => {
            const parentName = f.parent_id ? (globalFolders.find(p => p.id === f.parent_id)?.name || 'Parent Folder') : 'Directory Root';
            const tr = document.createElement('tr');
            tr.innerHTML = \`
              <td><strong>📁 \${f.name}</strong></td>
              <td><code style="font-size:11px; color:#818cf8;">\${f.id}</code></td>
              <td>\${parentName}</td>
              <td>\${f.quizCount || 0} Tests</td>
              <td>
                <button class="btn btn-danger" style="padding:4px 8px; font-size:11px;" onclick="deleteFolderPrompt('\${f.id}', '\${f.name.replace(/'/g, "\\\\'")}')">Delete</button>
              </td>
            \`;
            tbody.appendChild(tr);
          });
        }
      } catch (err) {
        showToast('Failed to load folders.', 'error');
      }
    }

    function populateFolderDropdowns(folders) {
      const selects = [document.getElementById('cq-folder'), document.getElementById('import-folder'), document.getElementById('cf-parent')];
      selects.forEach(sel => {
        if (!sel) return;
        const currentVal = sel.value;
        sel.innerHTML = '<option value="">📁 Directory Root (Top Level)</option>';
        folders.forEach(f => {
          const opt = document.createElement('option');
          opt.value = f.id;
          opt.innerText = '📁 ' + f.name;
          sel.appendChild(opt);
        });
        sel.value = currentVal;
      });
    }

    // 3. QUIZZES LOADER
    async function loadQuizzes() {
      try {
        const res = await apiRequest('/api/admin/quizzes');
        if (res.success) {
          const tbody = document.getElementById('quizzes-table-body');
          tbody.innerHTML = '';
          if (res.quizzes.length === 0) {
            tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; color:var(--text-dark);">No mock tests listed yet.</td></tr>';
            return;
          }
          res.quizzes.forEach(q => {
            const tr = document.createElement('tr');
            tr.innerHTML = \`
              <td><strong>\${q.title}</strong></td>
              <td>\${q.category}</td>
              <td>📁 \${q.folder_name}</td>
              <td>\${q.total_questions} Qs</td>
              <td>+\${q.marks_per_question} / -\${q.negative_marks}</td>
              <td>\${q.time_limit_seconds}s</td>
              <td><span class="badge \${q.is_premium ? 'badge-premium' : 'badge-free'}">\${q.is_premium ? '🔒 PREMIUM' : '🟢 FREE'}</span></td>
              <td>
                <button class="btn btn-secondary" style="padding:4px 8px; font-size:11px;" onclick="openQuestionsDrawer('\${q.id}', '\${q.title.replace(/'/g, "\\\\'")}')">Questions</button>
                <button class="btn btn-danger" style="padding:4px 8px; font-size:11px;" onclick="deleteQuizPrompt('\${q.id}', '\${q.title.replace(/'/g, "\\\\'")}')">Delete</button>
              </td>
            \`;
            tbody.appendChild(tr);
          });
        }
      } catch (err) {
        showToast('Failed to load examinations.', 'error');
      }
    }

    // 4. USERS LOADER
    let searchTimeout;
    function debounceUserSearch() {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(loadUsers, 300);
    }

    async function loadUsers() {
      const q = document.getElementById('users-search')?.value || '';
      try {
        const res = await apiRequest('/api/admin/users' + (q ? '?q=' + encodeURIComponent(q) : ''));
        if (res.success) {
          const tbody = document.getElementById('users-table-body');
          tbody.innerHTML = '';
          if (res.users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; color:var(--text-dark);">No candidate records matched.</td></tr>';
            return;
          }
          res.users.forEach(u => {
            const tr = document.createElement('tr');
            tr.innerHTML = \`
              <td><code>\${u.id}</code></td>
              <td><strong>\${u.first_name} \${u.last_name || ''}</strong></td>
              <td>\${u.username ? '@' + u.username : '—'}</td>
              <td>\${u.tests_completed} tests</td>
              <td>\${u.total_score} pts</td>
              <td>🔥 \${u.streak_days || 1}d</td>
              <td><span class="badge \${u.is_premium ? 'badge-premium' : 'badge-free'}">\${u.is_premium ? '👑 SCHOLAR PASS' : 'OPEN TIER'}</span></td>
              <td>
                <button class="btn \${u.is_premium ? 'btn-danger' : 'btn-emerald'}" style="padding:4px 10px; font-size:11px;" onclick="toggleUserPremium(\${u.id}, \${!u.is_premium})">
                  \${u.is_premium ? 'Revoke Pass' : '⭐ Grant Pass'}
                </button>
              </td>
            \`;
            tbody.appendChild(tr);
          });
        }
      } catch (err) {
        showToast('Failed to fetch candidates.', 'error');
      }
    }

    async function toggleUserPremium(userId, shouldBePremium) {
      try {
        const res = await apiRequest(\`/api/admin/users/\${userId}/toggle-premium\`, 'POST', { is_premium: shouldBePremium });
        if (res.success) {
          showToast(shouldBePremium ? 'Scholar Pass granted!' : 'Scholar Pass revoked.', 'success');
          loadUsers();
        }
      } catch {
        showToast('Failed to update status.', 'error');
      }
    }

    // 5. ADMINS LOADER
    async function loadAdmins() {
      try {
        const res = await apiRequest('/api/admin/admins');
        if (res.success) {
          const tbody = document.getElementById('admins-table-body');
          tbody.innerHTML = '';
          res.admins.forEach(adm => {
            const tr = document.createElement('tr');
            tr.innerHTML = \`
              <td><code>\${adm.id}</code></td>
              <td><strong>\${adm.name}</strong></td>
              <td><span class="badge \${adm.isRoot ? 'badge-root' : 'badge-premium'}">\${adm.isRoot ? '👑 PRIMARY OWNER' : '🛡️ APPOINTED ADMIN'}</span></td>
              <td>
                \${adm.isRoot ? '<span style="font-size:12px; color:var(--text-dark);">Permanent</span>' : \`<button class="btn btn-danger" style="padding:4px 8px; font-size:11px;" onclick="removeAdminPrompt('\${adm.id}')">Revoke Admin</button>\`}
              </td>
            \`;
            tbody.appendChild(tr);
          });
        }
      } catch (err) {
        showToast('Failed to load administrators.', 'error');
      }
    }

    async function removeAdminPrompt(userId) {
      if (!confirm(\`Revoke administrator rights from User ID \${userId}?\`)) return;
      try {
        const res = await apiRequest('/api/admin/admins/remove', 'POST', { userId });
        if (res.success) {
          showToast('Admin rights revoked.', 'success');
          loadAdmins();
        } else {
          showToast(res.error || 'Failed to remove admin.', 'error');
        }
      } catch {
        showToast('Error removing admin.', 'error');
      }
    }

    // 6. SETTINGS LOADER
    async function loadSettings() {
      try {
        const res = await apiRequest('/api/admin/settings');
        if (res.success) {
          document.getElementById('setting-upi').value = res.settings.upiId || '';
          document.getElementById('setting-price').value = res.settings.price || '';
          document.getElementById('setting-channel').value = res.settings.channel || '';
        }
      } catch (err) {
        showToast('Failed to load settings.', 'error');
      }
    }

    document.getElementById('settings-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        const upiId = document.getElementById('setting-upi').value;
        const price = document.getElementById('setting-price').value;
        const channel = document.getElementById('setting-channel').value;
        const res = await apiRequest('/api/admin/settings', 'POST', { upiId, price, channel });
        if (res.success) {
          showToast('Settings saved successfully! 💾', 'success');
        }
      } catch {
        showToast('Error saving settings.', 'error');
      }
    });

    // 7. BROADCAST HANDLER
    document.getElementById('broadcast-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const message = document.getElementById('broadcast-text').value;
      if (!confirm('Broadcast this announcement to all candidates in database?')) return;
      const btn = document.getElementById('btn-broadcast');
      btn.innerText = 'Dispatching Announcement... ⏳';
      btn.disabled = true;

      try {
        const res = await apiRequest('/api/admin/broadcast', 'POST', { message });
        if (res.success) {
          showToast(\`Dispatched to \${res.delivered} candidates (\${res.failed} skipped)!\`, 'success');
          document.getElementById('broadcast-text').value = '';
        } else {
          showToast(res.error || 'Broadcast failed.', 'error');
        }
      } catch {
        showToast('Error sending broadcast.', 'error');
      } finally {
        btn.innerText = '🚀 Dispatch Announcement Now';
        btn.disabled = false;
      }
    });

    // FORM MODAL HANDLERS
    document.getElementById('create-quiz-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const body = {
        title: document.getElementById('cq-title').value,
        category: document.getElementById('cq-category').value,
        folder_id: document.getElementById('cq-folder').value || null,
        description: document.getElementById('cq-desc').value,
        marks_per_question: Number(document.getElementById('cq-marks').value),
        negative_marks: Number(document.getElementById('cq-neg').value),
        time_limit_seconds: Number(document.getElementById('cq-time').value),
        is_premium: document.getElementById('cq-premium').checked,
      };
      try {
        const res = await apiRequest('/api/admin/quizzes', 'POST', body);
        if (res.success) {
          showToast('Examination created successfully!', 'success');
          closeModal('modal-create-quiz');
          loadQuizzes();
          loadDashboard();
        } else {
          showToast(res.error || 'Failed to create quiz.', 'error');
        }
      } catch {
        showToast('Error creating quiz.', 'error');
      }
    });

    document.getElementById('create-folder-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const name = document.getElementById('cf-name').value;
      const parentId = document.getElementById('cf-parent').value || null;
      try {
        const res = await apiRequest('/api/admin/folders', 'POST', { name, parentId });
        if (res.success) {
          showToast('Folder created! 📁', 'success');
          closeModal('modal-create-folder');
          loadFolders();
        }
      } catch {
        showToast('Error creating folder.', 'error');
      }
    });

    document.getElementById('add-admin-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const userId = document.getElementById('aa-id').value;
      try {
        const res = await apiRequest('/api/admin/admins/add', 'POST', { userId });
        if (res.success) {
          showToast('Administrator appointed successfully! 🛡️', 'success');
          closeModal('modal-add-admin');
          loadAdmins();
        } else {
          showToast(res.error || 'Failed to appoint admin.', 'error');
        }
      } catch {
        showToast('Error appointing admin.', 'error');
      }
    });

    function handleFileSelect(event) {
      const file = event.target.files && event.target.files[0];
      if (!file) return;
      processSelectedJsonFile(file);
    }

    function processSelectedJsonFile(file) {
      if (!file.name.toLowerCase().endsWith('.json') && file.type !== 'application/json') {
        showToast('Please select a valid .json file.', 'error');
        return;
      }
      const reader = new FileReader();
      reader.onload = (e) => {
        try {
          const content = e.target.result;
          const parsed = JSON.parse(content);
          document.getElementById('import-json').value = JSON.stringify(parsed, null, 2);
          
          const questionsCount = Array.isArray(parsed.questions) ? parsed.questions.length : 0;
          const statusEl = document.getElementById('file-chosen-status');
          if (statusEl) {
            statusEl.innerHTML = \`✅ <strong>\${file.name}</strong> (\${Math.round(file.size / 1024)} KB)\`;
            statusEl.style.color = '#34d399';
          }

          const badgeEl = document.getElementById('import-preview-badge');
          if (badgeEl) {
            badgeEl.style.display = 'block';
            badgeEl.innerHTML = \`✅ <strong>Ready:</strong> "\${parsed.title || 'Untitled'}" | 📚 \${questionsCount} Questions | Category: \${parsed.category || 'General'}\`;
          }

          showToast(\`Loaded \${file.name} (\${questionsCount} questions detected)!\`, 'success');
        } catch (err) {
          showToast('Invalid JSON file format: ' + err.message, 'error');
        }
      };
      reader.readAsText(file);
    }

    // Attach Dropzone Drag & Drop
    setTimeout(() => {
      const dropzone = document.getElementById('json-dropzone');
      if (dropzone) {
        ['dragenter', 'dragover'].forEach(eventName => {
          dropzone.addEventListener(eventName, (e) => {
            e.preventDefault();
            e.stopPropagation();
            dropzone.classList.add('dragover');
          }, false);
        });
        ['dragleave', 'drop'].forEach(eventName => {
          dropzone.addEventListener(eventName, (e) => {
            e.preventDefault();
            e.stopPropagation();
            dropzone.classList.remove('dragover');
          }, false);
        });
        dropzone.addEventListener('drop', (e) => {
          const dt = e.dataTransfer;
          const file = dt.files && dt.files[0];
          if (file) {
            processSelectedJsonFile(file);
          }
        }, false);
      }
    }, 500);

    document.getElementById('import-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        const jsonStr = document.getElementById('import-json').value;
        const parsed = JSON.parse(jsonStr);
        const targetFolder = document.getElementById('import-folder').value;
        if (targetFolder) parsed.folder_id = targetFolder;

        const res = await apiRequest('/api/admin/quizzes/import', 'POST', parsed);
        if (res.success) {
          showToast(\`Imported test with \${res.count} questions! 🎉\`, 'success');
          closeModal('modal-import');
          loadQuizzes();
          loadDashboard();
        } else {
          showToast(res.error || 'Import failed.', 'error');
        }
      } catch (err) {
        showToast('Invalid JSON syntax: ' + err.message, 'error');
      }
    });

    // QUESTIONS DRAWER
    async function openQuestionsDrawer(quizId, quizTitle) {
      currentQuizIdForQuestions = quizId;
      document.getElementById('mq-quiz-title').innerText = 'Questions for: ' + quizTitle;
      document.getElementById('modal-questions').classList.add('open');
      loadQuestionsList(quizId);
    }

    async function loadQuestionsList(quizId) {
      const container = document.getElementById('questions-list-container');
      container.innerHTML = '<div style="text-align:center; color:var(--text-dark);">Loading questions...</div>';
      try {
        const res = await apiRequest(\`/api/admin/quizzes/\${quizId}/questions\`);
        if (res.success) {
          document.getElementById('mq-count').innerText = res.questions.length;
          container.innerHTML = '';
          if (res.questions.length === 0) {
            container.innerHTML = '<div style="text-align:center; color:var(--text-dark); padding:20px;">No questions in this test yet. Add the first question using the form above!</div>';
            return;
          }
          res.questions.forEach((q, idx) => {
            const card = document.createElement('div');
            card.style.background = 'rgba(255, 255, 255, 0.03)';
            card.style.border = '1px solid rgba(255, 255, 255, 0.08)';
            card.style.borderRadius = 'var(--radius-sm)';
            card.style.padding = '12px 14px';
            card.style.display = 'flex';
            card.style.justifyContent = 'space-between';
            card.style.alignItems = 'flex-start';

            const optsHtml = q.options.map((opt, i) => \`
              <span style="display:inline-block; margin-right:8px; font-size:12px; \${i === q.correct_option_index ? 'color:#34d399; font-weight:600;' : 'color:var(--text-muted);'}">
                \${String.fromCharCode(65 + i)}: \${opt} \${i === q.correct_option_index ? '✓' : ''}
              </span>
            \`).join('');

            card.innerHTML = \`
              <div>
                <div style="font-weight:600; font-size:13px; margin-bottom:6px;">Q\${idx + 1}. \${q.question_text}</div>
                <div style="margin-bottom:4px;">\${optsHtml}</div>
                \${q.explanation ? \`<div style="font-size:11px; color:#94a3b8; font-style:italic;">💡 \${q.explanation}</div>\` : ''}
              </div>
              <button class="btn btn-danger" style="padding:4px 8px; font-size:11px;" onclick="deleteQuestion('\${q.id}')">Delete</button>
            \`;
            container.appendChild(card);
          });
        }
      } catch {
        container.innerHTML = '<div style="color:var(--rose);">Failed to load questions.</div>';
      }
    }

    document.getElementById('add-question-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      if (!currentQuizIdForQuestions) return;
      const body = {
        question_text: document.getElementById('aq-text').value,
        options: [
          document.getElementById('aq-opt-0').value,
          document.getElementById('aq-opt-1').value,
          document.getElementById('aq-opt-2').value,
          document.getElementById('aq-opt-3').value,
        ],
        correct_option_index: Number(document.getElementById('aq-correct').value),
        explanation: document.getElementById('aq-exp').value,
      };
      try {
        const res = await apiRequest(\`/api/admin/quizzes/\${currentQuizIdForQuestions}/questions\`, 'POST', body);
        if (res.success) {
          showToast('Question inserted! ➕', 'success');
          document.getElementById('add-question-form').reset();
          document.getElementById('formula-preview-box').style.display = 'none';
          loadQuestionsList(currentQuizIdForQuestions);
          loadQuizzes();
        }
      } catch {
        showToast('Error adding question.', 'error');
      }
    });

    async function deleteQuestion(questionId) {
      if (!confirm('Permanently delete this question?')) return;
      try {
        const res = await apiRequest(\`/api/admin/questions/\${questionId}\`, 'DELETE');
        if (res.success) {
          showToast('Question removed.', 'success');
          loadQuestionsList(currentQuizIdForQuestions);
          loadQuizzes();
        }
      } catch {
        showToast('Failed to delete question.', 'error');
      }
    }

    function updateFormulaPreview() {
      const text = document.getElementById('aq-text').value;
      const box = document.getElementById('formula-preview-box');
      if (text.includes('^') || text.includes('_') || text.includes('\\\\') || text.includes('$')) {
        box.style.display = 'block';
        box.innerText = 'Live Math Notation: ' + text;
      } else {
        box.style.display = 'none';
      }
    }

    // Modal Helpers
    function openCreateQuizModal() { document.getElementById('modal-create-quiz').classList.add('open'); }
    function openImportModal() {
      document.getElementById('modal-import').classList.add('open');
      const input = document.getElementById('json-file-input');
      if (input) input.value = '';
      const status = document.getElementById('file-chosen-status');
      if (status) {
        status.innerHTML = 'Select any .json examination paper';
        status.style.color = 'var(--text-muted)';
      }
      const badge = document.getElementById('import-preview-badge');
      if (badge) badge.style.display = 'none';
    }
    function openCreateFolderModal() { document.getElementById('modal-create-folder').classList.add('open'); }
    function openAddAdminModal() { document.getElementById('modal-add-admin').classList.add('open'); }
    function closeModal(id) { document.getElementById(id).classList.remove('open'); }

    async function deleteQuizPrompt(quizId, title) {
      if (!confirm(\`Permanently delete "\${title}" and all its questions?\`)) return;
      try {
        const res = await apiRequest(\`/api/admin/quizzes/\${quizId}\`, 'DELETE');
        if (res.success) {
          showToast('Test deleted.', 'success');
          loadQuizzes();
          loadDashboard();
        }
      } catch {
        showToast('Error deleting test.', 'error');
      }
    }

    async function deleteFolderPrompt(folderId, name) {
      if (!confirm(\`Delete folder "\${name}"? Tests inside will be moved to directory root.\`)) return;
      try {
        const res = await apiRequest(\`/api/admin/folders/\${folderId}\`, 'DELETE');
        if (res.success) {
          showToast('Folder deleted.', 'success');
          loadFolders();
        }
      } catch {
        showToast('Error deleting folder.', 'error');
      }
    }

    function showToast(msg, type = 'success') {
      const container = document.getElementById('toast-container');
      const el = document.createElement('div');
      el.className = 'toast toast-' + type;
      el.innerText = msg;
      container.appendChild(el);
      setTimeout(() => el.remove(), 4000);
    }
  </script>
</body>
</html>
`;
}
