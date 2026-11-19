# Test ve Doğrulama Sonuçları

Doğrulama tarihi: 19 Kasım 2026  
İncelenen kaynak commit: `a005f26580549d4f65435c7d8085dd7007ca6401`  
Yerel dal: `feature/software-foundation-security`

## Ortam

- WSL/Linux çalışma alanı
- Git 2.43.0
- VS Code Server Node.js 24.22.1
- MATLAB/Simulink: kurulu değil
- pnpm: çalıştırılabilir dosya kurulu değil
- gitleaks: kurulu değil

Bağımlılıklar ağ erişimi olmadan, mevcut pnpm v11 içerik mağazasından
`scripts/offline-store-install.mjs` ile açıldı. Bu yardımcı lifecycle script çalıştırmaz ve normal
bir geliştirme/CI ortamında `pnpm install --frozen-lockfile` yerine kullanılmamalıdır.

## Başarılı kontroller

| Kontrol            | Gerçek sonuç                                                                       |
| ------------------ | ---------------------------------------------------------------------------------- |
| TypeScript         | Contracts, billing, security, API ve web için `tsc --noEmit`: başarılı             |
| ESLint             | `eslint . --max-warnings 0`: başarılı, 0 uyarı                                     |
| Prettier           | `prettier --check .`: başarılı                                                     |
| Paket derleme      | Contracts, billing, security ve API `tsc` derlemesi: başarılı                      |
| Test kaynakları    | Derlenmiş test dosyaları üzerinde çevrimdışı uyumluluk koşusu: **29/29 geçti**     |
| API smoke          | `GET /health` Fastify inject testi: geçti                                          |
| SQLite             | Şema oluşturma, AMI yazma/okuma, unique/replay ve transaction testleri: geçti      |
| Simulink fixture   | Açıkça unsigned/synthetic fixture sözleşme testi: geçti                            |
| Simulink korunumu  | `git diff --exit-code -- simulink`: başarılı; A–C testleri değişmedi               |
| Secret ön taraması | Private-key/AWS/GitHub token imzaları için dosya ve ilk commit taraması: bulgu yok |

Çevrimdışı test komutu, kaynaklardaki aynı test dosyalarını ve assertion'ları çalıştırdı:

```bash
node --experimental-loader ./scripts/vitest-offline-loader.mjs \
  scripts/run-tests-offline.mjs \
  packages/contracts/dist/contracts.test.js \
  packages/billing/dist/billing.test.js \
  packages/security/dist/security.test.js \
  apps/api/dist/app.test.js
```

Geçen güvenlik senaryoları; 401/403 ayrımı, CORS'un kimlik doğrulama sayılmaması, izin verilmeyen
origin, rate limit, bozuk/aşırı büyük JSON, yanlış HMAC, değiştirilmiş veri, yanlış sayaç kimliği,
replay, SQL injection biçimli kimlik, path traversal, actor spoofing, süresi geçmiş/çakışan komut,
şebeke kesintisi ve aşırı yükte yeniden enerjilendirme engelini içerir.

## Başlatılamayan standart kontroller

### Vitest

`vitest run`, testleri toplamadan önce Rolldown'un Linux native bağlayıcısını bulamadığı için
exit 1 ile durdu:

```text
Error: Cannot find native binding
Cannot find module '@rolldown/binding-linux-x64-gnu'
Cannot find module '@rolldown/binding-wasm32-wasi'
```

Yerel mağazada yalnızca Windows hedefli bağlayıcı bulunduğundan bu bir test assertion hatası
değildir; yine de standart Vitest koşusu başarılı sayılmamıştır.

### Web üretim derlemesi

Web TypeScript derlemesi geçti. `vite build` aynı eksik Linux Rolldown bağlayıcısı nedeniyle
exit 1 ile başladıramadı. Bu nedenle bütün `pnpm build` zinciri başarılı sayılmamıştır.

### TCP dinleyicisi smoke denemesi

Derlenmiş API `127.0.0.1:31234` üzerinde başlatılmak istendi; çalışma alanı sandbox'ı socket
dinlemeye izin vermedi ve Node.js `listen EPERM: operation not permitted` döndürdü. Endpoint'in
uygulama içi smoke testi Fastify inject ile geçti, ancak bu ortamda gerçek TCP isteği başarılı
sayılmamıştır.

### Frozen kurulum ve dependency audit

Ortamda çalışır bir pnpm binary'si ve ağ erişimi yoktur. npm önbelleğindeki pnpm 12 paketi Linux
binary'sini indirmeye çalıştığı için kullanılamadı. Resmî pnpm ile lockfile üretilemediğinden
`pnpm-lock.yaml` oluşturulmadı; dolayısıyla `pnpm install --frozen-lockfile` ve `pnpm audit`
başarıyla çalıştırılmış değildir. CI frozen kurulum kullanacak biçimde hazırdır ancak lockfile
oluşturulup doğrulanmadan başarılı olmayacaktır.

## MATLAB/Simulink sonucu

MATLAB bu ortamda bulunmadığı için elektriksel A–C testleri yeniden çalıştırılmadı. Repository'de
kayıtlı `simulink/testler/test_sonuclari.md` sonucu **92 geçti, 0 başarısız** olarak incelendi;
bu sayı bu çalışma sırasında yeniden üretilmiş bir sonuç değildir.

## Gönderim öncesi açık doğrulamalar

1. Node.js 24 ve pnpm 12.21 bulunan ağ erişimli temiz bir ortamda lockfile üretin ve commit edin.
2. `pnpm install --frozen-lockfile`, `pnpm typecheck`, `pnpm lint`, `pnpm test` ve `pnpm build`
   komutlarını yeniden çalıştırın.
3. `pnpm audit --audit-level high` ve tam Git geçmişi için gitleaks taraması çalıştırın.
4. MATLAB lisanslı yerel ortamda mevcut A–C test paketini ayrıca çalıştırın.
