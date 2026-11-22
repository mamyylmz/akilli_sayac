# Akıllı Sayaç geliştirme durumu

Son güncelleme: 23.11.2026

## 1. Başlangıç noktası ve GitHub durumu

- Yazılım başlangıç dalı: `feature/software-foundation-security`
- Başlangıç commit'i: `559b760`
- Geliştirme dalı: `feature/software-simulink-integration`
- `origin/main`: `4fbf27c`; PR #1'in `2a17bce` merge commit'i bu commit ile geri alınmış durumda.
- PR #1: kapalı ve merge edilmiş; yazılımın `main`e yeniden alınması ayrı bir PR gerektirir.
- PR #2: açık, taslak ve merge edilebilir; head `simulink-d-asamasi@91c1cb7`.
- `simulink-han-ekrani@486b25b`, `simulink-veri-aktarimi@95d6e4d` dalının atasıdır.
- `simulink-d-asamasi@91c1cb7`, veri aktarımı dalının atası değildir. Veri aktarımı hattında ayrı
  `269fafc` kesinti düzeltmesi bulunur. İki `.slx` hattı Simulink geliştiricisi tarafından
  uzlaştırılmadan yazılım PR'ına zorla alınmamalıdır.

Simulink dalları rebase edilmedi, yeniden yazılmadı ve force push yapılmadı. Sözleşme, üretici ve
fixture'lar remote Git nesnelerinden salt okunur incelendi. Yazılım değişiklikleri aynı Simulink
değişikliklerini gelecekteki PR'da tekrar sunmamak için ayrı tutuldu.

## 2. Tamamlanan geliştirmeler

- Simulink veri sözleşmesi 1.0 için gerçek üçlü paket importer'ı.
- Çalıştırma bazlı SQLite Head-End/MDM saklama ve aktif/seçili çalışma desteği.
- T1/T2/T3 sayaçlarından, sürümü saklanan tarife ile BigInt tabanlı TL faturası.
- Çalıştırma, ölçüm serisi, tarife, fatura ve röle durum API'leri.
- API verisine bağlı responsive ve erişilebilir HAN ekranı.
- Röle placeholder'ının gerçek uygulama iddiasını kaldıran `pending/applied/rejected` protokolü.
- Import, seçim ve röle işlemleri için audit izleri.

## 3. Değişen ve eklenen dosyalar

Başlıca uygulama dosyaları:

- `apps/api/src/simulink-import.ts`: sözleşme parser ve doğrulamaları.
- `apps/api/src/database.ts`: yeni tablolar, transaction importu, çalıştırma seçimi ve faturalar.
- `apps/api/src/app.ts`: yeni ve güncellenen HTTP endpoint'leri.
- `apps/api/src/file-import.ts`: gerçek yol, symlink, boyut ve kararlı okuma kontrolleri.
- `apps/api/src/simulator-adapter.ts`: doğru röle durum semantiği.
- `apps/web/src/App.tsx`, `apps/web/src/styles.css`: HAN ekranı.
- `packages/contracts/src/control.ts`, `packages/security/src/auth.ts`: protokol ve yetki kapsamı.
- `apps/api/src/simulink-import.test.ts`, `apps/api/src/app.test.ts`: hedefli testler.
- `docs/SETUP.md`, `docs/INTEGRATION.md`, `docs/SIMULINK_RELAY_PROTOCOL.md`: işletim ve handoff.

`csv-parse@7.0.3` MIT lisanslı bağımlılığı kesin sürüm ve integrity ile lockfile'a eklendi.

## 4. API endpoint'leri

| Yöntem ve yol                                     | İşlev                                              | Yetki                   |
| ------------------------------------------------- | -------------------------------------------------- | ----------------------- |
| `POST /api/v1/ami/import-file`                    | Meta adı üzerinden sözleşme 1.0 üçlü paket importu | `ami:import`            |
| `GET /api/v1/simulation-runs`                     | Sayaç çalıştırmalarını ve aktif seçimi listeler    | `meter:read`            |
| `POST /api/v1/simulation-runs/:runId/select`      | Aktif çalıştırmayı seçer ve audit yazar            | `meter:read`            |
| `GET /api/v1/simulation-runs/:runId/measurements` | 1, 15 veya 60 dakikalık seri döndürür              | `meter:read`            |
| `GET /api/v1/dashboard?runId=...`                 | Seçilen çalıştırmanın özetini döndürür             | `meter:read`            |
| `GET /api/v1/tariffs`                             | Geçerlilik tarihli tarifeleri listeler             | `meter:read`            |
| `POST /api/v1/tariffs`                            | Değişmez kimlikli tarife oluşturur                 | `tariff:manage` (admin) |
| `POST /api/v1/simulation-runs/:runId/bills`       | Çalıştırma/tarife snapshot faturası                | `meter:read`            |
| `GET /api/v1/control-commands/:commandId`         | Röle komut protokol durumunu döndürür              | `meter:read`            |

HMAC doğrulamalı `POST /api/v1/ami/import`, audit ve röle güvenlik endpoint'leri korunmuştur.

## 5. Veri sözleşmesi 1.0 eşlemesi

- 27 ölçüm sütunu ve 9 olay sütunu tam ad ve sırayla doğrulanır.
- Sayaç `SIM-0001`, ortak `run_id`, `+03:00`, aralık başlangıcı ve ardışık 1 dakika kontrol edilir.
- Normal model/test paketi tam 1440 satır olmak zorundadır.
- Kısa paket yalnızca `veri_turu=test` ve metadata `ornek` alanıyla fixture kabul edilir.
- İlk iki tam gün satırında `gecerli=0` aranır; bu satırlar saklanır ve enerjileri korunur.
- `p_W`, `e_aralik_kWh` ve kümülatif net sayaçlara sıfır kırpma uygulanmaz.
- Olay kodları, durum, yeniden bağlantı red maskesi ve neden alanı doğrulanır.
- Simulink değerleri yeniden üretilmez; yalnızca sayaç farkları ve toplamlar toleransla karşılaştırılır.
- Metadata içindeki tüm `kontroller[].gecti` değerleri true değilse paket reddedilir.

## 6. Veritabanı migration'ları

Mevcut tablolar korunarak aşağıdaki tablolar eklendi:

- `simulation_runs`
- `simulation_measurements`
- `simulation_run_energy`
- `simulation_events`
- `active_simulation_runs`
- `billing_snapshots`

`run_id`, `(run_id, measured_at)`, `(run_id, minute)` ve olay kimlikleri benzersizdir. Uygun sayaç,
zaman ve çalıştırma index'leri vardır. Mevcut `control_commands` tablosuna geriye uyumlu
`protocol_status` sütunu eklenir. Import ölçüm, olay, enerji, aktif seçim ve audit kayıtlarını tek
`BEGIN IMMEDIATE` transaction'ında yazar; hata halinde rollback yapar.

## 7. Import akışı ve güvenlik

1. Yetkili aktör yalnızca meta dosya adını gönderir.
2. Dosya adı, izinli gerçek dizin, regular-file ve symlink koşulları doğrulanır.
3. Meta ve CSV boyutları; CSV kayıt üst sınırları kontrol edilir.
4. Metadata 1.0 şeması, dosya adları ve Simulink kontrolleri doğrulanır.
5. CSV baytlarının SHA-256 değerleri metadata ile karşılaştırılır.
6. Kimlik, sütun, tür, sıra, olay ve enerji kontrolleri yapılır.
7. Metadata doğrulama sonunda yeniden okunarak paket değişikliği denetlenir.
8. Aynı `run_id` ikinci kez yazılmaz.
9. Transaction tamamlanınca demonstrasyon tarife snapshot'ı oluşturulur.

SHA-256 üretici kimliği değildir. Import `trusted_source=0` olarak saklanır ve güvenli HMAC AMI
yoluna fiziksel güvenilirlik aktarmaz. Başarısız importlarda kullanıcıya kararlı hata kodu verilir
ve red audit kaydı yazılır.

## 8. HAN arayüzü

Arayüz API'den çalıştırma seçer; sayaç ve veri türünü, şebeke/röle/alarm durumunu, elektriksel
ölçümleri, net enerji/T1/T2/T3 sayaçlarını, reaktif enerjiyi, batarya SOC/mod/gücünü, fatura ve
olayları gösterir. Günlük güç grafiği 15 dakikalık veya saatlik seçilebilir. `gecerli=0` satırlar
güç ortalamasından çıkarılır ve turuncu kalite işaretiyle belirtilir. İkinci çalıştırma seçilerek
batarya aktif/pasif senaryolarının maliyet farkı karşılaştırılabilir.

Sözleşme 1.0 ayrı bir gerçek PF alanı üretmediği için arayüz bu değeri yeniden hesaplamaz; alanı
"sözleşmede yok" açıklamasıyla boş gösterir.

## 9. Tarife ve fatura

Mevcut `packages/billing` BigInt/mikrolira yaklaşımı kullanılır. Yerel varsayılan tarife açıkça
`demonstration=true` etiketlidir; T1/T2/T3, dağıtım ve örnek vergi bileşeni içerir. Tarife JSON'u,
enerji Wh değerleri ve sonuç her çalıştırma için snapshot olarak saklanır. Aynı run/tarife tekrar
istendiğinde eski snapshot döner. Net negatif tarife sayacı otomatik indirim olmaz; sıfırın altı
`excluded_net_export_wh` olarak ayrı kaydedilir. Reaktif ceza hesaplanmaz.

## 10. Röle entegrasyonunun gerçek durumu

Komut kimliği, aktör, sayaç, istenen durum, son kullanma zamanı, protokol durumu, sonuç/red nedeni
ve audit kaydı uygulanmıştır. Yerel placeholder gerçek modeli çalıştırmaz ve artık `APPLIED`
dönmez; `pending / QUEUED_FOR_SIMULINK` döner. Gerçek `applied` sonucu için
`docs/SIMULINK_RELAY_PROTOCOL.md` içindeki komut/yanıt adaptörü Simulink tarafında uygulanmalıdır.
CSV importu röle komutu üretmez.

## 11. Güvenlik kontrolleri

- Mevcut authentication, rol yetkileri, HMAC, replay koruması ve rate limiting korundu.
- Yeni admin-only `tariff:manage` yetkisi eklendi.
- SQL ifadeleri parametrelidir; veri dosyası içeriği çalıştırılmaz.
- Dosya traversal, symlink, boyut, satır, kararlı okuma ve SHA-256 kontrolleri vardır.
- Import, seçim, röle ve red işlemleri audit edilir.
- API varsayılan olarak yalnızca `127.0.0.1` üzerinde çalışır.
- Fixture ve model verisi fiziksel sayaç verisi olarak işaretlenmez.

## 12. Gerçek doğrulama sonuçları

Geçici resmi Node.js `v24.21.0` çalışma zamanı ile:

- Contracts, billing ve security TypeScript derlemesi: geçti.
- API ve web TypeScript typecheck: geçti.
- ESLint (`--max-warnings 0`) ve Prettier kontrolü: geçti.
- API derlemesi ve Vite production web build: geçti.
- `pnpm-lock.yaml` frozen/offline doğrulaması: geçti.
- `pnpm audit --audit-level high`: bilinen açık bulunmadı.
- Importer/API/röle hedefli testleri: **18/18 geçti**.
- Contracts/billing/security hedefli testleri: **16/16 geçti**.
- Remote `simulink-veri-aktarimi@95d6e4d` gerçek fixture doğrulaması:
  - kesinti paketi: 21 ölçüm / 4 olay, geçti;
  - aşırı güç paketi: 36 ölçüm / 6 olay, geçti;
  - aşırı güç paketi SQLite importu, 15 dk seri, olay ve demo fatura: geçti.

MATLAB R2026b bu ortamda yoktur. Fiziksel model veya Simulink testleri yeniden çalıştırılmadı;
repository'deki geliştirici raporları bağımsız doğrulama olarak sunulmaz.

Üst seviye `pnpm verify` sarmalayıcısı, sandbox içindeki `.pnpm` kilit dizininin salt okunur olması
ve alt süreçte `pnpm` PATH kaydı bulunmaması nedeniyle tek komut olarak çalışmadı. Sarmalayıcının
typecheck, lint, test ve build adımları aynı sürümlerle ayrı ayrı çalıştırılıp yukarıda raporlandı.

## 13. Kalan veya engellenen işler

- Gerçek 1440 satırlık üretim paketi Git politikasına göre depoda bulunmuyor. Yazılımın ürettiği
  1440 satırlık sözleşme fixture'ı test edildi; Simulink'ten dışarı alınmış tam gün dosyasıyla son
  kabul bağımsız test ekibinde yapılmalıdır.
- PR #2'nin `91c1cb7` `.slx` düzeltmesi ile veri aktarımı dalındaki `269fafc` hattı Simulink sahibi
  tarafından uzlaştırılmalıdır. Yazılım bu ikili dosya çatışmasını çözmeye çalışmamıştır.
- Gerçek Simulink röle komut tüketicisi ve onay yanıtı henüz yoktur.

## 14. Simulink geliştiricisinden beklenen görevler

1. PR #2 ve veri aktarımı dalındaki ayrışan model düzeltmelerini tek doğrulanmış hatta uzlaştırmak.
2. Uzlaştırılmış modelden bir tam günlük sözleşme 1.0 paketi üretmek.
3. Röle komut/yanıt adaptörünü uygulayıp `applied` ve `rejected` sonuçlarını model korumasına bağlamak.
4. Mevcut 195/195 raporunu uzlaştırılmış son commit üzerinde yeniden üretip commit/hash ile eşlemek.

## 15. Bağımsız kabul kriterleri

1. Yetkisiz import 401/403; izinli geçerli paket 201 dönmeli.
2. Değişmiş CSV, symlink, yanlış `run_id`, yanlış sayaç, eksik satır ve başarısız Simulink kontrolü
   hiçbir kısmi kayıt bırakmadan reddedilmeli.
3. Aynı `run_id` ikinci importta 409 dönmeli ve ölçüm/olay/fatura çoğalmamalı.
4. Tam gün 1440 satır ve ilk iki `gecerli=0` satır korunmalı; güç grafiğine geçersiz değer girmemeli.
5. Negatif güç/enerji korunmalı; net negatif enerji fatura indirimi olmamalı.
6. İki farklı `run_id` aynı güne ait olsa da ayrı seçilebilmeli ve sayaçları birleştirilmemeli.
7. HAN'da ölçüm, olay, batarya, tüketim, tarife ve TL tutarı seçilen run ile tutarlı olmalı.
8. Placeholder röle komutu `pending` kalmalı; gerçek model onayı olmadan `applied` olmamalı.
9. Eski HMAC AMI replay/idempotency ve mikrolira hassasiyet testleri geçmeye devam etmeli.

## 16. PR hazırlığı

Değişiklikler `feature/software-simulink-integration` dalında, `main` dışında hazırlanmıştır.
`main`e doğrudan merge veya public GitHub push yapılmamıştır. PR, yazılım temelini yeniden getiren
ayrı inceleme olarak açılmalı; hedef dal stratejisi Simulink dallarının uzlaştırılmasından sonra
proje yöneticisi tarafından onaylanmalıdır.
