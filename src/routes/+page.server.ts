import type { PageServerLoad } from './$types';
import { findSession } from '$lib/server/portal';

export const load: PageServerLoad = async ({ cookies, setHeaders }) => {
  setHeaders({ 'Cache-Control': 'private, no-store' });
  return {
    authenticated: !!(await findSession(cookies.get('schoolity_session'))),
  };
};
