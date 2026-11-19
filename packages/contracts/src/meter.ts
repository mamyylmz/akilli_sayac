import { z } from "zod";
import {
  dataProvenanceSchema,
  finiteNumberSchema,
  nonNegativeFiniteNumberSchema,
  packetMetadataSchema,
  timestampSchema,
} from "./common.js";

const simulationFields = {
  simulationTimeHours: finiteNumberSchema.min(0),
  exportedAt: timestampSchema,
  provenance: dataProvenanceSchema,
} as const;

export const meterMeasurementSchema = packetMetadataSchema
  .extend({
    ...simulationFields,
    voltageInstantV: finiteNumberSchema.optional(),
    currentInstantA: finiteNumberSchema.optional(),
    voltageRmsV: nonNegativeFiniteNumberSchema,
    currentRmsA: nonNegativeFiniteNumberSchema,
    activePowerW: finiteNumberSchema,
    reactivePowerVar: finiteNumberSchema,
    apparentPowerVa: nonNegativeFiniteNumberSchema,
    displacementPowerFactor: finiteNumberSchema.min(0).max(1),
    truePowerFactor: finiteNumberSchema.min(-1).max(1),
    description: z.string().max(256).optional(),
  })
  .strict();

export const energyReadingSchema = packetMetadataSchema
  .extend({
    ...simulationFields,
    totalActiveEnergyKWh: nonNegativeFiniteNumberSchema,
    inductiveReactiveEnergyKvarh: nonNegativeFiniteNumberSchema,
    capacitiveReactiveEnergyKvarh: nonNegativeFiniteNumberSchema,
  })
  .strict();

export const tariffReadingSchema = packetMetadataSchema
  .extend({
    ...simulationFields,
    t1KWh: nonNegativeFiniteNumberSchema,
    t2KWh: nonNegativeFiniteNumberSchema,
    t3KWh: nonNegativeFiniteNumberSchema,
  })
  .strict()
  .superRefine((value, context) => {
    const sum = value.t1KWh + value.t2KWh + value.t3KWh;
    if (!Number.isFinite(sum)) {
      context.addIssue({ code: "custom", message: "Tariff total must be finite" });
    }
  });

export const meterStatusSchema = packetMetadataSchema
  .extend({
    ...simulationFields,
    relayState: z.enum(["energized", "deenergized", "unknown"]),
    gridState: z.enum(["available", "unavailable", "unknown"]),
    overloadActive: z.boolean(),
  })
  .strict();

export const meterEventSchema = packetMetadataSchema
  .extend({
    ...simulationFields,
    eventType: z.enum([
      "grid_lost",
      "grid_restored",
      "relay_changed",
      "overload_started",
      "overload_cleared",
      "validation_rejected",
    ]),
    severity: z.enum(["info", "warning", "critical"]),
    message: z.string().min(1).max(256),
  })
  .strict();

export type MeterMeasurement = z.infer<typeof meterMeasurementSchema>;
export type EnergyReading = z.infer<typeof energyReadingSchema>;
export type TariffReading = z.infer<typeof tariffReadingSchema>;
export type MeterStatus = z.infer<typeof meterStatusSchema>;
export type MeterEvent = z.infer<typeof meterEventSchema>;
