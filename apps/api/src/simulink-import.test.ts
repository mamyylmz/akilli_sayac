import { createHash } from "node:crypto";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { LocalTokenAuth } from "@akilli-sayac/security";
import { buildApp } from "./app.js";
import { MeterDatabase } from "./database.js";
import {
  EVENT_COLUMNS,
  loadSimulinkImportPackage,
  MEASUREMENT_COLUMNS,
} from "./simulink-import.js";

const directories: string[] = [];

afterEach(() => {
  for (const directory of directories.splice(0))
    rmSync(directory, { recursive: true, force: true });
});

function digest(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function makePackage(options: { fullDay?: boolean; brokenDigest?: boolean } = {}) {
  const directory = mkdtempSync(join(tmpdir(), "akilli-sayac-import-"));
  directories.push(directory);
  const fullDay = options.fullDay ?? false;
  const count = fullDay ? 1440 : 3;
  const startMinute = fullDay ? 0 : 10;
  const runId = "SIM-0001-20261122T183044-E5E0ACFB";
  const rows: string[] = [];
  for (let index = 0; index < count; index += 1) {
    const minute = startMinute + index;
    const hour = Math.floor(minute / 60)
      .toString()
      .padStart(2, "0");
    const minutePart = (minute % 60).toString().padStart(2, "0");
    const total = fullDay ? (index + 1) * 0.001 : 1 + (index + 1) * 0.001;
    rows.push(
      [
        "SIM-0001",
        runId,
        `2026-11-22T${hour}:${minutePart}:00+03:00`,
        minute,
        1,
        fullDay && index < 2 ? 0 : 1,
        230,
        1,
        60,
        10,
        230,
        0.99,
        0.001,
        total.toFixed(6),
        total.toFixed(6),
        0,
        0,
        0,
        0,
        1,
        1,
        0,
        0,
        0,
        0,
        0.5,
        0,
      ].join(","),
    );
  }
  const measurementCsv = `${MEASUREMENT_COLUMNS.join(",")}\n${rows.join("\n")}\n`;
  const eventCsv = `${EVENT_COLUMNS.join(",")}\n`;
  const measurementFileName = fullDay
    ? "olcum_1dk_2026-11-22_TEST.csv"
    : "ornek_yazilim_olcum_TEST.csv";
  const eventFileName = fullDay ? "olaylar_2026-11-22_TEST.csv" : "ornek_yazilim_olaylar_TEST.csv";
  const metadataFileName = fullDay ? "meta_2026-11-22_TEST.json" : "ornek_yazilim_meta_TEST.json";
  writeFileSync(join(directory, measurementFileName), measurementCsv, "utf8");
  writeFileSync(join(directory, eventFileName), eventCsv, "utf8");
  const finalTotal = fullDay ? count * 0.001 : 1 + count * 0.001;
  const metadata = {
    sema_surumu: "1.0",
    run_id: runId,
    veri_turu: "test",
    kaynak: "Simulink simülasyonu; test fixture",
    sayac_id: "SIM-0001",
    gun: "2026-11-22",
    saat_dilimi: "+03:00",
    aralik_dk: 1,
    satir_sayisi: count,
    olay_sayisi: 0,
    dosyalar: {
      olcum: measurementFileName,
      olcum_sha256: options.brokenDigest ? "0".repeat(64) : digest(measurementCsv),
      olaylar: eventFileName,
      olaylar_sha256: digest(eventCsv),
    },
    sutunlar: MEASUREMENT_COLUMNS.map((ad) => ({ ad })),
    kontroller: [{ kontrol: "test", gecti: true, deger: "ok" }],
    gunluk_toplam: {
      e_toplam_kWh: finalTotal,
      e_t1_kWh: finalTotal,
      e_t2_kWh: 0,
      e_t3_kWh: 0,
      e_rend_kvarh: 0,
      e_rkap_kvarh: 0,
    },
    ...(fullDay ? {} : { ornek: { aciklama: "kısa yazılım fixture" } }),
  };
  writeFileSync(join(directory, metadataFileName), `${JSON.stringify(metadata)}\n`, "utf8");
  return { directory, metadataFileName, runId };
}

describe("Simulink contract 1.0 importer", () => {
  it("accepts a marked short fixture and stores it atomically by run_id", () => {
    const fixture = makePackage();
    const imported = loadSimulinkImportPackage(
      fixture.directory,
      fixture.metadataFileName,
      "SIM-0001",
    );
    expect(imported.fixture).toBe(true);
    expect(imported.measurements.length).toBe(3);

    const database = new MeterDatabase(":memory:");
    const first = database.ingestSimulinkPackage(imported, "operator-1");
    const duplicate = database.ingestSimulinkPackage(imported, "operator-1");
    expect(first).toMatchObject({ inserted: true, measurements: 3, events: 0 });
    expect(duplicate).toMatchObject({ inserted: false, runId: fixture.runId });
    expect(database.dashboard("SIM-0001", fixture.runId).run).toMatchObject({
      run_id: fixture.runId,
      trusted_source: 0,
    });
    database.close();
  });

  it("accepts a complete 1440-row day with the first two quality flags unset", () => {
    const fixture = makePackage({ fullDay: true });
    const imported = loadSimulinkImportPackage(
      fixture.directory,
      fixture.metadataFileName,
      "SIM-0001",
    );
    expect(imported.fixture).toBe(false);
    expect(imported.measurements.length).toBe(1440);
    expect(imported.measurements.slice(0, 2).every((row) => !row.valid)).toBe(true);
  });

  it("rejects a digest mismatch before any database write", () => {
    const fixture = makePackage({ brokenDigest: true });
    expect(() =>
      loadSimulinkImportPackage(fixture.directory, fixture.metadataFileName, "SIM-0001"),
    ).toThrow();
    try {
      loadSimulinkImportPackage(fixture.directory, fixture.metadataFileName, "SIM-0001");
    } catch (error) {
      expect(error).toMatchObject({ code: "CHECKSUM_MISMATCH" });
    }
  });

  it("imports through the authorized HTTP endpoint and rejects a replayed run", async () => {
    const fixture = makePackage();
    const database = new MeterDatabase(":memory:");
    const importToken = "operator-import-token-01";
    const auth = new LocalTokenAuth([
      { actorId: "operator-1", role: "operator", token: importToken },
    ]);
    const app = buildApp({
      database,
      auth,
      expectedMeterId: "SIM-0001",
      importDirectory: fixture.directory,
    });
    const request = {
      method: "POST" as const,
      url: "/api/v1/ami/import-file",
      headers: { authorization: `Bearer ${importToken}` },
      payload: { metadataFileName: fixture.metadataFileName },
    };
    const first = await app.inject(request);
    const replay = await app.inject(request);
    expect(first.statusCode).toBe(201);
    expect(first.json()).toMatchObject({
      imported: true,
      runId: fixture.runId,
      trustedPhysicalMeterData: false,
    });
    expect(replay.statusCode).toBe(409);
    await app.close();
    database.close();
  });
});
