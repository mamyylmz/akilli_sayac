# Simulink Entegrasyon Gereksinimleri

## Kapsam

İlk entegrasyon dosya tabanlıdır; MATLAB Engine kullanılmaz. Mevcut `.slx`, parametre ve A–C test
dosyaları yazılım tarafından değiştirilmez. Simulink geliştiricisi export üretir; TypeScript tarafı
şema, kaynak bütünlüğü ve idempotent kayıt yapar.

## Sinyal eşlemesi

| Simulink etiketi | JSON alanı                | Birim / not                       |
| ---------------- | ------------------------- | --------------------------------- |
| `V_anlik`        | `voltageInstantV`         | V, isteğe bağlı anlık örnek       |
| `I_anlik`        | `currentInstantA`         | A, isteğe bağlı anlık örnek       |
| `V_rms`          | `voltageRmsV`             | V rms                             |
| `I_rms`          | `currentRmsA`             | A rms                             |
| `P_aktif`        | `activePowerW`            | W; yön nedeniyle negatif olabilir |
| `Q_reaktif`      | `reactivePowerVar`        | var; endüktif +, kapasitif −      |
| `S_gorunur`      | `apparentPowerVa`         | VA = Vrms × Irms                  |
| `cos_phi`        | `displacementPowerFactor` | P / sqrt(P² + Q²), işaretsiz      |
| hesaplanan       | `truePowerFactor`         | P / (Vrms × Irms), yönlü          |
| `E_KWh`          | `totalActiveEnergyKWh`    | kWh, büyük K etiketi korunur      |
| `E_T1/T2/T3`     | `t1KWh/t2KWh/t3KWh`       | kWh                               |
| `E_Rend/E_Rkap`  | reaktif enerji alanları   | kVArh                             |
| `Role_Komut`     | `requestedRelayState`     | 1=`energized`, 0=`deenergized`    |

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

## CSV aktarımı

CSV UTF-8, başlıklı ve invariant `.` ondalık ayracıyla aşağıdaki minimum sütunları içermelidir:

```text
schemaVersion,meterId,sequence,simulationTimeHours,exportedAt,V_rms,I_rms,P_aktif,Q_reaktif,S_gorunur,cos_phi,truePF,E_KWh,E_T1,E_T2,E_T3,E_Rend,E_Rkap,relayState,gridState,overloadActive
```

CSV, kaynak doğrulaması değildir. En fazla 1000 kayıt/256 KiB kabul edilir; önce şemalı AMI
envelope'a dönüştürülüp imzalanmalıdır. API bilinmeyen bir CSV eşlemesini sessizce içe aktarmaz.

## Simulink geliştiricisinden beklenenler

- Export örnekleme noktası ve sıralama politikasını belirlemek.
- Tüm alanlar için sinyal etiketi, birim ve işaret konvansiyonunu korumak.
- Sayaç/packet UUID ve monoton sıra numarası üretmek.
- Hangi katmanın HMAC anahtarına erişeceğini ve anahtar rotasyonunu kararlaştırmak.
- Dosyayı atomik yazmak, kısmi/yeniden adlandırılmış dosya davranışını test etmek.
- `Role_Komut` için gerçek adapter tasarlanmadan önce D aşaması röle semantiğini ve fail-safe
  kararlarını yazılı olarak onaylamak.
- Yeni export testlerini mevcut 92 A–C test dosyasını değiştirmeden ayrı test olarak eklemek.
