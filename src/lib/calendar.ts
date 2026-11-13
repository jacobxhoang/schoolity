import type { ScheduleClass, ScheduleTerm } from './model';

const dayOrder = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'] as const;
export type Weekday = (typeof dayOrder)[number];

const dayNames: Record<string, Weekday> = {
  monday: 'MO',
  mon: 'MO',
  mo: 'MO',
  m: 'MO',
  tuesday: 'TU',
  tues: 'TU',
  tue: 'TU',
  tu: 'TU',
  t: 'TU',
  wednesday: 'WE',
  wed: 'WE',
  we: 'WE',
  w: 'WE',
  thursday: 'TH',
  thurs: 'TH',
  thur: 'TH',
  thu: 'TH',
  th: 'TH',
  r: 'TH',
  friday: 'FR',
  fri: 'FR',
  fr: 'FR',
  f: 'FR',
  saturday: 'SA',
  sat: 'SA',
  sa: 'SA',
  sunday: 'SU',
  sun: 'SU',
  su: 'SU',
};

export function meetingDays(value: string | undefined): Weekday[] {
  if (!value) return ['MO', 'TU', 'WE', 'TH', 'FR'];
  const text = value.toLowerCase().replace(/[.]/g, ' ');
  const found = new Set<Weekday>();
  for (const token of text.split(/[^a-z]+/).filter(Boolean)) {
    const day = dayNames[token];
    if (day) found.add(day);
  }
  if (!found.size) {
    const compact = text.replace(/[^a-z]/g, '');
    for (let index = 0; index < compact.length; ) {
      const pair = compact.slice(index, index + 2);
      if (pair in dayNames && pair.length === 2) {
        found.add(dayNames[pair]);
        index += 2;
        continue;
      }
      const single = compact[index];
      if (single && single in dayNames) found.add(dayNames[single]);
      index++;
    }
  }
  const days = dayOrder.filter((day) => found.has(day));
  return days.length ? days : ['MO', 'TU', 'WE', 'TH', 'FR'];
}

export function districtDate(value: string | undefined): Date | null {
  if (!value) return null;
  const text = value.trim();
  const match = text.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (match) {
    const date = new Date(
      Date.UTC(Number(match[3]), Number(match[1]) - 1, Number(match[2])),
    );
    return Number.isNaN(date.getTime()) ? null : date;
  }
  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime())) return null;
  return new Date(
    Date.UTC(
      parsed.getUTCFullYear(),
      parsed.getUTCMonth(),
      parsed.getUTCDate(),
    ),
  );
}

function clock(value: string | undefined): { hour: number; minute: number } | null {
  if (!value) return null;
  const match = value
    .trim()
    .match(/^(\d{1,2}):(\d{2})(?::\d{2})?\s*(am|pm)?$/i);
  if (!match) return null;
  let hour = Number(match[1]);
  const minute = Number(match[2]);
  const meridiem = match[3]?.toLowerCase();
  if (
    !Number.isInteger(hour) ||
    hour < 0 ||
    hour > 23 ||
    !Number.isInteger(minute) ||
    minute < 0 ||
    minute > 59
  )
    return null;
  if (meridiem === 'pm' && hour < 12) hour += 12;
  if (meridiem === 'am' && hour === 12) hour = 0;
  // Schedules that omit a meridiem conventionally use school-day hours.
  if (!meridiem && hour >= 1 && hour <= 6) hour += 12;
  return { hour, minute };
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 86_400_000);
}

function dateKey(date: Date): string {
  return `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, '0')}${String(date.getUTCDate()).padStart(2, '0')}`;
}

function timeKey(hour: number, minute: number): string {
  return `${String(hour).padStart(2, '0')}${String(minute).padStart(2, '0')}00`;
}

function stamp(): string {
  const now = new Date();
  return `${dateKey(now)}T${now.toISOString().slice(11, 19).replace(/:/g, '')}Z`;
}

function firstOnOrAfter(begin: Date, days: Weekday[]): Date {
  for (let offset = 0; offset < 7; offset++) {
    const date = addDays(begin, offset);
    if (days.includes(dayOrder[(date.getUTCDay() + 6) % 7])) return date;
  }
  return begin;
}

function escape(value: string): string {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/\r?\n/g, '\\n')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,');
}

function hash(value: string): string {
  let result = 2_166_136_261;
  for (let index = 0; index < value.length; index++) {
    result ^= value.charCodeAt(index);
    result = Math.imul(result, 16_777_619);
  }
  return (result >>> 0).toString(36);
}

function fold(line: string): string {
  const characters = Array.from(line);
  if (characters.length <= 73) return line;
  const chunks: string[] = [];
  let limit = 73;
  while (characters.length > limit) {
    chunks.push(characters.splice(0, limit).join(''));
    limit = 72;
  }
  chunks.push(characters.join(''));
  return chunks.join('\r\n ');
}

function eventUid(term: ScheduleTerm, course: ScheduleClass, index: number): string {
  return `schoolity-${term.id}-${index}-${hash(`${course.id}|${course.title}|${course.period}`)}@schoolity`;
}

export function calendarFilename(term: ScheduleTerm): string {
  const safe = term.name
    .normalize('NFKD')
    .replace(/[^a-zA-Z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .toLowerCase()
    .slice(0, 50);
  return `schoolity-${safe || 'schedule'}.ics`;
}

export function calendarFile(term: ScheduleTerm): string {
  const begin = districtDate(term.beginDate) ?? districtDate(new Date().toISOString())!;
  const end = districtDate(term.endDate) ?? addDays(begin, 180);
  const last = end < begin ? begin : end;
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Schoolity//Schedule//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    `X-WR-CALNAME:${escape(`${term.name} schedule`)}`,
    'X-WR-TIMEZONE:America/Chicago',
  ];
  term.classes.forEach((course, index) => {
    const days = meetingDays(course.meetingDays);
    const first = firstOnOrAfter(begin, days);
    if (first > last) return;
    const from = clock(course.startTime);
    const to = clock(course.endTime);
    const summary = [course.title || 'Class', course.period ? `Period ${course.period}` : '']
      .filter(Boolean)
      .join(' · ');
    const detail = [
      term.name,
      course.teacher,
      course.room ? `Room ${course.room}` : '',
      course.period ? `Period ${course.period}` : '',
    ]
      .filter(Boolean)
      .join('\n');
    lines.push(
      'BEGIN:VEVENT',
      `UID:${eventUid(term, course, index)}`,
      `DTSTAMP:${stamp()}`,
      `SUMMARY:${escape(summary)}`,
      `DESCRIPTION:${escape(detail)}`,
      ...(course.room ? [`LOCATION:${escape(course.room)}`] : []),
    );
    if (from) {
      const startMinutes = from.hour * 60 + from.minute;
      let endMinutes = to ? to.hour * 60 + to.minute : startMinutes + 60;
      if (endMinutes <= startMinutes) endMinutes = startMinutes + 60;
      const endDate = addDays(first, Math.floor(endMinutes / 1440));
      lines.push(
        `DTSTART:${dateKey(first)}T${timeKey(from.hour, from.minute)}`,
        `DTEND:${dateKey(endDate)}T${timeKey(Math.floor((endMinutes % 1440) / 60), endMinutes % 60)}`,
        `RRULE:FREQ=WEEKLY;BYDAY=${days.join(',')};UNTIL=${dateKey(last)}T235959`,
      );
    } else {
      lines.push(
        `DTSTART;VALUE=DATE:${dateKey(first)}`,
        `RRULE:FREQ=WEEKLY;BYDAY=${days.join(',')};UNTIL=${dateKey(last)}`,
      );
    }
    lines.push('TRANSP:TRANSPARENT', 'END:VEVENT');
  });
  lines.push('END:VCALENDAR', '');
  return lines.map(fold).join('\r\n');
}
