import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import type { AmiEnvelope, ControlCommand, MeterStatus } from "@akilli-sayac/contracts";
import {
  canonicalJson,
  evaluateControlCommand,
  LocalTokenAuth,
  ReplayGuard,
  signAmiEnvelope,
  verifyAmiEnvelope,
} from "./index.js";

const key = Buffer.alloc(32, 7);
const metadata = {
  schemaVersion: "1.0.0" as const,
  meterId: "meter-demo-001",
};
const provenance = { kind: "synthetic" as const, trusted: false };
const exportedAt = "2026-11-19T15:00:00.000Z";

function envelope(): AmiEnvelope {
  const simulation = { simulationTimeHours: 3.5, exportedAt, provenance };
  const packetId = randomUUID();
  return {
    ...metadata,
    id: packetId,
    packetId,
    sequence: 1,
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
      relayState: "energized",
      gridState: "available",
      overloadActive: false,
    },
    events: [],
  };
}

describe("AMI integrity", () => {
  it("canonicalizes object keys deterministically", () => {
    expect(canonicalJson({ z: 1, a: { y: 2, b: 3 } })).toBe('{"a":{"b":3,"y":2},"z":1}');
  });

  it("rejects a changed envelope and malformed HMAC", () => {
    const original = envelope();
    const signature = signAmiEnvelope(original, key);
    expect(verifyAmiEnvelope(original, signature, key)).toBe(true);
    expect(
      verifyAmiEnvelope(
        { ...original, measurement: { ...original.measurement, activePowerW: 9999 } },
        signature,
        key,
      ),
    ).toBe(false);
    expect(verifyAmiEnvelope(original, "not-a-valid-signature", key)).toBe(false);
  });

  it("rejects a replayed packet key", () => {
    const guard = new ReplayGuard();
    expect(guard.accept("meter-demo-001:1")).toBe(true);
    expect(guard.accept("meter-demo-001:1")).toBe(false);
  });
});

describe("local authorization and relay safety", () => {
  it("does not authorize viewer credentials for relay control", () => {
    const auth = new LocalTokenAuth([
      { actorId: "viewer-1", role: "viewer", token: "viewer-token-for-tests" },
    ]);
    expect(auth.authenticate("Bearer wrong-token-value")).toBeUndefined();
    expect(auth.authenticate("Bearer viewer-token-for-tests")?.role).toBe("viewer");
  });

  it.each([
    ["unavailable", false, "GRID_UNAVAILABLE"],
    ["available", true, "OVERLOAD_ACTIVE"],
  ] as const)("blocks energizing when grid=%s overload=%s", (gridState, overloadActive, code) => {
    const now = new Date("2026-11-19T15:00:00.000Z");
    const commandId = randomUUID();
    const command: ControlCommand = {
      ...metadata,
      id: commandId,
      commandId,
      createdAt: now.toISOString(),
      expiresAt: "2026-11-19T15:01:00.000Z",
      actorId: "operator-1",
      requestedRelayState: "energized",
      reason: "Local safety test",
    };
    const status: MeterStatus = {
      ...metadata,
      id: randomUUID(),
      simulationTimeHours: 3.5,
      exportedAt,
      provenance,
      relayState: "deenergized",
      gridState,
      overloadActive,
    };
    expect(evaluateControlCommand(command, status, undefined, now).code).toBe(code);
  });
});
