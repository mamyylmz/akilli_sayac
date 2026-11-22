import { createHash } from "node:crypto";
import { parse } from "csv-parse/sync";
import { z } from "zod";
import { readLimitedImportFile } from "./file-import.js";

const MEASUREMENT_COLUMNS = [
  "sayac_id",
  "run_id",
  "zaman",
  "dakika",
  "tarife_dilimi",
  "gecerli",
  "v_rms_V",
  "i_rms_A",
  "p_W",
  "q_var",
  "s_VA",
  "cos_phi",
  "e_aralik_kWh",
  "e_toplam_kWh",
  "e_t1_kWh",
  "e_t2_kWh",
  "e_t3_kWh",
  "e_rend_kvarh",
  "e_rkap_kvarh",
  "role_komut",
  "role",
  "durum",
  "asiri_guc_uyari",
  "olay_sayisi",
  "p_bat_W",
  "soc",
  "batarya_mod",
] as const;

const EVENT_COLUMNS = [
  "sayac_id",
  "run_id",
  "zaman",
  "saat",
  "olay_kodu",
  "olay",
  "durum",
  "red_maske",
  "red_nedeni",
] as const;

const eventCodes = new Set([10, 11, 20, 30, 31, 40, 41, 42, 43, 50, 51]);
const runIdPattern = /^SIM-[0-9]{4}-[0-9]{8}T[0-9]{6}-[0-9A-F]{8}$/;
const timestampPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?\+03:00$/;

const metadataSchema = z
  .object({
    sema_surumu: z.literal("1.0"),
    run_id: z.string().regex(runIdPattern),
    veri_turu: z.enum(["model", "test"]),
    kaynak: z.string().min(1).max(512),
    sayac_id: z.string().regex(/^SIM-[0-9]{4}$/),
    gun: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    saat_dilimi: z.literal("+03:00"),
    aralik_dk: z.literal(1),
    satir_sayisi: z.number().int().min(1).max(1440),
    olay_sayisi: z.number().int().min(0).max(20_000),
    dosyalar: z
      .object({
        olcum: z.string().regex(/^[a-zA-Z0-9][a-zA-Z0-9._-]*\.csv$/),
        olcum_sha256: z.string().regex(/^[0-9a-f]{64}$/),
        olaylar: z.string().regex(/^[a-zA-Z0-9][a-zA-Z0-9._-]*\.csv$/),
        olaylar_sha256: z.string().regex(/^[0-9a-f]{64}$/),
      })
      .strict(),
    sutunlar: z.array(z.object({ ad: z.string() }).passthrough()).length(27),
    kontroller: z
      .array(
        z
          .object({ kontrol: z.string().min(1), gecti: z.boolean(), deger: z.unknown() })
          .passthrough(),
      )
      .min(1),
    gunluk_toplam: z
      .object({
        e_toplam_kWh: z.number().finite(),
        e_t1_kWh: z.number().finite(),
        e_t2_kWh: z.number().finite(),
        e_t3_kWh: z.number().finite(),
        e_rend_kvarh: z.number().finite().min(0),
        e_rkap_kvarh: z.number().finite().min(0),
      })
      .passthrough()
      .optional(),
    ornek: z.unknown().optional(),
  })
  .passthrough();

export type SimulinkMetadata = z.infer<typeof metadataSchema>;

export interface SimulinkMeasurement {
  meterId: string;
  runId: string;
  timestamp: string;
  minute: number;
  tariffPeriod: 1 | 2 | 3;
  valid: boolean;
  voltageRmsV: number;
  currentRmsA: number;
  activePowerW: number;
  reactivePowerVar: number;
  apparentPowerVa: number;
  cosPhi: number;
  intervalEnergyKWh: number;
  totalEnergyKWh: number;
  t1KWh: number;
  t2KWh: number;
  t3KWh: number;
  inductiveKvarh: number;
  capacitiveKvarh: number;
  relayCommand: boolean;
  relayClosed: boolean;
  status: number;
  overloadWarning: boolean;
  eventCount: number;
  batteryPowerW: number;
  stateOfCharge: number;
  batteryMode: 0 | 1 | 2;
}

export interface SimulinkEvent {
  meterId: string;
  runId: string;
  timestamp: string;
  decimalHour: number;
  code: number;
  name: string;
  status: number;
  rejectionMask: number;
  rejectionReason: string;
}

export interface SimulinkImportPackage {
  metadata: SimulinkMetadata;
  metadataFileName: string;
  metadataJson: string;
  measurementSha256: string;
  eventsSha256: string;
  fixture: boolean;
  measurements: SimulinkMeasurement[];
  events: SimulinkEvent[];
}

export class SimulinkImportError extends Error {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "SimulinkImportError";
  }
}

function fail(code: string, message: string): never {
  throw new SimulinkImportError(code, message);
}

function sha256(bytes: Buffer): string {
  return createHash("sha256").update(bytes).digest("hex");
}

function parseCsv(contents: string, expectedColumns: readonly string[], kind: string): string[][] {
  if (contents.startsWith("\uFEFF")) fail("INVALID_ENCODING", `${kind} CSV must not contain a BOM`);
  if (contents.includes("\r")) fail("INVALID_LINE_ENDING", `${kind} CSV must use LF line endings`);
  let rows: string[][];
  try {
    rows = parse(contents, {
      bom: false,
      delimiter: ",",
      record_delimiter: "\n",
      relax_column_count: false,
      relax_quotes: false,
      skip_empty_lines: false,
    });
  } catch {
    return fail("INVALID_CSV", `${kind} CSV could not be parsed`);
  }
  if (rows.length === 0) fail("INVALID_CSV", `${kind} CSV has no header`);
  const header = rows[0] ?? [];
  if (
    header.length !== expectedColumns.length ||
    header.some((value, i) => value !== expectedColumns[i])
  ) {
    fail("INVALID_COLUMNS", `${kind} CSV columns do not match contract 1.0`);
  }
  return rows.slice(1);
}

function numberAt(row: string[], index: number, field: string): number {
  const raw = row[index];
  if (
    raw === undefined ||
    raw.trim() === "" ||
    !/^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/.test(raw)
  ) {
    fail("INVALID_NUMBER", `${field} must be a finite decimal number`);
  }
  const value = Number(raw);
  if (!Number.isFinite(value)) fail("INVALID_NUMBER", `${field} must be finite`);
  return value;
}

function integerAt(
  row: string[],
  index: number,
  field: string,
  minimum: number,
  maximum: number,
): number {
  const value = numberAt(row, index, field);
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    fail("INVALID_INTEGER", `${field} is outside the allowed integer range`);
  }
  return value;
}

function timestamp(value: string | undefined, day: string, field: string): string {
  if (
    !value ||
    !timestampPattern.test(value) ||
    !value.startsWith(`${day}T`) ||
    !Number.isFinite(Date.parse(value))
  ) {
    fail("INVALID_TIMESTAMP", `${field} must be ISO 8601 on ${day} with +03:00 offset`);
  }
  return value;
}

function within(value: number, minimum: number, maximum: number, field: string): number {
  if (value < minimum || value > maximum)
    fail("OUT_OF_RANGE", `${field} is outside the allowed range`);
  return value;
}

function parseMeasurements(rows: string[][], metadata: SimulinkMetadata): SimulinkMeasurement[] {
  return rows.map((row, rowIndex) => {
    if (row.length !== MEASUREMENT_COLUMNS.length)
      fail("INVALID_COLUMNS", "Measurement row width is invalid");
    const meterId = row[0] ?? "";
    const runId = row[1] ?? "";
    const measuredAt = timestamp(row[2], metadata.gun, `measurement row ${rowIndex + 1}`);
    const minute = integerAt(row, 3, "dakika", 0, 1439);
    const tariff = integerAt(row, 4, "tarife_dilimi", 1, 3) as 1 | 2 | 3;
    const valid = integerAt(row, 5, "gecerli", 0, 1) === 1;
    const voltage = within(numberAt(row, 6, "v_rms_V"), 0, 1000, "v_rms_V");
    const current = within(numberAt(row, 7, "i_rms_A"), 0, 10_000, "i_rms_A");
    const apparent = within(numberAt(row, 10, "s_VA"), 0, 10_000_000, "s_VA");
    const cosPhi = within(numberAt(row, 11, "cos_phi"), -1, 1, "cos_phi");
    const inductive = within(numberAt(row, 17, "e_rend_kvarh"), 0, 1_000_000, "e_rend_kvarh");
    const capacitive = within(numberAt(row, 18, "e_rkap_kvarh"), 0, 1_000_000, "e_rkap_kvarh");
    const relayCommand = integerAt(row, 19, "role_komut", 0, 1) === 1;
    const relayClosed = integerAt(row, 20, "role", 0, 1) === 1;
    const status = integerAt(row, 21, "durum", 0, 5);
    const overloadWarning = integerAt(row, 22, "asiri_guc_uyari", 0, 1) === 1;
    const eventCount = integerAt(row, 23, "olay_sayisi", 0, 1000);
    const stateOfCharge = within(numberAt(row, 25, "soc"), 0, 1, "soc");
    const batteryMode = integerAt(row, 26, "batarya_mod", 0, 2) as 0 | 1 | 2;
    return {
      meterId,
      runId,
      timestamp: measuredAt,
      minute,
      tariffPeriod: tariff,
      valid,
      voltageRmsV: voltage,
      currentRmsA: current,
      activePowerW: numberAt(row, 8, "p_W"),
      reactivePowerVar: numberAt(row, 9, "q_var"),
      apparentPowerVa: apparent,
      cosPhi,
      intervalEnergyKWh: numberAt(row, 12, "e_aralik_kWh"),
      totalEnergyKWh: numberAt(row, 13, "e_toplam_kWh"),
      t1KWh: numberAt(row, 14, "e_t1_kWh"),
      t2KWh: numberAt(row, 15, "e_t2_kWh"),
      t3KWh: numberAt(row, 16, "e_t3_kWh"),
      inductiveKvarh: inductive,
      capacitiveKvarh: capacitive,
      relayCommand,
      relayClosed,
      status,
      overloadWarning,
      eventCount,
      batteryPowerW: numberAt(row, 24, "p_bat_W"),
      stateOfCharge,
      batteryMode,
    };
  });
}

function parseEvents(rows: string[][], metadata: SimulinkMetadata): SimulinkEvent[] {
  return rows.map((row, rowIndex) => {
    if (row.length !== EVENT_COLUMNS.length) fail("INVALID_COLUMNS", "Event row width is invalid");
    const code = integerAt(row, 4, "olay_kodu", 0, 999);
    if (!eventCodes.has(code)) fail("UNKNOWN_EVENT_CODE", `Unknown event code ${code}`);
    const rejectionMask = integerAt(row, 7, "red_maske", 0, 15);
    const rejectionReason = row[8] ?? "";
    if (code === 31 && (rejectionMask === 0 || rejectionReason.trim() === "")) {
      fail("INVALID_REJECTION", "Rejected reconnection must include a mask and reason");
    }
    if (code !== 31 && rejectionMask !== 0) {
      fail("INVALID_REJECTION", "Rejection mask is only valid for event code 31");
    }
    return {
      meterId: row[0] ?? "",
      runId: row[1] ?? "",
      timestamp: timestamp(row[2], metadata.gun, `event row ${rowIndex + 1}`),
      decimalHour: within(numberAt(row, 3, "saat"), 0, 24, "saat"),
      code,
      name: row[5] ?? "",
      status: integerAt(row, 6, "durum", 0, 5),
      rejectionMask,
      rejectionReason,
    };
  });
}

function approximatelyEqual(left: number, right: number, tolerance = 0.001): boolean {
  return Math.abs(left - right) <= tolerance;
}

function validateRelationships(
  metadata: SimulinkMetadata,
  fixture: boolean,
  measurements: SimulinkMeasurement[],
  events: SimulinkEvent[],
  expectedMeterId: string,
): void {
  if (metadata.sayac_id !== expectedMeterId)
    fail("METER_MISMATCH", "Metadata meter is not configured");
  if (metadata.satir_sayisi !== measurements.length || metadata.olay_sayisi !== events.length) {
    fail("COUNT_MISMATCH", "Metadata row counts do not match the CSV files");
  }
  if (metadata.kontroller.some((check) => !check.gecti)) {
    fail("SIMULINK_CHECK_FAILED", "One or more Simulink metadata checks failed");
  }
  const declaredColumns = metadata.sutunlar.map((column) => column.ad);
  if (declaredColumns.some((column, index) => column !== MEASUREMENT_COLUMNS[index])) {
    fail("METADATA_COLUMNS_MISMATCH", "Metadata columns do not match contract 1.0");
  }
  if (!fixture && measurements.length !== 1440) {
    fail("INCOMPLETE_DAY", "A normal model or test run must contain exactly 1440 measurements");
  }
  if (fixture && measurements.length >= 1440) {
    fail("INVALID_FIXTURE", "A fixture must be a short excerpt");
  }
  if (!fixture && (measurements[0]?.valid !== false || measurements[1]?.valid !== false)) {
    fail("INVALID_INITIAL_QUALITY", "The first two full-day measurements must have gecerli=0");
  }

  for (let index = 0; index < measurements.length; index += 1) {
    const current = measurements[index];
    if (!current) continue;
    if (current.meterId !== metadata.sayac_id || current.runId !== metadata.run_id) {
      fail("IDENTITY_MISMATCH", "Measurement meter_id or run_id does not match metadata");
    }
    if (!fixture && current.minute !== index)
      fail("MINUTE_SEQUENCE", "Full-day minutes must be 0 through 1439");
    const hours = Math.floor(current.minute / 60)
      .toString()
      .padStart(2, "0");
    const minutes = (current.minute % 60).toString().padStart(2, "0");
    if (!current.timestamp.startsWith(`${metadata.gun}T${hours}:${minutes}:00`)) {
      fail("TIMESTAMP_SEQUENCE", "Measurement timestamp does not match its minute index");
    }
    const previous = measurements[index - 1];
    if (previous) {
      if (
        current.minute !== previous.minute + 1 ||
        Date.parse(current.timestamp) - Date.parse(previous.timestamp) !== 60_000
      ) {
        fail("TIMESTAMP_SEQUENCE", "Measurements must be consecutive one-minute intervals");
      }
      if (
        !approximatelyEqual(
          current.totalEnergyKWh - previous.totalEnergyKWh,
          current.intervalEnergyKWh,
        )
      ) {
        fail("ENERGY_INCONSISTENT", "Interval and cumulative active energy are inconsistent");
      }
    }
  }

  for (const event of events) {
    if (event.meterId !== metadata.sayac_id || event.runId !== metadata.run_id) {
      fail("IDENTITY_MISMATCH", "Event meter_id or run_id does not match metadata");
    }
  }
  if (measurements.reduce((sum, row) => sum + row.eventCount, 0) !== events.length) {
    fail("EVENT_COUNT_MISMATCH", "Measurement event counts do not match the event CSV");
  }

  const last = measurements.at(-1);
  if (!last) fail("EMPTY_MEASUREMENTS", "Measurement CSV has no data rows");
  if (!approximatelyEqual(last.t1KWh + last.t2KWh + last.t3KWh, last.totalEnergyKWh)) {
    fail("ENERGY_INCONSISTENT", "T1, T2 and T3 counters do not match total energy");
  }
  if (!fixture) {
    const intervalTotal = measurements.reduce((sum, row) => sum + row.intervalEnergyKWh, 0);
    if (!approximatelyEqual(intervalTotal, last.totalEnergyKWh)) {
      fail("ENERGY_INCONSISTENT", "Daily interval energy does not match the total counter");
    }
    for (const tariff of [1, 2, 3] as const) {
      const interval = measurements
        .filter((row) => row.tariffPeriod === tariff)
        .reduce((sum, row) => sum + row.intervalEnergyKWh, 0);
      const counter = tariff === 1 ? last.t1KWh : tariff === 2 ? last.t2KWh : last.t3KWh;
      if (!approximatelyEqual(interval, counter)) {
        fail("ENERGY_INCONSISTENT", `T${tariff} interval energy does not match its counter`);
      }
    }
    const declared = metadata.gunluk_toplam;
    if (!declared) fail("MISSING_DAILY_TOTAL", "A full-day package must declare daily totals");
    if (
      !approximatelyEqual(declared.e_toplam_kWh, last.totalEnergyKWh) ||
      !approximatelyEqual(declared.e_t1_kWh, last.t1KWh) ||
      !approximatelyEqual(declared.e_t2_kWh, last.t2KWh) ||
      !approximatelyEqual(declared.e_t3_kWh, last.t3KWh) ||
      !approximatelyEqual(declared.e_rend_kvarh, last.inductiveKvarh) ||
      !approximatelyEqual(declared.e_rkap_kvarh, last.capacitiveKvarh)
    ) {
      fail("METADATA_TOTAL_MISMATCH", "Metadata daily totals do not match the final counters");
    }
  }
}

export function loadSimulinkImportPackage(
  baseDirectory: string,
  metadataFileName: string,
  expectedMeterId: string,
): SimulinkImportPackage {
  if (
    !/^meta_\d{4}-\d{2}-\d{2}(?:_TEST)?\.json$/.test(metadataFileName) &&
    !/^ornek_[a-zA-Z0-9_]+_meta_TEST\.json$/.test(metadataFileName)
  ) {
    fail("INVALID_METADATA_FILENAME", "Metadata filename does not match contract 1.0");
  }
  let metadataFile;
  try {
    metadataFile = readLimitedImportFile(baseDirectory, metadataFileName, { maxBytes: 512 * 1024 });
  } catch (error) {
    return fail(
      "UNSAFE_IMPORT_PATH",
      error instanceof Error ? error.message : "Metadata file could not be read",
    );
  }
  let metadata: SimulinkMetadata;
  try {
    metadata = metadataSchema.parse(JSON.parse(metadataFile.contents) as unknown);
  } catch {
    return fail("INVALID_METADATA", "Metadata JSON does not match contract 1.0");
  }
  const fixture = metadata.ornek !== undefined;
  if (fixture && metadata.veri_turu !== "test")
    fail("INVALID_FIXTURE", "Fixtures must be marked as test data");
  if (fixture) {
    const prefix = metadataFileName.replace(/_meta_TEST\.json$/, "");
    if (
      metadata.dosyalar.olcum !== `${prefix}_olcum_TEST.csv` ||
      metadata.dosyalar.olaylar !== `${prefix}_olaylar_TEST.csv`
    ) {
      fail("FILENAME_MISMATCH", "Fixture filenames do not describe the same package");
    }
  } else {
    const suffix = metadata.veri_turu === "test" ? "_TEST" : "";
    if (
      metadataFileName !== `meta_${metadata.gun}${suffix}.json` ||
      metadata.dosyalar.olcum !== `olcum_1dk_${metadata.gun}${suffix}.csv` ||
      metadata.dosyalar.olaylar !== `olaylar_${metadata.gun}${suffix}.csv`
    ) {
      fail("FILENAME_MISMATCH", "Daily filenames do not match metadata day and data type");
    }
  }

  let measurementFile;
  let eventFile;
  try {
    measurementFile = readLimitedImportFile(baseDirectory, metadata.dosyalar.olcum, {
      maxBytes: 4 * 1024 * 1024,
      maxRecords: 1440,
    });
    eventFile = readLimitedImportFile(baseDirectory, metadata.dosyalar.olaylar, {
      maxBytes: 2 * 1024 * 1024,
      maxRecords: 20_000,
    });
  } catch (error) {
    return fail(
      "INCOMPLETE_PACKAGE",
      error instanceof Error ? error.message : "CSV file could not be read",
    );
  }
  const measurementSha256 = sha256(measurementFile.bytes);
  const eventsSha256 = sha256(eventFile.bytes);
  if (
    measurementSha256 !== metadata.dosyalar.olcum_sha256 ||
    eventsSha256 !== metadata.dosyalar.olaylar_sha256
  ) {
    fail("CHECKSUM_MISMATCH", "A CSV SHA-256 digest does not match metadata");
  }

  const measurementRows = parseCsv(measurementFile.contents, MEASUREMENT_COLUMNS, "Measurement");
  const eventRows = parseCsv(eventFile.contents, EVENT_COLUMNS, "Event");
  const measurements = parseMeasurements(measurementRows, metadata);
  const events = parseEvents(eventRows, metadata);
  validateRelationships(metadata, fixture, measurements, events, expectedMeterId);

  const metadataAfter = readLimitedImportFile(baseDirectory, metadataFileName, {
    maxBytes: 512 * 1024,
  });
  if (!metadataAfter.bytes.equals(metadataFile.bytes)) {
    fail("PACKAGE_CHANGED", "Metadata changed while the package was being validated");
  }
  return {
    metadata,
    metadataFileName,
    metadataJson: metadataFile.contents,
    measurementSha256,
    eventsSha256,
    fixture,
    measurements,
    events,
  };
}

export { EVENT_COLUMNS, MEASUREMENT_COLUMNS };
