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
  <script>
    (function() {
      try {
        var t = localStorage.getItem('examplayer_admin_theme') || 'dark';
        document.documentElement.setAttribute('data-theme', t);
      } catch (e) {}
    })();
  </script>
  <style>
    :root, [data-theme="dark"] {
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
      --card-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
      --sidebar-bg: rgba(15, 23, 42, 0.75);
      --modal-bg: #0f172a;
      --modal-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
      --input-bg: rgba(15, 23, 42, 0.8);
      --login-card-bg: rgba(15, 23, 42, 0.85);
      --login-overlay-bg: #080c14;
      --toast-bg: #1e293b;
      --toast-color: #ffffff;
      --table-border: rgba(255, 255, 255, 0.04);
      --table-hover: rgba(255, 255, 255, 0.02);
      --callout-bg: rgba(99, 102, 241, 0.08);
      --callout-border: rgba(99, 102, 241, 0.2);
      --callout-title: #a5b4fc;
      --item-card-bg: rgba(255, 255, 255, 0.03);
      --item-card-border: rgba(255, 255, 255, 0.08);
      --code-bg: rgba(99, 102, 241, 0.1);
      --code-color: #818cf8;
      --scrollbar-thumb: rgba(255, 255, 255, 0.15);
      --scrollbar-thumb-hover: rgba(255, 255, 255, 0.25);
    }

    [data-theme="light"] {
      --bg-base: #f8fafc;
      --bg-surface: #ffffff;
      --bg-card: #ffffff;
      --bg-card-hover: #f1f5f9;
      --border-subtle: #e2e8f0;
      --border-highlight: rgba(99, 102, 241, 0.4);
      --primary: #4f46e5;
      --primary-hover: #4338ca;
      --primary-glow: rgba(79, 70, 229, 0.2);
      --emerald: #059669;
      --emerald-glow: rgba(5, 150, 105, 0.15);
      --amber: #d97706;
      --rose: #e11d48;
      --cyan: #0284c7;
      --text-main: #0f172a;
      --text-muted: #475569;
      --text-dark: #64748b;
      --card-shadow: 0 4px 20px -2px rgba(15, 23, 42, 0.06), 0 2px 6px -1px rgba(15, 23, 42, 0.03);
      --sidebar-bg: #ffffff;
      --modal-bg: #ffffff;
      --modal-shadow: 0 25px 50px -12px rgba(15, 23, 42, 0.15);
      --input-bg: #f8fafc;
      --login-card-bg: rgba(255, 255, 255, 0.98);
      --login-overlay-bg: #f1f5f9;
      --toast-bg: #ffffff;
      --toast-color: #0f172a;
      --table-border: #f1f5f9;
      --table-hover: #f8fafc;
      --callout-bg: #eef2ff;
      --callout-border: #c7d2fe;
      --callout-title: #4338ca;
      --item-card-bg: #f8fafc;
      --item-card-border: #e2e8f0;
      --code-bg: #f1f5f9;
      --code-color: #4338ca;
      --scrollbar-thumb: #cbd5e1;
      --scrollbar-thumb-hover: #94a3b8;
    }

    [data-theme="light"] body {
      background-image: 
        radial-gradient(circle at 15% 15%, rgba(99, 102, 241, 0.05) 0%, transparent 40%),
        radial-gradient(circle at 85% 85%, rgba(6, 182, 212, 0.04) 0%, transparent 40%);
    }

    [data-theme="light"] .brand-title {
      background: linear-gradient(135deg, #0f172a 30%, #4338ca 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    [data-theme="light"] #sidebar {
      border-right: 1px solid #e2e8f0;
      box-shadow: 2px 0 12px rgba(0, 0, 0, 0.03);
    }

    [data-theme="light"] .nav-item:hover {
      background: #f1f5f9;
      color: #0f172a;
    }

    [data-theme="light"] .nav-item.active {
      background: linear-gradient(90deg, rgba(79, 70, 229, 0.1), rgba(79, 70, 229, 0.02));
      color: #4f46e5;
    }

    [data-theme="light"] .btn-secondary {
      background: #ffffff;
      border-color: #cbd5e1;
      color: #1e293b;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
    }

    [data-theme="light"] .btn-secondary:hover {
      background: #f1f5f9;
      border-color: #94a3b8;
    }

    [data-theme="light"] .form-control {
      background: #ffffff;
      border-color: #cbd5e1;
      color: #0f172a;
    }

    [data-theme="light"] .form-control:focus {
      background: #ffffff;
      border-color: #4f46e5;
      box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.15);
    }

    [data-theme="light"] th {
      background: #f8fafc;
      color: #64748b;
      border-bottom: 1px solid #cbd5e1;
    }

    [data-theme="light"] td {
      color: #1e293b;
      border-bottom: 1px solid #e2e8f0;
    }

    [data-theme="light"] tr:hover td {
      background: #f8fafc;
    }

    [data-theme="light"] .metric-value {
      color: #0f172a;
    }

    [data-theme="light"] .metric-icon-bg {
      opacity: 0.05;
    }

    [data-theme="light"] .modal-box {
      border-color: #cbd5e1;
    }

    [data-theme="light"] .modal-close {
      color: #64748b;
    }

    [data-theme="light"] .modal-close:hover {
      color: #0f172a;
    }

    [data-theme="light"] .file-dropzone {
      background: rgba(79, 70, 229, 0.03);
      border-color: rgba(79, 70, 229, 0.35);
    }

    [data-theme="light"] .file-dropzone:hover,
    [data-theme="light"] .file-dropzone.dragover {
      background: rgba(79, 70, 229, 0.08);
      border-color: var(--primary);
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
      background: var(--sidebar-bg);
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
      box-shadow: var(--card-shadow);
      transition: border-color var(--transition-fast), background var(--transition-smooth);
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
      box-shadow: var(--card-shadow);
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
      color: var(--text-main);
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
      border-bottom: 1px solid var(--table-border);
      color: var(--text-main);
    }
    tr:hover td {
      background: var(--table-hover);
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
      background: var(--input-bg);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-sm);
      padding: 10px 14px;
      color: var(--text-main);
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
      background: var(--modal-bg);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-lg);
      width: 100%;
      max-width: 640px;
      max-height: 90vh;
      overflow-y: auto;
      padding: 28px;
      box-shadow: var(--modal-shadow);
      color: var(--text-main);
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
      background: var(--toast-bg);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-sm);
      padding: 12px 18px;
      color: var(--toast-color);
      font-size: 13px;
      display: flex;
      align-items: center;
      gap: 10px;
      box-shadow: var(--modal-shadow);
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
      background: var(--login-overlay-bg);
      background-image: radial-gradient(circle at center, rgba(99, 102, 241, 0.12) 0%, transparent 60%);
      z-index: 2000;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .login-card {
      width: 100%;
      max-width: 420px;
      background: var(--login-card-bg);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-lg);
      padding: 36px 32px;
      box-shadow: var(--modal-shadow);
      backdrop-filter: blur(20px);
      text-align: center;
      position: relative;
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

    .question-item-card {
      background: var(--item-card-bg);
      border: 1px solid var(--item-card-border);
      border-radius: var(--radius-sm);
      padding: 12px 14px;
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 8px;
      transition: background var(--transition-fast), border-color var(--transition-fast);
    }
    .broadcast-target-card {
      display: flex;
      align-items: center;
      gap: 10px;
      background: var(--item-card-bg);
      border: 1px solid var(--border-subtle);
      padding: 12px 14px;
      border-radius: var(--radius-sm);
      cursor: pointer;
      transition: all var(--transition-fast);
    }
    .broadcast-target-card:hover {
      border-color: var(--primary);
    }
    .info-callout {
      background: var(--callout-bg);
      border: 1px solid var(--callout-border);
      border-radius: var(--radius-sm);
      padding: 14px;
      margin-bottom: 18px;
    }
    .auth-tab-bar {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
      background: rgba(0, 0, 0, 0.3);
      padding: 4px;
      border-radius: var(--radius-sm);
      margin-bottom: 22px;
    }
    [data-theme="light"] .auth-tab-bar {
      background: #f1f5f9;
      border: 1px solid #e2e8f0;
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

  <!-- DUAL-MODE LOGIN SCREEN -->
  <div id="login-overlay">
    <div class="login-card">
      <button type="button" class="btn btn-secondary" onclick="toggleTheme()" title="Switch Light/Dark Theme" style="position: absolute; top: 14px; right: 14px; padding: 6px 10px; font-size: 13px; border-radius: 99px;">
        <span class="theme-switch-icon">☀️</span>
      </button>
      <div class="login-icon">🏛️</div>
      <h2>Examplayer Admin OS</h2>
      <p style="margin-bottom: 18px;">Secure Authentication for Platform Administrators</p>

      <!-- Auth Method Switcher Tabs -->
      <div class="auth-tab-bar">
        <button type="button" id="auth-tab-otp" class="btn btn-secondary" style="justify-content: center; font-size: 12px; background: var(--primary); color: #fff;" onclick="switchAuthMode('otp')">
          📲 Telegram OTP
        </button>
        <button type="button" id="auth-tab-pass" class="btn btn-secondary" style="justify-content: center; font-size: 12px;" onclick="switchAuthMode('password')">
          🔑 Master Password
        </button>
      </div>

      <!-- MODE 1: TELEGRAM OTP LOGIN -->
      <div id="auth-mode-otp">
        <!-- Step 1: Request OTP -->
        <form id="otp-request-form" style="text-align: left;">
          <div class="form-group">
            <label class="form-label">Telegram Admin User ID</label>
            <input type="number" id="otp-user-id" class="form-control" placeholder="Enter your ID (e.g. 747573651)" required autofocus>
            <small style="color: var(--text-dark); font-size: 11px;">Bot will send a 6-digit OTP directly to your Telegram chat.</small>
          </div>
          <button type="submit" id="btn-request-otp" class="btn btn-primary" style="width: 100%; justify-content: center; padding: 12px;">
            Send Security OTP 📩
          </button>
        </form>

        <!-- Step 2: Verify OTP (Hidden by default) -->
        <form id="otp-verify-form" style="display: none; text-align: left;">
          <div style="background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: var(--radius-sm); padding: 10px 14px; margin-bottom: 16px; font-size: 12px; color: #34d399;">
            📲 <strong>OTP Dispatched!</strong> Check your Telegram private messages for the 6-digit security code.
          </div>
          <div class="form-group">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
              <label class="form-label" style="margin-bottom:0;">Enter 6-Digit Code</label>
              <span id="otp-timer" style="font-size: 11px; color: #fbbf24; font-family: monospace;">⏱️ 05:00</span>
            </div>
            <input type="text" id="otp-code-input" class="form-control" placeholder="123456" maxlength="6" style="letter-spacing: 6px; font-size: 18px; text-align: center; font-weight: 700; font-family: 'JetBrains Mono', monospace;" required>
          </div>
          <button type="submit" id="btn-verify-otp" class="btn btn-emerald" style="width: 100%; justify-content: center; padding: 12px; margin-bottom: 12px;">
            Verify & Unlock Console ⚡
          </button>
          <div style="text-align: center;">
            <a href="javascript:void(0)" onclick="resetOtpStep()" style="font-size: 12px; color: var(--text-muted); text-decoration: none;">← Change User ID or Resend</a>
          </div>
        </form>
      </div>

      <!-- MODE 2: MASTER PASSWORD LOGIN -->
      <div id="auth-mode-password" style="display: none; text-align: left;">
        <form id="password-login-form">
          <div class="form-group">
            <label class="form-label">Master Administrator Password</label>
            <input type="password" id="login-password-input" class="form-control" placeholder="Enter master password" required>
            <small style="color: var(--text-dark); font-size: 11px;">Configured in ADMIN_PASSWORD environment variable.</small>
          </div>
          <button type="submit" class="btn btn-primary" style="width: 100%; justify-content: center; padding: 12px;">
            Authenticate with Password 🔑
          </button>
        </form>
      </div>

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
      <li class="nav-item" onclick="switchTab('leaderboard')">
        <span class="nav-icon">🏆</span>
        <span>Leaderboard & Merit</span>
      </li>
      <li class="nav-item" onclick="switchTab('admins')">
        <span class="nav-icon">🛡️</span>
        <span>Admins Hub</span>
      </li>
      <li class="nav-item" onclick="switchTab('groups')">
        <span class="nav-icon">🏛️</span>
        <span>Community Groups</span>
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
      <div style="display:flex; align-items:center; gap:6px;">
        <button type="button" class="btn-logout" onclick="toggleTheme()" title="Switch Light/Dark Theme" style="padding:5px 8px;">
          <span class="theme-switch-icon">☀️</span>
        </button>
        <button class="btn-logout" onclick="logout()">Logout</button>
      </div>
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
        <button type="button" class="btn btn-secondary" id="btn-theme-toggle" onclick="toggleTheme()" title="Switch Theme">
          <span class="theme-switch-icon">☀️</span> <span class="theme-switch-label">Light Theme</span>
        </button>
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
        <div class="metric-card">
          <div class="metric-label">Community Groups</div>
          <div class="metric-value" id="stat-groups" style="color: #a78bfa;">0</div>
          <div class="metric-sub">🏛️ Authorized groups</div>
          <div class="metric-icon-bg">🏛️</div>
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
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 12px;">
          <div>
            <h3 style="font-family: 'Outfit'; font-size: 19px;">Candidate Directory & Pass Management</h3>
            <p style="font-size: 13px; color: var(--text-muted);">Inspect candidate performance and grant/revoke Premium Scholar Passes (Notifies candidate via Telegram).</p>
          </div>
          <div style="display: flex; gap: 8px; align-items: center;">
            <input type="text" id="users-search" class="form-control" placeholder="Search by name, @username, or Telegram ID..." style="max-width: 300px;" oninput="debounceUserSearch()">
            <button class="btn btn-emerald" style="font-size: 12px; padding: 7px 12px; white-space: nowrap;" onclick="quickUnlockPrompt()">⚡ Quick Pass by ID</button>
          </div>
        </div>
        <div style="display: flex; gap: 8px; margin-bottom: 14px;">
          <button class="btn btn-secondary user-filter-btn active" style="font-size:12px; padding:6px 12px;" onclick="setUserFilter('all')">👥 All Candidates</button>
          <button class="btn btn-secondary user-filter-btn" style="font-size:12px; padding:6px 12px;" onclick="setUserFilter('premium')">👑 Scholar Pass Only</button>
          <button class="btn btn-secondary user-filter-btn" style="font-size:12px; padding:6px 12px;" onclick="setUserFilter('free')">🟢 Open Tier Only</button>
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

    <!-- TAB: LEADERBOARD & MERIT STANDINGS -->
    <div id="tab-leaderboard" class="tab-content" style="display: none;">
      <div class="metrics-grid" style="grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); margin-bottom: 20px;">
        <div class="metric-card">
          <div class="metric-label">Ranked Candidates</div>
          <div class="metric-value" id="stat-lb-users">0</div>
          <div class="metric-sub">👥 Students on scoreboard</div>
          <div class="metric-icon-bg">🏆</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">All-India #1 Topper</div>
          <div class="metric-value" id="stat-lb-topper" style="font-size: 20px; color: #fbbf24;">—</div>
          <div class="metric-sub">🥇 Highest cumulative score</div>
          <div class="metric-icon-bg">🥇</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Peak Merit Score</div>
          <div class="metric-value" id="stat-lb-top-score" style="color: #38bdf8;">0</div>
          <div class="metric-sub">⚡ Peak merit points record</div>
          <div class="metric-icon-bg">⚡</div>
        </div>
      </div>

      <div class="card">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; flex-wrap: wrap; gap: 12px;">
          <div>
            <h3 style="font-family: 'Outfit'; font-size: 19px;">Competitive Merit Standings</h3>
            <p style="font-size: 13px; color: var(--text-muted);">Inspect cumulative All-India rankings or analyze candidate performance by specific examination module.</p>
          </div>
          <div style="display: flex; gap: 8px;">
            <button class="btn btn-secondary lb-view-btn active" id="btn-lb-global" onclick="setLbView('global')">🌐 All-India Standings</button>
            <button class="btn btn-secondary lb-view-btn" id="btn-lb-quiz" onclick="setLbView('quiz')">📝 Per-Examination Standings</button>
          </div>
        </div>

        <!-- SUBVIEW 1: GLOBAL LEADERBOARD -->
        <div id="lb-view-global">
          <div class="table-container">
            <table>
              <thead>
                <tr>
                  <th style="width: 80px;">Rank</th>
                  <th>Candidate</th>
                  <th>Telegram User ID</th>
                  <th>Tests Completed</th>
                  <th>Cumulative Score</th>
                  <th>Daily Streak</th>
                  <th>Scholar Pass</th>
                </tr>
              </thead>
              <tbody id="lb-global-table-body">
                <tr><td colspan="7" style="text-align:center;">Loading All-India standings...</td></tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- SUBVIEW 2: PER-TEST LEADERBOARD -->
        <div id="lb-view-quiz" style="display: none;">
          <div style="display: flex; gap: 14px; align-items: center; margin-bottom: 16px; flex-wrap: wrap; background: var(--item-card-bg); border: 1px solid var(--item-card-border); padding: 14px; border-radius: var(--radius-sm);">
            <div style="flex: 1; min-width: 250px;">
              <label class="form-label" style="margin-bottom: 4px;">Select Examination Module:</label>
              <select id="lb-quiz-select" class="form-control" onchange="onQuizLeaderboardSelect(this.value)">
                <option value="">Select an examination paper...</option>
              </select>
            </div>
            <div id="lb-quiz-meta" style="display: flex; gap: 16px; font-size: 13px; color: var(--text-muted); align-items: center; flex-wrap: wrap;">
              <!-- Populated dynamically: questions, marking scheme, attempts count -->
            </div>
          </div>

          <div class="table-container">
            <table>
              <thead>
                <tr>
                  <th style="width: 80px;">Rank</th>
                  <th>Candidate</th>
                  <th>Score (pts)</th>
                  <th>✅ Correct</th>
                  <th>❌ Incorrect</th>
                  <th>🎯 Accuracy</th>
                  <th>⏱️ Time Taken</th>
                </tr>
              </thead>
              <tbody id="lb-quiz-table-body">
                <tr><td colspan="7" style="text-align:center; color:var(--text-dark);">Select an examination paper above to display candidate standings.</td></tr>
              </tbody>
            </table>
          </div>
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

    <!-- TAB 6: COMMUNITY GROUPS DESK -->
    <div id="tab-groups" class="tab-content" style="display: none;">
      <div class="card" style="margin-bottom: 24px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; flex-wrap: wrap; gap: 12px;">
          <div>
            <h3 style="font-family: 'Outfit'; font-size: 19px;">Community Groups Authorization Desk</h3>
            <p style="font-size: 13px; color: var(--text-muted);">Authorize Telegram discussion groups for /groupquiz live battles or revoke permissions.</p>
          </div>
          <button class="btn btn-primary" onclick="openAddGroupModal()">🏛️ Authorize Community Group</button>
        </div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Group Title</th>
                <th>Telegram Group ID</th>
                <th>Authorization Status</th>
                <th>Live Status & Schedule</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody id="groups-table-body">
              <tr><td colspan="5" style="text-align:center;">Loading authorized groups...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 7: BROADCAST STUDIO -->
    <div id="tab-broadcast" class="tab-content" style="display: none;">
      <div class="card">
        <h3 style="font-family: 'Outfit'; font-size: 19px; margin-bottom: 6px;">Announcement Broadcast Studio</h3>
        <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 20px;">Dispatch instant announcements and alerts to students, groups or all channels via Telegram Bot.</p>
        
        <form id="broadcast-form">
          <div class="form-group" style="margin-bottom: 18px;">
            <label class="form-label">Audience Distribution Reach</label>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 10px;">
              <label class="broadcast-target-card">
                <input type="radio" name="broadcast-target" value="users" checked style="accent-color:var(--primary);">
                <div>
                  <div style="font-weight:600; font-size:13px;">👤 Candidates Only</div>
                  <div style="font-size:11px; color:var(--text-muted);">Registered individual students</div>
                </div>
              </label>
              <label class="broadcast-target-card">
                <input type="radio" name="broadcast-target" value="groups" style="accent-color:var(--primary);">
                <div>
                  <div style="font-weight:600; font-size:13px;">🏛️ Community Groups Only</div>
                  <div style="font-size:11px; color:var(--text-muted);">Authorized discussion groups</div>
                </div>
              </label>
              <label class="broadcast-target-card">
                <input type="radio" name="broadcast-target" value="all" style="accent-color:var(--primary);">
                <div>
                  <div style="font-weight:600; font-size:13px;">🌐 Global Blast (All Channels)</div>
                  <div style="font-size:11px; color:var(--text-muted);">Both Candidates & Groups</div>
                </div>
              </label>
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">Announcement Content (Supports Markdown: *bold*, _italics_, &#96;code&#96;)</label>
            <textarea id="broadcast-text" class="form-control" style="min-height: 140px;" placeholder="📢 Important Examination Announcement:&#10;&#10;New All-India UPSC Mock Test Paper 4 is now live! Attempt now via /quizzes." required></textarea>
          </div>
          <div class="info-callout">
            <div style="font-weight: 600; font-size: 13px; color: var(--callout-title); margin-bottom: 4px;">⚠️ High-Priority Dispatch Notice:</div>
            <div style="font-size: 12px; color: var(--text-muted);">This message will be dispatched in asynchronous batches according to the chosen distribution reach. Rate limits are handled automatically.</div>
          </div>
          <button type="submit" class="btn btn-primary" id="btn-broadcast">🚀 Dispatch Announcement Now</button>
        </form>
      </div>
    </div>

    <!-- TAB 8: SETTINGS -->
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
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
              <label class="form-label" style="margin-bottom:0;">Mandatory Telegram Announcement Channel</label>
              <button type="button" class="btn btn-secondary" style="padding:2px 8px; font-size:11px;" onclick="clearChannelField()">Clear Channel</button>
            </div>
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
            <div style="font-weight: 600; font-size: 14px; color: var(--text-main); margin-bottom: 4px;">Click to Choose JSON File, or Drag & Drop Here</div>
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

  <!-- MODAL: AUTHORIZE COMMUNITY GROUP -->
  <div id="modal-add-group" class="modal-backdrop">
    <div class="modal-box">
      <div class="modal-header">
        <h3>Authorize Community Group</h3>
        <button class="modal-close" onclick="closeModal('modal-add-group')">✕</button>
      </div>
      <form id="add-group-form">
        <div class="form-group">
          <label class="form-label">Telegram Group ID (Numeric)</label>
          <input type="text" id="ag-id" class="form-control" placeholder="e.g. -1001987654321" required>
          <small style="color:var(--text-dark); font-size:11px;">Obtain via /auth or forwarding group message to @userinfobot.</small>
        </div>
        <div class="form-group">
          <label class="form-label">Community / Group Title</label>
          <input type="text" id="ag-title" class="form-control" placeholder="e.g. UPSC Prelims Discussion Group" required>
        </div>
        <button type="submit" class="btn btn-primary" style="width:100%; justify-content:center;">Authorize Group 🏛️</button>
      </form>
    </div>
  </div>

  <!-- MODAL: LAUNCH GROUP QUIZ BATTLE -->
  <div id="modal-group-launch" class="modal-backdrop">
    <div class="modal-box">
      <div class="modal-header">
        <h3>🚀 Launch Live Battle in Group</h3>
        <button class="modal-close" onclick="closeModal('modal-group-launch')">✕</button>
      </div>
      <form id="group-launch-form" onsubmit="submitGroupLaunch(event)">
        <input type="hidden" id="gl-group-id">
        <div class="form-group">
          <label class="form-label">Target Community Group</label>
          <input type="text" id="gl-group-title" class="form-control" readonly style="opacity:0.85; font-weight:600;">
        </div>
        <div class="form-group">
          <label class="form-label">Select Examination Paper</label>
          <select id="gl-quiz-select" class="form-control" required>
            <option value="">Select an examination paper...</option>
          </select>
        </div>
        <div class="info-callout" style="margin-bottom:18px;">
          <div style="font-weight:600; font-size:13px; color:var(--callout-title); margin-bottom:4px;">⚡ Instant Battle Execution:</div>
          <div style="font-size:12px; color:var(--text-muted);">The bot will broadcast a 5-second countdown alert into this group and then sequentially deliver native Telegram quiz polls with automatic timeouts and ranklist scorecard.</div>
        </div>
        <div style="display:flex; justify-content:flex-end; gap:10px;">
          <button type="button" class="btn btn-secondary" onclick="closeModal('modal-group-launch')">Cancel</button>
          <button type="submit" class="btn btn-primary" id="btn-submit-gl">🚀 Start Live Battle</button>
        </div>
      </form>
    </div>
  </div>

  <!-- MODAL: SCHEDULE GROUP QUIZ BATTLE -->
  <div id="modal-group-schedule" class="modal-backdrop">
    <div class="modal-box">
      <div class="modal-header">
        <h3>⏰ Schedule Group Examination Battle</h3>
        <button class="modal-close" onclick="closeModal('modal-group-schedule')">✕</button>
      </div>
      <form id="group-schedule-form" onsubmit="submitGroupSchedule(event)">
        <input type="hidden" id="gs-group-id">
        <div class="form-group">
          <label class="form-label">Target Community Group</label>
          <input type="text" id="gs-group-title" class="form-control" readonly style="opacity:0.85; font-weight:600;">
        </div>
        <div class="form-group">
          <label class="form-label">Select Examination Paper</label>
          <select id="gs-quiz-select" class="form-control" required>
            <option value="">Select an examination paper...</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">Execution Timing Mode</label>
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-bottom:12px;">
            <label class="broadcast-target-card">
              <input type="radio" name="gs-mode" value="preset" checked onchange="toggleGsMode()" style="accent-color:var(--primary);">
              <div>
                <div style="font-weight:600; font-size:13px;">⏱️ Quick Delay</div>
                <div style="font-size:11px; color:var(--text-muted);">Launch after set minutes</div>
              </div>
            </label>
            <label class="broadcast-target-card">
              <input type="radio" name="gs-mode" value="custom" onchange="toggleGsMode()" style="accent-color:var(--primary);">
              <div>
                <div style="font-weight:600; font-size:13px;">🕒 Target IST Time</div>
                <div style="font-size:11px; color:var(--text-muted);">Exact slot today (HH:MM)</div>
              </div>
            </label>
          </div>
          <div id="gs-preset-box">
            <select id="gs-delay-select" class="form-control">
              <option value="5">⏱️ 5 Minutes Delay</option>
              <option value="15" selected>⏱️ 15 Minutes Delay</option>
              <option value="30">⏱️ 30 Minutes Delay</option>
              <option value="60">⏱️ 1 Hour Delay</option>
              <option value="120">⏱️ 2 Hours Delay</option>
            </select>
          </div>
          <div id="gs-custom-box" style="display:none;">
            <input type="text" id="gs-custom-time" class="form-control" placeholder="e.g. 20:00 or 8:30 PM or 45">
            <small style="font-size:11px; color:var(--text-muted); display:block; margin-top:4px;">Supports 24h format (e.g. 21:00), 12h format (e.g. 9:00 PM), or relative minutes (e.g. 45).</small>
          </div>
        </div>
        <div class="info-callout" style="margin-bottom:18px;">
          <div style="font-weight:600; font-size:13px; color:var(--callout-title); margin-bottom:4px;">📢 Automated Group Announcement:</div>
          <div style="font-size:12px; color:var(--text-muted);">The bot will post an official schedule announcement with countdown in the group, deliver a 60-second alert before starting, and trigger the polls automatically.</div>
        </div>
        <div style="display:flex; justify-content:flex-end; gap:10px;">
          <button type="button" class="btn btn-secondary" onclick="closeModal('modal-group-schedule')">Cancel</button>
          <button type="submit" class="btn btn-primary" id="btn-submit-gs">⏰ Confirm & Schedule</button>
        </div>
      </form>
    </div>
  </div>

  <!-- MODAL: EDIT EXAMINATION SCHEME -->
  <div id="modal-edit-quiz" class="modal-backdrop">
    <div class="modal-box">
      <div class="modal-header">
        <h3>Edit Examination Scheme</h3>
        <button class="modal-close" onclick="closeModal('modal-edit-quiz')">✕</button>
      </div>
      <form id="edit-quiz-form">
        <input type="hidden" id="eq-id">
        <div class="form-group">
          <label class="form-label">Paper Title</label>
          <input type="text" id="eq-title" class="form-control" required>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
          <div class="form-group">
            <label class="form-label">Subject Category</label>
            <input type="text" id="eq-category" class="form-control" required>
          </div>
          <div class="form-group">
            <label class="form-label">Folder Location</label>
            <select id="eq-folder" class="form-control">
              <option value="">📁 Directory Root (No folder)</option>
            </select>
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">Description / Syllabus</label>
          <textarea id="eq-desc" class="form-control"></textarea>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label">Marks Per Question</label>
            <input type="number" step="0.5" id="eq-marks" class="form-control" required>
          </div>
          <div class="form-group">
            <label class="form-label">Negative Penalty</label>
            <input type="number" step="0.1" id="eq-neg" class="form-control" required>
          </div>
          <div class="form-group">
            <label class="form-label">Time Per Question (sec)</label>
            <input type="number" id="eq-time" class="form-control" required>
          </div>
        </div>
        <div class="form-group" style="display:flex; align-items:center; gap:10px; margin-top:6px;">
          <input type="checkbox" id="eq-premium" style="width:18px; height:18px; accent-color: var(--primary);">
          <label for="eq-premium" style="font-size:13px; font-weight:500; cursor:pointer;">Require Premium Scholar Pass (Locked)</label>
        </div>
        <button type="submit" class="btn btn-primary" style="width: 100%; justify-content:center; margin-top:14px;">
          Save Scheme Changes 💾
        </button>
      </form>
    </div>
  </div>

  <!-- MODAL: EDIT QUESTION -->
  <div id="modal-edit-question" class="modal-backdrop">
    <div class="modal-box">
      <div class="modal-header">
        <h3>Edit Question</h3>
        <button class="modal-close" onclick="closeModal('modal-edit-question')">✕</button>
      </div>
      <form id="edit-question-form">
        <input type="hidden" id="eq-q-id">
        <div class="form-group">
          <label class="form-label">Question Text</label>
          <input type="text" id="eq-q-text" class="form-control" required>
        </div>
        <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-bottom:12px;">
          <input type="text" id="eq-q-opt-0" class="form-control" placeholder="Option A" required>
          <input type="text" id="eq-q-opt-1" class="form-control" placeholder="Option B" required>
          <input type="text" id="eq-q-opt-2" class="form-control" placeholder="Option C" required>
          <input type="text" id="eq-q-opt-3" class="form-control" placeholder="Option D" required>
        </div>
        <div style="display:grid; grid-template-columns: 1fr 2fr; gap:12px; margin-bottom:12px;">
          <div>
            <label class="form-label">Correct Option</label>
            <select id="eq-q-correct" class="form-control">
              <option value="0">Option A</option>
              <option value="1">Option B</option>
              <option value="2">Option C</option>
              <option value="3">Option D</option>
            </select>
          </div>
          <div>
            <label class="form-label">Detailed Explanation</label>
            <input type="text" id="eq-q-exp" class="form-control" placeholder="Explanation...">
          </div>
        </div>
        <button type="submit" class="btn btn-primary" style="width:100%; justify-content:center;">Save Question Changes 💾</button>
      </form>
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
      initTheme();
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

    let currentOtpUserId = '';
    let otpCountdownInterval = null;

    function switchAuthMode(mode) {
      if (mode === 'otp') {
        document.getElementById('auth-mode-otp').style.display = 'block';
        document.getElementById('auth-mode-password').style.display = 'none';
        document.getElementById('auth-tab-otp').style.background = 'var(--primary)';
        document.getElementById('auth-tab-otp').style.color = '#fff';
        document.getElementById('auth-tab-pass').style.background = 'transparent';
        document.getElementById('auth-tab-pass').style.color = 'var(--text-main)';
      } else {
        document.getElementById('auth-mode-otp').style.display = 'none';
        document.getElementById('auth-mode-password').style.display = 'block';
        document.getElementById('auth-tab-pass').style.background = 'var(--primary)';
        document.getElementById('auth-tab-pass').style.color = '#fff';
        document.getElementById('auth-tab-otp').style.background = 'transparent';
        document.getElementById('auth-tab-otp').style.color = 'var(--text-main)';
      }
    }

    // Step 1: Request OTP
    document.getElementById('otp-request-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const userId = document.getElementById('otp-user-id').value.trim();
      const btn = document.getElementById('btn-request-otp');
      btn.innerText = 'Dispatching Code... ⏳';
      btn.disabled = true;

      try {
        const res = await fetch('/api/admin/auth/request-otp', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ userId }),
        });
        const data = await res.json();
        if (data.success) {
          currentOtpUserId = userId;
          document.getElementById('otp-request-form').style.display = 'none';
          document.getElementById('otp-verify-form').style.display = 'block';
          document.getElementById('otp-code-input').value = '';
          document.getElementById('otp-code-input').focus();
          startOtpCountdown(300); // 5 mins
          showToast('Security code sent to your Telegram! 📲', 'success');
        } else {
          showToast(data.error || 'Failed to dispatch code.', 'error');
        }
      } catch {
        showToast('Network error while requesting code.', 'error');
      } finally {
        btn.innerText = 'Send Security OTP 📩';
        btn.disabled = false;
      }
    });

    // Step 2: Verify OTP
    document.getElementById('otp-verify-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const otp = document.getElementById('otp-code-input').value.trim();
      const btn = document.getElementById('btn-verify-otp');
      btn.innerText = 'Verifying... ⏳';
      btn.disabled = true;

      try {
        const res = await fetch('/api/admin/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ type: 'otp', userId: currentOtpUserId, otp }),
        });
        const data = await res.json();
        if (data.success && data.token) {
          authToken = data.token;
          localStorage.setItem('examplayer_admin_token', authToken);
          document.getElementById('login-overlay').style.display = 'none';
          clearInterval(otpCountdownInterval);
          showToast('Authenticated via Telegram 2FA! 🚀', 'success');
          loadDashboard();
        } else {
          showToast(data.error || 'Invalid OTP code.', 'error');
        }
      } catch {
        showToast('Verification network error.', 'error');
      } finally {
        btn.innerText = 'Verify & Unlock Console ⚡';
        btn.disabled = false;
      }
    });

    function resetOtpStep() {
      clearInterval(otpCountdownInterval);
      document.getElementById('otp-request-form').style.display = 'block';
      document.getElementById('otp-verify-form').style.display = 'none';
      document.getElementById('otp-code-input').value = '';
    }

    function startOtpCountdown(seconds) {
      clearInterval(otpCountdownInterval);
      let remaining = seconds;
      const timerEl = document.getElementById('otp-timer');
      otpCountdownInterval = setInterval(() => {
        remaining--;
        if (remaining <= 0) {
          clearInterval(otpCountdownInterval);
          timerEl.innerText = '⚠️ Expired';
          timerEl.style.color = 'var(--rose)';
          return;
        }
        const m = String(Math.floor(remaining / 60)).padStart(2, '0');
        const s = String(remaining % 60).padStart(2, '0');
        timerEl.innerText = '⏱️ ' + m + ':' + s;
      }, 1000);
    }

    // Mode 2: Password Login
    document.getElementById('password-login-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const password = document.getElementById('login-password-input').value;
      try {
        const res = await fetch('/api/admin/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ type: 'password', password }),
        });
        const data = await res.json();
        if (data.success && data.token) {
          authToken = data.token;
          localStorage.setItem('examplayer_admin_token', authToken);
          document.getElementById('login-overlay').style.display = 'none';
          showToast('Welcome back, Administrator!', 'success');
          loadDashboard();
        } else {
          showToast(data.error || 'Invalid password.', 'error');
        }
      } catch {
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
      const idxMap = { dashboard: 0, folders: 1, quizzes: 2, users: 3, leaderboard: 4, admins: 5, groups: 6, broadcast: 7, settings: 8 };
      const navItems = document.querySelectorAll('.nav-item');
      if (navItems[idxMap[tabId]]) navItems[idxMap[tabId]].classList.add('active');

      // Update Titles
      const titles = {
        dashboard: ['Operational Dashboard', 'Real-time candidate metrics, examinations directory and bot control.'],
        folders: ['Examination Folders & Directories', 'Hierarchical classification of mock tests and question categories.'],
        quizzes: ['Examinations Catalog & Papers', 'Create tests, inspect formulas, build questions or manage syllabus.'],
        users: ['Candidate Directory & Access Pass', 'Review registered students and grant Premium Scholar Passes.'],
        leaderboard: ['Candidate Merit Standings', 'Inspect All-India cumulative rankings and test-specific scoreboards.'],
        admins: ['Platform Administrators Hub', 'Manage primary and appointed bot administrators.'],
        groups: ['Community Groups Authorization Desk', 'Authorize Telegram groups to host live quiz tournaments or revoke permissions.'],
        broadcast: ['Announcement Broadcast Studio', 'Dispatch mass announcements and test notifications to students or groups.'],
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
      if (tabId === 'leaderboard') loadLeaderboard();
      if (tabId === 'admins') loadAdmins();
      if (tabId === 'groups') loadGroups();
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
          const groupsEl = document.getElementById('stat-groups');
          if (groupsEl) groupsEl.innerText = (s.authorizedGroups || 0).toLocaleString();
        }

        const quizRes = await apiRequest('/api/admin/quizzes');
        if (quizRes.success) {
          globalQuizzes = quizRes.quizzes;
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
                <button class="btn btn-secondary" style="padding:4px 8px; font-size:11px;" onclick="openQuestionsDrawer('\${q.id}', '\${q.title.replace(/'/g, "\\\\'")}')">Questions</button>
                <button class="btn btn-secondary" style="padding:4px 8px; font-size:11px; margin-left:4px;" onclick="openEditQuizModal('\${q.id}')">✏️ Edit</button>
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
                <button class="btn btn-secondary" style="padding:4px 8px; font-size:11px; margin-right:4px;" onclick="renameFolderPrompt('\${f.id}', '\${f.name.replace(/'/g, "\\\\'")}')">✏️ Rename</button>
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
      const selects = [
        document.getElementById('cq-folder'),
        document.getElementById('import-folder'),
        document.getElementById('cf-parent'),
        document.getElementById('eq-folder')
      ];
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
          globalQuizzes = res.quizzes;
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
                <button class="btn btn-secondary" style="padding:4px 8px; font-size:11px; margin-left:4px;" onclick="openEditQuizModal('\${q.id}')">✏️ Edit</button>
                <button class="btn btn-danger" style="padding:4px 8px; font-size:11px; margin-left:4px;" onclick="deleteQuizPrompt('\${q.id}', '\${q.title.replace(/'/g, "\\\\'")}')">Delete</button>
              </td>
            \`;
            tbody.appendChild(tr);
          });
        }
      } catch (err) {
        showToast('Failed to load examinations.', 'error');
      }
    }

    function openEditQuizModal(quizId) {
      const q = globalQuizzes.find(item => item.id === quizId);
      if (!q) return;
      document.getElementById('eq-id').value = q.id;
      document.getElementById('eq-title').value = q.title || '';
      document.getElementById('eq-category').value = q.category || 'General';
      document.getElementById('eq-folder').value = q.folder_id || '';
      document.getElementById('eq-desc').value = q.description || '';
      document.getElementById('eq-marks').value = q.marks_per_question ?? 2.0;
      document.getElementById('eq-neg').value = q.negative_marks ?? 0.5;
      document.getElementById('eq-time').value = q.time_limit_seconds ?? 30;
      document.getElementById('eq-premium').checked = Boolean(q.is_premium);
      document.getElementById('modal-edit-quiz').classList.add('open');
    }

    document.getElementById('edit-quiz-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const quizId = document.getElementById('eq-id').value;
      if (!quizId) return;
      const body = {
        title: document.getElementById('eq-title').value,
        category: document.getElementById('eq-category').value,
        folder_id: document.getElementById('eq-folder').value || null,
        description: document.getElementById('eq-desc').value,
        marks_per_question: Number(document.getElementById('eq-marks').value),
        negative_marks: Number(document.getElementById('eq-neg').value),
        time_limit_seconds: Number(document.getElementById('eq-time').value),
        is_premium: document.getElementById('eq-premium').checked,
      };
      try {
        const res = await apiRequest(\`/api/admin/quizzes/\${quizId}\`, 'PUT', body);
        if (res.success) {
          showToast('Examination scheme updated! 💾', 'success');
          closeModal('modal-edit-quiz');
          loadQuizzes();
          loadDashboard();
        } else {
          showToast(res.error || 'Failed to update quiz scheme.', 'error');
        }
      } catch {
        showToast('Error updating quiz.', 'error');
      }
    });

    // 4. USERS LOADER
    let searchTimeout;
    let currentUserTier = 'all';

    function debounceUserSearch() {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(loadUsers, 300);
    }

    function setUserFilter(tier) {
      currentUserTier = tier;
      document.querySelectorAll('.user-filter-btn').forEach(btn => btn.classList.remove('active'));
      const activeBtn = Array.from(document.querySelectorAll('.user-filter-btn')).find(b => {
        if (tier === 'all') return b.innerText.includes('All');
        if (tier === 'premium') return b.innerText.includes('Scholar');
        if (tier === 'free') return b.innerText.includes('Open');
        return false;
      });
      if (activeBtn) activeBtn.classList.add('active');
      loadUsers();
    }

    async function loadUsers() {
      const q = (document.getElementById('users-search')?.value || '').trim();
      try {
        const params = new URLSearchParams();
        if (q) params.set('q', q);
        if (currentUserTier !== 'all') params.set('tier', currentUserTier);
        const queryStr = params.toString() ? '?' + params.toString() : '';

        const res = await apiRequest('/api/admin/users' + queryStr);
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
          showToast(shouldBePremium ? 'Scholar Pass granted & Telegram celebratory message dispatched! 📲' : 'Scholar Pass revoked.', 'success');
          loadUsers();
          loadDashboard();
        }
      } catch {
        showToast('Failed to update status.', 'error');
      }
    }

    async function quickUnlockPrompt() {
      const inputId = prompt('Enter candidate Telegram User ID to grant Scholar Pass (e.g. 5988607147):');
      if (!inputId || !inputId.trim()) return;
      const numId = parseInt(inputId.trim(), 10);
      if (isNaN(numId)) {
        showToast('Invalid numerical Telegram ID.', 'error');
        return;
      }
      toggleUserPremium(numId, true);
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

    // 6. COMMUNITY GROUPS LOADER
    async function loadGroups() {
      try {
        const res = await apiRequest('/api/admin/groups');
        if (res.success) {
          const tbody = document.getElementById('groups-table-body');
          tbody.innerHTML = '';
          if (res.groups.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:var(--text-dark);">No community groups authorized yet. Click "Authorize Community Group" to add one.</td></tr>';
            return;
          }
          res.groups.forEach(g => {
            const tr = document.createElement('tr');
            let schedStatusHtml = '<span style="color:var(--text-dark); font-size:12px;">⚪ No Schedule</span>';
            if (g.isBattleActive) {
              schedStatusHtml = '<span class="badge badge-premium">🔥 Live Battle Active</span>';
            } else if (g.activeSchedule) {
              schedStatusHtml = \`
                <div style="font-size:12px; font-weight:600; color:var(--cyan);">
                  ⏰ \${g.activeSchedule.quizTitle}
                </div>
                <div style="font-size:11px; color:var(--text-muted); margin-bottom:4px;">
                  \${g.activeSchedule.timeFormatted} IST
                </div>
                <button class="btn btn-danger" style="padding:2px 7px; font-size:10px;" onclick="cancelGroupScheduleFromWeb(\${g.group_id})">
                  🛑 Cancel
                </button>
              \`;
            }

            const cleanTitle = (g.group_title || 'Community Group').replace(/'/g, "\\\\'");

            let actionBtns = '';
            if (g.is_active) {
              actionBtns += \`
                <button class="btn btn-primary" style="padding:4px 8px; font-size:11px;" onclick="openGroupLaunchModal(\${g.group_id}, '\${cleanTitle}')">
                  🚀 Launch
                </button>
                <button class="btn btn-secondary" style="padding:4px 8px; font-size:11px; margin-left:4px;" onclick="openGroupScheduleModal(\${g.group_id}, '\${cleanTitle}')">
                  ⏰ Schedule
                </button>
                <button class="btn btn-danger" style="padding:4px 8px; font-size:11px; margin-left:4px;" onclick="toggleGroupStatus(\${g.group_id}, false, '\${cleanTitle}')">
                  Revoke
                </button>
              \`;
            } else {
              actionBtns += \`
                <button class="btn btn-emerald" style="padding:4px 8px; font-size:11px;" onclick="toggleGroupStatus(\${g.group_id}, true, '\${cleanTitle}')">
                  Activate
                </button>
              \`;
            }
            actionBtns += \`
              <button class="btn btn-secondary" style="padding:4px 8px; font-size:11px; margin-left:4px;" onclick="deleteGroupRecord(\${g.group_id})">
                Delete
              </button>
            \`;

            tr.innerHTML = \`
              <td><strong>🏛️ \${g.group_title || 'Community Group'}</strong></td>
              <td><code>\${g.group_id}</code></td>
              <td>
                <span class="badge \${g.is_active ? 'badge-free' : 'badge-premium'}">
                  \${g.is_active ? '🟢 ACTIVE' : '🔴 REVOKED'}
                </span>
              </td>
              <td>\${schedStatusHtml}</td>
              <td style="white-space: nowrap;">\${actionBtns}</td>
            \`;
            tbody.appendChild(tr);
          });
        }
      } catch (err) {
        showToast('Failed to load groups.', 'error');
      }
    }

    async function toggleGroupStatus(groupId, isActive, groupTitle) {
      try {
        const res = await apiRequest(\`/api/admin/groups/\${groupId}/toggle\`, 'POST', { isActive, groupTitle });
        if (res.success) {
          showToast(isActive ? 'Group authorization approved! 🏛️' : 'Group authorization revoked.', 'success');
          loadGroups();
          loadDashboard();
        }
      } catch {
        showToast('Failed to toggle group status.', 'error');
      }
    }

    async function deleteGroupRecord(groupId) {
      if (!confirm(\`Permanently remove group \${groupId} from records?\`)) return;
      try {
        const res = await apiRequest(\`/api/admin/groups/\${groupId}\`, 'DELETE');
        if (res.success) {
          showToast('Group record deleted.', 'success');
          loadGroups();
          loadDashboard();
        }
      } catch {
        showToast('Failed to delete group record.', 'error');
      }
    }

    document.getElementById('add-group-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const groupId = document.getElementById('ag-id').value.trim();
      const groupTitle = document.getElementById('ag-title').value.trim();
      try {
        const res = await apiRequest('/api/admin/groups', 'POST', { groupId, groupTitle });
        if (res.success) {
          showToast('Group authorized successfully! 🏛️', 'success');
          closeModal('modal-add-group');
          document.getElementById('add-group-form').reset();
          loadGroups();
          loadDashboard();
        } else {
          showToast(res.error || 'Failed to authorize group.', 'error');
        }
      } catch {
        showToast('Error authorizing group.', 'error');
      }
    });

    function openAddGroupModal() {
      document.getElementById('modal-add-group').classList.add('open');
    }

    // Modal: Launch Group Live Battle
    function openGroupLaunchModal(groupId, groupTitle) {
      document.getElementById('gl-group-id').value = groupId;
      document.getElementById('gl-group-title').value = groupTitle;
      const sel = document.getElementById('gl-quiz-select');
      sel.innerHTML = '<option value="">Select an examination paper...</option>';
      if (globalQuizzes && globalQuizzes.length > 0) {
        globalQuizzes.forEach(q => {
          const opt = document.createElement('option');
          opt.value = q.id;
          opt.innerText = q.title + ' (' + q.total_questions + ' Qs | ' + q.category + ')';
          sel.appendChild(opt);
        });
      }
      document.getElementById('modal-group-launch').classList.add('open');
    }

    async function submitGroupLaunch(e) {
      e.preventDefault();
      const groupId = document.getElementById('gl-group-id').value;
      const quizId = document.getElementById('gl-quiz-select').value;
      if (!quizId) {
        showToast('Please select an examination paper.', 'error');
        return;
      }
      const btn = document.getElementById('btn-submit-gl');
      btn.disabled = true;
      btn.innerText = 'Launching...';
      try {
        const res = await apiRequest('/api/admin/groups/' + groupId + '/launch', 'POST', { quizId });
        if (res.success) {
          showToast('Live examination battle launched successfully! 🚀', 'success');
          closeModal('modal-group-launch');
          loadGroups();
        } else {
          showToast(res.error || 'Failed to launch battle.', 'error');
        }
      } catch {
        showToast('Error launching battle.', 'error');
      } finally {
        btn.disabled = false;
        btn.innerText = '🚀 Start Live Battle';
      }
    }

    // Modal: Schedule Group Live Battle
    function openGroupScheduleModal(groupId, groupTitle) {
      document.getElementById('gs-group-id').value = groupId;
      document.getElementById('gs-group-title').value = groupTitle;
      const sel = document.getElementById('gs-quiz-select');
      sel.innerHTML = '<option value="">Select an examination paper...</option>';
      if (globalQuizzes && globalQuizzes.length > 0) {
        globalQuizzes.forEach(q => {
          const opt = document.createElement('option');
          opt.value = q.id;
          opt.innerText = q.title + ' (' + q.total_questions + ' Qs | ' + q.category + ')';
          sel.appendChild(opt);
        });
      }
      document.getElementById('modal-group-schedule').classList.add('open');
    }

    function toggleGsMode() {
      const mode = document.querySelector('input[name="gs-mode"]:checked')?.value;
      if (mode === 'preset') {
        document.getElementById('gs-preset-box').style.display = 'block';
        document.getElementById('gs-custom-box').style.display = 'none';
      } else {
        document.getElementById('gs-preset-box').style.display = 'none';
        document.getElementById('gs-custom-box').style.display = 'block';
      }
    }

    async function submitGroupSchedule(e) {
      e.preventDefault();
      const groupId = document.getElementById('gs-group-id').value;
      const quizId = document.getElementById('gs-quiz-select').value;
      if (!quizId) {
        showToast('Please select an examination paper.', 'error');
        return;
      }
      const mode = document.querySelector('input[name="gs-mode"]:checked')?.value;
      let payload = { quizId };
      if (mode === 'preset') {
        payload.delayMinutes = document.getElementById('gs-delay-select').value;
      } else {
        const customTime = document.getElementById('gs-custom-time').value.trim();
        if (!customTime) {
          showToast('Please enter target time.', 'error');
          return;
        }
        payload.timeStr = customTime;
      }

      const btn = document.getElementById('btn-submit-gs');
      btn.disabled = true;
      btn.innerText = 'Scheduling...';
      try {
        const res = await apiRequest('/api/admin/groups/' + groupId + '/schedule', 'POST', payload);
        if (res.success) {
          showToast('Examination scheduled for ' + res.timeFormatted + ' IST! ⏰', 'success');
          closeModal('modal-group-schedule');
          loadGroups();
        } else {
          showToast(res.error || 'Failed to schedule.', 'error');
        }
      } catch {
        showToast('Error scheduling battle.', 'error');
      } finally {
        btn.disabled = false;
        btn.innerText = '⏰ Confirm & Schedule';
      }
    }

    async function cancelGroupScheduleFromWeb(groupId) {
      if (!confirm('Cancel scheduled examination session for this group?')) return;
      try {
        const res = await apiRequest('/api/admin/groups/' + groupId + '/cancel-schedule', 'POST');
        if (res.success) {
          showToast('Scheduled session cancelled. Notice sent to group.', 'success');
          loadGroups();
        } else {
          showToast(res.error || 'Failed to cancel schedule.', 'error');
        }
      } catch {
        showToast('Error cancelling schedule.', 'error');
      }
    }

    // ================= LEADERBOARD & MERIT MANAGEMENT =================
    let currentLbView = 'global';
    let globalLeaderboardCache = [];

    async function loadLeaderboard() {
      if (!globalQuizzes || globalQuizzes.length === 0) {
        try {
          const qRes = await apiRequest('/api/admin/quizzes');
          if (qRes.success) globalQuizzes = qRes.quizzes;
        } catch {}
      }
      populateLbQuizSelect();

      try {
        const res = await apiRequest('/api/admin/leaderboard/global');
        if (res.success) {
          globalLeaderboardCache = res.leaderboard || [];
          renderGlobalLeaderboard(globalLeaderboardCache);
        }
      } catch {
        showToast('Failed to load leaderboard data.', 'error');
      }
    }

    function populateLbQuizSelect() {
      const sel = document.getElementById('lb-quiz-select');
      if (!sel) return;
      const cur = sel.value;
      sel.innerHTML = '<option value="">Select an examination paper...</option>';
      if (globalQuizzes && globalQuizzes.length > 0) {
        globalQuizzes.forEach(q => {
          const opt = document.createElement('option');
          opt.value = q.id;
          opt.innerText = q.title + ' (' + q.total_questions + ' Qs | ' + q.category + ')';
          sel.appendChild(opt);
        });
      }
      if (cur) sel.value = cur;
    }

    function renderGlobalLeaderboard(users) {
      const tbody = document.getElementById('lb-global-table-body');
      if (!tbody) return;
      tbody.innerHTML = '';

      document.getElementById('stat-lb-users').innerText = users.length.toLocaleString();
      if (users.length > 0) {
        const topUser = users[0];
        const topName = topUser.username ? '@' + topUser.username : (topUser.first_name || 'Candidate');
        document.getElementById('stat-lb-topper').innerText = topName;
        document.getElementById('stat-lb-top-score').innerText = (topUser.total_score || 0).toLocaleString() + ' pts';
      } else {
        document.getElementById('stat-lb-topper').innerText = '—';
        document.getElementById('stat-lb-top-score').innerText = '0 pts';
      }

      if (users.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:var(--text-dark);">No candidate attempts recorded yet.</td></tr>';
        return;
      }

      const medals = ['🥇 #1', '🥈 #2', '🥉 #3'];
      users.forEach((u, idx) => {
        const tr = document.createElement('tr');
        const rankLabel = idx < 3 ? medals[idx] : '#' + (idx + 1);
        const nameDisplay = u.first_name || 'Anonymous';
        const handleDisplay = u.username ? '@' + u.username : '';

        tr.innerHTML = \`
          <td><strong>\${rankLabel}</strong></td>
          <td>
            <strong>\${nameDisplay}</strong>
            \${handleDisplay ? '<div style="font-size:11px; color:var(--primary);">' + handleDisplay + '</div>' : ''}
          </td>
          <td><code>\${u.id}</code></td>
          <td>\${(u.tests_completed || 0).toLocaleString()}</td>
          <td><strong style="color:var(--emerald);">\${(u.total_score || 0).toLocaleString()} pts</strong></td>
          <td>\${u.streak_days > 0 ? '🔥 ' + u.streak_days + ' Days' : '—'}</td>
          <td>
            <span class="badge \${u.is_premium ? 'badge-premium' : 'badge-free'}">
              \${u.is_premium ? '👑 SCHOLAR PASS' : '🟢 FREE TIER'}
            </span>
          </td>
        \`;
        tbody.appendChild(tr);
      });
    }

    function setLbView(view) {
      currentLbView = view;
      document.querySelectorAll('.lb-view-btn').forEach(btn => btn.classList.remove('active'));
      if (view === 'global') {
        document.getElementById('btn-lb-global').classList.add('active');
        document.getElementById('lb-view-global').style.display = 'block';
        document.getElementById('lb-view-quiz').style.display = 'none';
      } else {
        document.getElementById('btn-lb-quiz').classList.add('active');
        document.getElementById('lb-view-global').style.display = 'none';
        document.getElementById('lb-view-quiz').style.display = 'block';
        const sel = document.getElementById('lb-quiz-select');
        if (sel && sel.value) {
          loadQuizLeaderboard(sel.value);
        } else if (sel && sel.options.length > 1) {
          sel.selectedIndex = 1;
          loadQuizLeaderboard(sel.value);
        }
      }
    }

    function onQuizLeaderboardSelect(quizId) {
      if (!quizId) {
        document.getElementById('lb-quiz-table-body').innerHTML = '<tr><td colspan="7" style="text-align:center; color:var(--text-dark);">Select an examination paper above.</td></tr>';
        document.getElementById('lb-quiz-meta').innerHTML = '';
        return;
      }
      loadQuizLeaderboard(quizId);
    }

    async function loadQuizLeaderboard(quizId) {
      const tbody = document.getElementById('lb-quiz-table-body');
      const metaEl = document.getElementById('lb-quiz-meta');
      tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;">Evaluating examination standings...</td></tr>';

      try {
        const res = await apiRequest('/api/admin/leaderboard/quiz/' + quizId);
        if (res.success) {
          const q = res.quiz;
          const attempts = res.attempts || [];

          metaEl.innerHTML = \`
            <span>❓ <strong>\${q.total_questions}</strong> Questions</span>
            <span>⚡ Marks: <strong style="color:var(--emerald);">+\${q.marks_per_question}</strong> / <strong style="color:var(--rose);">-\${q.negative_marks}</strong></span>
            <span>🎯 <strong>\${attempts.length}</strong> Candidate Attempts Evaluated</span>
          \`;

          tbody.innerHTML = '';
          if (attempts.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:var(--text-dark);">No attempts recorded for this examination paper yet.</td></tr>';
            return;
          }

          const medals = ['🥇 #1', '🥈 #2', '🥉 #3'];
          attempts.forEach((att, idx) => {
            const tr = document.createElement('tr');
            const rankLabel = idx < 3 ? medals[idx] : '#' + (idx + 1);
            const rawName = att.first_name || (att.username ? '@' + att.username : 'Candidate');
            const handle = att.username ? '@' + att.username : '';

            const totalSec = att.time_taken_seconds || 0;
            const mins = Math.floor(totalSec / 60);
            const secs = totalSec % 60;
            const timeStr = String(mins).padStart(2, '0') + ':' + String(secs).padStart(2, '0');

            tr.innerHTML = \`
              <td><strong>\${rankLabel}</strong></td>
              <td>
                <strong>\${rawName}</strong>
                \${handle && handle !== rawName ? '<div style="font-size:11px; color:var(--primary);">' + handle + '</div>' : ''}
              </td>
              <td><strong style="color:var(--emerald);">\${att.score} pts</strong></td>
              <td style="color:var(--emerald);">✅ \${att.correct_count ?? 0}</td>
              <td style="color:var(--rose);">❌ \${att.wrong_count ?? 0}</td>
              <td>
                <div style="font-weight:600;">\${att.accuracy_percent ?? 0}%</div>
                <div style="height:4px; width:70px; background:var(--item-card-border); border-radius:2px; overflow:hidden; margin-top:2px;">
                  <div style="height:100%; width:\${att.accuracy_percent ?? 0}%; background:var(--primary);"></div>
                </div>
              </td>
              <td>⏱️ \${timeStr}</td>
            \`;
            tbody.appendChild(tr);
          });
        }
      } catch {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:var(--rose);">Failed to load examination standings.</td></tr>';
      }
    }

    // 7. SETTINGS LOADER
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

    function clearChannelField() {
      document.getElementById('setting-channel').value = '';
      showToast('Channel cleared. Click "Save Configuration" to apply.', 'success');
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

    // 8. BROADCAST HANDLER (MULTI-TARGET: CANDIDATES, GROUPS, ALL)
    document.getElementById('broadcast-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const message = document.getElementById('broadcast-text').value;
      const target = document.querySelector('input[name="broadcast-target"]:checked')?.value || 'users';
      const targetLabel = target === 'users' ? 'all registered candidates' : (target === 'groups' ? 'all authorized community groups' : 'GLOBAL BLAST (Candidates + Groups)');
      if (!confirm(\`Confirm dispatch of announcement to \${targetLabel}?\`)) return;
      const btn = document.getElementById('btn-broadcast');
      btn.innerText = 'Dispatching Announcement... ⏳';
      btn.disabled = true;

      try {
        const res = await apiRequest('/api/admin/broadcast', 'POST', { message, target });
        if (res.success) {
          showToast(\`Dispatched to \${res.delivered} recipients (\${res.failed} skipped)! 🚀\`, 'success');
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

    let currentQuizQuestions = [];

    async function loadQuestionsList(quizId) {
      const container = document.getElementById('questions-list-container');
      container.innerHTML = '<div style="text-align:center; color:var(--text-dark);">Loading questions...</div>';
      try {
        const res = await apiRequest(\`/api/admin/quizzes/\${quizId}/questions\`);
        if (res.success) {
          currentQuizQuestions = res.questions;
          document.getElementById('mq-count').innerText = res.questions.length;
          container.innerHTML = '';
          if (res.questions.length === 0) {
            container.innerHTML = '<div style="text-align:center; color:var(--text-dark); padding:20px;">No questions in this test yet. Add the first question using the form above!</div>';
            return;
          }
          res.questions.forEach((q, idx) => {
            const card = document.createElement('div');
            card.className = 'question-item-card';

            const optsHtml = q.options.map((opt, i) => \`
              <span style="display:inline-block; margin-right:8px; font-size:12px; \${i === q.correct_option_index ? 'color:#34d399; font-weight:600;' : 'color:var(--text-muted);'}">
                \${String.fromCharCode(65 + i)}: \${opt} \${i === q.correct_option_index ? '✓' : ''}
              </span>
            \`).join('');

            card.innerHTML = \`
              <div>
                <div style="font-weight:600; font-size:13px; margin-bottom:6px;">Q\${idx + 1}. \${q.question_text}</div>
                <div style="margin-bottom:4px;">\${optsHtml}</div>
                \${q.explanation ? \`<div style="font-size:11px; color:var(--text-muted); font-style:italic;">💡 \${q.explanation}</div>\` : ''}
              </div>
              <div style="display:flex; gap:6px;">
                <button class="btn btn-secondary" style="padding:4px 8px; font-size:11px;" onclick="openEditQuestionModal('\${q.id}')">✏️ Edit</button>
                <button class="btn btn-danger" style="padding:4px 8px; font-size:11px;" onclick="deleteQuestion('\${q.id}')">Delete</button>
              </div>
            \`;
            container.appendChild(card);
          });
        }
      } catch {
        container.innerHTML = '<div style="color:var(--rose);">Failed to load questions.</div>';
      }
    }

    function openEditQuestionModal(questionId) {
      const q = currentQuizQuestions.find(item => item.id === questionId);
      if (!q) return;
      document.getElementById('eq-q-id').value = q.id;
      document.getElementById('eq-q-text').value = q.question_text || '';
      document.getElementById('eq-q-opt-0').value = q.options[0] || '';
      document.getElementById('eq-q-opt-1').value = q.options[1] || '';
      document.getElementById('eq-q-opt-2').value = q.options[2] || '';
      document.getElementById('eq-q-opt-3').value = q.options[3] || '';
      document.getElementById('eq-q-correct').value = q.correct_option_index ?? 0;
      document.getElementById('eq-q-exp').value = q.explanation || '';
      document.getElementById('modal-edit-question').classList.add('open');
    }

    document.getElementById('edit-question-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const questionId = document.getElementById('eq-q-id').value;
      if (!questionId) return;
      const body = {
        question_text: document.getElementById('eq-q-text').value,
        options: [
          document.getElementById('eq-q-opt-0').value,
          document.getElementById('eq-q-opt-1').value,
          document.getElementById('eq-q-opt-2').value,
          document.getElementById('eq-q-opt-3').value,
        ],
        correct_option_index: Number(document.getElementById('eq-q-correct').value),
        explanation: document.getElementById('eq-q-exp').value,
      };
      try {
        const res = await apiRequest(\`/api/admin/questions/\${questionId}\`, 'PUT', body);
        if (res.success) {
          showToast('Question updated! 💾', 'success');
          closeModal('modal-edit-question');
          loadQuestionsList(currentQuizIdForQuestions);
        } else {
          showToast(res.error || 'Failed to update question.', 'error');
        }
      } catch {
        showToast('Error updating question.', 'error');
      }
    });

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

    async function renameFolderPrompt(folderId, name) {
      const newName = prompt('Enter new title for folder:', name);
      if (!newName || !newName.trim() || newName.trim() === name) return;
      try {
        const res = await apiRequest(\`/api/admin/folders/\${folderId}\`, 'PUT', { name: newName.trim() });
        if (res.success) {
          showToast('Folder renamed! 📁', 'success');
          loadFolders();
        } else {
          showToast(res.error || 'Failed to rename folder.', 'error');
        }
      } catch {
        showToast('Error renaming folder.', 'error');
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

    // THEME MANAGEMENT (DARK / LIGHT / WHITE)
    function initTheme() {
      var current = document.documentElement.getAttribute('data-theme') || 'dark';
      updateThemeUi(current);
    }

    function toggleTheme() {
      var current = document.documentElement.getAttribute('data-theme') || 'dark';
      var next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      try {
        localStorage.setItem('examplayer_admin_theme', next);
      } catch (e) {}
      updateThemeUi(next);
      showToast(next === 'light' ? 'Switched to Light (White) Theme ☀️' : 'Switched to Dark Theme 🌙', 'success');
    }

    function updateThemeUi(theme) {
      var isLight = theme === 'light';
      document.querySelectorAll('.theme-switch-icon').forEach(function(el) {
        el.innerText = isLight ? '🌙' : '☀️';
      });
      document.querySelectorAll('.theme-switch-label').forEach(function(el) {
        el.innerText = isLight ? 'Dark Theme' : 'Light Theme';
      });
    }

    setTimeout(initTheme, 50);
  </script>
</body>
</html>
`;
}
