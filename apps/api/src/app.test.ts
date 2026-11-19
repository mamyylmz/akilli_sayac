import { randomUUID } from "node:crypto";
import { afterEach, describe, expect, it } from "vitest";
import type {
  AmiEnvelope,
  ControlCommand,
  MeterStatus,
  SignedAmiPacket,
} from "@akilli-sayac/contracts";
import { LocalTokenAuth, signAmiEnvelope } from "@akilli-sayac/security";
import { buildApp } from "./app.js";
import { MeterDatabase } from "./database.js";
import { resolveImportFile } from "./file-import.js";
import type { SimulatorAdapter } from "./simulator-adapter.js";

const hmacKey = Buffer.alloc(32, 9);
const viewerToken = "viewer-test-token-0001";
const operatorToken = "operator-test-token-01";
const adminToken = "admin-test-token-00001";
const openApps: Array<{ close(): Promise<void> }> = [];
const openDatabases: MeterDatabase[] = [];

afterEach(async () => {
  await Promise.all(openApps.splice(0).map((app) => app.close()));
  for (const database of openDatabases.splice(0)) database.close();
});

function createEnvelope(
  sequence = 1,
  statusOverrides: Partial<Pick<MeterStatus, "gridState" | "relayState" | "overloadActive">> = {},
  meterId = "meter-demo-001",
): AmiEnvelope {
  const exportedAt = "2026-11-19T15:00:00.000Z";
  const metadata = { schemaVersion: "1.0.0" as const, meterId };
  const simulation = {
    simulationTimeHours: 3.5,
    exportedAt,
    provenance: { kind: "simulated" as const, trusted: true },
  };
  const packetId = randomUUID();
  return {
    ...metadata,
    id: packetId,
    packetId,
    sequence,
    simulationTimeHours: 3.5,
    generatedAt: exportedAt,
    transferredAt: exportedAt,
    measurement: {
      ...metadata,
      ...simulation,
      id: randomUUID(),
      voltageRmsV: 230,
      currentRmsA: 0.81,
      activePowerW: 149,
      reactivePowerVar: 111,
      apparentPowerVa: 185.8,
      displacementPowerFactor: 0.804,
      truePowerFactor: 0.804,
    },
    energy: {
      ...metadata,
      ...simulation,
      id: randomUUID(),
      totalActiveEnergyKWh: 0.52,
      inductiveReactiveEnergyKvarh: 0.1,
      capacitiveReactiveEnergyKvarh: 0,
    },
    tariff: {
      ...metadata,
      ...simulation,
      id: randomUUID(),
      t1KWh: 0,
      t2KWh: 0,
      t3KWh: 0.52,
    },
    status: {
      ...metadata,
      ...simulation,
      id: randomUUID(),
      relayState: "deenergized",
      gridState: "available",
      overloadActive: false,
      ...statusOverrides,
    },
    events: [],
  };
}

function signedPacket(envelope = createEnvelope()): SignedAmiPacket {
  return {
    envelope,
    algorithm: "HMAC-SHA256",
    signatureBase64: signAmiEnvelope(envelope, hmacKey),
  };
}

function command(
  requestedRelayState: "energized" | "deenergized" = "energized",
  overrides: Partial<ControlCommand> = {},
): ControlCommand {
  const commandId = randomUUID();
  const now = Date.now();
  return {
    schemaVersion: "1.0.0",
    id: commandId,
    commandId,
    meterId: "meter-demo-001",
    actorId: "operator-1",
    createdAt: new Date(now).toISOString(),
    expiresAt: new Date(now + 60_000).toISOString(),
    requestedRelayState,
    reason: "Local adversarial test",
    ...overrides,
  };
}

function createTestApp(
  options: { adapter?: SimulatorAdapter; bodyLimit?: number; rateLimitMax?: number } = {},
) {
  const database = new MeterDatabase(":memory:");
  const auth = new LocalTokenAuth([
    { actorId: "viewer-1", role: "viewer", token: viewerToken },
    { actorId: "operator-1", role: "operator", token: operatorToken },
    { actorId: "admin-1", role: "admin", token: adminToken },
  ]);
  const app = buildApp({
    database,
    auth,
    expectedMeterId: "meter-demo-001",
    hmacKey,
    allowedOrigins: ["http://127.0.0.1:5173"],
    ...(options.adapter ? { simulatorAdapter: options.adapter } : {}),
    ...(options.bodyLimit ? { bodyLimit: options.bodyLimit } : {}),
    ...(options.rateLimitMax ? { rateLimitMax: options.rateLimitMax } : {}),
  });
  openApps.push(app);
  openDatabases.push(database);
  return { app, database };
}

const operatorHeaders = { authorization: `Bearer ${operatorToken}` };

async function importStatus(app: ReturnType<typeof createTestApp>["app"], envelope: AmiEnvelope) {
  const response = await app.inject({
    method: "POST",
    url: "/api/v1/ami/import",
    headers: operatorHeaders,
    payload: signedPacket(envelope),
  });
  expect(response.statusCode).toBe(201);
}

describe("HTTP security", () => {
  it("serves a local smoke-test health endpoint", async () => {
    const { app } = createTestApp();
    const response = await app.inject({ method: "GET", url: "/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ status: "ok" });
  });

  it("returns 401 without authentication and 403 for a viewer relay request", async () => {
    const { app } = createTestApp();
    const noAuth = await app.inject({
      method: "POST",
      url: "/api/v1/control-commands",
      payload: command(),
    });
    expect(noAuth.statusCode).toBe(401);
    const viewer = await app.inject({
      method: "POST",
      url: "/api/v1/control-commands",
      headers: { authorization: `Bearer ${viewerToken}` },
      payload: command(),
    });
    expect(viewer.statusCode).toBe(403);
  });

  it("does not treat CORS as authentication", async () => {
    const { app } = createTestApp();
    const response = await app.inject({
      method: "GET",
      url: "/api/v1/dashboard",
      headers: { origin: "http://127.0.0.1:5173" },
    });
    expect(response.statusCode).toBe(401);
  });

  it("rejects disallowed origins and rate limits repeated requests", async () => {
    const first = createTestApp().app;
    const cors = await first.inject({
      method: "GET",
      url: "/health",
      headers: { origin: "https://attacker.example" },
    });
    expect(cors.statusCode).toBe(403);

    const limited = createTestApp({ rateLimitMax: 1 }).app;
    expect((await limited.inject({ method: "GET", url: "/health" })).statusCode).toBe(200);
    expect((await limited.inject({ method: "GET", url: "/health" })).statusCode).toBe(429);
  });

  it("rejects malformed JSON and oversized payloads without a stack trace", async () => {
    const malformedApp = createTestApp().app;
    const malformed = await malformedApp.inject({
      method: "POST",
      url: "/api/v1/ami/import",
      headers: { ...operatorHeaders, "content-type": "application/json" },
      payload: "{broken",
    });
    expect(malformed.statusCode).toBe(400);
    expect(malformed.body).not.toContain("at ");

    const smallApp = createTestApp({ bodyLimit: 100 }).app;
    const oversized = await smallApp.inject({
      method: "POST",
      url: "/api/v1/ami/import",
      headers: operatorHeaders,
      payload: { padding: "x".repeat(500) },
    });
    expect(oversized.statusCode).toBe(413);
  });
});

describe("AMI security and SQLite idempotency", () => {
  it("imports once and blocks replay by packet/sequence", async () => {
    const { app, database } = createTestApp();
    const packet = signedPacket();
    const first = await app.inject({
      method: "POST",
      url: "/api/v1/ami/import",
      headers: operatorHeaders,
      payload: packet,
    });
    const replay = await app.inject({
      method: "POST",
      url: "/api/v1/ami/import",
      headers: operatorHeaders,
      payload: packet,
    });
    expect(first.statusCode).toBe(201);
    expect(replay.statusCode).toBe(409);
    expect(database.dashboard("meter-demo-001").measurement).toBeDefined();
  });

  it("rejects wrong HMAC, changed data, and wrong meter identity", async () => {
    const { app } = createTestApp();
    const badHmac = signedPacket();
    badHmac.signatureBase64 = Buffer.alloc(32, 1).toString("base64");
    expect(
      (
        await app.inject({
          method: "POST",
          url: "/api/v1/ami/import",
          headers: operatorHeaders,
          payload: badHmac,
        })
      ).statusCode,
    ).toBe(401);

    const changed = signedPacket();
    changed.envelope.measurement.activePowerW = 9000;
    expect(
      (
        await app.inject({
          method: "POST",
          url: "/api/v1/ami/import",
          headers: operatorHeaders,
          payload: changed,
        })
      ).statusCode,
    ).toBe(401);

    const wrongMeter = signedPacket(createEnvelope(2, {}, "meter-other-001"));
    expect(
      (
        await app.inject({
          method: "POST",
          url: "/api/v1/ami/import",
          headers: operatorHeaders,
          payload: wrongMeter,
        })
      ).statusCode,
    ).toBe(400);
  });

  it("rejects SQL injection-shaped identifiers at the schema boundary", async () => {
    const { app } = createTestApp();
    const packet = signedPacket();
    const hostile = "meter-demo-001' OR 1=1--";
    const raw = JSON.parse(JSON.stringify(packet)) as SignedAmiPacket;
    raw.envelope.meterId = hostile;
    raw.envelope.measurement.meterId = hostile;
    raw.envelope.energy.meterId = hostile;
    raw.envelope.tariff.meterId = hostile;
    raw.envelope.status.meterId = hostile;
    const response = await app.inject({
      method: "POST",
      url: "/api/v1/ami/import",
      headers: operatorHeaders,
      payload: raw,
    });
    expect(response.statusCode).toBe(400);
  });

  it("blocks path traversal before any file read", () => {
    expect(() => resolveImportFile("/tmp/allowed", "../../etc/passwd.json")).toThrow();
    expect(() => resolveImportFile("/tmp/allowed", "meter.exe")).toThrow();
  });
});

describe("relay control safety", () => {
  it("applies a command once and returns an idempotent duplicate result", async () => {
    const { app } = createTestApp();
    await importStatus(app, createEnvelope());
    const payload = command();
    const first = await app.inject({
      method: "POST",
      url: "/api/v1/control-commands",
      headers: operatorHeaders,
      payload,
    });
    const duplicate = await app.inject({
      method: "POST",
      url: "/api/v1/control-commands",
      headers: operatorHeaders,
      payload,
    });
    expect(first.statusCode).toBe(202);
    expect(duplicate.statusCode).toBe(200);
    expect(duplicate.json()).toMatchObject({ outcome: "duplicate", code: "DUPLICATE_COMMAND" });
  });

  it("rejects expired commands and actor spoofing", async () => {
    const { app } = createTestApp();
    await importStatus(app, createEnvelope());
    const expired = command("energized", {
      createdAt: new Date(Date.now() - 120_000).toISOString(),
      expiresAt: new Date(Date.now() - 60_000).toISOString(),
    });
    const expiredResponse = await app.inject({
      method: "POST",
      url: "/api/v1/control-commands",
      headers: operatorHeaders,
      payload: expired,
    });
    expect(expiredResponse.statusCode).toBe(409);
    expect(expiredResponse.json()).toMatchObject({ code: "EXPIRED_COMMAND" });

    const spoofed = await app.inject({
      method: "POST",
      url: "/api/v1/control-commands",
      headers: operatorHeaders,
      payload: command("deenergized", { actorId: "admin-1" }),
    });
    expect(spoofed.statusCode).toBe(403);
  });

  it.each([
    [{ gridState: "unavailable" as const }, "GRID_UNAVAILABLE"],
    [{ overloadActive: true }, "OVERLOAD_ACTIVE"],
  ])("blocks unsafe reconnection for status %j", async (status, code) => {
    const { app } = createTestApp();
    await importStatus(app, createEnvelope(1, status));
    const response = await app.inject({
      method: "POST",
      url: "/api/v1/control-commands",
      headers: operatorHeaders,
      payload: command("energized"),
    });
    expect(response.statusCode).toBe(409);
    expect(response.json()).toMatchObject({ code });
  });

  it("rejects simultaneous conflicting commands", async () => {
    let release: (() => void) | undefined;
    let started: (() => void) | undefined;
    const startedPromise = new Promise<void>((resolve) => {
      started = resolve;
    });
    const adapter: SimulatorAdapter = {
      async applyRelayCommand(request) {
        started?.();
        await new Promise<void>((resolve) => {
          release = resolve;
        });
        return { relayState: request.requestedRelayState, message: "test adapter" };
      },
    };
    const { app } = createTestApp({ adapter });
    await importStatus(app, createEnvelope());
    const firstPromise = app.inject({
      method: "POST",
      url: "/api/v1/control-commands",
      headers: operatorHeaders,
      payload: command("energized"),
    });
    await startedPromise;
    const conflicting = await app.inject({
      method: "POST",
      url: "/api/v1/control-commands",
      headers: operatorHeaders,
      payload: command("deenergized"),
    });
    expect(conflicting.statusCode).toBe(409);
    expect(conflicting.json()).toMatchObject({ code: "CONFLICTING_COMMAND" });
    release?.();
    expect((await firstPromise).statusCode).toBe(202);
  });
});
