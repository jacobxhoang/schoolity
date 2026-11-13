export interface LocationState {
  section: string;
  course: string | null;
}
const sections = new Set([
  "grades",
  "schedule",
  "mail",
  "documents",
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
export function targetExplanation(
  points: number,
  target: number,
  result: number | null,
): string {
  if (!Number.isFinite(points) || points <= 0)
    return "Enter a points possible value greater than zero.";
  if (!Number.isFinite(target) || target < 0)
    return "Enter a valid target grade.";
  if (result === null)
    return "This category has no usable grading weight or scored points. Choose another category or add a scored assignment.";
  if (result <= 0)
    return "Your current scenario meets this target even with zero points on this next assignment.";
  if (result > points)
    return "Above full credit is required. Try another target or assignment size.";
  return "Points needed on this assignment.";
}
