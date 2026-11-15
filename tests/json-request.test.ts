import { test } from "node:test";
import assert from "node:assert/strict";
import { readJsonRequest } from "../src/lib/server/json-request.ts";
import { PortalError } from "../src/lib/server/portal.ts";

const url = new URL("https://schoolity.example/api/portal");
const request = (body: string, headers: Record<string, string> = {}) =>
  new Request(url, {
    method: "POST",
    body,
    headers: {
      origin: url.origin,
      "content-type": "application/json; charset=utf-8",
      ...headers,
    },
  });
const status = (expected: number) => (error: unknown) =>
  error instanceof PortalError && error.status === expected;

test("shared request reader validates origin, media type, and JSON", async () => {
  assert.deepEqual(
    await readJsonRequest(request('{"action":"read"}'), url, 100),
    { action: "read" },
  );
  await assert.rejects(
    readJsonRequest(
      request("{}", { origin: "https://other.example" }),
      url,
      100,
    ),
    status(403),
  );
  await assert.rejects(
    readJsonRequest(
      request("{}", { "content-type": "application/jsonp" }),
      url,
      100,
    ),
    status(403),
  );
  await assert.rejects(readJsonRequest(request("{"), url, 100), status(400));
});

test("request limits count UTF-8 bytes and do not trust missing or false lengths", async () => {
  for (const headers of [{}, { "content-length": "1" }] as Record<
    string,
    string
  >[])
    await assert.rejects(
      readJsonRequest(request('"ééé"', headers), url, 6),
      status(413),
    );
  await assert.rejects(
    readJsonRequest(request("{}", { "content-length": "101" }), url, 100),
    status(413),
  );
  assert.deepEqual(await readJsonRequest(request("{}"), url, 2), {});
});
