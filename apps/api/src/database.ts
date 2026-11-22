import { randomUUID } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";
import type {
  AmiEnvelope,
  CommandResult,
  ControlCommand,
  MeterStatus,
} from "@akilli-sayac/contracts";

interface PacketRow {
  packet_id: string;
}

interface MeterRow {
  id: string;
  relay_state: MeterStatus["relayState"];
  grid_state: MeterStatus["gridState"];
  overload_active: number;
  last_simulation_time: number;
  updated_at: string;
}

interface CommandRow {
  command_id: string;
  requested_state: ControlCommand["requestedRelayState"];
}

interface ResultRow {
  result_json: string;
}

export interface DashboardSnapshot {
  meter: MeterRow | undefined;
  measurement: Record<string, unknown> | undefined;
  energy: Record<string, unknown> | undefined;
  events: Array<Record<string, unknown>>;
}

export class MeterDatabase {
  readonly #database: DatabaseSync;

  constructor(path: string) {
    if (path !== ":memory:") mkdirSync(dirname(path), { recursive: true });
    this.#database = new DatabaseSync(path);
    this.#database.exec(
      "PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;",
    );
    this.#migrate();
  }

  #migrate(): void {
    this.#database.exec(`
      CREATE TABLE IF NOT EXISTS meters (
        id TEXT PRIMARY KEY,
        relay_state TEXT NOT NULL DEFAULT 'unknown',
        grid_state TEXT NOT NULL DEFAULT 'unknown',
        overload_active INTEGER NOT NULL DEFAULT 0 CHECK (overload_active IN (0, 1)),
        last_sequence INTEGER,
        last_simulation_time REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS ami_packets (
        packet_id TEXT PRIMARY KEY,
        meter_id TEXT NOT NULL REFERENCES meters(id),
        sequence INTEGER NOT NULL,
        received_at TEXT NOT NULL,
        UNIQUE (meter_id, sequence)
      );

      CREATE TABLE IF NOT EXISTS measurements (
        id TEXT PRIMARY KEY,
        packet_id TEXT NOT NULL UNIQUE REFERENCES ami_packets(packet_id),
        meter_id TEXT NOT NULL REFERENCES meters(id),
        sequence INTEGER NOT NULL,
        simulation_time_hours REAL NOT NULL,
        exported_at TEXT NOT NULL,
        voltage_rms_v REAL NOT NULL,
        current_rms_a REAL NOT NULL,
        active_power_w REAL NOT NULL,
        reactive_power_var REAL NOT NULL,
        apparent_power_va REAL NOT NULL,
        displacement_power_factor REAL NOT NULL,
        true_power_factor REAL NOT NULL,
        description TEXT
      );

      CREATE INDEX IF NOT EXISTS measurements_meter_sequence
        ON measurements(meter_id, sequence);
      CREATE INDEX IF NOT EXISTS measurements_meter_simulation_time
        ON measurements(meter_id, simulation_time_hours);

      CREATE TABLE IF NOT EXISTS energy_readings (
        id TEXT PRIMARY KEY,
        packet_id TEXT NOT NULL UNIQUE REFERENCES ami_packets(packet_id),
        meter_id TEXT NOT NULL REFERENCES meters(id),
        simulation_time_hours REAL NOT NULL,
        total_active_kwh REAL NOT NULL,
        t1_kwh REAL NOT NULL,
        t2_kwh REAL NOT NULL,
        t3_kwh REAL NOT NULL,
        inductive_kvarh REAL NOT NULL,
        capacitive_kvarh REAL NOT NULL
      );

      CREATE INDEX IF NOT EXISTS energy_meter_simulation_time
        ON energy_readings(meter_id, simulation_time_hours);

      CREATE TABLE IF NOT EXISTS meter_events (
        id TEXT PRIMARY KEY,
        packet_id TEXT NOT NULL REFERENCES ami_packets(packet_id),
        meter_id TEXT NOT NULL REFERENCES meters(id),
        simulation_time_hours REAL NOT NULL,
        event_type TEXT NOT NULL,
        severity TEXT NOT NULL,
        message TEXT NOT NULL,
        exported_at TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS events_meter_time ON meter_events(meter_id, exported_at DESC);

      CREATE TABLE IF NOT EXISTS control_commands (
        command_id TEXT PRIMARY KEY,
        meter_id TEXT NOT NULL REFERENCES meters(id),
        actor_id TEXT NOT NULL,
        requested_state TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('pending', 'completed'))
      );

      CREATE TABLE IF NOT EXISTS command_results (
        id TEXT PRIMARY KEY,
        command_id TEXT NOT NULL UNIQUE REFERENCES control_commands(command_id),
        meter_id TEXT NOT NULL REFERENCES meters(id),
        completed_at TEXT NOT NULL,
        outcome TEXT NOT NULL,
        code TEXT NOT NULL,
        relay_state TEXT NOT NULL,
        message TEXT NOT NULL,
        result_json TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS tariff_configs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        valid_from TEXT NOT NULL,
        valid_until TEXT,
        demonstration INTEGER NOT NULL CHECK (demonstration IN (0, 1)),
        config_json TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS audit_events (
        id TEXT PRIMARY KEY,
        meter_id TEXT,
        actor_id TEXT,
        action TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        details_json TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS audit_occurred_at ON audit_events(occurred_at DESC);
    `);
  }

  ensureMeter(meterId: string, now = new Date().toISOString()): void {
    this.#database
      .prepare(
        `INSERT INTO meters (id, created_at, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(id) DO NOTHING`,
      )
      .run(meterId, now, now);
  }

  ingestEnvelope(envelope: AmiEnvelope): { inserted: boolean; existingPacketId?: string } {
    const existing = this.#database
      .prepare(
        `SELECT packet_id FROM ami_packets
         WHERE packet_id = ? OR (meter_id = ? AND sequence = ?)
         LIMIT 1`,
      )
      .get(envelope.packetId, envelope.meterId, envelope.sequence) as PacketRow | undefined;
    if (existing) return { inserted: false, existingPacketId: existing.packet_id };

    const receivedAt = new Date().toISOString();
    this.#database.exec("BEGIN IMMEDIATE");
    try {
      this.ensureMeter(envelope.meterId, receivedAt);
      this.#database
        .prepare(
          `INSERT INTO ami_packets (packet_id, meter_id, sequence, received_at)
           VALUES (?, ?, ?, ?)`,
        )
        .run(envelope.packetId, envelope.meterId, envelope.sequence, receivedAt);

      const measurement = envelope.measurement;
      this.#database
        .prepare(
          `INSERT INTO measurements (
             id, packet_id, meter_id, sequence, simulation_time_hours, exported_at,
             voltage_rms_v, current_rms_a, active_power_w, reactive_power_var,
             apparent_power_va, displacement_power_factor, true_power_factor, description
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          measurement.id,
          envelope.packetId,
          envelope.meterId,
          envelope.sequence,
          envelope.simulationTimeHours,
          measurement.exportedAt,
          measurement.voltageRmsV,
          measurement.currentRmsA,
          measurement.activePowerW,
          measurement.reactivePowerVar,
          measurement.apparentPowerVa,
          measurement.displacementPowerFactor,
          measurement.truePowerFactor,
          measurement.description ?? null,
        );

      this.#database
        .prepare(
          `INSERT INTO energy_readings (
             id, packet_id, meter_id, simulation_time_hours, total_active_kwh,
             t1_kwh, t2_kwh, t3_kwh, inductive_kvarh, capacitive_kvarh
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          envelope.energy.id,
          envelope.packetId,
          envelope.meterId,
          envelope.simulationTimeHours,
          envelope.energy.totalActiveEnergyKWh,
          envelope.tariff.t1KWh,
          envelope.tariff.t2KWh,
          envelope.tariff.t3KWh,
          envelope.energy.inductiveReactiveEnergyKvarh,
          envelope.energy.capacitiveReactiveEnergyKvarh,
        );

      const insertEvent = this.#database.prepare(
        `INSERT INTO meter_events (
           id, packet_id, meter_id, simulation_time_hours, event_type, severity, message, exported_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      );
      for (const event of envelope.events) {
        insertEvent.run(
          event.id,
          envelope.packetId,
          envelope.meterId,
          event.simulationTimeHours,
          event.eventType,
          event.severity,
          event.message,
          event.exportedAt,
        );
      }

      this.#database
        .prepare(
          `UPDATE meters SET relay_state = ?, grid_state = ?, overload_active = ?,
             last_sequence = ?, last_simulation_time = ?, updated_at = ? WHERE id = ?`,
        )
        .run(
          envelope.status.relayState,
          envelope.status.gridState,
          envelope.status.overloadActive ? 1 : 0,
          envelope.sequence,
          envelope.simulationTimeHours,
          receivedAt,
          envelope.meterId,
        );
      this.#insertAudit(envelope.meterId, null, "ami.imported", receivedAt, {
        packetId: envelope.packetId,
        sequence: envelope.sequence,
      });
      this.#database.exec("COMMIT");
      return { inserted: true };
    } catch (error) {
      this.#database.exec("ROLLBACK");
      throw error;
    }
  }

  getMeterStatus(meterId: string): MeterStatus | undefined {
    const row = this.#database.prepare("SELECT * FROM meters WHERE id = ?").get(meterId) as
      MeterRow | undefined;
    if (!row) return undefined;
    return {
      schemaVersion: "1.0.0",
      id: randomUUID(),
      meterId: row.id,
      simulationTimeHours: row.last_simulation_time,
      exportedAt: row.updated_at,
      provenance: { kind: "simulated", trusted: true },
      relayState: row.relay_state,
      gridState: row.grid_state,
      overloadActive: row.overload_active === 1,
    };
  }

  dashboard(meterId: string): DashboardSnapshot {
    const meter = this.#database.prepare("SELECT * FROM meters WHERE id = ?").get(meterId) as
      MeterRow | undefined;
    const measurement = this.#database
      .prepare("SELECT * FROM measurements WHERE meter_id = ? ORDER BY sequence DESC LIMIT 1")
      .get(meterId) as Record<string, unknown> | undefined;
    const energy = this.#database
      .prepare(
        "SELECT * FROM energy_readings WHERE meter_id = ? ORDER BY simulation_time_hours DESC LIMIT 1",
      )
      .get(meterId) as Record<string, unknown> | undefined;
    const events = this.#database
      .prepare("SELECT * FROM meter_events WHERE meter_id = ? ORDER BY exported_at DESC LIMIT 50")
      .all(meterId) as Array<Record<string, unknown>>;
    return { meter, measurement, energy, events };
  }

  findCommandResult(commandId: string): CommandResult | undefined {
    const row = this.#database
      .prepare("SELECT result_json FROM command_results WHERE command_id = ?")
      .get(commandId) as ResultRow | undefined;
    return row ? (JSON.parse(row.result_json) as CommandResult) : undefined;
  }

  beginCommand(command: ControlCommand): boolean {
    const existing = this.#database
      .prepare("SELECT command_id FROM control_commands WHERE command_id = ?")
      .get(command.commandId) as CommandRow | undefined;
    if (existing) return false;
    this.ensureMeter(command.meterId, command.createdAt);
    this.#database.exec("BEGIN IMMEDIATE");
    try {
      this.#database
        .prepare(
          `INSERT INTO control_commands (
             command_id, meter_id, actor_id, requested_state, reason, created_at, expires_at, status
           ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')`,
        )
        .run(
          command.commandId,
          command.meterId,
          command.actorId,
          command.requestedRelayState,
          command.reason,
          command.createdAt,
          command.expiresAt,
        );
      this.#insertAudit(
        command.meterId,
        command.actorId,
        "relay.command.created",
        command.createdAt,
        {
          commandId: command.commandId,
          requestedRelayState: command.requestedRelayState,
        },
      );
      this.#database.exec("COMMIT");
      return true;
    } catch (error) {
      this.#database.exec("ROLLBACK");
      throw error;
    }
  }

  inFlightRelayState(
    meterId: string,
    excludingCommandId: string,
  ): ControlCommand["requestedRelayState"] | undefined {
    const row = this.#database
      .prepare(
        `SELECT command_id, requested_state FROM control_commands
         WHERE meter_id = ? AND status = 'pending' AND command_id <> ?
         ORDER BY created_at LIMIT 1`,
      )
      .get(meterId, excludingCommandId) as CommandRow | undefined;
    return row?.requested_state;
  }

  completeCommand(command: ControlCommand, result: CommandResult): void {
    this.#database.exec("BEGIN IMMEDIATE");
    try {
      this.#database
        .prepare(
          `INSERT INTO command_results (
             id, command_id, meter_id, completed_at, outcome, code, relay_state, message, result_json
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          result.id,
          command.commandId,
          command.meterId,
          result.completedAt,
          result.outcome,
          result.code,
          result.relayState,
          result.message,
          JSON.stringify(result),
        );
      this.#database
        .prepare("UPDATE control_commands SET status = 'completed' WHERE command_id = ?")
        .run(command.commandId);
      if (result.outcome === "accepted") {
        this.#database
          .prepare("UPDATE meters SET relay_state = ?, updated_at = ? WHERE id = ?")
          .run(result.relayState, result.completedAt, command.meterId);
      }
      this.#insertAudit(
        command.meterId,
        command.actorId,
        "relay.command.completed",
        result.completedAt,
        {
          commandId: command.commandId,
          code: result.code,
          outcome: result.outcome,
        },
      );
      this.#database.exec("COMMIT");
    } catch (error) {
      this.#database.exec("ROLLBACK");
      throw error;
    }
  }

  listAudit(limit = 100): Array<Record<string, unknown>> {
    const safeLimit = Math.max(1, Math.min(500, Math.trunc(limit)));
    return this.#database
      .prepare("SELECT * FROM audit_events ORDER BY occurred_at DESC LIMIT ?")
      .all(safeLimit);
  }

  #insertAudit(
    meterId: string | null,
    actorId: string | null,
    action: string,
    occurredAt: string,
    details: Record<string, unknown>,
  ): void {
    this.#database
      .prepare(
        `INSERT INTO audit_events (id, meter_id, actor_id, action, occurred_at, details_json)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .run(randomUUID(), meterId, actorId, action, occurredAt, JSON.stringify(details));
  }

  close(): void {
    this.#database.close();
  }
}
