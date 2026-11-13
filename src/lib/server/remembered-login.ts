import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';
import { store, type Store } from './store.ts';
import { PortalError } from './portal.ts';

export const REMEMBER_SECONDS = 30 * 86400;
const validId = (id: string | undefined): id is string => !!id && /^[A-Za-z0-9_-]{43}$/.test(id);
export function rememberedLoginKey(id: string): string {
  return 'remember:' + createHash('sha256').update(id).digest('hex');
}
interface Credentials { username: string; password: string }

export class RememberedLogins {
  private localKey = randomBytes(32);
  private storage: Pick<Store, 'get' | 'set' | 'delete'>;
  private env: NodeJS.ProcessEnv;
  private now: () => number;
  constructor(
    storage: Pick<Store, 'get' | 'set' | 'delete'> = store,
    env: NodeJS.ProcessEnv = process.env,
    now: () => number = Date.now,
  ) { this.storage = storage; this.env = env; this.now = now; }
  private key(): Buffer {
    const configured = this.env.SCHOOLITY_REMEMBER_KEY;
    if (configured && /^[A-Za-z0-9+/]{43}=$/.test(configured)) {
      const key = Buffer.from(configured, 'base64');
      if (key.length === 32) return key;
    }
    if (configured || this.env.VERCEL)
      throw new PortalError('Saved sign-in is temporarily unavailable. Try again later.', 503);
    // Local development uses an in-memory store and a process-local key.
    return this.localKey;
  }
  ensureReady(): void { this.key(); }
  async create(credentials: Credentials): Promise<string> {
    const key = this.key();
    const id = randomBytes(32).toString('base64url');
    const expires = this.now() + REMEMBER_SECONDS * 1000;
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', key, iv);
    cipher.setAAD(Buffer.from(`schoolity:v1:${rememberedLoginKey(id)}:${expires}`));
    const ciphertext = Buffer.concat([cipher.update(JSON.stringify(credentials), 'utf8'), cipher.final()]);
    try {
      await this.storage.set(rememberedLoginKey(id), JSON.stringify({
        version: 1, expires, iv: iv.toString('base64url'),
        tag: cipher.getAuthTag().toString('base64url'), ciphertext: ciphertext.toString('base64url'),
      }), REMEMBER_SECONDS);
    } catch { throw new PortalError('Saved sign-in storage is unavailable. Try again.', 503); }
    return id;
  }
  async read(id: string | undefined): Promise<Credentials | undefined> {
    if (!validId(id)) return undefined;
    let raw: string | null;
    try { raw = await this.storage.get(rememberedLoginKey(id)); }
    catch { throw new PortalError('Saved sign-in storage is unavailable. Try again.', 503); }
    if (!raw) return undefined;
    // Missing configuration is retryable, and must not delete a saved login.
    const key = this.key();
    try {
      const entry = JSON.parse(raw);
      if (entry.version !== 1 || !Number.isFinite(entry.expires) || entry.expires <= this.now() ||
          typeof entry.iv !== 'string' || typeof entry.tag !== 'string' || typeof entry.ciphertext !== 'string')
        throw new Error('Invalid saved login');
      const iv = Buffer.from(entry.iv, 'base64url'), tag = Buffer.from(entry.tag, 'base64url');
      if (iv.length !== 12 || tag.length !== 16) throw new Error('Invalid saved login');
      const decipher = createDecipheriv('aes-256-gcm', key, iv, { authTagLength: 16 });
      decipher.setAAD(Buffer.from(`schoolity:v1:${rememberedLoginKey(id)}:${entry.expires}`));
      decipher.setAuthTag(tag);
      const credentials = JSON.parse(Buffer.concat([
        decipher.update(Buffer.from(entry.ciphertext, 'base64url')), decipher.final(),
      ]).toString('utf8'));
      if (typeof credentials.username !== 'string' || !credentials.username ||
          typeof credentials.password !== 'string' || !credentials.password) throw new Error('Invalid saved login');
      return { username: credentials.username, password: credentials.password };
    } catch {
      await this.end(id);
      return undefined;
    }
  }
  async end(id: string | undefined): Promise<void> {
    if (!validId(id)) return;
    try { await this.storage.delete(rememberedLoginKey(id)); }
    catch { throw new PortalError('Saved sign-in storage is unavailable. Try again.', 503); }
  }
}
export const rememberedLogins = new RememberedLogins();
