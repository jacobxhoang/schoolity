import { test } from 'node:test';
import assert from 'node:assert/strict';
import { events, schedule } from '../src/lib/portal-data.ts';

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
