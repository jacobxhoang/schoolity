import type { GradeData } from "./model";

export const GRADE_CACHE_KEY = "schoolity.gradebook.v1";
type Storage = Pick<globalThis.Storage, "getItem" | "setItem" | "removeItem">;
const validBook = (value: any): value is GradeData =>
  value &&
  Number.isInteger(value.currentTerm) &&
  Array.isArray(value.terms) &&
  value.terms.every(
    (t: any) => t && Number.isInteger(t.id) && typeof t.name === "string",
  ) &&
  Array.isArray(value.courses) &&
  value.courses.every(
    (c: any) =>
      c &&
      ["id", "name", "teacher", "room", "period"].every(
        (k) => typeof c[k] === "string",
      ) &&
      (c.official === null || Number.isFinite(c.official)) &&
      Array.isArray(c.categories) &&
      c.categories.every(
        (g: any) =>
          g && typeof g.name === "string" && Number.isFinite(g.weight),
      ) &&
      Array.isArray(c.assignments) &&
      c.assignments.every(
        (a: any) =>
          a &&
          ["id", "title", "category", "due"].every(
            (k) => typeof a[k] === "string",
          ) &&
          (a.earned === null || Number.isFinite(a.earned)) &&
          Number.isFinite(a.possible),
      ),
  );

export function clearGradeCache(storage: Storage) {
  try {
    storage.removeItem(GRADE_CACHE_KEY);
  } catch {
    /* Storage may be disabled. */
  }
}
export function readGradeCache(
  storage: Storage,
  identity: string | null,
  now = Date.now(),
): { book: GradeData; savedAt: number } | null {
  try {
    const cached = JSON.parse(storage.getItem(GRADE_CACHE_KEY) ?? "null");
    if (
      !identity ||
      !cached ||
      cached.identity !== identity ||
      !Number.isFinite(cached.savedAt) ||
      cached.savedAt > now ||
      now - cached.savedAt > 7 * 86400000 ||
      !validBook(cached.book)
    ) {
      clearGradeCache(storage);
      return null;
    }
    return { book: cached.book, savedAt: cached.savedAt };
  } catch {
    clearGradeCache(storage);
    return null;
  }
}
export function saveGradeCache(
  storage: Storage,
  identity: string | null,
  book: GradeData,
  savedAt: number,
) {
  if (!identity || !validBook(book)) return;
  try {
    storage.setItem(
      GRADE_CACHE_KEY,
      JSON.stringify({ identity, book, savedAt }),
    );
  } catch {
    /* A full or unavailable cache must not interrupt fresh grades. */
  }
}
