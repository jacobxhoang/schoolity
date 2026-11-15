import { parse, parseFragment, type DefaultTreeAdapterTypes } from "parse5";
import { number, object } from "../portal-data.ts";
import type { GraduationRequirement, SubjectDetails } from "../records.ts";

// Read JSON assigned by the district page without executing any page scripts.
export function parseHistoryPage(html: string): unknown[] {
  const assignment = /\bPXP\.CourseHistory\s*=\s*(?=\[)/.exec(html);
  if (!assignment) {
    if (
      /type\s*=\s*["']password["']|<form[^>]*action=["'][^"']*(?:PXP2_Login|Login_Student)/i.test(
        html,
      )
    )
      throw Object.assign(
        new Error("Your district web session ended. Sign in again."),
        { status: 401 },
      );
    throw new Error(
      "The district did not return a supported course history. Try refreshing.",
    );
  }
  const start = assignment.index + assignment[0].length;
  let depth = 0,
    quoted = false,
    escaped = false;
  for (let index = start; index < html.length; index++) {
    const char = html[index];
    if (quoted) {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === '"') quoted = false;
      continue;
    }
    if (char === '"') quoted = true;
    else if (char === "[" || char === "{") depth++;
    else if (char === "]" || char === "}") {
      if (--depth === 0) {
        const data: unknown = JSON.parse(html.slice(start, index + 1));
        if (Array.isArray(data)) return data;
        break;
      }
    }
  }
  throw new Error(
    "The district returned an unreadable course history. Try refreshing.",
  );
}

export function parseHistoryOverview(html: string) {
  const courseHistory = parseHistoryPage(html);
  const requirements = new Map<string, GraduationRequirement>();
  let classOf = "";
  type Node = DefaultTreeAdapterTypes.Node;
  function content(node: Node): string {
    if ("tagName" in node && ["script", "style"].includes(node.tagName))
      return "";
    return "value" in node
      ? node.value
      : "childNodes" in node
        ? node.childNodes.map(content).join(" ")
        : "";
  }
  function visit(node: Node, inSummary = false, inDetails = false) {
    if ("tagName" in node) {
      const attribute = (name: string) =>
        node.attrs.find((a) => a.name === name)?.value;
      const classes = (attribute("class") ?? "").split(/\s+/);
      inSummary ||= classes.includes("pxp-summary");
      inDetails ||= classes.includes("details");
      if (/^h[1-3]$/.test(node.tagName) && !classOf)
        classOf = content(node).match(/Class of\s+(\d{4})/i)?.[1] ?? "";
      if (
        node.tagName === "tr" &&
        inSummary &&
        inDetails &&
        attribute("data-guid") !== undefined
      ) {
        const cells = node.childNodes.filter(
          (n): n is DefaultTreeAdapterTypes.Element =>
            "tagName" in n && ["td", "th"].includes(n.tagName),
        );
        if (cells.length >= 5) {
          const text = cells.map((c) => content(c).replace(/\s+/g, " ").trim());
          if (text[0])
            requirements.set(attribute("data-guid") || text[0], {
              id: attribute("data-guid") ?? "",
              subject: text[0],
              required: number(text[1]),
              completed: number(text[2]),
              inProgress: number(text[3]),
              remaining: number(text[4]),
            });
        }
      }
    }
    if ("childNodes" in node)
      for (const child of node.childNodes) visit(child, inSummary, inDetails);
  }
  visit(parse(html));
  return {
    courseHistory,
    graduationRequirements: [...requirements.values()],
    classOf,
  };
}

// The district supplies column names and rows for one requirement. Convert cell
// markup to plain text; never execute scripts or render district-provided HTML.
export function parseSubjectDetails(payload: unknown): SubjectDetails {
  const data = object(payload),
    columns = Array.isArray(data.Columns) ? data.Columns : object(data.Columns);
  if (!Object.keys(columns).length || !Array.isArray(data.Rows))
    throw new Error(
      "The district returned an unsupported subject detail format. Try again.",
    );
  function cell(value: unknown): string {
    if (typeof value !== "string" && typeof value !== "number") return "";
    function content(node: DefaultTreeAdapterTypes.Node): string {
      if ("tagName" in node && ["script", "style"].includes(node.tagName))
        return "";
      return "value" in node
        ? node.value
        : "childNodes" in node
          ? node.childNodes.map(content).join(" ")
          : "";
    }
    return content(parseFragment(String(value)))
      .replace(/\s+/g, " ")
      .trim();
  }
  const splitLabels: Record<string, string> = {
    CourseTitle: "Course",
    CourseID: "Course ID",
  };
  const fields = Object.entries(columns).flatMap(([key, label]) =>
    key.split("|").map((part) => ({
      key: part,
      label: key.includes("|")
        ? (splitLabels[part] ?? cell(label))
        : cell(label),
    })),
  );
  const markIndex = fields.findIndex(
    (f) => /^(mark|grade)$/i.test(f.key) || /^(mark|grade)$/i.test(f.label),
  );
  if (markIndex < 0)
    throw new Error(
      "The district did not identify completed and in-progress classes. Try again.",
    );
  const result: SubjectDetails = {
    columns: fields.map((f) => f.label),
    completed: [],
    inProgress: [],
  };
  for (const raw of data.Rows) {
    if (raw === null || typeof raw !== "object")
      throw new Error(
        "The district returned unreadable subject classes. Try again.",
      );
    const row = object(raw);
    const supplied = Object.values(raw);
    const named = fields.some((f) => Object.hasOwn(row, f.key));
    if (!named && supplied.length !== fields.length)
      throw new Error(
        "The district returned unreadable subject classes. Try again.",
      );
    const values = named
      ? fields.map((f) => cell(row[f.key]))
      : supplied.map(cell);
    // StudentVUE distinguishes finalized classes by their mark, including F/P.
    (values[markIndex] ? result.completed : result.inProgress).push(values);
  }
  return result;
}
