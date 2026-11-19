import type { ControlCommand } from "@akilli-sayac/contracts";

export interface SimulatorAdapterResult {
  relayState: "energized" | "deenergized";
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
      relayState: command.requestedRelayState,
      message: "Accepted by the local simulator adapter; no physical relay was operated",
    });
  }
}
