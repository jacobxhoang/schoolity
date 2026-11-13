import type { Course, GradeData, Profile, EventItem } from './model';
import { decodeHTMLStrict } from 'entities';
export type JsonObject = Record<string, unknown>;
export function object(value: unknown): JsonObject {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as JsonObject)
    : {};
}
export function rows(value: unknown): JsonObject[] {
  return (Array.isArray(value) ? value : value == null ? [] : [value]).map(
    object,
  );
}
export function string(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number'
    ? String(value)
    : '';
}
// Decode display text only. IDs, tokens, URLs and numeric data stay untouched.
export function displayText(value: unknown): string {
  return decodeHTMLStrict(string(value)).replace(/\u00a0/g, ' ');
}
export function number(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}
const palette = [
  '#b2c8f4',
  '#e9b8a3',
  '#bdd6b4',
  '#d3c0e9',
  '#efd68e',
  '#9dcfc8',
];
export function grades(payload: unknown): GradeData {
  const raw = object(payload),
    g = object(raw.traditionalGradebook ?? payload);
  if (g.errorMessage) throw new Error(string(g.errorMessage));
  const term = object(g.reportingPeriod);
  if (number(term.index) === null)
    throw new Error(
      'The district did not return a usable gradebook reporting period.',
    );
  const courses: Course[] = rows(g.courses).map((c, i) => {
    const marks = rows(c.marks),
      mark = marks[0] ?? {};
    return {
      id: string(c.courseID ?? c.courseId) || `course-${i}`,
      name: displayText(c.courseName) || displayText(c.title),
      teacher: displayText(c.staff),
      room: displayText(c.room),
      period: displayText(c.period),
      color: palette[i % palette.length],
      official: number(mark.calculatedScoreRaw),
      categories: rows(mark.gradeCalculationSummary)
        .filter((x) => string(x.type).toUpperCase() !== 'TOTAL')
        .map((x) => ({
          name: displayText(x.type),
          weight: Number.parseFloat(string(x.weight)) || 0,
        })),
      assignments: rows(mark.assignments).map((a, j) => ({
        id: string(a.gradebookID ?? a.gradebookId) || `task-${j}`,
        title: displayText(a.measure),
        category: displayText(a.type),
        earned: number(a.point ?? a.scoreCalValue ?? a.score),
        possible: number(a.pointPossible ?? a.scoreMaxValue) ?? 0,
        due: string(a.dueDate),
        excluded: string(a.notes).startsWith('(Not For Grading)'),
      })),
    };
  });
  return {
    courses,
    currentTerm: number(term.index)!,
    terms: rows(g.reportingPeriods).map((t) => ({
      id: number(t.index) ?? 0,
      name: displayText(t.gradePeriod),
    })),
  };
}
export function profile(payload: unknown): Profile {
  const p = object(payload);
  return {
    name: displayText(p.formattedName) || 'Student',
    school: displayText(p.schoolName) || 'Your school',
    grade: string(p.grade),
  };
}
export function events(payload: unknown, kind: string): EventItem[] {
  const data = object(payload);
  if (kind === 'mail')
    return rows(data.inboxItemListings).map((m) => ({
      id: string(m.smMessageGU ?? m.smMsgPersonGU),
      attachments: rows(m.attachments)
        .filter(
          (a) =>
            string(a.smAttachmentGU) ||
            string(a.documentName) ||
            string(a.fileName),
        )
        .map((a) => ({
          id: string(a.smAttachmentGU),
          filename:
            displayText(a.documentName) ||
            displayText(a.fileName) ||
            'Attachment',
        })),
      title: displayText(m.subject),
      author: rows(m.from)
        .map((sender) => displayText(sender.details1).trim())
        .filter(Boolean)
        .join(', '),
      detail: displayText(
        string(m.messageText)
          .replace(/<br\s*\/?\s*>/gi, '\n')
          .replace(/<\/(?:p|div|li)>/gi, '\n')
          .replace(/<[^>]*>/g, ' '),
      ),
      date: string(m.sendDateTimeFormattedShort ?? m.sendDateTime),
    }));
  if (kind === 'schedule')
    return rows(data.classLists ?? data.classListing ?? data.classes).map(
      (c) => ({
        title: displayText(c.courseTitle ?? c.courseName),
        detail: `${displayText(c.teacher ?? c.staff)} · Room ${displayText(c.roomName ?? c.room)}`,
        date: `Period ${string(c.period)}`,
      }),
    );
  if (kind === 'documents')
    return rows(data.studentDocumentDatas).map((d) => ({
      id: string(d.documentGU),
      filename: displayText(d.documentFileName),
      title: displayText(d.documentComment) || displayText(d.documentFileName),
      detail: displayText(d.documentType),
      date: string(d.documentDate),
    }));
  return [];
}
