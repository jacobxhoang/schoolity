export interface LocationState {
  section: string;
  course: string | null;
}
const sections = new Set([
  "grades",
  "schedule",
  "mail",
  "documents",
  "student",
  "history",
  "attendance",
]);
export function readLocation(hash: string): LocationState {
  const parts = hash.replace(/^#/, "").split("/");
  const section = sections.has(parts[0]) ? parts[0] : "grades";
  try {
    return {
      section,
      course:
        section === "grades" && parts[1] === "course" && parts[2]
          ? decodeURIComponent(parts.slice(2).join("/"))
          : null,
    };
  } catch {
    return { section: "grades", course: null };
  }
}
export function courseLocation(id: string): string {
  return `#grades/course/${encodeURIComponent(id)}`;
}
export function scoreChange(
  current: number | null,
  baseline: number | null,
): string {
  if (current === null || baseline === null) return "No comparison available";
  const change = current - baseline;
  return `${change >= 0 ? "+" : "−"}${Math.abs(change).toFixed(1)} percentage points from your starting estimate`;
}
export function chartRange(values: number[]): { low: number; high: number } {
  const clean = values.filter(Number.isFinite);
  return { low: Math.min(0, ...clean), high: Math.max(100, ...clean) };
}
