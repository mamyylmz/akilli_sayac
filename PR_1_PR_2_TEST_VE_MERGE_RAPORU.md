# Akıllı Sayaç PR #1 ve PR #2 test ve merge raporu

22 Kasım 2026, İstanbul. PR #1 önce `main` dalına birleştirildi. Kullanıcının dal tercihi üzerine merge, `4fbf27cb538029d9faa185de5ae2495708e2ac42` commit’iyle geri alındı. Yazılım ve hesaplama düzeltmesi `feature/software-foundation-security` dalında korundu. PR #2 açık kaldı. Bu ortamda MATLAB bulunamadığı için kritik simülasyon testleri doğrulanamadı.

## 1. İncelenen PR Numaraları ve Commit SHA'ları

| Referans | SHA | İnceleme |
| --- | --- | --- |
| [PR #1](https://github.com/mamyylmz/akilli_sayac/pull/1), `feature/software-foundation-security` | `e79631e5a28e8bde326715ff11db43560f236e2d` | İlk incelemedeki baş commit. 7 commit, 65 eklenen dosya. |
| PR #1 düzeltilmiş ve birleştirilmiş baş commit’i | `c15fa2d185dddaf1ac6bbfaf5c29b6ef8f265bea` | İki faturalama dosyası. GitHub `verify` ve `gitleaks` kontrolleri geçti. |
| [PR #2](https://github.com/mamyylmz/akilli_sayac/pull/2), `simulink-d-asamasi` | `91c1cb7d05fe1e49bf4ead84b8759d83ef4419bc` | 5 commit, 27 yeni veya değişen dosya. Son GitHub durumu `open / clean`. |
| [`main`](https://github.com/mamyylmz/akilli_sayac/tree/main) | `4fbf27cb538029d9faa185de5ae2495708e2ac42` | PR #1 merge’ünü geri alan commit. Dosya ağacı başlangıç SHA’sı `a005f26580549d4f65435c7d8085dd7007ca6401` ile aynı. |

GitHub REST API üzerinden PR durumları ve `main` SHA’sı alındı. `gh` kurulu olmadığı için yerel klonda `git status --short --branch`, `git log`, `git diff --name-status origin/main...<dal>` ve `git diff --check origin/main...<dal>` kullanıldı. İki PR diff’inde silinen dosya ya da boşluk hatası görülmedi. Yerel `git merge-tree --write-tree` kontrolü iki PR için mevcut `main` ile ve düzeltilmiş PR #1 ile PR #2 arasında çakışma göstermedi.

## 2. Çalıştırılan Testler ve Sonuçları

### PR #1

| Komut veya yöntem | Sonuç |
| --- | --- |
| `pnpm install --frozen-lockfile` | **GEÇTİ.** pnpm 12.21.0 ile ilk kurulum Node.js 22 uyarısıyla tamamlandı. Node.js 24.22.3 ile tekrar çalıştırılan kilitli kurulum temiz çıktı verdi. |
| `pnpm build:packages`, `pnpm typecheck`, `pnpm lint`, `pnpm build` | **GEÇTİ.** TypeScript, ESLint ve web/API derlemeleri tamamlandı. |
| `pnpm test` | **GEÇTİ.** Orijinal SHA’da 4 dosyada 29 test. Yeni dağıtım bedeli sınır testi ayrıca orijinal hesaplama üzerinde başarısız oldu. |
| `pnpm test:smoke:tcp` | **GEÇTİ.** Gerçek TCP bağlantısı üzerinden sağlık testi. |
| `node apps/api/dist/server.js`, `node node_modules/vite/bin/vite.js preview --strictPort --port 4173` (web dizininde), `Invoke-WebRequest`, `netstat -ano -p tcp` | **GEÇTİ.** API `127.0.0.1:3000/health` isteğine HTTP 200 ve `status=ok`, frontend `127.0.0.1:4173/` isteğine HTTP 200 verdi. İki süreç kapatıldı ve çıkışları doğrulandı. |
| `node --input-type=module -e` ile `MeterDatabase` ve `node:sqlite` disk testi | **GEÇTİ.** Yazma, okuma, benzersizlik hatası sonrası rollback, kısmi kaydın yokluğu, düzeltilmiş işlemin tekrar denenmesi, yeniden açılışta mükerrer kayıt reddi ve `PRAGMA integrity_check` doğrulandı. Yalnızca sentetik veri kullanıldı. |
| `pnpm audit`, geçmiş için Gitleaks | **GEÇTİ.** Ayrıntılar bölüm 6’da. |

### PR #2

`Get-Command matlab`, standart kurulum dizinleri ve MathWorks kayıt defteri anahtarları kontrol edildi. Bu ortamda MATLAB R2026b çalıştırılabilir dosyası bulunamadı. Simulink, Simscape ve Simscape Electrical bileşenlerinin kurulumu veya lisansı doğrulanamadı. Model ve parametreler üzerinde kalıcı değişiklik yapılmadı.

| Hedef komut veya kontrol | Sonuç |
| --- | --- |
| `addpath testler; test_dogrulama` | **DOĞRULANAMADI.** A–C temel ölçüm, enerji ve tarife regresyonu. |
| `addpath testler; test_D_koruma` | **DOĞRULANAMADI.** Altı aşırı güç senaryosu, röle açma/kapatma, izinli ve reddedilen yeniden bağlantı, gerilim, güç eşikleri ve zaman ölçeklemesi. |
| `test_B_batarya`, `test_E_guc_kalitesi`, `test_F_talep`, `test_G_kesinti_batarya`, `tum_testler` | **DOĞRULANAMADI.** Batarya, güç kalitesi, talep yönetimi, kesinti-batarya regresyonu ve toplu çalıştırma. |
| `git diff --stat`, `git log -1 -- <dosya>`, `git show <dal>:<rapor>` | **Statik inceleme tamamlandı.** Modelin ve A–C/D/G sonuçlarının son güncellemeleri PR #2 baş commit’inde, parametre dosyasının son değişikliği önceki `1bc028e` commit’inde. A–C, D ve G raporları R2026b belirtirken README daha eski A–C sonucunu güncel diye gösteriyor. Çıktıların tam olarak aynı model ve parametre bileşiminden üretildiği bağımsız çalıştırmayla doğrulanamadı. |

## 3. Tespit Edilen Hatalar

- **PR #1, dağıtım bedelinde hassasiyet kaybı.** Her biri güvenli tamsayı olan Wh sayaçları `number` olarak toplandığında birleşik değer güvenli tamsayı aralığını aşabiliyordu. `BigInt` dönüşümü toplama sonrasında yapıldığı için yuvarlanmış değer fiyatlamaya taşınıyordu. Yeni testte beklenen `8_998_192_055_486_252` mikrolira yerine `8_998_192_055_486_251` hesaplandı.
- **PR #2, README ile A–C raporu arasında güncellik farkı.** README 19 Kasım’daki 92 başarılı testi güncel diye gösteriyor. Baş commit’teki A–C raporu 22 Kasım tarihli ve 93 başarılı test bildiriyor. MATLAB erişimi olmadığı için güncel modelin bağımsız sayımı doğrulanamadı.

## 4. Yapılan Düzeltmeler

- `packages/billing/src/index.ts` doğrulanmış Wh değerlerini toplamadan önce `bigint` türüne çeviriyor.
- `packages/billing/src/billing.test.ts` toplam Wh değeri güvenli tamsayı sınırını aştığında ve ücret hâlâ temsil edilebildiğinde dağıtım ücretini kontrol eden regresyon testi içeriyor.
- Kök neden ve test `c15fa2d185dddaf1ac6bbfaf5c29b6ef8f265bea` commit mesajında belgelendi. GitHub yazma erişimi sağlandıktan sonra commit normal push ile PR #1 dalına gönderildi ve sonuçlar PR’a eklendi. Yerel Git kimliği yapılandırılmamış olduğundan commit oluşturulurken kişisel bilgi içermeyen bir araç kimliği kullanıldı. PR #2’ye düzeltme uygulanmadı. [PR #1 test yorumu](https://github.com/mamyylmz/akilli_sayac/pull/1#issuecomment-7084284933)

## 5. Tekrar Test Sonuçları

PR #1’de düzeltmeden sonra `pnpm build:packages`, `pnpm typecheck`, `pnpm lint`, `pnpm build` ve `git diff --check` başarılı. `pnpm test` ile **30/30**, `pnpm test:smoke:tcp` ile **1/1** test geçti. Ayrı servis ve disk SQLite kontrolleri de başarılı. PR #2 tekrar testleri **DOĞRULANAMADI**.

## 6. Güvenlik İncelemesi Bulguları

| Kontrol | Sonuç ve kapsam |
| --- | --- |
| Yetkisiz röle komutu | Mevcut entegrasyon testi kimliksiz istek için 401, görüntüleyici rolü için 403 doğruladı. |
| Tekrar gönderim ve HMAC | Mevcut testler paket kimliği/sıra tekrarının, hatalı HMAC’in, değiştirilmiş içeriğin ve yanlış sayaç kimliğinin reddini doğruladı. |
| Bozuk ve aşırı büyük payload | Mevcut testler bozuk JSON ve boyut sınırı reddini, yanıtta yığın izi bulunmadığını doğruladı. |
| SQL injection ve path traversal | Mevcut testler SQL benzeri tanımlayıcıların şema sınırında, dizin dışı yol biçimlerinin dosya okumasından önce reddini doğruladı. İnceleme bu mevcut test kapsamıyla sınırlı. |
| Yerel bind | Çalıştırılan API ve frontend süreçlerinin dinleme adresleri `netstat` ile `127.0.0.1` olarak doğrulandı. API yapılandırması yalnızca bu adresi kabul ediyor. |
| `.gitignore` ve CI | `git check-ignore` ile yerel ortam, SQLite, özel fixture/import ve simülasyon çıktısı yolları kontrol edildi. CI dosyasında salt okunur token yetkisi, checkout kimlik bilgilerinin kalıcı tutulmaması, SHA ile sabitlenen Actions, audit ve geçmiş taraması incelendi. |
| Bağımlılıklar ve gizli bilgiler | `pnpm audit` bilinen açık raporlamadı. `gitleaks git --config .gitleaks.toml --redact=100 --log-opts="--all" .` yerel düzeltme dahil 22 commit’te eşleşme bulmadı. |
| Gerçek ve sentetik veri | Örnek dosya `fixtures/synthetic/` altında ve imzasız. Şema kaynak tipini tutuyor ve sentetik verinin güvenilir işaretlenmesini reddediyor. Dashboard prototip verisini simüle/sentetik etiketliyor ve fiziksel veri güven bayrağını kapalı döndürüyor. SQLite ve çalışma zamanı doğrulamalarında sentetik örnek kullanıldı. Fiziksel veriyle çalışan bir uçtan uca ayrıştırma akışı doğrulanamadı. |
| Simulink sınırı | Röle testi yerel yazılım adaptörünü kapsıyor. Canlı Simulink veri aktarımı ve fiziksel röle çalıştırma **DOĞRULANAMADI**. |

## 7. Merge Edilen PR'lar ve Merge Commit SHA'ları

PR #1, GitHub’da test edilmiş baş SHA sabitlenerek merge commit yöntemiyle birleştirildi. Merge commit SHA’sı `2a17bce0a4268f0c8dffdf9bdf1fb378178f2ea9`. İşlemden sonra hem `feature/software-foundation-security` hem `simulink-d-asamasi` uzak ref’lerinin bulunduğu doğrulandı. [Merge commit’i](https://github.com/mamyylmz/akilli_sayac/commit/2a17bce0a4268f0c8dffdf9bdf1fb378178f2ea9)

PR #1 merge’ü `git revert -m 1` ile geri alındı. Uzak geçmiş normal push ile ilerletildi. [Geri alma commit’i](https://github.com/mamyylmz/akilli_sayac/commit/4fbf27cb538029d9faa185de5ae2495708e2ac42)

## 8. Birleştirilemeyen İşlemler ve Nedenleri

- **PR #2 açık.** PR #1 merge edildikten sonra `git merge-tree --write-tree origin/main origin/simulink-d-asamasi` çakışmasız tamamlandı. GitHub da PR’ı birleştirilebilir gösterdi. Çakışmayı gidermek için dal güncellemesi gerekmedi.
- **PR #2 kritik testleri DOĞRULANAMADI.** PATH, kurulum dizinleri, MathWorks kayıt defteri ve ilgili ortam değişkenlerinde çalıştırılabilir MATLAB R2026b ortamı bulunamadı. PR baş SHA’sında bağımsız MATLAB CI kontrolü de görülmedi. Simulink geliştiricisinden veya erişim sağlanan başka bir doğrulama ortamından A–C, altı D senaryosu ve B/E/F/G testlerinin yeni çıktıları gerekiyor. Son kabul, güncel `main` ile birleştirilecek kod üzerinden yapılmalı.

## 9. Güncel `main` Dalının Durumu

Yazılım testleri geri alma öncesinde `2a17bce0a4268f0c8dffdf9bdf1fb378178f2ea9` üzerinde çalıştırıldı. Node.js 24.22.3 ve pnpm 12.21.0 ile kilitli kurulum, paket derlemesi, typecheck, lint, **30/30 yazılım testi**, build ve **1/1 TCP testi** tamamlandı. Lint’in ilk çalıştırması geçici bir Windows dosya kilidiyle kesildi ve tekrarında geçti. `git ls-tree` ile `simulink/` ağaç kimliği `eeea20afde740b099e1e124333bc4c8e5ac54c1a` olarak eşleşti.

Merge sonrası `pnpm audit` ve Gitleaks kontrolleri bulgu üretmedi. Geri almadan sonra `git diff --exit-code a005f26580549d4f65435c7d8085dd7007ca6401 4fbf27cb538029d9faa185de5ae2495708e2ac42` başarılı oldu. Mevcut `main`, merge öncesi dosya ağacına döndüğü için yazılım çalışma alanı feature dalında bulunuyor. Bu rapor da feature dalına dahil edildi.
