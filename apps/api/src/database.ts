import { randomUUID } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";
import {
  calculateBill,
  tariffConfigSchema,
  type BillResult,
  type TariffConfig,
} from "@akilli-sayac/billing";
import type {
  AmiEnvelope,
  CommandResult,
  ControlCommand,
  MeterStatus,
} from "@akilli-sayac/contracts";
import type { SimulinkImportPackage } from "./simulink-import.js";

export const DEFAULT_DEMO_TARIFF_ID = "00000000-0000-4000-8000-000000000001";

const DEFAULT_DEMO_TARIFF: TariffConfig = tariffConfigSchema.parse({
  id: DEFAULT_DEMO_TARIFF_ID,
  name: "Yerel demonstrasyon üç zamanlı tarife",
  currency: "TRY",
  validFrom: "2020-01-01T00:00:00+03:00",
  demonstration: true,
  pricesMicroliraPerKWh: {
    t1: 2_500_000,
    t2: 3_500_000,
    t3: 1_750_000,
    distribution: 1_000_000,
  },
  taxes: [{ code: "DEMO_VERGI", rateBasisPoints: 2_000 }],
});

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
  run?: Record<string, unknown>;
  billing?: Record<string, unknown>;
}

export interface SimulationImportResult {
  inserted: boolean;
  runId: string;
  measurements: number;
  events: number;
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

      CREATE TABLE IF NOT EXISTS simulation_runs (
        run_id TEXT PRIMARY KEY,
        meter_id TEXT NOT NULL REFERENCES meters(id),
        schema_version TEXT NOT NULL,
        data_type TEXT NOT NULL CHECK (data_type IN ('model', 'test')),
        is_fixture INTEGER NOT NULL CHECK (is_fixture IN (0, 1)),
        day TEXT NOT NULL,
        timezone TEXT NOT NULL,
        interval_minutes INTEGER NOT NULL CHECK (interval_minutes = 1),
        measurement_count INTEGER NOT NULL,
        event_count INTEGER NOT NULL,
        source TEXT NOT NULL,
        trusted_source INTEGER NOT NULL DEFAULT 0 CHECK (trusted_source = 0),
        metadata_filename TEXT NOT NULL,
        measurement_sha256 TEXT NOT NULL,
        events_sha256 TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        imported_by TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS simulation_runs_meter_day
        ON simulation_runs(meter_id, day DESC, imported_at DESC);

      CREATE TABLE IF NOT EXISTS simulation_measurements (
        run_id TEXT NOT NULL REFERENCES simulation_runs(run_id) ON DELETE CASCADE,
        meter_id TEXT NOT NULL REFERENCES meters(id),
        measured_at TEXT NOT NULL,
        minute INTEGER NOT NULL CHECK (minute BETWEEN 0 AND 1439),
        tariff_period INTEGER NOT NULL CHECK (tariff_period BETWEEN 1 AND 3),
        valid INTEGER NOT NULL CHECK (valid IN (0, 1)),
        voltage_rms_v REAL NOT NULL,
        current_rms_a REAL NOT NULL,
        active_power_w REAL NOT NULL,
        reactive_power_var REAL NOT NULL,
        apparent_power_va REAL NOT NULL,
        cos_phi REAL NOT NULL,
        interval_energy_kwh REAL NOT NULL,
        total_energy_kwh REAL NOT NULL,
        t1_kwh REAL NOT NULL,
        t2_kwh REAL NOT NULL,
        t3_kwh REAL NOT NULL,
        inductive_kvarh REAL NOT NULL,
        capacitive_kvarh REAL NOT NULL,
        relay_command INTEGER NOT NULL CHECK (relay_command IN (0, 1)),
        relay_closed INTEGER NOT NULL CHECK (relay_closed IN (0, 1)),
        meter_status INTEGER NOT NULL CHECK (meter_status BETWEEN 0 AND 5),
        overload_warning INTEGER NOT NULL CHECK (overload_warning IN (0, 1)),
        event_count INTEGER NOT NULL,
        battery_power_w REAL NOT NULL,
        state_of_charge REAL NOT NULL,
        battery_mode INTEGER NOT NULL CHECK (battery_mode BETWEEN 0 AND 2),
        PRIMARY KEY (run_id, measured_at),
        UNIQUE (run_id, minute)
      );

      CREATE INDEX IF NOT EXISTS simulation_measurements_meter_time
        ON simulation_measurements(meter_id, measured_at);

      CREATE TABLE IF NOT EXISTS simulation_run_energy (
        run_id TEXT PRIMARY KEY REFERENCES simulation_runs(run_id) ON DELETE CASCADE,
        meter_id TEXT NOT NULL REFERENCES meters(id),
        total_kwh REAL NOT NULL,
        t1_kwh REAL NOT NULL,
        t2_kwh REAL NOT NULL,
        t3_kwh REAL NOT NULL,
        inductive_kvarh REAL NOT NULL,
        capacitive_kvarh REAL NOT NULL
      );

      CREATE TABLE IF NOT EXISTS simulation_events (
        id TEXT PRIMARY KEY,
        run_id TEXT NOT NULL REFERENCES simulation_runs(run_id) ON DELETE CASCADE,
        meter_id TEXT NOT NULL REFERENCES meters(id),
        occurred_at TEXT NOT NULL,
        decimal_hour REAL NOT NULL,
        event_code INTEGER NOT NULL,
        event_name TEXT NOT NULL,
        meter_status INTEGER NOT NULL,
        rejection_mask INTEGER NOT NULL,
        rejection_reason TEXT NOT NULL,
        UNIQUE (run_id, occurred_at, event_code)
      );

      CREATE INDEX IF NOT EXISTS simulation_events_run_time
        ON simulation_events(run_id, occurred_at DESC);

      CREATE TABLE IF NOT EXISTS active_simulation_runs (
        meter_id TEXT PRIMARY KEY REFERENCES meters(id),
        run_id TEXT NOT NULL REFERENCES simulation_runs(run_id),
        selected_at TEXT NOT NULL,
        selected_by TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS control_commands (
        command_id TEXT PRIMARY KEY,
        meter_id TEXT NOT NULL REFERENCES meters(id),
        actor_id TEXT NOT NULL,
        requested_state TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('pending', 'completed')),
        protocol_status TEXT NOT NULL DEFAULT 'accepted'
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

      CREATE TABLE IF NOT EXISTS billing_snapshots (
        run_id TEXT NOT NULL REFERENCES simulation_runs(run_id),
        tariff_id TEXT NOT NULL REFERENCES tariff_configs(id),
        calculated_at TEXT NOT NULL,
        period_started_at TEXT NOT NULL,
        t1_wh INTEGER NOT NULL,
        t2_wh INTEGER NOT NULL,
        t3_wh INTEGER NOT NULL,
        excluded_net_export_wh INTEGER NOT NULL,
        tariff_config_json TEXT NOT NULL,
        bill_json TEXT NOT NULL,
        PRIMARY KEY (run_id, tariff_id)
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
    const commandColumns = this.#database
      .prepare("PRAGMA table_info(control_commands)")
      .all() as Array<{
      name: string;
    }>;
    if (!commandColumns.some((column) => column.name === "protocol_status")) {
      this.#database.exec(
        "ALTER TABLE control_commands ADD COLUMN protocol_status TEXT NOT NULL DEFAULT 'accepted'",
      );
    }
    this.saveTariff(DEFAULT_DEMO_TARIFF);
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

  ingestSimulinkPackage(imported: SimulinkImportPackage, actorId: string): SimulationImportResult {
    const { metadata } = imported;
    const existing = this.#database
      .prepare("SELECT run_id FROM simulation_runs WHERE run_id = ?")
      .get(metadata.run_id);
    if (existing) {
      return {
        inserted: false,
        runId: metadata.run_id,
        measurements: 0,
        events: 0,
      };
    }
    const importedAt = new Date().toISOString();
    this.ensureMeter(metadata.sayac_id, importedAt);
    this.#database.exec("BEGIN IMMEDIATE");
    try {
      this.#database
        .prepare(
          `INSERT INTO simulation_runs (
             run_id, meter_id, schema_version, data_type, is_fixture, day, timezone,
             interval_minutes, measurement_count, event_count, source, trusted_source,
             metadata_filename, measurement_sha256, events_sha256, metadata_json,
             imported_at, imported_by
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          metadata.run_id,
          metadata.sayac_id,
          metadata.sema_surumu,
          metadata.veri_turu,
          imported.fixture ? 1 : 0,
          metadata.gun,
          metadata.saat_dilimi,
          metadata.aralik_dk,
          imported.measurements.length,
          imported.events.length,
          metadata.kaynak,
          imported.metadataFileName,
          imported.measurementSha256,
          imported.eventsSha256,
          imported.metadataJson,
          importedAt,
          actorId,
        );

      const insertMeasurement = this.#database.prepare(
        `INSERT INTO simulation_measurements (
           run_id, meter_id, measured_at, minute, tariff_period, valid,
           voltage_rms_v, current_rms_a, active_power_w, reactive_power_var,
           apparent_power_va, cos_phi, interval_energy_kwh, total_energy_kwh,
           t1_kwh, t2_kwh, t3_kwh, inductive_kvarh, capacitive_kvarh,
           relay_command, relay_closed, meter_status, overload_warning, event_count,
           battery_power_w, state_of_charge, battery_mode
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      );
      for (const row of imported.measurements) {
        insertMeasurement.run(
          row.runId,
          row.meterId,
          row.timestamp,
          row.minute,
          row.tariffPeriod,
          row.valid ? 1 : 0,
          row.voltageRmsV,
          row.currentRmsA,
          row.activePowerW,
          row.reactivePowerVar,
          row.apparentPowerVa,
          row.cosPhi,
          row.intervalEnergyKWh,
          row.totalEnergyKWh,
          row.t1KWh,
          row.t2KWh,
          row.t3KWh,
          row.inductiveKvarh,
          row.capacitiveKvarh,
          row.relayCommand ? 1 : 0,
          row.relayClosed ? 1 : 0,
          row.status,
          row.overloadWarning ? 1 : 0,
          row.eventCount,
          row.batteryPowerW,
          row.stateOfCharge,
          row.batteryMode,
        );
      }

      const insertEvent = this.#database.prepare(
        `INSERT INTO simulation_events (
           id, run_id, meter_id, occurred_at, decimal_hour, event_code, event_name,
           meter_status, rejection_mask, rejection_reason
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      );
      for (const event of imported.events) {
        insertEvent.run(
          randomUUID(),
          event.runId,
          event.meterId,
          event.timestamp,
          event.decimalHour,
          event.code,
          event.name,
          event.status,
          event.rejectionMask,
          event.rejectionReason,
        );
      }

      const last = imported.measurements.at(-1);
      if (!last) throw new Error("Validated Simulink package has no measurements");
      this.#database
        .prepare(
          `INSERT INTO simulation_run_energy (
             run_id, meter_id, total_kwh, t1_kwh, t2_kwh, t3_kwh,
             inductive_kvarh, capacitive_kvarh
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          metadata.run_id,
          metadata.sayac_id,
          last.totalEnergyKWh,
          last.t1KWh,
          last.t2KWh,
          last.t3KWh,
          last.inductiveKvarh,
          last.capacitiveKvarh,
        );
      this.#database
        .prepare(
          `INSERT INTO active_simulation_runs (meter_id, run_id, selected_at, selected_by)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(meter_id) DO UPDATE SET
             run_id = excluded.run_id,
             selected_at = excluded.selected_at,
             selected_by = excluded.selected_by`,
        )
        .run(metadata.sayac_id, metadata.run_id, importedAt, actorId);
      this.#database
        .prepare(
          `UPDATE meters SET relay_state = ?, grid_state = ?, overload_active = ?,
             last_simulation_time = ?, updated_at = ? WHERE id = ?`,
        )
        .run(
          last.relayClosed ? "energized" : "deenergized",
          last.status === 4 ? "unavailable" : "available",
          last.overloadWarning ? 1 : 0,
          last.minute / 60,
          importedAt,
          metadata.sayac_id,
        );
      this.#insertAudit(metadata.sayac_id, actorId, "simulink.run.imported", importedAt, {
        runId: metadata.run_id,
        fixture: imported.fixture,
        measurementCount: imported.measurements.length,
        eventCount: imported.events.length,
        trustedPhysicalSource: false,
      });
      this.#database.exec("COMMIT");
    } catch (error) {
      this.#database.exec("ROLLBACK");
      throw error;
    }
    this.calculateRunBill(metadata.run_id, DEFAULT_DEMO_TARIFF_ID);
    return {
      inserted: true,
      runId: metadata.run_id,
      measurements: imported.measurements.length,
      events: imported.events.length,
    };
  }

  recordImportFailure(meterId: string, actorId: string, fileName: string, code: string): void {
    this.#insertAudit(meterId, actorId, "simulink.run.rejected", new Date().toISOString(), {
      metadataFileName: fileName,
      code,
    });
  }

  listSimulationRuns(meterId: string): Array<Record<string, unknown>> {
    return this.#database
      .prepare(
        `SELECT r.run_id, r.meter_id, r.schema_version, r.data_type, r.is_fixture,
                r.day, r.measurement_count, r.event_count, r.source, r.trusted_source,
                r.imported_at, CASE WHEN a.run_id = r.run_id THEN 1 ELSE 0 END AS active
         FROM simulation_runs r
         LEFT JOIN active_simulation_runs a ON a.meter_id = r.meter_id
         WHERE r.meter_id = ?
         ORDER BY r.day DESC, r.imported_at DESC`,
      )
      .all(meterId);
  }

  selectSimulationRun(meterId: string, runId: string, actorId: string): boolean {
    const exists = this.#database
      .prepare("SELECT run_id FROM simulation_runs WHERE run_id = ? AND meter_id = ?")
      .get(runId, meterId);
    if (!exists) return false;
    const now = new Date().toISOString();
    this.#database
      .prepare(
        `INSERT INTO active_simulation_runs (meter_id, run_id, selected_at, selected_by)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(meter_id) DO UPDATE SET
           run_id = excluded.run_id, selected_at = excluded.selected_at,
           selected_by = excluded.selected_by`,
      )
      .run(meterId, runId, now, actorId);
    this.#insertAudit(meterId, actorId, "simulink.run.selected", now, { runId });
    return true;
  }

  simulationSeries(runId: string, bucketMinutes: 1 | 15 | 60): Array<Record<string, unknown>> {
    return this.#database
      .prepare(
        `SELECT MIN(measured_at) AS measured_at,
                CAST(minute / ? AS INTEGER) * ? AS minute,
                SUM(CASE WHEN valid = 1 THEN 1 ELSE 0 END) AS valid_count,
                SUM(CASE WHEN valid = 0 THEN 1 ELSE 0 END) AS invalid_count,
                AVG(CASE WHEN valid = 1 THEN voltage_rms_v END) AS voltage_rms_v,
                AVG(CASE WHEN valid = 1 THEN current_rms_a END) AS current_rms_a,
                AVG(CASE WHEN valid = 1 THEN active_power_w END) AS active_power_w,
                AVG(CASE WHEN valid = 1 THEN reactive_power_var END) AS reactive_power_var,
                AVG(CASE WHEN valid = 1 THEN apparent_power_va END) AS apparent_power_va,
                SUM(interval_energy_kwh) AS interval_energy_kwh,
                MAX(overload_warning) AS overload_warning,
                AVG(battery_power_w) AS battery_power_w,
                AVG(state_of_charge) AS state_of_charge
         FROM simulation_measurements
         WHERE run_id = ?
         GROUP BY CAST(minute / ? AS INTEGER)
         ORDER BY minute`,
      )
      .all(bucketMinutes, bucketMinutes, runId, bucketMinutes);
  }

  saveTariff(value: TariffConfig): boolean {
    const tariff = tariffConfigSchema.parse(value);
    const result = this.#database
      .prepare(
        `INSERT INTO tariff_configs (
           id, name, valid_from, valid_until, demonstration, config_json
         ) VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO NOTHING`,
      )
      .run(
        tariff.id,
        tariff.name,
        tariff.validFrom,
        tariff.validUntil ?? null,
        tariff.demonstration ? 1 : 0,
        JSON.stringify(tariff),
      );
    return result.changes === 1;
  }

  listTariffs(): TariffConfig[] {
    const rows = this.#database
      .prepare("SELECT config_json FROM tariff_configs ORDER BY valid_from DESC, name")
      .all() as Array<{ config_json: string }>;
    return rows.map((row) => tariffConfigSchema.parse(JSON.parse(row.config_json) as unknown));
  }

  calculateRunBill(runId: string, tariffId: string): Record<string, unknown> {
    const existing = this.#database
      .prepare("SELECT * FROM billing_snapshots WHERE run_id = ? AND tariff_id = ?")
      .get(runId, tariffId) as Record<string, unknown> | undefined;
    if (existing)
      return { ...existing, bill: JSON.parse(String(existing.bill_json)) as BillResult };
    const run = this.#database
      .prepare(
        `SELECT r.day, e.t1_kwh, e.t2_kwh, e.t3_kwh
         FROM simulation_runs r JOIN simulation_run_energy e ON e.run_id = r.run_id
         WHERE r.run_id = ?`,
      )
      .get(runId) as { day: string; t1_kwh: number; t2_kwh: number; t3_kwh: number } | undefined;
    const tariffRow = this.#database
      .prepare("SELECT config_json FROM tariff_configs WHERE id = ?")
      .get(tariffId) as { config_json: string } | undefined;
    if (!run || !tariffRow) throw new Error("Run or tariff was not found");
    const tariff = tariffConfigSchema.parse(JSON.parse(tariffRow.config_json) as unknown);
    const rawWh = [run.t1_kwh, run.t2_kwh, run.t3_kwh].map((value) => Math.round(value * 1000));
    const billableWh = rawWh.map((value) => Math.max(0, value));
    const excludedNetExportWh = rawWh.reduce((sum, value) => sum + Math.max(0, -value), 0);
    const periodStartedAt = `${run.day}T00:00:00+03:00`;
    const bill = calculateBill(
      {
        t1Wh: billableWh[0] ?? 0,
        t2Wh: billableWh[1] ?? 0,
        t3Wh: billableWh[2] ?? 0,
        periodStartedAt,
      },
      tariff,
    );
    const calculatedAt = new Date().toISOString();
    this.#database
      .prepare(
        `INSERT INTO billing_snapshots (
           run_id, tariff_id, calculated_at, period_started_at, t1_wh, t2_wh, t3_wh,
           excluded_net_export_wh, tariff_config_json, bill_json
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        runId,
        tariffId,
        calculatedAt,
        periodStartedAt,
        billableWh[0] ?? 0,
        billableWh[1] ?? 0,
        billableWh[2] ?? 0,
        excludedNetExportWh,
        JSON.stringify(tariff),
        JSON.stringify(bill),
      );
    return {
      run_id: runId,
      tariff_id: tariffId,
      calculated_at: calculatedAt,
      period_started_at: periodStartedAt,
      t1_wh: billableWh[0] ?? 0,
      t2_wh: billableWh[1] ?? 0,
      t3_wh: billableWh[2] ?? 0,
      excluded_net_export_wh: excludedNetExportWh,
      tariff_config_json: JSON.stringify(tariff),
      bill_json: JSON.stringify(bill),
      bill,
    };
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

  dashboard(meterId: string, requestedRunId?: string): DashboardSnapshot {
    const selectedRun = requestedRunId
      ? this.#database
          .prepare("SELECT * FROM simulation_runs WHERE run_id = ? AND meter_id = ?")
          .get(requestedRunId, meterId)
      : this.#database
          .prepare(
            `SELECT r.* FROM simulation_runs r
             JOIN active_simulation_runs a ON a.run_id = r.run_id
             WHERE a.meter_id = ?`,
          )
          .get(meterId);
    if (selectedRun) {
      const run = selectedRun as Record<string, unknown>;
      const runId = String(run.run_id);
      const measurement = this.#database
        .prepare(
          `SELECT * FROM simulation_measurements
           WHERE run_id = ? ORDER BY minute DESC LIMIT 1`,
        )
        .get(runId) as Record<string, unknown> | undefined;
      const energy = this.#database
        .prepare("SELECT * FROM simulation_run_energy WHERE run_id = ?")
        .get(runId) as Record<string, unknown> | undefined;
      const events = this.#database
        .prepare(
          "SELECT * FROM simulation_events WHERE run_id = ? ORDER BY occurred_at DESC LIMIT 100",
        )
        .all(runId) as Array<Record<string, unknown>>;
      const billingRow = this.#database
        .prepare(
          `SELECT * FROM billing_snapshots WHERE run_id = ?
           ORDER BY calculated_at DESC LIMIT 1`,
        )
        .get(runId) as Record<string, unknown> | undefined;
      const meter = this.#database.prepare("SELECT * FROM meters WHERE id = ?").get(meterId) as
        MeterRow | undefined;
      const billing = billingRow
        ? {
            ...billingRow,
            tariff: JSON.parse(String(billingRow.tariff_config_json)) as unknown,
            bill: JSON.parse(String(billingRow.bill_json)) as unknown,
          }
        : undefined;
      return {
        meter,
        measurement,
        energy,
        events,
        run,
        ...(billing ? { billing } : {}),
      };
    }
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

  commandStatus(commandId: string): Record<string, unknown> | undefined {
    return this.#database
      .prepare(
        `SELECT c.command_id, c.meter_id, c.actor_id, c.requested_state, c.reason,
                c.created_at, c.expires_at, c.protocol_status,
                r.completed_at, r.code, r.relay_state, r.message
         FROM control_commands c
         LEFT JOIN command_results r ON r.command_id = c.command_id
         WHERE c.command_id = ?`,
      )
      .get(commandId);
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
             command_id, meter_id, actor_id, requested_state, reason, created_at, expires_at,
             status, protocol_status
           ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', 'accepted')`,
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
        .prepare(
          "UPDATE control_commands SET status = 'completed', protocol_status = ? WHERE command_id = ?",
        )
        .run(result.outcome, command.commandId);
      if (result.outcome === "applied") {
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
