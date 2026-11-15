import {
  displayText,
  number,
  object,
  profile,
  profilePayload,
  rows,
} from "./portal-data.ts";

export interface InfoSection {
  title: string;
  fields: { label: string; value: string }[];
  groups?: { title: string; fields: { label: string; value: string }[] }[];
  table?: { columns: string[]; rows: string[][] };
  note?: string;
}
export interface HistoryCourse {
  id: string;
  title: string;
  code: string;
  school: string;
  year: string;
  term: string;
  grade: string;
  mark: string;
  attempted: number | null;
  completed: number | null;
}
export interface GraduationRequirement {
  id: string;
  subject: string;
  required: number | null;
  completed: number | null;
  inProgress: number | null;
  remaining: number | null;
}
export interface SubjectDetails {
  columns: string[];
  completed: string[][];
  inProgress: string[][];
}
export interface AttendanceDay {
  date: string;
  reason: string;
  note: string;
  periods: {
    period: string;
    status: string;
    reason: string;
    course: string;
    teacher: string;
  }[];
}
export type RecordPage =
  | { kind: "student"; sections: InfoSection[]; notice?: string }
  | {
      kind: "history";
      courses: HistoryCourse[];
      requirements: GraduationRequirement[];
      classOf: string;
    }
  | {
      kind: "attendance";
      days: AttendanceDay[];
      totals: { label: string; value: number }[];
    };

function field(record: unknown, ...names: string[]): unknown {
  const entries = Object.entries(object(record));
  for (const name of names) {
    const entry = entries.find(
      ([key]) => key.replace(/^[@_]+/, "").toLowerCase() === name.toLowerCase(),
    );
    if (entry && entry[1] !== null && entry[1] !== undefined && entry[1] !== "")
      return entry[1];
  }
  return undefined;
}
const text = (record: unknown, ...names: string[]) =>
  displayText(field(record, ...names)).trim();

export function studentText(value: unknown): string {
  return displayText(value)
    .replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, "")
    .replace(/<br\s*\/?\s*>|<\/(?:p|div|li)\s*>/gi, "\n")
    .replace(/<[^>]*>/g, "")
    .split(/\r?\n/)
    .map((line) => line.replace(/[\t \u00a0]+/g, " ").trim())
    .filter(Boolean)
    .join("\n");
}

export function studentInformation(
  payload: unknown,
): RecordPage & { kind: "student" } {
  const wrapper = object(payload);
  const raw = profilePayload(wrapper.studentInfo ?? payload),
    p = object(raw.StudentInfo ?? raw);
  const identity = profile(p);
  const sections: InfoSection[] = [];
  function section(
    title: string,
    definitions: [string, string[]][],
    record = p,
  ) {
    const fields = definitions
      .map(([label, keys]) => ({
        label,
        value: studentText(field(record, ...keys)),
      }))
      .filter((entry) => entry.value);
    if (fields.length) sections.push({ title, fields });
  }
  const id = identity.studentId;
  section("Student", [
    ["Name", ["formattedName", "studentName"]],
    ["Grade", ["grade"]],
    ["Birth date", ["birthDate"]],
    ["Gender", ["gender"]],
    ["Email", ["studentEmail", "email"]],
    ["Phone", ["phone"]],
    ["Home address", ["homeAddress", "address"]],
    ["Language spoken at home", ["homeLanguage", "languageSpokenAtHome"]],
    ["Last name goes by", ["lastNameGoesBy"]],
    ["Nickname", ["nickName"]],
  ]);
  if (id && sections[0]?.title === "Student") {
    sections[0].fields.splice(1, 0, { label: "Student ID", value: id });
  } else if (id) {
    sections.unshift({
      title: "Student",
      fields: [{ label: "Student ID", value: id }],
    });
  }
  section("School", [
    ["School", ["schoolName"]],
    [
      "Homeroom teacher",
      ["homeRoomTeacher", "homeroomTeacherName", "homeRoom"],
    ],
    ["Homeroom", ["homeRoomName", "roomName"]],
    ["Counselor", ["counselorName", "counselor"]],
    ["Graduation year", ["graduationYear"]],
    ["Track", ["track"]],
    ["Meals balance", ["mealsBalance", "mealBalance"]],
  ]);
  for (const [index, contact] of rows(
    field(p, "emergencyContacts", "emergencyContact"),
  ).entries()) {
    section(
      `Emergency contact ${index + 1}`,
      [
        ["Name", ["name", "contactName"]],
        ["Relationship", ["relationship"]],
        ["Email", ["email"]],
        ["Home phone", ["homePhone"]],
        ["Work phone", ["workPhone"]],
        ["Mobile phone", ["mobilePhone", "cellPhone"]],
        ["Other phone", ["otherPhone"]],
      ],
      contact,
    );
  }
  for (const locker of rows(field(p, "studentLockers", "lockers"))) {
    section(
      "Locker",
      [
        ["Number", ["lockerNumber", "number"]],
        ["Location", ["location"]],
        ["Type", ["type", "lockerType"]],
        ["Vertical location", ["verticalLocation"]],
        ["Combination", ["combination"]],
      ],
      locker,
    );
  }
  section("Transportation", [
    ["Bus to school", ["busToSchool"]],
    ["Pick-up stop", ["pickupBusStop", "pickupStop"]],
    ["Pick-up time", ["pickupTime"]],
    ["Pick-up bus company", ["pickupBusCompany"]],
    ["Pick-up effective date", ["pickupEffectiveDate"]],
    ["Bus from school", ["busFromSchool"]],
    ["Drop-off stop", ["dropoffBusStop", "dropoffStop"]],
    ["Drop-off time", ["dropoffTime"]],
    ["Drop-off bus company", ["dropoffBusCompany"]],
    ["Drop-off effective date", ["dropoffEffectiveDate"]],
    ["Activity bus", ["activityBus"]],
    ["Activity bus stop", ["activityBusStop"]],
    ["Activity bus company", ["activityBusCompany"]],
  ]);
  section("Physician and dentist information", [
    ["Physician", ["physicianName"]],
    ["Physician phone", ["physicianPhone"]],
    ["Physician extension", ["physicianExt"]],
    ["Hospital", ["hospital"]],
    ["Dentist", ["dentistName"]],
    ["Dentist phone", ["dentistPhone"]],
    ["Dentist extension", ["dentistExt"]],
    ["Dental office", ["dentalOffice"]],
  ]);
  section("Other information", [["Case manager", ["caseManager"]]]);
  if (
    Array.isArray(wrapper.studentSections) &&
    wrapper.studentSections.length
  ) {
    const web = (wrapper.studentSections as InfoSection[]).map((section) => ({
      ...section,
      fields: section.fields.map((f) => ({ ...f })),
    }));
    const aliases: Record<string, string> = {
      name: "studentname",
      studentid: "permid",
      email: "studentemail",
      school: "schoolname",
      homeroom: "roomname",
      counselor: "counselorname",
      languagespokenathome: "languagespokeninhome",
    };
    const key = (label: string) => label.toLowerCase().replace(/[^a-z]/g, "");
    const identitySection = web.find((s) =>
      /student information/i.test(s.title),
    );
    if (identitySection)
      for (const section of sections.filter((s) =>
        ["Student", "School"].includes(s.title),
      )) {
        for (const f of section.fields) {
          const wanted = aliases[key(f.label)] ?? key(f.label);
          const existing = identitySection.fields.find(
            (entry) => key(entry.label) === wanted,
          );
          if (existing) existing.value = f.value;
          else identitySection.fields.push({ ...f });
        }
      }
    return {
      kind: "student",
      sections: web,
      ...(typeof wrapper.studentInfoNotice === "string"
        ? { notice: wrapper.studentInfoNotice }
        : {}),
    };
  }
  return {
    kind: "student",
    sections,
    ...(typeof wrapper.studentInfoNotice === "string"
      ? { notice: wrapper.studentInfoNotice }
      : {}),
  };
}

export function courseHistory(
  payload: unknown,
): RecordPage & { kind: "history" } {
  const wrapper = object(payload);
  const groups = Array.isArray(payload) ? payload : wrapper.courseHistory;
  if (!Array.isArray(groups))
    throw new Error(
      "The district returned an unsupported course history. Try refreshing.",
    );
  const courses: HistoryCourse[] = [];
  for (const [gradeIndex, group] of rows(groups).entries()) {
    for (const [termIndex, term] of rows(field(group, "Terms")).entries()) {
      for (const [courseIndex, course] of rows(
        field(term, "Courses"),
      ).entries()) {
        courses.push({
          id: `${gradeIndex}-${termIndex}-${courseIndex}`,
          title: text(course, "CourseTitle"),
          code: text(course, "CourseID"),
          school: text(term, "SchoolName"),
          year: text(term, "Year"),
          term: text(term, "TermName"),
          grade: text(group, "Grade"),
          mark: text(course, "Mark"),
          attempted: number(field(course, "CreditsAttempted")),
          completed: number(field(course, "CreditsCompleted")),
        });
      }
    }
  }
  if (groups.length && !courses.length)
    throw new Error(
      "No readable courses were returned. Open Course History in StudentVUE or try refreshing.",
    );
  const requirements = rows(wrapper.graduationRequirements)
    .map((row) => ({
      id: text(row, "id"),
      subject: text(row, "subject"),
      required: number(field(row, "required")),
      completed: number(field(row, "completed")),
      inProgress: number(field(row, "inProgress")),
      remaining: number(field(row, "remaining")),
    }))
    .filter((row) => row.subject);
  return {
    kind: "history",
    courses,
    requirements,
    classOf: text(wrapper, "classOf"),
  };
}

export function attendance(
  payload: unknown,
): RecordPage & { kind: "attendance" } {
  const wrapper = object(payload),
    data = object(wrapper.attendance ?? wrapper.Attendance ?? payload);
  if (
    field(data, "dailyAttendance") !== undefined ||
    field(data, "periodAttendance") !== undefined ||
    Object.keys(data).some((key) =>
      /^(dailyAttendance|periodAttendance)$/i.test(key),
    )
  ) {
    const dates = new Map<
      string,
      { absenceDate: string; reason: string; note: string; periods: unknown[] }
    >();
    function visit(
      value: unknown,
      period: boolean,
      inheritedDate = "",
      depth = 0,
    ) {
      if (depth > 12 || value === null || typeof value !== "object") return;
      if (Array.isArray(value)) {
        for (const item of value) visit(item, period, inheritedDate, depth + 1);
        return;
      }
      const row = object(value);
      const ownDate = text(
        row,
        "absenceDate",
        "attendanceDate",
        "date",
        "dayDate",
      );
      const date = ownDate || inheritedDate;
      const number = text(row, "number", "period", "periodNumber");
      const reason = text(
        row,
        "reason",
        "absenceReason",
        "codeAllDayDescription",
        "absenceDescription",
        "description",
      );
      const status = text(
        row,
        "name",
        "status",
        "attendanceName",
        "attendanceCodeDescription",
        "codeDescription",
      );
      if (date && (ownDate || number)) {
        const day = dates.get(date) ?? {
          absenceDate: date,
          reason: "",
          note: "",
          periods: [],
        };
        if (period && number)
          day.periods.push({
            number,
            name: status,
            reason,
            course: text(row, "course", "courseTitle", "courseName"),
            staff: text(row, "staff", "teacher", "teacherName"),
          });
        else {
          day.reason ||= reason || status;
          day.note ||= text(row, "note", "notes", "comment");
        }
        dates.set(date, day);
      }
      for (const [key, child] of Object.entries(row)) {
        if (child !== null && typeof child === "object")
          visit(child, period || /period/i.test(key), date, depth + 1);
      }
    }
    visit(field(data, "dailyAttendance"), false);
    visit(field(data, "periodAttendance"), true);
    return attendance({ absences: [...dates.values()] });
  }
  const absenceValue = field(data, "absences");
  const absenceList = Array.isArray(absenceValue)
    ? absenceValue
    : field(absenceValue, "Absence");
  if (Object.keys(data).length && absenceValue === undefined)
    throw new Error(
      "The district returned an unsupported attendance format. Try refreshing or open Attendance in StudentVUE.",
    );
  const days = rows(absenceList)
    .map((day) => {
      const periods = field(day, "periods");
      return {
        date: text(day, "absenceDate", "date"),
        reason: text(day, "reason", "codeAllDayDescription"),
        note: text(day, "note"),
        periods: rows(
          Array.isArray(periods) ? periods : field(periods, "Period"),
        ).map((p) => ({
          period: text(p, "number", "period"),
          status: text(p, "name", "status"),
          reason: text(p, "reason"),
          course: text(p, "course"),
          teacher: text(p, "staff"),
        })),
      };
    })
    .sort((a, b) => (Date.parse(b.date) || 0) - (Date.parse(a.date) || 0));
  const totals: { label: string; value: number }[] = [];
  for (const [key, label] of [
    ["totalExcused", "Excused periods"],
    ["totalUnexcused", "Unexcused periods"],
    ["totalTardies", "Tardy periods"],
  ] as const) {
    const value = field(data, key);
    if (value === undefined) continue;
    const list = Array.isArray(value) ? value : field(value, "PeriodTotal");
    const counts = rows(list).map((entry) => number(field(entry, "total")));
    if (counts.length && counts.every((count) => count !== null && count >= 0))
      totals.push({
        label,
        value: counts.reduce<number>((sum, count) => sum + count!, 0),
      });
  }
  return { kind: "attendance", days, totals };
}

export function readRecords(resource: string, payload: unknown): RecordPage {
  if (resource === "student") return studentInformation(payload);
  if (resource === "history") return courseHistory(payload);
  if (resource === "attendance") return attendance(payload);
  throw new Error("Unknown student resource.");
}
