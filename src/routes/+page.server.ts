import type { PageServerLoad } from './$types';
import { PortalError } from '$lib/server/portal';
import { browserAuth, REMEMBER_COOKIE, SESSION_COOKIE } from '$lib/server/browser-auth';
import { gradeCacheIdentity } from '$lib/server/grade-cache-identity';

export const load: PageServerLoad = async ({ cookies, url, getClientAddress, setHeaders }) => {
  setHeaders({ 'Cache-Control': 'private, no-store' });
  try {
    const authenticated = !!await browserAuth.restore({ cookies, url, getClientAddress });
    return { authenticated, cacheIdentity: authenticated ? gradeCacheIdentity(cookies.get(SESSION_COOKIE)) : null, signInError: '', retrySavedSignIn: false };
  } catch (error) {
    return { authenticated: false, signInError: error instanceof PortalError ? error.message : 'Could not restore sign-in. Try again.',
      retrySavedSignIn: !!cookies.get(REMEMBER_COOKIE) };
  }
};
