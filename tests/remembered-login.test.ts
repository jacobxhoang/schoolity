import { test, type TestContext } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Store, store } from '../src/lib/server/store.ts';
import { RememberedLogins, rememberedLoginKey, REMEMBER_SECONDS } from '../src/lib/server/remembered-login.ts';
import { BrowserAuth, SESSION_COOKIE, REMEMBER_COOKIE, type AuthContext } from '../src/lib/server/browser-auth.ts';
import { signIn, findSession, endSession, bindRememberedSession, PortalError } from '../src/lib/server/portal.ts';

const testKey = Buffer.alloc(32, 7).toString('base64');
const credentials = { username: 'synthetic-student', password: 'synthetic-password-only' };
function jar(initial: Record<string, string> = {}) {
  const values = new Map(Object.entries(initial));
  const options = new Map<string, unknown>();
  const context: AuthContext = {
    url: new URL('https://schoolity.example'), getClientAddress: () => 'test-address',
    cookies: {
      get: (name) => values.get(name),
      set: (name, value, settings) => { values.set(name, value); options.set(name, settings); },
      delete: (name) => { values.delete(name); },
    },
  };
  return { context, values, options };
}
function fixture(t: TestContext) {
  const keys = new Set<string>(), sessions: string[] = [];
  const storage = {
    get: (key: string) => store.get(key), delete: (key: string) => store.delete(key),
    set: async (key: string, value: string, seconds: number) => { keys.add(key); await store.set(key, value, seconds); },
  };
  const saved = new RememberedLogins(storage, { SCHOOLITY_REMEMBER_KEY: testKey });
  const state = {
    logins: 0,
    limits: [] as Array<{ scope: string; key: string }>,
    error: undefined as PortalError | undefined,
    beforeLogin: undefined as (() => Promise<void>) | undefined,
    failRememberEnd: false,
  };
  const remembered = {
    ensureReady: () => saved.ensureReady(),
    create: (value: { username: string; password: string }) => saved.create(value),
    read: (id: string | undefined) => saved.read(id),
    end: async (id: string | undefined) => {
      if (state.failRememberEnd) throw new PortalError('Saved sign-in storage is unavailable.', 503);
      return saved.end(id);
    },
  };
  const auth = new BrowserAuth({
    remembered, findSession, endSession, bindRememberedSession,
    limitLogin: async (scope, key) => { state.limits.push({ scope, key }); },
    signIn: async (district, username, password) => {
      state.logins++;
      if (state.beforeLogin) await state.beforeLogin();
      if (state.error) throw state.error;
      assert.equal(username, credentials.username);
      assert.equal(password, credentials.password);
      const result = await signIn(district, username, password, async () => ({ access_token: 'fixture-' + randomUUID(), expires_in: 120 }));
      sessions.push(result.id);
      return result;
    },
  });
  t.after(async () => { for (const id of sessions) await endSession(id); for (const key of keys) await store.delete(key); });
  return { auth, remembered, state, sessions, keys };
}

test('remembered credentials are encrypted at rest and survive independent server instances', async () => {
  const storage = new Store({});
  const first = new RememberedLogins(storage, { SCHOOLITY_REMEMBER_KEY: testKey });
  const id = await first.create(credentials);
  const raw = (await storage.get(rememberedLoginKey(id)))!;
  assert.ok(!raw.includes(credentials.username));
  assert.ok(!raw.includes(credentials.password));
  assert.ok(!rememberedLoginKey(id).includes(id));
  const second = new RememberedLogins(storage, { SCHOOLITY_REMEMBER_KEY: testKey });
  assert.deepEqual(await second.read(id), credentials);
  const otherId = await first.create(credentials);
  assert.notEqual(JSON.parse(raw).ciphertext, JSON.parse((await storage.get(rememberedLoginKey(otherId)))!).ciphertext);
});

test('ciphertext, expiry, and record identity cannot be tampered with to restore credentials', async () => {
  const storage = new Store({});
  const saved = new RememberedLogins(storage, { SCHOOLITY_REMEMBER_KEY: testKey });
  for (const field of ['ciphertext', 'tag', 'expires']) {
    const id = await saved.create(credentials), key = rememberedLoginKey(id);
    const entry = JSON.parse((await storage.get(key))!);
    entry[field] = field === 'expires' ? entry.expires + 86400000 : (entry[field][0] === 'A' ? 'B' : 'A') + entry[field].slice(1);
    await storage.set(key, JSON.stringify(entry), REMEMBER_SECONDS);
    assert.equal(await saved.read(id), undefined);
    assert.equal(await storage.get(key), null);
  }
  const id = await saved.create(credentials), otherId = 'a'.repeat(43);
  await storage.set(rememberedLoginKey(otherId), (await storage.get(rememberedLoginKey(id)))!, REMEMBER_SECONDS);
  assert.equal(await saved.read(otherId), undefined);
  assert.deepEqual(await saved.read(id), credentials);
});

test('remembered sign-in expires after thirty days and cannot be extended by using it', async () => {
  let now = Date.now();
  const storage = new Store({});
  const saved = new RememberedLogins(storage, { SCHOOLITY_REMEMBER_KEY: testKey }, () => now);
  const id = await saved.create(credentials);
  now += REMEMBER_SECONDS * 1000 - 1;
  assert.deepEqual(await saved.read(id), credentials);
  now += 2;
  assert.equal(await saved.read(id), undefined);
});

test('missing encryption configuration and storage outages fail closed without forgetting a saved login', async () => {
  const storage = new Store({});
  const env: NodeJS.ProcessEnv = { VERCEL: '1', SCHOOLITY_REMEMBER_KEY: testKey };
  const saved = new RememberedLogins(storage, env);
  const id = await saved.create(credentials), raw = await storage.get(rememberedLoginKey(id));
  delete env.SCHOOLITY_REMEMBER_KEY;
  await assert.rejects(saved.read(id), (e) => e instanceof PortalError && e.status === 503);
  assert.equal(await storage.get(rememberedLoginKey(id)), raw);
  await assert.rejects(saved.create(credentials), /temporarily unavailable/);
  const unavailable = new RememberedLogins({ get: async () => { throw new Error('outage'); }, set: storage.set.bind(storage), delete: storage.delete.bind(storage) }, env);
  await assert.rejects(unavailable.read(id), (e) => e instanceof PortalError && e.status === 503);
});

test('web login uses opaque HTTP-only persistent cookies and renews an expired school session on return', async (t) => {
  const f = fixture(t), browser = jar();
  await f.auth.login(browser.context, credentials.username, credentials.password, true);
  const id = browser.values.get(REMEMBER_COOKIE)!;
  assert.match(id, /^[A-Za-z0-9_-]{43}$/);
  assert.deepEqual(browser.options.get(REMEMBER_COOKIE), { path: '/', httpOnly: true, sameSite: 'lax', secure: true, maxAge: REMEMBER_SECONDS });
  assert.ok(!JSON.stringify([...browser.values]).includes(credentials.password));
  assert.ok(await f.auth.restore(browser.context));
  assert.equal(f.state.logins, 1);
  assert.equal(f.state.limits.length, 1);
  assert.equal(f.state.limits[0].scope, 'login');
  assert.ok(f.state.limits[0].key.includes(credentials.username));
  await endSession(browser.values.get(SESSION_COOKIE));
  const returned = jar({ [REMEMBER_COOKIE]: id });
  assert.ok(await f.auth.restore(returned.context));
  assert.equal(f.state.logins, 2);
  assert.equal(f.state.limits.length, 2);
  assert.equal(f.state.limits[1].scope, 'renew');
  assert.equal(f.state.limits[1].key, id);
  assert.ok(returned.values.get(SESSION_COOKIE));
});

test('district rejection during a read or document request renews once and retries the operation', async (t) => {
  const f = fixture(t), browser = jar();
  await f.auth.login(browser.context, credentials.username, credentials.password, true);
  let operations = 0;
  const result = await f.auth.withSession(browser.context, async () => {
    if (++operations === 1) throw new PortalError('Expired district token', 401);
    return 'requested-document-bytes';
  });
  assert.equal(result, 'requested-document-bytes');
  assert.equal(operations, 2);
  assert.equal(f.state.logins, 2);
});

test('signing out revokes the remembered login and every linked session across server instances', async (t) => {
  const f = fixture(t), browser = jar();
  await f.auth.login(browser.context, credentials.username, credentials.password, true);
  const rememberedId = browser.values.get(REMEMBER_COOKIE)!;
  const sibling = jar({ [REMEMBER_COOKIE]: rememberedId });
  const siblingSession = await f.auth.restore(sibling.context);
  assert.ok(siblingSession);
  const siblingId = sibling.values.get(SESSION_COOKIE)!;
  await f.auth.logout(browser.context);
  assert.equal(browser.values.size, 0);
  assert.equal(await findSession(siblingId), undefined);
  assert.equal(await f.remembered.read(rememberedId), undefined);
  assert.equal(await f.auth.restore(sibling.context), undefined);
});

test('signing out clears the local session and cookies even when revoking saved credentials fails', async (t) => {
  const f = fixture(t), browser = jar();
  await f.auth.login(browser.context, credentials.username, credentials.password, true);
  const sessionId = browser.values.get(SESSION_COOKIE)!;
  f.state.failRememberEnd = true;
  await assert.rejects(
    f.auth.logout(browser.context),
    (e) => e instanceof PortalError && e.status === 503,
  );
  assert.equal(browser.values.size, 0);
  assert.equal(await findSession(sessionId), undefined);
});

test('a valid sign-in succeeds even when cleanup of an older saved login is unavailable', async (t) => {
  const f = fixture(t), browser = jar();
  await f.auth.login(browser.context, credentials.username, credentials.password, true);
  f.state.failRememberEnd = true;
  await f.auth.login(browser.context, credentials.username, credentials.password, false);
  assert.equal(f.state.logins, 2);
  assert.equal(browser.values.get(REMEMBER_COOKIE), undefined);
  assert.ok(await findSession(browser.values.get(SESSION_COOKIE)));
});

test('turning off Keep me signed in removes earlier saved credentials and preserves ordinary session login', async (t) => {
  const f = fixture(t), browser = jar();
  await f.auth.login(browser.context, credentials.username, credentials.password, true);
  const previous = browser.values.get(REMEMBER_COOKIE)!;
  await f.auth.login(browser.context, credentials.username, credentials.password, false);
  assert.equal(browser.values.get(REMEMBER_COOKIE), undefined);
  assert.equal(await f.remembered.read(previous), undefined);
  assert.equal((await findSession(browser.values.get(SESSION_COOKIE)))?.rememberKey, undefined);
});

test('temporary renewal errors preserve saved sign-in, while a changed password removes it', async (t) => {
  const f = fixture(t), browser = jar();
  await f.auth.login(browser.context, credentials.username, credentials.password, true);
  const id = browser.values.get(REMEMBER_COOKIE)!;
  await endSession(browser.values.get(SESSION_COOKIE));
  f.state.error = new PortalError('Temporary network error', 503);
  await assert.rejects(f.auth.restore(browser.context), (e) => e instanceof PortalError && e.status === 503);
  assert.equal(browser.values.get(REMEMBER_COOKIE), id);
  assert.deepEqual(await f.remembered.read(id), credentials);
  f.state.error = undefined;
  assert.ok(await f.auth.restore(browser.context));
  await endSession(browser.values.get(SESSION_COOKIE));
  f.state.error = new PortalError('Password changed', 401);
  assert.equal(await f.auth.restore(browser.context), undefined);
  assert.equal(browser.values.get(REMEMBER_COOKIE), undefined);
  assert.equal(await f.remembered.read(id), undefined);
});

test('an in-flight automatic renewal cannot restore sign-in after logout', async (t) => {
  const f = fixture(t), browser = jar();
  await f.auth.login(browser.context, credentials.username, credentials.password, true);
  await endSession(browser.values.get(SESSION_COOKIE));
  let started!: () => void, resume!: () => void;
  const reached = new Promise<void>((resolve) => { started = resolve; });
  const gate = new Promise<void>((resolve) => { resume = resolve; });
  f.state.beforeLogin = async () => { started(); await gate; };
  const restoration = f.auth.restore(browser.context);
  await reached;
  await f.auth.logout(browser.context);
  resume();
  assert.equal(await restoration, undefined);
  assert.equal(browser.values.size, 0);
  for (const id of f.sessions) assert.equal(await findSession(id), undefined);
});

test('simultaneous grade and profile requests share one automatic renewal', async (t) => {
  const f = fixture(t), browser = jar();
  await f.auth.login(browser.context, credentials.username, credentials.password, true);
  await endSession(browser.values.get(SESSION_COOKIE));
  const id = browser.values.get(REMEMBER_COOKIE)!;
  const requests = [jar({ [REMEMBER_COOKIE]: id }), jar({ [REMEMBER_COOKIE]: id }), jar({ [REMEMBER_COOKIE]: id })];
  const sessions = await Promise.all(requests.map((request) => f.auth.restore(request.context)));
  assert.ok(sessions.every(Boolean));
  assert.equal(new Set(requests.map((request) => request.values.get(SESSION_COOKIE))).size, 1);
  assert.equal(f.state.logins, 2);
});
