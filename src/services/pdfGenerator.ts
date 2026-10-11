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
 * Generates a high-quality PDF Scorecard & Detailed Solutions Booklet as a Buffer.
 * Fully supports Hindi / Devanagari and English Unicode text using Noto Sans Devanagari.
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
        info: {
          Title: `${quiz.title} - Scorecard & Solutions`,
          Author: 'Examplayer Bot',
          Subject: 'Examination Scorecard & Solutions',
          Keywords: 'quiz, exam, scorecard, solutions, examplayer',
        },
      });

      // Register Unicode Fonts for perfect Devanagari / Hindi & English rendering
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
      doc.rect(36, 36, contentWidth, 54).fill('#1E3A8A'); // Dark Blue

      doc.fillColor('#FFFFFF')
        .fontSize(17)
        .font(boldFont)
        .text('EXAMPLAYER EXAMINATION PLATFORM', 46, 46, { width: contentWidth - 20, align: 'center' });

      doc.fontSize(9.5)
        .font(regularFont)
        .fillColor('#93C5FD') // Light blue
        .text('Official Examination Scorecard & Detailed Solution Booklet', 46, 68, { width: contentWidth - 20, align: 'center' });

      doc.y = 100;

      // ================= 2. CANDIDATE & TEST INFO BOX =================
      const infoBoxY = doc.y;
      doc.rect(36, infoBoxY, contentWidth, 68)
        .fillAndStroke('#F8FAFC', '#CBD5E1');

      doc.fillColor('#1E293B').font(boldFont).fontSize(9);

      // Left Column: Candidate Info
      doc.text('CANDIDATE DETAILS', 48, infoBoxY + 8);
      doc.font(regularFont).fontSize(9).fillColor('#334155');
      doc.text(`Name: `, 48, infoBoxY + 22, { continued: true })
        .font(boldFont).text(student.name);
      doc.font(regularFont).text(`Telegram ID: `, 48, infoBoxY + 36, { continued: true })
        .font(boldFont).text(String(student.id));
      doc.font(regularFont).text(`Date: `, 48, infoBoxY + 50, { continued: true })
        .font(boldFont).text(new Date().toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata', day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }));

      // Right Column: Exam Info
      const rightColX = 300;
      doc.font(boldFont).fontSize(9).fillColor('#1E293B');
      doc.text('EXAM DETAILS', rightColX, infoBoxY + 8);
      doc.font(regularFont).fontSize(9).fillColor('#334155');
      doc.text(`Test Name: `, rightColX, infoBoxY + 22, { continued: true })
        .font(boldFont).text(quiz.title.slice(0, 32));
      doc.font(regularFont).text(`Category: `, rightColX, infoBoxY + 36, { continued: true })
        .font(boldFont).text(quiz.category || 'General');
      doc.font(regularFont).text(`Marking: `, rightColX, infoBoxY + 50, { continued: true })
        .font(boldFont).text(`+${quiz.marks_per_question} / -${quiz.negative_marks} per question`);

      doc.y = infoBoxY + 76;

      // ================= 3. PERFORMANCE SUMMARY (IF RESULT PROVIDED) =================
      if (result) {
        const perfBoxY = doc.y;
        doc.rect(36, perfBoxY, contentWidth, 60)
          .fillAndStroke('#EEF2FF', '#C7D2FE');

        const colW = contentWidth / 4;

        // Card 1: Score
        doc.fillColor('#1E3A8A').font(boldFont).fontSize(14)
          .text(`${result.finalScore} / ${result.maxScore}`, 36, perfBoxY + 12, { width: colW, align: 'center' });
        doc.fillColor('#4B5563').font(regularFont).fontSize(8)
          .text('TOTAL SCORE', 36, perfBoxY + 32, { width: colW, align: 'center' });

        // Card 2: Accuracy
        doc.fillColor('#0D9488').font(boldFont).fontSize(14)
          .text(`${result.accuracy}%`, 36 + colW, perfBoxY + 12, { width: colW, align: 'center' });
        doc.fillColor('#4B5563').font(regularFont).fontSize(8)
          .text('ACCURACY', 36 + colW, perfBoxY + 32, { width: colW, align: 'center' });

        // Card 3: Breakdown (Correct/Wrong/Skipped)
        doc.fillColor('#15803D').font(boldFont).fontSize(11)
          .text(`✅ ${result.correctCount}  ❌ ${result.wrongCount}  ⏭️ ${result.skippedCount}`, 36 + colW * 2, perfBoxY + 14, { width: colW, align: 'center' });
        doc.fillColor('#4B5563').font(regularFont).fontSize(8)
          .text('ANSWERS BREAKDOWN', 36 + colW * 2, perfBoxY + 32, { width: colW, align: 'center' });

        // Card 4: Time & Verdict
        const timeStr = formatTime(result.timeTakenSeconds);
        doc.fillColor('#6366F1').font(boldFont).fontSize(11)
          .text(`${timeStr}`, 36 + colW * 3, perfBoxY + 12, { width: colW, align: 'center' });
        doc.fillColor('#4338CA').font(boldFont).fontSize(8)
          .text(`${result.remark}`, 36 + colW * 3, perfBoxY + 30, { width: colW, align: 'center' });

        doc.y = perfBoxY + 68;
      }

      // ================= 4. SECTION TITLE: DETAILED SOLUTIONS =================
      doc.rect(36, doc.y, contentWidth, 22).fill('#334155');
      doc.fillColor('#FFFFFF').font(boldFont).fontSize(9)
        .text('DETAILED QUESTION-BY-QUESTION SOLUTIONS & ANALYSIS', 46, doc.y + 6);

      doc.y += 28;

      // Build Answer Lookup Map if userAnswers provided
      const answerMap = new Map<string, UserAnswerRecord>();
      if (userAnswers) {
        userAnswers.forEach((ans) => answerMap.set(ans.question_id, ans));
      }

      // ================= 5. QUESTIONS LOOP =================
      for (let i = 0; i < questions.length; i++) {
        const q = questions[i];
        const options = Array.isArray(q.options) ? q.options : [];
        const userAns = answerMap.get(q.id);

        // Estimate question block height before writing
        if (doc.y > pageHeight - 160) {
          drawFooter(doc, pageWidth, pageHeight, regularFont);
          doc.addPage();
          doc.y = 40;
        }

        // Question status badge
        let qStatusBadge = '';
        if (userAns) {
          if (userAns.is_correct) {
            qStatusBadge = ' [Correct +Marks]';
          } else if (userAns.selected_option_index === -1) {
            qStatusBadge = ' [Skipped]';
          } else {
            qStatusBadge = ' [Incorrect -Negative]';
          }
        }

        // Question Title
        doc.fillColor('#0F172A').font(boldFont).fontSize(10);
        doc.text(`Q${i + 1}. ${q.question_text}${qStatusBadge}`, 42, doc.y, {
          width: contentWidth - 12,
        });

        doc.y += 4;

        // Options
        options.forEach((optText, optIdx) => {
          const letter = OPTION_LETTERS[optIdx] || `${optIdx + 1}`;
          const isCorrect = optIdx === q.correct_option_index;
          const isSelected = userAns && userAns.selected_option_index === optIdx;

          let bullet = `  (${letter}) `;
          let suffix = '';

          if (isCorrect) {
            doc.font(boldFont).fontSize(9).fillColor('#15803D'); // Green
            suffix = '  <-- Correct Answer';
          } else if (isSelected) {
            doc.font(boldFont).fontSize(9).fillColor('#DC2626'); // Red
            suffix = '  <-- Your Choice (Wrong)';
          } else {
            doc.font(regularFont).fontSize(9).fillColor('#334155');
          }

          if (isSelected && isCorrect) {
            suffix = '  <-- Your Choice (Correct)';
          }

          doc.text(`${bullet}${optText}${suffix}`, 50, doc.y, {
            width: contentWidth - 28,
          });
          doc.y += 2;
        });

        // Explanation Box (if explanation exists)
        if (q.explanation && q.explanation.trim()) {
          doc.y += 4;
          const explText = `Explanation: ${q.explanation.trim()}`;
          const textHeight = doc.heightOfString(explText, { width: contentWidth - 24 });
          const explBoxHeight = textHeight + 10;

          // Check if box fits on page
          if (doc.y + explBoxHeight > pageHeight - 50) {
            drawFooter(doc, pageWidth, pageHeight, regularFont);
            doc.addPage();
            doc.y = 40;
          }

          doc.rect(46, doc.y, contentWidth - 20, explBoxHeight)
            .fillAndStroke('#F0FDF4', '#BBF7D0');

          doc.fillColor('#166534').font(regularFont).fontSize(8.5);
          doc.text(explText, 52, doc.y + 5, { width: contentWidth - 32 });
          doc.y += explBoxHeight + 6;
        } else {
          doc.y += 6;
        }

        // Separator Line
        doc.moveTo(36, doc.y).lineTo(pageWidth - 36, doc.y).strokeColor('#E2E8F0').stroke();
        doc.y += 8;
      }

      // Draw footer on final page
      drawFooter(doc, pageWidth, pageHeight, regularFont);

      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}

function drawFooter(doc: PDFKit.PDFDocument, pageWidth: number, pageHeight: number, fontName: string) {
  const footerY = pageHeight - 28;
  doc.moveTo(36, footerY).lineTo(pageWidth - 36, footerY).strokeColor('#CBD5E1').stroke();

  doc.fillColor('#64748B').font(fontName).fontSize(8)
    .text('Examplayer Bot | Telegram: @Examplayer_bot | Automated Testing Platform', 36, footerY + 6, {
      width: pageWidth - 72,
      align: 'center',
    });
}
