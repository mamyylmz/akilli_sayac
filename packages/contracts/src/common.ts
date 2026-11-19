import { z } from "zod";

export const SCHEMA_VERSION = "1.0.0" as const;

export const finiteNumberSchema = z.number().finite();
export const nonNegativeFiniteNumberSchema = finiteNumberSchema.min(0);
export const positiveIntegerSchema = z.number().int().positive().safe();
export const nonNegativeIntegerSchema = z.number().int().min(0).safe();
export const identifierSchema = z.string().uuid();
export const meterIdSchema = z
  .string()
  .min(3)
  .max(64)
  .regex(/^[a-zA-Z0-9][a-zA-Z0-9._-]*$/, "Invalid meter identifier");
export const timestampSchema = z.string().datetime({ offset: true });

export const packetMetadataSchema = z
  .object({
    schemaVersion: z.literal(SCHEMA_VERSION),
    id: identifierSchema,
    meterId: meterIdSchema,
  })
  .strict();

export const dataProvenanceSchema = z
  .object({
    kind: z.enum(["device", "simulated", "synthetic"]),
    trusted: z.boolean(),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.kind === "synthetic" && value.trusted) {
      context.addIssue({
        code: "custom",
        message: "Synthetic data cannot be marked trusted",
        path: ["trusted"],
      });
    }
  });

export type PacketMetadata = z.infer<typeof packetMetadataSchema>;
export type DataProvenance = z.infer<typeof dataProvenanceSchema>;
