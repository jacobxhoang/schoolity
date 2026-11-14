import { createCipheriv, createDecipheriv, createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { store, type Store } from './store.ts';
import { APNs, type PushEnvironment } from './apns.ts';
import { signIn, findSession, endSession, read, PortalError, type Session } from './portal.ts';
import { grades } from '../portal-data.ts';
import type { GradeData } from '../model';

const TTL = 30 * 86400, QUEUE = 'push:due';
const hash = (s: string) => createHash('sha256').update(s).digest('hex');
const validID = (s: unknown): s is string => typeof s === 'string' && /^[A-Za-z0-9_-]{43}$/.test(s);
const recordKey = (id: string) => 'push:record:' + hash(id);
interface RecordData {
  version: 1; expires: number; secretHash: string; device: string; environment: PushEnvironment;
  credentials: { username: string; password: string }; session: Session;
  seen: Record<string, true>; terms: number[]; status: 'active' | 'sign-in-required';
  lastChecked: number; lastSent: number;
}
type Storage = Pick<Store, 'get' | 'set' | 'delete' | 'increment' | 'claim' | 'compareSet' | 'due' | 'schedule' | 'unschedule'>;
interface District {
  login(username: string, password: string): Promise<Session>;
  grades(session: Session): Promise<GradeData>;
}
const district: District = {
  async login(username, password) {
    const result = await signIn(username, password);
    try {
      const session = await findSession(result.id);
      if (!session) throw new PortalError('Could not create a district session.', 502);
      return session;
    } finally { await endSession(result.id); }
  },
  async grades(session) { return grades(await read(session, 'grades', undefined)); },
};

export function newlyGraded(book: GradeData, previous: Record<string, true>, terms: number[]) {
  const seen = { ...previous }, messages: { id: string; body: string }[] = [];
  const baseline = !terms.includes(book.currentTerm);
  for (const course of book.courses) for (const assignment of course.assignments) {
    if (assignment.excluded || assignment.hypothetical || assignment.earned === null || !Number.isFinite(assignment.earned)) continue;
    const id = hash(JSON.stringify([book.currentTerm, course.id, assignment.id]));
    if (!baseline && !seen[id]) messages.push({ id, body: `${course.name} — ${assignment.title}: ${assignment.earned} / ${assignment.possible}` });
    seen[id] = true;
  }
  return { seen, terms: [...new Set([...terms, book.currentTerm])], messages };
}

export class PushService {
  private storage: Storage;
  private env: NodeJS.ProcessEnv;
  private provider: Pick<APNs, 'ensureReady' | 'send'>;
  private portal: District;
  private now: () => number;
  constructor(storage: Storage = store, env: NodeJS.ProcessEnv = process.env,
              provider: Pick<APNs, 'ensureReady' | 'send'> = new APNs(env),
              portal: District = district, now = Date.now) {
    this.storage = storage; this.env = env; this.provider = provider; this.portal = portal; this.now = now;
  }
  private key() {
    const value = this.env.SCHOOLITY_PUSH_ENCRYPTION_KEY ?? '';
    if (!/^[A-Za-z0-9+/]{43}=$/.test(value) || Buffer.from(value, 'base64').length !== 32)
      throw new PortalError('Closed-app alerts are not configured on this service.', 503);
    return Buffer.from(value, 'base64');
  }
  ensureReady() {
    if (this.env.SCHOOLITY_PUSH_ENABLED !== 'true') throw new PortalError('Closed-app alerts are not enabled on this service.', 503);
    this.key(); this.provider.ensureReady();
    if (!this.env.CRON_SECRET || this.env.CRON_SECRET.length < 32)
      throw new PortalError('The notification scheduler is not configured.', 503);
  }
  private encrypt(id: string, value: RecordData) {
    const iv = randomBytes(12), cipher = createCipheriv('aes-256-gcm', this.key(), iv);
    cipher.setAAD(Buffer.from(recordKey(id)));
    const data = Buffer.concat([cipher.update(JSON.stringify(value)), cipher.final()]);
    return JSON.stringify({ iv: iv.toString('base64url'), tag: cipher.getAuthTag().toString('base64url'), data: data.toString('base64url') });
  }
  private decrypt(id: string, raw: string): RecordData {
    try {
      const wrapped = JSON.parse(raw), decipher = createDecipheriv('aes-256-gcm', this.key(), Buffer.from(wrapped.iv, 'base64url'));
      decipher.setAAD(Buffer.from(recordKey(id))); decipher.setAuthTag(Buffer.from(wrapped.tag, 'base64url'));
      const record = JSON.parse(Buffer.concat([decipher.update(Buffer.from(wrapped.data, 'base64url')), decipher.final()]).toString());
      if (record.version !== 1 || record.expires <= this.now()) throw new Error();
      return record;
    } catch { throw new PortalError('This notification subscription has ended. Enable alerts again.', 410); }
  }
  private async authenticated(id: unknown, secret: unknown) {
    if (!validID(id) || !validID(secret)) throw new PortalError('Invalid notification subscription.', 401);
    const raw = await this.storage.get(recordKey(id));
    if (!raw) throw new PortalError('This notification subscription has ended.', 410);
    const record = this.decrypt(id, raw);
    if (!timingSafeEqual(Buffer.from(hash(secret)), Buffer.from(record.secretHash))) throw new PortalError('Invalid notification subscription.', 401);
    return { record, raw, id };
  }
  async register(input: Record<string, unknown>, secret: string, address: string) {
    this.ensureReady();
    const { id, device, environment, username, password } = input;
    if (!validID(id) || !validID(secret) || typeof device !== 'string' || !/^[a-f0-9]{64,256}$/.test(device) ||
        !['development', 'production'].includes(String(environment)) || typeof username !== 'string' ||
        !username.trim() || username.length > 256 || typeof password !== 'string' || !password || password.length > 1024)
      throw new PortalError('Invalid notification registration.', 400);
    for (const bucket of [hash(address), hash(username.toLowerCase())])
      if (await this.storage.increment('push:limit:' + bucket, 600) > 10) throw new PortalError('Too many attempts. Try again in ten minutes.', 429);
    if (await this.storage.get('push:revoked:' + hash(id))) throw new PortalError('Create a new notification subscription.', 410);
    const old = await this.storage.get(recordKey(id));
    const existing = old ? (await this.authenticated(id, secret)).record : undefined;
    if (existing && existing.credentials.username.toLowerCase() !== username.toLowerCase()) throw new PortalError('Disable the previous account’s alerts first.', 409);
    const session = await this.portal.login(username.trim(), password);
    const book = await this.portal.grades(session);
    const baseline = newlyGraded(book, existing?.seen ?? {}, existing?.terms ?? []);
    const record: RecordData = { version: 1, expires: this.now() + TTL * 1000, secretHash: hash(secret),
      device, environment: environment as PushEnvironment, credentials: { username: username.trim(), password }, session,
      seen: baseline.seen, terms: baseline.terms, status: 'active', lastChecked: this.now(), lastSent: existing?.lastSent ?? 0 };
    const next = this.encrypt(id, record);
    if (await this.storage.get('push:revoked:' + hash(id))) throw new PortalError('This notification subscription was disabled.', 410);
    const saved = old ? await this.storage.compareSet(recordKey(id), old, next, TTL) : await this.storage.claim(recordKey(id), next, TTL);
    if (!saved) throw new PortalError('Notification settings changed. Try again.', 409);
    if (await this.storage.get('push:revoked:' + hash(id))) {
      await this.storage.compareSet(recordKey(id), next, null);
      throw new PortalError('This notification subscription was disabled.', 410);
    }
    await this.storage.schedule(QUEUE, id, this.now() + 5 * 60 * 1000);
    return { status: 'active', expires: record.expires, lastChecked: record.lastChecked };
  }
  async status(id: unknown, secret: string) {
    const { record } = await this.authenticated(id, secret);
    return { status: record.status, expires: record.expires, lastChecked: record.lastChecked, lastSent: record.lastSent };
  }
  async remove(id: unknown, secret: string) {
    if (!validID(id) || !validID(secret)) throw new PortalError('Invalid notification subscription.', 401);
    if (!await this.storage.get(recordKey(id))) return;
    const { raw } = await this.authenticated(id, secret);
    await this.storage.set('push:revoked:' + hash(id), '1', TTL);
    await this.storage.compareSet(recordKey(id), raw, null);
    await this.storage.unschedule(QUEUE, id);
  }
  authorizedCron(header: string | null) {
    const expected = `Bearer ${this.env.CRON_SECRET ?? ''}`;
    return (this.env.CRON_SECRET?.length ?? 0) >= 32 && !!header && header.length === expected.length &&
      timingSafeEqual(Buffer.from(header), Buffer.from(expected));
  }
  async run() {
    this.ensureReady();
    let checked = 0, sent = 0, failed = 0;
    const start = this.now();
    // Bound each invocation to one student. A frequent external scheduler can
    // invoke again to drain larger queues without exceeding function limits.
    for (const id of await this.storage.due(QUEUE, this.now(), 1)) {
      const lock = 'push:lock:' + hash(id), lease = randomBytes(24).toString('base64url');
      if (!await this.storage.claim(lock, lease, 120)) continue;
      try {
        const raw = await this.storage.get(recordKey(id));
        if (!raw || await this.storage.get('push:revoked:' + hash(id))) { await this.storage.unschedule(QUEUE, id); continue; }
        const record = this.decrypt(id, raw);
        if (record.status !== 'active') { await this.storage.unschedule(QUEUE, id); continue; }
        let book: GradeData;
        try {
          if (record.session.expires <= this.now()) record.session = await this.portal.login(record.credentials.username, record.credentials.password);
          try { book = await this.portal.grades(record.session); }
          catch (error) {
            if (!(error instanceof PortalError) || error.status !== 401) throw error;
            record.session = await this.portal.login(record.credentials.username, record.credentials.password);
            book = await this.portal.grades(record.session);
          }
        } catch (error) {
          if (!(error instanceof PortalError) || error.status !== 401) throw error;
          record.status = 'sign-in-required';
          // Remove credentials immediately if the district rejects them.
          record.credentials.password = ''; record.session.token = '';
          await this.storage.compareSet(recordKey(id), raw, this.encrypt(id, record), Math.max(1, Math.ceil((record.expires - this.now()) / 1000)));
          await this.storage.unschedule(QUEUE, id); continue;
        }
        checked++;
        const delta = newlyGraded(book, record.seen, record.terms);
        // One summary alert bounds APNs runtime even if many scores arrive.
        if (delta.messages.length) {
          if (await this.storage.get(recordKey(id)) !== raw || await this.storage.get('push:revoked:' + hash(id))) continue;
          const body = delta.messages.length === 1 ? delta.messages[0].body : `${delta.messages.length} assignments have new grades. Open Schoolity to view them.`;
          const result = await this.provider.send(record.device, record.environment, hash(delta.messages.map(m => m.id).sort().join('|')), body);
          if (result === 'invalid') {
            await this.storage.compareSet(recordKey(id), raw, null); await this.storage.unschedule(QUEUE, id); continue;
          }
          sent++; record.lastSent = this.now();
        }
        record.seen = delta.seen; record.terms = delta.terms; record.lastChecked = this.now();
        if (await this.storage.compareSet(recordKey(id), raw, this.encrypt(id, record), Math.max(1, Math.ceil((record.expires - this.now()) / 1000))))
          await this.storage.schedule(QUEUE, id, this.now() + 5 * 60 * 1000);
      } catch (error) {
        failed++;
        if (error instanceof PortalError && error.status === 410) {
          await this.storage.delete(recordKey(id)); await this.storage.unschedule(QUEUE, id);
        } else await this.storage.schedule(QUEUE, id, this.now() + 15 * 60 * 1000);
      } finally { await this.storage.compareSet(lock, lease, null); }
      if (this.now() - start > 45000) break;
    }
    return { checked, sent, failed };
  }
}
export const pushService = new PushService();
