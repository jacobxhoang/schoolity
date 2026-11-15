import type { SubjectDetails } from './records';

/** Share preloads and clicks, and prevent an older overview repopulating the cache. */
export class HistorySubjectCache {
  private values = new Map<string, SubjectDetails>();
  private pending = new Map<string, Promise<SubjectDetails>>();
  private revision = 0;

  has(id: string) { return this.values.has(id); }
  clear() {
    this.revision++;
    this.values.clear();
    this.pending.clear();
  }
  load(id: string, fetch: () => Promise<SubjectDetails>): Promise<SubjectDetails> {
    const cached = this.values.get(id);
    if (cached) return Promise.resolve(cached);
    const running = this.pending.get(id);
    if (running) return running;
    const revision = this.revision;
    const task = Promise.resolve().then(fetch).then(details => {
      if (revision !== this.revision) throw new Error('Course history changed. Open the subject again.');
      this.values.set(id, details);
      return details;
    }).finally(() => {
      if (this.pending.get(id) === task) this.pending.delete(id);
    });
    this.pending.set(id, task);
    return task;
  }
}
