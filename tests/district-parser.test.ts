import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { invoke } from '../ios/Parser/district.ts';

test('the shipped iOS parser is self-contained and matches the source parser', () => {
  const context: Record<string, any> = {};
  runInNewContext(readFileSync(new URL('../ios/Schoolity/Resources/DistrictParser.js', import.meta.url), 'utf8'), context);
  for (const [operation, arguments_] of [
    ['normalize', {resource:'grades',payload:{reportingPeriod:{index:0},courses:[{courseID:'math',courseName:'Math &amp; Science',marks:[]}]}}],
    ['normalize', {resource:'profile',payload:{formattedName:'Sample Student',permID:'000123'}}],
    ['normalize', {resource:'attendance',payload:{absences:[]}}],
    ['payload', {resource:'attendance',response:{data:{dailyAttendance:{entries:[]},periodAttendance:{entries:[]}}}}],
    ['normalize', {resource:'attendance',payload:{dailyAttendance:[],periodAttendance:[{attendanceDate:'11/03/2026',periodNumber:'1',status:'Excused'}]}}],
    ['history', {html:'<script>throw new Error("never run");PXP.CourseHistory=[];</script>'}],
    ['subject', {text:JSON.stringify({d:{Data:{Columns:{Term:'Term',Mark:'Mark'},Rows:[{Term:'2025 - T1',Mark:'A'}]}}})}],
    ['download', {mail:false,response:{data:{studentAttachedDocumentData:{documentDatas:[{base64Code:'aGVsbG8='}]}}}}],
    ['download', {mail:true,response:{data:{attachmentXML:'<Base64Code>aGVsbG8=</Base64Code>'}}}],
    ['download', {mail:true,response:{data:{attachmentXML:'<!ENTITY x SYSTEM "file:///private">'}}}],
  ] as const) {
    const input = JSON.stringify(arguments_);
    assert.equal(context.DistrictParser.invoke(operation, input), invoke(operation, input));
  }
});
