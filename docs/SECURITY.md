# Akıllı Sayaç Güvenliği

## Uygulanan kontroller

- API varsayılan ve izin verilen tek bind adresi `127.0.0.1`.
- CORS allow-list, kimlik doğrulamadan bağımsızdır.
- Bearer token'lar kaynak kodundan değil ortam değişkeninden alınır ve bellekte SHA-256 özetiyle
  karşılaştırılır. Token ve HMAC anahtarı loglanmaz.
- Viewer yalnızca okur; Operator/Admin AMI ve röle işlemlerini sunucu tarafı izin kontrolüyle
  yapabilir. Kimliksiz/yetkisiz yanıtları 401/403 olarak ayrıdır.
- Fastify body limiti 256 KiB, dosya limiti 256 KiB / 1000 kayıt ve IP başına rate limit vardır.
- Dış girdiler strict Zod şemalarından geçer; NaN/Infinity reddedilir.
- Hata yanıtlarında stack trace veya dosya yolu döndürülmez.
- SQLite sorguları parametrelidir; AMI ve komut kayıtları transaction kullanır.
- HMAC-SHA256 canonical UTF-8 JSON üzerinde hesaplanır; anahtar en az 32 bayttır ve doğrulama
  sabit zamanlı karşılaştırma kullanır.
- `packetId` ve sayaç sıra numarası replay/idempotency için unique constraint ile korunur.
- Dosya içe aktarma tek düz dosya adı ve `.json/.csv` uzantısıyla sınırlıdır.
- React kullanıcı metnini HTML olarak render etmez; CSP tanımlıdır.
- Röle komutlarında actor, TTL, sayaç, grid, overload ve eşzamanlı çakışma kontrol edilir.

## Secret yönetimi

Örnek `.env.example` gerçek değer içermez. Yerel anahtar üretimi:

```powershell
$bytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
[Convert]::ToHexString($bytes).ToLowerInvariant()
```

Çıktıyı yalnızca yerel `.env` içindeki `AKILLI_SAYAC_AMI_HMAC_KEY_HEX` değişkenine yazın.
Bearer token'lar en az 128 bit rastgele olmalı ve `AKILLI_SAYAC_LOCAL_TOKENS_JSON` içinde yerel
olarak tutulmalıdır. Git'e eklemeyin.

## Public GitHub incelemesi — 19 Kasım 2026

- Repository public, varsayılan dal `main`, incelenen kaynak commit `a005f26580549d4f65435c7d8085dd7007ca6401`.
- İnceleme anında yalnızca `main` vardı; açık PR ve ruleset yoktu.
- İlk commit'te CI veya kök güvenlik yapılandırması yoktu.
- Branch protection endpoint'i GitHub App tarafından 403 döndürdü. Protection durumunun kapalı
  olduğu varsayılmadı; arayüzden yönetici doğrulaması gerekiyor.
- Dependabot/secret scanning durum endpoint'leri bu entegrasyon tarafından erişilebilir değildi;
  etkinleştirildiği iddia edilmez.
- Gitleaks yerel ortamda kurulu değildi ve ağ kapalıydı. Güvenli regex tabanlı dosya adı/içerik
  taraması yapılır; tam gitleaks geçmiş taraması gönderim öncesi zorunlu açık iştir.

## Yönetici tarafından GitHub arayüzünde yapılacaklar

1. `main` için PR zorunluluğu, en az bir review ve CI required status check içeren ruleset ekleyin.
2. Force push ve branch deletion'ı kapatın.
3. Secret scanning, push protection, dependency graph, Dependabot alerts ve security updates'i
   etkinleştirip durumlarını doğrulayın.
4. Actions varsayılan token yetkisini read-only yapın ve yalnızca izinli action'lara izin verin.
5. İlk lockfile üretildikten sonra CI başarı vermeden merge etmeyin.

## Bilinen sınırlar

- Yerel dosya sistemi yöneticisine karşı SQLite/audit değiştirilemez değildir.
- `LocalSimulatorAdapter` fiziksel güvenlik interlock'u değildir.
- Tek kullanıcı modu çok kullanıcılı internete açık servis olarak kullanılamaz.
- CSV tek başına güvenilir AMI değildir; güvenilir sayılması için imzalı envelope'a dönüştürülmelidir.
- Fiziksel cihaz kimliği, anahtar provizyonu ve rotasyonu prototip kapsamının dışındadır.
