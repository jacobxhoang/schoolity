import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Store } from '../src/lib/server/store.ts';
test('local sessions can be saved and revoked without external services', async () => {
  const store = new Store({});
  await store.set('session:test', 'value', 30);
  assert.equal(await store.get('session:test'), 'value');
  await store.delete('session:test');
  assert.equal(await store.get('session:test'), null);
  await store.set('expired', 'value', -1);
  assert.equal(await store.get('expired'), null);
  assert.equal(await store.increment('login:test', 600), 1);
  assert.equal(await store.increment('login:test', 600), 2);
});
test('Vercel fails closed when shared storage is absent or broken', async () => {
  await assert.rejects(
    new Store({ VERCEL: '1' }).set('session:test', 'value', 30),
    /Configure/,
  );
  await assert.rejects(
    new Store({
      UPSTASH_REDIS_REST_URL: 'http://invalid',
      UPSTASH_REDIS_REST_TOKEN: 'test',
    }).get('test'),
    /HTTPS/,
  );
  const env = {
    VERCEL: '1',
    UPSTASH_REDIS_REST_URL: 'https://example.upstash.io',
    UPSTASH_REDIS_REST_TOKEN: 'test',
  };
  await assert.rejects(
    new Store(
      env,
      (async () =>
        new Response('{"error":"failed"}', { status: 500 })) as typeof fetch,
    ).get('test'),
    /unavailable/,
  );
});
test('independent Vercel instances share sessions, expiry commands, revocation and atomic rate limits', async () => {
  const data = new Map<string, string>();
  const commands: unknown[][] = [];
  const transport = (async (url, options) => {
    assert.equal(url, 'https://example.upstash.io');
    assert.equal(
      (options?.headers as Record<string, string>).Authorization,
      'Bearer test',
    );
    assert.equal(options?.cache, 'no-store');
    const args = JSON.parse(String(options?.body));
    commands.push(args);
    let result: unknown = null;
    if (args[0] === 'SET') {
      data.set(args[1], args[2]);
      assert.equal(args[3], 'EX');
      assert.equal(args[4], 30);
      result = 'OK';
    }
    if (args[0] === 'GET') result = data.get(args[1]) ?? null;
    if (args[0] === 'DEL') {
      data.delete(args[1]);
      result = 1;
    }
    if (args[0] === 'EVAL') result = 3;
    return new Response(JSON.stringify({ result }));
  }) as typeof fetch;
  const env = {
    VERCEL: '1',
    VERCEL_ENV: 'production',
    UPSTASH_REDIS_REST_URL: 'https://example.upstash.io',
    UPSTASH_REDIS_REST_TOKEN: 'test',
  };
  const first = new Store(env, transport),
    second = new Store(env, transport);
  await first.set('session:test', 'value', 30);
  assert.equal(await second.get('session:test'), 'value');
  await second.delete('session:test');
  assert.equal(await first.get('session:test'), null);
  assert.equal(await first.increment('login:hash', 600), 3);
  assert.ok(commands.some((c) => c[0] === 'EVAL'));
  assert.equal(commands[0][1], 'schoolity:production:session:test');
});
