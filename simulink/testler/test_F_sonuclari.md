# Akıllı Sayaç – Talep Yönetimi Testi (F aşaması)

- Tarih: 21-Nov-2026 18:03:38
- MATLAB: 26.2.0.3386108 (R2026b)
- Mod: measurement_test (koruma ve batarya kapalı)
- Senaryo: çamaşır makinesi (1400 W, 1,5 saat) 19:00–20:30 → 02:00–03:30
- Özet: **7 GEÇTİ, 0 KALDI**

| Sayaç | Referans | Kaydırılmış | Fark |
|---|---|---|---|
| Toplam (kWh) | 14.5527 | 14.5529 | +0.0002 |
| T1 (kWh) | 1.9801 | 1.9801 | +0.0000 |
| T2 Puant (kWh) | 8.0959 | 5.9952 | -2.1007 |
| T3 Gece (kWh) | 4.4768 | 6.5777 | +2.1009 |

TL farkı yazılım katmanında hesaplanır: ΔTL = 2.10 kWh × (T2 birim fiyatı − T3 birim fiyatı)

| Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |
|---|---|---|---|---|---|---|
| Toplam enerji – kaydırılmış / referans (korunmalı) | - | 1 | 1.00002 | %0.002 | %0.1 | GEÇTİ |
| T2 Puant azalması (referans − kaydırılmış) | kWh | 2.1 | 2.10069 | %0.033 | %1 | GEÇTİ |
| T3 Gece artışı (kaydırılmış − referans) | kWh | 2.1 | 2.10091 | %0.043 | %1 | GEÇTİ |
| T1 Gündüz değişimi | kWh | 0 | 5.71247e-10 | 5.71e-10 | ±0.001 | GEÇTİ |
| Endüktif reaktif enerji – kaydırılmış / referans (korunmalı) | - | 1 | 1.00008 | %0.008 | %0.2 | GEÇTİ |
| 20:15 şebeke gücü azalması (çamaşır yok) | W | 1400 | 1398.64 | %0.097 | %1 | GEÇTİ |
| 02:30 şebeke gücü artışı (çamaşır gece) | W | 1400 | 1399.01 | %0.071 | %1 | GEÇTİ |
