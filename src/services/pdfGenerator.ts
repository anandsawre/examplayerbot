import PDFDocument from 'pdfkit';
import path from 'node:path';
import fs from 'node:fs';
import { Quiz, Question } from '../types';
import { ScoreResult, formatTime } from './scoring';

export interface StudentInfo {
  id: number;
  name: string;
  username?: string;
}

export interface UserAnswerRecord {
  question_id: string;
  selected_option_index: number;
  is_correct: boolean;
}

const OPTION_LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];

/**
 * Sanitizes and formats text for PDFKit rendering with Noto Sans Devanagari.
 * 1. Converts chemical formulas and equations to standard ASCII-compatible text (e.g., H2O, CO2, x^2)
 *    so that no characters map to missing glyph boxes ▯ (.notdef).
 * 2. Normalizes LaTeX math fractions and square roots.
 * 3. Strips unsupported emojis and checkmarks that render as rectangles.
 */
export function cleanPdfText(text: string): string {
  if (!text) return '';
  let s = text;

  // Convert any Unicode subscripts (₀-₉) back to standard digits so they NEVER render as ▯
  const subMap: Record<string, string> = {
    '₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
    '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9',
  };
  s = s.replace(/[₀₁₂₃₄₅₆₇₈₉]/g, (m) => subMap[m] || m);

  // Convert Unicode superscripts (⁰-⁹) to ^digit notation
  const supMap: Record<string, string> = {
    '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
    '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
  };
  s = s.replace(/[⁰¹²³⁴⁵⁶⁷⁸⁹]/g, (m) => '^' + (supMap[m] || m));

  // LaTeX math notation cleanup
  s = s.replace(/\\frac\s*\{([^}]+)\}\s*\{([^}]+)\}/g, '($1 / $2)');
  s = s.replace(/\\sqrt\s*\{([^}]+)\}/g, 'sqrt($1)');
  s = s.replace(/\\sqrt\b/g, 'sqrt');
  s = s.replace(/\\times\b/g, '×');
  s = s.replace(/\\div\b/g, '÷');
  s = s.replace(/\\degree\b|\^\\circ/g, '°');

  // Strip math mode delimiters ($ or $$)
  s = s.replace(/\${1,2}/g, '');

  // Strip emojis, checkmarks and special symbols that don't exist in NotoSansDevanagari
  s = s.replace(/[\u{1F300}-\u{1FAFF}]/gu, ''); // Emojis like 💡, 🚀
  s = s.replace(/[✓✗✔✖]/g, ''); // Checkmark / cross symbols

  return s.trim();
}

/**
 * Measures the height of a question card in points.
 */
function measureQuestionCardHeight(
  doc: PDFKit.PDFDocument,
  q: Question,
  width: number,
  fontReg: string,
  fontBold: string
): number {
  const innerW = width - 16;
  let h = 8; // top padding

  // Question Title
  doc.font(fontBold).fontSize(8.5);
  const titleText = `Q. ${cleanPdfText(q.question_text)}`;
  h += doc.heightOfString(titleText, { width: innerW }) + 4;

  // Options (Clean: NO "(Correct)" or "(Your Choice)" suffix!)
  const options = Array.isArray(q.options) ? q.options : [];
  doc.fontSize(7.5);
  options.forEach((optText, optIdx) => {
    const letter = OPTION_LETTERS[optIdx] || `${optIdx + 1}`;
    const cleanOpt = cleanPdfText(optText);
    const line = `(${letter}) ${cleanOpt}`;
    doc.font(fontBold);
    h += doc.heightOfString(line, { width: innerW }) + 2.5;
  });

  // Answer & Explanation Box at the bottom of the card
  const correctLetter = OPTION_LETTERS[q.correct_option_index] || 'A';
  let solText = `Ans: (${correctLetter})`;
  if (q.explanation && q.explanation.trim()) {
    solText += `  •  Explanation: ${cleanPdfText(q.explanation.trim())}`;
  }
  doc.font(fontReg).fontSize(7);
  const solH = doc.heightOfString(solText, { width: innerW - 10 }) + 6;
  h += solH + 6;

  h += 6; // bottom padding
  return Math.ceil(h);
}

/**
 * Draws a single question card at (x, y) with fixed width and height.
 */
function drawQuestionCard(
  doc: PDFKit.PDFDocument,
  q: Question,
  qNum: number,
  userAns: UserAnswerRecord | undefined,
  x: number,
  y: number,
  width: number,
  height: number,
  fontReg: string,
  fontBold: string
) {
  // 1. Card Container (White card with crisp border)
  doc.roundedRect(x, y, width, height, 4)
    .fillAndStroke('#FFFFFF', '#CBD5E1');

  let curY = y + 7;
  const innerX = x + 8;
  const innerW = width - 16;

  // 2. Question Title (Clean, professional, without clutter badges)
  const cleanTitle = `Q${qNum}. ${cleanPdfText(q.question_text)}`;
  doc.fillColor('#0F172A').font(fontBold).fontSize(8.5);
  doc.text(cleanTitle, innerX, curY, { width: innerW });
  curY += doc.heightOfString(cleanTitle, { width: innerW }) + 4;

  // 3. Options (NO "(Correct)" or "(Your Choice)" text! Clean option presentation)
  const options = Array.isArray(q.options) ? q.options : [];
  options.forEach((optText, optIdx) => {
    const letter = OPTION_LETTERS[optIdx] || `${optIdx + 1}`;
    const isCorrect = optIdx === q.correct_option_index;
    const isSelected = userAns && userAns.selected_option_index === optIdx;
    const cleanOpt = cleanPdfText(optText);

    let textColor = '#334155'; // Slate
    let fontChoice = fontReg;

    if (isCorrect) {
      textColor = '#15803D'; // Bold Green for correct option
      fontChoice = fontBold;
    } else if (isSelected) {
      textColor = '#DC2626'; // Bold Red if candidate selected this wrong option
      fontChoice = fontBold;
    }

    const optLine = `(${letter}) ${cleanOpt}`;
    doc.fillColor(textColor).font(fontChoice).fontSize(7.5);
    doc.text(optLine, innerX + 2, curY, { width: innerW - 2 });
    curY += doc.heightOfString(optLine, { width: innerW - 2 }) + 2;
  });

  // 4. Solution & Explanation Box at the bottom of the card
  curY += 2;
  const correctLetter = OPTION_LETTERS[q.correct_option_index] || 'A';
  let solText = `Ans: (${correctLetter})`;

  if (userAns && !userAns.is_correct && userAns.selected_option_index >= 0) {
    const selLetter = OPTION_LETTERS[userAns.selected_option_index] || '';
    solText += `  (Your Choice: ${selLetter})`;
  }

  if (q.explanation && q.explanation.trim()) {
    solText += `  •  Explanation: ${cleanPdfText(q.explanation.trim())}`;
  }

  doc.font(fontReg).fontSize(7);
  const solH = doc.heightOfString(solText, { width: innerW - 10 }) + 6;

  doc.roundedRect(innerX, curY, innerW, solH, 3)
    .fillAndStroke('#F0FDF4', '#BBF7D0');

  doc.fillColor('#166534').font(fontReg).fontSize(7);
  doc.text(solText, innerX + 5, curY + 3, { width: innerW - 10 });
}

/**
 * Generates an official Side-by-Side (2-Column) Examination Solutions Booklet.
 * Fully supports Hindi / Devanagari and English Unicode text, scientific formulas,
 * and guarantees zero blank pages.
 */
export async function generateScorecardPdf(
  quiz: Quiz,
  questions: Question[],
  student: StudentInfo,
  result?: ScoreResult,
  userAnswers?: UserAnswerRecord[]
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: 'A4',
        margin: 36,
        bufferPages: true, // Buffer all pages so footers & page count are added cleanly with NO blank pages!
        info: {
          Title: `${quiz.title} - Scorecard & Solutions`,
          Author: 'Examplayer Platform',
          Subject: 'Examination Scorecard & Solutions Booklet',
          Keywords: 'quiz, exam, scorecard, solutions, examplayer',
        },
      });

      // Register Unicode Fonts for Devanagari / Hindi & English rendering
      const fontDir = path.join(process.cwd(), 'assets', 'fonts');
      const fontRegPath = path.join(fontDir, 'NotoSansDevanagari-Regular.ttf');
      const fontBoldPath = path.join(fontDir, 'NotoSansDevanagari-Bold.ttf');

      let regularFont = 'Helvetica';
      let boldFont = 'Helvetica-Bold';

      if (fs.existsSync(fontRegPath) && fs.existsSync(fontBoldPath)) {
        doc.registerFont('AppFont', fontRegPath);
        doc.registerFont('AppFontBold', fontBoldPath);
        regularFont = 'AppFont';
        boldFont = 'AppFontBold';
      }

      const buffers: Buffer[] = [];
      doc.on('data', (chunk) => buffers.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', (err) => reject(err));

      const pageWidth = doc.page.width; // 595.28 for A4
      const pageHeight = doc.page.height; // 841.89 for A4
      const contentWidth = pageWidth - 72; // 523.28

      // ================= 1. HEADER BANNER =================
      doc.rect(36, 36, contentWidth, 50).fill('#1E3A8A'); // Dark Blue

      doc.fillColor('#FFFFFF')
        .fontSize(16)
        .font(boldFont)
        .text('EXAMPLAYER EXAMINATION PLATFORM', 46, 44, { width: contentWidth - 20, align: 'center' });

      doc.fontSize(9)
        .font(regularFont)
        .fillColor('#93C5FD') // Light blue
        .text('Official Examination Scorecard & Detailed Solution Booklet', 46, 64, { width: contentWidth - 20, align: 'center' });

      doc.y = 94;

      // ================= 2. CANDIDATE & TEST INFO BOX =================
      const infoBoxY = doc.y;
      doc.rect(36, infoBoxY, contentWidth, 60)
        .fillAndStroke('#F8FAFC', '#CBD5E1');

      doc.fillColor('#1E293B').font(boldFont).fontSize(8.5);

      // Left Column: Candidate Info
      doc.text('CANDIDATE DETAILS', 48, infoBoxY + 6);
      doc.font(regularFont).fontSize(8).fillColor('#334155');
      doc.text(`Name: `, 48, infoBoxY + 18, { continued: true })
        .font(boldFont).text(student.name);
      doc.font(regularFont).text(`Telegram ID: `, 48, infoBoxY + 30, { continued: true })
        .font(boldFont).text(String(student.id));
      doc.font(regularFont).text(`Date: `, 48, infoBoxY + 42, { continued: true })
        .font(boldFont).text(new Date().toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata', day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }));

      // Right Column: Exam Info
      const rightColX = 300;
      doc.font(boldFont).fontSize(8.5).fillColor('#1E293B');
      doc.text('EXAMINATION SCHEME', rightColX, infoBoxY + 6);
      doc.font(regularFont).fontSize(8).fillColor('#334155');
      doc.text(`Paper: `, rightColX, infoBoxY + 18, { continued: true })
        .font(boldFont).text(quiz.title.slice(0, 36));
      doc.font(regularFont).text(`Subject: `, rightColX, infoBoxY + 30, { continued: true })
        .font(boldFont).text(quiz.category || 'General');
      doc.font(regularFont).text(`Marking: `, rightColX, infoBoxY + 42, { continued: true })
        .font(boldFont).text(`+${quiz.marks_per_question} / -${quiz.negative_marks} per question`);

      doc.y = infoBoxY + 66;

      // ================= 3. PERFORMANCE SUMMARY (IF RESULT PROVIDED) =================
      if (result) {
        const perfBoxY = doc.y;
        doc.rect(36, perfBoxY, contentWidth, 50)
          .fillAndStroke('#EEF2FF', '#C7D2FE');

        const colW = contentWidth / 4;

        // Card 1: Score
        doc.fillColor('#1E3A8A').font(boldFont).fontSize(12)
          .text(`${result.finalScore} / ${result.maxScore}`, 36, perfBoxY + 9, { width: colW, align: 'center' });
        doc.fillColor('#4B5563').font(regularFont).fontSize(7.5)
          .text('TOTAL SCORE', 36, perfBoxY + 27, { width: colW, align: 'center' });

        // Card 2: Accuracy
        doc.fillColor('#0D9488').font(boldFont).fontSize(12)
          .text(`${result.accuracy}%`, 36 + colW, perfBoxY + 9, { width: colW, align: 'center' });
        doc.fillColor('#4B5563').font(regularFont).fontSize(7.5)
          .text('ACCURACY', 36 + colW, perfBoxY + 27, { width: colW, align: 'center' });

        // Card 3: Breakdown
        doc.fillColor('#15803D').font(boldFont).fontSize(10)
          .text(`✅ ${result.correctCount}  ❌ ${result.wrongCount}  ⏭️ ${result.skippedCount}`, 36 + colW * 2, perfBoxY + 11, { width: colW, align: 'center' });
        doc.fillColor('#4B5563').font(regularFont).fontSize(7.5)
          .text('BREAKDOWN', 36 + colW * 2, perfBoxY + 27, { width: colW, align: 'center' });

        // Card 4: Time & Remark
        const timeStr = formatTime(result.timeTakenSeconds);
        doc.fillColor('#6366F1').font(boldFont).fontSize(10)
          .text(`${timeStr}`, 36 + colW * 3, perfBoxY + 9, { width: colW, align: 'center' });
        doc.fillColor('#4338CA').font(boldFont).fontSize(7.5)
          .text(`${result.remark}`, 36 + colW * 3, perfBoxY + 25, { width: colW, align: 'center' });

        doc.y = perfBoxY + 56;
      }

      // ================= 4. SECTION BANNER: SOLUTIONS =================
      doc.rect(36, doc.y, contentWidth, 20).fill('#334155');
      doc.fillColor('#FFFFFF').font(boldFont).fontSize(8.5)
        .text('DETAILED QUESTION-BY-QUESTION SOLUTIONS (EXAMINATION SCHEME)', 46, doc.y + 5);

      doc.y += 26;

      // Build Answer Lookup Map if userAnswers provided
      const answerMap = new Map<string, UserAnswerRecord>();
      if (userAnswers) {
        userAnswers.forEach((ans) => answerMap.set(ans.question_id, ans));
      }

      // ================= 5. SIDE-BY-SIDE (2-COLUMN) QUESTIONS LOOP =================
      const columnGap = 16;
      const colWidth = (contentWidth - columnGap) / 2; // 253.64 pt
      const col1X = 36;
      const col2X = 36 + colWidth + columnGap;
      const maxContentY = pageHeight - 44; // Leave 44pt for bottom margin and footer

      for (let i = 0; i < questions.length; i += 2) {
        const qLeft = questions[i];
        const qRight = i + 1 < questions.length ? questions[i + 1] : null;

        const hLeft = measureQuestionCardHeight(doc, qLeft, colWidth, regularFont, boldFont);
        const hRight = qRight ? measureQuestionCardHeight(doc, qRight, colWidth, regularFont, boldFont) : 0;
        const rowHeight = Math.max(hLeft, hRight);

        // Check if row fits on current page
        if (doc.y + rowHeight > maxContentY) {
          doc.addPage();
          doc.y = 36;
        }

        const startY = doc.y;

        // Draw Left Card
        drawQuestionCard(
          doc,
          qLeft,
          i + 1,
          answerMap.get(qLeft.id),
          col1X,
          startY,
          colWidth,
          rowHeight,
          regularFont,
          boldFont
        );

        // Draw Right Card (if present)
        if (qRight) {
          drawQuestionCard(
            doc,
            qRight,
            i + 2,
            answerMap.get(qRight.id),
            col2X,
            startY,
            colWidth,
            rowHeight,
            regularFont,
            boldFont
          );
        }

        doc.y = startY + rowHeight + 8;
      }

      // ================= 6. DRAW FOOTER ON ALL BUFFERED PAGES =================
      const pageRange = doc.bufferedPageRange();
      const totalPages = pageRange.count;

      for (let p = pageRange.start; p < pageRange.start + totalPages; p++) {
        doc.switchToPage(p);

        // Disable bottom margin so footer text never triggers an auto-page-break!
        doc.page.margins.bottom = 0;

        const footerY = pageHeight - 26;
        doc.moveTo(36, footerY).lineTo(pageWidth - 36, footerY).strokeColor('#CBD5E1').lineWidth(0.5).stroke();

        doc.fillColor('#64748B').font(regularFont).fontSize(7.5);
        doc.text('Examplayer Platform | Telegram: @Examplayer_bot | Automated Testing Platform', 36, footerY + 5, {
          width: contentWidth - 80,
          align: 'left',
          lineBreak: false,
        });

        doc.text(`Page ${p + 1} of ${totalPages}`, pageWidth - 116, footerY + 5, {
          width: 80,
          align: 'right',
          lineBreak: false,
        });
      }

      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}
