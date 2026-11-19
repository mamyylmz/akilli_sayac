# Akıllı Sayaç Yazılım Mimarisi

## Hedef

Tek Fastify uygulaması içinde head-end, MDM, tarife ve kontrol modüllerini basit tutmak; mevcut
Simulink modelini değiştirmeden JSON/CSV dosya sınırı üzerinden bağlanmak. Mikroservis, broker,
Redis, Kubernetes veya ücretli servis yoktur.

## Akış

```text
Simulink export (JSON/CSV)
        │
        ▼
Contracts + HMAC verification ──► SQLite transaction ──► Dashboard API
        │                                  │
        └─ rejection/audit                 └─ billing engine

HAN UI ─► Fastify auth ─► command validation ─► safety policy ─► simulator adapter
```

## Workspace

```text
apps/
  api/        Fastify API, SQLite ve simulator adapter
  web/        React/Vite HAN ekranı
packages/
  contracts/  Zod şemaları ve TypeScript tipleri
  billing/    T1/T2/T3 tamsayı hesap motoru
  security/   HMAC, auth, replay ve röle politikası
fixtures/     Açıkça sentetik ve imzasız geliştirme verileri
simulink/     Korunan elektriksel model
docs/         Mimari, güvenlik, entegrasyon ve test kayıtları
```

## Veri modeli

SQLite tabloları: `meters`, `ami_packets`, `measurements`, `energy_readings`, `meter_events`,
`control_commands`, `command_results`, `tariff_configs`, `audit_events`. Foreign key'ler açık,
paket ve sıra numarası unique, ölçüm/simülasyon zamanı indexlidir. AMI paketi, ölçüm, enerji,
durum ve audit kaydı tek transaction içinde yazılır.

## Güç faktörü ve zaman

- `displacementPowerFactor`: Simulink `cos_phi = P / sqrt(P² + Q²)`.
- `truePowerFactor`: `P / (V_rms × I_rms)`.
- `simulationTimeHours`: 1 simülasyon saniyesinin 1 tüketim saatini temsil ettiği eksen.
- `exportedAt`: Simulink verisinin dosyaya çıkarıldığı gerçek zaman.
- `generatedAt` / `transferredAt`: AMI paket üretim ve aktarım zamanları.

Bu zamanlar birbirinin yerine kullanılmaz.

## Fatura hassasiyeti

Enerji motoru girdiyi Wh tamsayısı, fiyatı mikrolira/kWh tamsayısı ve vergiyi basis point olarak
alır. Çarpım `bigint` ile yapılır, yarım-yukarı yuvarlanır, sonuç güvenli tamsayıya dönüştürülür.
Enerji, dağıtım ve vergi ayrı kalemlerdir. Demonstrasyon fiyatı gerçek tarife olarak sunulmaz;
reaktif ceza hesaplanmaz.
