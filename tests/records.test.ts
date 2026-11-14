import { test } from 'node:test';
import assert from 'node:assert/strict';
import { studentInformation, attendance, courseHistory } from '../src/lib/records.ts';
import { parseHistoryPage, parseHistoryOverview, parseSubjectDetails } from '../src/lib/server/history.ts';
import { cookieHeader, districtRequest, read, readHistorySubject, signIn, findSession, endSession, PortalError } from '../src/lib/server/portal.ts';
import { DISTRICT_URL } from '../src/lib/config.ts';
import { randomUUID } from 'node:crypto';

const history = [{ Grade: '09', Terms: [{ SchoolName: 'Sample School', Year: '2025', TermName: 'T1', Courses: [
  { CourseID: 'math', CourseTitle: 'Math &amp; Science', Mark: 'P', CreditsAttempted: '0.5', CreditsCompleted: '0' },
  { CourseID: 'math', CourseTitle: 'Math continued', Mark: 'A', CreditsCompleted: '0.5' },
] }] }];

test('student info preserves district ID and only displays supplied scalar fields', () => {
  const result = studentInformation({ studentInfoXML: { permID: '000123', formattedName: 'Sample &amp; Student' },
    studentInfoDetailXML: { permID: '', grade: '11', schoolName: 'Sample School', emergencyContacts: [{ name: 'Sample Contact', relationship: 'Guardian' }] } });
  assert.equal(result.sections[0].fields.find(f => f.label === 'Student ID')?.value, '000123');
  assert.equal(result.sections[0].fields[0].value, 'Sample & Student');
  assert.ok(result.sections.some(s => s.title === 'Emergency contact 1'));
  assert.deepEqual(studentInformation({}).sections, []);
  assert.deepEqual(studentInformation({ permID: Number.MAX_SAFE_INTEGER + 1 }).sections, []);
});

test('history keeps passing marks, zero credits and duplicate course IDs in distinct rows', () => {
  const result = courseHistory(history);
  assert.equal(result.courses.length, 2);
  assert.equal(result.courses[0].title, 'Math & Science');
  assert.equal(result.courses[0].mark, 'P');
  assert.equal(result.courses[0].completed, 0);
  assert.equal(result.courses[1].attempted, null);
  assert.notEqual(result.courses[0].id, result.courses[1].id);
  assert.deepEqual(courseHistory([]).courses, []);
  assert.throws(() => courseHistory({}), /unsupported/);
  assert.throws(() => courseHistory([{ wrong: true }]), /No readable courses/);
});

test('history parser reads balanced JSON without executing page code', () => {
  const data = [{ Grade: '10', Terms: [], note: 'a ]; string with \\"quotes"' }];
  assert.deepEqual(parseHistoryPage(`<script>PXP.CourseHistory = ${JSON.stringify(data)}; throw new Error('do not execute');</script>`), data);
  assert.deepEqual(parseHistoryPage('<script>PXP.CourseHistory = [];</script>'), []);
  assert.throws(() => parseHistoryPage('<script>PXP.CourseHistory = [runCode()];</script>'));
  assert.throws(() => parseHistoryPage('<script>PXP.CourseHistory = [{</script>'), /unreadable/);
  assert.throws(() => parseHistoryPage('<input type="password">'), (e: unknown) => e instanceof Error && 'status' in e && e.status === 401);
  assert.throws(() => parseHistoryPage('<a href="PXP2_Login_Student.aspx?Logout=1">Logout</a>'), /supported course history/);
});

test('attendance maps daily and period reasons, newest dates first, without inventing totals', () => {
  const result = attendance({ absences: [
    { absenceDate: '10/01/2026', reason: 'Appointment', periods: [{ number: 1, name: 'Excused', course: 'Math', staff: 'Sample Teacher' }] },
    { absenceDate: '11/01/2026', reason: 'Activity', periods: [] },
  ], totalExcused: [{ number: 1, total: 0 }, { number: 2, total: 2 }] });
  assert.equal(result.days[0].date, '11/01/2026');
  assert.equal(result.days[1].periods[0].status, 'Excused');
  assert.deepEqual(result.totals, [{ label: 'Excused periods', value: 2 }]);
  assert.deepEqual(attendance({}).totals, []);
  assert.throws(() => attendance({ unexpected: true }), /unsupported attendance/);
});

test('attendance accepts singleton legacy periods and preserves zero totals', () => {
  const result = attendance({ Attendance: { Absences: { Absence: { _AbsenceDate: '10/01/2026', _Reason: 'Excused', Periods: { Period: { _Number: '01', _Name: 'Excused' } } } },
    TotalExcused: { PeriodTotal: { _Number: '01', _Total: '0' } } } });
  assert.equal(result.days[0].periods[0].period, '01');
  assert.equal(result.totals[0].value, 0);
});

test('new district resources use the fixed read methods and history needs server-side cookies', async () => {
  const session = { base: DISTRICT_URL, token: 'synthetic', expires: Date.now() + 10000 };
  for (const [resource, method] of [['student', 'GetStudentInfoData'], ['attendance', 'Attendance']]) {
    await read(session, resource, undefined, async (_base, selected, auth, params) => {
      assert.equal(selected, method);
      assert.equal(auth, 'Bearer synthetic');
      assert.equal(params.childIntID, 0);
      return { data: {} };
    });
  }
  await assert.rejects(read(session, 'history', undefined), (e: unknown) => e instanceof PortalError && e.status === 502);
  assert.deepEqual(await read({ ...session, webCookie: 'ASP.NET_SessionId=synthetic' }, 'history', undefined, undefined,
    async (base, path, headers) => {
      assert.equal(base, DISTRICT_URL);
      assert.equal(path, '/PXP2_CourseHistory.aspx?AGU=0');
      assert.equal(headers.Cookie, 'ASP.NET_SessionId=synthetic');
      return { text: `PXP.CourseHistory = ${JSON.stringify(history)};`, cookie: '' };
    }), { courseHistory: history, graduationRequirements: [], classOf: '' });
  await assert.rejects(districtRequest('https://other.example', '/page', {}), /Unsupported district/);
});

test('history login pages and HTTP rejections are feature errors, while mobile authentication still expires', async () => {
  const session = { base: DISTRICT_URL, token: 'synthetic-' + randomUUID(), webCookie: 'expired', expires: Date.now() + 10000 };
  for (const page of [
    async () => ({ text: '<input type="password">', cookie: '' }),
    async () => { throw new PortalError('District web login expired', 401); },
  ]) {
    for (const request of [
      () => read(session, 'history', undefined, undefined, page),
      () => readHistorySubject(session, 'math', page),
    ]) await assert.rejects(request(), (e: unknown) => e instanceof PortalError && e.status === 502 && /other pages are still available/.test(e.message));
  }
  await assert.rejects(read(session, 'grades', undefined, async () => {
    throw new PortalError('Mobile token expired', 401);
  }), (e: unknown) => e instanceof PortalError && e.status === 401);
});

test('graduation progress reads district subject totals and preserves missing values', () => {
  const html = `<h1>Graduation Status <span>Class of 2028</span></h1>
    <section class="pxp-summary"><div class="details"><table><tbody>
      <tr data-guid="english"><td>English &amp; Language</td><td>4.00</td><td>2.00</td><td>1.00</td><td>1.00</td></tr>
      <tr data-guid="arts"><td>Arts</td><td>1.00</td><td>0.00</td><td></td><td>1.00</td></tr>
    </tbody></table></div></section><script>PXP.CourseHistory = [];</script>`;
  const result = parseHistoryOverview(html);
  assert.equal(result.classOf, '2028');
  assert.equal(result.graduationRequirements.length, 2);
  assert.deepEqual(result.graduationRequirements[0], {id:'english',subject:'English & Language',required:4,completed:2,inProgress:1,remaining:1});
  assert.equal(result.graduationRequirements[1].completed, 0);
  assert.equal(result.graduationRequirements[1].inProgress, null);
  const mapped = courseHistory(result);
  assert.equal(mapped.requirements[0].required, 4);
  assert.equal(mapped.classOf, '2028');
  assert.deepEqual(courseHistory([]).requirements, []);
});

const subjectColumns = { Term:'Term', CourseTitle:'Course Title (ID)', Mark:'Mark', Attempted:'Credit Attempted', Completed:'Credit Completed' };
test('subject detail separates finalized and pending classes and strips cell markup', () => {
  const result = parseSubjectDetails({ Columns:subjectColumns, Rows:[
    {Term:'2025 - T1',CourseTitle:'<b>Literature &amp; Composition</b><script>bad()</script>',Mark:'F',Attempted:'0.5',Completed:'0'},
    {Term:'2026 - T1',CourseTitle:'Current English',Mark:'',Attempted:'0.5',Completed:''},
    {Term:'2025 - T2',CourseTitle:'English by assessment',Mark:'P',Attempted:'0.5',Completed:'0.5'},
  ] });
  assert.equal(result.completed.length,2);
  assert.equal(result.inProgress.length,1);
  assert.equal(result.completed[0][1],'Literature & Composition');
  assert.equal(result.completed[0][4],'0');
  assert.deepEqual(parseSubjectDetails({Columns:subjectColumns,Rows:[]}).completed,[]);
  assert.throws(() => parseSubjectDetails({Columns:{Name:'Course'},Rows:[]}), /did not identify/);
  assert.throws(() => parseSubjectDetails({Columns:subjectColumns,Rows:[{}]}), /unreadable/);
  assert.equal(parseSubjectDetails({Columns:['Term','Course','Mark'],Rows:[['2025','Sample','A']]}).completed.length,1);
});

test('subject requests verify membership before the dedicated district detail call', async () => {
  const session = {base:DISTRICT_URL,token:'synthetic-'+randomUUID(),webCookie:'ASP.NET_SessionId=fixture',expires:Date.now()+10000};
  let calls = 0;
  const page = async (_base: string, path: string, headers: Record<string,string>, body?: string) => {
    calls++;
    assert.equal(headers.Cookie,session.webCookie);
    if (body === undefined) return {text:'<section class="pxp-summary"><div class="details"><table><tr data-guid="E09"><td>English</td><td>1</td><td>0.5</td><td>0.5</td><td>0</td></tr></table></div></section><script>PXP.CourseHistory=[];</script>',cookie:''};
    assert.equal(path,'/service/PXP2Communication.asmx/GetCourseHistoryDetails');
    assert.deepEqual(JSON.parse(body),{agu:'0',itemGU:'E09'});
    assert.equal(headers.AGU,'0');
    return {text:JSON.stringify({d:{Data:{Columns:subjectColumns,Rows:[]}}}),cookie:''};
  };
  assert.deepEqual((await readHistorySubject(session,'E09',page)).inProgress,[]);
  assert.equal(calls,2);
  calls=0;
  await assert.rejects(readHistorySubject(session,'ANOTHER_SUBJECT',page), (e: unknown)=>e instanceof PortalError&&e.status===404);
  // Membership is still checked, and the overview is reused, so this costs no district request.
  assert.equal(calls,0);
  await assert.rejects(readHistorySubject(session,'../other',page), (e: unknown)=>e instanceof PortalError&&e.status===400);
  await assert.rejects(readHistorySubject({...session,webCookie:undefined},'E09',page), (e: unknown)=>e instanceof PortalError&&e.status===502);
  await assert.rejects(readHistorySubject(session,'E09',async (base,path,headers,body) => body === undefined
    ? page(base,path,headers,body)
    : {text:JSON.stringify({d:{Error:{Message:'INVALID_CONTEXT'}}}),cookie:''}),
    (e: unknown)=>e instanceof PortalError&&e.status===502);
});

test('login stores district cookies only in the server session and strips cookie attributes', async () => {
  assert.equal(cookieHeader(['ASP.NET_SessionId=fixture; HttpOnly; Path=/', 'bad=evil\r\nInjected: yes', 'other=value; Secure']), 'ASP.NET_SessionId=fixture; other=value');
  const result = await signIn('synthetic', 'synthetic-password', async (_base, _method, _auth, _params, capture) => {
    capture?.('ASP.NET_SessionId=fixture');
    return { access_token: 'synthetic-token', expires_in: 60 };
  });
  try {
    assert.equal((await findSession(result.id))?.webCookie, 'ASP.NET_SessionId=fixture');
    assert.ok(!JSON.stringify(result).includes('ASP.NET'));
  } finally { await endSession(result.id); }
});
