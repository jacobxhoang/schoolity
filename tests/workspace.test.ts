import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  readLocation,
  courseLocation,
  chartRange,
  scoreChange,
} from '../src/lib/workspace.ts';
import { requestPortal, RequestFailure } from '../src/lib/portal-request.ts';
import { trend, type Course } from '../src/lib/model.ts';

test('course navigation round-trips unusual district identifiers', () => {
  for (const hash of ['', '#overview', '#unknown'])
    assert.deepEqual(readLocation(hash), { section: 'grades', course: null });
  assert.deepEqual(readLocation(courseLocation('Math/2 · A')), {
    section: 'grades',
    course: 'Math/2 · A',
  });
  assert.deepEqual(readLocation('#grades/course/%oops'), {
    section: 'grades',
    course: null,
  });
  assert.deepEqual(readLocation('#attendance'), {
    section: 'grades',
    course: null,
  });
});
test('extra credit is included in chart bounds, with stable empty bounds', () => {
  assert.deepEqual(chartRange([86, 110, NaN]), { low: 0, high: 110 });
  assert.deepEqual(chartRange([]), { low: 0, high: 100 });
});
test('scenario results describe the comparison and unavailable inputs', () => {
  assert.match(scoreChange(90, 86), /\+4.0 percentage points/);
  assert.match(scoreChange(null, 86), /No comparison/);
});
const course: Course = {
  id: 'a',
  name: 'Fictional class',
  teacher: '',
  room: '',
  period: '',
  official: 90,
  categories: [],
  assignments: [
    {
      id: 'later',
      title: 'Later',
      category: '',
      earned: 10,
      possible: 20,
      due: '2/1/2026',
    },
    {
      id: 'earlier',
      title: 'Earlier',
      category: '',
      earned: 20,
      possible: 20,
      due: '12/1/2025',
    },
  ],
};
test('trend follows dates rather than the text sorting of dates', () =>
  assert.deepEqual(trend(course), [100, 75]));
const reply = (status: number, body: unknown): typeof fetch =>
  (async () => new Response(JSON.stringify(body), { status })) as typeof fetch;
test('successful requests use same-origin no-store POSTs', async () => {
  let captured: RequestInit | undefined;
  const transport = (async (input, options) => {
    assert.equal(input, '/api/portal');
    captured = options;
    return new Response('{"data":{}}');
  }) as typeof fetch;
  assert.deepEqual(await requestPortal({ action: 'read' }, transport), {
    data: {},
  });
  assert.equal(captured?.cache, 'no-store');
  assert.equal(captured?.method, 'POST');
});
test('expired sessions and rejected credentials give different recovery advice', async () => {
  await assert.rejects(
    requestPortal({ action: 'read' }, reply(401, {})),
    (e) =>
      e instanceof RequestFailure &&
      e.status === 401 &&
      /session has ended/.test(e.message),
  );
  await assert.rejects(
    requestPortal({ action: 'login' }, reply(401, {})),
    /username and password/,
  );
});
test('temporary server and network errors offer a retry without discarding work', async () => {
  await assert.rejects(
    requestPortal({ action: 'read' }, reply(503, {})),
    /workspace has been kept/,
  );
  await assert.rejects(
    requestPortal({ action: 'read' }, (async () => {
      throw new Error('network');
    }) as typeof fetch),
    /Check your connection/,
  );
});
test('authentication recovery still works for a non-JSON gateway response', async () => {
  await assert.rejects(
    requestPortal(
      { action: 'read' },
      (async () => new Response('Expired', { status: 401 })) as typeof fetch,
    ),
    /session has ended/,
  );
  await assert.rejects(
    requestPortal(
      { action: 'read' },
      (async () =>
        new Response('Unavailable', { status: 503 })) as typeof fetch,
    ),
    /workspace has been kept/,
  );
});
