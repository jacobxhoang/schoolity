import { test } from 'node:test';
import assert from 'node:assert/strict';
import { events } from '../src/lib/portal-data.ts';
test('mail keeps senders separate from the title and message body', () => {
  const [message] = events(
    {
      inboxItemListings: [
        {
          subject: 'Class update',
          from: [{ details1: 'Teacher One' }, { details1: 'Teacher Two' }],
          messageText: '<p>Bring your notebook &amp; pencil.</p>',
        },
      ],
    },
    'mail',
  );
  assert.equal(message.title, 'Class update');
  assert.equal(message.author, 'Teacher One, Teacher Two');
  assert.equal(message.detail.trim(), 'Bring your notebook & pencil.');
});
test('missing sender data leaves the title and body usable', () => {
  const [message] = events(
    { inboxItemListings: [{ subject: 'Notice', messageText: 'Message body' }] },
    'mail',
  );
  assert.equal(message.author, '');
  assert.equal(message.detail, 'Message body');
  assert.equal(message.title, 'Notice');
});
