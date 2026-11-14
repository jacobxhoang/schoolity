import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import {
  PortalError,
  read,
  readHistorySubject,
} from '$lib/server/portal';
import { nativeData, object } from '$lib/portal-data';
import { DISTRICT_URL } from '$lib/config';
import { browserAuth } from '$lib/server/browser-auth';
import { readRecords } from '$lib/records';
export const POST: RequestHandler = async ({
  request,
  cookies,
  url,
  getClientAddress,
}) => {
  const context = { cookies, url, getClientAddress };
  const headers = { 'Cache-Control': 'no-store', Pragma: 'no-cache' };
  try {
    if (
      request.headers.get('origin') !== url.origin ||
      !request.headers.get('content-type')?.startsWith('application/json')
    )
      throw new PortalError('A same-origin JSON request is required.', 403);
    if (Number(request.headers.get('content-length')) > 8192)
      throw new PortalError('Request too large.', 413);
    const raw = await request.text();
    if (raw.length > 8192) throw new PortalError('Request too large.', 413);
    let input;
    try {
      input = object(JSON.parse(raw));
    } catch {
      throw new PortalError('Invalid request.', 400);
    }
    if (input.action === 'logout') {
      await browserAuth.logout(context);
      return json({ ok: true }, { headers });
    }
    if (input.action === 'login') {
      if (
        typeof input.username !== 'string' ||
        typeof input.password !== 'string' ||
        !input.username.trim() ||
        !input.password
      )
        throw new PortalError('Enter your username and password.', 400);
      if (input.remember !== undefined && typeof input.remember !== 'boolean')
        throw new PortalError('Choose whether to stay signed in.', 400);
      if (
        input.district !== undefined &&
        input.district !== DISTRICT_URL &&
        input.district !== 'synergyportal.anoka.k12.mn.us'
      )
        throw new PortalError(
          'This Schoolity instance only connects to the configured Anoka district.',
          400,
        );
      await browserAuth.login(context, input.username, input.password, input.remember === true);
      return json({ ok: true }, { headers });
    }
    if (input.action === 'session')
      return json({ connected: !!await browserAuth.restore(context) }, { headers });
    if (typeof input.resource !== 'string')
      throw new PortalError('Select a resource.', 400);
    const resource = input.resource;
    const data = await browserAuth.withSession(context, (session) => resource === 'history-subject'
      ? readHistorySubject(session, input.subject)
      : read(session, resource, input.term));
    return json(
      { data: input.normalized === true && resource !== 'history-subject'
        ? ['student', 'history', 'attendance'].includes(resource) ? readRecords(resource, data) : nativeData(data, resource)
        : data },
      { headers },
    );
  } catch (error) {
    return json(
      {
        error:
          error instanceof PortalError
            ? error.message
            : 'Could not reach your district. Try again.',
      },
      { status: error instanceof PortalError ? error.status : 502, headers },
    );
  }
};
