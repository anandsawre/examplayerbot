/**
 * Leaderboard Table Generator
 * Formats high-precision monospace box tables for Telegram messages.
 * Displays all key competitive metrics:
 * [# (Rank/Medal) | Candidate | ✅ (Correct) | ❌ (Wrong) | -Neg (Penalty) | Score (Obtained) | Time (Taken) | % (Accuracy)]
 */

export interface LeaderboardTableEntry {
  rank: number;
  name: string;
  correctCount: number;
  wrongCount: number;
  negPenalty: number;
  score: number;
  timeSeconds: number;
  accuracy: number;
}

export function formatTableTime(seconds: number): string {
  if (!seconds || seconds <= 0) return '0s';
  if (seconds < 60) return `${Math.max(1, Math.round(seconds))}s`;
  const m = Math.floor(seconds / 60);
  const s = Math.round(seconds % 60);
  return s > 0 ? `${m}m${s < 10 ? '0' : ''}${s}s` : `${m}m`;
}

export function cleanDisplayName(name: string): string {
  if (!name) return 'Candidate';
  let s = name.normalize('NFKD')
    .replace(/[\uE000-\uF8FF]/g, '')
    .replace(/[➳🏹➜➔➤]/g, '')
    .replace(/[\u{1F300}-\u{1FAFF}]/gu, '')
    .trim();
  return s || 'Candidate';
}

function pad(str: string | number, len: number, align: 'left' | 'right' = 'left'): string {
  let s = String(str);
  if (s.length > len) {
    s = s.slice(0, len - 1) + '…';
  }
  return align === 'right' ? s.padStart(len, ' ') : s.padEnd(len, ' ');
}

/**
 * Builds the official 8-column monospace table string for Telegram <pre> blocks.
 * Exactly 48 characters wide per row to prevent wrapping on mobile devices.
 */
export function buildLeaderboardBoxTable(entries: LeaderboardTableEntry[]): string {
  if (!entries || entries.length === 0) {
    return 'No candidate attempts recorded yet.';
  }

  const MEDALS = ['🥇', '🥈', '🥉'];
  let out = '┌──┬────────────┬──┬──┬─────┬──────┬──────┬────┐\n';
  out +=    '│# │Candidate   │✅│❌│ -Neg│ Score│  Time│   %│\n';
  out +=    '├──┼────────────┼──┼──┼─────┼──────┼──────┼────┤\n';

  entries.forEach((e) => {
    const rankStr = e.rank <= 3 ? MEDALS[e.rank - 1] : pad(e.rank, 2, 'right');
    const nameStr = pad(cleanDisplayName(e.name), 12);
    const cStr = pad(e.correctCount, 2, 'right');
    const wStr = pad(e.wrongCount, 2, 'right');
    const negStr = pad(e.negPenalty > 0 ? `-${e.negPenalty.toFixed(1)}` : ' 0.0', 5, 'right');
    const scoreStr = pad(e.score.toFixed(2), 6, 'right');
    const timeStr = pad(formatTableTime(e.timeSeconds), 6, 'right');
    const pctStr = pad(`${e.accuracy}%`, 4, 'right');

    out += `│${rankStr}│${nameStr}│${cStr}│${wStr}│${negStr}│${scoreStr}│${timeStr}│${pctStr}│\n`;
  });

  out +=    '└──┴────────────┴──┴──┴─────┴──────┴──────┴────┘';
  return out;
}

/**
 * Escapes characters for Telegram HTML parse_mode
 */
export function escapeHtml(str: string): string {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}
