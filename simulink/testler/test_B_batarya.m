%% BATARYA TESTLERİ – Akıllı Sayaç (ev tipi enerji depolama)
% Konum : Akilli_Sayac/simulink/testler/test_B_batarya.m
% Çalıştırma: simulink klasöründeyken  addpath testler  ve  test_B_batarya  (~1 dk)
%
%   B1 Bataryalı normal gün   – koruma AKTİF, batarya AKTİF (varsayılan çalışma)
%   B2 Ada çalışma önleme     – B1 + kullanıcı 18:30'da röleyi keser: batarya durmalı
%   B3 Ölçüm testi modu       – 'measurement_test': batarya kendiliğinden kapalı olmalı
% Beklenen değerler: testler/teorik_hesaplar.md §14
% Çıktılar: testler/test_B_sonuclari.md ve .xlsx. Model KAYDEDİLMEZ.

clear;   % (clc yok: arka arkaya çalışan testlerin çıktısı silinmesin)
testDir = fileparts(mfilename('fullpath'));
kokDir  = fileparts(testDir);
cd(kokDir);
mdl = 'Akilli_Sayac';
akilli_sayac_param;

TS = cell(0,10);
kayit = { 'RMS Measurement1',   1, 'Irms';
          'Power Measurement',  1, 'P';
          'Enerji_Sayaci',      1, 'E';
          'Sayac_T1',           1, 'ET1';
          'Sayac_T2',           1, 'ET2';
          'Sayac_T3',           1, 'ET3';
          'Batarya_Mantigi',    1, 'Pbat';
          'Batarya_Mantigi',    2, 'SOC';
          'Batarya_Mantigi',    3, 'mod';
          'Koruma_Mantigi',     2, 'durum';
          'Koruma_Mantigi',     4, 'olay' };

S = struct('ad', {}, 'sen', {});
S(1).ad = 'B1 Bataryalı normal gün';  S(1).sen = struct('test_modu','normal','batarya_aktif',1);
S(2).ad = 'B2 Ada çalışma önleme';    S(2).sen = struct('test_modu','normal','batarya_aktif',1,'t_kesme',18.5);
S(3).ad = 'B3 Ölçüm testi modu';      S(3).sen = struct('test_modu','measurement_test','batarya_aktif',1);
sure = zeros(1, numel(S));

for k = 1:numel(S)
    fprintf('%s çalışıyor...\n', S(k).ad);
    [logs, sure(k)] = modeliCalistir(mdl, kayit, S(k).sen);
    SN = struct();
    for j = 1:size(kayit,1)
        [SN.(['t_' kayit{j,3}]), SN.(kayit{j,3})] = sinyalAl(logs, kayit{j,3});
    end
    id = sprintf('B%d', k);
    switch k
        case 1
            TS = kSayi(TS, id, 'Aşırı güç kesmesi sayısı (batarya tepeyi düşürdü)', 'adet', 0, sum(SN.olay == 20), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Gün boyu şebekeden çekilen P < P_sinir (1 = evet)', '-', 1, double(max(SN.P(SN.t_P > 0.1)) < P_sinir), 0, 'Mutlak');
            TS = kSayi(TS, id, '18:05 şebeke gücü (4544 − 2500 deşarj)', 'W', 2044, degerAn(SN.t_P,SN.P,18+5*dk), 0.02, 'Bağıl');
            TS = kSayi(TS, id, '22:45 şebeke gücü (şarj P_geri''ye kısıldı)', 'W', 3800, degerAn(SN.t_P,SN.P,22.75), 0.01, 'Bağıl');
            negE = -trapz(SN.t_P, min(SN.P,0)) * k_kWh;
            TS = kSayi(TS, id, 'Şebekeye verilen enerji (negatif P)', 'kWh', 0, negE, 0.002, 'Mutlak');
            TS = kSayi(TS, id, 'T1 Gündüz sayacı', 'kWh', 1.977, SN.ET1(end), 0.01, 'Bağıl');
            TS = kSayi(TS, id, 'T2 Puant sayacı', 'kWh', 4.072, SN.ET2(end), 0.01, 'Bağıl');
            TS = kSayi(TS, id, 'T3 Gece sayacı', 'kWh', 8.970, SN.ET3(end), 0.01, 'Bağıl');
            TS = kSayi(TS, id, 'Günlük enerji (14,56 + şarj/deşarj kaybı)', 'kWh', 15.02, SN.E(end), 0.01, 'Bağıl');
            TS = kSayi(TS, id, 'SOC 02:00 (gece şarjı tamam)', '-', 0.95, degerAn(SN.t_SOC,SN.SOC,2), 0.002, 'Mutlak');
            TS = kSayi(TS, id, 'SOC 18:00', '-', 0.9184, degerAn(SN.t_SOC,SN.SOC,18), 0.003, 'Mutlak');
            TS = kSayi(TS, id, 'SOC 19:00', '-', 0.3921, degerAn(SN.t_SOC,SN.SOC,19), 0.005, 'Mutlak');
            ib = find(SN.t_SOC > 17 & SN.SOC <= SOC_min + 1e-3, 1);
            tb = NaN;  if ~isempty(ib), tb = SN.t_SOC(ib); end
            TS = kSayi(TS, id, 'Batarya boşalma anı (saat, ≈19:51)', 'saat', 19.85, tb, 2*dk, 'Mutlak');
            TS = kSayi(TS, id, 'SOC 24:00 (güne başladığı değere yakın)', '-', 0.6326, SN.SOC(end), 0.005, 'Mutlak');
            TS = kSayi(TS, id, 'En büyük deşarj gücü (≤ P_desarj)', 'W', P_desarj, max(SN.Pbat), 1e-6, 'Bağıl');
            TS = kSayi(TS, id, 'Durum kodu 23:30 (0 = normal)', '-', 0, degerAn(SN.t_durum,SN.durum,23.5), 0, 'Mutlak');
        case 2
            TS = kSayi(TS, id, 'Röle açıkken batarya gücü (18:45)', 'W', 0, degerAn(SN.t_Pbat,SN.Pbat,18.75), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Röle açıkken batarya modu (0 = bekleme)', '-', 0, degerAn(SN.t_mod,SN.mod,18.75), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Röle açıkken I_rms (ada çalışma yok)', 'A', 0, degerAn(SN.t_Irms,SN.Irms,18.75), 0.01, 'Mutlak');
            TS = kSayi(TS, id, 'Röle açıkken gece şarjı yok (22:30 batarya gücü)', 'W', 0, degerAn(SN.t_Pbat,SN.Pbat,22.5), 0, 'Mutlak');
            TS = kSayi(TS, id, 'SOC değişimi 18:31–24:00 (sabit kalmalı)', '-', 0, SN.SOC(end) - degerAn(SN.t_SOC,SN.SOC,18.5+dk), 0.001, 'Mutlak');
        case 3
            TS = kSayi(TS, id, 'Gün boyu en büyük |batarya gücü|', 'W', 0, max(abs(SN.Pbat)), 0, 'Mutlak');
            TS = kSayi(TS, id, 'Günlük enerji (referans gün)', 'kWh', 14.56, SN.E(end), 0.01, 'Bağıl');
    end
end
akilli_sayac_param;

%% Rapor
ng = sum(strcmp(TS(:,10),'GEÇTİ')); nk = sum(strcmp(TS(:,10),'KALDI'));
fprintf('\nBATARYA TESTLERİ — %s — MATLAB %s\n', char(datetime('now')), version);
fprintf('%-4s %-58s %-5s %12s %12s %10s  %s\n', 'Sen.','Kontrol','Birim','Beklenen','Gerçekleşen','Hata','Sonuç');
for i = 1:size(TS,1)
    fprintf('%-4s %-58s %-5s %12.6g %12.6g %10s  %s\n', TS{i,1}, TS{i,2}, TS{i,3}, TS{i,4}, TS{i,5}, hataYaz(TS{i,7}, TS{i,6}), TS{i,10});
end
fprintf('\nÖZET: %d GEÇTİ, %d KALDI\n', ng, nk);

T = cell2table(TS, 'VariableNames', {'Senaryo','Kontrol','Birim','Beklenen','Gerceklesen','Fark', ...
                                     'Bagil_hata','Tolerans_turu','Tolerans','Sonuc'});
writetable(T, fullfile(testDir,'test_B_sonuclari.xlsx'), 'Sheet', 'Sonuclar', 'WriteMode', 'replacefile');
fid = fopen(fullfile(testDir,'test_B_sonuclari.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Akıllı Sayaç – Batarya Testleri\n\n');
fprintf(fid, '- Tarih: %s\n- MATLAB: %s\n- Model: %s.slx\n', char(datetime('now')), version, mdl);
fprintf(fid, '- Batarya: %g kWh, SOC %g–%g, şarj %g W (T3), deşarj en fazla %g W (T2), verim %g / %g, SOC_0 = %g\n', ...
        E_bat, SOC_min, SOC_max, P_sarj, P_desarj, eta_sarj, eta_desarj, SOC_0);
fprintf(fid, '- Özet: **%d GEÇTİ, %d KALDI**\n\n', ng, nk);
fprintf(fid, '| Senaryo | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |\n|---|---|---|---|---|---|---|---|\n');
for i = 1:size(TS,1)
    fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s |\n', TS{i,1}, TS{i,2}, TS{i,3}, sayiYaz(TS{i,4}), sayiYaz(TS{i,5}), ...
            hataYaz(TS{i,7}, TS{i,6}), tolYaz(TS{i,8}, TS{i,9}), TS{i,10});
end
fclose(fid);
fprintf('Sonuçlar: testler/test_B_sonuclari.md, testler/test_B_sonuclari.xlsx\n');

%% ---------------- yardımcı fonksiyonlar ----------------
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
