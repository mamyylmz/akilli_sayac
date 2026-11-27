# Akıllı Sayaç Kurulumu

## Desteklenen geliştirme ortamı

- Windows 11 ve VS Code
- Git 2.43 veya yeni uyumlu sürüm
- Node.js 24 LTS
- pnpm 12.21.x
- MATLAB/Simulink yalnızca elektriksel modeli yerelde doğrulamak isteyen ekip üyesi için

WSL zorunlu değildir. Projeyi PowerShell'de açtıysanız Node/pnpm komutlarını PowerShell'de;
WSL'de açtıysanız aynı WSL dağıtımında çalıştırın. Windows ve WSL `node_modules` klasörlerini
karıştırmayın.

Eksik ücretsiz araçlar Windows Package Manager ile kurulabilir:

```powershell
winget install --id Git.Git -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id Microsoft.VisualStudioCode -e
npm install --global pnpm@12.21.0
```

Mevcut çalışan kurulumları gereksiz yere değiştirmeyin. MATLAB/Simulink kurulumu bu proje
tarafından yönetilmez.

## Kurulum ve doğrulama

Bağımlılıklar kilitlidir. Temiz kurulumlarda frozen lockfile kullanın:

```powershell
pnpm install --frozen-lockfile
Copy-Item .env.example .env
pnpm typecheck
pnpm lint
pnpm test
pnpm build
```

Çevrimdışı geliştirme koşusunun gerçek sonuçları ve standart araç zincirindeki açık engeller
`docs/TEST_RESULTS.md` dosyasındadır.

`.env` içindeki placeholder'ları gerçek yerel değerlerle değiştirin; `.env` Git tarafından
yok sayılır. HMAC anahtarını `docs/SECURITY.md` komutuyla üretin. Token JSON örneği:

```json
[
  { "actorId": "local-operator", "role": "operator", "token": "<random-local-token>" },
  { "actorId": "local-viewer", "role": "viewer", "token": "<different-random-token>" }
]
```

## Çalıştırma

Önce derleyin, sonra iki terminal açın:

```powershell
pnpm --filter @akilli-sayac/api start
pnpm --filter @akilli-sayac/web dev
```

- API: `http://127.0.0.1:3000`
- HAN UI: `http://127.0.0.1:5173`

API başka bir interface'e bind olmaz. Gerçek röle işletilmez.

## Simulink veri paketini içe aktarma

Sözleşme 1.0'a ait ölçüm CSV, olay CSV ve meta JSON dosyasını `.env` içindeki
`AKILLI_SAYAC_IMPORT_DIR` klasörüne birlikte kopyalayın. Meta dosyası tamamlanma işaretidir ve en
son atomik olarak taşınmalıdır. Ardından operator veya admin token'ıyla yalnızca meta dosyasını
bildirin:

```powershell
Invoke-RestMethod -Method Post `
  -Uri http://127.0.0.1:3000/api/v1/ami/import-file `
  -Headers @{ Authorization = "Bearer <yerel-token>" } `
  -ContentType "application/json" `
  -Body '{"metadataFileName":"meta_2026-11-22.json"}'
```

API iki CSV adını metadata içinden alır; dosya yolu, boyut, SHA-256, şema, `run_id`, sayaç,
satır sırası, olay ve enerji kontrolleri geçmeden SQLite'a kayıt yapmaz. Kısa fixture paketleri
yalnızca metadata içinde `ornek` alanı bulunduğunda kabul edilir.

## MATLAB testi

MATLAB R2026b, Simulink, Simscape ve Simscape Electrical mevcutsa `simulink/testler` içinden
`test_dogrulama` çalıştırılabilir. MATLAB yoksa kayıtlı Simulink testlerinin yeniden çalıştırıldığı
iddia edilmemelidir; yalnızca repository'deki test sonuç dosyaları kaynak gösterilir.
