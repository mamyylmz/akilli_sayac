# Simulink Entegrasyon Gereksinimleri

## Kapsam

İlk entegrasyon dosya tabanlıdır; MATLAB Engine kullanılmaz. Mevcut `.slx`, parametre ve A–C test
dosyaları yazılım tarafından değiştirilmez. Simulink geliştiricisi export üretir; TypeScript tarafı
şema, kaynak bütünlüğü ve idempotent kayıt yapar.

## Sinyal eşlemesi

| Simulink etiketi | JSON alanı              | Birim / not                       |
| ---------------- | ----------------------- | --------------------------------- |
| `V_anlik`        | `voltageInstantV`       | V, isteğe bağlı anlık örnek       |
| `I_anlik`        | `currentInstantA`       | A, isteğe bağlı anlık örnek       |
| `V_rms`          | `voltageRmsV`           | V rms                             |
| `I_rms`          | `currentRmsA`           | A rms                             |
| `P_aktif`        | `activePowerW`          | W; yön nedeniyle negatif olabilir |
| `Q_reaktif`      | `reactivePowerVar`      | var; endüktif +, kapasitif −      |
| `S_gorunur`      | `apparentPowerVa`       | VA = Vrms × Irms                  |
| `cos_phi`        | `cos_phi`               | P / sqrt(P² + Q²), P yönünü izler |
| `E_KWh`          | `totalActiveEnergyKWh`  | kWh, büyük K etiketi korunur      |
| `E_T1/T2/T3`     | `t1KWh/t2KWh/t3KWh`     | kWh                               |
| `E_Rend/E_Rkap`  | reaktif enerji alanları | kVArh                             |
| `Role_Komut`     | `requestedRelayState`   | 1=`energized`, 0=`deenergized`    |

## Zaman alanları

- `simulationTimeHours`: Simulink ekseni; modelde 1 simülasyon saniyesi = 1 tüketim saati.
- `exportedAt`: dosyanın dışa aktarıldığı UTC/offset içeren ISO 8601 zaman.
- `generatedAt`: AMI envelope'ın oluşturulduğu gerçek zaman.
- `transferredAt`: yazılım aktarımının yapıldığı gerçek zaman.

Simülasyondaki 18:00 olayı gerçek dünyada 18:00'de olmuş kabul edilmez.

## JSON aktarımı

`fixtures/synthetic/ami-envelope.unsigned.json` yalnızca açıkça sentetik şema örneğidir ve API
tarafından güvenilir paket olarak kabul edilmez. Güvenilir yerel prototip için:

1. Envelope `packages/contracts` şemasına uygun üretilir.
2. Nesne anahtarları `canonicalJson` ile alfabetik ve özyinelemeli sıralanır; UTF-8 kullanılır.
3. 32 baytlık paylaşılan yerel anahtarla HMAC-SHA256 hesaplanır ve Base64 yazılır.
4. `{ envelope, algorithm: "HMAC-SHA256", signatureBase64 }` biçimi `.json` olarak atomik taşınır.
5. Önce geçici dosyaya yazılıp aynı dosya sisteminde rename edilmelidir; kısmi dosya okunmamalıdır.

## Sözleşme 1.0 CSV/JSON aktarımı

Normatif tanım `simulink-veri-aktarimi` dalındaki `simulink/veri_sozlesmesi.md` dosyasıdır.
Üretici `simulink/veri_aktar.m`, aynı `run_id` değerini taşıyan üç dosya oluşturur:

- `olcum_1dk_<gün>.csv`: 27 sütun ve normal pakette 1440 dakika;
- `olaylar_<gün>.csv`: sözleşmedeki olay kodları ve durumlar;
- `meta_<gün>.json`: sürüm, sayaç, dosya adları, SHA-256 özetleri ve Simulink kontrolleri.

Zaman aralık başlangıcıdır ve `+03:00` taşır. İlk iki tam gün satırındaki `gecerli=0`, şebeke
kesintisi sayılmaz; bu satırların enerji sayaçları saklanır. `p_W` ve `e_aralik_kWh` negatif
olabilir ve sıfıra kırpılmaz. Görsel güç analizi geçersiz satırları dışarıda bırakırken enerji
alanları korunur.

SHA-256, CSV baytlarının metadata ile tutarlı olduğunu gösterir; üreticinin kimliğini kanıtlamaz.
İçe aktarılan paket `trusted_source=0` olarak saklanır. HMAC doğrulamalı AMI JSON yolu ayrı güven
sınırı olarak çalışmaya devam eder.

## Simulink geliştiricisinden beklenenler

- Export örnekleme noktası ve sıralama politikasını belirlemek.
- Tüm alanlar için sinyal etiketi, birim ve işaret konvansiyonunu korumak.
- Sözleşme 1.0 dosya adlarını, `run_id` değerini ve SHA-256 özetlerini korumak.
- Dosyayı atomik yazmak, kısmi/yeniden adlandırılmış dosya davranışını test etmek.
- `Role_Komut` için [Simulink röle protokolündeki](./SIMULINK_RELAY_PROTOCOL.md) komut tüketimi,
  onay ve sonuç çıkışını uygulamak.
- Yeni export testlerini mevcut fiziksel model testlerini değiştirmeden ayrı test olarak eklemek.
