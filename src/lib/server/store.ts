// Shared on Vercel; bounded, expiring memory storage for local development.
export class Store {
  private memory = new Map<string, { value: string; expires: number }>();
  private env: NodeJS.ProcessEnv;
  private transport: typeof fetch;
  constructor(
    env: NodeJS.ProcessEnv = process.env,
    transport: typeof fetch = fetch,
  ) {
    this.env = env;
    this.transport = transport;
  }
  private config() {
    const url = this.env.UPSTASH_REDIS_REST_URL || this.env.KV_REST_API_URL;
    const token =
      this.env.UPSTASH_REDIS_REST_TOKEN || this.env.KV_REST_API_TOKEN;
    if (!url || !token) {
      if (this.env.VERCEL || url || token)
        throw new Error(
          'Configure the shared session store before signing in.',
        );
      return null;
    }
    if (new URL(url).protocol !== 'https:')
      throw new Error('Session storage requires HTTPS.');
    return { url, token };
  }
  private async command(args: (string | number)[]) {
    const config = this.config();
    if (!config) throw new Error('Shared storage is not configured.');
    try {
      const response = await this.transport(config.url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${config.token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(args),
        cache: 'no-store',
        signal: AbortSignal.timeout(5000),
      });
      const answer = await response.json();
      if (!response.ok || answer.error) throw new Error();
      return answer.result;
    } catch {
      throw new Error('Session storage is temporarily unavailable. Try again.');
    }
  }
  private key(key: string) {
    return `${this.env.SCHOOLITY_STORE_PREFIX || `schoolity:${this.env.VERCEL_ENV || 'local'}`}:${key}`;
  }
  private clean() {
    for (const [key, entry] of this.memory)
      if (entry.expires <= Date.now()) this.memory.delete(key);
  }
  async get(key: string): Promise<string | null> {
    if (this.config()) return await this.command(['GET', this.key(key)]);
    this.clean();
    return this.memory.get(key)?.value ?? null;
  }
  async set(key: string, value: string, seconds: number) {
    if (this.config()) {
      await this.command(['SET', this.key(key), value, 'EX', seconds]);
      return;
    }
    this.clean();
    if (this.memory.size >= 10000)
      throw new Error('Session storage is busy. Try again later.');
    this.memory.set(key, { value, expires: Date.now() + seconds * 1000 });
  }
  async delete(key: string) {
    if (this.config()) await this.command(['DEL', this.key(key)]);
    else this.memory.delete(key);
  }
  async increment(key: string, seconds: number): Promise<number> {
    if (this.config()) {
      const count = Number(
        await this.command([
          'EVAL',
          "local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n",
          1,
          this.key(key),
          seconds,
        ]),
      );
      if (!Number.isInteger(count) || count < 1)
        throw new Error('Invalid rate limit response.');
      return count;
    }
    this.clean();
    const n = Number(this.memory.get(key)?.value || 0) + 1;
    if (n === 1) await this.set(key, String(n), seconds);
    else this.memory.get(key)!.value = String(n);
    return n;
  }
}
export const store = new Store();
