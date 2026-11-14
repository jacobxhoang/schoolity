import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseStudentPage } from '../src/lib/server/student-info.ts';
import { studentInformation, studentText } from '../src/lib/records.ts';
import { read, PortalError } from '../src/lib/server/portal.ts';
import { DISTRICT_URL } from '../src/lib/config.ts';

const html = `<div id="MainDiv">
<table class="info_tbl"><tr><td>Student Information</td></tr><tr>
<td><span class="tbl_label">Student Name</span><br>Sample Student</td>
<td><span class="tbl_label">Perm ID</span><br>000123</td>
<td><span class="tbl_label">Home Address</span><br>MN</td>
<td><span class="tbl_label">Nick Name</span><br></td>
<td><span class="tbl_label">Meals Balance</span><br>0.00</td></tr></table>
<table class="info_tbl"><tr><td>IN CASE OF EMERGENCY: Contacts</td></tr>
<tr><td><span class="tbl_label">Name</span><br>Sample Guardian</td><td><span class="tbl_label">Other Phone</span><br>555-0100</td></tr>
<tr><td><span class="tbl_label">Name</span><br>Second Guardian</td><td><span class="tbl_label">Email</span><br></td></tr></table>
<table class="info_tbl"><tr><td>Physician and Dentist Information</td></tr>
<tr><td><span class="tbl_label">Physician Name</span><br>Sample Clinic</td><td><span class="tbl_label">Extension</span><br></td></tr>
<tr><td><span class="tbl_label">Dentist Name</span><br>Sample Dental Office</td><td><span class="tbl_label">Extension</span><br>010</td></tr></table>
<table class="info_tbl"><tr><td>Student Locker</td></tr><tr class="row_subhdr"><td>Locker Number</td><td>Type</td><td>Location</td><td>Vertical Location</td><td>Combination</td></tr>
<tr><td>0012</td><td>Single</td><td>North</td><td>Upper</td><td>01-02-03</td></tr></table>
<table class="info_tbl"><tr><td>Transportation Information</td></tr><tr><td><span class="tbl_label">Bus to School</span><br>007</td><td><span class="tbl_label">Pick Up Bus Company</span><br>Sample Transit</td><td><span class="tbl_label">Activity Bus Stop</span><br>Sample Road<br>Example Town</td><td><span class="tbl_label">Drop Off Effective Date</span><br>11/16/2026</td></tr></table>
<table class="info_tbl"><tr><td>Other Data</td></tr><tr><td><span class="tbl_label">Case Manager</span><br></td></tr></table>
<table class="info_tbl"><tr><td>Activity Screening</td></tr><tr class="row_subhdr"><td>Screen Date</td><td>Screen Type</td><td>Result</td></tr><tr><td colspan="3">No health screen activity information provided</td></tr></table>
</div><script>throw new Error('never execute');</script>`;

test('student values turn raw and encoded HTML breaks into text lines without rendering markup', () => {
  for (const br of ['<br>','<BR />','&lt;br&gt;'])
    assert.equal(studentText(`101 Sample Road${br}Example, MN 00000`),'101 Sample Road\nExample, MN 00000');
  assert.equal(studentText('<p>A &amp; B</p><script>doNotExecute()</script><p>Second line</p>'),'A & B\nSecond line');
  assert.equal(studentText(0),'0');
});

test('StudentVUE page mapping preserves every information section and missing fields', () => {
  const sections = parseStudentPage(html);
  assert.equal(sections.length,7);
  assert.equal(sections[0].fields.find(f=>f.label==='Nick Name')?.value,'');
  assert.equal(sections[0].fields.find(f=>f.label==='Meals Balance')?.value,'0.00');
  assert.equal(sections[1].groups?.length,2);
  assert.equal(sections[1].groups?.[0].fields[1].label,'Other Phone');
  assert.deepEqual(sections[2].groups?.map(g=>g.title),['Physician','Dentist']);
  assert.equal(sections[3].table?.rows[0][0],'0012');
  assert.equal(sections[3].table?.rows[0][4],'01-02-03');
  assert.equal(sections[4].fields.find(f=>f.label==='Bus to School')?.value,'007');
  assert.equal(sections[4].fields.find(f=>f.label==='Activity Bus Stop')?.value,'Sample Road\nExample Town');
  assert.equal(sections[5].fields[0].label,'Case Manager');
  assert.match(sections[6].note!,/No health screen/);
  assert.equal(sections[6].table,undefined);
});

test('complete web sections retain the fuller mobile address without mutating the response', () => {
  const studentSections = parseStudentPage(html);
  const result = studentInformation({studentInfo:{permID:'000123',homeAddress:'101 Sample Road<br>Example, MN 00000'},studentSections});
  assert.equal(result.sections.length,7);
  assert.equal(result.sections[0].fields.find(f=>f.label==='Home Address')?.value,'101 Sample Road\nExample, MN 00000');
  assert.equal(studentSections[0].fields.find(f=>f.label==='Home Address')?.value,'MN');
});

test('student page errors remain explicit rather than appearing as complete empty information', async () => {
  assert.throws(()=>parseStudentPage('<input type="password">'),(e:unknown)=>e instanceof Error&&'status' in e&&e.status===401);
  assert.throws(()=>parseStudentPage('<div id="MainDiv"></div>'),/No readable/);
  const session={base:DISTRICT_URL,token:'synthetic',expires:Date.now()+10000};
  const send = async () => ({data:{studentInfoXML:{formattedName:'Sample Student'}}});
  const partial=studentInformation(await read(session,'student',undefined,send));
  assert.match(partial.notice!,/Sign in again/);
  const complete=studentInformation(await read({...session,webCookie:'ASP.NET_SessionId=fixture'},'student',undefined,send,async (base,path,headers)=>{
    assert.equal(base,DISTRICT_URL); assert.equal(path,'/PXP2_Student.aspx?AGU=0'); assert.equal(headers.Cookie,'ASP.NET_SessionId=fixture');
    return {text:html,cookie:''};
  }));
  assert.equal(complete.sections.length,7);
  const retry=studentInformation(await read({...session,webCookie:'fixture'},'student',undefined,send,async()=>{throw new Error('Unavailable');}));
  assert.match(retry.notice!,/could not be loaded/);
  await assert.rejects(read({...session,webCookie:'fixture'},'student',undefined,send,async()=>({text:'<input type="password">',cookie:''})),(e:unknown)=>e instanceof PortalError&&e.status===401);
});
