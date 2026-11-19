import { useState, type FormEvent } from "react";

interface DashboardResponse {
  dataStatus: string;
  trustedPhysicalMeterData: boolean;
  meter?: {
    relay_state?: string;
    grid_state?: string;
    overload_active?: number;
  };
  measurement?: {
    voltage_rms_v?: number;
    current_rms_a?: number;
    active_power_w?: number;
    reactive_power_var?: number;
    apparent_power_va?: number;
    displacement_power_factor?: number;
    true_power_factor?: number;
  };
  energy?: {
    total_active_kwh?: number;
    t1_kwh?: number;
    t2_kwh?: number;
    t3_kwh?: number;
    inductive_kvarh?: number;
    capacitive_kvarh?: number;
  };
  events?: Array<{ id?: string; severity?: string; message?: string; exported_at?: string }>;
}

interface MetricProps {
  label: string;
  value: number | string | undefined;
  unit?: string;
}

function Metric({ label, value, unit }: MetricProps) {
  return (
    <article className="metric">
      <h2>{label}</h2>
      <p>
        {value ?? "—"} {value !== undefined ? unit : ""}
      </p>
    </article>
  );
}

function format(value: number | undefined, digits = 2): number | string | undefined {
  return value === undefined ? undefined : value.toFixed(digits);
}

export function App() {
  const [token, setToken] = useState("");
  const [dashboard, setDashboard] = useState<DashboardResponse>();
  const [error, setError] = useState<string>();
  const [loading, setLoading] = useState(false);

  async function loadDashboard(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(undefined);
    try {
      const response = await fetch("http://127.0.0.1:3000/api/v1/dashboard", {
        headers: { authorization: `Bearer ${token}` },
      });
      if (!response.ok) throw new Error(`API isteği başarısız (${response.status})`);
      setDashboard((await response.json()) as DashboardResponse);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Beklenmeyen hata");
    } finally {
      setLoading(false);
    }
  }

  const measurement = dashboard?.measurement;
  const energy = dashboard?.energy;
  const meter = dashboard?.meter;

  return (
    <main>
      <header>
        <div>
          <p className="eyebrow">Yerel HAN ekranı</p>
          <h1>Akıllı Sayaç</h1>
        </div>
        <strong className="data-label">Synthetic / Simulated</strong>
      </header>

      <section className="notice" aria-label="Veri güvenilirliği">
        Bu ekran fiziksel sayaç verisi göstermez. Geliştirme verileri sentetik veya Simulink
        kaynaklıdır.
      </section>

      <form onSubmit={(event) => void loadDashboard(event)} className="connection-form">
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
          {loading ? "Yükleniyor…" : "Verileri yenile"}
        </button>
      </form>
      {error ? (
        <p role="alert" className="error">
          {error}
        </p>
      ) : null}

      <section className="metrics" aria-label="Sayaç ölçümleri">
        <Metric label="Gerilim" value={format(measurement?.voltage_rms_v)} unit="V rms" />
        <Metric label="Akım" value={format(measurement?.current_rms_a)} unit="A rms" />
        <Metric label="Aktif güç" value={format(measurement?.active_power_w)} unit="W" />
        <Metric label="Reaktif güç" value={format(measurement?.reactive_power_var)} unit="var" />
        <Metric label="Görünür güç" value={format(measurement?.apparent_power_va)} unit="VA" />
        <Metric label="cosφ" value={format(measurement?.displacement_power_factor, 3)} />
        <Metric label="Gerçek PF" value={format(measurement?.true_power_factor, 3)} />
        <Metric label="Toplam enerji" value={format(energy?.total_active_kwh, 3)} unit="kWh" />
        <Metric
          label="T1 / T2 / T3"
          value={
            energy
              ? `${format(energy.t1_kwh, 3)} / ${format(energy.t2_kwh, 3)} / ${format(energy.t3_kwh, 3)}`
              : undefined
          }
          unit="kWh"
        />
        <Metric
          label="Endüktif / Kapasitif"
          value={
            energy
              ? `${format(energy.inductive_kvarh, 3)} / ${format(energy.capacitive_kvarh, 3)}`
              : undefined
          }
          unit="kVArh"
        />
        <Metric label="TL maliyet" value="Tarife yapılandırılmadı" />
        <Metric label="Röle" value={meter?.relay_state} />
        <Metric label="Şebeke" value={meter?.grid_state} />
        <Metric
          label="Aşırı yük"
          value={meter ? (meter.overload_active ? "Aktif" : "Yok") : undefined}
        />
      </section>

      <section aria-labelledby="events-title" className="events">
        <h2 id="events-title">Alarm geçmişi</h2>
        {dashboard?.events?.length ? (
          <ul>
            {dashboard.events.map((event) => (
              <li key={event.id}>
                <strong>{event.severity ?? "info"}</strong> — {event.message ?? "Açıklama yok"}
              </li>
            ))}
          </ul>
        ) : (
          <p>Gösterilecek olay yok.</p>
        )}
      </section>
    </main>
  );
}
