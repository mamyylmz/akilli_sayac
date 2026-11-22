# Akıllı Sayaç – Kesinti + Batarya Regresyon Testi (G)

- Tarih: 22-Nov-2026 18:22:12
- MATLAB: 26.2.0.3386108 (R2026b)
- Mod: normal (koruma ve batarya aktif), E testindeki şebeke profili
- Özet: **7 GEÇTİ, 0 KALDI**

| No | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |
|---|---|---|---|---|---|---|---|
| G1 | Sadece_Enduktif: sıfır geçişi algılama kapalı (1 = kapalı) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| G2 | Sadece_Kapasitif: sıfır geçişi algılama kapalı (1 = kapalı) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| G3 | Simülasyon hatasız tamamlandı (1 = evet) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| G4 | Kesinti algılama başlangıcı (saat) | saat | 12.5198 | 12.519 | -0.000833 | ±0.00416667 | GEÇTİ |
| G5 | Kesinti algılama bitişi (saat) | saat | 12.6668 | 12.667 | 0.000167 | ±0.00416667 | GEÇTİ |
| G6 | Kesinti sırasında enerji sayacı artışı (durmalı) | kWh | 0 | -2.24265e-13 | -2.24e-13 | ±0.0001 | GEÇTİ |
| G7 | Gün sonu SOC (bataryalı günle aynı, B1: 0,6326) | - | 0.6326 | 0.632604 | 4.21e-06 | ±0.001 | GEÇTİ |

Neden: bataryalı günde kesinti sırasında Q sıfır etrafında salınınca iki Saturation bloğundaki sıfır geçişi algılaması simülasyonu durduruyordu (gösteri günü, 21.11.2026). Düzeltme: ZeroCross = off.
