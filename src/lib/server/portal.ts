import { request as httpsRequest } from 'node:https';
import { lookup } from 'node:dns/promises';
import { store } from './store.ts';
import { sessionLifetime } from './session-policy.ts';
import { randomBytes, createHash } from 'node:crypto';
import { BlockList } from 'node:net';
import { object, profilePayload, string } from '../portal-data.ts';
import { DISTRICT_URL } from '../config.ts';
import { parseHistoryOverview, parseSubjectDetails } from './history.ts';
import { parseStudentPage } from './student-info.ts';
export class PortalError extends Error {
  status: number;
  constructor(message: string, status = 502) {
    super(message);
    this.status = status;
  }
}

// StudentVUE's browser cookie is separate from the mobile API token. A
// browser-only failure must not tell clients to discard the whole login.
function historyFailure(error: unknown): PortalError {
  if (error instanceof Error && 'status' in error && error.status === 401)
    return new PortalError('Course history needs to reconnect to StudentVUE. Your other pages are still available. Try refreshing later.', 502);
  return error instanceof PortalError ? error : new PortalError(
    error instanceof Error ? error.message : 'Could not read course history. Try again.');
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
  captureCookies?: (cookie: string) => void,
): Promise<Record<string, unknown>> {
  const result = await districtRequest(base, `/api/v1/mobile/PXPWebServices/${method}`, {
    Authorization: authorization,
  }, JSON.stringify({ arguments: { request: JSON.stringify(parameters) } }));
  try {
    const data = object(JSON.parse(result.text));
    if (result.cookie) captureCookies?.(result.cookie);
    return data;
  } catch {
    throw new PortalError('Your district sent an unreadable response.');
  }
}
export function cookieHeader(values: string[]): string {
  return values.map((value) => value.split(';', 1)[0])
    .filter((value) => /^[!#$%&'*+.^_`|~\w-]+=[^\s;,\x00-\x1f\x7f]*$/.test(value))
    .join('; ').slice(0, 8192);
}
export async function districtRequest(
  base: string,
  path: string,
  headers: Record<string, string>,
  body?: string,
): Promise<{ text: string; cookie: string }> {
  const destination = new URL(path, base);
  if (destination.origin !== DISTRICT_URL || !path.startsWith('/'))
    throw new PortalError('Unsupported district address.', 400);
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
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: body === undefined ? 'text/html' : 'application/json',
          ...headers,
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
              incoming.statusCode === 401 || incoming.statusCode === 403 || incoming.statusCode === 302
                ? 'Your district rejected the login. Check your username and password.'
                : `The district returned HTTP ${incoming.statusCode}.`,
              incoming.statusCode === 401 || incoming.statusCode === 403 || incoming.statusCode === 302
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
          resolve({ text: Buffer.concat(pieces).toString('utf8'),
            cookie: cookieHeader(incoming.headers['set-cookie'] ?? []) });
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
    outgoing.end(body);
  });
}
export interface Session {
  base: string;
  token: string;
  expires: number;
  rememberKey?: string;
  webCookie?: string;
}
export async function findSession(
  id: string | undefined,
): Promise<Session | undefined> {
  if (!id || !/^[A-Za-z0-9_-]{43}$/.test(id)) return undefined;
  try {
    const raw = await store.get('session:' + id);
    if (!raw) return undefined;
    const entry = JSON.parse(raw) as Session;
    if (entry.expires > Date.now()) {
      if (!entry.rememberKey) return entry;
      if (/^remember:[a-f0-9]{64}$/.test(entry.rememberKey) && await store.get(entry.rememberKey)) return entry;
    }
    await store.delete('session:' + id);
    return undefined;
  } catch {
    throw new PortalError('Session storage is unavailable. Try again.', 503);
  }
}
export async function bindRememberedSession(id: string, rememberKey: string): Promise<void> {
  const session = await findSession(id);
  if (!session || !/^remember:[a-f0-9]{64}$/.test(rememberKey))
    throw new PortalError('Your session has ended. Sign in again.', 401);
  await store.set('session:' + id, JSON.stringify({ ...session, rememberKey }),
    Math.max(1, Math.ceil((session.expires - Date.now()) / 1000)));
}
export async function endSession(id: string | undefined): Promise<void> {
  if (id && /^[A-Za-z0-9_-]{43}$/.test(id)) await store.delete('session:' + id);
}
export async function limitLogin(scope: 'login' | 'renew', key: string) {
  try {
    const count = await store.increment(
      `limit:${scope}:` + createHash('sha256').update(key).digest('hex'),
      600,
    );
    if (count > 10)
      throw new PortalError(
        'Too many sign-in attempts. Try again in ten minutes.',
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
  username: string,
  password: string,
  send = exchange,
): Promise<{ id: string; maxAge: number }> {
  const base = DISTRICT_URL;
  const auth = Buffer.from(`${username}:${password}`).toString('base64');
  let webCookie: string | undefined;
  const result = await send(base, 'AttemptLogin', `Basic ${auth}`, {
    userID: null,
    password: null,
    userType: 'Student',
    DeviceModel: 'Schoolity web',
    LoginClientData: `POST:/api/v1/mobile/PXPWebServices/AttemptLogin:${Date.now()}:${randomBytes(12).toString('hex')}`,
  }, (cookie) => { webCookie = cookie; });
  if (typeof result.access_token !== 'string' || !result.access_token)
    throw new PortalError(
      'Login was not accepted. Check your username and password.',
      401,
    );
  const id = randomBytes(32).toString('base64url');
  const maxAge = sessionLifetime(result.expires_in);
  const entry: Session = {
    base,
    token: result.access_token,
    expires: Date.now() + maxAge * 1000,
    ...(webCookie ? { webCookie } : {}),
  };
  await store.set('session:' + id, JSON.stringify(entry), maxAge);
  return { id, maxAge };
}
const HISTORY_CACHE_SECONDS = 120;
type HistoryOverview = ReturnType<typeof parseHistoryOverview>;

// The cache is a short-lived, session-scoped copy of the student's own
// course-history overview; the key is a one-way hash of the district token.
function historyCacheKey(session: Session): string {
  return 'history:v1:' + createHash('sha256').update(session.token).digest('hex');
}

async function courseHistoryOverview(
  session: Session,
  page: typeof districtRequest,
): Promise<HistoryOverview> {
  if (!session.webCookie)
    throw new PortalError('Missing district web session.', 401);
  const response = await page(session.base, '/PXP2_CourseHistory.aspx?AGU=0', {
    Cookie: session.webCookie,
  });
  const overview = parseHistoryOverview(response.text);
  try {
    await store.set(
      historyCacheKey(session),
      JSON.stringify(overview),
      HISTORY_CACHE_SECONDS,
    );
  } catch {
    // Caching is an optimisation; the fresh overview is still returned.
  }
  return overview;
}

// Requirement identifiers are validated against this overview before any
// subject detail is requested. Reusing a just-loaded copy keeps a workspace
// preload from downloading the district page once per subject area.
async function cachedCourseHistoryOverview(
  session: Session,
  page: typeof districtRequest,
): Promise<HistoryOverview> {
  try {
    const raw = await store.get(historyCacheKey(session));
    if (raw) {
      const cached = JSON.parse(raw) as HistoryOverview;
      if (
        Array.isArray(cached?.graduationRequirements) &&
        Array.isArray(cached?.courseHistory)
      )
        return cached;
    }
  } catch {
    // Fall through to the district when the store is unavailable.
  }
  return await courseHistoryOverview(session, page);
}

export async function read(
  session: Session,
  resource: string,
  term: unknown,
  send = exchange,
  page = districtRequest,
): Promise<unknown> {
  if (resource === 'history') {
    try {
      return await courseHistoryOverview(session, page);
    } catch (error) { throw historyFailure(error); }
  }
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
    student: ['GetStudentInfoData', {}, ['studentInfoDetailXML', 'studentInfoXML']],
    attendance: ['Attendance', {}, ['attendance']],
    schedule: [
      'StudentClassList',
      {
        loadAllTerms: true,
        conSchOrgYearGU: '',
        conSchTermIndex: '-1',
        termIndex: '-1',
      },
      ['studentClassScheduleForAllTerms', 'studentClassSchedule'],
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
  const response = await send(
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
  if (resource === 'student') {
    const studentInfo = profilePayload(data);
    if (!session.webCookie) return {studentInfo, studentInfoNotice:'Sign in again to load all StudentVUE information, including contacts, lockers, and transportation.'};
    try {
      const response = await page(session.base, '/PXP2_Student.aspx?AGU=0', {Cookie:session.webCookie});
      return {studentInfo, studentSections:parseStudentPage(response.text)};
    } catch (error) {
      if (error instanceof Error && 'status' in error && error.status === 401)
        return {studentInfo, studentInfoNotice:'Your additional StudentVUE information needs to reconnect. Your available student details are shown below. Sign out and sign in again to load contacts, lockers, and transportation.'};
      return {studentInfo, studentInfoNotice:'Additional StudentVUE information could not be loaded. Refresh to try again.'};
    }
  }
  for (const [index, key] of spec[2].entries()) {
    const value = data[key];
    if (value == null) continue;
    const empty =
      typeof value === 'object' &&
      !Array.isArray(value) &&
      Object.keys(value as Record<string, unknown>).length === 0;
    // Prefer a populated all-term schedule over an empty wrapper, while
    // preserving the existing empty-response contract for other resources.
    if (empty && index < spec[2].length - 1) continue;
    return value;
  }
  return data;
}

export async function readHistorySubject(session: Session, subject: unknown, page = districtRequest) {
  if (typeof subject !== 'string' || !/^[A-Za-z0-9_-]{1,100}$/.test(subject))
    throw new PortalError('Choose a subject area.', 400);
  try {
    if (!session.webCookie) throw new PortalError('Missing district web session.', 401);
    const overview = await cachedCourseHistoryOverview(session, page);
    const own = overview.graduationRequirements.find(requirement => requirement.id === subject);
    if (!own) throw new PortalError('This subject area is not available for your account. Refresh course history.', 404);
    const response = await page(session.base, '/service/PXP2Communication.asmx/GetCourseHistoryDetails', {
      Cookie: session.webCookie, AGU: '0', Origin: DISTRICT_URL,
    }, JSON.stringify({ agu: '0', itemGU: own.id }));
    const envelope = object(object(JSON.parse(response.text)).d);
    if (envelope.Error) {
      if (object(envelope.Error).Message === 'INVALID_CONTEXT')
        throw new PortalError('Your district web session ended. Sign in again.', 401);
      throw new PortalError('The district could not load these subject classes. Try again.');
    }
    return parseSubjectDetails(envelope.Data);
  } catch (error) { throw historyFailure(error); }
}
