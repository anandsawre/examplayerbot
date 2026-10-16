import { createCanvas, GlobalFonts } from '@napi-rs/canvas';
import path from 'node:path';
import fs from 'node:fs';

// Register Hindi Devanagari fonts once at startup
try {
  const fontDir = path.join(process.cwd(), 'assets', 'fonts');
  const fontBoldPath = path.join(fontDir, 'NotoSansDevanagari-Bold.ttf');
  const fontRegPath = path.join(fontDir, 'NotoSansDevanagari-Regular.ttf');

  if (fs.existsSync(fontBoldPath)) {
    GlobalFonts.registerFromPath(fontBoldPath, 'DevaBold');
  }
  if (fs.existsSync(fontRegPath)) {
    GlobalFonts.registerFromPath(fontRegPath, 'DevaReg');
  }
} catch (e) {
  console.warn('Font registration notice:', e);
}

export interface LeaderboardCardEntry {
  rank: number;
  name: string;
  correctCount: number;
  wrongCount: number;
  negPenalty?: number;
  score: number;
  timeTakenSeconds: number;
  accuracy: number;
}

export function formatDisplayTime(seconds: number): string {
  if (!seconds || seconds <= 0) return '0s';
  if (seconds < 60) return `${Math.max(1, Math.round(seconds))}s`;
  const m = Math.floor(seconds / 60);
  const s = Math.round(seconds % 60);
  return s > 0 ? `${m}m ${s}s` : `${m}m`;
}

export function cleanDisplayName(name: string): string {
  if (!name) return 'Candidate';
  let s = name.normalize('NFKD')
    .replace(/[\uE000-\uF8FF]/g, '')
    .replace(/[^\p{L}\p{N}\s._\-@()]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return s.length > 20 ? s.slice(0, 19) + '…' : (s || 'Candidate');
}

// 1. Vector Golden Trophy for Card Header
function drawTitleTrophy(ctx: any, x: number, y: number) {
  ctx.save();
  ctx.translate(x, y);

  // Cup Bowl
  ctx.fillStyle = '#F59E0B'; // Gold
  ctx.beginPath();
  ctx.moveTo(3, 4);
  ctx.lineTo(21, 4);
  ctx.lineTo(19, 15);
  ctx.arc(12, 15, 7, 0, Math.PI, false);
  ctx.closePath();
  ctx.fill();

  // Handles
  ctx.strokeStyle = '#D97706';
  ctx.lineWidth = 2;
  ctx.beginPath();
  // Left handle
  ctx.moveTo(4, 6);
  ctx.bezierCurveTo(-2, 6, -2, 14, 6, 14);
  // Right handle
  ctx.moveTo(20, 6);
  ctx.bezierCurveTo(26, 6, 26, 14, 18, 14);
  ctx.stroke();

  // Stem & Base
  ctx.fillStyle = '#D97706';
  ctx.fillRect(10.5, 17, 3, 5);
  ctx.fillRect(6, 21, 12, 3);

  ctx.restore();
}

// 2. Vector Green Checkmark Box (✅)
function drawGreenCheckmark(ctx: any, cx: number, cy: number, size = 19) {
  ctx.save();
  const half = size / 2;
  const x = cx - half;
  const y = cy - half;
  const r = 4;

  ctx.fillStyle = '#16A34A';
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + size - r, y);
  ctx.quadraticCurveTo(x + size, y, x + size, y + r);
  ctx.lineTo(x + size, y + size - r);
  ctx.quadraticCurveTo(x + size, y + size, x + size - r, y + size);
  ctx.lineTo(x + r, y + size);
  ctx.quadraticCurveTo(x, y + size, x, y + size - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
  ctx.fill();

  ctx.strokeStyle = '#FFFFFF';
  ctx.lineWidth = 2.4;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(x + 4.5, y + 9.5);
  ctx.lineTo(x + 8, y + 13.5);
  ctx.lineTo(x + 14.5, y + 6);
  ctx.stroke();

  ctx.restore();
}

// 3. Vector Red Cross (❌)
function drawRedCross(ctx: any, cx: number, cy: number, size = 17) {
  ctx.save();
  const half = size / 2;
  ctx.strokeStyle = '#DC2626';
  ctx.lineWidth = 3.2;
  ctx.lineCap = 'round';

  ctx.beginPath();
  ctx.moveTo(cx - half + 2, cy - half + 2);
  ctx.lineTo(cx + half - 2, cy + half - 2);
  ctx.moveTo(cx + half - 2, cy - half + 2);
  ctx.lineTo(cx - half + 2, cy + half - 2);
  ctx.stroke();

  ctx.restore();
}

// 4. Vector Ribbon Medal Badge for Ranks 1, 2, 3
function drawMedalBadge(ctx: any, cx: number, cy: number, rank: number) {
  ctx.save();

  // Ribbon straps at top
  ctx.fillStyle = '#3B82F6'; // Blue left
  ctx.beginPath();
  ctx.moveTo(cx - 5, cy - 14);
  ctx.lineTo(cx - 1, cy - 8);
  ctx.lineTo(cx - 7, cy - 6);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = '#EF4444'; // Red right
  ctx.beginPath();
  ctx.moveTo(cx + 5, cy - 14);
  ctx.lineTo(cx + 1, cy - 8);
  ctx.lineTo(cx + 7, cy - 6);
  ctx.closePath();
  ctx.fill();

  // Medal Coin Circle
  let fillColor = '#F59E0B'; // Gold
  let strokeColor = '#B45309';
  let textColor = '#78350F';

  if (rank === 2) {
    fillColor = '#CBD5E1'; // Silver
    strokeColor = '#64748B';
    textColor = '#334155';
  } else if (rank === 3) {
    fillColor = '#FDBA74'; // Bronze
    strokeColor = '#C2410C';
    textColor = '#7C2D12';
  }

  const radius = 9.5;
  ctx.fillStyle = fillColor;
  ctx.strokeStyle = strokeColor;
  ctx.lineWidth = 1.2;

  ctx.beginPath();
  ctx.arc(cx, cy + 1, radius, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  // Number inside medal
  ctx.fillStyle = textColor;
  ctx.font = 'bold 11px sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(String(rank), cx, cy + 1.5);

  ctx.restore();
}

function wrapTitle(title: string, maxCharsPerLine = 42): string[] {
  if (title.length <= maxCharsPerLine) return [title];
  const words = title.split(' ');
  const lines: string[] = [];
  let current = '';
  for (const w of words) {
    if ((current + ' ' + w).trim().length <= maxCharsPerLine) {
      current = (current + ' ' + w).trim();
    } else {
      if (current) lines.push(current);
      current = w;
    }
  }
  if (current) lines.push(current);
  return lines.slice(0, 2);
}

/**
 * Generates the official Telegram Leaderboard Card Image.
 * Matches user's exact reference sample with 8 complete performance columns:
 * [# (Ribbon Medal) | Name | ✅ (Sahi) | ❌ (Galt) | -Neg (Negative) | Score (Obtained) | Time (Time Taken) | % (Accuracy)]
 */
export function generateLeaderboardImage(
  title: string,
  entries: LeaderboardCardEntry[]
): Buffer {
  const width = 640;
  const paddingX = 18;
  const tableWidth = width - paddingX * 2; // 604px

  const titleLines = wrapTitle(title, 42);
  const titleHeight = titleLines.length > 1 ? 62 : 44;
  const headerHeight = 40;
  const rowHeight = 42;
  const bottomPadding = 18;

  // Show up to 50 participants cleanly on the card
  const displayEntries = entries.slice(0, 50);
  const tableHeight = headerHeight + Math.max(1, displayEntries.length) * rowHeight;
  const height = paddingX + titleHeight + tableHeight + bottomPadding;

  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');

  // 1. Pure White Card Background
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(0, 0, width, height);

  // 2. Title with Golden Trophy
  drawTitleTrophy(ctx, paddingX, paddingX + 2);
  ctx.fillStyle = '#0F172A';
  ctx.font = 'bold 16px DevaBold, sans-serif';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';

  if (titleLines.length === 1) {
    ctx.fillText(titleLines[0], paddingX + 28, paddingX + 14);
  } else {
    ctx.fillText(titleLines[0], paddingX + 28, paddingX + 12);
    ctx.fillText(titleLines[1], paddingX + 28, paddingX + 34);
  }

  // 3. Table Column Widths: [#, Name, ✅, ❌, -Neg, Score, Time, %]
  // Total: 42 + 190 + 48 + 48 + 56 + 74 + 84 + 62 = 604px
  const colWidths = [42, 190, 48, 48, 56, 74, 84, 62];
  const colX: number[] = [];
  let curX = paddingX;
  for (const w of colWidths) {
    colX.push(curX);
    curX += w;
  }

  const tableTop = paddingX + titleHeight;

  // Outer Border
  ctx.strokeStyle = '#D1D5DB';
  ctx.lineWidth = 1;
  ctx.strokeRect(paddingX, tableTop, tableWidth, tableHeight);

  // Header Row Background (Subtle light grey)
  ctx.fillStyle = '#F3F4F6';
  ctx.fillRect(paddingX, tableTop, tableWidth, headerHeight);

  // Header Bottom Line
  ctx.strokeStyle = '#D1D5DB';
  ctx.beginPath();
  ctx.moveTo(paddingX, tableTop + headerHeight);
  ctx.lineTo(paddingX + tableWidth, tableTop + headerHeight);
  ctx.stroke();

  // Vertical Dividers
  for (let c = 1; c < colX.length; c++) {
    ctx.beginPath();
    ctx.moveTo(colX[c], tableTop);
    ctx.lineTo(colX[c], tableTop + tableHeight);
    ctx.stroke();
  }

  // Header Labels
  const headerY = tableTop + headerHeight / 2;
  ctx.font = 'bold 14px DevaBold, sans-serif';
  ctx.fillStyle = '#374151';
  ctx.textBaseline = 'middle';

  // #
  ctx.textAlign = 'center';
  ctx.fillText('#', colX[0] + colWidths[0] / 2, headerY);

  // Name
  ctx.textAlign = 'left';
  ctx.fillText('Name', colX[1] + 10, headerY);

  // ✅ (Vector Green Box)
  drawGreenCheckmark(ctx, colX[2] + colWidths[2] / 2, headerY, 19);

  // ❌ (Vector Red Cross)
  drawRedCross(ctx, colX[3] + colWidths[3] / 2, headerY, 17);

  // -Neg
  ctx.textAlign = 'center';
  ctx.fillStyle = '#DC2626';
  ctx.fillText('-Neg', colX[4] + colWidths[4] / 2, headerY);

  // Score
  ctx.fillStyle = '#374151';
  ctx.fillText('Score', colX[5] + colWidths[5] / 2, headerY);

  // Time
  ctx.fillText('Time', colX[6] + colWidths[6] / 2, headerY);

  // %
  ctx.fillText('%', colX[7] + colWidths[7] / 2, headerY);

  // If no entries, draw empty state
  if (displayEntries.length === 0) {
    const rowCenterY = tableTop + headerHeight + rowHeight / 2;
    ctx.fillStyle = '#64748B';
    ctx.font = '14px DevaBold, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('No candidate attempts recorded yet.', paddingX + tableWidth / 2, rowCenterY);
    return canvas.toBuffer('image/png');
  }

  // 4. Data Rows
  displayEntries.forEach((entry, idx) => {
    const rowTop = tableTop + headerHeight + idx * rowHeight;
    const rowCenterY = rowTop + rowHeight / 2;

    // Horizontal Row Divider
    ctx.strokeStyle = '#E5E7EB';
    ctx.beginPath();
    ctx.moveTo(paddingX, rowTop + rowHeight);
    ctx.lineTo(paddingX + tableWidth, rowTop + rowHeight);
    ctx.stroke();

    // Col 0: Rank / Ribbon Medal Badge
    if (entry.rank >= 1 && entry.rank <= 3) {
      drawMedalBadge(ctx, colX[0] + colWidths[0] / 2, rowCenterY, entry.rank);
    } else {
      ctx.font = 'bold 14px DevaBold, sans-serif';
      ctx.fillStyle = '#4B5563';
      ctx.textAlign = 'center';
      ctx.fillText(String(entry.rank), colX[0] + colWidths[0] / 2, rowCenterY);
    }

    // Col 1: Name
    ctx.textAlign = 'left';
    ctx.fillStyle = '#111827';
    ctx.font = 'bold 14px DevaBold, sans-serif';
    ctx.fillText(cleanDisplayName(entry.name), colX[1] + 10, rowCenterY);

    // Col 2: ✅ (Kitna Sahi)
    ctx.textAlign = 'center';
    ctx.font = 'bold 14px DevaBold, sans-serif';
    ctx.fillStyle = '#1F2937';
    ctx.fillText(String(entry.correctCount), colX[2] + colWidths[2] / 2, rowCenterY);

    // Col 3: ❌ (Kitna Galt)
    ctx.fillText(String(entry.wrongCount), colX[3] + colWidths[3] / 2, rowCenterY);

    // Col 4: -Neg (Kitna Negative)
    const negVal = entry.negPenalty || 0;
    ctx.fillStyle = negVal > 0 ? '#DC2626' : '#6B7280';
    const negText = negVal > 0 ? ('-' + negVal.toFixed(1)) : '0.0';
    ctx.fillText(negText, colX[4] + colWidths[4] / 2, rowCenterY);

    // Col 5: Score (Obtained Marks)
    ctx.font = 'bold 14px DevaBold, sans-serif';
    ctx.fillStyle = '#111827';
    ctx.fillText(entry.score.toFixed(2), colX[5] + colWidths[5] / 2, rowCenterY);

    // Col 6: Time (Time Taken)
    ctx.font = 'bold 13.5px DevaBold, sans-serif';
    ctx.fillStyle = '#374151';
    ctx.fillText(formatDisplayTime(entry.timeTakenSeconds), colX[6] + colWidths[6] / 2, rowCenterY);

    // Col 7: % (Accuracy)
    ctx.font = 'bold 13.5px DevaBold, sans-serif';
    ctx.fillStyle = '#111827';
    ctx.fillText(Math.round(entry.accuracy) + '%', colX[7] + colWidths[7] / 2, rowCenterY);
  });

  return canvas.toBuffer('image/png');
}
