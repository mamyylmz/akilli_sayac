# Akıllı Sayaç – Batarya Testleri

- Tarih: 22-Nov-2026 18:21:28
- MATLAB: 26.2.0.3386108 (R2026b)
- Model: Akilli_Sayac.slx
- Batarya: 5 kWh, SOC 0.1–0.95, şarj 1500 W (T3), deşarj en fazla 2500 W (T2), verim 0.95 / 0.95, SOC_0 = 0.63
- Özet: **23 GEÇTİ, 0 KALDI**

| Senaryo | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |
|---|---|---|---|---|---|---|---|
| B1 | Aşırı güç kesmesi sayısı (batarya tepeyi düşürdü) | adet | 0 | 0 | 0 | ±0 | GEÇTİ |
| B1 | Gün boyu şebekeden çekilen P < P_sinir (1 = evet) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| B1 | 18:05 şebeke gücü (4544 − 2500 deşarj) | W | 2044 | 2045.86 | %0.091 | %2 | GEÇTİ |
| B1 | 22:45 şebeke gücü (şarj P_geri'ye kısıldı) | W | 3800 | 3796.46 | %0.093 | %1 | GEÇTİ |
| B1 | Şebekeye verilen enerji (negatif P) | kWh | 0 | 0.00151328 | 0.00151 | ±0.002 | GEÇTİ |
| B1 | T1 Gündüz sayacı | kWh | 1.977 | 1.98008 | %0.156 | %1 | GEÇTİ |
| B1 | T2 Puant sayacı | kWh | 4.072 | 4.05964 | %0.304 | %1 | GEÇTİ |
| B1 | T3 Gece sayacı | kWh | 8.97 | 8.94224 | %0.309 | %1 | GEÇTİ |
| B1 | Günlük enerji (14,56 + şarj/deşarj kaybı) | kWh | 15.02 | 14.982 | %0.253 | %1 | GEÇTİ |
| B1 | SOC 02:00 (gece şarjı tamam) | - | 0.95 | 0.950055 | 5.5e-05 | ±0.002 | GEÇTİ |
| B1 | SOC 18:00 | - | 0.9184 | 0.918476 | 7.61e-05 | ±0.003 | GEÇTİ |
| B1 | SOC 19:00 | - | 0.3921 | 0.39216 | 6.03e-05 | ±0.005 | GEÇTİ |
| B1 | Batarya boşalma anı (saat, ≈19:51) | saat | 19.85 | 19.847 | -0.003 | ±0.0333333 | GEÇTİ |
| B1 | SOC 24:00 (güne başladığı değere yakın) | - | 0.6326 | 0.632604 | 4.21e-06 | ±0.005 | GEÇTİ |
| B1 | En büyük deşarj gücü (≤ P_desarj) | W | 2500 | 2500 | %0.000 | %0.0001 | GEÇTİ |
| B1 | Durum kodu 23:30 (0 = normal) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| B2 | Röle açıkken batarya gücü (18:45) | W | 0 | 0 | 0 | ±0 | GEÇTİ |
| B2 | Röle açıkken batarya modu (0 = bekleme) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| B2 | Röle açıkken I_rms (ada çalışma yok) | A | 0 | 0 | 0 | ±0.01 | GEÇTİ |
| B2 | Röle açıkken gece şarjı yok (22:30 batarya gücü) | W | 0 | 0 | 0 | ±0 | GEÇTİ |
| B2 | SOC değişimi 18:31–24:00 (sabit kalmalı) | - | 0 | 0 | 0 | ±0.001 | GEÇTİ |
| B3 | Gün boyu en büyük |batarya gücü| | W | 0 | 0 | 0 | ±0 | GEÇTİ |
| B3 | Günlük enerji (referans gün) | kWh | 14.56 | 14.5527 | %0.050 | %1 | GEÇTİ |
