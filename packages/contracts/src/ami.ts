import { z } from "zod";
import {
  identifierSchema,
  meterIdSchema,
  nonNegativeIntegerSchema,
  SCHEMA_VERSION,
  timestampSchema,
} from "./common.js";
import {
  energyReadingSchema,
  meterEventSchema,
  meterMeasurementSchema,
  meterStatusSchema,
  tariffReadingSchema,
} from "./meter.js";

export const amiEnvelopeSchema = z
  .object({
    schemaVersion: z.literal(SCHEMA_VERSION),
    id: identifierSchema,
    packetId: identifierSchema,
    meterId: meterIdSchema,
    sequence: nonNegativeIntegerSchema,
    simulationTimeHours: z.number().finite().min(0),
    generatedAt: timestampSchema,
    transferredAt: timestampSchema,
    measurement: meterMeasurementSchema,
    energy: energyReadingSchema,
    tariff: tariffReadingSchema,
    status: meterStatusSchema,
    events: z.array(meterEventSchema).max(100),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.id !== value.packetId) {
      context.addIssue({ code: "custom", message: "id must equal packetId", path: ["packetId"] });
    }
    const nested = [value.measurement, value.energy, value.tariff, value.status, ...value.events];
    if (nested.some((item) => item.meterId !== value.meterId)) {
      context.addIssue({ code: "custom", message: "Nested meterId mismatch", path: ["meterId"] });
    }
    if (nested.some((item) => item.schemaVersion !== value.schemaVersion)) {
      context.addIssue({ code: "custom", message: "Nested schema version mismatch" });
    }
  });

export const signedAmiPacketSchema = z
  .object({
    envelope: amiEnvelopeSchema,
    algorithm: z.literal("HMAC-SHA256"),
    signatureBase64: z.string().min(43).max(44),
  })
  .strict();

export type AmiEnvelope = z.infer<typeof amiEnvelopeSchema>;
export type SignedAmiPacket = z.infer<typeof signedAmiPacketSchema>;
