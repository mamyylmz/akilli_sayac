# Veri Sözleşmesi: Simulink → Yazılım (TASLAK 0.1)

**Durum:** Taslak. Sütun adları ve biçim yazılım ekibiyle birlikte kesinleşecek (karar K4).
**Hazırlayan:** Poyraz Ege Taş (Simulink) · **Tarih:** 20.11.2026
**Üreten betik:** `simulink/veri_aktar.m` · **Şema sürümü:** `0.1-TASLAK`

## 1. Ne üretilir

Komut penceresinde `veri_aktar` çalıştırılınca model bir gün (24 saat) çalışır ve üç dosya yazılır:

| Dosya | İçerik |
|---|---|
| `olcum_1dk_<gün>.csv` | 1440 satır; her satır bir dakikalık aralık (ölçüm, enerji, röle, batarya) |
| `olaylar_<gün>.csv` | Koruma olay kaydı: her olay bir satır. Olay yoksa yalnızca başlık satırı vardır |
| `meta_<gün>.json` | Şema sürümü, çalıştırma ayarları, günlük toplamlar, sütun açıklamaları, kontroller |

`<gün>` = `YYYY-AA-GG` (varsayılan: çalıştırıldığı gün). Değiştirmek için `veri_aktar('gun','2026-11-26')`; başka sayaç kimliği için `veri_aktar('sayac_id','SIM-0002')`.

## 2. Model sonucu ile test verisi ayrımı

Proje kararı gereği ikisi karışmaz:

| Durum | Klasör | Dosya adı | `meta.veri_turu` |
|---|---|---|---|
| Normal gün (`test_senaryo` tanımlı değil) | `ciktilar/model/` | `olcum_1dk_2026-11-20.csv` | `model` |
| Test senaryosu (`test_senaryo` tanımlı) | `ciktilar/test/` | `olcum_1dk_2026-11-20_TEST.csv` | `test` |

Test dosyalarının meta dosyasında senaryonun hangi değerleri değiştirdiği de yazar (`test_senaryosu`).

## 3. Genel biçim kuralları

- Karakter kodlaması UTF-8 (BOM yok), ayraç virgül, ondalık ayırıcı nokta, ilk satır başlık.
- Metin alanları yalnızca olay dosyasında ve çift tırnak içinde.
- Zaman: ISO 8601, yerel saat, `+03:00` (Türkiye yıl boyu UTC+3). Örnek: `2026-11-20T18:05:00+03:00`.
- Ölçüm satırının zamanı **aralığın başıdır**: `18:05` satırı 18:05:00–18:06:00 aralığını gösterir.
- Birimler sütun adının sonundadır (`_V`, `_A`, `_W`, `_var`, `_VA`, `_kWh`, `_kvarh`).
- Kümülatif sayaçlar gün başında 0'dan başlar.
- Kaynak simülasyondur; gerçek sayaç ya da kişisel veri içermez.

**Verideki bilinen durumlar (hata değildir):**

- **İlk iki satır (00:00 ve 00:01) `gecerli = 0`:** Gerilim, akım ve güç bir periyotluk (20 ms = 1,2 profil dakikası) pencereyle ölçülür. Pencere dolmadan V, I ve S eksik görünür (00:00'da V = 0). Bu satırlar "şebeke yok" diye yorumlanmamalı.
- **Puantta küçük negatif değerler:** Batarya evin bütün yükünü karşıladığında şebeke gücü sıfıra iner. Batarya tahmini yüke göre çalıştığı için `p_W` ve `e_aralik_kWh` birkaç watt kadar negatif olabilir (en düşük −1,1 W). Yazılım küçük negatif değerleri kabul etmeli.
- **cos φ ≈ 0:** Aynı dakikalarda şebekeden neredeyse yalnızca reaktif güç çekildiği için `cos_phi` sıfıra yakındır. Bu fiziksel olarak doğrudur.

## 4. Ölçüm dosyası: `olcum_1dk_<gün>.csv`

Değer türü: **ortalama** = dakika içindeki zaman ağırlıklı ortalama; **aralık sonu** = dakikanın sonundaki değer; **aralık farkı** = o dakikadaki artış; **en büyük** = dakika içindeki en büyük değer.

| Sütun | Birim | Değer türü | Açıklama |
|---|---|---|---|
| `sayac_id` | – | metin | Sayaç kimliği (simülasyon: `SIM-0001`) |
| `zaman` | – | aralık başı | ISO 8601, `+03:00` |
| `dakika` | dk | aralık başı | Gün içindeki dakika, 0–1439 |
| `tarife_dilimi` | – | aralık | 1 gündüz (06–17), 2 puant (17–22), 3 gece (22–06); modelin tarife tablosundan |
| `gecerli` | – | aralık | 1 = ölçüm geçerli; 0 = ölçüm penceresi henüz dolmamış (günün ilk 2 dakikası, bkz. §3) |
| `v_rms_V` | V | ortalama | Gerilim etkin değeri |
| `i_rms_A` | A | ortalama | Akım etkin değeri |
| `p_W` | W | ortalama | Sayaç noktasında şebekeden çekilen aktif güç (batarya dahil) |
| `q_var` | var | ortalama | Reaktif güç (+ endüktif, − kapasitif) |
| `s_VA` | VA | ortalama | Görünür güç, S = V·I |
| `cos_phi` | – | ortalama | Güç faktörü (modeldeki cos φ sinyalinin dakika ortalaması) |
| `e_aralik_kWh` | kWh | aralık farkı | Bu dakikada çekilen aktif enerji |
| `e_toplam_kWh` | kWh | aralık sonu | Gün başından beri toplam aktif enerji |
| `e_t1_kWh` | kWh | aralık sonu | T1 gündüz sayacı (kümülatif) |
| `e_t2_kWh` | kWh | aralık sonu | T2 puant sayacı (kümülatif) |
| `e_t3_kWh` | kWh | aralık sonu | T3 gece sayacı (kümülatif) |
| `e_rend_kvarh` | kvarh | aralık sonu | Endüktif reaktif enerji (kümülatif) |
| `e_rkap_kvarh` | kvarh | aralık sonu | Kapasitif reaktif enerji (kümülatif) |
| `role_komut` | – | aralık sonu | Kullanıcı / uzaktan röle komutu: 1 enerji ver, 0 kes (modelin komut programından) |
| `role` | – | aralık sonu | Koruma kararı / ana röle: 1 kapalı (enerji var), 0 açık |
| `durum` | – | aralık sonu | Sayaç durumu (bkz. §5.2) |
| `asiri_guc_uyari` | – | en büyük | 1 = dakika içinde aşırı güç uyarısı vardı |
| `olay_sayisi` | adet | toplam | Dakika içindeki olay sayısı (ayrıntı olay dosyasında) |
| `p_bat_W` | W | ortalama | Batarya gücü: + evi besliyor (deşarj), − şarj oluyor |
| `soc` | – | aralık sonu | Batarya doluluğu, 0–1 |
| `batarya_mod` | – | aralık sonu | 0 bekleme, 1 şarj, 2 deşarj |

## 5. Olay dosyası: `olaylar_<gün>.csv`

| Sütun | Açıklama |
|---|---|
| `sayac_id` | Sayaç kimliği |
| `zaman` | Olayın zamanı, ISO 8601, saniye çözünürlüklü (`+03:00`) |
| `saat` | Aynı zaman, ondalık saat (ör. 18,0667 = 18:04:00) |
| `olay_kodu` | Kod (bkz. §5.1) |
| `olay` | Kodun Türkçe adı |
| `durum` | Olaydan sonraki sayaç durumu (bkz. §5.2) |
| `red_maske` | Yalnızca yeniden bağlantı isteklerinde (30/31) anlamlıdır; bkz. §5.3 |
| `red_nedeni` | Red maskesinin Türkçe açıklaması (boş = red yok) |

Normal günde (bataryalı) güç 4 kW sınırını aşmadığı için olay dosyası boş olabilir.

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

1 bekleme süresi dolmadı · 2 tahmini yük > P_geri (3800 W) · 4 gerilim aralık dışı ya da kararlı değil · 8 şebeke yok
Örnek: 5 = 1 + 4 → hem bekleme dolmadı hem gerilim uygun değil.

## 6. Meta dosyası: `meta_<gün>.json`

| Alan | Açıklama |
|---|---|
| `sema_surumu` | `0.1-TASLAK` |
| `veri_turu` | `model` ya da `test` |
| `sayac_id`, `gun`, `saat_dilimi`, `aralik_dk`, `satir_sayisi`, `olay_sayisi`, `gecersiz_dakika` | Dosyanın kimliği ve boyutu |
| `ayarlar` | `test_modu`, `koruma_aktif`, `batarya_etkin`, `P_sinir_W`, `P_geri_W`, `t_stop_saat` |
| `test_senaryosu` | Test verisinde değiştirilen parametreler (model verisinde boş) |
| `gunluk_toplam` | Gün sonu sayaç değerleri: toplam, T1, T2, T3, endüktif ve kapasitif reaktif |
| `dakika_sayisi_dilim` | Her tarife diliminin dakika sayısı (660 / 300 / 480) |
| `sutunlar` | Her sütunun adı, birimi, değer türü ve açıklaması |
| `kontroller` | Betiğin yaptığı tutarlılık kontrolleri ve sonuçları |
| `uyarilar` | Varsa veri düzeltmeleri (ör. sayısal olmayan örnek) |

## 7. Yazılım tarafı için öneriler

- **Fatura (TL):** Fiyatlar yalnızca yazılım katmanında tutulur; Simulink fiyat bilmez.
  `TL = e_t1·f1 + e_t2·f2 + e_t3·f3` (+ diğer bileşenler), son satırdaki T1/T2/T3 değerleriyle.
  Dakika bazında aynı sonuç: `TL = Σ e_aralik_kWh × f[tarife_dilimi]`.
- **Tutarlılık:** Her dilim için `Σ e_aralik_kWh` ≈ son satırdaki `e_tX_kWh` (fark ≤ 0,001 kWh; dilim geçişinde çözücünün tek adımı). Betik bunu kontrol edip meta dosyasına yazar.
- **Tekrar hesap yok:** Simulink'te hesaplanan değerler (cos φ, T1/T2/T3, durum) yazılımda yeniden hesaplanmamalı; dosyadan okunmalı.

## 8. Açık sorular (K4 için)

1. **Aralık:** 1 dakika mı, 15 dakika mı? Gerçek sayaçlarda yük profili genellikle 15 dakikalık tutulur. Betik iki türlü de yazabilecek şekilde değiştirilebilir.
2. **Zaman damgası:** Aralık başı (şu anki) mı, aralık sonu mu?
3. **Sayaç kimliği biçimi:** `SIM-0001` uygun mu?
4. **Biçim:** CSV yeterli mi, JSON da gerekiyor mu?
5. **Sütunlar:** Gereksiz ya da eksik sütun var mı?
6. **Git:** Örnek model çıktıları (`ciktilar/model/`) depoya girsin mi, yoksa ayrı mı paylaşılsın? Öneri: `ciktilar/test/` depoya girmesin.
