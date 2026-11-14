import { parse, type DefaultTreeAdapterTypes as Tree } from 'parse5';
import type { InfoSection } from '../records.ts';

type Node = Tree.Node;
const children = (node: Node): Node[] => 'childNodes' in node ? node.childNodes : [];
const attr = (node: Node, name: string) => 'attrs' in node ? node.attrs.find(a => a.name === name)?.value ?? '' : '';
const hasClass = (node: Node, name: string) => attr(node, 'class').split(/\s+/).includes(name);
function text(node: Node, omitLabels = false): string {
  if ('tagName' in node) {
    if (['script','style','button','input','select','textarea'].includes(node.tagName) || (omitLabels && hasClass(node,'tbl_label'))) return '';
    if (node.tagName === 'br') return '\n';
    if (['p','div','li'].includes(node.tagName)) return '\n' + children(node).map(n => text(n,omitLabels)).join('') + '\n';
  }
  return 'value' in node ? node.value : children(node).map(n => text(n,omitLabels)).join('');
}
const clean = (value: string) => value.split(/\r?\n/).map(line => line.replace(/[\t \u00a0]+/g,' ').trim()).filter(Boolean).join('\n');
function find(node: Node, predicate: (n: Node) => boolean): Node | undefined {
  if (predicate(node)) return node;
  for (const child of children(node)) { const result = find(child,predicate); if (result) return result; }
  return undefined;
}
function all(node: Node, predicate: (n: Node) => boolean): Node[] {
  return [...(predicate(node) ? [node] : []), ...children(node).flatMap(n => all(n,predicate))];
}

export function parseStudentPage(html: string): InfoSection[] {
  const document = parse(html);
  const main = find(document,n => attr(n,'id') === 'MainDiv');
  if (!main) {
    if (/type\s*=\s*["']password["']|<form[^>]*action=["'][^"']*(?:PXP2_Login|Login_Student)/i.test(html))
      throw Object.assign(new Error('Your district web session ended. Sign in again to load all student information.'), {status:401});
    throw new Error('The district did not return a supported Student Info page. Try refreshing.');
  }
  const sections: InfoSection[] = [];
  for (const table of all(main,n => 'tagName' in n && n.tagName === 'table' && hasClass(n,'info_tbl'))) {
    const tableRows: Node[] = [];
    function rows(node: Node) {
      for (const child of children(node)) {
        if ('tagName' in child && child.tagName === 'table') continue;
        if ('tagName' in child && child.tagName === 'tr') tableRows.push(child);
        else rows(child);
      }
    }
    rows(table);
    if (!tableRows.length) continue;
    const cells = (row: Node) => children(row).filter(n => 'tagName' in n && ['td','th'].includes(n.tagName));
    const heading = cells(tableRows[0]);
    if (heading.length !== 1) continue;
    const title = clean(text(heading[0]));
    if (!title) continue;
    const section: InfoSection = {title:/emergency/i.test(title) ? 'Emergency contacts' : title, fields:[]};
    const labeledRows: InfoSection['fields'][] = [];
    let columns: string[] = [];
    const values: string[][] = [];
    const notes: string[] = [];
    for (const row of tableRows.slice(1)) {
      const rowCells = cells(row);
      if (hasClass(row,'row_subhdr')) { columns = rowCells.map(c => clean(text(c))); continue; }
      const fields = rowCells.flatMap(cell => {
        const label = find(cell,n => hasClass(n,'tbl_label'));
        const labelText = label ? clean(text(label)) : '';
        return labelText ? [{label:/^orderby$/i.test(labelText) ? 'Contact order' : labelText, value:clean(text(cell,true))}] : [];
      }).filter(f => f.label);
      if (fields.length) labeledRows.push(fields);
      else if (columns.length && rowCells.length === columns.length && !rowCells.some(c => Number(attr(c,'colspan')) > 1))
        values.push(rowCells.map(c => clean(text(c))));
      else { const note = clean(text(row)); if (note) notes.push(note); }
    }
    if (/emergency/i.test(title)) section.groups = labeledRows.map((fields,index) => ({title:`Contact ${index+1}`,fields}));
    else if (/physician|dentist/i.test(title)) section.groups = labeledRows.map((fields,index) => ({title:/physician/i.test(fields[0]?.label ?? '') ? 'Physician' : /dentist/i.test(fields[0]?.label ?? '') ? 'Dentist' : `Entry ${index+1}`,fields}));
    else section.fields = labeledRows.flat();
    if (columns.length && values.length) section.table = {columns, rows:values};
    if (notes.length) section.note = notes.join('\n');
    if (section.fields.length || section.groups?.length || section.table || section.note) sections.push(section);
  }
  if (!sections.length) throw new Error('No readable student information was returned. Try refreshing.');
  return sections;
}
