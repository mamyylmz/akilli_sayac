%% G – KESİNTİ + BATARYA REGRESYON TESTİ – Akıllı Sayaç
% Konum : Akilli_Sayac/simulink/testler/test_G_kesinti_batarya.m
% Çalıştırma: simulink klasöründeyken  addpath testler  ve  test_G_kesinti_batarya  (~40 s)
%
% Neden var: Gösteri günü senaryosu (21.11.2026) bataryalı günde 12:30 kesintisinde simülasyonun
% durduğunu ortaya çıkardı. Kesintide Q sıfır etrafında sayısal gürültüyle salınıyor; Q'yu sıfırda
% kesen iki Saturation bloğunda (Sadece_Enduktif, Sadece_Kapasitif) sıfır geçişi algılama açıkken
% Simulink 1000 ardışık sıfır geçişinden sonra çalışmayı durduruyordu. E testi bataryasız koşulda
% bu sınıra ulaşmadığı için hata görünmemişti.
% Düzeltme: iki blokta ZeroCross = 'off' (kVARh sayacının doğruluğuna etkisi en fazla bir çözücü adımı).
%
% Senaryo: varsayılan bataryalı gün (koruma ve batarya AKTİF) + E testindeki şebeke profili
%          (12:30–12:40 kesinti, 20:10 çökme 184 V, 21:10 yükselme 264,5 V).
% Kontroller:
%   G1, G2  iki blokta sıfır geçişi algılama kapalı (yapılandırma)
%   G3      simülasyon hatasız tamamlandı (düzeltme öncesi 12:32'de duruyordu)
%   G4, G5  kesintinin başlangıcı ve bitişi E testindeki gecikmelerle algılandı
%   G6      kesinti sırasında enerji sayacı artmadı
%   G7      gün sonu SOC bataryalı günle aynı (kesinti T1'de, gerilim olayları batarya boşaldıktan sonra)
% Çıktılar: testler/test_G_sonuclari.md / .xlsx

clear;   % (clc yok)
testDir = fileparts(mfilename('fullpath'));
kokDir  = fileparts(testDir);
cd(kokDir);
mdl = 'Akilli_Sayac';
akilli_sayac_param;

TS = cell(0,10);
kayit = { 'Enerji_Sayaci',   1, 'E';
          'Koruma_Mantigi',  4, 'olay';
          'Batarya_Mantigi', 2, 'SOC' };

sen = struct('test_modu', 'normal');                 % batarya varsayılan olarak açık
sen.sebeke_t = [0  12.5  12.5+10*dk  20+10*dk  20+20*dk  21+10*dk  21+20*dk  25];
sen.sebeke_V = [Vrms  0  Vrms  0.80*Vrms  Vrms  1.15*Vrms  Vrms  Vrms];
tb = 12.5;  te = 12.5 + 10*dk;

% G1, G2: yapılandırma
load_system(mdl);
TS = kSayi(TS, 'G1', 'Sadece_Enduktif: sıfır geçişi algılama kapalı (1 = kapalı)', '-', 1, ...
           double(strcmpi(get_param([mdl '/Sadece_Enduktif'], 'ZeroCross'), 'off')), 0, 'Mutlak');
TS = kSayi(TS, 'G2', 'Sadece_Kapasitif: sıfır geçişi algılama kapalı (1 = kapalı)', '-', 1, ...
           double(strcmpi(get_param([mdl '/Sadece_Kapasitif'], 'ZeroCross'), 'off')), 0, 'Mutlak');

% G3: simülasyon
fprintf('Kesinti + batarya senaryosu çalışıyor...\n');
hataMesaji = '';  sure = NaN;
try
    [logs, sure] = modeliCalistir(mdl, kayit, sen);
    tamam = 1;
catch hata
    tamam = 0;  hataMesaji = hata.message;
end
TS = kSayi(TS, 'G3', 'Simülasyon hatasız tamamlandı (1 = evet)', '-', 1, tamam, 0, 'Mutlak');

if tamam
    SN = struct();
    for j = 1:size(kayit,1)
        [SN.(['t_' kayit{j,3}]), SN.(kayit{j,3})] = sinyalAl(logs, kayit{j,3});
    end
    [ot, oc] = olaylar(SN);
    tab = ilk(ot(oc == 40 & ot >= tb - dk & ot <= te));
    tae = ilk(ot(oc == 41 & ot >= te - dk & ot <= te + 3*dk));
    % Beklenen gecikmeler E testiyle aynı: başlangıç +1,19 dk, bitiş +0,01 dk (teorik_hesaplar.md §15)
    TS = kSayi(TS, 'G4', 'Kesinti algılama başlangıcı (saat)', 'saat', tb + 1.19*dk, tab, 0.25*dk, 'Mutlak');
    TS = kSayi(TS, 'G5', 'Kesinti algılama bitişi (saat)', 'saat', te + 0.01*dk, tae, 0.25*dk, 'Mutlak');
    TS = kSayi(TS, 'G6', 'Kesinti sırasında enerji sayacı artışı (durmalı)', 'kWh', 0, ...
               degerAn(SN.t_E, SN.E, te - dk) - degerAn(SN.t_E, SN.E, tb + 2*dk), 1e-4, 'Mutlak');
    TS = kSayi(TS, 'G7', 'Gün sonu SOC (bataryalı günle aynı, B1: 0,6326)', '-', 0.6326, SN.SOC(end), 0.001, 'Mutlak');
else
    for id = {'G4', 'G5', 'G6', 'G7'}
        TS(end+1,:) = {id{1}, 'Simülasyon tamamlanmadığı için ölçülemedi', '-', NaN, NaN, NaN, NaN, 'Mutlak', NaN, 'KALDI'}; %#ok<SAGROW>
    end
end
akilli_sayac_param;

%% Rapor
ng = sum(strcmp(TS(:,10),'GEÇTİ')); nk = sum(strcmp(TS(:,10),'KALDI'));
fprintf('\nKESİNTİ + BATARYA REGRESYON TESTİ — %s — MATLAB %s (%.1f s)\n', char(datetime('now')), version, sure);
fprintf('%-4s %-66s %-5s %12s %12s %10s  %s\n', 'No','Kontrol','Birim','Beklenen','Gerçekleşen','Hata','Sonuç');
for i = 1:size(TS,1)
    fprintf('%-4s %-66s %-5s %12.6g %12.6g %10s  %s\n', TS{i,1}, TS{i,2}, TS{i,3}, TS{i,4}, TS{i,5}, hataYaz(TS{i,7}, TS{i,6}), TS{i,10});
end
if ~isempty(hataMesaji), fprintf('Simülasyon hatası: %s\n', hataMesaji); end
fprintf('\nÖZET: %d GEÇTİ, %d KALDI\n', ng, nk);

T = cell2table(TS, 'VariableNames', {'No','Kontrol','Birim','Beklenen','Gerceklesen','Fark', ...
                                     'Bagil_hata','Tolerans_turu','Tolerans','Sonuc'});
writetable(T, fullfile(testDir,'test_G_sonuclari.xlsx'), 'Sheet', 'Sonuclar', 'WriteMode', 'replacefile');

fid = fopen(fullfile(testDir,'test_G_sonuclari.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Akıllı Sayaç – Kesinti + Batarya Regresyon Testi (G)\n\n');
fprintf(fid, '- Tarih: %s\n- MATLAB: %s\n- Mod: normal (koruma ve batarya aktif), E testindeki şebeke profili\n', char(datetime('now')), version);
fprintf(fid, '- Özet: **%d GEÇTİ, %d KALDI**\n\n', ng, nk);
fprintf(fid, '| No | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |\n|---|---|---|---|---|---|---|---|\n');
for i = 1:size(TS,1)
    fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s |\n', TS{i,1}, TS{i,2}, TS{i,3}, sayiYaz(TS{i,4}), sayiYaz(TS{i,5}), ...
            hataYaz(TS{i,7}, TS{i,6}), tolYaz(TS{i,8}, TS{i,9}), TS{i,10});
end
if ~isempty(hataMesaji), fprintf(fid, '\nSimülasyon hatası: `%s`\n', hataMesaji); end
fprintf(fid, ['\nNeden: bataryalı günde kesinti sırasında Q sıfır etrafında salınınca iki Saturation bloğundaki ' ...
              'sıfır geçişi algılaması simülasyonu durduruyordu (gösteri günü, 21.11.2026). Düzeltme: ZeroCross = off.\n']);
fclose(fid);
fprintf('Sonuçlar: testler/test_G_sonuclari.md, .xlsx\n');

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

function [ot, oc] = olaylar(SN)
    i = find(SN.olay ~= 0);
    if ~isempty(i)
        tut = [true; diff(i) > 1 | diff(SN.olay(i)) ~= 0];
        i = i(tut);
    end
    ot = SN.t_olay(i);  oc = SN.olay(i);
end

function v = ilk(x)
    if isempty(x), v = NaN; else, v = x(1); end
end
