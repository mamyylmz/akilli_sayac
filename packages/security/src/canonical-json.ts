function canonicalizeValue(value: unknown): string {
  if (value === null) return "null";
  if (typeof value === "string" || typeof value === "boolean") return JSON.stringify(value);
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new TypeError("Canonical JSON only supports finite numbers");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalizeValue).join(",")}]`;
  if (typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, nested]) => nested !== undefined)
      .sort(([left], [right]) => left.localeCompare(right, "en"));
    return `{${entries
      .map(([key, nested]) => `${JSON.stringify(key)}:${canonicalizeValue(nested)}`)
      .join(",")}}`;
  }
  throw new TypeError(`Unsupported canonical JSON value: ${typeof value}`);
}

/** RFC 8785-inspired UTF-8 JSON with recursively sorted object keys. */
export function canonicalJson(value: unknown): string {
  return canonicalizeValue(value);
}
