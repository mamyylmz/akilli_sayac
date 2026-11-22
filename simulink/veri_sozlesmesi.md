# Veri Sözleşmesi: Simulink → Yazılım (sürüm 1.0)

**Durum:** Proje yöneticisinin 22.11.2026 kararlarıyla güncellendi; birleştirme öncesi incelemeye sunulur.
**Hazırlayan:** Poyraz Ege Taş (Simulink) · **Tarih:** 22.11.2026
**Üreten betik:** `simulink/veri_aktar.m` · **Şema sürümü:** `1.0`

## 0. Kararlar (22.11.2026)

| # | Karar | Bu belgedeki karşılığı |
|---|---|---|
| 1 | Kayıt aralığı **1 dakika**; 15 dakikalık veri gerekirse yazılımda türetilir | §3 |
| 2 | Zaman damgası **aralık başlangıcı**, `[başlangıç, bitiş)` | §3 |
| 3 | Sayaç kimliği `SIM-0001` | §4 |
| 4 | Biçim: ölçüm CSV + olay CSV + meta JSON | §1 |
| 5 | Mevcut sütunlar korunur; negatif enerji, geçersiz satırlar ve cos φ işareti açıkça tanımlanır; şebekeden net çekilen enerji ile evin toplam tüketimi karıştırılmaz | §6 |
| 6 | Tam günlük model ve test çıktıları Git'e gönderilmez; yalnızca küçük, anonim, simülasyon olduğu belirtilmiş örnekler (fixture) tutulur | §9 |
| 7 | Yazılımdaki 1000 satır sınırı 1440 satıra uyarlanır | Yazılım tarafı |
| 8 | En az bir olay içeren test senaryosu için `olaylar.csv` örneği | §9 |
| 9 | Simulink'in hesapladığı değerler yazılımda yeniden üretilmez, doğrulanıp kullanılır; TL ve fiyatlar yalnızca yazılımda | §8 |
| + | Her çalıştırmanın benzersiz kimliği (`run_id`) ve CSV dosyalarının SHA-256 özetleri | §7 |

## 1. Ne üretilir

`veri_aktar` modeli bir gün (24 saat) çalıştırır ve aynı çalıştırmaya ait üç dosya yazar:

| Dosya | İçerik |
|---|---|
| `olcum_1dk_<gün>.csv` | 1440 satır; her satır bir dakikalık aralık |
| `olaylar_<gün>.csv` | Koruma olay kaydı, her olay bir satır. Olay yoksa yalnızca başlık satırı vardır |
| `meta_<gün>.json` | Şema sürümü, `run_id`, CSV özetleri, ayarlar, günlük toplamlar, sütun açıklamaları, kontroller |

`<gün>` = `YYYY-AA-GG` (varsayılan: çalıştırıldığı gün). `veri_aktar('gun','2026-11-26')`, `veri_aktar('sayac_id','SIM-0002')`.

## 2. Model sonucu ile test verisi ayrımı

| Durum | Klasör | Dosya adı | `meta.veri_turu` |
|---|---|---|---|
| Normal gün (`test_senaryo` tanımlı değil) | `ciktilar/model/` | `olcum_1dk_2026-11-22.csv` | `model` |
| Test senaryosu (`test_senaryo` tanımlı) | `ciktilar/test/` | `olcum_1dk_2026-11-22_TEST.csv` | `test` |

Test verisinin meta dosyasında senaryonun değiştirdiği parametreler yazar (`test_senaryosu`). `ciktilar/` klasörü Git'e gönderilmez.

## 3. Genel biçim kuralları

- UTF-8 (BOM yok), ayraç virgül, ondalık ayırıcı nokta, ilk satır başlık, satır sonu LF.
- Metin alanları yalnızca olay dosyasında ve çift tırnak içinde.
- Zaman: ISO 8601, yerel saat `+03:00` (Türkiye yıl boyu UTC+3). Örnek: `2026-11-22T18:05:00+03:00`.
- **Kayıt aralığı 1 dakika.** Satırın zamanı **aralığın başıdır**: `18:05` satırı `[18:05:00, 18:06:00)` aralığıdır. 15 dakikalık veri gerekirse yazılım 15 satırı birleştirir (enerjiler toplanır, kümülatif sayaçlarda 15. satır alınır).
- Birimler sütun adının sonundadır (`_V`, `_A`, `_W`, `_var`, `_VA`, `_kWh`, `_kvarh`).
- Kümülatif sayaçlar gün başında 0'dan başlar.
- Kaynak simülasyondur; gerçek sayaç ya da kişisel veri içermez.

## 4. Ölçüm dosyası: `olcum_1dk_<gün>.csv` (27 sütun)

Değer türü: **ortalama** = dakika içindeki zaman ağırlıklı ortalama; **aralık sonu** = dakikanın sonundaki değer; **aralık farkı** = o dakikadaki artış; **en büyük** = dakika içindeki en büyük değer.

| Sütun | Birim | Değer türü | Açıklama |
|---|---|---|---|
| `sayac_id` | – | metin | Sayaç kimliği (`SIM-0001`) |
| `run_id` | – | metin | Çalıştırma kimliği; bütün satırlarda ve üç dosyada aynı (§7) |
| `zaman` | – | aralık başı | ISO 8601, `+03:00` |
| `dakika` | dk | aralık başı | Gün içindeki dakika, 0–1439 |
| `tarife_dilimi` | – | aralık | 1 gündüz (06–17), 2 puant (17–22), 3 gece (22–06); modelin tarife tablosundan |
| `gecerli` | – | aralık | 1 = ölçüm geçerli; 0 = ölçüm penceresi dolmamış (§6.2) |
| `v_rms_V` | V | ortalama | Gerilim etkin değeri |
| `i_rms_A` | A | ortalama | Sayaç noktasındaki akımın etkin değeri |
| `p_W` | W | ortalama | Sayaç noktasındaki **net** aktif güç: + şebekeden çekilen, − şebekeye verilen (§6.1) |
| `q_var` | var | ortalama | Reaktif güç: + endüktif, − kapasitif |
| `s_VA` | VA | ortalama | Görünür güç, S = V·I |
| `cos_phi` | – | ortalama | Güç faktörü, işareti §6.3'te |
| `e_aralik_kWh` | kWh | aralık farkı | Bu dakikadaki **net** aktif enerji (negatif olabilir, §6.1) |
| `e_toplam_kWh` | kWh | aralık sonu | Gün başından beri net aktif enerji |
| `e_t1_kWh` | kWh | aralık sonu | T1 gündüz sayacı, net, kümülatif |
| `e_t2_kWh` | kWh | aralık sonu | T2 puant sayacı, net, kümülatif |
| `e_t3_kWh` | kWh | aralık sonu | T3 gece sayacı, net, kümülatif |
| `e_rend_kvarh` | kvarh | aralık sonu | Endüktif reaktif enerji, kümülatif |
| `e_rkap_kvarh` | kvarh | aralık sonu | Kapasitif reaktif enerji, kümülatif |
| `role_komut` | – | aralık sonu | Kullanıcı / uzaktan röle komutu: 1 enerji ver, 0 kes |
| `role` | – | aralık sonu | Koruma kararı / ana röle: 1 kapalı (enerji var), 0 açık |
| `durum` | – | aralık sonu | Sayaç durumu (§5.2) |
| `asiri_guc_uyari` | – | en büyük | 1 = dakika içinde aşırı güç uyarısı vardı |
| `olay_sayisi` | adet | toplam | Dakika içindeki olay sayısı (ayrıntı olay dosyasında) |
| `p_bat_W` | W | ortalama | Batarya gücü: + evi besliyor (deşarj), − şarj oluyor |
| `soc` | – | aralık sonu | Batarya doluluğu, 0–1 |
| `batarya_mod` | – | aralık sonu | 0 bekleme, 1 şarj, 2 deşarj |

Sütunlar 0.1 taslağıyla aynıdır; tek ek `run_id`'dir (karar +).

## 5. Olay dosyası: `olaylar_<gün>.csv`

| Sütun | Açıklama |
|---|---|
| `sayac_id`, `run_id` | Sayaç ve çalıştırma kimliği |
| `zaman` | Olayın zamanı, ISO 8601, saniye çözünürlüklü (`+03:00`) |
| `saat` | Aynı zaman, ondalık saat (ör. 18,0667 = 18:04:00) |
| `olay_kodu` | Kod (§5.1) |
| `olay` | Kodun Türkçe adı |
| `durum` | Olaydan sonraki sayaç durumu (§5.2) |
| `red_maske` | Yalnızca yeniden bağlantı isteklerinde (30/31) anlamlıdır (§5.3) |
| `red_nedeni` | Red maskesinin Türkçe açıklaması (boş = red yok) |

Normal günde (bataryalı) güç 4 kW sınırını aşmadığı için olay dosyası boştur. Olay içeren örnekler §9'da.

### 5.1 Olay kodları

| Kod | Olay | Kod | Olay |
|---|---|---|---|
| 10 | Aşırı güç uyarısı başladı | 11 | Aşırı güç uyarısı bitti |
| 20 | Aşırı güç kesmesi (röle açıldı, kilit) | | |
| 30 | Yeniden bağlantı kabul | 31 | Yeniden bağlantı red |
| 40 | Şebeke kesildi | 41 | Şebeke geri geldi |
| 42 | Gerilim 207–253 V dışına çıktı | 43 | Gerilim aralığa döndü |
| 50 | Kullanıcı kesti | 51 | Kullanıcı açtı |

### 5.2 Durum kodları

0 normal · 1 uyarı · 2 kesildi, onay bekliyor · 3 kullanıcı kesti · 4 şebeke yok · 5 gerilim aralık dışı

### 5.3 Red maskesi (toplam)

1 bekleme süresi dolmadı · 2 tahmini yük > P_geri (3800 W) · 4 gerilim aralık dışı ya da kararlı değil · 8 şebeke yok.
Örnek: 3 = 1 + 2 → bekleme dolmadı ve tahmini yük yüksek.

## 6. Tanımlar (karar 5)

### 6.1 Net enerji, evin tüketimi ve negatif değerler

- Batarya, sayacın **ev tarafındadır**. Sayaç yalnızca şebekeyle ev arasındaki **net** alışverişi ölçer:
  `p_W = evin yükü − p_bat_W` (deşarjda batarya yükün bir kısmını karşılar, şarjda yüke eklenir).
- `p_W`, `e_aralik_kWh`, `e_toplam_kWh` ve `e_t1/t2/t3_kWh` **şebekeden net çekilen** değerlerdir; **evin toplam tüketimi değildir**. Arayüzde "Şebekeden çekilen" diye gösterilmelidir.
- Evin toplam tüketimi bu dosyada sütun olarak yoktur. Gerekirse Simulink'te hesaplanıp yeni bir sütun olarak eklenir (karar 9 gereği yazılımda türetilmez).
- **İşaret:** + şebekeden eve, − evden şebekeye. Batarya şebekeye enerji vermek için çalıştırılmaz (deşarj ≤ tahmini yük). Buna rağmen batarya evin bütün yükünü karşıladığında, tahmin ile gerçek tüketim arasındaki küçük farktan `p_W` birkaç watt negatif olabilir. Normal günde en düşük −1,1 W, günlük toplam ≈ 0,0015 kWh.
- Negatif dakikalarda `e_aralik_kWh` negatif olur ve kümülatif sayaçlar çok az azalır. **Yazılım negatif değerleri sıfıra kırpmamalıdır.** Kırpılırsa §8'deki toplam kontrolleri tutmaz. Fatura son satırdaki net T1/T2/T3 değerleriyle hesaplanır.

### 6.2 Geçersiz ölçüm satırları (`gecerli = 0`)

- Gerilim, akım ve güç bir periyotluk (20 ms = 1,2 profil dakikası) pencereyle ölçülür. Pencere dolmadan başlayan dakikalarda `gecerli = 0` olur: her günün **ilk iki satırı (00:00, 00:01)**.
- Bu satırlarda `v_rms_V`, `i_rms_A`, `p_W`, `q_var`, `s_VA` ve `cos_phi` güvenilir değildir (00:00'da V = 0 görünür). "Şebeke yok" diye yorumlanmamalı; güç kalitesi analizlerine, alarmlara ve grafiklere katılmamalıdır.
- Satırlar **silinmez**, dosya her zaman 1440 satırdır. Enerji sütunları ve kümülatif sayaçlar bu satırlarda da geçerlidir.
- Ayrıca kesinti sırasında RMS hesabı sıfıra çok yakın bir sayının karekökünü alırken NaN üretebilir. Gerçek değer 0 olduğu için 0 yazılır ve meta dosyasının `notlar` alanında belirtilir. Bu satırlar `gecerli = 1`'dir; değerler doğrudur (V = 0, I = 0).

### 6.3 cos φ işareti

- `cos_phi = P / √(P² + Q²)`. İşareti **P'nin işaretini izler**: normalde pozitif, yalnızca net verilen (P < 0) dakikalarda negatiftir.
- **Endüktif / kapasitif ayrımı cos φ'den yapılmaz**, `q_var` işaretinden yapılır: `q_var > 0` endüktif (geri), `q_var < 0` kapasitif (ileri).
- P ve Q birlikte sıfıra yakınken (kesinti, açık röle, batarya bütün yükü karşılarken) cos φ ≈ 0'dır. `s_VA < 1` olan dakikalarda cos φ **tanımsız** kabul edilmelidir.

## 7. Çalıştırma kimliği ve dosya özetleri

- `run_id` biçimi: `<sayac_id>-<YYYYMMDD>T<HHMMSS>-<8 onaltılık karakter>`. Örnek: `SIM-0001-20261122T180512-6D3B1A55`.
- Aynı çalıştırmanın üç dosyasında da aynıdır: ölçüm ve olay dosyasında her satırda bir sütun, meta dosyasında `run_id` alanı.
- Meta dosyasındaki `dosyalar` alanında iki CSV'nin adı ve **SHA-256** özeti vardır (`olcum_sha256`, `olaylar_sha256`). Özet, dosyanın baytları üzerinden hesaplanır. Dosya Excel ile açılıp kaydedilirse ya da satır sonları değişirse özet tutmaz.
- **Yazılımın yapacağı doğrulama:**
  - iki CSV'nin SHA-256'sı meta ile aynı,
  - her satırdaki `run_id` = `meta.run_id`,
  - ölçümde 1440 satır.

  Windows'ta elle kontrol için: `certutil -hashfile <dosya> SHA256`.

## 8. Yazılım tarafı (karar 9)

- **Fatura (TL):** Fiyatlar yalnızca yazılımda tutulur; Simulink fiyat bilmez.
  - Son satırdaki net değerlerle: `TL = e_t1·f1 + e_t2·f2 + e_t3·f3` (+ diğer bileşenler).
  - Dakika bazında aynı sonuç: `TL = Σ e_aralik_kWh × f[tarife_dilimi]`.
- **Tekrar hesap yok, doğrulama var:** cos φ, T1/T2/T3, durum gibi değerler yeniden hesaplanmaz, dosyadan okunur. Yazılımın yapabileceği tutarlılık kontrolleri:
  - `Σ e_aralik_kWh` = son satırdaki `e_toplam_kWh`,
  - her dilim için `Σ e_aralik_kWh` ≈ son satırdaki `e_tX_kWh`. Fark ≤ 0,001 kWh; dilim geçişinde çözücünün tek bir adımından gelir.
- `meta.kontroller`, Simulink tarafında yapılan 8 kontrolün sonucunu içerir. Hepsi `gecti: true` değilse dosya kullanılmamalıdır.

## 9. Örnek dosyalar (fixture) ve Git (kararlar 6 ve 8)

- **Git'e girmeyenler:** Tam günlük çıktılar (`ciktilar/`, 1440 satır). Gerektiğinde depo dışından paylaşılır.
- **Git'e girenler:** `simulink/ornek_veri/` klasöründeki küçük örnekler. Bunlar gösteri günü test senaryosundan alınmış kısa kesitlerdir ve `gosteri_gunu('ornek')` ile yeniden üretilir.

| Örnek | Kesit | Satır | Olaylar |
|---|---|---|---|
| `ornek_kesinti_*` | 12:25–12:45 | 21 | 42, 40, 41, 43 (kesinti ve dönüş) |
| `ornek_asiri_guc_*` | 17:55–18:30 | 36 | 10, 20, 11, 31 (maske 3), 31 (maske 2), 30 (aşırı güç, kesme, iki red, kabul) |

- Her örnek üç dosyadır: `_olcum_TEST.csv`, `_olaylar_TEST.csv`, `_meta_TEST.json`. Satırlar tam günlük dosyadan olduğu gibi kopyalanır; biçim ve `run_id` aynıdır.
- **Kümülatif sayaçlar kesitte 0'dan başlamaz**, gün başından devam eder.
- Örneğin meta dosyasındaki `ornek` alanında kesitin başı ve sonu, kaynak günün toplamları ve "simülasyon verisidir" açıklaması bulunur. `satir_sayisi`, `olay_sayisi` ve SHA-256 özetleri kesitin kendi dosyalarına aittir.
- `ornek_veri/` dosyalarında Git satır sonu dönüşümü kapalıdır (`.gitattributes`); özetler her bilgisayarda aynı kalır.

## Sürüm geçmişi

| Sürüm | Tarih | Değişiklik |
|---|---|---|
| 0.1-TASLAK | 20.11.2026 | İlk taslak, 26 sütun |
| 1.0 | 22.11.2026 | Proje yöneticisinin kararları: 1 dk, aralık başı, CSV+CSV+JSON, `SIM-0001`; `run_id` sütunu ve SHA-256 özetleri; net enerji, negatif değer, geçersiz satır ve cos φ tanımları; örnek dosyalar ve Git kuralı |
