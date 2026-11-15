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
          "Configure the shared session store before signing in.",
        );
      return null;
    }
    if (new URL(url).protocol !== "https:")
      throw new Error("Session storage requires HTTPS.");
    return { url, token };
  }
  private async command(args: (string | number)[]) {
    const config = this.config();
    if (!config) throw new Error("Shared storage is not configured.");
    try {
      const response = await this.transport(config.url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${config.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(args),
        cache: "no-store",
        signal: AbortSignal.timeout(5000),
      });
      const answer = await response.json();
      if (!response.ok || answer.error) throw new Error();
      return answer.result;
    } catch {
      throw new Error("Session storage is temporarily unavailable. Try again.");
    }
  }
  private key(key: string) {
    return `${this.env.SCHOOLITY_STORE_PREFIX || `schoolity:${this.env.VERCEL_ENV || "local"}`}:${key}`;
  }
  private clean() {
    for (const [key, entry] of this.memory)
      if (entry.expires <= Date.now()) this.memory.delete(key);
  }
  async get(key: string): Promise<string | null> {
    if (this.config()) return await this.command(["GET", this.key(key)]);
    this.clean();
    return this.memory.get(key)?.value ?? null;
  }
  async set(key: string, value: string, seconds: number) {
    if (this.config()) {
      await this.command(["SET", this.key(key), value, "EX", seconds]);
      return;
    }
    this.clean();
    if (this.memory.size >= 10000 && !this.memory.has(key))
      throw new Error("Session storage is busy. Try again later.");
    this.memory.set(key, { value, expires: Date.now() + seconds * 1000 });
  }
  async delete(key: string) {
    if (this.config()) await this.command(["DEL", this.key(key)]);
    else this.memory.delete(key);
  }
  async increment(key: string, seconds: number): Promise<number> {
    if (this.config()) {
      const count = Number(
        await this.command([
          "EVAL",
          "local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n",
          1,
          this.key(key),
          seconds,
        ]),
      );
      if (!Number.isInteger(count) || count < 1)
        throw new Error("Invalid rate limit response.");
      return count;
    }
    this.clean();
    const n = Number(this.memory.get(key)?.value || 0) + 1;
    if (n === 1) await this.set(key, String(n), seconds);
    else this.memory.get(key)!.value = String(n);
    return n;
  }
  async claim(key: string, value: string, seconds: number): Promise<boolean> {
    if (this.config())
      return (
        (await this.command([
          "SET",
          this.key(key),
          value,
          "EX",
          seconds,
          "NX",
        ])) === "OK"
      );
    this.clean();
    if (this.memory.has(key)) return false;
    await this.set(key, value, seconds);
    return true;
  }
  async compareSet(
    key: string,
    expected: string,
    value: string | null,
    seconds = 1,
  ): Promise<boolean> {
    if (this.config())
      return (
        Number(
          await this.command([
            "EVAL",
            "if redis.call('GET',KEYS[1])~=ARGV[1] then return 0 end; if ARGV[2]=='delete' then redis.call('DEL',KEYS[1]) else redis.call('SET',KEYS[1],ARGV[3],'EX',ARGV[4]) end; return 1",
            1,
            this.key(key),
            expected,
            value === null ? "delete" : "set",
            value ?? "",
            seconds,
          ]),
        ) === 1
      );
    this.clean();
    if (this.memory.get(key)?.value !== expected) return false;
    if (value === null) this.memory.delete(key);
    else this.memory.set(key, { value, expires: Date.now() + seconds * 1000 });
    return true;
  }
  private ordered = new Map<string, Map<string, number>>();
  async due(key: string, now: number, count: number): Promise<string[]> {
    if (this.config())
      return await this.command([
        "ZRANGEBYSCORE",
        this.key(key),
        "-inf",
        now,
        "LIMIT",
        0,
        count,
      ]);
    return [...(this.ordered.get(key) ?? new Map<string, number>())]
      .filter(([, score]) => score <= now)
      .sort((a, b) => a[1] - b[1])
      .slice(0, count)
      .map(([id]) => id);
  }
  async schedule(key: string, id: string, at: number) {
    if (this.config()) {
      await this.command(["ZADD", this.key(key), at, id]);
      return;
    }
    if (!this.ordered.has(key)) this.ordered.set(key, new Map());
    this.ordered.get(key)!.set(id, at);
  }
  async unschedule(key: string, id: string) {
    if (this.config()) await this.command(["ZREM", this.key(key), id]);
    else this.ordered.get(key)?.delete(id);
  }
}
export const store = new Store();
