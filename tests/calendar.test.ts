import { test } from 'node:test';
import assert from 'node:assert/strict';
import { events, schedule } from '../src/lib/portal-data.ts';
import {
  calendarFile,
  calendarFilename,
  districtDate,
  meetingDays,
} from '../src/lib/calendar.ts';
import type { ScheduleTerm } from '../src/lib/model.ts';

const allTerms = {
  studentClassScheduleForAllTerms: {
    termIndex: 1,
    termLists: [
      {
        termIndex: 0,
        termName: 'Semester 0',
        beginDate: '08/19/2025',
        endDate: '12/19/2025',
      },
      {
        termIndex: 1,
        termName: 'Semester 1',
        beginDate: '01/05/2026',
        endDate: '05/28/2026',
      },
    ],
    studentClassScheduleForTerms: [
      {
        thisTermIndex: 0,
        beginDate: '08/19/2025',
        endDate: '12/19/2025',
        classLists: [
          {
            period: '2',
            courseTitle: 'Biology &amp; Lab',
            roomName: '204',
            teacher: 'Pat Lee',
            meetingDays: 'M,T,W,Th,F',
            sectionGU: 'biology',
          },
        ],
      },
      {
        thisTermIndex: 1,
        beginDate: '01/05/2026',
        endDate: '05/28/2026',
        classLists: [
          {
            period: '1',
            courseTitle: 'Algebra II',
            roomName: '102',
            teacher: 'Sam Rivera',
            meetingDays: 'M,W,F',
            sectionGU: 'algebra',
          },
        ],
      },
    ],
  },
};

const allTermSchedule = allTerms.studentClassScheduleForAllTerms;

const term: ScheduleTerm = {
  id: 1,
  name: 'Semester 1 / Spring',
  beginDate: '01/05/2026',
  endDate: '05/28/2026',
  classes: [
    {
      id: 'algebra',
      title: 'Algebra II',
      teacher: 'Sam Rivera',
      room: '102',
      period: '2',
      meetingDays: 'M,W,F',
    },
  ],
};

test('schedule maps every term and selects the district current term', () => {
  for (const payload of [allTermSchedule, allTerms]) {
    const result = schedule(payload);
    assert.equal(result.currentTerm, 1);
    assert.deepEqual(
      result.terms.map((entry) => entry.name),
      ['Semester 0', 'Semester 1'],
    );
    assert.equal(result.terms[0].classes[0].title, 'Biology & Lab');
    assert.equal(result.terms[0].classes[0].teacher, 'Pat Lee');
    assert.equal(result.terms[0].classes[0].room, '204');
    assert.equal(result.terms[0].classes[0].meetingDays, 'M,T,W,Th,F');
    assert.equal(result.terms[1].classes[0].title, 'Algebra II');
    assert.equal(result.terms[1].beginDate, '01/05/2026');
  }
});

test('flat schedules remain one term for the native listing', () => {
  const flat = {
    termIndex: 0,
    termIndexName: 'Quarter 1',
    classLists: [
      {
        period: 3,
        courseTitle: 'Chemistry',
        teacher: 'Dana Kim',
        roomName: '310',
      },
    ],
  };
  const result = schedule(flat);
  assert.equal(result.currentTerm, 0);
  assert.equal(result.terms.length, 1);
  assert.equal(result.terms[0].name, 'Quarter 1');
  assert.deepEqual(events(flat, 'schedule'), [
    {
      title: 'Chemistry',
      detail: 'Dana Kim · Room 310',
      date: 'Period 3',
    },
  ]);
  for (const payload of [allTermSchedule, allTerms])
    assert.deepEqual(events(payload, 'schedule'), [
      {
        title: 'Algebra II',
        detail: 'Sam Rivera · Room 102',
        date: 'Period 1',
      },
    ]);
  assert.deepEqual(events({ classLists: [] }, 'schedule'), []);
});

test('meeting days understand common district formats and fall back safely', () => {
  assert.deepEqual(meetingDays(undefined), ['MO', 'TU', 'WE', 'TH', 'FR']);
  assert.deepEqual(meetingDays('M,T,W,Th,F'), [
    'MO',
    'TU',
    'WE',
    'TH',
    'FR',
  ]);
  assert.deepEqual(meetingDays('MTWThF'), ['MO', 'TU', 'WE', 'TH', 'FR']);
  assert.deepEqual(meetingDays('T/Th'), ['TU', 'TH']);
  assert.deepEqual(meetingDays('1,2'), ['MO', 'TU', 'WE', 'TH', 'FR']);
});

test('calendar dates parse district and ISO formats', () => {
  assert.equal(districtDate('01/05/2026')?.toISOString(), '2026-01-05T00:00:00.000Z');
  assert.equal(districtDate('2026-01-05')?.toISOString(), '2026-01-05T00:00:00.000Z');
  assert.equal(districtDate('not a date'), null);
  assert.equal(districtDate(undefined), null);
});

test('calendar files repeat classes weekly for the selected term', () => {
  const file = calendarFile(term);
  assert.match(file, /^BEGIN:VCALENDAR\r\n/);
  assert.match(file, /SUMMARY:Algebra II · Period 2/);
  assert.match(file, /LOCATION:102/);
  assert.match(file, /DTSTART;VALUE=DATE:20260105/);
  assert.match(
    file,
    /RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=20260528/,
  );
  assert.doesNotMatch(file, /DTEND/);
  assert.match(file, /END:VCALENDAR\r\n$/);
  assert.equal(calendarFilename(term), 'schoolity-semester-1-spring.ics');
});

test('calendar files use class times when the district provides them', () => {
  const timed: ScheduleTerm = {
    ...term,
    classes: [
      {
        ...term.classes[0],
        startTime: '8:15 AM',
        endTime: '9:40 AM',
      },
    ],
  };
  const file = calendarFile(timed);
  assert.match(file, /DTSTART:20260105T081500/);
  assert.match(file, /DTEND:20260105T094000/);
  assert.match(file, /UNTIL=20260528T235959/);
});

test('calendar text is escaped and empty terms still produce a file', () => {
  const escaped = calendarFile({
    ...term,
    classes: [
      {
        ...term.classes[0],
        title: 'Algebra, II; Honors',
      },
    ],
  });
  assert.match(escaped, /SUMMARY:Algebra\\, II\\; Honors · Period 2/);
  const empty = calendarFile({ ...term, classes: [] });
  assert.doesNotMatch(empty, /BEGIN:VEVENT/);
  assert.match(empty, /END:VCALENDAR/);
});
