# Teorik Hesaplar (Beklenen Değerler) – A–C Aşamaları

Bu belge, `testler/test_dogrulama.m` betiğindeki **beklenen değerlerin** nereden geldiğini gösterir.
Hesaplar, modeldeki devrenin fazör (sinüzoidal kararlı durum) çözümüyle yapılmıştır.
Anahtarların 0,01 Ω kapalı direnci, ana rölenin 0,01 Ω direnci ve bobinlerin 1e-4 S paralel iletkenliği hesaba katılmıştır.

## 1. Varsayımlar
- Tek fazlı, sinüzoidal 230 V rms / 50 Hz şebeke; harmonik yok.
- **Zaman ölçeği: 1 s simülasyon = 1 saat.** 24 s simülasyon = 1 gün.
- Cihaz güçleri: Akıllı Şebekeler 6. hafta slaytındaki ev aletleri tablosu. Motorlu cihazların cos φ değerleri varsayımdır.
- Bu belgedeki reaktif büyüklükler (Q, kVARh, oran) **yalnızca bu model varsayımları kapsamında** geçerlidir. Sayaç bunları izleme amacıyla ölçer; kompanzasyon kapsam dışıdır.

## 2. Enerji dönüşüm katsayısı (k_kWh)
Güç W cinsinden, simülasyon zamanı s cinsinden. 1 simülasyon saniyesi 3600 gerçek saniyeyi temsil eder:

E [kWh] = ∫P dt · 3600 / 3,6×10⁶ = ∫P dt / 1000  →  **k_kWh = 1/1000**

Kontrol: 1000 W sabit yük, 1 simülasyon saniyesi (= 1 saat) → 1000 · 1 / 1000 = **1 kWh** (betikte C2 testi).

## 3. Tarife dilimleri
Gündüz T1 06:00–17:00, Puant T2 17:00–22:00, Gece T3 22:00–06:00 (Gediz Perakende tarife sayfası).

| Değişken | Saat noktaları | Değer |
|---|---|---|
| T1 | [0 6 17 25] | [0 1 0 0] |
| T2 | [0 17 22 25] | [0 1 0 0] |
| T3 | [0 6 22 25] | [1 0 1 1] |

Lookup Table "Flat" interpolasyonu, değeri bir sonraki noktaya kadar sabit tutar. Her an m1 + m2 + m3 = 1 olmalıdır; boşluk ya da çakışma olmamalıdır (betikte C3 ve C4 testleri).

## 4. Zaman dilimlerine göre beklenen değerler
Δt saat cinsindendir. E = P·Δt/1000 [kWh], E_R = Q·Δt/1000 [kVARh].

| Saat | Dilim | Çalışan cihazlar | Δt (h) | I (A) | P (W) | Q (VAR) | cos φ | E (kWh) | E_R (kVARh) |
|---|---|---|---|---|---|---|---|---|---|
| 00:00–06:00 | T3 | Baz | 6,000 | 0,81 | 149 | 111 | 0,804 | 0,897 | 0,664 |
| 06:00–07:00 | T1 | Baz | 1,000 | 0,81 | 149 | 111 | 0,804 | 0,149 | 0,111 |
| 07:00–07:10 | T1 | Baz + Su ısıtıcı | 0,167 | 9,35 | 2148 | 111 | 0,999 | 0,358 | 0,018 |
| 07:10–17:00 | T1 | Baz | 9,833 | 0,81 | 149 | 111 | 0,804 | 1,470 | 1,088 |
| 17:00–18:00 | T2 | Baz | 1,000 | 0,81 | 149 | 111 | 0,804 | 0,149 | 0,111 |
| 18:00–18:10 | T2 | Baz + Su ısıtıcı + Fırın | 0,167 | 19,76 | 4544 | 110 | 1,000 | 0,757 | 0,018 |
| 18:10–19:00 | T2 | Baz + Fırın | 0,833 | 11,09 | 2547 | 111 | 0,999 | 2,123 | 0,092 |
| 19:00–20:00 | T2 | Baz + TV + Çamaşır m, | 1,000 | 8,70 | 1632 | 1158 | 0,816 | 1,632 | 1,158 |
| 20:00–20:30 | T2 | Baz + TV + Çamaşır m, + Klima | 0,500 | 14,51 | 2770 | 1861 | 0,830 | 1,385 | 0,931 |
| 20:30–22:00 | T2 | Baz + TV + Klima | 1,500 | 6,94 | 1371 | 815 | 0,860 | 2,057 | 1,223 |
| 22:00–22:30 | T3 | Baz + TV + Klima | 0,500 | 6,94 | 1371 | 815 | 0,860 | 0,686 | 0,408 |
| 22:30–23:00 | T3 | Baz + TV + Klima + Bulaşık m, | 0,500 | 12,22 | 2690 | 815 | 0,957 | 1,345 | 0,407 |
| 23:00–24:00 | T3 | Baz + TV + Bulaşık m, | 1,000 | 6,76 | 1552 | 111 | 0,997 | 1,552 | 0,111 |

## 5. Toplamlar
| Büyüklük | Beklenen |
|---|---|
| Toplam aktif enerji | **14,560 kWh** |
| T1 Gündüz | **1,977 kWh** |
| T2 Puant | **8,103 kWh** |
| T3 Gece | **4,479 kWh** |
| T1 + T2 + T3 | 14,560 kWh (= toplam) |
| Endüktif reaktif enerji | **6,339 kVARh** |
| Kapasitif reaktif enerji | **0** (profilde kapasitif yük yok) |
| Reaktif oran | **%43,5** |
| Ara kontrol: 06:00 / 17:00 / 22:00 | 0,897 / 2,874 / 10,978 kWh |

## 6. Güç faktörü tanımları
- Modeldeki gösterge: **cos φ = P / √(P² + Q²)**. Power Measurement bloğu yalnızca 50 Hz bileşenini ölçtüğü için bu, *yer değiştirme güç faktörüdür*.
- *Gerçek güç faktörü*: **PF = P / (V_rms · I_rms)**.
- Sinüzoidal bir modelde ikisi eşittir. Harmonik içeren (doğrusal olmayan) yüklerde **eşit değildir**; PF daha düşük çıkar. Betik, bu modelde iki değerin farkının 0,005'ten küçük olduğunu kontrol eder (T9). Doğrusal olmayan yük eklenirse iki gösterge ayrı ayrı izlenmelidir.

## 7. Reaktif oran hakkında
- Oran = 100 · E_R,end / E_P. Bu bir **izleme göstergesidir, reaktif ceza hesabı değildir**; mesken aboneleri reaktif bedelden muaftır.
- Paydaya eklenen 1e-3 kWh yalnızca sıfıra bölmeyi önler. Günün başında tüketim çok küçükken oran anlamlı değildir. **Oran yalnızca dönem sonunda (24:00) yorumlanmalıdır.**

## 8. İşaret konvansiyonu
- **P > 0:** şebekeden çekilen (tüketilen) güç.
- **Q > 0:** endüktif yük (akım gerilimden geride). T2'de doğrulandı (R–L test yükü: +1380 VAR).
- **Q < 0:** kapasitif yük (akım gerilimden ileride). T12'de doğrulanır (bkz. §11).
- Ekrandaki cos φ **işaretsizdir**; yükün endüktif mi kapasitif mi olduğunu Q'nun işareti gösterir.

## 9. Bilinen ölçüm etkileri
- RMS ve güç ölçümü bir periyotluk (20 ms; gerçek zamanda 72 s) pencere kullanır. Her yük değişiminden sonra bu süre boyunca geçici değerler oluşur (Q'daki kısa sıçramalar). Kapasitif sayaçtaki küçük birikim (~0,008 kVARh) bu geçicilerden kaynaklanır.
- Koruma ve limit kararlarında (D aşaması) ham tek örnek yerine **gecikme ya da filtre** kullanılacaktır.
- Negatif P geçicilerinin enerjiye etkisi betikte ayrıca ölçülür; toplamın %0,1'inden küçük olması beklenir.

## 10. Görünür güç S (T13)
- Modelde **S = V_rms · I_rms** (`Gorunur_Guc` bloğu, `S_gorunur` etiketi). Bu, harmonikli durumda da geçerli olan tanımdır.
- Beklenen değer §4 tablosundaki P ve Q'dan: **S = √(P² + Q²)**. Sinüzoidal modelde iki tanım eşittir; betik farkın %0,5'ten küçük olduğunu kontrol eder.

| Saat | P (W) | Q (VAR) | S = √(P²+Q²) (VA) |
|---|---|---|---|
| 03:30 | 149 | 111 | 185,8 |
| 07:05 | 2148 | 111 | 2150,9 |
| 18:05 (günün tepesi) | 4544 | 110 | **4545,3** |
| 19:30 | 1632 | 1158 | 2001,1 |
| 20:15 | 2770 | 1861 | 3337,1 |
| 23:30 (gün sonu) | 1552 | 111 | **1556,0** |

## 11. Kapasitif test yükü (T12)
Normal günde kapalıdır (`kap_u = [0 0]`). Test betiği, parametre dosyasının **test senaryosu** bölümüyle 03:00–04:00 arasında açar. Bu saatte evde yalnızca baz yük çalışır.

**Kondansatör:** Q_kap = V²·ω·C → C = 1000 / (230² · 314,16) = **60,17 µF**

**Neden tam saatte açılıyor:** t = 3 s, 150. periyodun başıdır; gerilim sıfırdan geçer. Kondansatör gerilim sıfırken devreye girdiği için ani şarj akımı oluşmaz.

**Fazör çözümü (230 V, 50 Hz):**

| Kol | P (W) | Q (VAR) | I (A) |
|---|---|---|---|
| Baz yük (R + L ∥ 1e-4 S) | 149,49 | +110,68 | 0,809 |
| Kondansatör (+ anahtar 0,01 Ω) | 0,19 | −1000,0 | 4,348 |
| **Toplam** | **149,68** | **−889,32** | **3,921** |

- S = √(149,68² + 889,32²) = **901,8 VA**
- cos φ = 149,68 / 901,8 = **0,166** (kapasitif; ekranda işaretsiz görünür)
- 03:03–03:57 arası (0,9 saat; geçici bölgeler hariç):
  - kapasitif sayaç artışı = 889,32 · 0,9 / 1000 = **0,8004 kVARh**
  - endüktif sayaç artışı = **0** (Q < 0 iken endüktif sayaç saymaz)
  - aktif enerji artışı = 149,68 · 0,9 / 1000 = **0,1347 kWh** (kondansatör aktif enerji eklemez)

## 12. Ana röle kesme testi (T4)
Test senaryosunda `t_kesme = 23`: ana röle 23:00'te açılır ve gün sonuna kadar açık kalır.

- Röle açık direnç yolu 1e-8 S → I ≈ 230 · 1e-8 = 2,3 µA ≈ **0**. Bu yüzden P ≈ 0 ve Q ≈ 0.
- Gerilim **şebeke tarafında** ölçüldüğü için V_rms = **230 V** kalır. Böylece "röle açık" (V var) ile "şebeke kesildi" (V yok) durumları ayırt edilebilir (D aşaması).
- Enerji sayacı 23:03–24:00 arasında **artmamalıdır**.
