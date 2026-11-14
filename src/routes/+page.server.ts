import type { PageServerLoad } from './$types';
import { PortalError } from '$lib/server/portal';
import {
  browserAuth,
  REMEMBER_COOKIE,
  SESSION_COOKIE,
} from '$lib/server/browser-auth';
import { gradeCacheIdentity } from '$lib/server/grade-cache-identity';

export const load: PageServerLoad = async ({ cookies, setHeaders }) => {
  setHeaders({ 'Cache-Control': 'private, no-store' });
  const savedSignIn = !!cookies.get(REMEMBER_COOKIE);
  try {
    // Only read an existing session while rendering. An expired saved sign-in
    // is renewed from the browser after this page paints, so a slow district
    // cannot delay the response or hold up navigation.
    const session = await browserAuth.existing({ cookies });
    return {
      authenticated: !!session,
      cacheIdentity: session
        ? gradeCacheIdentity(cookies.get(SESSION_COOKIE))
        : null,
      signInError: '',
      retrySavedSignIn: !session && savedSignIn,
    };
  } catch (error) {
    return {
      authenticated: false,
      cacheIdentity: null,
      signInError:
        error instanceof PortalError
          ? error.message
          : 'Could not restore sign-in. Try again.',
      retrySavedSignIn: savedSignIn,
    };
  }
};
