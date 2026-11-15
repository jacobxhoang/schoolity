import { test } from "node:test";
import assert from "node:assert/strict";
import {
  displayText,
  grades,
  events,
  profile,
} from "../src/lib/portal-data.ts";
import { calculate } from "../src/lib/model.ts";
test("display text decodes named and numeric entities while preserving ordinary ampersands", () => {
  assert.equal(displayText("Chapter 4&amp;5"), "Chapter 4&5");
  assert.equal(
    displayText("&quot;It&#39;s&quot; &ndash; &#x1F600; &copy;"),
    '"It\'s" – 😀 ©',
  );
  assert.equal(displayText("AT&T &notAnEntity;"), "AT&T &notAnEntity;");
  assert.equal(displayText("One&nbsp;Two"), "One Two");
});
test("grade labels decode consistently without changing identifiers or category weighting", () => {
  const data = grades({
    reportingPeriod: { index: 0 },
    courses: [
      {
        courseID: "raw&amp;id",
        courseName: "Art &amp; Design",
        staff: "O&#39;Brien",
        marks: [
          {
            gradeCalculationSummary: [
              { type: "Tests &amp; Quizzes", weight: 100 },
            ],
            assignments: [
              {
                gradebookID: "task&amp;id",
                measure: "Chapter 4&amp;5",
                type: "Tests &amp; Quizzes",
                point: 37,
                pointPossible: 40,
              },
            ],
          },
        ],
      },
    ],
  });
  const course = data.courses[0];
  assert.equal(course.name, "Art & Design");
  assert.equal(course.teacher, "O'Brien");
  assert.equal(course.assignments[0].title, "Chapter 4&5");
  assert.equal(course.id, "raw&amp;id");
  assert.equal(course.assignments[0].id, "task&amp;id");
  assert.equal(calculate(course), 92.5);
});
test("mail, document and profile labels decode as plain text", () => {
  const [mail] = events(
    {
      inboxItemListings: [
        {
          smMessageGU: "raw&amp;id",
          subject: "Class &amp; club",
          from: [{ details1: "Mr. O&#39;Brien" }],
          messageText: "<p>Line &amp; one<br>Line &lt;two&gt;</p>",
          attachments: [
            { smAttachmentGU: "raw&amp;file", documentName: "A&amp;B.pdf" },
          ],
        },
      ],
    },
    "mail",
  );
  assert.equal(mail.title, "Class & club");
  assert.equal(mail.author, "Mr. O'Brien");
  assert.match(mail.detail, /Line & one\nLine <two>/);
  assert.equal(mail.attachments![0].filename, "A&B.pdf");
  assert.equal(mail.attachments![0].id, "raw&amp;file");
  assert.equal(
    events(
      {
        studentDocumentDatas: [
          { documentGU: "id", documentComment: "Tests &amp; results" },
        ],
      },
      "documents",
    )[0].title,
    "Tests & results",
  );
  assert.equal(profile({ formattedName: "A &amp; B" }).name, "A & B");
});
