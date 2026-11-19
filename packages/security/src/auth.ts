import { createHash, timingSafeEqual } from "node:crypto";

export const roles = ["viewer", "operator", "admin"] as const;
export type Role = (typeof roles)[number];
export type Permission = "meter:read" | "ami:import" | "relay:control" | "audit:read";

export interface Actor {
  actorId: string;
  role: Role;
}

export interface TokenRecord extends Actor {
  token: string;
}

const rolePermissions: Record<Role, ReadonlySet<Permission>> = {
  viewer: new Set(["meter:read"]),
  operator: new Set(["meter:read", "ami:import", "relay:control", "audit:read"]),
  admin: new Set(["meter:read", "ami:import", "relay:control", "audit:read"]),
};

export function hasPermission(actor: Actor, permission: Permission): boolean {
  return rolePermissions[actor.role].has(permission);
}

function tokenDigest(token: string): Buffer {
  return createHash("sha256").update(token, "utf8").digest();
}

export class LocalTokenAuth {
  readonly #records: Array<{ digest: Buffer; actor: Actor }>;

  constructor(records: TokenRecord[]) {
    if (records.some((record) => record.token.length < 16)) {
      throw new Error("Local bearer tokens must contain at least 16 characters");
    }
    this.#records = records.map(({ token, actorId, role }) => ({
      digest: tokenDigest(token),
      actor: { actorId, role },
    }));
  }

  authenticate(authorization: string | undefined): Actor | undefined {
    if (!authorization?.startsWith("Bearer ")) return undefined;
    const supplied = tokenDigest(authorization.slice("Bearer ".length));
    for (const record of this.#records) {
      if (timingSafeEqual(supplied, record.digest)) return record.actor;
    }
    return undefined;
  }
}

export function localTokenAuthFromJson(value: string | undefined): LocalTokenAuth {
  if (!value) return new LocalTokenAuth([]);
  const parsed: unknown = JSON.parse(value);
  if (!Array.isArray(parsed)) throw new Error("AKILLI_SAYAC_LOCAL_TOKENS_JSON must be an array");
  const records = parsed.map((item) => {
    if (
      typeof item !== "object" ||
      item === null ||
      typeof (item as TokenRecord).token !== "string" ||
      typeof (item as TokenRecord).actorId !== "string" ||
      !roles.includes((item as TokenRecord).role)
    ) {
      throw new Error("Invalid local token record");
    }
    return item as TokenRecord;
  });
  return new LocalTokenAuth(records);
}
