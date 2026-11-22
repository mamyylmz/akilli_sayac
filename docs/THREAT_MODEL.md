# Akıllı Sayaç Tehdit Modeli

## Kapsam ve varsayımlar

Bu model NISTIR 7628'in akıllı şebekede bütünlük, kullanılabilirlik, gizlilik ve hesap verebilirlik
hedefleri ile OWASP API güvenliği ilkelerini projenin yerel kapsamına uyarlar. İlk sürüm tek
kullanıcılı, `127.0.0.1` üzerinde çalışan bir geliştirme uygulamasıdır. Localhost erişimi tek
başına kimlik doğrulama veya yetkilendirme sayılmaz.

Fiziksel sayaç, gerçek röle, MATLAB Engine, internet servisi ve gerçek elektrik şebekesi kapsam
dışıdır. `LocalSimulatorAdapter` yalnızca yazılım davranışını sınar.

## Varlıklar

- Ölçüm, aktif/reaktif enerji ve tarife sayaçları
- Tarife yapılandırmaları ve TL hesapları
- Röle kontrol komutları ve sonuçları
- AMI paketleri, sıra numaraları ve HMAC anahtarı
- Olay ve audit kayıtları
- Yerel SQLite veritabanı ve journal dosyaları
- Yerel kullanıcı oturum belirteçleri ve rol atamaları
- GitHub kaynak kodu, CI iş akışları ve bağımlılık kilidi

## Güven sınırları

1. **Tarayıcı → API:** Tarayıcı güvenilir değildir. Her girdi sunucuda doğrulanır; CORS yalnızca
   tarayıcı köken politikasıdır.
2. **Simulink dosyası → içe aktarma klasörü:** Dosya adı, uzantı, boyut, kayıt sayısı, şema,
   sayaç kimliği ve HMAC ayrı ayrı kontrol edilir.
3. **API → SQLite:** Yalnızca parametreli sorgular ve transaction kullanılır.
4. **API → simulator adapter:** Yetki, komut şeması ve güvenlik politikası geçilmeden adapter
   çağrılmaz.
5. **Yerel süreç → secret ortamı:** HMAC anahtarı ve bearer token'lar yalnızca ortam değişkeninde
   bulunur; kaynak koduna, loga veya veritabanına açık değerleriyle yazılmaz.
6. **Repository → GitHub Actions:** PR kodu güvenilmezdir. İş akışı salt-okunur token kullanır ve
   secret gerektirmez.

## Başlıca tehditler ve kontroller

| Tehdit                          | Etki                                | Kontrol                                                              | Artık risk                                                       |
| ------------------------------- | ----------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Sahte AMI kaynağı               | Yanlış ölçüm/fatura                 | HMAC-SHA256, 32 bayt dış anahtar, sabit zamanlı doğrulama            | Anahtar çalınırsa kaynak taklit edilebilir                       |
| Paket değiştirme                | Ölçüm bütünlüğü kaybı               | Deterministik canonical JSON ve HMAC                                 | İmzadan önceki üretici güvenliği ayrı konudur                    |
| Replay / mükerrer sıra          | Çifte enerji kaydı                  | `packet_id` ve `(meter_id, sequence)` unique constraint, transaction | DB dosyası geri yüklenirse eski paketler yeniden görünebilir     |
| Yetkisiz röle komutu            | Hizmet kesintisi/tehlikeli açma     | Bearer auth, sunucu rol kontrolü, actor eşleştirme, audit            | Yerel admin hesabı/işletim sistemi ele geçirilirse sınır aşılır  |
| Güvensiz yeniden enerjilendirme | Şebeke yokken veya aşırı yükte açma | Grid ve overload politikası, süre sonu, çatışan komut engeli         | Gerçek donanım interlock'u henüz yok                             |
| SQL injection                   | Veri ifşası/değiştirme              | Zod ve yalnızca parametreli StatementSync sorguları                  | Kötü niyetli yerel DB dosya erişimi kapsam dışı                  |
| Path traversal                  | Keyfi dosya okuma                   | Tek dosya adı regex'i, izinli `.json/.csv`, canonical base path      | İçe aktarma dizinine yazabilen yerel kullanıcı dosya ekleyebilir |
| XSS                             | Tarayıcı oturumu etkisi             | React metin render'ı, `dangerouslySetInnerHTML` yok, CSP             | Yeni HTML render özellikleri ayrıca incelenmeli                  |
| Büyük/bozuk payload             | DoS                                 | 256 KiB body/file limiti, 1000 kayıt limiti, rate limit              | Tek süreçli yerel API kaynakları sınırlıdır                      |
| Log/stack bilgi sızıntısı       | Sistem bilgisi ifşası               | Güvenli hata kodları, istemciye stack yok, secret loglama yok        | Geliştirici debug logları kontrollü kullanılmalı                 |
| GitHub supply chain             | Kod veya paket zehirleme            | Action SHA pinleri, minimum permission, frozen lockfile hedefi       | GitHub ayarları yönetici tarafından etkinleştirilmelidir         |

## Röle kötüye kullanım senaryoları

- Viewer komutu 403 ile reddedilir; kimliksiz istek 401 alır.
- `commandId` tekrarlandığında adapter ikinci kez çağrılmaz.
- Süresi geçmiş komut, yanlış sayaç ve sahte aktör reddedilir.
- Şebeke yokken veya aşırı yük sürerken `energized` isteği reddedilir.
- Aynı anda zıt durum isteyen pending komutlar çakışma olarak kaydedilir.
- Şebeke yokken `deenergized` isteğinin otomatik olarak tehlikeli olduğu varsayılmaz.

## Kayıt bütünlüğü sınırı

Audit olayları ölçümlerden ayrı tutulur ve transaction içinde komutla ilişkilendirilir. Bu,
uygulama seviyesinde izlenebilirlik sağlar; yerel SQLite dosyasına işletim sistemi seviyesinde
yazabilen kötü niyetli kullanıcıya karşı değiştirilemezlik iddiası taşımaz. Daha güçlü ihtiyaçta
işletim sistemi ACL'i, şifreli disk ve dış append-only kayıt hedefi ayrıca tasarlanmalıdır.
