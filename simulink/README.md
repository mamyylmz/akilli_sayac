# Akıllı Sayaç Projesi – Simulink Modeli (v2, ev tipi)

**Durum tarihi:** 20.11.2026  **Hazırlayan:** Poyraz Ege Taş (şebeke ve devre tasarımı)

## 1. Klasördeki dosyalar

| Dosya | Ne işe yarar |
|---|---|
| `Akilli_Sayac.slx` | **Ana model** — tek çalışma dosyası (bunu açın) |
| `yedekler/` | Tarihli yedekler `Akilli_Sayac_YYYY_AA_GG[_SSDD].slx` (değiştirmeyin) |
| `akilli_sayac_param.m` | Tüm parametreler, zaman ölçekleri ve test modları. Model her çalıştırmada bunu otomatik çalıştırır (InitFcn) |
| `koruma_mantigi.m` | D aşaması: aşırı güç koruması, yeniden bağlantı koşulları, durum ve olay kodları (`Koruma_Mantigi` bloğu çağırır) |
| `batarya_mantigi.m` | Ev tipi batarya: şarj/deşarj kararı ve doluluk (SOC) hesabı (`Batarya_Mantigi` bloğu çağırır) |
| `testler/test_dogrulama.m` | A–C aşamaları doğrulaması, `measurement_test` modunda (koruma ve batarya kapalı) |
| `testler/test_D_koruma.m` | D aşaması: 6 koruma senaryosu (normal, kısa aşım, kalıcı aşım, güvenli bağlantı, red, gerilim arızasında red) + olay kaydı |
| `testler/test_B_batarya.m` | Batarya: bataryalı gün, ada çalışma önleme, ölçüm testi modunda kapalı olma |
| `testler/test_E_guc_kalitesi.m` | E aşaması: kesinti, gerilim çökmesi ve yükselmesi; olay başlangıcı, süresi, ölçülen değerler, sistem tepkisi |
| `testler/test_F_talep.m` | F aşaması: çamaşır makinesini gece tarifesine kaydırma (enerji korunur, T2 → T3) |
| `testler/tum_testler.m` | Bütün testleri sırayla çalıştırıp genel özet verir |
| `testler/test_sonuclari.md` / `.xlsx` | Betiğin ürettiği sonuçlar: her ölçüm ayrı satırda, sayısal sütunlar (beklenen / gerçekleşen / fark / hata / sonuç) |
| `testler/teorik_hesaplar.md` | Beklenen değerlerin hesabı (zaman dilimi bazında P, Q, S, kWh, kVARh; kapasitif test yükü; röle testi) |
| `testler/C_asamasi_dogrulama.xlsx` | Formüllü doğrulama çalışma kitabı (C aşaması, 18.11.2026 çalıştırması): cihaz hesapları, dilim bazında enerji, tarife dağılımı |
| `raporlar/` | Haftalık raporlar ve proje kararlarının karşılanma raporu |

**Git deposu:** https://github.com/mamyylmz/akilli_sayac → `simulink/` klasörü. Depoda `yedekler/` ve `raporlar/` bulunmaz (`.gitignore`): Git her sürümü zaten sakladığı için yedeklere gerek yok; raporlarda ekip üyelerinin öğrenci numaraları olduğu için herkese açık depoya konmaz.

## 2. Nasıl çalıştırılır

1. MATLAB'da bu klasörü **Current Folder** yapın.
2. `Akilli_Sayac.slx` modelini açın ve **Run**'a basın (5–10 sn sürer).
3. Sonuçlar: **Scope1** (I_rms, P, Q, V_rms), **Enerji_Scope**, **GucFaktoru_Scope**, Display blokları ve **HAN – Ev İçi Müşteri Ekranı** (Dashboard).
4. Sunum için: SIMULATION › Run (▼) › Simulation Pacing › hız 1 → bir gün 24 saniyede, HAN ekranı canlı izlenir.
5. **Testler:** Modeli kaydedin (Ctrl+S). `simulink` klasöründeyken komut penceresine `addpath testler` ve ardından `tum_testler` yazın (~6 dk; hepsini çalıştırır) ya da tek bir test adını yazın (ör. `test_D_koruma`).

Gereken araç kutuları: Simulink, Simscape, Simscape Electrical.
Model daha yeni bir MATLAB sürümünde kaydedildi. Daha eski sürümde açılmazsa haber verin, eski sürüme dışa aktarılabilir.

**Değerleri değiştirmek:** Bloklara sayı değil değişken adı yazıldı. Değer değiştirmek için yalnızca `akilli_sayac_param.m` dosyasını düzenleyin.

## 3. Zaman ölçeği ve tarife

- **1 s simülasyon = 1 saat.** Stop time = 24 s = 1 gün. Scope'larda zaman ekseni doğrudan saattir (7 = 07:00).
- Üç zamanlı tarife dilimleri: **Gündüz (T1) 06–17, Puant (T2) 17–22, Gece (T3) 22–06.**
- Enerji dönüşümü: kWh = ∫P dt / 1000.

## 4. Model mimarisi

| Bölüm | Bloklar | Not |
|---|---|---|
| Şebeke | AC Voltage Source (230 V rms, 50 Hz) | Simscape Foundation |
| Ölçüm noktası | Current Sensor, Voltage Sensor | Gerilim **şebeke tarafında**: röle açıkken de gerilim ölçülür |
| Ana röle (uzaktan kesme-açma) | Switch `Ana_Role` | Komut sinyali `Role_Komut`. Şu an `Kesme_Testi` Step bloğundan geliyor (test kapalı) |
| Ev yükleri | Baz yük (R-L) + 6 cihaz alt sistemi | Her cihaz: saat → program tablosu → anahtar → R (motorlularda R-L) |
| Ölçüm | RMS Measurement (×2), Power Measurement | Base frequency 50 Hz, bir periyotluk pencere |
| Enerji sayacı | Gain (`k_kWh`) + Integrator | Toplam kWh |
| Üç zamanlı sayaç | Tarife maskeleri (Lookup, Flat) × güç → 3 Integrator | T1 gündüz, T2 puant, T3 gece |
| Reaktif enerji | Saturation ile endüktif/kapasitif ayrımı → 2 Integrator | Yalnızca izleme (mesken muaf) |
| Güç faktörü | Fcn: P / √(P² + Q²) | Anlık cos φ (işaretsiz) |
| Görünür güç | Product `Gorunur_Guc`: V_rms · I_rms | S (VA) |
| Kapasitif test yükü | Alt sistem `Kapasitif_Test_Yuku` (anahtar + 60,17 µF) | **Normal günde kapalı.** Yalnızca T12 testinde 03:00–04:00 açılır |
| HAN ekranı | Dashboard: Gauge, Lamp, Display | Puant lambası 17–22 arası kırmızı |

## 5. Sinyaller (Goto etiketleri)

Algoritma, AMI veya fatura tarafında kullanılabilecek sinyaller:

| Etiket | Anlamı | Birim |
|---|---|---|
| `V_anlik`, `I_anlik` | Anlık gerilim ve akım | V, A |
| `V_rms`, `I_rms` | Etkin değerler | V, A |
| `P_aktif` | Aktif güç | W |
| `Q_reaktif` | Reaktif güç (endüktif +) | VAR |
| `Role_Komut` | **Giriş:** 1 = enerji ver, 0 = kes | — |
| `E_KWh` | Toplam aktif enerji (etikette **büyük K**) | kWh |
| `E_T1`, `E_T2`, `E_T3` | Gündüz / Puant / Gece aktif enerji | kWh |
| `E_Rend`, `E_Rkap` | Endüktif / Kapasitif reaktif enerji | kVARh |
| `S_gorunur` | Görünür güç (V_rms · I_rms) | VA |
| `cos_phi` | Anlık güç faktörü (işaretsiz; yön için Q'nun işaretine bakılır) | — |

## 6. Ev yük profili

Cihaz güçleri 6. hafta ders slaytındaki ev aletleri tablosundan alındı.

| Cihaz | Güç | Tür | Çalışma saati |
|---|---|---|---|
| Baz yük (buzdolabı + bekleme) | 150 W | Motorlu, cos φ 0,80 | 24 saat |
| Su ısıtıcı | 2,0 kW | Omik | 07:00–07:10, 18:00–18:10 |
| Fırın | 2,4 kW | Omik | 18:00–19:00 |
| TV | 83 W | Omik | 19:00–24:00 |
| Bulaşık makinesi | 1,32 kW | Omik | 22:30–24:00 |
| Çamaşır makinesi | 1,4 kW | Motorlu, cos φ 0,80 | 19:00–20:30 |
| Klima | 1,14 kW | Motorlu, cos φ 0,85 | 20:00–23:00 |

**Günlük enerji (hesaplanan): 14,56 kWh.** Gündüz 1,98 / Puant 8,10 / Gece 4,48 kWh.
En yüksek anlık güç: 18:00–18:10 arasında **4,54 kW** (su ısıtıcı + fırın + baz yük).

## 7. Yapılan testler

T1–T11 ilk olarak Scope ve Display değerleriyle elle doğrulandı. T4 ve T6–T13 ile parametre/katsayı kontrolleri (C0–C4) `testler/test_dogrulama.m` ile **otomatik olarak** tekrarlanır.
**Güncel sonuç (19.11.2026 18:02, R2026b): 92 GEÇTİ, 0 KALDI, 0 BEKLİYOR** → `testler/test_sonuclari.md`

| Test | İçerik | Sonuç |
|---|---|---|
| T1 | Dalga şekli: v tepe 325 V, i tepe 14,1 A, akım 2,05 ms geride (eski 1840 W test yükü) | Geçti |
| T2 | RMS, P, Q: 230 V, 10 A, 1840 W, 1380 VAR | Geçti |
| T3 | Anahtarlı yük (su ısıtıcı): 17,74 A, 3839 W | Geçti |
| T4 | Uzaktan kesme: röle açılınca I = P = Q = 0, V = 230 V, enerji sayacı durur | Geçti (otomatik) |
| T5 | Cihazları alt sisteme çevirme (refactoring): sonuç değişmedi | Geçti |
| T6 | 24 saatlik ev profili: tüm zaman dilimlerinde I, P, Q hesapla örtüşüyor | Geçti |
| T7 | Enerji sayacı doğruluğu: 14,55 kWh ölçülen / 14,56 kWh hesaplanan (−%0,07) | Geçti |
| T8 | Tarife bütünlüğü: T1 + T2 + T3 = toplam (1,98 + 8,10 + 4,48 = 14,55 kWh) | Geçti |
| T9 | Güç faktörü profili: gece 0,80, puantta 0,82–0,86, gün sonu 0,9975 | Geçti |
| T10 | Reaktif enerji: endüktif 6,33 kVARh (beklenen 6,34); oran %43,5. Kapasitif 0,008 kVARh (anahtarlama anlarındaki ölçüm sıçramaları; gözlem) | Geçti |
| T11 | HAN ekranı: değerler sayaçlarla aynı, puant lambası 17–22 arası yanıyor | Geçti |
| T12 | Kapasitif test yükü (03:00–04:00): Q = −889 VAR, kapasitif sayaç +0,8005 kVARh, endüktif sayaç artmıyor, P değişmiyor | Geçti (otomatik) |
| T13 | Görünür güç: 10 noktada S = V·I, √(P²+Q²) ile fark %0,0002; günün tepesi 4545 VA | Geçti (otomatik) |

## 8. Önemli notlar

- 3. rapordaki **L = 87,5 mH hatalıydı**, doğrusu 43,93 mH (T1–T4 testleri bu değerle yapıldı).
- **Reaktif ceza ve otomatik kompanzasyon kaldırıldı:** mesken ve tek fazlı aboneler reaktif bedelden muaf. Sayaç Q ve cos φ'yi yalnızca güç kalitesi izleme için ölçüyor.
- Motorlu cihazların bobinlerinde **Parallel conductance = 1e-4**. Anahtar açılınca bobin enerjisinin boşalma yolu; değiştirmeyin.
- Ölçüm blokları bir yük değişiminden sonra yaklaşık bir periyot (20 ms) hatalı değer verir (Q'daki kısa sıçramalar). Karar algoritmaları bu süreyi beklemeli; koruma kararlarında gecikme/filtre kullanılacak.
- **Güç faktörü:** Ekrandaki cos φ = P/√(P²+Q²) (yer değiştirme güç faktörü). Gerçek güç faktörü PF = P/(Vrms·Irms). Bu sinüzoidal modelde ikisi eşit (betikte kontrol ediliyor); harmonikli yüklerde eşit değildir.
- **Reaktif oran** bir izleme göstergesidir, ceza hesabı değildir. Yalnızca dönem sonunda (24:00) yorumlanmalıdır.
- Reaktif enerji değerleri (E_Rend, E_Rkap) yalnızca bu tek fazlı, sinüzoidal model varsayımları kapsamında geçerlidir.
- **Test senaryosu:** Parametre dosyasının sonundaki bölüm, çalışma alanında `test_senaryo` adlı bir struct varsa onun alanlarını kullanır (ör. `test_senaryo.t_kesme = 23`). Test betiği bunu kendisi açar ve kapatır. Elle denediyseniz iş bitince `clear test_senaryo` yazın.
- **cos φ işaretsizdir.** Kapasitif yükte de pozitif görünür; yükün endüktif mi kapasitif mi olduğunu Q'nun işareti gösterir.
- Test betiği çalışmadan önce modelin kaydedilmiş olmasını ister (kaydedilmemiş değişiklik test sonucunu belirsiz yapar).
- Modeli kaydederken **Save As kullanmayın** (sizi yeni dosyaya geçirir). Yedekler `yedekler/` klasörüne tarihli adla kopyalanır. Dosya adlarında **nokta ve boşluk kullanmayın**; Simulink model adı olarak kabul etmez.

## 8b. D aşaması ve batarya (19.11.2026)

**Zaman ölçekleri:** Profil ölçeği 1 s = 1 saat (cihaz programları, tarife, enerji, koruma zamanlayıcıları); fiziksel ölçek 50 Hz, 1 periyot = 20 ms = 1,2 profil dakikası (ölçüm penceresi, geçiciler, gerilim kararlılık penceresi). Profil ölçeğinde ~1,2 dakikadan kısa süreler ölçülemez.

**Şebeke:** Kontrollü gerilim kaynağı (`Sebeke`): v(t) = sebeke_V(t)·√2·sin(ωt). Normal günde 230 V; gerilim olayı senaryoları `sebeke_t / sebeke_V` ile kurulur. Hesaplanan gerilim `V_ref` etiketiyle batarya akımında kullanılır (ölçüm yerine; cebirsel döngü oluşmaz).

**Çalışma modları (`test_modu`):** `normal` = koruma ve batarya AKTİF (varsayılan). `measurement_test` = koruma ve batarya kapalı; yalnızca C aşaması referans ölçüm testleri (14,56 kWh referansı korunur).

**Koruma (D):** P_sinir 4000 W, P_geri 3800 W (histerezis). Aşım 1 dk sürerse uyarı, 3 dk sürerse röle açılır ve kilitlenir. Yeniden bağlantı yalnızca yetkili istekle (`baglan_t/u`) ve şu koşullarla: kesmeden ≥ 5 dk geçmiş, tahmini yük ≤ 3800 W (cihaz programlarından; röle açıkken ölçülen P = 0 kullanılmaz), gerilim 207–253 V aralığında ve 3 periyot (60 ms ≈ 3,6 profil dk) kararlı, şebeke var.

| Durum kodu | Anlamı |
|---|---|
| 0 | Normal |
| 1 | Aşırı güç uyarısı |
| 2 | Aşırı güç kesmesi – kilitli, yetkili onay bekliyor |
| 3 | Kullanıcı/uzaktan komutla açık |
| 4 | Şebeke yok (V < 23 V) |
| 5 | Gerilim 207–253 V dışında |

Olay kodları: 10/11 uyarı başladı/bitti, 20 kesme, 30/31 bağlantı kabul/red, 40/41 şebeke kesildi/geldi, 42/43 gerilim aralık dışı/döndü, 50/51 kullanıcı kesti/açtı. Red maskesi: 1 bekleme, 2 yük, 4 gerilim, 8 şebeke yok (toplanır).

**Batarya:** 5 kWh, SOC 0,10–0,95; gece (T3) 1500 W şarj (P_geri − tahmini yükü aşmayacak şekilde kısılır), puantta (T2) en fazla 2500 W deşarj (tahmini yükü aşmaz → şebekeye enerji verilmez); röle açıkken durur. Bataryalı günde 18:00 tepesi 4544 W → ≈ 2044 W'a iner, koruma kesmez. Kontrollü akım kaynağının (`Batarya`) **+ ucu nötrde** olduğu için akım kazancı **+1/Vrms²**'dir: i(t) = P_bat·v_ref(t)/230².

| Sinyal (Goto) | Anlamı |
|---|---|
| `Role_Komut` | Kullanıcı/uzaktan komut (1 = enerji ver) |
| `Role_Cikis` | Koruma mantığının röle çıkışı (rölenin asıl komutu) |
| `Durum_Kodu`, `Olay_Kodu`, `Red_Maske`, `Asiri_Guc_Uyari` | Koruma çıkışları |
| `P_tahmin` | Cihaz programlarından tahmini yük (W) |
| `Tarife_T2`, `Tarife_T3` | Tarife dilim maskeleri |
| `V_ref` | Şebekenin hesaplanan anlık gerilimi (V) |
| `P_batarya`, `SOC`, `Batarya_Mod` | Batarya gücü (W; + deşarj, − şarj), doluluk, mod (0 bekleme, 1 şarj, 2 deşarj) |

**Test sonuçları (19.11.2026):** C 93/93 (measurement_test), D 39/39, batarya testi: `test_B_batarya` (20.11.2026).

## 9. Sıradaki adımlar (Simulink tarafı)

Tamamlandı: A–C (93 test), D aşaması koruma ve röle mantığı (39 test), ev tipi batarya.

1. E (güç kalitesi) ve F (talep yönetimi) test betikleri hazır: `test_E_guc_kalitesi`, `test_F_talep`
2. Yazılıma veri aktarımı (CSV/JSON), veri sözleşmesi kesinleşince
3. İsteğe bağlı (P2): THD/harmonik, aşırı gerilimde röle açma (ekip kararı gerekir)

TL cinsinden fatura: yazılım katmanı (T1/T2/T3 sayaç değerlerini kullanır).
