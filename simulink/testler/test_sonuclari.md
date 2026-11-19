# Akıllı Sayaç – Doğrulama Sonuçları (A–C aşamaları)

- Tarih: 19-Nov-2026 20:20:15
- MATLAB: 26.2.0.3386108 (R2026b)
- Model: Akilli_Sayac.slx
- 1. çalıştırma: normal gün, measurement_test modu (koruma devre dışı, test yükleri kapalı), 14.0 s
- 2. çalıştırma: test senaryosu, measurement_test modu (kondansatör 03:00–04:00, ana röle 23:00'te açık), 13.7 s
- Özet: **93 GEÇTİ, 0 KALDI, 0 BEKLİYOR**

| Test | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |
|---|---|---|---|---|---|---|---|
| C0 | Parametre dosyasında eksik değişken sayısı | adet | 0 | 0 | 0 | ±0 | GEÇTİ |
| C0 | Normal günde kapasitif test yükü kapalı (kap_u toplamı) | adet | 0 | 0 | 0 | ±0 | GEÇTİ |
| C0 | Normal günde röle testi kapalı (t_kesme > 24) | adet | 1 | 1 | 0 | ±0 | GEÇTİ |
| C0 | Varsayılan çalışmada koruma aktif (koruma_aktif) | adet | 1 | 1 | 0 | ±0 | GEÇTİ |
| C1 | k_kWh dönüşüm katsayısı (3600/3,6e6) | - | 0.001 | 0.001 | 0 | ±1e-12 | GEÇTİ |
| C2 | Test modeli: 1000 W sabit yük x 1 saat | kWh | 1 | 1 | 0 | ±1e-06 | GEÇTİ |
| C3 | Tarife maskeleri toplamı - günün en küçük değeri (her dakika) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| C3 | Tarife maskeleri toplamı - günün en büyük değeri (her dakika) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| C4 | Doğru dilime düşen sınır anı (05:59, 06:00, 16:59, 17:00, 21:59, 22:00) | adet | 6 | 6 | 0 | ±0 | GEÇTİ |
| T4 | Röle açık (23:30) - I_rms | A | 0 | 0 | 0 | ±0.01 | GEÇTİ |
| T4 | Röle açık (23:30) - P | W | 0 | 0.000528991 | 0.000529 | ±1 | GEÇTİ |
| T4 | Röle açık (23:30) - Q | VAR | 0 | 4.19069e-10 | 4.19e-10 | ±1 | GEÇTİ |
| T4 | Röle açık (23:30) - V_rms (şebeke tarafı ölçüm) | V | 230 | 229.999 | %0.000 | %0.5 | GEÇTİ |
| T4 | Röle açıkken enerji sayacı artışı 23:03–24:00 (durmalı) | kWh | 0 | 5.02549e-07 | 5.03e-07 | ±0.0001 | GEÇTİ |
| T6 | Profil 03:30 - I_rms | A | 0.81 | 0.808679 | %0.163 | %2 | GEÇTİ |
| T6 | Profil 03:30 - P | W | 149 | 149.483 | %0.324 | %1 | GEÇTİ |
| T6 | Profil 03:30 - Q | VAR | 111 | 110.676 | %0.292 | %2 | GEÇTİ |
| T6 | Profil 03:30 - cos φ | - | 0.804 | 0.80369 | -0.00031 | ±0.005 | GEÇTİ |
| T6 | Profil 07:05 - I_rms | A | 9.35 | 9.35084 | %0.009 | %2 | GEÇTİ |
| T6 | Profil 07:05 - P | W | 2148 | 2147.86 | %0.007 | %1 | GEÇTİ |
| T6 | Profil 07:05 - Q | VAR | 111 | 110.593 | %0.367 | %2 | GEÇTİ |
| T6 | Profil 07:05 - cos φ | - | 0.999 | 0.998677 | -0.000323 | ±0.005 | GEÇTİ |
| T6 | Profil 12:00 - I_rms | A | 0.81 | 0.808678 | %0.163 | %2 | GEÇTİ |
| T6 | Profil 12:00 - P | W | 149 | 149.478 | %0.321 | %1 | GEÇTİ |
| T6 | Profil 12:00 - Q | VAR | 111 | 110.676 | %0.292 | %2 | GEÇTİ |
| T6 | Profil 12:00 - cos φ | - | 0.804 | 0.803681 | -0.000319 | ±0.005 | GEÇTİ |
| T6 | Profil 18:05 - I_rms | A | 19.76 | 19.7611 | %0.006 | %2 | GEÇTİ |
| T6 | Profil 18:05 - P | W | 4544 | 4543.71 | %0.006 | %1 | GEÇTİ |
| T6 | Profil 18:05 - Q | VAR | 110 | 110.492 | %0.448 | %2 | GEÇTİ |
| T6 | Profil 18:05 - cos φ | - | 1 | 0.999704 | -0.000296 | ±0.005 | GEÇTİ |
| T6 | Profil 18:30 - I_rms | A | 11.09 | 11.085 | %0.045 | %2 | GEÇTİ |
| T6 | Profil 18:30 - P | W | 2547 | 2547.11 | %0.004 | %1 | GEÇTİ |
| T6 | Profil 18:30 - Q | VAR | 111 | 110.576 | %0.382 | %2 | GEÇTİ |
| T6 | Profil 18:30 - cos φ | - | 0.999 | 0.999059 | 5.9e-05 | ±0.005 | GEÇTİ |
| T6 | Profil 19:30 - I_rms | A | 8.7 | 8.69749 | %0.029 | %2 | GEÇTİ |
| T6 | Profil 19:30 - P | W | 1632 | 1631.43 | %0.035 | %1 | GEÇTİ |
| T6 | Profil 19:30 - Q | VAR | 1158 | 1157.6 | %0.034 | %2 | GEÇTİ |
| T6 | Profil 19:30 - cos φ | - | 0.816 | 0.815551 | -0.000449 | ±0.005 | GEÇTİ |
| T6 | Profil 20:15 - I_rms | A | 14.51 | 14.51 | %0.000 | %2 | GEÇTİ |
| T6 | Profil 20:15 - P | W | 2770 | 2770.02 | %0.001 | %1 | GEÇTİ |
| T6 | Profil 20:15 - Q | VAR | 1861 | 1861.28 | %0.015 | %2 | GEÇTİ |
| T6 | Profil 20:15 - cos φ | - | 0.83 | 0.830026 | 2.62e-05 | ±0.005 | GEÇTİ |
| T6 | Profil 21:30 - I_rms | A | 6.94 | 6.93642 | %0.052 | %2 | GEÇTİ |
| T6 | Profil 21:30 - P | W | 1371 | 1371.39 | %0.028 | %1 | GEÇTİ |
| T6 | Profil 21:30 - Q | VAR | 815 | 815.17 | %0.021 | %2 | GEÇTİ |
| T6 | Profil 21:30 - cos φ | - | 0.86 | 0.859604 | -0.000396 | ±0.005 | GEÇTİ |
| T6 | Profil 22:45 - I_rms | A | 12.22 | 12.2206 | %0.005 | %2 | GEÇTİ |
| T6 | Profil 22:45 - P | W | 2690 | 2690.03 | %0.001 | %1 | GEÇTİ |
| T6 | Profil 22:45 - Q | VAR | 815 | 814.764 | %0.029 | %2 | GEÇTİ |
| T6 | Profil 22:45 - cos φ | - | 0.957 | 0.957064 | 6.36e-05 | ±0.005 | GEÇTİ |
| T6 | Profil 23:30 - I_rms | A | 6.76 | 6.76362 | %0.054 | %2 | GEÇTİ |
| T6 | Profil 23:30 - P | W | 1552 | 1551.69 | %0.020 | %1 | GEÇTİ |
| T6 | Profil 23:30 - Q | VAR | 111 | 110.618 | %0.345 | %2 | GEÇTİ |
| T6 | Profil 23:30 - cos φ | - | 0.997 | 0.997469 | 0.000469 | ±0.005 | GEÇTİ |
| T6 | Vrms (12:00) | V | 230 | 229.999 | %0.001 | %0.5 | GEÇTİ |
| T7 | Toplam enerji 06:00 | kWh | 0.897 | 0.894996 | %0.223 | %1 | GEÇTİ |
| T7 | Toplam enerji 17:00 | kWh | 2.874 | 2.87505 | %0.037 | %1 | GEÇTİ |
| T7 | Toplam enerji 22:00 | kWh | 10.978 | 10.9709 | %0.064 | %1 | GEÇTİ |
| T7 | Toplam enerji 24:00 (günlük) | kWh | 14.56 | 14.5527 | %0.050 | %1 | GEÇTİ |
| T7 | Negatif P geçicilerinin enerjisi (tolerans: toplamın %0,1) | kWh | 0 | -0 | -0 | ±0.01456 | GEÇTİ |
| T8 | T1 Gündüz sayacı | kWh | 1.977 | 1.98005 | %0.155 | %1 | GEÇTİ |
| T8 | T2 Puant sayacı | kWh | 8.103 | 8.09583 | %0.089 | %1 | GEÇTİ |
| T8 | T3 Gece sayacı | kWh | 4.479 | 4.47677 | %0.050 | %1 | GEÇTİ |
| T8 | abs(T1 + T2 + T3 - Toplam) | kWh | 0 | 6.41265e-13 | 6.41e-13 | ±0.001 | GEÇTİ |
| T8 | T1 sayacının 06:00 öncesi değeri | kWh | 0 | 1.78695e-06 | 1.79e-06 | ±0.001 | GEÇTİ |
| T8 | T2 sayacının 17:00 öncesi değeri | kWh | 0 | 1.78688e-06 | 1.79e-06 | ±0.001 | GEÇTİ |
| T8 | T3 sayacının 06:00-22:00 arası artışı | kWh | 0 | 6.85469e-05 | 6.85e-05 | ±0.001 | GEÇTİ |
| T9 | cos φ (24:00) | - | 0.997 | 0.997469 | 0.000469 | ±0.005 | GEÇTİ |
| T9 | En büyük fark: P/√(P²+Q²) ile P/(Vrms·Irms) | - | 0 | 1.53672e-05 | 1.54e-05 | ±0.005 | GEÇTİ |
| T10 | Endüktif reaktif enerji | kVARh | 6.339 | 6.32874 | %0.162 | %1 | GEÇTİ |
| T10 | Kapasitif reaktif enerji (normal günde kapasitif yük yok) | kVARh | 0 | 0.00815833 | 0.00816 | ±0.02 | GEÇTİ |
| T10 | Reaktif oran E_R / E (izleme göstergesi, ceza değil) | % | 43.5 | 43.4856 | -0.0144 | ±0.5 | GEÇTİ |
| T12 | Kondansatör açık (03:30) - Q | VAR | -889.3 | -889.357 | %0.006 | %2 | GEÇTİ |
| T12 | Kondansatör açık (03:30) - Q işareti (−1 = kapasitif) | - | -1 | -1 | 0 | ±0 | GEÇTİ |
| T12 | Kondansatör açık (03:30) - P (değişmemeli) | W | 149.7 | 149.814 | %0.076 | %1 | GEÇTİ |
| T12 | Kondansatör açık (03:30) - I_rms | A | 3.921 | 3.92126 | %0.007 | %2 | GEÇTİ |
| T12 | Kondansatör açık (03:30) - S | VA | 901.8 | 901.887 | %0.010 | %2 | GEÇTİ |
| T12 | Kondansatör açık (03:30) - cos φ (işaretsiz gösterim) | - | 0.166 | 0.166112 | 0.000112 | ±0.005 | GEÇTİ |
| T12 | Kapasitif sayaç artışı 03:03–03:57 | kVARh | 0.8004 | 0.800422 | %0.003 | %1 | GEÇTİ |
| T12 | Endüktif sayaç artışı 03:03–03:57 (artmamalı) | kVARh | 0 | 0 | 0 | ±0.001 | GEÇTİ |
| T12 | Aktif enerji artışı 03:03–03:57 (kondansatör aktif enerji eklememeli) | kWh | 0.1347 | 0.134832 | %0.098 | %1 | GEÇTİ |
| T13 | Profil 03:30 - S = Vrms·Irms | VA | 185.801 | 185.995 | %0.105 | %2 | GEÇTİ |
| T13 | Profil 07:05 - S = Vrms·Irms | VA | 2150.87 | 2150.68 | %0.009 | %2 | GEÇTİ |
| T13 | Profil 12:00 - S = Vrms·Irms | VA | 185.801 | 185.995 | %0.104 | %2 | GEÇTİ |
| T13 | Profil 18:05 - S = Vrms·Irms | VA | 4545.33 | 4545.03 | %0.007 | %2 | GEÇTİ |
| T13 | Profil 18:30 - S = Vrms·Irms | VA | 2549.42 | 2549.55 | %0.005 | %2 | GEÇTİ |
| T13 | Profil 19:30 - S = Vrms·Irms | VA | 2001.1 | 2000.41 | %0.034 | %2 | GEÇTİ |
| T13 | Profil 20:15 - S = Vrms·Irms | VA | 3337.1 | 3337.28 | %0.005 | %2 | GEÇTİ |
| T13 | Profil 21:30 - S = Vrms·Irms | VA | 1594.95 | 1595.37 | %0.026 | %2 | GEÇTİ |
| T13 | Profil 22:45 - S = Vrms·Irms | VA | 2810.75 | 2810.71 | %0.001 | %2 | GEÇTİ |
| T13 | Profil 23:30 - S = Vrms·Irms | VA | 1555.96 | 1555.63 | %0.022 | %2 | GEÇTİ |
| T13 | En büyük bağıl fark: Vrms·Irms ile √(P²+Q²) (10 nokta) | - | 0 | 1.69503e-05 | 1.7e-05 | ±0.005 | GEÇTİ |
| T13 | Günün en büyük S değeri (18:00–18:10 tepe) | VA | 4545.3 | 4545.03 | %0.006 | %1 | GEÇTİ |

Not: Ekrandaki cos φ işaretsizdir; yükün kapasitif mi endüktif mi olduğunu Q'nun işareti gösterir (T12).
