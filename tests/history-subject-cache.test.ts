import { test } from "node:test";
import assert from "node:assert/strict";
import { HistorySubjectCache } from "../src/lib/history-subject-cache.ts";
import type { SubjectDetails } from "../src/lib/records.ts";

const details: SubjectDetails = {
  columns: ["Course"],
  completed: [["English"]],
  inProgress: [],
};

test("a subject click shares its active preload and later uses the cached result", async () => {
  const cache = new HistorySubjectCache();
  let calls = 0;
  const fetch = async () => {
    calls++;
    return details;
  };
  const preload = cache.load("english", fetch);
  assert.equal(cache.load("english", fetch), preload);
  assert.deepEqual(await preload, details);
  assert.deepEqual(await cache.load("english", fetch), details);
  assert.equal(calls, 1);
});

test("a failed subject remains retryable", async () => {
  const cache = new HistorySubjectCache();
  await assert.rejects(
    cache.load("english", async () => {
      throw new Error("Temporary failure");
    }),
  );
  assert.equal(cache.has("english"), false);
  assert.deepEqual(await cache.load("english", async () => details), details);
});

test("refresh or sign-out prevents old responses overwriting the new history", async () => {
  const cache = new HistorySubjectCache();
  let finish!: (value: SubjectDetails) => void;
  const old = cache.load(
    "english",
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  await Promise.resolve();
  cache.clear();
  const next = { ...details, completed: [["Updated English"]] };
  await cache.load("english", async () => next);
  finish(details);
  await assert.rejects(old, /history changed/);
  assert.deepEqual(await cache.load("english", async () => details), next);
});
