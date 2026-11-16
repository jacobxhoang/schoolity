import { test } from "node:test";
import assert from "node:assert/strict";
import { calculate, type Course } from "../src/lib/model.ts";
import { grades } from "../src/lib/portal-data.ts";
const course: Course = {
  id: "test",
  name: "Test",
  teacher: "",
  room: "",
  period: "",
  official: null,
  categories: [
    { name: "Practice", weight: 30 },
    { name: "Exam", weight: 70 },
  ],
  assignments: [
    {
      id: "a",
      title: "a",
      category: "Practice",
      earned: 20,
      possible: 20,
      due: "",
    },
    {
      id: "b",
      title: "b",
      category: "Exam",
      earned: 40,
      possible: 50,
      due: "",
    },
  ],
};
test("weighted category results are calculated independently of assignment sizes", () =>
  assert.equal(calculate(course), 86));
test("ungraded assignments do not lower a grade", () =>
  assert.equal(
    calculate({
      ...course,
      assignments: [
        ...course.assignments,
        {
          id: "new",
          title: "",
          category: "Exam",
          earned: null,
          possible: 100,
          due: "",
        },
      ],
    }),
    86,
  ));
test("empty categories redistribute active weights", () =>
  assert.equal(
    calculate({ ...course, assignments: [course.assignments[0]] }),
    100,
  ));
test("excluded assignments do not contribute", () =>
  assert.equal(
    calculate({
      ...course,
      assignments: [
        course.assignments[0],
        { ...course.assignments[1], excluded: true },
      ],
    }),
    100,
  ));
test("zero earned is a grade rather than missing data", () =>
  assert.equal(
    calculate({
      ...course,
      assignments: [{ ...course.assignments[0], earned: 0 }],
    }),
    0,
  ));
test("points grading includes zero-denominator extra credit", () =>
  assert.ok(
    Math.abs(
      calculate({
        categories: [],
        assignments: [
          course.assignments[0],
          { ...course.assignments[0], earned: 2, possible: 0 },
        ],
      })! - 110,
    ) < 1e-9,
  ));
test("no graded points produces no grade", () =>
  assert.equal(calculate({ categories: [], assignments: [] }), null));
test("mobile JSON mapping preserves term zero and missing scores", () => {
  const result = grades({
    reportingPeriod: { index: 0 },
    reportingPeriods: [{ index: 0, gradePeriod: "Fall" }],
    courses: [
      {
        courseID: 12,
        marks: [
          {
            calculatedScoreRaw: 0,
            assignments: [
              { gradebookID: 1, point: 0, pointPossible: 10 },
              { gradebookID: 2, pointPossible: 10 },
              { gradebookID: 3, pointPossible: 0, scoreMaxValue: 50 },
              { gradebookID: 4, point: 5, pointPossible: 0, scoreMaxValue: 50 },
            ],
            gradeCalculationSummary: [],
          },
        ],
      },
    ],
  });
  assert.equal(result.currentTerm, 0);
  assert.equal(result.courses[0].official, 0);
  assert.equal(result.courses[0].assignments[0].earned, 0);
  assert.equal(result.courses[0].assignments[1].earned, null);
  assert.equal(result.courses[0].assignments[2].possible, 50);
  assert.equal(result.courses[0].assignments[3].possible, 0);
});
test("missing reporting period cannot masquerade as a valid gradebook", () =>
  assert.throws(() => grades({}), /reporting period/));
