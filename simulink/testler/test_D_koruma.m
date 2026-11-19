%% D AŞAMASI KORUMA TESTLERİ – Akıllı Sayaç
% Konum : Akilli_Sayac/simulink/testler/test_D_koruma.m
% Çalıştırma: Current Folder'ı "testler" yapın ve  test_D_koruma  yazın (~2 dk).
%
% Koruma 'normal' modda (AKTİF) altı senaryoda test edilir:
%   S1 Normal çalışma           – su ısıtıcı 17:00'ye alınır, aşım yok
%   S2 Kısa süreli aşım         – su ısıtıcı ile fırın yalnızca 2 dk çakışır
%   S3 Kalıcı aşım              – referans gün (18:00–18:10 çakışma), bağlanma isteği YOK
%   S4 Güvenli yeniden bağlantı – S3 + 18:15'te yetkili istek
%   S5 Reddedilen bağlantı      – S3 + 18:06'da istek (bekleme dolmadı, yük yüksek)
%   S6 Gerilim arızasında red   – S4 + 18:12–18:20 arası şebeke 190 V
% Eşikler ve zamanlar akilli_sayac_param.m dosyasındadır (P_sinir, P_geri, t_uyari,
% t_asim, t_bekle, V_min, V_max, t_kararli). Beklenen değerler: testler/teorik_hesaplar.md §13
%
% Çıktılar (testler/ klasörüne):
%   test_D_sonuclari.md / .xlsx   – beklenen / gerçekleşen / sonuç
%   olay_kayitlari.md             – her senaryonun olay kaydı (zaman, olay, neden, P, V)
% Model KAYDEDİLMEZ.

clear;   % (clc yok: arka arkaya çalışan testlerin çıktısı silinmesin)
testDir = fileparts(mfilename('fullpath'));
kokDir  = fileparts(testDir);
cd(kokDir);
mdl = 'Akilli_Sayac';
akilli_sayac_param;                                   % normal değerler (dk, P_sinir ...)

TS = cell(0,10);
OL = cell(0,8);   % {Senaryo, Saat, Olay kodu, Olay, Red nedeni, P_ölçülen (W), P_tahmin (W), V (V)}

kayit = { 'RMS Measurement',    1, 'Vrms';
          'RMS Measurement1',   1, 'Irms';
          'Power Measurement',  1, 'P';
          'Enerji_Sayaci',      1, 'E';
          'Yuk_Tahmini',        1, 'Ptah';
          'Koruma_Mantigi',     1, 'role';
          'Koruma_Mantigi',     2, 'durum';
          'Koruma_Mantigi',     3, 'uyari';
          'Koruma_Mantigi',     4, 'olay';
          'Koruma_Mantigi',     5, 'red' };

ref_kettle_t = [0 7 7+10*dk 18 18+10*dk 25];  ref_kettle_u = [0 1 0 1 0 0];
istek = @(saat) deal([0 saat saat+dk 25], [0 1 0 0]);    % tek darbelik yetkili istek

%% Senaryo tanımları
S = struct('ad', {}, 'sen', {});
s = struct('test_modu', 'normal');
s1 = s;  s1.kettle_t = [0 7 7+10*dk 17 17+10*dk 25];  s1.kettle_u = ref_kettle_u;
s2 = s;  s2.kettle_t = [0 7 7+10*dk 18 18+2*dk 25];   s2.kettle_u = ref_kettle_u;
s3 = s;  % referans gün, istek yok
s4 = s;  [s4.baglan_t, s4.baglan_u] = istek(18 + 15*dk);
s5 = s;  [s5.baglan_t, s5.baglan_u] = istek(18 + 6*dk);
s6 = s4; s6.sebeke_t = [0 18+12*dk 18+20*dk 25];  s6.sebeke_V = [230 190 230 230];
S(1).ad = 'S1 Normal çalışma';            S(1).sen = s1;
S(2).ad = 'S2 Kısa süreli aşım';          S(2).sen = s2;
S(3).ad = 'S3 Kalıcı aşım';               S(3).sen = s3;
S(4).ad = 'S4 Güvenli yeniden bağlantı';  S(4).sen = s4;
S(5).ad = 'S5 Reddedilen bağlantı';       S(5).sen = s5;
S(6).ad = 'S6 Gerilim arızasında red';    S(6).sen = s6;

t_kesme_bek = 18 + 4.1*dk;     % beklenen kesme anı (aşım ~18:01,0 + 3 dk + örnekleme)
sure = zeros(1, numel(S));

for k = 1:numel(S)
    fprintf('%s çalışıyor...\n', S(k).ad);
    [logs, sure(k)] = modeliCalistir(mdl, kayit, S(k).sen);
    SN = struct();
    for j = 1:size(kayit,1)
        [SN.(['t_' kayit{j,3}]), SN.(kayit{j,3})] = sinyalAl(logs, kayit{j,3});
    end
    id = sprintf('S%d', k);
    [ot, oc, om] = olaylar(SN);                      % olay zamanı, kodu, red maskesi
    for j = 1:numel(ot)
        OL(end+1,:) = {S(k).ad, saatYaz(ot(j)), oc(j), olayAdi(oc(j)), redYaz(om(j)), ...
                       degerAn(SN.t_P,SN.P,ot(j)), degerAn(SN.t_Ptah,SN.Ptah,ot(j)), degerAn(SN.t_Vrms,SN.Vrms,ot(j))}; %#ok<SAGROW>
    end
    n = @(kod) sum(oc == kod);
    tk = ot(oc == 20);   tb = ot(oc == 30 | oc == 31);

    switch k
        case 1  % Normal çalışma
            TS = kSayi(TS, id, 'Uyarı sayısı', 'adet', 0, n(10), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Kesme sayısı', 'adet', 0, n(20), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Röle gün boyu kapalı (en küçük role)', '-', 1, min(SN.role), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Gün boyu P < P_sinir (1 = evet)', '-', 1, double(max(SN.P(SN.t_P > 0.1)) < P_sinir), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Günlük enerji (referans günle aynı)', 'kWh', 14.56, SN.E(end), 0.01, 'Bağıl');
            TS = kSayi(TS, id, 'Durum kodu 23:30 (0 = normal)', '-', 0, degerAn(SN.t_durum,SN.durum,23.5), 0, 'Mutlak');
        case 2  % Kısa süreli aşım
            TS = kSayi(TS, id, 'Uyarı sayısı', 'adet', 1, n(10), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Uyarı başlama anı (saat)', 'saat', 18+2*dk, ilk(ot(oc==10)), 0.2*dk, 'Mutlak');
            TS = kSayi(TS, id, 'Kesme sayısı (aşım < t_asim)', 'adet', 0, n(20), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Röle gün boyu kapalı (en küçük role)', '-', 1, min(SN.role), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Aşım sırasında en büyük P (sınır aşıldı mı)', 'W', 4544, max(SN.P(SN.t_P > 18 & SN.t_P < 18+3*dk)), 0.02, 'Bağıl');
        case 3  % Kalıcı aşım, istek yok
            TS = kSayi(TS, id, 'Kesme sayısı', 'adet', 1, n(20), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Kesme anı (saat)', 'saat', t_kesme_bek, ilk(tk), 0.25*dk, 'Mutlak');
            TS = kSayi(TS, id, 'Kesmeden 10 dk sonra I_rms (yük gerçekten kesildi)', 'A', 0, degerAn(SN.t_Irms,SN.Irms,18+15*dk), 0.01, 'Mutlak');
            TS = kSayi(TS, id, 'Kesmeden 10 dk sonra P', 'W', 0, degerAn(SN.t_P,SN.P,18+15*dk), 1, 'Mutlak');
            TS = kSayi(TS, id, 'Röle açıkken V_rms (şebeke var)', 'V', 230, degerAn(SN.t_Vrms,SN.Vrms,18+15*dk), 0.005, 'Bağıl');
            TS = kSayi(TS, id, 'Onaysız yeniden bağlantı sayısı', 'adet', 0, n(30), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Gün sonunda röle (0 = açık, onay bekliyor)', '-', 0, SN.role(end), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Durum kodu 23:30 (2 = aşırı güç kilidi)', '-', 2, degerAn(SN.t_durum,SN.durum,23.5), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Kesmeden sonra enerji artışı 18:10–24:00 (durmalı)', 'kWh', 0, SN.E(end)-degerAn(SN.t_E,SN.E,18+10*dk), 1e-4, 'Mutlak');
        case 4  % Güvenli yeniden bağlantı
            TS = kSayi(TS, id, 'Kesme sayısı', 'adet', 1, n(20), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Bağlantı KABUL sayısı', 'adet', 1, n(30), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Bağlantı kabul anı (saat)', 'saat', 18+15*dk, ilk(ot(oc==30)), 0.1*dk, 'Mutlak');
            TS = kSayi(TS, id, 'Bağlantı anında tahmini yük (≤ P_geri)', 'W', 2550, degerAn(SN.t_Ptah,SN.Ptah,18+15*dk), 0.001, 'Bağıl');
            TS = kSayi(TS, id, 'Bağlantıdan sonra P 18:30 (fırın + baz)', 'W', 2547, degerAn(SN.t_P,SN.P,18.5), 0.02, 'Bağıl');
            TS = kSayi(TS, id, 'Gün sonunda röle (1 = kapalı)', '-', 1, SN.role(end), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Durum kodu 23:30 (0 = normal)', '-', 0, degerAn(SN.t_durum,SN.durum,23.5), 0, 'Mutlak');
        case 5  % Reddedilen bağlantı
            TS = kSayi(TS, id, 'Bağlantı RED sayısı', 'adet', 1, n(31), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Red anı (saat)', 'saat', 18+6*dk, ilk(tb), 0.1*dk, 'Mutlak');
            TS = kSayi(TS, id, 'Red nedeni maskesi (1 bekleme + 2 yük = 3)', '-', 3, ilk(om(oc==31)), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Bağlantı KABUL sayısı', 'adet', 0, n(30), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Koşullar sonradan sağlansa da röle açık (18:30)', '-', 0, degerAn(SN.t_role,SN.role,18.5), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Gün sonunda röle (0 = açık)', '-', 0, SN.role(end), 0, 'Mutlak');
        case 6  % Gerilim arızasında red
            TS = kSayi(TS, id, 'Bağlantı anında V_rms (aralık dışı)', 'V', 190, degerAn(SN.t_Vrms,SN.Vrms,18+15*dk), 0.01, 'Bağıl');
            TS = kSayi(TS, id, 'Durum kodu 18:16 (5 = gerilim aralık dışı)', '-', 5, degerAn(SN.t_durum,SN.durum,18+16*dk), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Gerilim aralık dışı olayı (42) sayısı', 'adet', 1, n(42), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Bağlantı RED sayısı', 'adet', 1, n(31), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Red nedeni maskesi (4 = gerilim)', '-', 4, ilk(om(oc==31)), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Gerilim düzeldikten sonra röle (18:30, 0 = açık)', '-', 0, degerAn(SN.t_role,SN.role,18.5), 0, 'Mutlak');
    end
end
akilli_sayac_param;   % çalışma alanını normal değerlere döndür

%% Rapor
ng = sum(strcmp(TS(:,10),'GEÇTİ')); nk = sum(strcmp(TS(:,10),'KALDI'));
fprintf('\nD AŞAMASI KORUMA TESTLERİ — %s — MATLAB %s\n', char(datetime('now')), version);
fprintf('%-4s %-62s %-5s %12s %12s %10s  %s\n', 'Sen.','Kontrol','Birim','Beklenen','Gerçekleşen','Hata','Sonuç');
for i = 1:size(TS,1)
    fprintf('%-4s %-62s %-5s %12.6g %12.6g %10s  %s\n', TS{i,1}, TS{i,2}, TS{i,3}, TS{i,4}, TS{i,5}, hataYaz(TS{i,7}, TS{i,6}), TS{i,10});
end
fprintf('\nÖZET: %d GEÇTİ, %d KALDI\n', ng, nk);

T = cell2table(TS, 'VariableNames', {'Senaryo','Kontrol','Birim','Beklenen','Gerceklesen','Fark', ...
                                     'Bagil_hata','Tolerans_turu','Tolerans','Sonuc'});
writetable(T, fullfile(testDir,'test_D_sonuclari.xlsx'), 'Sheet', 'Sonuclar', 'WriteMode', 'replacefile');
TO = cell2table(OL, 'VariableNames', {'Senaryo','Saat','Kod','Olay','Red_nedeni','P_olculen_W','P_tahmin_W','V_rms_V'});
writetable(TO, fullfile(testDir,'test_D_sonuclari.xlsx'), 'Sheet', 'Olay_kayitlari');

fid = fopen(fullfile(testDir,'test_D_sonuclari.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Akıllı Sayaç – D Aşaması Koruma Testleri\n\n');
fprintf(fid, '- Tarih: %s\n- MATLAB: %s\n- Model: %s.slx, çalışma modu: normal (koruma aktif)\n', char(datetime('now')), version, mdl);
fprintf(fid, '- Parametreler: P_sinir = %g W, P_geri = %g W, t_uyari = %g dk, t_asim = %g dk, t_bekle = %g dk, V = %g–%g V, t_kararli = %g ms (%g periyot)\n', ...
        P_sinir, P_geri, t_uyari/dk, t_asim/dk, t_bekle/dk, V_min, V_max, 1000*t_kararli, t_kararli*f);
fprintf(fid, '- Zaman ölçeği: profil 1 s = 1 saat (1 dk = %.1f ms sim); fiziksel 1 periyot = 20 ms sim = 1,2 profil dk\n', 1000*dk);
fprintf(fid, '- Özet: **%d GEÇTİ, %d KALDI**\n\n', ng, nk);
fprintf(fid, '| Senaryo | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |\n|---|---|---|---|---|---|---|---|\n');
for i = 1:size(TS,1)
    fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s |\n', TS{i,1}, TS{i,2}, TS{i,3}, sayiYaz(TS{i,4}), sayiYaz(TS{i,5}), ...
            hataYaz(TS{i,7}, TS{i,6}), tolYaz(TS{i,8}, TS{i,9}), TS{i,10});
end
fprintf(fid, '\nNot: "saat" birimindeki değerler profil saatidir (18.0683 = 18:04,1).\n');
fclose(fid);

fid = fopen(fullfile(testDir,'olay_kayitlari.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Olay Kayıtları – D Aşaması Senaryoları\n\n%s\n\n', char(datetime('now')));
fprintf(fid, '| Senaryo | Saat | Kod | Olay | Red nedeni | P ölçülen (W) | P tahmin (W) | V (V) |\n|---|---|---|---|---|---|---|---|\n');
for i = 1:size(OL,1)
    fprintf(fid, '| %s | %s | %d | %s | %s | %.0f | %.0f | %.1f |\n', OL{i,:});
end
fclose(fid);
fprintf('Sonuçlar: testler/test_D_sonuclari.md, testler/test_D_sonuclari.xlsx, testler/olay_kayitlari.md\n');

%% ---------------- yardımcı fonksiyonlar ----------------
function [ot, oc, om] = olaylar(SN)
    i = find(SN.olay ~= 0);
    if ~isempty(i)                                   % aynı olayın ardışık tekrarlarını ayıkla
        tut = [true; diff(i) > 1 | diff(SN.olay(i)) ~= 0];
        i = i(tut);
    end
    ot = SN.t_olay(i);  oc = SN.olay(i);
    om = zeros(size(i));
    for j = 1:numel(i), om(j) = degerAn(SN.t_red, SN.red, ot(j)); end
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
        case 42, s = 'Gerilim 207–253 V aralığı dışına çıktı';
        case 43, s = 'Gerilim aralığa döndü';
        case 50, s = 'Kullanıcı kesti';
        case 51, s = 'Kullanıcı açtı';
        otherwise, s = sprintf('Kod %d', kod);
    end
end

function s = redYaz(m)
    if m == 0, s = '-'; return; end
    p = {};
    if bitand(m,1), p{end+1} = 'bekleme süresi dolmadı'; end
    if bitand(m,2), p{end+1} = 'tahmini yük > P_geri'; end
    if bitand(m,4), p{end+1} = 'gerilim aralık dışı / kararsız'; end
    if bitand(m,8), p{end+1} = 'şebeke yok'; end
    s = sprintf('%d: %s', m, strjoin(p, ', '));
end

function v = ilk(x)
    if isempty(x), v = NaN; else, v = x(1); end
end

function [logs, sure] = modeliCalistir(mdl, kayit, senaryo)
    acikti = bdIsLoaded(mdl);
    if acikti && strcmp(get_param(mdl, 'Dirty'), 'on')
        error('"%s" açık ve kaydedilmemiş değişiklik var. Önce Ctrl+S ile kaydedip betiği tekrar çalıştırın.', mdl);
    end
    load_system(mdl);
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
    if ~isempty(senaryo), assignin('base', 'test_senaryo', senaryo); end
    hata = [];  logs = [];  sure = NaN;
    try
        tic;  out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');  sure = toc;
        logs = out.logsout;
    catch hata
    end
    evalin('base', 'clear test_senaryo');
    for k = 1:size(kayit,1)
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

function TS = kSayi(TS, id, ad, birim, bek, olc, tol, tip)
    fark = olc - bek;
    if strcmp(tip, 'Bağıl')
        bh = abs(fark) / max(abs(bek), eps);  gecti = bh <= tol;
    else
        bh = NaN;                              gecti = abs(fark) <= tol;
    end
    if isnan(olc), gecti = false; end
    TS(end+1,:) = {id, ad, birim, bek, olc, fark, bh, tip, tol, secim(gecti, 'GEÇTİ', 'KALDI')};
end

function s = sayiYaz(x)
    if isnan(x), s = '-'; else, s = sprintf('%.6g', x); end
end

function s = hataYaz(bh, fark)
    if ~isnan(bh), s = sprintf('%%%.3f', 100*bh);
    elseif ~isnan(fark), s = sprintf('%.3g', fark);
    else, s = '-'; end
end

function s = tolYaz(tip, tol)
    if isnan(tol), s = '-';
    elseif strcmp(tip, 'Bağıl'), s = sprintf('%%%g', 100*tol);
    else, s = sprintf('±%g', tol); end
end

function s = secim(kosul, a, b)
    if kosul, s = a; else, s = b; end
end

function [t, d] = sinyalAl(logs, ad)
    ts = logs.getElement(ad).Values;
    t = ts.Time;  d = squeeze(ts.Data);
end

function v = degerAn(t, d, tq)
    v = d(find(t <= tq, 1, 'last'));
end

function s = saatYaz(x)
    h = floor(x);  m = (x - h)*60;
    s = sprintf('%02d:%04.1f', h, m);
end
