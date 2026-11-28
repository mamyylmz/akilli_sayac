function sonuc = kabul_paketi(varargin)
%KABUL_PAKETI  MATLAB/Simulink kabul kanıtlarını tek bir commit'e bağlı tek bir zip'te toplar.
% Konum : Akilli_Sayac/simulink/kabul_paketi.m
%
% Kullanım (simulink klasöründeyken; GitHub Desktop'ta "No local changes" iken):
%   kabul_paketi
%   kabul_paketi('kirliyeIzinVer', true)   % yalnızca deneme: manifestoda "temiz": false yazar,
%                                          % sonuç FAIL sayılır
%
% Sırasıyla:
%   1) Git: commit SHA ve dal okunur. İzlenen dosyalarda kaydedilmemiş değişiklik varsa durur
%      (kanıt o commit'e ait olmazdı).
%   2) Ortam: MATLAB, Simulink, Simscape, Simscape Electrical sürümleri.
%   3) tum_testler çalışır; her grubun GEÇTİ/KALDI sayısı ve sonuç dosyaları pakete girer.
%   4) Exportlar: veri_aktar (normal gün, model verisi) ve gosteri_gunu('veri') (olaylı TEST günü).
%      Contract 1.0 dosyaları değiştirilmeden kopyalanır.
%   5) role_adaptoru ile gerçek modelde üç komut: 12:00 kesme (normal gün), 18:10 enerji verme
%      (aşırı güç kesmesinden sonra, koruma kilitli), 18:20 enerji verme (güvenli). Komut, cevap,
%      kanıt dosyaları ve defter saklanır.
%   6) manifesto.json: commit, ortam, test dağılımı, run_id'ler, adaptör sonuçları, kaynak dosyaların
%      Git blob kimlikleri (git ls-tree ile karşılaştırılabilir) ve paketteki her dosyanın SHA-256'sı.
%      OZET.md: aynı bilgilerin kısa, okunur hali.
%   7) Hepsi ciktilar/kabul/kabul_<sha7>_<zaman>/ klasörüne ve aynı adlı .zip dosyasına yazılır
%      (ciktilar/ Git dışında). Çalışmanın tamamı kabul_gunlugu.txt dosyasına kaydedilir.
% Süre: ~12 dk.
%
% 28.11.2026 - Poyraz: ilk sürüm; günlükte uyarı yığın izleri kapalı, komutlara reason alanı

p = inputParser;
p.addParameter('kirliyeIzinVer', false, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
izin = logical(p.Results.kirliyeIzinVer);

kok = fileparts(mfilename('fullpath'));
eskiDizin = cd(kok);
geriDon = onCleanup(@() cd(eskiDizin)); %#ok<NASGU>
evalin('base', 'clear test_senaryo');
acik = find_system('type', 'block_diagram');
kirliModel = {};
if ~isempty(acik), kirliModel = acik(strcmp(get_param(acik, 'Dirty'), 'on')); end
if ~isempty(kirliModel)
    error('Açık modelde kaydedilmemiş değişiklik var (%s). Kaydetmeden kapatın (veya commit''leyin), sonra tekrar çalıştırın.', ...
          strjoin(kirliModel, ', '));
end
bdclose('all');

%% 1) Git
r = gitrepo(fullfile(kok, '..'));
sha = char(r.LastCommit.ID);
dal = '(ayrık HEAD)';
try, dal = char(r.CurrentBranch.Name); catch, end
[temiz, degisen, izlenmeyen] = gitDurumu(r);
fprintf('Commit: %s | Dal: %s | Çalışma alanı temiz: %s\n', sha, dal, mat2str(temiz));
if isequal(temiz, false) && ~izin
    error(['Kaydedilmemiş değişiklik var; kanıt bu commit''e ait olmaz. Önce GitHub Desktop''ta ' ...
           'commit''leyin veya geri alın (Discard):\n  %s'], strjoin(cellstr(degisen), '\n  '));
end

zaman = char(datetime('now', 'TimeZone', 'Europe/Istanbul', 'Format', 'yyyyMMdd_HHmmss'));
ad = sprintf('kabul_%s_%s', sha(1:7), zaman);
ust = fullfile(kok, 'ciktilar', 'kabul');
paket = fullfile(ust, ad);
for d = {'testler', fullfile('ciktilar', 'model'), fullfile('ciktilar', 'test'), 'role_komut'}
    mkdir(fullfile(paket, d{1}));
end
gunluk = fullfile(paket, 'kabul_gunlugu.txt');
diary(gunluk);
diary on
kapatGunluk = onCleanup(@() diary('off')); %#ok<NASGU>
eskiUyari = warning('query', 'backtrace');            % günlükte uyarıların yığın izi (bağlantılı satırlar) olmasın;
warning('off', 'backtrace');                          % uyarı metinleri yine yazılır
geriUyari = onCleanup(@() warning(eskiUyari)); %#ok<NASGU>
fprintf('KABUL PAKETİ %s\nCommit: %s | Dal: %s | Temiz: %s\n', ad, sha, dal, mat2str(temiz));

%% 2) Ortam
v = ver;
k = startsWith({v.Name}, ["MATLAB", "Simulink", "Simscape"]);
urunler = struct('ad', {v(k).Name}, 'surum', {v(k).Version}, 'surumAdi', {v(k).Release});
ortam = struct('matlab', version, 'urunler', {urunler}, 'bilgisayar', computer);
fprintf('MATLAB %s\n', version);
for i = 1:numel(urunler)
    fprintf('  %s %s %s\n', urunler(i).ad, urunler(i).surum, urunler(i).surumAdi);
end

%% 3) Testler
tBas = tic;
try
    testleriCalistir(fullfile(kok, 'testler'));
catch h
    fprintf('tum_testler HATA: %s\n', h.message);
end
testSuresi = toc(tBas);
cd(kok);
evalin('base', 'clear test_senaryo');
diary off;  diary on                                   % günlüğü diske yaz, sonra oku
gruplar = ozetiOku(gunluk);
kopyala(fullfile(kok, 'testler'), ...
        {'*_sonuclari.md', '*_sonuclari.xlsx', 'olay_kayitlari.md', 'guc_kalitesi_olaylari.md'}, ...
        fullfile(paket, 'testler'));
ad195 = {'test_dogrulama', 'test_D_koruma', 'test_B_batarya', 'test_E_guc_kalitesi', ...
         'test_F_talep', 'test_G_kesinti_batarya'};
g195 = gruplar(ismember({gruplar.ad}, ad195));
testler = struct('gruplar', {gruplar}, ...
    'dagilim195', dagilim(g195), ...
    'gecti195', sum([g195.gecti]), 'kaldi195', sum([g195.kaldi]), ...
    'toplamGecti', sum([gruplar.gecti]), 'toplamKaldi', sum([gruplar.kaldi]), ...
    'toplamBekliyor', sum([gruplar.bekliyor]), 'grupSayisi', numel(gruplar), ...
    'sureSn', round(testSuresi));
testlerGecti = numel(gruplar) == 7 && testler.toplamKaldi == 0 && testler.toplamBekliyor == 0 && ...
               all([gruplar.gecti] > 0);

%% 4) Exportlar
evalin('base', 'clear test_senaryo');
a = veri_aktar;
g = gosteri_gunu('veri');
exportlar = [exportKaydi(a, paket, 'model', ''), ...
             exportKaydi(g.aktarim, paket, 'test', sprintf('%d/%d', nnz([g.kontroller{:,2}]), size(g.kontroller, 1)))];
if exist(g.grafik, 'file'), copyfile(g.grafik, fullfile(paket, 'ciktilar', 'test', 'gosteri_gunu.png')); end
exportGecti = a.kontroller_gecti && strcmp(a.veri_turu, 'model') && ...
              g.aktarim.kontroller_gecti && strcmp(g.aktarim.veri_turu, 'test') && g.gecti;

%% 5) Röle adaptörü: gerçek modelde üç komut
dk = 1/60;
asiri = struct('camasir_t', [0 18 18+15*dk 19 20.5 25], 'camasir_u', [0 1 0 1 0 0], ...
               'klima_t',   [0 18 18+15*dk 20 23 25],   'klima_u',   [0 1 0 1 0 0]);
rs = RandStream('mt19937ar', 'Seed', 'shuffle');
rk = fullfile(paket, 'role_komut');
komutlar = { ...
  '1_kesme_1200.json',              'deenergized', 12,  0, struct(), 'Normal gün, 12:00 uzaktan kesme';
  '2_enerji_kilitliyken_1810.json', 'energized',   18, 10, asiri,    'Aşırı güç kesmesinden sonra; bekleme dolmuş ama tahmini yük yüksek';
  '3_enerji_guvenli_1820.json',     'energized',   18, 20, asiri,    'Aynı senaryo; çamaşır makinesi ve klima kapandıktan sonra' };
beklenen = { 'applied',  'APPLIED',             0;
             'rejected', 'PROTECTION_REJECTED', 2;
             'applied',  'APPLIED',             0 };
adaptor = struct('dosya', {}, 'aciklama', {}, 'commandId', {}, 'istenen', {}, 'saat', {}, ...
                 'status', {}, 'code', {}, 'relayState', {}, 'komut', {}, 'role', {}, 'durum', {}, ...
                 'redMaske', {}, 'beklenenStatus', {}, 'beklenenCode', {}, 'gecti', {});
fprintf('\nRÖLE ADAPTÖRÜ (gerçek model)\n');
for i = 1:size(komutlar, 1)
    cid = uuidUret(rs);
    komutYaz(rk, komutlar{i,1}, cid, komutlar{i,2}, komutlar{i,3}, komutlar{i,4});
    role_adaptoru('klasor', rk, 'senaryo', komutlar{i,5});
    c  = jsonOku(fullfile(rk, 'giden', [cid '.json']));
    kn = jsonOku(fullfile(rk, 'kanit', [cid '.json']));
    x = struct('dosya', komutlar{i,1}, 'aciklama', komutlar{i,6}, 'commandId', cid, ...
        'istenen', komutlar{i,2}, 'saat', sprintf('%02d:%02d', komutlar{i,3}, komutlar{i,4}), ...
        'status', alan(c, 'status'), 'code', alan(c, 'code'), 'relayState', alan(c, 'relayState'), ...
        'komut', alan(kn, 'komut'), 'role', alan(kn, 'role'), 'durum', alan(kn, 'durum'), ...
        'redMaske', alan(kn, 'redMaske'), 'beklenenStatus', beklenen{i,1}, 'beklenenCode', beklenen{i,2}, ...
        'gecti', false);
    x.gecti = isequal(x.status, beklenen{i,1}) && isequal(x.code, beklenen{i,2}) && ...
              isequal(x.redMaske, beklenen{i,3});
    adaptor(end+1) = x; %#ok<AGROW>
end
adaptorGecti = all([adaptor.gecti]);
cd(kok);

%% 6) Manifesto ve özet
[temizSon, degisenSon] = gitDurumu(gitrepo(fullfile(kok, '..')));   % çalışma sırasında izlenen dosya değişti mi?
kaynak = kaynakDosyalar(kok);
genelGecti = isequal(temiz, true) && isequal(temizSon, true) && testlerGecti && exportGecti && adaptorGecti;
sonucMetni = secim(genelGecti, 'PASS', 'FAIL');

fprintf('\n================ KABUL PAKETİ ================\n');
fprintf('Commit      : %s (%s), temiz başta: %s, sonda: %s\n', sha, dal, mat2str(temiz), mat2str(temizSon));
fprintf('Testler     : %d GEÇTİ, %d KALDI (195 = %s; %d grup)  %s\n', testler.toplamGecti, ...
        testler.toplamKaldi, testler.dagilim195, numel(gruplar), secim(testlerGecti, 'PASS', 'FAIL'));
for e = exportlar
    fprintf('Export %-5s: %s, %d satır, %d olay, kontroller %s %s\n', e.veriTuru, e.runId, e.satir, ...
            e.olay, mat2str(e.kontrollerGecti), e.gosteriKontrolleri);
end
for x = adaptor
    fprintf('Adaptör     : %s %-11s -> %-8s %-20s röle %g, maske %g  %s\n', x.saat, x.istenen, ...
            x.status, x.code, x.role, x.redMaske, secim(x.gecti, 'PASS', 'FAIL'));
end
fprintf('GENEL       : %s\n', sonucMetni);
diary off

dosyalar = paketDosyalari(paket);                     % günlük dahil; manifesto ve OZET hariç
man = struct('manifestoSurumu', '1.0', 'paket', ad, ...
    'olusturma', char(datetime('now', 'TimeZone', 'Europe/Istanbul', 'Format', 'yyyy-MM-dd''T''HH:mm:ssxxx')), ...
    'sonuc', sonucMetni, ...
    'git', struct('commit', sha, 'dal', dal, 'temizBaslangic', temiz, 'temizBitis', temizSon, ...
                  'degisenDosyalar', {cellstr(degisen)}, 'izlenmeyenDosyalar', {cellstr(izlenmeyen)}, ...
                  'calismaSirasindaDegisen', {cellstr(degisenSon)}), ...
    'ortam', ortam, ...
    'testler', testler, 'testlerGecti', testlerGecti, ...
    'exportlar', {exportlar}, 'exportGecti', exportGecti, ...
    'roleAdaptoru', struct('komutlar', {adaptor}, 'gecti', adaptorGecti), ...
    'kaynakDosyalar', {kaynak}, ...
    'dosyalar', {dosyalar}, ...
    'notlar', {{ ...
      'Bütün veriler Simulink simülasyonudur; gerçek sayaç veya kişisel veri yoktur.', ...
      'Contract 1.0 dosyaları veri_aktar çıktısının değiştirilmemiş kopyalarıdır; SHA-256 özetleri meta dosyalarındakilerle aynıdır.', ...
      'kaynakDosyalar.gitBlob: diskteki dosyadan Git kurallarıyla (.m/.md/.gitignore için CRLF->LF) hesaplanan blob kimliği; git ls-tree -r <commit> simulink/ çıktısıyla aynı olmalıdır.', ...
      'Röle cevapları protokoldeki alanlarla imzasız yazılır; ayrıntılar role_komut/kanit/ altındadır.'}});
fid = fopen(fullfile(paket, 'manifesto.json'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', jsonencode(man, 'PrettyPrint', true));
fclose(fid);
ozetYaz(fullfile(paket, 'OZET.md'), man);

%% 7) Zip
zipYolu = [paket '.zip'];
zip(zipYolu, ad, ust);
zipSha = sha256_dosya(zipYolu);
fprintf('Paket       : %s\nZip SHA-256 : %s\n\n', zipYolu, zipSha);
if nargout > 0
    sonuc = struct('commit', sha, 'zip', zipYolu, 'zipSha256', zipSha, 'gecti', genelGecti, 'manifesto', man);
end
end

%% ---------------- yardımcı fonksiyonlar ----------------
function testleriCalistir(klasor)
    % tum_testler kendi çalışma alanında çalışır (testlerin "clear" komutu buraya dokunmaz)
    eski = cd(klasor);
    geri = onCleanup(@() cd(eski)); %#ok<NASGU>
    feval('tum_testler');
end

function [temiz, degisen, izlenmeyen] = gitDurumu(r)
    % temiz: true/false; Git durumu okunamazsa [] (manifestoda null, sonuç FAIL)
    temiz = [];  degisen = strings(0,1);  izlenmeyen = strings(0,1);
    try
        degisen = string(r.ModifiedFiles(:));
        temiz = isempty(degisen);
    catch
        warning('Git çalışma alanı durumu okunamadı.');
    end
    try, izlenmeyen = string(r.UntrackedFiles(:)); catch, end
end

function g = ozetiOku(gunluk)
    % tum_testler'in "GENEL ÖZET" satırları: test_x  açıklama  N GEÇTİ, M KALDI[, K BEKLİYOR]
    g = struct('ad', {}, 'gecti', {}, 'kaldi', {}, 'bekliyor', {}, 'ozet', {});
    s = fileread(gunluk, 'Encoding', 'UTF-8');
    i = strfind(s, 'GENEL ÖZET');
    if isempty(i), return; end
    for satir = splitlines(s(i(end):end))'
        ad = regexp(satir{1}, '^(test_\w+)\s', 'tokens', 'once');
        if isempty(ad), continue; end
        t = regexp(satir{1}, '(\d+) GEÇTİ, (\d+) KALDI(?:, (\d+) BEKLİYOR)?', 'tokens', 'once');
        if isempty(t)                                   % HATA veya özet bulunamadı: kaldı sayılır
            g(end+1) = struct('ad', ad{1}, 'gecti', 0, 'kaldi', 1, 'bekliyor', 0, 'ozet', strtrim(satir{1})); %#ok<AGROW>
            continue
        end
        b = 0;  if numel(t) >= 3 && ~isempty(t{3}), b = str2double(t{3}); end
        g(end+1) = struct('ad', ad{1}, 'gecti', str2double(t{1}), 'kaldi', str2double(t{2}), ...
                          'bekliyor', b, 'ozet', strtrim(satir{1})); %#ok<AGROW>
    end
end

function s = dagilim(g)
    s = '';
    if ~isempty(g), s = strjoin(arrayfun(@(x) sprintf('%d', x.gecti), g, 'UniformOutput', false), '/'); end
end

function kopyala(kaynakDir, desenler, hedefDir)
    for d = desenler
        L = dir(fullfile(kaynakDir, d{1}));
        for k = 1:numel(L), copyfile(fullfile(L(k).folder, L(k).name), hedefDir); end
    end
end

function e = exportKaydi(s, paket, tur, gosteri)
    hedef = fullfile(paket, 'ciktilar', tur);
    for f = {s.olcum, s.olaylar, s.meta}, copyfile(f{1}, hedef); end
    m = jsondecode(fileread(s.meta, 'Encoding', 'UTF-8'));
    ad = @(y) ['ciktilar/' tur '/' dosyaAdi(y)];
    e = struct('veriTuru', s.veri_turu, 'runId', s.run_id, 'satir', m.satir_sayisi, 'olay', s.olay_sayisi, ...
               'kontrollerGecti', s.kontroller_gecti, 'gosteriKontrolleri', gosteri, ...
               'olcum', ad(s.olcum), 'olaylar', ad(s.olaylar), 'meta', ad(s.meta), ...
               'olcumSha256', s.olcum_sha256, 'olaylarSha256', s.olaylar_sha256);
end

function a = dosyaAdi(yol)
    [~, n, u] = fileparts(yol);  a = [n u];
end

function L = kaynakDosyalar(kok)
    % Modelin ve kodun diskteki hali (commit'teki blob'larla karşılaştırmak için)
    D = [dir(fullfile(kok, '*.m')); dir(fullfile(kok, 'testler', '*.m')); dir(fullfile(kok, '*.md')); ...
         dir(fullfile(kok, 'Akilli_Sayac.slx')); dir(fullfile(kok, '.gitignore')); dir(fullfile(kok, '.gitattributes'))];
    L = struct('yol', {}, 'gitBlob', {}, 'sha256', {});
    for k = 1:numel(D)
        tam = fullfile(D(k).folder, D(k).name);
        goreli = ['simulink/' strrep(erase(tam, [kok filesep]), '\', '/')];
        L(end+1) = struct('yol', goreli, 'gitBlob', gitBlob(tam, ~endsWith(D(k).name, '.slx')), ...
                          'sha256', sha256_dosya(tam)); %#ok<AGROW>
    end
end

function h = gitBlob(dosya, metin)
    % Git blob kimliği: SHA-1("blob <boyut>\0" + içerik). Metin dosyalarında CRLF -> LF.
    fid = fopen(dosya, 'r');  b = fread(fid, inf, '*uint8')';  fclose(fid);
    if metin
        cr = find(b(1:end-1) == 13 & b(2:end) == 10);
        b(cr) = [];
    end
    b = [uint8(sprintf('blob %d', numel(b))), uint8(0), b];
    h = '';
    try
        md = java.security.MessageDigest.getInstance('SHA-1');
        h = lower(reshape(dec2hex(typecast(md.digest(b), 'uint8'), 2)', 1, []));
    catch
        try
            sh = System.Security.Cryptography.SHA1.Create();
            h = lower(reshape(dec2hex(uint8(sh.ComputeHash(b)), 2)', 1, []));
        catch
            warning('Git blob kimliği hesaplanamadı: %s', dosya);
        end
    end
end

function L = paketDosyalari(paket)
    D = dir(fullfile(paket, '**', '*'));
    D = D(~[D.isdir]);
    L = struct('yol', {}, 'boyut', {}, 'sha256', {});
    for k = 1:numel(D)
        tam = fullfile(D(k).folder, D(k).name);
        goreli = strrep(erase(tam, [paket filesep]), '\', '/');
        if any(strcmp(goreli, {'manifesto.json', 'OZET.md'})), continue; end
        L(end+1) = struct('yol', goreli, 'boyut', D(k).bytes, 'sha256', sha256_dosya(tam)); %#ok<AGROW>
    end
end

function id = uuidUret(rs)
    % Rastgele UUID (sürüm 4)
    h = @(n) lower(dec2hex(randi(rs, [0 15], 1, n))');
    id = sprintf('%s-%s-4%s-%s%s-%s', h(8), h(4), h(3), lower(dec2hex(8 + randi(rs, [0 3]))), h(3), h(12));
end

function komutYaz(klasor, dosyaAdi, cid, istenen, hh, mm)
    % Alanlar docs/SIMULINK_RELAY_PROTOCOL.md'deki örnek komutla aynıdır (reason dahil). Tarih bugün, geçerlilik 24 saat;
    % simülasyon saati createdAt'in +03:00 saatinden alınır.
    bugun = datetime('today', 'TimeZone', 'Europe/Istanbul');
    k = struct('schemaVersion', '1.0.0', 'id', cid, 'commandId', cid, 'meterId', 'SIM-0001', ...
               'actorId', 'matlab-kabul-paketi', ...
               'createdAt', sprintf('%sT%02d:%02d:00+03:00', char(bugun, 'yyyy-MM-dd'), hh, mm), ...
               'expiresAt', sprintf('%sT%02d:%02d:00+03:00', char(bugun + days(1), 'yyyy-MM-dd'), hh, mm), ...
               'requestedRelayState', istenen, 'reason', 'MATLAB kabul paketi testi');
    if ~exist(fullfile(klasor, 'gelen'), 'dir'), mkdir(fullfile(klasor, 'gelen')); end
    fid = fopen(fullfile(klasor, 'gelen', dosyaAdi), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s\n', jsonencode(k, 'PrettyPrint', true));
    fclose(fid);
end

function ozetYaz(dosya, m)
    f = fopen(dosya, 'w', 'n', 'UTF-8');
    p = @(varargin) fprintf(f, varargin{:});
    p('# Kabul paketi – %s\n\n', m.paket);
    p('**Sonuç: %s**  \n', m.sonuc);
    p('Commit `%s` (dal `%s`) – çalışma alanı temiz: başta %s, sonda %s  \n', m.git.commit, m.git.dal, ...
      mat2str(m.git.temizBaslangic), mat2str(m.git.temizBitis));
    p('Oluşturma: %s – MATLAB %s  \n', m.olusturma, m.ortam.matlab);
    p('Bütün veriler Simulink simülasyonudur; gerçek sayaç veya kişisel veri yoktur.\n\n');
    p('## Testler (%d GEÇTİ, %d KALDI; 195 = %s)\n\n| Test | Sonuç |\n|---|---|\n', ...
      m.testler.toplamGecti, m.testler.toplamKaldi, m.testler.dagilim195);
    for g = m.testler.gruplar, p('| %s | %d GEÇTİ, %d KALDI |\n', g.ad, g.gecti, g.kaldi); end
    p('\nTam çıktı: `kabul_gunlugu.txt`; her testin tablosu: `testler/`.\n\n');
    p('## Contract 1.0 exportları\n\n| Tür | run_id | Satır | Olay | Kontroller |\n|---|---|---|---|---|\n');
    for e = m.exportlar
        p('| %s | %s | %d | %d | %s %s |\n', e.veriTuru, e.runId, e.satir, e.olay, ...
          secim(e.kontrollerGecti, 'geçti', 'KALDI'), e.gosteriKontrolleri);
    end
    p('\n## Röle adaptörü (gerçek modelde)\n\n| Saat | İstenen | status | code | Röle | Maske | Beklenen |\n|---|---|---|---|---|---|---|\n');
    for x = m.roleAdaptoru.komutlar
        p('| %s | %s | %s | %s | %g | %g | %s/%s %s |\n', x.saat, x.istenen, x.status, x.code, x.role, ...
          x.redMaske, x.beklenenStatus, x.beklenenCode, secim(x.gecti, '✓', '✗'));
    end
    p('\nKomut: `role_komut/islenen/`, cevap: `role_komut/giden/`, kanıt: `role_komut/kanit/` (commandId adlı).\n\n');
    p('## Doğrulama\n\n');
    p('- Kod ve model commit''teki hali mi: `git ls-tree -r %s simulink/` çıktısındaki blob kimlikleri `manifesto.json` → `kaynakDosyalar.gitBlob` ile aynı olmalı.\n', m.git.commit);
    p('- Dosyalar değişmedi mi: her dosyanın SHA-256''sı `manifesto.json` → `dosyalar` içinde (Windows: `certutil -hashfile <dosya> SHA256`).\n');
    fclose(f);
end

function v = jsonOku(f)
    if exist(f, 'file'), v = jsondecode(fileread(f, 'Encoding', 'UTF-8')); else, v = []; end
end

function v = alan(s, f)
    if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = NaN; end
end

function s = secim(kosul, a, b)
    if kosul, s = a; else, s = b; end
end
