import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import {
  endSession,
  findSession,
  PortalError,
  read,
  signIn,
} from '$lib/server/portal';
import { object } from '$lib/portal-data';
import { DISTRICT_URL } from '$lib/config';
const attempts = new Map<string, { count: number; until: number }>();
export const POST: RequestHandler = async ({
  request,
  cookies,
  url,
  getClientAddress,
}) => {
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
    const id = cookies.get('schoolity_session');
    if (input.action === 'logout') {
      endSession(id);
      cookies.delete('schoolity_session', { path: '/' });
      return json({ ok: true }, { headers });
    }
    if (input.action === 'login') {
      for (const [key, value] of attempts)
        if (value.until < Date.now()) attempts.delete(key);
      const ip = getClientAddress();
      const attempt = attempts.get(ip) ?? {
        count: 0,
        until: Date.now() + 600_000,
      };
      if (attempt.count >= 10)
        throw new PortalError(
          'Too many login attempts. Try again in ten minutes.',
          429,
        );
      if (attempts.size > 10000)
        throw new PortalError('Please try again later.', 503);
      attempt.count++;
      attempts.set(ip, attempt);
      if (
        typeof input.username !== 'string' ||
        typeof input.password !== 'string' ||
        !input.username.trim() ||
        !input.password
      )
        throw new PortalError('Enter your username and password.', 400);
      if (
        input.district !== undefined &&
        input.district !== DISTRICT_URL &&
        input.district !== 'synergyportal.anoka.k12.mn.us'
      )
        throw new PortalError(
          'This Schoolity instance only connects to the configured Anoka district.',
          400,
        );
      const next = await signIn(DISTRICT_URL, input.username, input.password);
      endSession(id);
      cookies.set('schoolity_session', next, {
        path: '/',
        httpOnly: true,
        sameSite: 'strict',
        secure: url.protocol === 'https:',
        maxAge: 1800,
      });
      return json({ ok: true }, { headers });
    }
    const session = findSession(id);
    if (input.action === 'session')
      return json({ connected: !!session }, { headers });
    if (!session)
      throw new PortalError(
        'Your session has ended. Sign in again to refresh your school data.',
        401,
      );
    if (typeof input.resource !== 'string')
      throw new PortalError('Select a resource.', 400);
    return json(
      { data: await read(session, input.resource, input.term) },
      { headers },
    );
  } catch (error) {
    return json(
      {
        error:
          error instanceof PortalError
            ? error.message
            : 'Could not reach your district. Check the portal address and try again.',
      },
      { status: error instanceof PortalError ? error.status : 502, headers },
    );
  }
};
