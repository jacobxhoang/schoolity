import type {
  Course,
  GradeData,
  Profile,
  EventItem,
  ScheduleClass,
  ScheduleData,
} from "./model";
import { decodeHTMLStrict } from "entities";
export type JsonObject = Record<string, unknown>;
export function object(value: unknown): JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonObject)
    : {};
}
export function rows(value: unknown): JsonObject[] {
  return (Array.isArray(value) ? value : value == null ? [] : [value]).map(
    object,
  );
}
export function string(value: unknown): string {
  return typeof value === "string" || typeof value === "number"
    ? String(value)
    : "";
}
// Decode display text only. IDs, tokens, URLs and numeric data stay untouched.
export function displayText(value: unknown): string {
  return decodeHTMLStrict(string(value)).replace(/\u00a0/g, " ");
}
function positive(value: number | null): number | null {
  return value !== null && value > 0 ? value : null;
}
function leadingNumber(value: unknown): number | null {
  const match = /-?\d+(?:\.\d+)?/.exec(string(value));
  return match ? number(match[0]) : null;
}
export function number(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}
export function grades(payload: unknown): GradeData {
  const raw = object(payload),
    g = object(raw.traditionalGradebook ?? payload);
  if (g.errorMessage) throw new Error(string(g.errorMessage));
  const term = object(g.reportingPeriod);
  if (number(term.index) === null)
    throw new Error(
      "The district did not return a usable gradebook reporting period.",
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
      official: number(mark.calculatedScoreRaw),
      categories: rows(mark.gradeCalculationSummary)
        .filter((x) => string(x.type).toUpperCase() !== "TOTAL")
        .map((x) => ({
          name: displayText(x.type),
          weight: Number.parseFloat(string(x.weight)) || 0,
        })),
      assignments: rows(mark.assignments).map((a, j) => {
        const earned = number(a.point ?? a.scoreCalValue ?? a.score);
        const pointPossible = number(a.pointPossible);
        const scoreMaxValue = number(a.scoreMaxValue);
        // Ungraded rows can leave pointPossible and scoreMaxValue empty while
        // the district's display string still says "50 Points Possible". Use
        // any known maximum for ungraded work only, so extra-credit rows keep
        // their zero denominator for grade math.
        const pointsLabel = leadingNumber(a.points);
        let possible = pointPossible ?? scoreMaxValue ?? 0;
        if (earned === null) {
          possible =
            positive(pointPossible) ??
            positive(scoreMaxValue) ??
            positive(pointsLabel) ??
            0;
        }
        return {
          id: string(a.gradebookID ?? a.gradebookId) || `task-${j}`,
          title: displayText(a.measure),
          category: displayText(a.type),
          earned,
          possible,
          due: string(a.dueDate),
          excluded: string(a.notes).startsWith("(Not For Grading)"),
        };
      }),
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
export function profilePayload(payload: unknown): JsonObject {
  const raw = object(payload);
  if (!raw.studentInfoXML && !raw.studentInfoDetailXML) return raw;
  return Object.fromEntries([
    ...Object.entries(object(raw.studentInfoXML)),
    ...Object.entries(object(raw.studentInfoDetailXML)).filter(
      ([, value]) => value !== null && value !== undefined && value !== "",
    ),
  ]);
}
export function profile(payload: unknown): Profile {
  const p = profilePayload(payload);
  // A district student number is distinct from an account/GUID or child index.
  // Keep it as text, preserving leading zeros and never guessing from a login.
  const studentId = [
    p.permID,
    p.permId,
    p.PermID,
    p.studentID,
    p.studentId,
    p.StudentID,
    p.studentNumber,
  ]
    .map((value) =>
      typeof value === "string"
        ? value.trim()
        : Number.isSafeInteger(value) && Number(value) >= 0
          ? String(value)
          : "",
    )
    .find((value) => value.length > 0);
  return {
    name: displayText(p.formattedName) || "Student",
    school:
      displayText(
        p.schoolName ?? p.school ?? p.SchoolName ?? p.currentSchool,
      ) || "Your school",
    grade: string(p.grade),
    ...(studentId ? { studentId } : {}),
  };
}
function scheduleClass(c: JsonObject, index: number): ScheduleClass {
  const meeting = c.meetingDays;
  const meetingDays = Array.isArray(meeting)
    ? meeting.map(string).filter(Boolean).join(", ")
    : string(meeting);
  return {
    id: string(c.sectionGU ?? c.sectionId) || `class-${index}`,
    title: displayText(c.courseTitle ?? c.courseName ?? c.title),
    teacher: displayText(c.teacher ?? c.staff),
    room: displayText(c.roomName ?? c.room),
    period: string(c.period),
    ...(meetingDays ? { meetingDays: displayText(meetingDays) } : {}),
  };
}
export function schedule(payload: unknown): ScheduleData {
  const top = object(payload);
  const wrappedAll = object(top.studentClassScheduleForAllTerms);
  const wrappedSingle = object(top.studentClassSchedule);
  const all =
    Object.keys(wrappedAll).length > 0
      ? wrappedAll
      : "termLists" in top || "studentClassScheduleForTerms" in top
        ? top
        : {};
  const single = Object.keys(wrappedSingle).length ? wrappedSingle : {};
  const base = Object.keys(all).length ? all : single;
  const groups = rows(base.studentClassScheduleForTerms);
  const flatSource = rows(top.classLists).length
    ? top
    : rows(base.classLists).length
      ? base
      : single;
  const flat = rows(flatSource.classLists);
  const termRows = [...rows(base.termLists), ...rows(top.termLists)];
  const classGroups = new Map<number, JsonObject[]>();
  for (const group of groups) {
    const index = number(group.thisTermIndex ?? group.termIndex);
    if (index !== null) classGroups.set(index, rows(group.classLists));
  }
  if (!classGroups.size && flat.length) {
    const index =
      number(
        flatSource.termIndex ??
          base.termIndex ??
          top.termIndex ??
          single.termIndex,
      ) ?? 0;
    classGroups.set(index, flat);
    if (!termRows.length)
      termRows.push({
        termIndex: index,
        termName:
          flatSource.termIndexName ??
          base.termIndexName ??
          top.termIndexName ??
          single.termIndexName,
      });
  }
  const metadata = new Map<number, JsonObject>();
  for (const row of termRows) {
    const id = number(row.termIndex ?? row.index);
    if (id !== null) metadata.set(id, row);
  }
  for (const id of classGroups.keys())
    if (!metadata.has(id)) metadata.set(id, { termIndex: id });
  const groupDates = new Map<number, JsonObject>();
  for (const group of groups) {
    const id = number(group.thisTermIndex ?? group.termIndex);
    if (id !== null) groupDates.set(id, group);
  }
  const periodValue = (period: string) => {
    const value = Number.parseFloat(period);
    return Number.isFinite(value) ? value : Number.MAX_SAFE_INTEGER;
  };
  const terms = [...metadata.entries()].map(([id, row]) => {
    const group = groupDates.get(id);
    const beginDate = string(
      group?.beginDate ?? row.beginDate ?? row.startDate,
    );
    const endDate = string(group?.endDate ?? row.endDate);
    return {
      id,
      name:
        displayText(row.termName ?? row.termIndexName ?? row.gradePeriod) ||
        `Term ${id + 1}`,
      ...(beginDate ? { beginDate } : {}),
      ...(endDate ? { endDate } : {}),
      classes: rows(classGroups.get(id))
        .map(scheduleClass)
        .sort(
          (a, b) =>
            periodValue(a.period) - periodValue(b.period) ||
            a.title.localeCompare(b.title),
        ),
    };
  });
  const hint = number(
    all.termIndex ?? base.termIndex ?? top.termIndex ?? single.termIndex,
  );
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const current =
    hint !== null && metadata.has(hint)
      ? hint
      : (terms.find((term) => {
          const begin = new Date(term.beginDate ?? "");
          const end = new Date(term.endDate ?? "");
          return (
            !Number.isNaN(begin.getTime()) &&
            !Number.isNaN(end.getTime()) &&
            today >= begin &&
            today <= end
          );
        })?.id ??
        terms.find((term) => term.classes.length)?.id ??
        terms[0]?.id ??
        0);
  return { terms, currentTerm: current };
}
export function events(payload: unknown, kind: string): EventItem[] {
  const data = object(payload);
  if (kind === "mail")
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
            "Attachment",
        })),
      title: displayText(m.subject),
      author: rows(m.from)
        .map((sender) => displayText(sender.details1).trim())
        .filter(Boolean)
        .join(", "),
      detail: displayText(
        string(m.messageText)
          .replace(/<br\s*\/?\s*>/gi, "\n")
          .replace(/<\/(?:p|div|li)>/gi, "\n")
          .replace(/<[^>]*>/g, " "),
      ),
      date: string(m.sendDateTimeFormattedShort ?? m.sendDateTime),
    }));
  if (kind === "schedule") {
    const parsed = schedule(payload);
    const term =
      parsed.terms.find((entry) => entry.id === parsed.currentTerm) ??
      parsed.terms[0];
    return (term?.classes ?? []).map((c) => ({
      title: c.title,
      detail: [c.teacher, c.room ? `Room ${c.room}` : ""]
        .filter(Boolean)
        .join(" · "),
      date: c.period ? `Period ${c.period}` : "",
    }));
  }
  if (kind === "documents")
    return rows(data.studentDocumentDatas).map((d) => ({
      id: string(d.documentGU),
      filename: displayText(d.documentFileName),
      title: displayText(d.documentComment) || displayText(d.documentFileName),
      detail: displayText(d.documentType),
      date: string(d.documentDate),
    }));
  return [];
}

// Opt-in, stable display models for the native client. The web client's raw
// response contract stays unchanged; authentication still precedes this mapping.
export function nativeData(payload: unknown, resource: string): unknown {
  if (resource === "grades") return grades(payload);
  if (resource === "profile") return profile(payload);
  return events(payload, resource);
}
