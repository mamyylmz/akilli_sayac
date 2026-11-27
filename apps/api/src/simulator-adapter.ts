import type { ControlCommand } from "@akilli-sayac/contracts";

export interface SimulatorAdapterResult {
  status: "pending" | "applied" | "rejected";
  code: "QUEUED_FOR_SIMULINK" | "APPLIED";
  relayState: "energized" | "deenergized" | "unknown";
  message: string;
}

export interface SimulatorAdapter {
  applyRelayCommand(command: ControlCommand): Promise<SimulatorAdapterResult>;
}

/**
 * Local-only placeholder. It never calls MATLAB, hardware, a network, or a third party.
 * The Simulink team must implement the documented file exchange before replacing it.
 */
export class LocalSimulatorAdapter implements SimulatorAdapter {
  async applyRelayCommand(command: ControlCommand): Promise<SimulatorAdapterResult> {
    return Promise.resolve({
      status: "pending",
      code: "QUEUED_FOR_SIMULINK",
      relayState: "unknown",
      message: `Command ${command.commandId} is pending Simulink acknowledgement; no relay was operated`,
    });
  }
}
