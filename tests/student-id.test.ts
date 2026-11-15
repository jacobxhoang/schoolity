import { test } from "node:test";
import assert from "node:assert/strict";
import { profile, profilePayload } from "../src/lib/portal-data.ts";

test("student ID preserves leading zeros and is never inferred from account identifiers", () => {
  assert.equal(profile({ permID: "00012345" }).studentId, "00012345");
  assert.equal(
    profile({ permID: "", studentID: "0012345" }).studentId,
    "0012345",
  );
  assert.equal(profile({ studentNumber: 12345 }).studentId, "12345");
  assert.equal(
    profile({ studentGU: "opaque-guid", childIntID: 0, userName: "login" })
      .studentId,
    undefined,
  );
  assert.equal(profile({ permID: {} }).studentId, undefined);
  assert.equal(
    profile({ studentID: Number.MAX_SAFE_INTEGER + 1 }).studentId,
    undefined,
  );
});

test("profile merges summary and detail data without losing the ID to an empty detail field", () => {
  const envelope = {
    studentInfoXML: { permID: "00012345", formattedName: "Sample Student" },
    studentInfoDetailXML: {
      permID: "",
      schoolName: "Sample School",
      grade: "11",
    },
  };
  assert.equal(profilePayload(envelope).permID, "00012345");
  assert.deepEqual(profile(envelope), {
    name: "Sample Student",
    school: "Sample School",
    grade: "11",
    studentId: "00012345",
  });
  assert.equal(
    profile({ formattedName: "Sample Student" }).studentId,
    undefined,
  );
});
