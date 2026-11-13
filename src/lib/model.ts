export interface Task {
  id: string;
  title: string;
  category: string;
  earned: number | null;
  possible: number;
  due: string;
  excluded?: boolean;
  hypothetical?: boolean;
}
export interface Category {
  name: string;
  weight: number;
}
export interface Course {
  id: string;
  name: string;
  teacher: string;
  room: string;
  period: string;
  color: string;
  official: number | null;
  categories: Category[];
  assignments: Task[];
}
export interface Term {
  id: number;
  name: string;
}
export interface GradeData {
  courses: Course[];
  terms: Term[];
  currentTerm: number;
}
export interface Profile {
  name: string;
  school: string;
  grade: string;
}
export interface EventItem {
  author?: string;
  id?: string;
  filename?: string;
  title: string;
  detail: string;
  date: string;
}

export function calculate(
  course: Pick<Course, 'assignments' | 'categories'>,
): number | null {
  const active = course.assignments.filter(
    (a) =>
      !a.excluded &&
      a.earned !== null &&
      Number.isFinite(a.earned) &&
      Number.isFinite(a.possible) &&
      a.possible >= 0,
  );
  if (!active.length) return null;
  const totals = new Map<string, { earned: number; possible: number }>();
  for (const a of active) {
    const t = totals.get(a.category) ?? { earned: 0, possible: 0 };
    t.earned += a.earned!;
    t.possible += a.possible;
    totals.set(a.category, t);
  }
  if (!course.categories.some((c) => c.weight > 0)) {
    const earned = active.reduce((s, a) => s + a.earned!, 0),
      possible = active.reduce((s, a) => s + a.possible, 0);
    return possible > 0 ? (earned / possible) * 100 : null;
  }
  let result = 0,
    weight = 0;
  for (const c of course.categories) {
    const t = totals.get(c.name);
    if (t && t.possible > 0 && c.weight > 0) {
      result += (t.earned / t.possible) * c.weight;
      weight += c.weight;
    }
  }
  return weight > 0 ? (result / weight) * 100 : null;
}
export function letter(score: number | null): string {
  if (score === null) return '—';
  return score >= 90
    ? 'A'
    : score >= 80
      ? 'B'
      : score >= 70
        ? 'C'
        : score >= 60
          ? 'D'
          : 'F';
}
export function percentage(score: number | null): string {
  return score === null ? '—' : `${score.toFixed(1)}%`;
}
export function targetScore(
  course: Course,
  category: string,
  possible: number,
  target: number,
): number | null {
  if (
    !Number.isFinite(possible) ||
    possible <= 0 ||
    !Number.isFinite(target) ||
    target < 0
  )
    return null;
  const withScore = (earned: number) =>
    calculate({
      ...course,
      assignments: [
        ...course.assignments,
        { id: 'target', title: 'Target', category, possible, earned, due: '' },
      ],
    });
  const low = withScore(0),
    high = withScore(possible);
  if (low === null || high === null || high === low || possible <= 0)
    return null;
  return ((target - low) / (high - low)) * possible;
}
export function trend(course: Course): number[] {
  const ordered = course.assignments
    .filter((a) => a.earned !== null && !a.excluded)
    .toSorted((a, b) => {
      const first = Date.parse(a.due),
        second = Date.parse(b.due);
      return Number.isFinite(first) && Number.isFinite(second)
        ? first - second
        : 0;
    });
  return ordered.map(
    (_, i) =>
      calculate({ ...course, assignments: ordered.slice(0, i + 1) }) ?? 0,
  );
}
