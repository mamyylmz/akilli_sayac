import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { Actor, LocalTokenAuth, Permission } from "@akilli-sayac/security";
import { hasPermission } from "@akilli-sayac/security";

declare module "fastify" {
  interface FastifyRequest {
    actor: Actor | undefined;
  }
}

export interface HttpSecurityOptions {
  allowedOrigins: string[];
  auth: LocalTokenAuth;
  rateLimitMax: number;
  rateLimitWindowMilliseconds: number;
}

export function installHttpSecurity(app: FastifyInstance, options: HttpSecurityOptions): void {
  const rates = new Map<string, { count: number; resetsAt: number }>();

  app.addHook("onRequest", async (request, reply) => {
    const origin = request.headers.origin;
    if (origin && !options.allowedOrigins.includes(origin)) {
      await reply.code(403).send({ error: "ORIGIN_NOT_ALLOWED", message: "Origin is not allowed" });
      return;
    }
    if (origin) {
      void reply.header("access-control-allow-origin", origin);
      void reply.header("vary", "Origin");
      void reply.header("access-control-allow-headers", "authorization, content-type");
      void reply.header("access-control-allow-methods", "GET, POST, OPTIONS");
    }

    const now = Date.now();
    const key = request.ip;
    const current = rates.get(key);
    const rate =
      !current || current.resetsAt <= now
        ? { count: 1, resetsAt: now + options.rateLimitWindowMilliseconds }
        : { ...current, count: current.count + 1 };
    rates.set(key, rate);
    void reply.header("x-ratelimit-limit", String(options.rateLimitMax));
    void reply.header(
      "x-ratelimit-remaining",
      String(Math.max(0, options.rateLimitMax - rate.count)),
    );
    if (rate.count > options.rateLimitMax) {
      await reply.code(429).send({ error: "RATE_LIMITED", message: "Too many requests" });
      return;
    }

    request.actor = options.auth.authenticate(request.headers.authorization);
  });

  app.options("*", async (_request, reply) => reply.code(204).send());
}

export function requirePermission(permission: Permission) {
  return async function permissionGuard(request: FastifyRequest, reply: FastifyReply) {
    if (!request.actor) {
      await reply
        .code(401)
        .send({ error: "UNAUTHENTICATED", message: "Authentication is required" });
      return;
    }
    if (!hasPermission(request.actor, permission)) {
      await reply.code(403).send({ error: "FORBIDDEN", message: "Permission is required" });
    }
  };
}
