import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  decodeDocument,
  downloadDocument,
} from '../src/lib/server/documents.ts';
import { events } from '../src/lib/portal-data.ts';
import { PortalError, type Session } from '../src/lib/server/portal.ts';
const session: Session = {
  base: 'https://school.example',
  token: 'test-token',
  expires: Date.now() + 1000,
};
const listing = {
  studentDocumentDatas: [
    {
      documentGU: 'sample-id',
      documentFileName: 'Report.pdf',
      documentComment: 'Report',
      documentType: 'Report card',
    },
  ],
};
test('document list preserves the download identifier and filename', () => {
  assert.equal(events(listing, 'documents')[0].id, 'sample-id');
  assert.equal(events(listing, 'documents')[0].filename, 'Report.pdf');
});
test('downloads request only a document in this student’s listing and decode its bytes', async () => {
  const result = await downloadDocument(
    session,
    'sample-id',
    async () => listing,
    async (base, method, auth, parameters) => {
      assert.equal(base, session.base);
      assert.equal(method, 'GetStudentDocumentContent');
      assert.equal(auth, 'Bearer test-token');
      assert.equal(parameters.documentGU, 'sample-id');
      return {
        data: {
          studentAttachedDocumentData: {
            documentDatas: [
              {
                base64Code: Buffer.from('%PDF-test').toString('base64'),
                fileName: 'Report.pdf',
              },
            ],
          },
        },
      };
    },
  );
  assert.equal(result.bytes.toString(), '%PDF-test');
  assert.equal(result.filename, 'Report.pdf');
});
test('an unlisted identifier cannot reach the document-content API', async () => {
  await assert.rejects(
    downloadDocument(
      session,
      'other-account-id',
      async () => listing,
      async () => {
        assert.fail('Content API must not be called');
      },
    ),
    (e) => e instanceof PortalError && e.status === 404,
  );
});
test('missing, corrupt and oversized document data produce a recoverable error', () => {
  for (const base64Code of ['', 'not valid!', 'AAAA'.repeat(3_000_001)])
    assert.throws(
      () => decodeDocument({ base64Code }, 'report.pdf'),
      PortalError,
    );
});
test('filenames cannot inject paths or response headers', () => {
  const result = decodeDocument(
    { base64Code: 'dGVzdA==', fileName: '../../secret\\report\r\n".pdf' },
    'fallback.pdf',
  );
  assert.equal(result.filename, 'report___.pdf');
});
test('Vercel downloads fail with a useful error before exceeding function response limits', () => {
  const previous = process.env.VERCEL;
  process.env.VERCEL = '1';
  try {
    assert.throws(
      () =>
        decodeDocument(
          { base64Code: Buffer.alloc(4_000_001).toString('base64') },
          'large.pdf',
        ),
      (e) =>
        e instanceof PortalError &&
        e.status === 413 &&
        e.message.includes('StudentVUE'),
    );
  } finally {
    if (previous === undefined) delete process.env.VERCEL;
    else process.env.VERCEL = previous;
  }
});
