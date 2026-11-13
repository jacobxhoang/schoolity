import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { PortalError } from '$lib/server/portal';
import { browserAuth } from '$lib/server/browser-auth';
import {
  downloadDocument,
  downloadMailAttachment,
} from '$lib/server/documents';
import { object } from '$lib/portal-data';

export const POST: RequestHandler = async ({ request, cookies, url, getClientAddress }) => {
  const headers = {
    'Cache-Control': 'no-store',
    Pragma: 'no-cache',
    'X-Content-Type-Options': 'nosniff',
  };
  try {
    if (
      request.headers.get('origin') !== url.origin ||
      !request.headers.get('content-type')?.startsWith('application/json')
    )
      throw new PortalError('A same-origin JSON request is required.', 403);
    if (Number(request.headers.get('content-length')) > 1024)
      throw new PortalError('Request too large.', 413);
    const raw = await request.text();
    if (raw.length > 1024) throw new PortalError('Request too large.', 413);
    let input;
    try {
      input = object(JSON.parse(raw));
    } catch {
      throw new PortalError('Invalid request.', 400);
    }
    if (
      input.kind !== undefined &&
      input.kind !== 'document' &&
      input.kind !== 'mail'
    )
      throw new PortalError('Unsupported download type.', 400);
    const file = await browserAuth.withSession({ cookies, url, getClientAddress }, (session) =>
      input.kind === 'mail'
        ? downloadMailAttachment(session, input.messageId, input.id)
        : downloadDocument(session, input.id));
    const ascii = file.filename.replace(/[^\x20-\x7e]/g, '_');
    const encoded = encodeURIComponent(file.filename).replace(
      /['()*]/g,
      (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase(),
    );
    return new Response(new Uint8Array(file.bytes), {
      headers: {
        ...headers,
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': `attachment; filename="${ascii}"; filename*=UTF-8''${encoded}`,
      },
    });
  } catch (e) {
    return json(
      {
        error:
          e instanceof PortalError ? e.message : 'Download failed. Try again.',
      },
      { status: e instanceof PortalError ? e.status : 502, headers },
    );
  }
};
