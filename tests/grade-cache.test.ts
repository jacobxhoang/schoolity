import { test } from "node:test";
import assert from "node:assert/strict";
import { percentage } from "../src/lib/model.ts";
import {
  readGradeCache,
  saveGradeCache,
  clearGradeCache,
  GRADE_CACHE_KEY,
} from "../src/lib/grade-cache.ts";
import { gradeCacheIdentity } from "../src/lib/server/grade-cache-identity.ts";

function storage() {
  const values = new Map<string, string>();
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => {
      values.set(key, value);
    },
    removeItem: (key: string) => {
      values.delete(key);
    },
  };
}
const book = {
  courses: [],
  terms: [{ id: 0, name: "Quarter 1" }],
  currentTerm: 0,
};
test("grade percentages always use two decimal places", () => {
  assert.equal(percentage(92.5), "92.50%");
  assert.equal(percentage(92.456), "92.46%");
  assert.equal(percentage(0), "0.00%");
  assert.equal(percentage(null), "—");
});
test("last grades and their refresh time survive another visit to the same authenticated session", () => {
  const local = storage();
  saveGradeCache(local, "same-session", book, 1000);
  assert.deepEqual(readGradeCache(local, "same-session", 2000), {
    book,
    savedAt: 1000,
  });
  clearGradeCache(local);
  assert.equal(local.getItem(GRADE_CACHE_KEY), null);
});
test("signed-out and different sessions cannot reuse a cached gradebook", () => {
  const local = storage();
  for (const identity of [null, "different-session"]) {
    saveGradeCache(local, "original", book, 1000);
    assert.equal(readGradeCache(local, identity, 2000), null);
    assert.equal(local.getItem(GRADE_CACHE_KEY), null);
  }
  assert.notEqual(gradeCacheIdentity("one"), gradeCacheIdentity("two"));
  assert.notEqual(gradeCacheIdentity("one"), "one");
});
test("corrupt, expired and structurally invalid caches are discarded", () => {
  const local = storage();
  for (const raw of [
    "broken",
    JSON.stringify({
      identity: "same",
      savedAt: 1000,
      book: { ...book, courses: [{}] },
    }),
  ]) {
    local.setItem(GRADE_CACHE_KEY, raw);
    assert.equal(readGradeCache(local, "same", 2000), null);
  }
  saveGradeCache(local, "same", book, 1000);
  assert.equal(readGradeCache(local, "same", 8 * 86400000), null);
});
test("unavailable browser storage does not break fresh grade loading", () => {
  const blocked = {
    getItem() {
      throw new Error();
    },
    setItem() {
      throw new Error();
    },
    removeItem() {
      throw new Error();
    },
  };
  assert.doesNotThrow(() => saveGradeCache(blocked, "same", book, 1000));
  assert.equal(readGradeCache(blocked, "same"), null);
});
