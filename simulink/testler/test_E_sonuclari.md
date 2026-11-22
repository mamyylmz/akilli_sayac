# Akıllı Sayaç – Güç Kalitesi Testleri (E aşaması)

- Tarih: 22-Nov-2026 18:21:39
- MATLAB: 26.2.0.3386108 (R2026b)
- Mod: normal (koruma aktif), batarya kapalı
- Özet: **26 GEÇTİ, 0 KALDI**

| Olay | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |
|---|---|---|---|---|---|---|---|
| E1 | Kesinti (V < 23 V) - algılama başlangıcı (saat) | saat | 12.5198 | 12.519 | -0.000833 | ±0.00416667 | GEÇTİ |
| E1 | Kesinti (V < 23 V) - algılama bitişi (saat) | saat | 12.6668 | 12.667 | 0.000167 | ±0.00416667 | GEÇTİ |
| E1 | Kesinti (V < 23 V) - ölçülen süre (dk) | dk | 8.82 | 8.88 | 0.06 | ±0.5 | GEÇTİ |
| E1 | Kesinti (V < 23 V) - olay sırasında V_rms | V | 0 | 0 | 0 | ±0.5 | GEÇTİ |
| E1 | Kesinti (V < 23 V) - olay sırasında P | W | 0 | 0 | 0 | ±1 | GEÇTİ |
| E1 | Kesinti (V < 23 V) - enerji sayacı artışı (durmalı) | kWh | 0 | -2.24265e-13 | -2.24e-13 | ±0.0001 | GEÇTİ |
| E1 | Kesinti (V < 23 V) - durum kodu olay ortasında | - | 4 | 4 | 0 | ±0 | GEÇTİ |
| E1 | Kesinti (V < 23 V) - röle kapalı kaldı (gerilim olayında kesme yapılmaz) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| E1 | Kesinti (V < 23 V) - olay sonrası durum (0 = normal) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| E2 | Gerilim çökmesi (184 V) - algılama başlangıcı (saat) | saat | 20.1772 | 20.178 | 0.000833 | ±0.00416667 | GEÇTİ |
| E2 | Gerilim çökmesi (184 V) - algılama bitişi (saat) | saat | 20.3428 | 20.343 | 0.000167 | ±0.00416667 | GEÇTİ |
| E2 | Gerilim çökmesi (184 V) - ölçülen süre (dk) | dk | 9.94 | 9.9 | -0.04 | ±0.5 | GEÇTİ |
| E2 | Gerilim çökmesi (184 V) - olay sırasında V_rms | V | 184 | 183.999 | %0.000 | %0.5 | GEÇTİ |
| E2 | Gerilim çökmesi (184 V) - güç oranı P(olay)/P(önce) = (V/230)² | - | 0.64 | 0.640001 | %0.000 | %1 | GEÇTİ |
| E2 | Gerilim çökmesi (184 V) - durum kodu olay ortasında | - | 5 | 5 | 0 | ±0 | GEÇTİ |
| E2 | Gerilim çökmesi (184 V) - röle kapalı kaldı (gerilim olayında kesme yapılmaz) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| E2 | Gerilim çökmesi (184 V) - olay sonrası durum (0 = normal) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| E3 | Gerilim yükselmesi (264,5 V) - algılama başlangıcı (saat) | saat | 21.1797 | 21.183 | 0.00333 | ±0.00416667 | GEÇTİ |
| E3 | Gerilim yükselmesi (264,5 V) - algılama bitişi (saat) | saat | 21.3403 | 21.338 | -0.00233 | ±0.00416667 | GEÇTİ |
| E3 | Gerilim yükselmesi (264,5 V) - ölçülen süre (dk) | dk | 9.64 | 9.3 | -0.34 | ±0.5 | GEÇTİ |
| E3 | Gerilim yükselmesi (264,5 V) - olay sırasında V_rms | V | 264.5 | 264.499 | %0.000 | %0.5 | GEÇTİ |
| E3 | Gerilim yükselmesi (264,5 V) - güç oranı P(olay)/P(önce) = (V/230)² | - | 1.3225 | 1.3225 | %0.000 | %1 | GEÇTİ |
| E3 | Gerilim yükselmesi (264,5 V) - durum kodu olay ortasında | - | 5 | 5 | 0 | ±0 | GEÇTİ |
| E3 | Gerilim yükselmesi (264,5 V) - röle kapalı kaldı (gerilim olayında kesme yapılmaz) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| E3 | Gerilim yükselmesi (264,5 V) - olay sonrası durum (0 = normal) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| E | Gün boyunca aşırı güç kesmesi (gerilim olayları kesme üretmemeli) | adet | 0 | 0 | 0 | ±0 | GEÇTİ |

Not: "saat" birimindeki değerler profil saatidir.
