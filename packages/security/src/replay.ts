export class ReplayGuard {
  readonly #seen = new Map<string, number>();

  constructor(private readonly retentionMilliseconds = 24 * 60 * 60 * 1000) {}

  accept(key: string, now = Date.now()): boolean {
    for (const [storedKey, expiresAt] of this.#seen) {
      if (expiresAt <= now) this.#seen.delete(storedKey);
    }
    if (this.#seen.has(key)) return false;
    this.#seen.set(key, now + this.retentionMilliseconds);
    return true;
  }
}
