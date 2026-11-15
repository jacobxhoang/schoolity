import { test } from "node:test";
import assert from "node:assert/strict";
import { requestPortal, RequestFailure } from "../src/lib/portal-request.ts";

test("a temporary gateway failure recovers on the next read", async () => {
  let calls = 0;
  const transport = (async () =>
    ++calls === 1
      ? new Response("Gateway unavailable", { status: 502 })
      : Response.json({ data: { courses: [] } })) as typeof fetch;
  assert.deepEqual(
    await requestPortal({ action: "read", resource: "history" }, transport),
    { data: { courses: [] } },
  );
  assert.equal(calls, 2);
});

test("persistent failures stop after three reads and preserve the specific error", async () => {
  let calls = 0;
  const transport = (async () => {
    calls++;
    return Response.json(
      { error: "Course history needs to reconnect." },
      { status: 502 },
    );
  }) as typeof fetch;
  await assert.rejects(
    requestPortal({ action: "read" }, transport),
    /Course history needs to reconnect/,
  );
  assert.equal(calls, 3);
});

test("authentication failures and mutations are never retried", async () => {
  for (const [action, status] of [
    ["login", 503],
    ["logout", 502],
    ["session", 503],
    ["read", 401],
    ["read", 429],
  ] as const) {
    let calls = 0;
    const transport = (async () => {
      calls++;
      return Response.json({}, { status });
    }) as typeof fetch;
    await assert.rejects(requestPortal({ action }, transport), RequestFailure);
    assert.equal(calls, 1);
  }
});
