import type { PageServerLoad } from './$types';
import { PortalError } from '$lib/server/portal';
import { browserAuth, REMEMBER_COOKIE } from '$lib/server/browser-auth';

export const load: PageServerLoad = async ({ cookies, url, getClientAddress, setHeaders }) => {
  setHeaders({ 'Cache-Control': 'private, no-store' });
  try {
    return { authenticated: !!await browserAuth.restore({ cookies, url, getClientAddress }), signInError: '', retrySavedSignIn: false };
  } catch (error) {
    return { authenticated: false, signInError: error instanceof PortalError ? error.message : 'Could not restore sign-in. Try again.',
      retrySavedSignIn: !!cookies.get(REMEMBER_COOKIE) };
  }
};
