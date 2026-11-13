import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  sessionLifetime,
  sessionCookieOptions,
} from '../src/lib/server/session-policy.ts';
import { signIn, findSession, endSession, limitLogin, PortalError } from '../src/lib/server/portal.ts';
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
    'https://synergyportal.anoka.k12.mn.us',
    'synthetic-user',
    'synthetic-password',
    async () => ({ access_token: 'synthetic-token', expires_in: 86400 }),
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
