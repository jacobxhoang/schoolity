import { events, object, rows, string } from '../portal-data.ts';
import { exchange, read, PortalError, type Session } from './portal.ts';

export function decodeDocument(payload: unknown, fallback: string) {
  const wrapper = object(payload);
  const document = rows(wrapper.documentDatas)[0] ?? wrapper;
  const encoded = string(document.base64Code).replace(/\s/g, '');
  if (
    !encoded ||
    encoded.length > 12_000_000 ||
    encoded.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)
  )
    throw new PortalError(
      'The district did not return a usable document. Try again.',
    );
  const bytes = Buffer.from(encoded, 'base64');
  const filename =
    (string(document.fileName) || fallback || 'document')
      .split(/[\\/]/)
      .at(-1)!
      .replace(/[\x00-\x1f\x7f<>:"|?*]/g, '_')
      .slice(0, 180) || 'document';
  return { bytes, filename };
}

export async function downloadDocument(
  session: Session,
  id: unknown,
  load = read,
  call = exchange,
) {
  if (
    typeof id !== 'string' ||
    !id.trim() ||
    id.length > 200 ||
    /[\x00-\x1f]/.test(id)
  )
    throw new PortalError('Choose a document to download.', 400);
  const listing = events(
    await load(session, 'documents', undefined),
    'documents',
  );
  const own = listing.find(
    (document) => document.id?.toLowerCase() === id.toLowerCase(),
  );
  if (!own)
    throw new PortalError(
      'This document is no longer available for your account. Refresh the list.',
      404,
    );
  const response = await call(
    session.base,
    'GetStudentDocumentContent',
    `Bearer ${session.token}`,
    { childIntID: 0, languageCode: '1', documentGU: own.id },
  );
  if (response.error)
    throw new PortalError(
      'The district could not download this document. Try again.',
    );
  const data = object(response.data);
  return decodeDocument(
    data.studentAttachedDocumentData ?? data,
    own.filename ?? 'document',
  );
}
