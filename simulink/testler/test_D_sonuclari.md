# Akıllı Sayaç – D Aşaması Koruma Testleri

- Tarih: 22-Nov-2026 18:20:56
- MATLAB: 26.2.0.3386108 (R2026b)
- Model: Akilli_Sayac.slx, çalışma modu: normal (koruma aktif)
- Parametreler: P_sinir = 4000 W, P_geri = 3800 W, t_uyari = 1 dk, t_asim = 3 dk, t_bekle = 5 dk, V = 207–253 V, t_kararli = 60 ms (3 periyot)
- Zaman ölçeği: profil 1 s = 1 saat (1 dk = 16.7 ms sim); fiziksel 1 periyot = 20 ms sim = 1,2 profil dk
- Özet: **39 GEÇTİ, 0 KALDI**

| Senaryo | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |
|---|---|---|---|---|---|---|---|
| S1 | Uyarı sayısı | adet | 0 | 0 | 0 | ±0 | GEÇTİ |
| S1 | Kesme sayısı | adet | 0 | 0 | 0 | ±0 | GEÇTİ |
| S1 | Röle gün boyu kapalı (en küçük role) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| S1 | Gün boyu P < P_sinir (1 = evet) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| S1 | Günlük enerji (referans günle aynı) | kWh | 14.56 | 14.553 | %0.048 | %1 | GEÇTİ |
| S1 | Durum kodu 23:30 (0 = normal) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| S2 | Uyarı sayısı | adet | 1 | 1 | 0 | ±0 | GEÇTİ |
| S2 | Uyarı başlama anı (saat) | saat | 18.0333 | 18.034 | 0.000667 | ±0.00333333 | GEÇTİ |
| S2 | Kesme sayısı (aşım < t_asim) | adet | 0 | 0 | 0 | ±0 | GEÇTİ |
| S2 | Röle gün boyu kapalı (en küçük role) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| S2 | Aşım sırasında en büyük P (sınır aşıldı mı) | W | 4544 | 4543.69 | %0.007 | %2 | GEÇTİ |
| S3 | Kesme sayısı | adet | 1 | 1 | 0 | ±0 | GEÇTİ |
| S3 | Kesme anı (saat) | saat | 18.0683 | 18.067 | -0.00133 | ±0.00416667 | GEÇTİ |
| S3 | Kesmeden 10 dk sonra I_rms (yük gerçekten kesildi) | A | 0 | 0 | 0 | ±0.01 | GEÇTİ |
| S3 | Kesmeden 10 dk sonra P | W | 0 | 0.000529 | 0.000529 | ±1 | GEÇTİ |
| S3 | Röle açıkken V_rms (şebeke var) | V | 230 | 229.999 | %0.000 | %0.5 | GEÇTİ |
| S3 | Onaysız yeniden bağlantı sayısı | adet | 0 | 0 | 0 | ±0 | GEÇTİ |
| S3 | Gün sonunda röle (0 = açık, onay bekliyor) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| S3 | Durum kodu 23:30 (2 = aşırı güç kilidi) | - | 2 | 2 | 0 | ±0 | GEÇTİ |
| S3 | Kesmeden sonra enerji artışı 18:10–24:00 (durmalı) | kWh | 0 | 3.08581e-06 | 3.09e-06 | ±0.0001 | GEÇTİ |
| S4 | Kesme sayısı | adet | 1 | 1 | 0 | ±0 | GEÇTİ |
| S4 | Bağlantı KABUL sayısı | adet | 1 | 1 | 0 | ±0 | GEÇTİ |
| S4 | Bağlantı kabul anı (saat) | saat | 18.25 | 18.25 | 0 | ±0.00166667 | GEÇTİ |
| S4 | Bağlantı anında tahmini yük (≤ P_geri) | W | 2550 | 2550 | %0.000 | %0.1 | GEÇTİ |
| S4 | Bağlantıdan sonra P 18:30 (fırın + baz) | W | 2547 | 2547.13 | %0.005 | %2 | GEÇTİ |
| S4 | Gün sonunda röle (1 = kapalı) | - | 1 | 1 | 0 | ±0 | GEÇTİ |
| S4 | Durum kodu 23:30 (0 = normal) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| S5 | Bağlantı RED sayısı | adet | 1 | 1 | 0 | ±0 | GEÇTİ |
| S5 | Red anı (saat) | saat | 18.1 | 18.1 | 0 | ±0.00166667 | GEÇTİ |
| S5 | Red nedeni maskesi (1 bekleme + 2 yük = 3) | - | 3 | 3 | 0 | ±0 | GEÇTİ |
| S5 | Bağlantı KABUL sayısı | adet | 0 | 0 | 0 | ±0 | GEÇTİ |
| S5 | Koşullar sonradan sağlansa da röle açık (18:30) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| S5 | Gün sonunda röle (0 = açık) | - | 0 | 0 | 0 | ±0 | GEÇTİ |
| S6 | Bağlantı anında V_rms (aralık dışı) | V | 190 | 189.999 | %0.000 | %1 | GEÇTİ |
| S6 | Durum kodu 18:16 (5 = gerilim aralık dışı) | - | 5 | 5 | 0 | ±0 | GEÇTİ |
| S6 | Gerilim aralık dışı olayı (42) sayısı | adet | 1 | 1 | 0 | ±0 | GEÇTİ |
| S6 | Bağlantı RED sayısı | adet | 1 | 1 | 0 | ±0 | GEÇTİ |
| S6 | Red nedeni maskesi (4 = gerilim) | - | 4 | 4 | 0 | ±0 | GEÇTİ |
| S6 | Gerilim düzeldikten sonra röle (18:30, 0 = açık) | - | 0 | 0 | 0 | ±0 | GEÇTİ |

Not: "saat" birimindeki değerler profil saatidir (18.0683 = 18:04,1).
