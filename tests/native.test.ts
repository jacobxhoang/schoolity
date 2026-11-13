import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nativeData, grades, profile, events } from '../src/lib/portal-data.ts';

test('native display responses preserve the existing grade contract and term zero', () => {
  const input = { traditionalGradebook: { reportingPeriod: { index: 0 }, reportingPeriods: [{ index: 0, gradePeriod: 'Quarter 1' }], courses: [{ courseID: 'math', courseName: 'Math &amp; Science', marks: [{ calculatedScoreRaw: 0, assignments: [{ measure: 'Chapter 4&amp;5', point: 0, pointPossible: 40 }] }] }] } };
  assert.deepEqual(nativeData(input, 'grades'), grades(input));
  const value = nativeData(input, 'grades') as ReturnType<typeof grades>;
  assert.equal(value.currentTerm, 0);
  assert.equal(value.courses[0].official, 0);
  assert.equal(value.courses[0].assignments[0].title, 'Chapter 4&5');
  assert.throws(() => nativeData({}, 'grades'), /reporting period/);
});

test('native profile and listing responses preserve ownership identifiers and decoded labels', () => {
  const identity = { formattedName: 'Sample &amp; Student' };
  assert.deepEqual(nativeData(identity, 'profile'), profile(identity));
  const message = { inboxItemListings: [{ smMessageGU: 'opaque&amp;id', subject: 'Chapter 4&amp;5', from: [{ details1: 'Sample Teacher' }], attachments: [{ smAttachmentGU: 'file-id', documentName: 'Review.pdf' }], messageText: '<p>Practice &amp; review</p>' }] };
  assert.deepEqual(nativeData(message, 'mail'), events(message, 'mail'));
  const mail = nativeData(message, 'mail') as ReturnType<typeof events>;
  assert.equal(mail[0].id, 'opaque&amp;id');
  assert.equal(mail[0].author, 'Sample Teacher');
  assert.equal(mail[0].attachments?.[0].id, 'file-id');
  assert.deepEqual(nativeData({ classLists: [] }, 'schedule'), []);
  assert.deepEqual(nativeData({ studentDocumentDatas: [] }, 'documents'), []);
});
