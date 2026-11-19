import type { ControlCommand, MeterStatus } from "@akilli-sayac/contracts";

export type ControlPolicyCode =
  | "APPLIED"
  | "EXPIRED_COMMAND"
  | "GRID_UNAVAILABLE"
  | "OVERLOAD_ACTIVE"
  | "CONFLICTING_COMMAND"
  | "METER_MISMATCH";

export interface ControlPolicyDecision {
  allowed: boolean;
  code: ControlPolicyCode;
  message: string;
}

export function evaluateControlCommand(
  command: ControlCommand,
  status: MeterStatus,
  inFlightRequestedState: ControlCommand["requestedRelayState"] | undefined,
  now = new Date(),
): ControlPolicyDecision {
  if (command.meterId !== status.meterId) {
    return { allowed: false, code: "METER_MISMATCH", message: "Command meter does not match" };
  }
  if (Date.parse(command.expiresAt) <= now.getTime()) {
    return { allowed: false, code: "EXPIRED_COMMAND", message: "Command has expired" };
  }
  if (inFlightRequestedState && inFlightRequestedState !== command.requestedRelayState) {
    return {
      allowed: false,
      code: "CONFLICTING_COMMAND",
      message: "A conflicting relay command is already in progress",
    };
  }
  if (command.requestedRelayState === "energized" && status.gridState !== "available") {
    return { allowed: false, code: "GRID_UNAVAILABLE", message: "Grid is not available" };
  }
  if (command.requestedRelayState === "energized" && status.overloadActive) {
    return { allowed: false, code: "OVERLOAD_ACTIVE", message: "Overload remains active" };
  }
  return { allowed: true, code: "APPLIED", message: "Command passed the local safety policy" };
}
