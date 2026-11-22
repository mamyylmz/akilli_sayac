import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { amiEnvelopeSchema, meterMeasurementSchema, tariffReadingSchema } from "./index.js";

const baseMeasurement = {
  schemaVersion: "1.0.0",
  id: "11111111-1111-4111-8111-111111111111",
  meterId: "meter-demo-001",
  simulationTimeHours: 3.5,
  exportedAt: "2026-11-19T15:00:00.000Z",
  provenance: { kind: "synthetic", trusted: false },
  voltageRmsV: 230,
  currentRmsA: 0.81,
  activePowerW: 149,
  reactivePowerVar: 111,
  apparentPowerVa: 185.8,
  displacementPowerFactor: 0.804,
  truePowerFactor: 0.804,
};

describe("meter contracts", () => {
  it("accepts negative active power because direction is physically meaningful", () => {
    expect(
      meterMeasurementSchema.parse({ ...baseMeasurement, activePowerW: -25 }).activePowerW,
    ).toBe(-25);
  });

  it.each([Number.NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY])(
    "rejects non-finite measurement %s",
    (value) => {
      expect(() =>
        meterMeasurementSchema.parse({ ...baseMeasurement, activePowerW: value }),
      ).toThrow();
    },
  );

  it("keeps hostile descriptions as plain data instead of HTML", () => {
    const description = '<img src=x onerror="alert(1)">';
    expect(meterMeasurementSchema.parse({ ...baseMeasurement, description }).description).toBe(
      description,
    );
  });

  it("rejects invalid tariff quantities", () => {
    expect(() =>
      tariffReadingSchema.parse({
        schemaVersion: "1.0.0",
        id: "11111111-1111-4111-8111-111111111111",
        meterId: "meter-demo-001",
        simulationTimeHours: 3.5,
        exportedAt: "2026-11-19T15:00:00.000Z",
        provenance: { kind: "synthetic", trusted: false },
        t1KWh: -1,
        t2KWh: 1,
        t3KWh: 1,
      }),
    ).toThrow();
  });

  it("validates the explicitly unsigned synthetic Simulink fixture", () => {
    const fixture: unknown = JSON.parse(
      readFileSync(resolve(process.cwd(), "fixtures/synthetic/ami-envelope.unsigned.json"), "utf8"),
    );
    const parsed = amiEnvelopeSchema.parse(fixture);
    expect(parsed.measurement.provenance).toEqual({ kind: "synthetic", trusted: false });
  });
});
