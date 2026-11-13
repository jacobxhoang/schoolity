import { request as httpsRequest } from 'node:https';
import { lookup } from 'node:dns/promises';
import { store } from './store.ts';
import { sessionLifetime } from './session-policy.ts';
import { randomBytes, createHash } from 'node:crypto';
import { BlockList } from 'node:net';
import { object, profilePayload, string } from '../portal-data.ts';
export class PortalError extends Error {
  status: number;
  constructor(message: string, status = 502) {
    super(message);
    this.status = status;
  }
}
export function districtAddress(raw: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(raw.includes('://') ? raw : `https://${raw}`);
  } catch {
    throw new PortalError('Enter a valid district portal address.', 400);
  }
  if (
    parsed.protocol !== 'https:' ||
    parsed.username ||
    parsed.password ||
    parsed.port
  )
    throw new PortalError(
      'Use an HTTPS district address without a custom port.',
      400,
    );
  if (
    !/^(?:[a-z\d-]+\.)+[a-z]{2,}$/i.test(parsed.hostname) ||
    /\.(local|localhost|internal)$/i.test(parsed.hostname)
  )
    throw new PortalError('Enter your public district portal address.', 400);
  let prefix = parsed.pathname
    .replace(/\/[^/]+\.aspx$/i, '')
    .replace(/\/$/, '');
  if (!/^(\/[\w-]+)*$/.test(prefix))
    throw new PortalError('The portal address has an unsupported path.', 400);
  if (parsed.hostname === 'sisstudent.fcps.edu' && !prefix) prefix = '/SVUE';
  parsed.pathname = prefix;
  parsed.search = '';
  parsed.hash = '';
  return parsed;
}
const privateNetworks = new BlockList();
for (const [address, prefix] of [
  ['0.0.0.0', 8],
  ['10.0.0.0', 8],
  ['100.64.0.0', 10],
  ['127.0.0.0', 8],
  ['169.254.0.0', 16],
  ['172.16.0.0', 12],
  ['192.168.0.0', 16],
  ['192.0.0.0', 24],
  ['192.0.2.0', 24],
  ['198.18.0.0', 15],
  ['198.51.100.0', 24],
  ['203.0.113.0', 24],
  ['224.0.0.0', 3],
] as const)
  privateNetworks.addSubnet(address, prefix, 'ipv4');
const globalV6 = new BlockList();
globalV6.addSubnet('2000::', 3, 'ipv6');
privateNetworks.addSubnet('2001::', 23, 'ipv6');
privateNetworks.addSubnet('2001:db8::', 32, 'ipv6');
privateNetworks.addSubnet('2002::', 16, 'ipv6');
export function publicAddress(address: string): boolean {
  return address.includes(':')
    ? globalV6.check(address, 'ipv6') && !privateNetworks.check(address, 'ipv6')
    : !privateNetworks.check(address, 'ipv4');
}
export async function exchange(
  base: string,
  method: string,
  authorization: string,
  parameters: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const destination = new URL(
    `${base.replace(/\/$/, '')}/api/v1/mobile/PXPWebServices/${method}`,
  );
  const resolved = await lookup(destination.hostname, { all: true });
  if (!resolved.length || resolved.some((r) => !publicAddress(r.address)))
    throw new PortalError(
      'The district address must resolve to a public server.',
      400,
    );
  const selected = resolved[0];
  return new Promise((resolve, reject) => {
    const outgoing = httpsRequest(
      destination,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          Authorization: authorization,
        },
        lookup: (_host, opts, cb) =>
          opts.all
            ? cb(null, [selected])
            : cb(null, selected.address, selected.family),
      },
      (incoming) => {
        if (incoming.statusCode !== 200) {
          incoming.resume();
          reject(
            new PortalError(
              incoming.statusCode === 401 || incoming.statusCode === 403
                ? 'Your district rejected the login. Check your portal address and credentials.'
                : `The district returned HTTP ${incoming.statusCode}.`,
              incoming.statusCode === 401 || incoming.statusCode === 403
                ? 401
                : 502,
            ),
          );
          return;
        }
        let size = 0;
        const pieces: Buffer[] = [];
        incoming.on('data', (b: Buffer) => {
          size += b.length;
          if (size > 12_000_000)
            outgoing.destroy(
              new PortalError('The district response exceeded the size limit.'),
            );
          else pieces.push(b);
        });
        incoming.on('error', reject);
        incoming.on('end', () => {
          try {
            resolve(object(JSON.parse(Buffer.concat(pieces).toString('utf8'))));
          } catch {
            reject(
              new PortalError('Your district sent an unreadable response.'),
            );
          }
        });
      },
    );
    const timer = setTimeout(
      () =>
        outgoing.destroy(
          new PortalError('Your district took too long to respond.', 504),
        ),
      15_000,
    );
    outgoing.on('close', () => clearTimeout(timer));
    outgoing.on('error', reject);
    outgoing.end(
      JSON.stringify({ arguments: { request: JSON.stringify(parameters) } }),
    );
  });
}
export interface Session {
  base: string;
  token: string;
  expires: number;
}
export async function findSession(
  id: string | undefined,
): Promise<Session | undefined> {
  if (!id || !/^[A-Za-z0-9_-]{43}$/.test(id)) return undefined;
  try {
    const raw = await store.get('session:' + id);
    if (!raw) return undefined;
    const entry = JSON.parse(raw) as Session;
    if (entry.expires > Date.now()) return entry;
    await store.delete('session:' + id);
    return undefined;
  } catch {
    throw new PortalError('Session storage is unavailable. Try again.', 503);
  }
}
export async function endSession(id: string | undefined): Promise<void> {
  if (id && /^[A-Za-z0-9_-]{43}$/.test(id)) await store.delete('session:' + id);
}
export async function limitLogin(ip: string) {
  try {
    const count = await store.increment(
      'login:' + createHash('sha256').update(ip).digest('hex'),
      600,
    );
    if (count > 10)
      throw new PortalError(
        'Too many login attempts. Try again in ten minutes.',
        429,
      );
  } catch (e) {
    if (e instanceof PortalError) throw e;
    throw new PortalError(
      'Sign-in storage is unavailable. Configure shared storage and try again.',
      503,
    );
  }
}
export async function signIn(
  district: string,
  username: string,
  password: string,
  send = exchange,
): Promise<{ id: string; maxAge: number }> {
  const base = districtAddress(district).href.replace(/\/$/, '');
  const auth = Buffer.from(`${username}:${password}`).toString('base64');
  const result = await send(base, 'AttemptLogin', `Basic ${auth}`, {
    userID: null,
    password: null,
    userType: 'Student',
    DeviceModel: 'Schoolity web',
    LoginClientData: `POST:/api/v1/mobile/PXPWebServices/AttemptLogin:${Date.now()}:${randomBytes(12).toString('hex')}`,
  });
  if (typeof result.access_token !== 'string' || !result.access_token)
    throw new PortalError(
      'Login was not accepted. Check your district and credentials.',
      401,
    );
  const id = randomBytes(32).toString('base64url');
  const maxAge = sessionLifetime(result.expires_in);
  const entry: Session = {
    base,
    token: result.access_token,
    expires: Date.now() + maxAge * 1000,
  };
  await store.set('session:' + id, JSON.stringify(entry), maxAge);
  return { id, maxAge };
}
export async function read(
  session: Session,
  resource: string,
  term: unknown,
): Promise<unknown> {
  const methods: Record<string, [string, Record<string, unknown>, string[]]> = {
    grades: [
      'Gradebook',
      {
        concurrentSchOrgYearGU: '',
        ...(term === undefined
          ? {}
          : { ReportPeriod: term, reportPeriod: term }),
      },
      ['traditionalGradebook'],
    ],
    profile: [
      'GetStudentInfoData',
      {},
      ['studentInfoDetailXML', 'studentInfoXML'],
    ],
    schedule: [
      'StudentClassList',
      {
        loadAllTerms: false,
        conSchOrgYearGU: '',
        conSchTermIndex: '-1',
        termIndex: '-1',
      },
      ['studentClassSchedule'],
    ],
    documents: ['GetStudentDocuments', {}, ['studentDocuments']],
    mail: [
      'GetSynergyMailMessage',
      { folderGU: 'Inbox', loadMessageBody: 'true', skip: '0', take: '50' },
      ['synergyMailDataXML'],
    ],
  };
  const spec = methods[resource];
  if (!spec) throw new PortalError('That resource is not available.', 404);
  if (
    term !== undefined &&
    (!Number.isInteger(term) || Number(term) < 0 || Number(term) > 100)
  )
    throw new PortalError('Invalid reporting period.', 400);
  const response = await exchange(
    session.base,
    spec[0],
    `Bearer ${session.token}`,
    { childIntID: 0, languageCode: '1', ...spec[1] },
  );
  if (response.error) {
    const e = object(response.error);
    if (string(e.code) === '2100') return {};
    throw new PortalError(
      `The district could not load this information${e.code ? ` (code ${string(e.code)})` : ''}.`,
    );
  }
  if (!('data' in response))
    throw new PortalError('The district returned an unexpected response.');
  const data = object(response.data);
  if (resource === 'profile') return profilePayload(data);
  for (const key of spec[2]) if (data[key] != null) return data[key];
  return data;
}
