// Bundled locally for JavaScriptCore. No network, DOM, eval, or server imports.
import { nativeData, object, profilePayload, schedule } from '../../src/lib/portal-data.ts';
import { readRecords } from '../../src/lib/records.ts';
import { parseHistoryOverview, parseSubjectDetails } from '../../src/lib/server/history.ts';
import { parseStudentPage } from '../../src/lib/server/student-info.ts';

export function invoke(operation: string, input: string): string {
  try {
    const args = JSON.parse(input);
    let data: unknown;
    switch (operation) {
      case 'normalize': {
        const { resource, payload } = args;
        data = resource === 'schedule-terms' ? schedule(payload)
          : ['student', 'history', 'attendance'].includes(resource) ? readRecords(resource, payload)
          : nativeData(payload, resource);
        break;
      }
      case 'payload': {
        const response = object(args.response);
        if (response.error) {
          if (String(object(response.error).code) === '2100') { data = {}; break; }
          throw new Error('The district could not load this information. Try again.');
        }
        if (!('data' in response)) throw new Error('The district returned an unexpected response.');
        const raw = object(response.data);
        const keys: Record<string, string[]> = {
          grades: ['traditionalGradebook'], profile: [], student: [], attendance: ['attendance'],
          'schedule-terms': ['studentClassScheduleForAllTerms', 'studentClassSchedule'],
          documents: ['studentDocuments'], mail: ['synergyMailDataXML'],
        };
        if (args.resource === 'profile' || args.resource === 'student') data = profilePayload(raw);
        else {
          data = raw;
          for (const key of keys[args.resource] ?? []) {
            if (raw[key] == null) continue;
            if (args.resource === 'schedule-terms' && !Object.keys(object(raw[key])).length && !Array.isArray(raw[key])) continue;
            data = raw[key]; break;
          }
        }
        break;
      }
      case 'history': data = parseHistoryOverview(args.html); break;
      case 'student': data = { studentInfo: args.profile, studentSections: parseStudentPage(args.html) }; break;
      case 'subject': {
        const envelope = object(object(JSON.parse(args.text)).d);
        if (envelope.Error) throw new Error('Course history needs to reconnect to StudentVUE. Try refreshing later.');
        data = parseSubjectDetails(envelope.Data); break;
      }
      case 'download': {
        const response = object(args.response);
        if (response.error) throw new Error('The district could not download this file.');
        const raw = object(response.data);
        let value: unknown = args.mail ? raw.attachmentXML ?? raw : raw.studentAttachedDocumentData ?? raw;
        if (typeof value === 'string') {
          try { value = JSON.parse(value); }
          catch {
            const text = value as string;
            const encoded = !/<!DOCTYPE|<!ENTITY/i.test(text) && text.match(/<(?:\w+:)?Base64Code\s*>([A-Za-z0-9+/=\s]+)<\/(?:\w+:)?Base64Code\s*>/i)?.[1];
            if (!encoded) throw new Error('The district returned an unsupported file format.');
            value = { base64Code: encoded };
          }
        }
        const wrapper = object(value);
        const file = object(wrapper.AttachmentXML ?? (Array.isArray(wrapper.documentDatas) ? wrapper.documentDatas[0] : wrapper.documentDatas) ?? wrapper);
        const encoded = String(file.base64Code ?? file.Base64Code ?? '').replace(/\s/g, '');
        if (!encoded || encoded.length > 12_000_000 || encoded.length % 4 || !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)) throw new Error('The district did not return a usable file.');
        data = encoded; break;
      }
      default: throw new Error('Unsupported local parser operation.');
    }
    return JSON.stringify({ data });
  } catch (error) {
    return JSON.stringify({ error: error instanceof Error ? error.message : 'Could not read the district response.' });
  }
}
