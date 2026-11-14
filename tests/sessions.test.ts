import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  sessionLifetime,
  sessionCookieOptions,
} from '../src/lib/server/session-policy.ts';
import { signIn, findSession, endSession, limitLogin, PortalError } from '../src/lib/server/portal.ts';
import { BrowserAuth } from '../src/lib/server/browser-auth.ts';
import { DISTRICT_URL } from '../src/lib/config.ts';
import { store } from '../src/lib/server/store.ts';
import { createHash, randomUUID } from 'node:crypto';
test('district sessions longer than thirty minutes retain their validity', () => {
  assert.equal(sessionLifetime(86400), 86400);
  assert.equal(sessionLifetime('7200'), 7200);
  assert.equal(sessionLifetime(300), 300);
  assert.equal(sessionLifetime(999999999), 30 * 86400);
  for (const value of [null, undefined, 'invalid', 0, -1, Infinity, NaN])
    assert.equal(sessionLifetime(value), 1800);
});
test('persistent cookies allow returning navigation while keeping credentials out of script access', () => {
  const cookie = sessionCookieOptions(
    new URL('https://schoolity.example'),
    86400,
  );
  assert.equal(cookie.maxAge, 86400);
  assert.equal(cookie.sameSite, 'lax');
  assert.equal(cookie.httpOnly, true);
  assert.equal(cookie.secure, true);
  assert.equal(cookie.path, '/');
  assert.equal(
    sessionCookieOptions(new URL('http://127.0.0.1:5180'), 300).secure,
    false,
  );
});
test('interactive and automatic sign-in use separate rate-limit buckets', async () => {
  const key = 'synthetic-' + randomUUID();
  const digest = createHash('sha256').update(key).digest('hex');
  const stored = ['limit:login:' + digest, 'limit:renew:' + digest];
  try {
    for (let i = 0; i < 10; i++) await limitLogin('login', key);
    await assert.rejects(
      limitLogin('login', key),
      (e) => e instanceof PortalError && e.status === 429,
    );
    await limitLogin('renew', key);
  } finally {
    for (const item of stored) await store.delete(item);
  }
});
test('the same saved session survives repeated server loads and sign-out revokes it', async () => {
  const before = Date.now();
  const saved = await signIn(
    'synthetic-user',
    'synthetic-password',
    async (base) => {
      assert.equal(base, DISTRICT_URL);
      return { access_token: 'synthetic-token', expires_in: 86400 };
    },
  );
  assert.equal(saved.maxAge, 86400);
  for (let i = 0; i < 3; i++) {
    const session = await findSession(saved.id);
    assert.equal(session?.token, 'synthetic-token');
    assert.ok(session!.expires >= before + 86400 * 1000);
    assert.ok(!JSON.stringify(session).includes('synthetic-password'));
  }
  await endSession(saved.id);
  assert.equal(await findSession(saved.id), undefined);
});

test('rendering reads an existing session without contacting the district', async () => {
  const session = {
    base: DISTRICT_URL,
    token: 'synthetic-existing-token',
    expires: Date.now() + 60_000,
  };
  let signIns = 0;
  let credentialReads = 0;
  const auth = new BrowserAuth({
    findSession: async (id) => (id === 'known-session' ? session : undefined),
    signIn: async () => {
      signIns += 1;
      return { id: 'new-session', maxAge: 60 };
    },
    endSession: async () => {},
    bindRememberedSession: async () => {},
    limitLogin: async () => {},
    remembered: {
      ensureReady: () => {},
      create: async () => 'unused',
      read: async () => {
        credentialReads += 1;
        return { username: 'synthetic', password: 'synthetic' };
      },
      end: async () => {},
    },
  });
  const jar = new Map<string, string>([['schoolity_session', 'known-session']]);
  const context = {
    cookies: {
      get: (name: string) => jar.get(name),
      set: (name: string, value: string) => void jar.set(name, value),
      delete: (name: string) => void jar.delete(name),
    },
    url: new URL('https://schoolity.example/'),
    getClientAddress: () => '127.0.0.1',
  };
  assert.equal(await auth.existing(context), session);
  assert.equal(signIns, 0);
  assert.equal(credentialReads, 0);
});
