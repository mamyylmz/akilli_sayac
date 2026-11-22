function sonuc = veri_aktar(varargin)
%VERI_AKTAR  Akıllı Sayaç modelini bir gün çalıştırır, sonuçları yazılım tarafı için
%   1 dakikalık CSV olarak yazar.
% Konum : Akilli_Sayac/simulink/veri_aktar.m
%
% Kullanım (simulink klasöründeyken, komut penceresine):
%   veri_aktar                              % bugünün tarihi, sayaç SIM-0001
%   veri_aktar('gun', '2026-11-26')         % başka bir tarih
%   veri_aktar('sayac_id', 'SIM-0002')      % başka bir sayaç kimliği
%   s = veri_aktar;                         % dosya yolları ve kontrol sonucu da döner (gosteri_gunu kullanır)
%
% ŞEMA SÜRÜMÜ 1.0: proje yöneticisinin 22.11.2026 kararlarıyla güncellendi.
% Ayrıntılı açıklama: veri_sozlesmesi.md
% Her çalıştırmanın benzersiz bir kimliği (run_id) vardır; ölçüm, olay ve meta dosyalarında aynıdır.
% Meta dosyasında iki CSV dosyasının SHA-256 özetleri bulunur.
%
% Model sonuçları ile test verileri ayrı tutulur (proje kararı):
%   - Komut penceresinde 'test_senaryo' YOKSA → normal gün     → ciktilar/model/
%   - 'test_senaryo' VARSA                    → test senaryosu → ciktilar/test/  (dosya adında _TEST)
%
% Çıktılar (gun = YYYY-AA-GG):
%   olcum_1dk_<gun>.csv   1440 satır; her satır bir dakikalık aralık
%   olaylar_<gun>.csv     koruma olay kaydı (normal günde boş olabilir)
%   meta_<gun>.json       şema sürümü, çalıştırma ayarları, günlük toplamlar, kontroller
%
% Bu betik hesap yapmaz, modelin ürettiği sinyalleri dakikalara böler
% (tarife dilimi ve röle komutu parametre dosyasındaki tablolardan okunur):
%   ortalama     : V, I, P, Q, S, cos φ, batarya gücü (zaman ağırlıklı)
%   aralık sonu  : kümülatif enerji sayaçları, röle, durum, SOC, batarya modu
%   aralık farkı : o dakikadaki enerji (enerji sayacının iki sınır arasındaki farkı)
% Para (TL) hesabı burada YAPILMAZ; yazılım katmanında yapılır (proje kararı).

%% Ayarlar
SEMA        = '1.0';
SAAT_DILIMI = '+03:00';          % Türkiye yıl boyu UTC+3 (yaz saati yok)
mdl         = 'Akilli_Sayac';

p = inputParser;
p.FunctionName = 'veri_aktar';
addParameter(p, 'gun', char(datetime('today', 'Format', 'yyyy-MM-dd')));
addParameter(p, 'sayac_id', 'SIM-0001');
parse(p, varargin{:});
gun     = char(p.Results.gun);
sayacId = char(p.Results.sayac_id);
if isempty(regexp(gun, '^\d{4}-\d{2}-\d{2}$', 'once'))
    error('gun "YYYY-AA-GG" biçiminde olmalı. Örnek: veri_aktar(''gun'', ''2026-11-26'')');
end
try
    datetime(gun, 'InputFormat', 'yyyy-MM-dd');
catch
    error('Geçersiz tarih: %s', gun);
end
if isempty(regexp(sayacId, '^[A-Za-z0-9_-]+$', 'once'))
    error('sayac_id yalnızca harf, rakam, - ve _ içerebilir.');
end

kok = fileparts(mfilename('fullpath'));
eskiDizin = pwd;
geriDon = onCleanup(@() cd(eskiDizin)); %#ok<NASGU>
cd(kok);

% Çalıştırma kimliği: sayaç + zaman + rastgele 8 karakter (tempname benzersiz bir ad üretir)
[~, tn] = fileparts(tempname);
runId = sprintf('%s-%s-%s', sayacId, char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss')), upper(tn(end-7:end)));

%% Model sonucu mu, test verisi mi?
senaryoVar = evalin('base', 'exist(''test_senaryo'', ''var'') == 1 && isstruct(test_senaryo)');
if senaryoVar
    veriTuru = 'test';
    senaryo  = evalin('base', 'test_senaryo');
    ek       = '_TEST';
    fprintf('UYARI: test_senaryo tanımlı (%s).\n', strjoin(fieldnames(senaryo)', ', '));
    fprintf('       Çıktı TEST verisi olarak ciktilar/test/ klasörüne yazılacak.\n');
else
    veriTuru = 'model';
    senaryo  = struct();
    ek       = '';
end
cikisDir = fullfile(kok, 'ciktilar', veriTuru);
if ~exist(cikisDir, 'dir'), mkdir(cikisDir); end

%% Kaydedilecek sinyaller: {blok adı, çıkış portu, kayıt adı}
% Tarife dilimi ve röle komutu parametre dosyasındaki tablolardan okunur; bunlar modeldeki
% Lookup (Gunduz_T1, Puant_T2, Gece_T3) ve Step (Kesme_Testi) bloklarının kullandığı değişkenlerin aynısıdır.
kayit = { 'RMS Measurement',    1, 'Vrms';
          'RMS Measurement1',   1, 'Irms';
          'Power Measurement',  1, 'P';
          'Power Measurement',  2, 'Q';
          'Gorunur_Guc',        1, 'S';
          'cos_phi_hesap',      1, 'cosphi';
          'Enerji_Sayaci',      1, 'E';
          'Sayac_T1',           1, 'ET1';
          'Sayac_T2',           1, 'ET2';
          'Sayac_T3',           1, 'ET3';
          'Sayac_Rend',         1, 'ERend';
          'Sayac_Rkap',         1, 'ERkap';
          'Koruma_Mantigi',     1, 'role';
          'Koruma_Mantigi',     2, 'durum';
          'Koruma_Mantigi',     3, 'uyari';
          'Koruma_Mantigi',     4, 'olay';
          'Koruma_Mantigi',     5, 'red';
          'Batarya_Mantigi',    1, 'Pbat';
          'Batarya_Mantigi',    2, 'SOC';
          'Batarya_Mantigi',    3, 'bmod' };

%% Modeli çalıştır
fprintf('Model çalışıyor (%s, %s verisi)...\n', mdl, veriTuru);
[logs, sure] = modeliCalistir(mdl, kayit);

uyarilar = {};   % beklenmeyen veri sorunları (kontrolü düşürür)
notlar   = {};   % bilinen, zararsız durumlar (bilgi)
S = struct();
for j = 1:size(kayit,1)
    ad = kayit{j,3};
    el = logs.getElement(ad);
    t  = el.Values.Time(:);
    x  = double(squeeze(el.Values.Data));  x = x(:);
    kotu = ~isfinite(x);
    if any(kotu)
        % RMS bloğu, sıfıra çok yakın bir değerin karekökünü alırken (kesinti, açık röle) sayısal
        % gürültüden dolayı NaN verebilir. Gerçek değer 0'dır. NaN'ın hemen yanındaki örnekler
        % sıfıra çok yakınsa bu bilinen durumdur (not); değilse veri sorunu sayılır (uyarı).
        iyi = find(~kotu);
        x(kotu) = 0;
        if numel(iyi) >= 2
            yakin = interp1(iyi, x(iyi), find(kotu), 'nearest', 'extrap');
            sifirda = all(abs(yakin) <= 1e-3 * max(abs(x(iyi))));
        else
            sifirda = false;
        end
        if sifirda
            notlar{end+1} = sprintf('%s: %d örnek NaN (sıfıra çok yakın değerin karekökü, ör. kesintide); 0 alındı', ad, nnz(kotu)); %#ok<AGROW>
        else
            uyarilar{end+1} = sprintf('%s: %d örnek sayısal değil (NaN/Inf), 0 alındı', ad, nnz(kotu)); %#ok<AGROW>
        end
    end
    S.(ad) = struct('t', t, 'x', x);
end

ayar = struct();
ayar.test_modu     = evalin('base', 'test_modu');
ayar.koruma_aktif  = evalin('base', 'koruma_aktif');
ayar.batarya_etkin = evalin('base', 'batarya_etkin');
ayar.P_sinir_W     = evalin('base', 'P_sinir');
ayar.P_geri_W      = evalin('base', 'P_geri');
ayar.t_stop_saat   = evalin('base', 't_stop');
if abs(ayar.t_stop_saat - 24) > 1e-9
    error('Veri aktarımı bir günlük çalıştırma içindir (t_stop = 24). Şu an t_stop = %g.', ayar.t_stop_saat);
end

%% Dakikalara böl (simülasyonda 1 s = 1 saat → 1 dakika = 1/60 s)
nDk   = 1440;
kenar = (0:nDk)' / 60;                     % aralık sınırları
orta  = (kenar(1:end-1) + kenar(2:end)) / 2;
son   = kenar(2:end) - 1e-6;               % aralık sonundan hemen önce (tam sınırdaki geçiş sonraki aralığa aittir)

V     = ortalama(S.Vrms,   kenar, 'dogrusal');
I     = ortalama(S.Irms,   kenar, 'dogrusal');
P     = ortalama(S.P,      kenar, 'dogrusal');
Q     = ortalama(S.Q,      kenar, 'dogrusal');
Sg    = ortalama(S.S,      kenar, 'dogrusal');
pf    = ortalama(S.cosphi, kenar, 'dogrusal');
Pbat  = ortalama(S.Pbat,   kenar, 'basamak');

Ek    = anlik(S.E, kenar, 'dogrusal');     % kümülatif enerji, aralık sınırlarında
eAr   = diff(Ek);
eTop  = Ek(2:end);
eT1   = anlik(S.ET1,   kenar(2:end), 'dogrusal');
eT2   = anlik(S.ET2,   kenar(2:end), 'dogrusal');
eT3   = anlik(S.ET3,   kenar(2:end), 'dogrusal');
eRe   = anlik(S.ERend, kenar(2:end), 'dogrusal');
eRk   = anlik(S.ERkap, kenar(2:end), 'dogrusal');

role  = round(anlik(S.role,  son, 'onceki'));   % koruma kararı; ana röle bunu 1 adım (1 ms) sonra uygular
durum = round(anlik(S.durum, son, 'onceki'));
soc   = anlik(S.SOC, son, 'onceki');
bmod  = round(anlik(S.bmod,  son, 'onceki'));
uyari = round(enBuyuk(S.uyari, kenar));

% Tarife dilimi: Gunduz_T1 / Puant_T2 / Gece_T3 Lookup bloklarıyla aynı tablo (T*_t, T*_u), aynı kural
% ("Flat": girişin altındaki en yakın kırılma noktasının değeri). Dakikanın ortasında okunur.
tb = evalin('base', '{T1_t, T1_u, T2_t, T2_u, T3_t, T3_u}');
m1 = interp1(tb{1}, tb{2}, orta, 'previous') > 0.5;
m2 = interp1(tb{3}, tb{4}, orta, 'previous') > 0.5;
m3 = interp1(tb{5}, tb{6}, orta, 'previous') > 0.5;
% Röle komutu: Kesme_Testi Step bloğu (t_kesme anına kadar 1, sonra 0)
t_kesme = evalin('base', 't_kesme');
komut   = double(son < t_kesme);
dilim    = 1*m1 + 2*m2 + 3*m3;
tekDilim = (m1 + m2 + m3) == 1;
% Geçerlilik: RMS ve güç ölçümü bir periyotluk pencereyle yapılır (1/f = 20 ms = 1,2 profil dk).
% Pencere dolmadan başlayan dakikalarda V, I, S eksik görünür → gecerli = 0.
f_sebeke = evalin('base', 'f');
gecerli  = double(kenar(1:end-1) >= 1/f_sebeke);

% Olaylar: olay sinyalinin sıfırdan farklı olduğu adımlar (test_D_koruma ile aynı yöntem)
i = find(S.olay.x ~= 0);
if ~isempty(i)
    tut = [true; diff(i) > 1 | diff(S.olay.x(i)) ~= 0];
    i = i(tut);
end
ot = S.olay.t(i);
oc = round(S.olay.x(i));
om = round(anlik(S.red,   ot, 'onceki'));
od = round(anlik(S.durum, ot, 'onceki'));
if isempty(ot)
    olaySay = zeros(nDk, 1);
else
    olaySay = accumarray(discretize(ot, kenar), 1, [nDk 1]);
end

%% Sütun tanımları (CSV başlığı ve meta dosyası buradan üretilir)
sutun = {
 'sayac_id',        '-',     'metin',        'Sayaç kimliği (simülasyon)';
 'run_id',          '-',     'metin',        'Simülasyon çalıştırmasının kimliği; ölçüm, olay ve meta dosyalarında aynıdır';
 'zaman',           '-',     'aralık başı',  'Aralığın başlangıcı, ISO 8601, yerel saat (+03:00); satır [zaman, zaman + 1 dk) aralığıdır';
 'dakika',          'dk',    'aralık başı',  'Gün içindeki dakika, 0-1439';
 'tarife_dilimi',   '-',     'aralık',       '1 gündüz (06-17), 2 puant (17-22), 3 gece (22-06)';
 'gecerli',         '-',     'aralık',       '1 = ölçüm geçerli; 0 = RMS ölçüm penceresi (1 periyot = 1,2 profil dk) henüz dolmamış (günün ilk 2 dakikası)';
 'v_rms_V',         'V',     'ortalama',     'Gerilim etkin değeri';
 'i_rms_A',         'A',     'ortalama',     'Akım etkin değeri';
 'p_W',             'W',     'ortalama',     'Sayaç noktasında şebekeden çekilen aktif güç (batarya dahil)';
 'q_var',           'var',   'ortalama',     'Reaktif güç (+ endüktif, - kapasitif)';
 's_VA',            'VA',    'ortalama',     'Görünür güç, S = V x I';
 'cos_phi',         '-',     'ortalama',     'Güç faktörü (modeldeki cos phi sinyalinin dakika ortalaması)';
 'e_aralik_kWh',    'kWh',   'aralık farkı', 'Bu dakikada çekilen aktif enerji';
 'e_toplam_kWh',    'kWh',   'aralık sonu',  'Gün başından beri toplam aktif enerji';
 'e_t1_kWh',        'kWh',   'aralık sonu',  'T1 gündüz sayacı (kümülatif)';
 'e_t2_kWh',        'kWh',   'aralık sonu',  'T2 puant sayacı (kümülatif)';
 'e_t3_kWh',        'kWh',   'aralık sonu',  'T3 gece sayacı (kümülatif)';
 'e_rend_kvarh',    'kvarh', 'aralık sonu',  'Endüktif reaktif enerji (kümülatif)';
 'e_rkap_kvarh',    'kvarh', 'aralık sonu',  'Kapasitif reaktif enerji (kümülatif)';
 'role_komut',      '-',     'aralık sonu',  'Kullanıcı / uzaktan röle komutu: 1 enerji ver, 0 kes';
 'role',            '-',     'aralık sonu',  'Ana röle: 1 kapalı (enerji var), 0 açık';
 'durum',           '-',     'aralık sonu',  '0 normal, 1 uyarı, 2 kesildi-onay bekliyor, 3 kullanıcı kesti, 4 şebeke yok, 5 gerilim aralık dışı';
 'asiri_guc_uyari', '-',     'en büyük',     '1 = dakika içinde aşırı güç uyarısı vardı';
 'olay_sayisi',     'adet',  'toplam',       'Dakika içindeki olay sayısı (ayrıntı olaylar dosyasında)';
 'p_bat_W',         'W',     'ortalama',     'Batarya gücü: + evi besliyor (deşarj), - şarj oluyor';
 'soc',             '-',     'aralık sonu',  'Batarya doluluğu, 0-1';
 'batarya_mod',     '-',     'aralık sonu',  '0 bekleme, 1 şarj, 2 deşarj' };
satirBicim = ['%s,%s,%s,%d,%d,%d,%.3f,%.4f,%.2f,%.2f,%.2f,%.4f,' ...
              '%.7f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,' ...
              '%d,%d,%d,%d,%d,%.2f,%.4f,%d\n'];

%% Ölçüm dosyası
olcumAd = sprintf('olcum_1dk_%s%s.csv', gun, ek);
fid = fopen(fullfile(cikisDir, olcumAd), 'w', 'n', 'UTF-8');
if fid < 0, error('Dosya açılamadı: %s (Excel''de açıksa kapatın)', olcumAd); end
fprintf(fid, '%s\n', strjoin(sutun(:,1)', ','));
for k = 1:nDk
    hh = floor((k-1)/60);  mm = mod(k-1, 60);
    zaman = sprintf('%sT%02d:%02d:00%s', gun, hh, mm, SAAT_DILIMI);
    fprintf(fid, satirBicim, sayacId, runId, zaman, k-1, dilim(k), gecerli(k), ...
        yuvarla(V(k),3), yuvarla(I(k),4), yuvarla(P(k),2), yuvarla(Q(k),2), yuvarla(Sg(k),2), yuvarla(pf(k),4), ...
        yuvarla(eAr(k),7), yuvarla(eTop(k),6), yuvarla(eT1(k),6), yuvarla(eT2(k),6), yuvarla(eT3(k),6), ...
        yuvarla(eRe(k),6), yuvarla(eRk(k),6), ...
        komut(k), role(k), durum(k), uyari(k), olaySay(k), yuvarla(Pbat(k),2), yuvarla(soc(k),4), bmod(k));
end
fclose(fid);

%% Olay dosyası
olayAd = sprintf('olaylar_%s%s.csv', gun, ek);
fid = fopen(fullfile(cikisDir, olayAd), 'w', 'n', 'UTF-8');
if fid < 0, error('Dosya açılamadı: %s (Excel''de açıksa kapatın)', olayAd); end
fprintf(fid, 'sayac_id,run_id,zaman,saat,olay_kodu,olay,durum,red_maske,red_nedeni\n');
for j = 1:numel(ot)
    sn = min(floor(ot(j)*3600), 86399);                        % gün içindeki saniye
    zaman = sprintf('%sT%02d:%02d:%02d%s', gun, floor(sn/3600), floor(mod(sn,3600)/60), mod(sn,60), SAAT_DILIMI);
    fprintf(fid, '%s,%s,%s,%.6f,%d,"%s",%d,%d,"%s"\n', sayacId, runId, zaman, ot(j), oc(j), olayAdi(oc(j)), od(j), om(j), redYaz(om(j)));
end
fclose(fid);

% Dosya özetleri (SHA-256): yazılım, dosyaların bozulmadan ve aynı çalıştırmadan geldiğini doğrular
hOlcum = sha256_dosya(fullfile(cikisDir, olcumAd));
hOlay  = sha256_dosya(fullfile(cikisDir, olayAd));

%% Kontroller (yuvarlanmamış değerlerle)
K = cell(0, 3);
K(end+1,:) = {'Satır sayısı 1440', numel(eAr) == nDk, sprintf('%d', numel(eAr))};
d = abs(sum(eAr) - eTop(end));
K(end+1,:) = {'Dakika enerjilerinin toplamı = gün sonu toplamı', d < 1e-9, sprintf('fark %.2e kWh', d)};
d = abs(eT1(end) + eT2(end) + eT3(end) - eTop(end));
K(end+1,:) = {'T1 + T2 + T3 = toplam', d < 1e-4, sprintf('fark %.2e kWh', d)};
d = max(abs([sum(eAr(dilim==1)) - eT1(end), sum(eAr(dilim==2)) - eT2(end), sum(eAr(dilim==3)) - eT3(end)]));
% Dilim geçişinde (06, 17, 22) sayaç en fazla bir çözücü adımı (≤ 1e-4 s = 0,36 profil s) kayabilir:
% 5000 W × 1e-4 saat = 5e-4 kWh / geçiş; bir dilimin iki geçişi → tolerans 1e-3 kWh.
K(end+1,:) = {'Dilim bazında dakika enerjileri = T1/T2/T3 sayaçları', d < 1e-3, sprintf('en büyük fark %.2e kWh', d)};
ePort = sum(P) / 60 / 1000;                                    % W·(1/60 saat) → kWh
d = abs(ePort - eTop(end)) / max(eTop(end), eps);
K(end+1,:) = {'Ortalama güçten enerji = sayaç enerjisi', d < 1e-3, sprintf('bağıl fark %.2e', d)};
K(end+1,:) = {'Her dakikada tek tarife dilimi', all(tekDilim), sprintf('%d dakika sorunlu', nnz(~tekDilim))};
K(end+1,:) = {'Beklenmeyen sayısal olmayan değer yok', isempty(uyarilar), sprintf('%d sinyalde sorun, %d bilinen durum', numel(uyarilar), numel(notlar))};
K(end+1,:) = {'SHA-256 özetleri hesaplandı', ~isempty(hOlcum) && ~isempty(hOlay), sprintf('%s...', hOlcum(1:min(12,end)))};
nGec = nnz([K{:,2}]);

%% Meta dosyası
meta = struct();
meta.sema_surumu         = SEMA;
meta.run_id              = runId;
meta.veri_turu           = veriTuru;
meta.kaynak              = 'Simulink simülasyonu (Akilli_Sayac.slx); gerçek sayaç verisi değildir';
meta.sayac_id            = sayacId;
meta.gun                 = gun;
meta.saat_dilimi         = SAAT_DILIMI;
meta.aralik_dk           = 1;
meta.satir_sayisi        = nDk;
meta.olay_sayisi         = numel(ot);
meta.olusturma_zamani    = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
meta.matlab_surumu       = version;
meta.calistirma_suresi_s = round(sure, 1);
meta.ayarlar             = ayar;
meta.test_senaryosu      = senaryo;
meta.gunluk_toplam       = struct('e_toplam_kWh', eTop(end), 'e_t1_kWh', eT1(end), 'e_t2_kWh', eT2(end), ...
                                  'e_t3_kWh', eT3(end), 'e_rend_kvarh', eRe(end), 'e_rkap_kvarh', eRk(end));
meta.dakika_sayisi_dilim = struct('t1', nnz(dilim==1), 't2', nnz(dilim==2), 't3', nnz(dilim==3));
meta.gecersiz_dakika     = nnz(gecerli == 0);
meta.dosyalar            = struct('olcum', olcumAd, 'olcum_sha256', hOlcum, ...
                                  'olaylar', olayAd, 'olaylar_sha256', hOlay);
meta.sutunlar            = cell2struct(sutun, {'ad', 'birim', 'deger', 'aciklama'}, 2);
meta.kontroller          = cell2struct(K, {'kontrol', 'gecti', 'deger'}, 2);
meta.uyarilar            = uyarilar;
meta.notlar              = notlar;
metaAd = sprintf('meta_%s%s.json', gun, ek);
fid = fopen(fullfile(cikisDir, metaAd), 'w', 'n', 'UTF-8');
if fid < 0, error('Dosya açılamadı: %s', metaAd); end
fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true));
fclose(fid);

%% Özet
fprintf('\nVERİ AKTARIMI — %s verisi — gün %s — sayaç %s — şema %s\n', veriTuru, gun, sayacId, SEMA);
fprintf('  run_id: %s\n', runId);
fprintf('  Toplam %.4f kWh | T1 %.4f | T2 %.4f | T3 %.4f\n', eTop(end), eT1(end), eT2(end), eT3(end));
fprintf('  Olay sayısı: %d\n', numel(ot));
for k = 1:size(K,1)
    if K{k,2}, s = 'GEÇTİ'; else, s = 'KALDI'; end
    fprintf('  [%s] %s (%s)\n', s, K{k,1}, K{k,3});
end
for k = 1:numel(uyarilar), fprintf('  UYARI: %s\n', uyarilar{k}); end
for k = 1:numel(notlar),   fprintf('  Not: %s\n', notlar{k}); end
fprintf('  Kontroller: %d/%d geçti\n', nGec, size(K,1));
fprintf('  Dosyalar: ciktilar/%s/%s, %s, %s\n', veriTuru, olcumAd, olayAd, metaAd);
if senaryoVar
    fprintf('  HATIRLATMA: test_senaryo hâlâ tanımlı. Normal güne dönmek için:  clear test_senaryo\n');
end
if nargout > 0
    sonuc = struct('veri_turu', veriTuru, 'klasor', cikisDir, ...
                   'olcum', fullfile(cikisDir, olcumAd), 'olaylar', fullfile(cikisDir, olayAd), ...
                   'meta', fullfile(cikisDir, metaAd), ...
                   'kontroller_gecti', nGec == size(K,1), 'olay_sayisi', numel(ot), ...
                   'run_id', runId, 'olcum_sha256', hOlcum, 'olaylar_sha256', hOlay);
end
end

%% ---------------- yardımcı fonksiyonlar ----------------
function m = ortalama(s, kenar, yontem)
    % Her [kenar(k), kenar(k+1)) aralığında zaman ağırlıklı ortalama.
    % 'dogrusal': örnekler arası doğrusal (yamuk kuralı); 'basamak': ayrık sinyal, sıfır dereceli tutma.
    t = s.t;  x = s.x;
    if numel(t) < 2, m = repmat(x(end), numel(kenar)-1, 1); return; end
    dt = diff(t);
    switch yontem
        case 'dogrusal', alan = dt .* (x(1:end-1) + x(2:end)) / 2;
        case 'basamak',  alan = dt .* x(1:end-1);
        otherwise,       error('Bilinmeyen yöntem: %s', yontem);
    end
    alanTop = [0; cumsum(alan)];
    [tu, iu] = unique(t, 'last');
    Ik = interp1(tu, alanTop(iu), min(max(kenar, tu(1)), tu(end)), 'linear');
    m = diff(Ik) ./ diff(kenar);
end

function v = anlik(s, tq, yontem)
    % Sinyalin tq anlarındaki değeri. 'onceki': o andaki ya da hemen önceki örnek.
    tq = tq(:);
    if isempty(tq), v = zeros(0, 1); return; end
    [tu, iu] = unique(s.t, 'last');
    xu = s.x(iu);
    if numel(tu) < 2, v = repmat(xu(end), size(tq)); return; end
    tq = min(max(tq, tu(1)), tu(end));
    switch yontem
        case 'dogrusal', v = interp1(tu, xu, tq, 'linear');
        case 'onceki',   v = interp1(tu, xu, tq, 'previous');
        otherwise,       error('Bilinmeyen yöntem: %s', yontem);
    end
end

function m = enBuyuk(s, kenar)
    % Her aralıktaki en büyük değer (aralıkta örnek yoksa 0).
    b  = discretize(s.t, kenar);
    ok = ~isnan(b);
    m  = accumarray(b(ok), s.x(ok), [numel(kenar)-1 1], @max, 0);
end

function y = yuvarla(x, n)
    y = round(x, n) + 0;                   % + 0: "-0.00" yazılmasın
end

function s = olayAdi(kod)
    switch kod
        case 10, s = 'Aşırı güç uyarısı başladı';
        case 11, s = 'Aşırı güç uyarısı bitti';
        case 20, s = 'Aşırı güç kesmesi (röle açıldı, kilit)';
        case 30, s = 'Yeniden bağlantı KABUL';
        case 31, s = 'Yeniden bağlantı RED';
        case 40, s = 'Şebeke kesildi';
        case 41, s = 'Şebeke geri geldi';
        case 42, s = 'Gerilim 207-253 V aralığı dışına çıktı';
        case 43, s = 'Gerilim aralığa döndü';
        case 50, s = 'Kullanıcı kesti';
        case 51, s = 'Kullanıcı açtı';
        otherwise, s = sprintf('Kod %d', kod);
    end
end

function s = redYaz(m)
    if m == 0, s = ''; return; end
    p = {};
    if bitand(m,1), p{end+1} = 'bekleme süresi dolmadı'; end
    if bitand(m,2), p{end+1} = 'tahmini yük > P_geri'; end
    if bitand(m,4), p{end+1} = 'gerilim aralık dışı / kararsız'; end
    if bitand(m,8), p{end+1} = 'şebeke yok'; end
    s = strjoin(p, '; ');
end

function [logs, sure] = modeliCalistir(mdl, kayit)
    % test_* betiklerindeki ile aynı: kaydı geçici açar, çalıştırır, model ayarlarını geri yükler.
    acikti = bdIsLoaded(mdl);
    if acikti && strcmp(get_param(mdl, 'Dirty'), 'on')
        error('"%s" açık ve kaydedilmemiş değişiklik var. Önce Ctrl+S ile kaydedip tekrar çalıştırın.', mdl);
    end
    load_system(mdl);
    % MATLAB Function bloklarının içindeki çağrı satırı yerinde mi? (20.11.2026: Batarya_Mantigi
    % bloğunun 2. satırı yanlışlıkla silinmişti; hata mesajı yanıltıcıydı.)
    beklenen = {'Batarya_Mantigi', 'batarya_mantigi(u, par)';  'Koruma_Mantigi', 'koruma_mantigi(u, par)'};
    for k = 1:size(beklenen,1)
        rt = sfroot;
        ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [mdl '/' beklenen{k,1}]);
        if isempty(ch) || ~contains(ch.Script, beklenen{k,2})
            error(['"%s" bloğunun kodunda "%s" satırı yok. Bloğa çift tıklayıp kodu kontrol edin;\n' ...
                   'iki satır olmalı: function [...] = fcn(u, par)  ve  [...] = %s;'], ...
                   beklenen{k,1}, beklenen{k,2}, beklenen{k,2});
        end
    end
    for k = 1:size(kayit,1)
        if getSimulinkBlockHandle([mdl '/' kayit{k,1}]) == -1
            error('Blok bulunamadı: "%s/%s". Modeldeki blok adını kontrol edin.', mdl, kayit{k,1});
        end
    end
    eskiLog = get_param(mdl, 'SignalLogging');
    set_param(mdl, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');
    try, eskiPace = get_param(mdl, 'EnablePacing'); set_param(mdl, 'EnablePacing', 'off'); catch, eskiPace = ''; end
    eski = cell(size(kayit,1), 3);
    for k = 1:size(kayit,1)
        ph = get_param([mdl '/' kayit{k,1}], 'PortHandles');  p = ph.Outport(kayit{k,2});
        eski(k,:) = {get_param(p,'DataLogging'), get_param(p,'DataLoggingNameMode'), get_param(p,'DataLoggingName')};
        set_param(p, 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', kayit{k,3});
    end
    hata = [];  logs = [];  sure = NaN;
    try
        tic;  out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');  sure = toc;
        logs = out.logsout;
    catch hata
    end
    for k = size(kayit,1):-1:1             % ters sıra: aynı porta iki kayıt varsa ilk ayar geri gelsin
        ph = get_param([mdl '/' kayit{k,1}], 'PortHandles');  p = ph.Outport(kayit{k,2});
        set_param(p, 'DataLogging', eski{k,1}, 'DataLoggingNameMode', eski{k,2}, 'DataLoggingName', eski{k,3});
    end
    set_param(mdl, 'SignalLogging', eskiLog);
    if ~isempty(eskiPace), set_param(mdl, 'EnablePacing', eskiPace); end
    dosya = get_param(mdl, 'FileName');
    if acikti, set_param(mdl, 'Dirty', 'off'); else, close_system(mdl, 0); end
    asv = [dosya '.autosave'];
    if exist(asv, 'file'), delete(asv); end
    if ~isempty(hata), rethrow(hata); end
end
