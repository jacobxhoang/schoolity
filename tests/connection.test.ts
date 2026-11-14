import { test } from 'node:test';
import assert from 'node:assert/strict';
import { publicAddress, findSession } from '../src/lib/server/portal.ts';
import { read, readHistorySubject } from '../src/lib/server/portal.ts';
import { DISTRICT_HOST, DISTRICT_URL } from '../src/lib/config.ts';
import { randomUUID } from 'node:crypto';

test('Schoolity has a fixed Anoka district connection', () => {
  assert.equal(DISTRICT_HOST, 'synergyportal.anoka.k12.mn.us');
  assert.equal(DISTRICT_URL, 'https://synergyportal.anoka.k12.mn.us');
});
test('unknown resources cannot reach the district', async () => {
  await assert.rejects(
    read(
      { base: DISTRICT_URL, token: 'unused', expires: Date.now() + 1000 },
      'unsupported-resource',
      undefined,
    ),
    /not available/,
  );
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

test('subject details reuse one course-history read for the signed-in student', async () => {
  const session = {
    base: DISTRICT_URL,
    token: 'synthetic-history-' + randomUUID(),
    expires: Date.now() + 60_000,
    webCookie: 'web=synthetic',
  };
  const historyPage = `<!doctype html><html><body>
    <h1>Class of 2027</h1>
    <script>PXP.CourseHistory = [];</script>
    <table class="pxp-summary details">
      <tr data-guid="req-1"><td>Mathematics</td><td>3</td><td>1</td><td>0.5</td><td>1.5</td></tr>
    </table>
  </body></html>`;
  let pageReads = 0;
  let detailReads = 0;
  const page = async (_base: string, path: string) => {
    if (path.startsWith('/PXP2_CourseHistory.aspx')) {
      pageReads += 1;
      return { text: historyPage, cookie: '' };
    }
    detailReads += 1;
    return {
      text: JSON.stringify({
        d: {
          Data: {
            Columns: { Term: 'Term', CourseTitle: 'Course Title', Mark: 'Mark' },
            Rows: [{ Term: '2025 - S1', CourseTitle: 'Algebra II', Mark: 'A' }],
          },
        },
      }),
      cookie: '',
    };
  };
  const details = await readHistorySubject(session, 'req-1', page);
  assert.deepEqual(details.columns, ['Term', 'Course Title', 'Mark']);
  assert.deepEqual(details.completed[0], ['2025 - S1', 'Algebra II', 'A']);
  await readHistorySubject(session, 'req-1', page);
  assert.equal(pageReads, 1);
  assert.equal(detailReads, 2);
  await assert.rejects(
    readHistorySubject(session, 'unknown-subject', page),
    /not available/,
  );
  assert.equal(pageReads, 1);
});
