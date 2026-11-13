import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  districtAddress,
  publicAddress,
  findSession,
} from '../src/lib/server/portal.ts';
import { read } from '../src/lib/server/portal.ts';
import { DISTRICT_HOST, DISTRICT_URL } from '../src/lib/config.ts';

test('Schoolity has a fixed Anoka district connection', () => {
  assert.equal(DISTRICT_HOST, 'synergyportal.anoka.k12.mn.us');
  assert.equal(DISTRICT_URL, 'https://synergyportal.anoka.k12.mn.us');
});
test('attendance is not an available district resource', async () => {
  await assert.rejects(
    read(
      { base: DISTRICT_URL, token: 'unused', expires: Date.now() + 1000 },
      'attendance',
      undefined,
    ),
    /not available/,
  );
});

test('district URLs retain deployment prefixes and remove portal filenames', () => {
  assert.equal(
    districtAddress('https://district.example.org/SVUE/Home_PXP2.aspx?x=1')
      .href,
    'https://district.example.org/SVUE',
  );
  assert.equal(districtAddress('sisstudent.fcps.edu').pathname, '/SVUE');
});
test('district input rejects insecure URLs, credentials, internal hosts and custom ports', () => {
  for (const input of [
    'http://district.example.org',
    '127.0.0.1',
    'https://user:secret@district.example.org',
    'https://district.example.org:8443',
    'https://school.internal',
    'https://district.example.org/%2fhidden',
  ])
    assert.throws(() => districtAddress(input));
});
test('district connections exclude private and reserved IPv4 and IPv6 destinations', () => {
  for (const address of [
    '127.0.0.1',
    '192.168.1.1',
    '10.0.0.1',
    '172.16.0.1',
    '169.254.169.254',
    '100.64.0.1',
    '198.18.0.1',
    '224.0.0.1',
    '::1',
    '::ffff:127.0.0.1',
    'fc00::1',
    '2001:db8::1',
    '2002:7f00:1::1',
  ])
    assert.equal(publicAddress(address), false);
  assert.equal(publicAddress('8.8.8.8'), true);
  assert.equal(publicAddress('2606:4700:4700::1111'), true);
});
test('missing and unknown session cookies do not authenticate', async () => {
  assert.equal(await findSession(undefined), undefined);
  assert.equal(await findSession('not-a-session'), undefined);
});
