import { test } from "node:test";
import assert from "node:assert/strict";
import { randomBytes, generateKeyPairSync, verify } from "node:crypto";
import { Store } from "../src/lib/server/store.ts";
import { PushService, newlyGraded } from "../src/lib/server/push.ts";
import { APNs } from "../src/lib/server/apns.ts";
import { PortalError } from "../src/lib/server/portal.ts";
import type { GradeData } from "../src/lib/model.ts";

const book = (score: number | null): GradeData => ({
  currentTerm: 0,
  terms: [],
  courses: [
    {
      id: "math",
      name: "Mathematics",
      teacher: "",
      room: "",
      period: "",
      official: null,
      categories: [],
      assignments: [
        {
          id: "work",
          title: "Assignment",
          category: "Practice",
          earned: score,
          possible: 10,
          due: "",
        },
      ],
    },
  ],
});
function fixture() {
  let time = Date.now(),
    current = book(null),
    sends = 0,
    reads = 0;
  let readError: Error | undefined,
    loginError: Error | undefined,
    sendError: Error | undefined;
  let invalid = false,
    beforeRead: (() => Promise<void>) | undefined;
  const storage = new Store({});
  const writes: string[] = [];
  const set = storage.set.bind(storage);
  storage.set = async (key, value, seconds) => {
    writes.push(value);
    return set(key, value, seconds);
  };
  const claim = storage.claim.bind(storage);
  storage.claim = async (key, value, seconds) => {
    writes.push(value);
    return claim(key, value, seconds);
  };
  const env = {
    SCHOOLITY_PUSH_ENABLED: "true",
    SCHOOLITY_PUSH_ENCRYPTION_KEY: Buffer.alloc(32, 7).toString("base64"),
    CRON_SECRET: "cron-secret-".repeat(4),
  };
  const service = new PushService(
    storage,
    env,
    {
      ensureReady() {},
      async send() {
        if (sendError) throw sendError;
        sends++;
        return invalid ? "invalid" : "sent";
      },
    },
    {
      async login() {
        if (loginError) throw loginError;
        return {
          base: "https://district.example",
          token: "synthetic-district-token",
          expires: time + 3600000,
        };
      },
      async grades() {
        reads++;
        if (beforeRead) await beforeRead();
        if (readError) throw readError;
        return current;
      },
    },
    () => time,
  );
  const id = randomBytes(32).toString("base64url"),
    secret = randomBytes(32).toString("base64url");
  const registration = {
    id,
    device: "a".repeat(64),
    environment: "development",
    username: "synthetic-student",
    password: "synthetic-password",
  };
  return {
    service,
    storage,
    env,
    id,
    secret,
    writes,
    registration,
    register: () => service.register(registration, secret, "fixture-address"),
    tick: () => {
      time += 16 * 60000;
    },
    graded: () => {
      current = book(0);
    },
    readError: (e?: Error) => {
      readError = e;
    },
    loginError: (e?: Error) => {
      loginError = e;
    },
    sendError: (e?: Error) => {
      sendError = e;
    },
    beforeRead: (fn?: () => Promise<void>) => {
      beforeRead = fn;
    },
    invalid: () => {
      invalid = true;
    },
    counts: () => ({ sends, reads }),
  };
}

test("push subscriptions encrypt credentials and require the management secret", async () => {
  const f = fixture();
  await f.register();
  assert.ok(f.writes.length);
  for (const raw of f.writes) {
    assert.ok(!raw.includes("synthetic-password"));
    assert.ok(!raw.includes("synthetic-student"));
    assert.ok(!raw.includes("synthetic-district-token"));
  }
  await assert.rejects(
    f.service.status(f.id, randomBytes(32).toString("base64url")),
    (e: unknown) => e instanceof PortalError && e.status === 401,
  );
  assert.equal((await f.service.status(f.id, f.secret)).status, "active");
  await assert.rejects(
    f.service.remove(f.id, randomBytes(32).toString("base64url")),
  );
  await f.service.remove(f.id, f.secret);
  await assert.rejects(f.service.status(f.id, f.secret));
});
test("initial grades stay silent; zero scores notify once across concurrent checks", async () => {
  const f = fixture();
  await f.register();
  f.tick();
  f.graded();
  const results = await Promise.all([f.service.run(), f.service.run()]);
  assert.equal(
    results.reduce((sum, r) => sum + r.sent, 0),
    1,
  );
  assert.equal(f.counts().sends, 1);
  f.tick();
  await f.service.run();
  assert.equal(f.counts().sends, 1);
});
test("APNs failures retry without losing the newly graded assignment", async () => {
  const f = fixture();
  await f.register();
  f.tick();
  f.graded();
  f.sendError(new Error("Temporary"));
  assert.equal((await f.service.run()).failed, 1);
  f.tick();
  f.sendError();
  assert.equal((await f.service.run()).sent, 1);
});
test("invalid device tokens remove the subscription and its district credentials", async () => {
  const f = fixture();
  await f.register();
  f.tick();
  f.graded();
  f.invalid();
  await f.service.run();
  await assert.rejects(f.service.status(f.id, f.secret));
  f.tick();
  assert.equal((await f.service.run()).checked, 0);
});
test("revoking during a district request cannot restore a subscription or send its grades", async () => {
  const f = fixture();
  await f.register();
  f.tick();
  f.graded();
  let resume!: () => void, started!: () => void;
  const waiting = new Promise<void>((r) => {
    started = r;
  });
  f.beforeRead(async () => {
    started();
    await new Promise<void>((r) => {
      resume = r;
    });
  });
  const run = f.service.run();
  await waiting;
  await f.service.remove(f.id, f.secret);
  resume();
  await run;
  assert.equal(f.counts().sends, 0);
  await assert.rejects(f.service.status(f.id, f.secret));
});
test("rejected district credentials stop polling instead of repeatedly attempting login", async () => {
  const f = fixture();
  await f.register();
  f.tick();
  f.readError(new PortalError("Expired", 401));
  f.loginError(new PortalError("Rejected", 401));
  await f.service.run();
  assert.equal(
    (await f.service.status(f.id, f.secret)).status,
    "sign-in-required",
  );
  const reads = f.counts().reads;
  f.tick();
  await f.service.run();
  assert.equal(f.counts().reads, reads);
});
test("cron requires its own strong secret and missing configuration fails closed", async () => {
  const f = fixture();
  assert.equal(f.service.authorizedCron(null), false);
  assert.equal(f.service.authorizedCron("Bearer wrong"), false);
  assert.equal(f.service.authorizedCron("Bearer " + f.env.CRON_SECRET), true);
  const missing = new PushService(new Store({}), {});
  assert.throws(() => missing.ensureReady());
});
test("grade detection separates reporting periods and ignores hypothetical or excluded work", () => {
  const initial = newlyGraded(book(8), {}, []);
  assert.equal(initial.messages.length, 0);
  const next = book(9);
  assert.equal(
    newlyGraded(next, initial.seen, initial.terms).messages.length,
    0,
  );
  next.currentTerm = 1;
  assert.equal(
    newlyGraded(next, initial.seen, initial.terms).messages.length,
    0,
  );
  const base = newlyGraded(book(null), {}, []);
  const hypo = book(10);
  hypo.courses[0].assignments[0].hypothetical = true;
  assert.equal(newlyGraded(hypo, base.seen, base.terms).messages.length, 0);
});
test("APNs provider creates a verifiable ES256 JWT and reuses it within its validity window", () => {
  const { privateKey, publicKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  });
  const provider = new APNs({
    SCHOOLITY_APNS_KEY_ID: "ABCDEFGHIJ",
    SCHOOLITY_APNS_TEAM_ID: "0123456789",
    SCHOOLITY_APNS_TOPIC: "com.schoolity.app",
    SCHOOLITY_APNS_PRIVATE_KEY: privateKey
      .export({ type: "pkcs8", format: "pem" })
      .toString(),
  });
  const token = provider.token(),
    parts = token.split(".");
  assert.equal(
    verify(
      "sha256",
      Buffer.from(parts.slice(0, 2).join(".")),
      { key: publicKey, dsaEncoding: "ieee-p1363" },
      Buffer.from(parts[2], "base64url"),
    ),
    true,
  );
  assert.equal(provider.token(), token);
});
