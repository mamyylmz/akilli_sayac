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

İlk yazılım temeli çevrimdışı bir WSL ortamında hazırlandı ve bu ortamda resmî pnpm ile
`pnpm-lock.yaml` üretilemedi. İlk ağ erişimli doğrulamada bir kez `pnpm install` çalıştırın,
oluşan lockfile'ı inceleyip commit edin. Bundan sonraki tüm kurulumlar ve CI frozen olmalıdır:

```powershell
pnpm install
git add pnpm-lock.yaml
# Lockfile commit edildikten sonraki temiz kurulumlarda:
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

## MATLAB testi

MATLAB R2026b, Simulink, Simscape ve Simscape Electrical mevcutsa `simulink/testler` içinden
`test_dogrulama` çalıştırılabilir. MATLAB yoksa kayıtlı 92 testin yeniden çalıştırıldığı iddia
edilmemelidir; yalnızca repository'deki `simulink/testler/test_sonuclari.md` kaynak gösterilir.
