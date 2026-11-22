import { z } from "zod";
import { packetMetadataSchema, timestampSchema } from "./common.js";

export const controlCommandSchema = packetMetadataSchema
  .extend({
    commandId: z.string().uuid(),
    createdAt: timestampSchema,
    expiresAt: timestampSchema,
    actorId: z.string().min(1).max(128),
    requestedRelayState: z.enum(["energized", "deenergized"]),
    reason: z.string().min(3).max(256),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.id !== value.commandId) {
      context.addIssue({
        code: "custom",
        message: "id must equal commandId",
        path: ["commandId"],
      });
    }
    if (Date.parse(value.expiresAt) <= Date.parse(value.createdAt)) {
      context.addIssue({
        code: "custom",
        message: "expiresAt must be after createdAt",
        path: ["expiresAt"],
      });
    }
  });

export const commandResultSchema = packetMetadataSchema
  .extend({
    commandId: z.string().uuid(),
    completedAt: timestampSchema,
    outcome: z.enum(["accepted", "pending", "applied", "rejected", "duplicate"]),
    code: z.enum([
      "APPLIED",
      "QUEUED_FOR_SIMULINK",
      "DUPLICATE_COMMAND",
      "EXPIRED_COMMAND",
      "GRID_UNAVAILABLE",
      "OVERLOAD_ACTIVE",
      "CONFLICTING_COMMAND",
      "METER_MISMATCH",
      "UNAUTHORIZED",
    ]),
    relayState: z.enum(["energized", "deenergized", "unknown"]),
    message: z.string().min(1).max(256),
  })
  .strict();

export type ControlCommand = z.infer<typeof controlCommandSchema>;
export type CommandResult = z.infer<typeof commandResultSchema>;
