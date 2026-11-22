# Simulink röle komut protokolü

## Güncel durum

Yazılım katmanı komutu doğrular, yetkili aktörü ve süre sınırını denetler, `command_id` ile tekilleştirir ve audit kaydı oluşturur. `LocalSimulatorAdapter` MATLAB/Simulink, donanım veya fiziksel röle çalıştırmaz. Bu adaptörün sonucu `pending / QUEUED_FOR_SIMULINK` olur ve röle durumu `unknown` kalır.

`applied` yalnızca Simulink modeli komutu tüketip kendi koruma kararından sonra yeni röle durumunu açıkça bildirdiğinde kullanılabilir.

## Yazılım isteği

```json
{
  "schemaVersion": "1.0.0",
  "id": "4b62dc1e-1a67-4cc9-a32c-8cf167295830",
  "commandId": "4b62dc1e-1a67-4cc9-a32c-8cf167295830",
  "meterId": "SIM-0001",
  "actorId": "operator-1",
  "createdAt": "2026-11-23T12:00:00+03:00",
  "expiresAt": "2026-11-23T12:01:00+03:00",
  "requestedRelayState": "deenergized",
  "reason": "Yetkili yerel kullanıcı isteği"
}
```

Durumların anlamı:

| Durum       | Anlam                                                                   |
| ----------- | ----------------------------------------------------------------------- |
| `accepted`  | Yazılım doğruladı ve kalıcı kayda aldı; model henüz işlememiş olabilir. |
| `pending`   | Simulink onayı bekleniyor; röle uygulanmış sayılmaz.                    |
| `applied`   | Simulink komutu uyguladı ve sonucu bildirdi.                            |
| `rejected`  | Yazılım güvenlik politikası veya Simulink koruması komutu reddetti.     |
| `duplicate` | Aynı `command_id` daha önce işlendi; ikinci kez röle işlemi yapılmadı.  |

## Simulink yanıtı

Model tarafındaki gelecekteki adaptör en az aşağıdaki yanıtı üretmelidir:

```json
{
  "schemaVersion": "1.0.0",
  "commandId": "4b62dc1e-1a67-4cc9-a32c-8cf167295830",
  "meterId": "SIM-0001",
  "completedAt": "2026-11-23T12:00:04+03:00",
  "status": "applied",
  "relayState": "deenergized",
  "code": "APPLIED",
  "message": "Simulink koruma mantığı komutu uyguladı"
}
```

Red yanıtı `status: rejected`, mevcut röle durumu, kararlı bir red kodu ve kullanıcıya gösterilebilir kısa bir neden içermelidir. Süresi geçmiş komut uygulanmamalıdır.

## Model tarafında beklenen görev

Simulink geliştiricisi, mevcut koruma mantığını değiştirmeden onaylı komut girişini ve sonuç çıkışını modele bağlamalıdır. Dosya tabanlı yerel adaptör kullanılırsa komut ve yanıt dosyaları geçici ada yazılıp atomik yeniden adlandırılmalı; kısmi dosyalar tüketilmemeli; her `command_id` en fazla bir kez uygulanmalıdır. Modelin koruma kararı yazılım isteğinden önceliklidir.

Ölçüm CSV/JSON importu bu protokolden bağımsızdır. Geçmiş bir CSV paketini içe aktarmak röle komutu oluşturmaz veya mevcut komut durumunu değiştirmez.
