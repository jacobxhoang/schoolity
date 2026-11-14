import { createHash } from 'node:crypto';
// A one-way namespace, never the cookie that authenticates the account.
export const gradeCacheIdentity = (sessionID: string | undefined) => sessionID
  ? createHash('sha256').update('schoolity:grade-cache:v1:' + sessionID).digest('hex') : null;
