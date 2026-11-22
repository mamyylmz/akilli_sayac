import { randomUUID } from "node:crypto";
import { join } from "node:path";
import Fastify, { type FastifyInstance } from "fastify";
import { ZodError, z } from "zod";
import {
  amiEnvelopeSchema,
  commandResultSchema,
  controlCommandSchema,
  signedAmiPacketSchema,
  type CommandResult,
  type ControlCommand,
  type SignedAmiPacket,
} from "@akilli-sayac/contracts";
import {
  evaluateControlCommand,
  type LocalTokenAuth,
  verifyAmiEnvelope,
} from "@akilli-sayac/security";
import type { MeterDatabase } from "./database.js";
import { readLimitedImportFile } from "./file-import.js";
import { installHttpSecurity, requirePermission } from "./http-security.js";
import { LocalSimulatorAdapter, type SimulatorAdapter } from "./simulator-adapter.js";

export interface BuildAppOptions {
  database: MeterDatabase;
  auth: LocalTokenAuth;
  allowedOrigins?: string[];
  expectedMeterId: string;
  hmacKey?: Buffer;
  simulatorAdapter?: SimulatorAdapter;
  bodyLimit?: number;
  rateLimitMax?: number;
  importDirectory?: string;
  logger?: boolean;
}

function resultFor(
  command: ControlCommand,
  values: Pick<CommandResult, "outcome" | "code" | "relayState" | "message">,
): CommandResult {
  return commandResultSchema.parse({
    schemaVersion: "1.0.0",
    id: randomUUID(),
    meterId: command.meterId,
    commandId: command.commandId,
    completedAt: new Date().toISOString(),
    ...values,
  });
}

export function buildApp(options: BuildAppOptions): FastifyInstance {
  const app = Fastify({
    logger: options.logger ?? false,
    bodyLimit: options.bodyLimit ?? 256 * 1024,
    trustProxy: false,
  });
  const adapter = options.simulatorAdapter ?? new LocalSimulatorAdapter();
  const importDirectory = options.importDirectory ?? join(process.cwd(), "fixtures", "imports");
  options.database.ensureMeter(options.expectedMeterId);

  installHttpSecurity(app, {
    allowedOrigins: options.allowedOrigins ?? ["http://127.0.0.1:5173"],
    auth: options.auth,
    rateLimitMax: options.rateLimitMax ?? 120,
    rateLimitWindowMilliseconds: 60_000,
  });

  app.setErrorHandler(async (error, _request, reply) => {
    if (error instanceof ZodError) {
      await reply.code(400).send({
        error: "VALIDATION_ERROR",
        message: "Request validation failed",
        issues: error.issues.map((issue) => ({
          path: issue.path.join("."),
          message: issue.message,
        })),
      });
      return;
    }
    if (
      error instanceof SyntaxError ||
      (error as { code?: string }).code === "FST_ERR_CTP_INVALID_JSON_BODY"
    ) {
      await reply
        .code(400)
        .send({ error: "MALFORMED_JSON", message: "Request body is not valid JSON" });
      return;
    }
    if ((error as { code?: string }).code === "FST_ERR_CTP_BODY_TOO_LARGE") {
      await reply
        .code(413)
        .send({ error: "PAYLOAD_TOO_LARGE", message: "Request body is too large" });
      return;
    }
    app.log.error(
      { error: error instanceof Error ? error.name : "UnknownError" },
      "Unhandled request failure",
    );
    await reply
      .code(500)
      .send({ error: "INTERNAL_ERROR", message: "Request could not be completed" });
  });

  app.get("/health", () => ({ status: "ok", service: "Akıllı Sayaç API" }));

  app.get("/api/v1/dashboard", { preHandler: requirePermission("meter:read") }, () => ({
    dataStatus: "Simulated / Synthetic",
    trustedPhysicalMeterData: false,
    ...options.database.dashboard(options.expectedMeterId),
  }));

  function importPacket(packetValue: unknown): { statusCode: number; body: unknown } {
    const packet = signedAmiPacketSchema.parse(packetValue);
    if (packet.envelope.meterId !== options.expectedMeterId) {
      return { statusCode: 400, body: { error: "METER_MISMATCH", message: "Unexpected meter" } };
    }
    if (!options.hmacKey) {
      return {
        statusCode: 503,
        body: {
          error: "HMAC_NOT_CONFIGURED",
          message: "AMI integrity verification is unavailable",
        },
      };
    }
    if (!verifyAmiEnvelope(packet.envelope, packet.signatureBase64, options.hmacKey)) {
      return {
        statusCode: 401,
        body: { error: "INVALID_HMAC", message: "AMI signature is invalid" },
      };
    }
    const result = options.database.ingestEnvelope(packet.envelope);
    if (!result.inserted) {
      return {
        statusCode: 409,
        body: { error: "REPLAY_DETECTED", message: "Packet or sequence was already processed" },
      };
    }
    return { statusCode: 201, body: { packetId: packet.envelope.packetId, imported: true } };
  }

  app.post(
    "/api/v1/ami/import",
    { preHandler: requirePermission("ami:import") },
    (request, reply) => {
      const result = importPacket(request.body);
      return reply.code(result.statusCode).send(result.body);
    },
  );

  app.post(
    "/api/v1/ami/import-file",
    { preHandler: requirePermission("ami:import") },
    (request, reply) => {
      const body = z
        .object({ fileName: z.string().min(1).max(128) })
        .strict()
        .parse(request.body);
      const imported = readLimitedImportFile(importDirectory, body.fileName, {
        maxBytes: 256 * 1024,
        maxRecords: 1000,
      });
      if (imported.extension !== ".json") {
        return reply.code(422).send({
          error: "CSV_REQUIRES_MAPPING",
          message: "CSV must be converted using the documented Simulink column mapping",
        });
      }
      const parsed: unknown = JSON.parse(imported.contents);
      const result = importPacket(parsed);
      return reply.code(result.statusCode).send(result.body);
    },
  );

  app.post(
    "/api/v1/control-commands",
    { preHandler: requirePermission("relay:control") },
    async (request, reply) => {
      const command = controlCommandSchema.parse(request.body);
      if (!request.actor) return reply.code(401).send({ error: "UNAUTHENTICATED" });
      if (command.actorId !== request.actor.actorId) {
        return reply
          .code(403)
          .send({ error: "ACTOR_MISMATCH", message: "Actor identity is server verified" });
      }
      if (command.meterId !== options.expectedMeterId) {
        return reply.code(400).send({ error: "METER_MISMATCH", message: "Unexpected meter" });
      }

      const existing = options.database.findCommandResult(command.commandId);
      if (existing) {
        return reply.code(200).send({
          ...existing,
          outcome: "duplicate",
          code: "DUPLICATE_COMMAND",
          message: "Command was already processed; relay was not operated again",
        });
      }
      if (!options.database.beginCommand(command)) {
        return reply.code(409).send({
          error: "DUPLICATE_COMMAND",
          message: "Command is already pending or completed",
        });
      }

      const status = options.database.getMeterStatus(options.expectedMeterId);
      if (!status) throw new Error("Configured meter is missing");
      const inFlight = options.database.inFlightRelayState(command.meterId, command.commandId);
      const decision = evaluateControlCommand(command, status, inFlight);
      if (!decision.allowed) {
        const rejected = resultFor(command, {
          outcome: "rejected",
          code: decision.code,
          relayState: status.relayState,
          message: decision.message,
        });
        options.database.completeCommand(command, rejected);
        return reply.code(409).send(rejected);
      }

      const adapterResult = await adapter.applyRelayCommand(command);
      const accepted = resultFor(command, {
        outcome: "accepted",
        code: "APPLIED",
        relayState: adapterResult.relayState,
        message: adapterResult.message,
      });
      options.database.completeCommand(command, accepted);
      return reply.code(202).send(accepted);
    },
  );

  app.get("/api/v1/audit-events", { preHandler: requirePermission("audit:read") }, (request) => {
    const query = z
      .object({ limit: z.coerce.number().int().min(1).max(500).default(100) })
      .parse(request.query);
    return { events: options.database.listAudit(query.limit) };
  });

  app.setNotFoundHandler(async (_request, reply) => {
    await reply.code(404).send({ error: "NOT_FOUND", message: "Route was not found" });
  });

  return app;
}

export function validateUnsignedEnvelopeForTestOnly(value: unknown) {
  return amiEnvelopeSchema.parse(value);
}

export type { SignedAmiPacket };
