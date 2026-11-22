import { randomUUID } from "node:crypto";
import { join } from "node:path";
import Fastify, { type FastifyInstance } from "fastify";
import { ZodError, z } from "zod";
import { tariffConfigSchema } from "@akilli-sayac/billing";
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
import { installHttpSecurity, requirePermission } from "./http-security.js";
import { loadSimulinkImportPackage, SimulinkImportError } from "./simulink-import.js";
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

  app.get("/api/v1/dashboard", { preHandler: requirePermission("meter:read") }, (request) => {
    const query = z
      .object({
        runId: z
          .string()
          .regex(/^SIM-[0-9]{4}-[0-9]{8}T[0-9]{6}-[0-9A-F]{8}$/)
          .optional(),
      })
      .parse(request.query);
    return {
      dataStatus: "Simulated",
      trustedPhysicalMeterData: false,
      ...options.database.dashboard(options.expectedMeterId, query.runId),
    };
  });

  app.get("/api/v1/simulation-runs", { preHandler: requirePermission("meter:read") }, () => ({
    runs: options.database.listSimulationRuns(options.expectedMeterId),
  }));

  app.post(
    "/api/v1/simulation-runs/:runId/select",
    { preHandler: requirePermission("meter:read") },
    (request, reply) => {
      const params = z.object({ runId: z.string().min(1).max(96) }).parse(request.params);
      if (!request.actor) return reply.code(401).send({ error: "UNAUTHENTICATED" });
      if (
        !options.database.selectSimulationRun(
          options.expectedMeterId,
          params.runId,
          request.actor.actorId,
        )
      ) {
        return reply
          .code(404)
          .send({ error: "RUN_NOT_FOUND", message: "Simulation run was not found" });
      }
      return reply.code(200).send({ selected: true, runId: params.runId });
    },
  );

  app.get(
    "/api/v1/simulation-runs/:runId/measurements",
    { preHandler: requirePermission("meter:read") },
    (request) => {
      const params = z.object({ runId: z.string().min(1).max(96) }).parse(request.params);
      const query = z
        .object({
          bucketMinutes: z.coerce
            .number()
            .int()
            .refine((value) => [1, 15, 60].includes(value))
            .default(15),
        })
        .parse(request.query);
      return {
        runId: params.runId,
        bucketMinutes: query.bucketMinutes,
        measurements: options.database.simulationSeries(
          params.runId,
          query.bucketMinutes as 1 | 15 | 60,
        ),
      };
    },
  );

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
        .object({ metadataFileName: z.string().min(1).max(128) })
        .strict()
        .parse(request.body);
      if (!request.actor) return reply.code(401).send({ error: "UNAUTHENTICATED" });
      try {
        const imported = loadSimulinkImportPackage(
          importDirectory,
          body.metadataFileName,
          options.expectedMeterId,
        );
        const result = options.database.ingestSimulinkPackage(imported, request.actor.actorId);
        if (!result.inserted) {
          return reply.code(409).send({
            error: "RUN_ALREADY_IMPORTED",
            message: "This Simulink run was already imported",
            runId: result.runId,
          });
        }
        return reply.code(201).send({
          imported: true,
          runId: result.runId,
          measurementCount: result.measurements,
          eventCount: result.events,
          dataSource: "Simulink simulation",
          trustedPhysicalMeterData: false,
        });
      } catch (error) {
        if (!(error instanceof SimulinkImportError)) throw error;
        options.database.recordImportFailure(
          options.expectedMeterId,
          request.actor.actorId,
          body.metadataFileName,
          error.code,
        );
        return reply.code(422).send({ error: error.code, message: error.message });
      }
    },
  );

  app.get("/api/v1/tariffs", { preHandler: requirePermission("meter:read") }, () => ({
    tariffs: options.database.listTariffs(),
  }));

  app.post(
    "/api/v1/tariffs",
    { preHandler: requirePermission("tariff:manage") },
    (request, reply) => {
      const tariff = tariffConfigSchema.parse(request.body);
      if (!options.database.saveTariff(tariff)) {
        return reply
          .code(409)
          .send({ error: "TARIFF_EXISTS", message: "Tariff ID already exists" });
      }
      return reply.code(201).send({ created: true, tariff });
    },
  );

  app.post(
    "/api/v1/simulation-runs/:runId/bills",
    { preHandler: requirePermission("meter:read") },
    (request, reply) => {
      const params = z.object({ runId: z.string().min(1).max(96) }).parse(request.params);
      const body = z.object({ tariffId: z.string().uuid() }).strict().parse(request.body);
      try {
        return reply.code(200).send(options.database.calculateRunBill(params.runId, body.tariffId));
      } catch {
        return reply
          .code(404)
          .send({ error: "RUN_OR_TARIFF_NOT_FOUND", message: "Run or tariff was not found" });
      }
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
        outcome: adapterResult.status,
        code: adapterResult.code,
        relayState: adapterResult.relayState,
        message: adapterResult.message,
      });
      options.database.completeCommand(command, accepted);
      return reply.code(202).send(accepted);
    },
  );

  app.get(
    "/api/v1/control-commands/:commandId",
    { preHandler: requirePermission("meter:read") },
    (request, reply) => {
      const params = z.object({ commandId: z.string().uuid() }).parse(request.params);
      const status = options.database.commandStatus(params.commandId);
      return status
        ? reply.code(200).send(status)
        : reply.code(404).send({ error: "COMMAND_NOT_FOUND", message: "Command was not found" });
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
