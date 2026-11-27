import { useState, type FormEvent } from "react";

interface SimulationRun {
  run_id: string;
  data_type: "model" | "test";
  is_fixture: number;
  day: string;
  measurement_count: number;
  event_count: number;
  source: string;
  trusted_source: number;
  active: number;
}

interface DashboardResponse {
  dataStatus: string;
  trustedPhysicalMeterData: boolean;
  run?: SimulationRun & { meter_id?: string; schema_version?: string };
  meter?: { id?: string; relay_state?: string; grid_state?: string; overload_active?: number };
  measurement?: {
    measured_at?: string;
    valid?: number;
    voltage_rms_v?: number;
    current_rms_a?: number;
    active_power_w?: number;
    reactive_power_var?: number;
    apparent_power_va?: number;
    cos_phi?: number;
    true_power_factor?: number;
    relay_closed?: 0 | 1;
    relay_command?: 0 | 1;
    total_energy_kwh?: number;
    t1_kwh?: number;
    t2_kwh?: number;
    t3_kwh?: number;
    inductive_kvarh?: number;
    capacitive_kvarh?: number;
    battery_power_w?: number;
    state_of_charge?: number;
    battery_mode?: number;
  };
  energy?: {
    total_kwh?: number;
    total_active_kwh?: number;
    t1_kwh?: number;
    t2_kwh?: number;
    t3_kwh?: number;
    inductive_kvarh?: number;
    capacitive_kvarh?: number;
  };
  billing?: {
    excluded_net_export_wh?: number;
    tariff?: {
      name?: string;
      demonstration?: boolean;
      pricesMicroliraPerKWh?: { t1?: number; t2?: number; t3?: number; distribution?: number };
    };
    bill?: { totalMicrolira?: number; demonstration?: boolean; tariffId?: string };
  };
  events?: Array<{
    id?: string;
    occurred_at?: string;
    event_code?: number;
    event_name?: string;
    meter_status?: number;
    rejection_reason?: string;
    severity?: string;
    message?: string;
    exported_at?: string;
  }>;
}

interface SeriesPoint {
  minute: number;
  measured_at: string;
  valid_count: number;
  invalid_count: number;
  active_power_w: number | null;
  interval_energy_kwh: number;
  battery_power_w: number | null;
  state_of_charge: number | null;
  overload_warning: number;
}

interface MetricProps {
  label: string;
  value: number | string | undefined;
  unit?: string | undefined;
  note?: string | undefined;
}

function Metric({ label, value, unit, note }: MetricProps) {
  return (
    <article className="metric">
      <h3>{label}</h3>
      <p>
        {value ?? "—"} {value !== undefined && unit ? <small>{unit}</small> : null}
      </p>
      {note ? <span>{note}</span> : null}
    </article>
  );
}

function format(value: number | undefined | null, digits = 2): string | undefined {
  return value === undefined || value === null ? undefined : value.toFixed(digits);
}

function money(microlira: number | undefined): string | undefined {
  return microlira === undefined
    ? undefined
    : new Intl.NumberFormat("tr-TR", { style: "currency", currency: "TRY" }).format(
        microlira / 1_000_000,
      );
}

function batteryMode(mode: number | undefined): string | undefined {
  return mode === 1 ? "Şarj" : mode === 2 ? "Deşarj" : mode === 0 ? "Bekleme" : undefined;
}

function PowerChart({ points }: { points: SeriesPoint[] }) {
  const usable = points.filter((point) => point.active_power_w !== null);
  if (usable.length < 2) return <p>Grafik için yeterli geçerli ölçüm yok.</p>;
  const values = usable.map((point) => point.active_power_w ?? 0);
  const minimum = Math.min(0, ...values);
  const maximum = Math.max(1, ...values);
  const range = maximum - minimum || 1;
  const coordinates = usable
    .map((point) => {
      const x = (point.minute / 1439) * 1000;
      const y = 210 - (((point.active_power_w ?? 0) - minimum) / range) * 190;
      return `${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(" ");
  const invalid = points.filter((point) => point.invalid_count > 0);
  return (
    <div className="chart-wrap">
      <svg
        viewBox="0 0 1000 240"
        role="img"
        aria-label="Seçilen günün şebekeden net aktif güç grafiği"
      >
        <line x1="0" y1="210" x2="1000" y2="210" className="axis" />
        <polyline points={coordinates} className="power-line" />
        {invalid.map((point) => (
          <circle
            key={point.minute}
            cx={(point.minute / 1439) * 1000}
            cy="225"
            r="5"
            className="invalid-point"
          />
        ))}
      </svg>
      <div className="chart-labels" aria-hidden="true">
        <span>00:00</span>
        <span>06:00</span>
        <span>12:00</span>
        <span>18:00</span>
        <span>24:00</span>
      </div>
      {invalid.length ? (
        <p className="quality-note">
          Turuncu işaretli {invalid.length} aralık geçersiz satır içerir; bu satırlar güç
          ortalamasına katılmadı.
        </p>
      ) : null}
    </div>
  );
}

export function App() {
  const [token, setToken] = useState("");
  const [runs, setRuns] = useState<SimulationRun[]>([]);
  const [selectedRunId, setSelectedRunId] = useState("");
  const [comparisonRunId, setComparisonRunId] = useState("");
  const [dashboard, setDashboard] = useState<DashboardResponse>();
  const [comparison, setComparison] = useState<DashboardResponse>();
  const [series, setSeries] = useState<SeriesPoint[]>([]);
  const [bucketMinutes, setBucketMinutes] = useState<15 | 60>(15);
  const [error, setError] = useState<string>();
  const [loading, setLoading] = useState(false);

  const headers = { authorization: `Bearer ${token}` };

  async function requestJson<T>(url: string, init?: RequestInit): Promise<T> {
    const response = await fetch(`http://127.0.0.1:3000${url}`, {
      ...init,
      headers: { ...headers, ...(init?.headers ?? {}) },
    });
    if (!response.ok) throw new Error(`API isteği başarısız (${response.status})`);
    return (await response.json()) as T;
  }

  async function loadRun(runId: string, resolution: 15 | 60 = bucketMinutes) {
    const [snapshot, timeline] = await Promise.all([
      requestJson<DashboardResponse>(`/api/v1/dashboard?runId=${encodeURIComponent(runId)}`),
      requestJson<{ measurements: SeriesPoint[] }>(
        `/api/v1/simulation-runs/${encodeURIComponent(runId)}/measurements?bucketMinutes=${resolution}`,
      ),
    ]);
    setSelectedRunId(runId);
    setDashboard(snapshot);
    setSeries(timeline.measurements);
  }

  async function connect(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(undefined);
    try {
      const response = await requestJson<{ runs: SimulationRun[] }>("/api/v1/simulation-runs");
      setRuns(response.runs);
      const active = response.runs.find((run) => run.active === 1) ?? response.runs[0];
      if (active) await loadRun(active.run_id);
      else setDashboard(await requestJson<DashboardResponse>("/api/v1/dashboard"));
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Beklenmeyen hata");
    } finally {
      setLoading(false);
    }
  }

  async function chooseRun(runId: string) {
    setLoading(true);
    setError(undefined);
    try {
      await requestJson(`/api/v1/simulation-runs/${encodeURIComponent(runId)}/select`, {
        method: "POST",
      });
      await loadRun(runId);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Çalıştırma seçilemedi");
    } finally {
      setLoading(false);
    }
  }

  async function chooseComparison(runId: string) {
    setError(undefined);
    try {
      setComparisonRunId(runId);
      setComparison(
        runId
          ? await requestJson<DashboardResponse>(
              `/api/v1/dashboard?runId=${encodeURIComponent(runId)}`,
            )
          : undefined,
      );
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Karşılaştırma yüklenemedi");
    }
  }

  const measurement = dashboard?.measurement;
  const energy = dashboard?.energy;
  const meter = dashboard?.meter;
  const run = dashboard?.run;
  let relayState = meter?.relay_state;
  if (run) {
    const relayClosed = measurement?.relay_closed;
    relayState =
      relayClosed === undefined ? undefined : relayClosed === 1 ? "energized" : "deenergized";
  }
  const tariff = dashboard?.billing?.tariff;
  const bill = dashboard?.billing?.bill;
  const energyTotal = energy?.total_kwh ?? energy?.total_active_kwh;
  const costDifference =
    bill?.totalMicrolira !== undefined && comparison?.billing?.bill?.totalMicrolira !== undefined
      ? bill.totalMicrolira - comparison.billing.bill.totalMicrolira
      : undefined;

  return (
    <main>
      <header>
        <div>
          <p className="eyebrow">Yerel HAN ekranı</p>
          <h1>Akıllı Sayaç</h1>
        </div>
        <strong className="data-label">Simülasyon verisi</strong>
      </header>

      <section className="notice" aria-label="Veri güvenilirliği">
        <strong>Kaynak sınırı:</strong>{" "}
        {run?.source ?? "Bu veriler Simulink simülasyonundan gelir."} SHA-256 dosya bütünlüğünü
        doğrular, fiziksel sayaç kimliğini doğrulamaz.
      </section>

      <form onSubmit={(event) => void connect(event)} className="connection-form">
        <label htmlFor="local-token">Yerel erişim belirteci</label>
        <input
          id="local-token"
          type="password"
          autoComplete="off"
          value={token}
          onChange={(event) => setToken(event.target.value)}
          required
        />
        <button type="submit" disabled={loading}>
          {loading ? "Yükleniyor…" : "Bağlan ve yenile"}
        </button>
      </form>
      {error ? (
        <p role="alert" className="error">
          {error}
        </p>
      ) : null}

      {runs.length ? (
        <section className="run-picker" aria-labelledby="run-title">
          <div>
            <h2 id="run-title">Simülasyon çalıştırması</h2>
            <p>Farklı gün ve senaryoların kümülatif sayaçları ayrı tutulur.</p>
          </div>
          <label>
            Gösterilen çalıştırma
            <select
              value={selectedRunId}
              onChange={(event) => void chooseRun(event.target.value)}
              disabled={loading}
            >
              {runs.map((run) => (
                <option key={run.run_id} value={run.run_id}>
                  {run.day} · {run.data_type}
                  {run.is_fixture ? " · fixture" : ""} · {run.run_id}
                </option>
              ))}
            </select>
          </label>
          <label>
            Karşılaştırma
            <select
              value={comparisonRunId}
              onChange={(event) => void chooseComparison(event.target.value)}
            >
              <option value="">Karşılaştırma yok</option>
              {runs
                .filter((run) => run.run_id !== selectedRunId)
                .map((run) => (
                  <option key={run.run_id} value={run.run_id}>
                    {run.day} · {run.run_id}
                  </option>
                ))}
            </select>
          </label>
        </section>
      ) : null}

      <section className="panel" aria-labelledby="status-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Genel durum</p>
            <h2 id="status-title">Sayaç ve çalışma</h2>
          </div>
          <span
            className={
              measurement?.valid === 0 || measurement?.valid === undefined
                ? "badge warning"
                : "badge ok"
            }
          >
            {measurement
              ? measurement.valid === 0
                ? "Ölçüm geçersiz"
                : measurement.valid === 1
                  ? "Ölçüm geçerli"
                  : "Kalite bayrağı yok"
              : "Veri bekleniyor"}
          </span>
        </div>
        <div className="metrics">
          <Metric
            label="Sayaç"
            value={dashboard?.run?.meter_id ?? meter?.id}
            note={
              dashboard?.run?.data_type
                ? `Tür: ${dashboard.run.data_type}${dashboard.run.is_fixture ? " fixture" : ""}`
                : undefined
            }
          />
          <Metric label="Şebeke" value={meter?.grid_state} />
          <Metric label="Röle" value={relayState} />
          {run ? (
            <Metric
              label="Röle komutu"
              value={measurement?.relay_command}
              note="1: enerji ver, 0: kes"
            />
          ) : null}
          <Metric
            label="Aşırı güç alarmı"
            value={meter ? (meter.overload_active ? "Aktif" : "Yok") : undefined}
          />
        </div>
      </section>

      <section className="panel" aria-labelledby="electric-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Elektriksel ölçümler</p>
            <h2 id="electric-title">Son dakika</h2>
          </div>
          <span>{measurement?.measured_at ?? "—"}</span>
        </div>
        <div className="metrics">
          <Metric label="Gerilim" value={format(measurement?.voltage_rms_v)} unit="V rms" />
          <Metric label="Akım" value={format(measurement?.current_rms_a)} unit="A rms" />
          <Metric
            label="Aktif güç"
            value={format(measurement?.active_power_w)}
            unit="W"
            note="Şebekeden net çekilen"
          />
          <Metric label="Reaktif güç" value={format(measurement?.reactive_power_var)} unit="var" />
          <Metric label="Görünür güç" value={format(measurement?.apparent_power_va)} unit="VA" />
          <Metric
            label="cosφ"
            value={format(measurement?.cos_phi, 3)}
            note="İşareti aktif gücü izler"
          />
          <Metric
            label="Gerçek PF"
            value={format(measurement?.true_power_factor, 3)}
            note={
              measurement?.true_power_factor === undefined
                ? "Sözleşme 1.0 bu alanı üretmiyor"
                : undefined
            }
          />
          <Metric
            label="Endüktif / kapasitif"
            value={
              energy
                ? `${format(energy.inductive_kvarh, 3)} / ${format(energy.capacitive_kvarh, 3)}`
                : undefined
            }
            unit="kVArh"
          />
        </div>
      </section>

      <section className="panel" aria-labelledby="consumption-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Tüketim</p>
            <h2 id="consumption-title">Şebekeden net enerji ve güç</h2>
          </div>
          <label>
            Analiz aralığı
            <select
              value={bucketMinutes}
              onChange={(event) => {
                const value = Number(event.target.value) as 15 | 60;
                setBucketMinutes(value);
                if (selectedRunId) void loadRun(selectedRunId, value);
              }}
            >
              <option value={15}>15 dakika</option>
              <option value={60}>Saatlik</option>
            </select>
          </label>
        </div>
        <div className="metrics compact">
          <Metric label="Toplam net enerji" value={format(energyTotal, 3)} unit="kWh" />
          <Metric label="T1" value={format(energy?.t1_kwh, 3)} unit="kWh" />
          <Metric label="T2" value={format(energy?.t2_kwh, 3)} unit="kWh" />
          <Metric label="T3" value={format(energy?.t3_kwh, 3)} unit="kWh" />
        </div>
        <PowerChart points={series} />
      </section>

      <section className="panel" aria-labelledby="battery-title">
        <p className="eyebrow">Batarya</p>
        <h2 id="battery-title">Durum ve senaryo karşılaştırması</h2>
        <div className="metrics compact">
          <Metric
            label="SOC"
            value={
              measurement?.state_of_charge === undefined
                ? undefined
                : format(measurement.state_of_charge * 100, 1)
            }
            unit="%"
          />
          <Metric label="Mod" value={batteryMode(measurement?.battery_mode)} />
          <Metric
            label="Batarya gücü"
            value={format(measurement?.battery_power_w)}
            unit="W"
            note="+ deşarj, − şarj"
          />
          <Metric
            label="Karşılaştırılan maliyet farkı"
            value={money(costDifference)}
            note={
              comparison
                ? `${selectedRunId} eksi ${comparisonRunId}`
                : "Batarya aktif/pasif senaryoları için ikinci çalıştırmayı seçin"
            }
          />
        </div>
      </section>

      <section className="panel" aria-labelledby="billing-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Faturalandırma</p>
            <h2 id="billing-title">Sabitlenmiş tarife snapshot’ı</h2>
          </div>
          {tariff?.demonstration ? (
            <span className="badge warning">Demonstrasyon fiyatı</span>
          ) : null}
        </div>
        <div className="metrics compact">
          <Metric
            label="T1 / T2 / T3 fiyatı"
            value={
              tariff?.pricesMicroliraPerKWh
                ? `${format((tariff.pricesMicroliraPerKWh.t1 ?? 0) / 1_000_000, 4)} / ${format((tariff.pricesMicroliraPerKWh.t2 ?? 0) / 1_000_000, 4)} / ${format((tariff.pricesMicroliraPerKWh.t3 ?? 0) / 1_000_000, 4)}`
                : undefined
            }
            unit="TL/kWh"
          />
          <Metric
            label="Dağıtım bedeli"
            value={
              tariff?.pricesMicroliraPerKWh?.distribution === undefined
                ? undefined
                : format(tariff.pricesMicroliraPerKWh.distribution / 1_000_000, 4)
            }
            unit="TL/kWh"
          />
          <Metric
            label="Hesaplanan maliyet"
            value={money(bill?.totalMicrolira)}
            note={tariff?.name}
          />
          <Metric
            label="Fiyatlanmayan net ihracat"
            value={dashboard?.billing?.excluded_net_export_wh}
            unit="Wh"
            note="Otomatik indirim uygulanmaz"
          />
        </div>
      </section>

      <section className="panel events" aria-labelledby="events-title">
        <p className="eyebrow">Olay geçmişi</p>
        <h2 id="events-title">Koruma ve şebeke olayları</h2>
        {dashboard?.events?.length ? (
          <ul>
            {dashboard.events.map((event, index) => (
              <li key={event.id ?? `${event.occurred_at}-${index}`}>
                <time>{event.occurred_at ?? event.exported_at}</time>
                <strong>
                  {event.event_code !== undefined
                    ? `Kod ${event.event_code}`
                    : (event.severity ?? "Bilgi")}
                </strong>
                <span>
                  {event.event_name ?? event.message ?? "Açıklama yok"}
                  {event.rejection_reason ? ` — ${event.rejection_reason}` : ""}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p>Seçilen çalıştırmada olay yok.</p>
        )}
      </section>
    </main>
  );
}
