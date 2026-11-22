%% F AŞAMASI – TALEP YÖNETİMİ TESTİ – Akıllı Sayaç
% Konum : Akilli_Sayac/simulink/testler/test_F_talep.m
% Çalıştırma: simulink klasöründeyken  addpath testler  ve  test_F_talep  (~40 s)
%
% Çamaşır makinesinin çalışma saati puanttan (19:00–20:30, T2) geceye (02:00–03:30, T3)
% kaydırılır. Toplam enerji korunmalı; yalnızca tarife dilimleri arasında yer değiştirmeli.
%   F0 Referans    : çamaşır 19:00–20:30
%   F1 Kaydırılmış : çamaşır 02:00–03:30
% İki çalıştırma da 'measurement_test' modundadır (koruma ve batarya kapalı): yalnızca
% kaydırmanın etkisi görülsün. TL farkı yazılım katmanında hesaplanır:
%   ΔTL = ΔE × (T2 birim fiyatı − T3 birim fiyatı)
% Beklenen değerler: testler/teorik_hesaplar.md §16
% Çıktılar: testler/test_F_sonuclari.md / .xlsx

clear;   % (clc yok)
testDir = fileparts(mfilename('fullpath'));
kokDir  = fileparts(testDir);
cd(kokDir);
mdl = 'Akilli_Sayac';
akilli_sayac_param;

TS = cell(0,10);
kayit = { 'Power Measurement',  1, 'P';
          'Enerji_Sayaci',      1, 'E';
          'Sayac_T1',           1, 'ET1';
          'Sayac_T2',           1, 'ET2';
          'Sayac_T3',           1, 'ET3';
          'Sayac_Rend',         1, 'ERend' };

ref  = struct('test_modu', 'measurement_test');
kay  = ref;  kay.camasir_t = [0 2 3.5 25];  kay.camasir_u = [0 1 0 0];
S = {ref, kay};  ad = {'F0 Referans (çamaşır 19:00–20:30)', 'F1 Kaydırılmış (çamaşır 02:00–03:30)'};
SONUC = cell(1,2);  sure = zeros(1,2);   % (R adı parametre dosyasında kullanılıyor)
for k = 1:2
    fprintf('%s çalışıyor...\n', ad{k});
    [logs, sure(k)] = modeliCalistir(mdl, kayit, S{k});
    SN = struct();
    for j = 1:size(kayit,1)
        [SN.(['t_' kayit{j,3}]), SN.(kayit{j,3})] = sinyalAl(logs, kayit{j,3});
    end
    SONUC{k} = SN;
end
a = SONUC{1};  b = SONUC{2};
dE = 1.4 * 1.5;   % kWh: çamaşır makinesi 1400 W × 1,5 saat

TS = kSayi(TS, 'F', 'Toplam enerji – kaydırılmış / referans (korunmalı)', '-', 1, b.E(end)/a.E(end), 0.001, 'Bağıl');
TS = kSayi(TS, 'F', 'T2 Puant azalması (referans − kaydırılmış)', 'kWh', dE, a.ET2(end) - b.ET2(end), 0.01, 'Bağıl');
TS = kSayi(TS, 'F', 'T3 Gece artışı (kaydırılmış − referans)', 'kWh', dE, b.ET3(end) - a.ET3(end), 0.01, 'Bağıl');
TS = kSayi(TS, 'F', 'T1 Gündüz değişimi', 'kWh', 0, b.ET1(end) - a.ET1(end), 1e-3, 'Mutlak');
TS = kSayi(TS, 'F', 'Endüktif reaktif enerji – kaydırılmış / referans (korunmalı)', '-', 1, b.ERend(end)/a.ERend(end), 0.002, 'Bağıl');
TS = kSayi(TS, 'F', '20:15 şebeke gücü azalması (çamaşır yok)', 'W', 1400, degerAn(a.t_P,a.P,20.25) - degerAn(b.t_P,b.P,20.25), 0.01, 'Bağıl');
TS = kSayi(TS, 'F', '02:30 şebeke gücü artışı (çamaşır gece)', 'W', 1400, degerAn(b.t_P,b.P,2.5) - degerAn(a.t_P,a.P,2.5), 0.01, 'Bağıl');
akilli_sayac_param;

ozet = { 'Toplam (kWh)', a.E(end), b.E(end);  'T1 (kWh)', a.ET1(end), b.ET1(end);
         'T2 Puant (kWh)', a.ET2(end), b.ET2(end);  'T3 Gece (kWh)', a.ET3(end), b.ET3(end) };

%% Rapor
ng = sum(strcmp(TS(:,10),'GEÇTİ')); nk = sum(strcmp(TS(:,10),'KALDI'));
fprintf('\nTALEP YÖNETİMİ TESTİ — %s — MATLAB %s\n', char(datetime('now')), version);
fprintf('%-16s %12s %14s\n', '', 'Referans', 'Kaydırılmış');
for i = 1:size(ozet,1), fprintf('%-16s %12.4f %14.4f\n', ozet{i,:}); end
fprintf('\n%-3s %-62s %-5s %12s %12s %10s  %s\n', '', 'Kontrol','Birim','Beklenen','Gerçekleşen','Hata','Sonuç');
for i = 1:size(TS,1)
    fprintf('%-3s %-62s %-5s %12.6g %12.6g %10s  %s\n', TS{i,1}, TS{i,2}, TS{i,3}, TS{i,4}, TS{i,5}, hataYaz(TS{i,7}, TS{i,6}), TS{i,10});
end
fprintf('\nÖZET: %d GEÇTİ, %d KALDI\n', ng, nk);

T = cell2table(TS, 'VariableNames', {'Test','Kontrol','Birim','Beklenen','Gerceklesen','Fark', ...
                                     'Bagil_hata','Tolerans_turu','Tolerans','Sonuc'});
writetable(T, fullfile(testDir,'test_F_sonuclari.xlsx'), 'Sheet', 'Sonuclar', 'WriteMode', 'replacefile');
writetable(cell2table(ozet, 'VariableNames', {'Sayac','Referans','Kaydirilmis'}), ...
           fullfile(testDir,'test_F_sonuclari.xlsx'), 'Sheet', 'Karsilastirma');
fid = fopen(fullfile(testDir,'test_F_sonuclari.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Akıllı Sayaç – Talep Yönetimi Testi (F aşaması)\n\n');
fprintf(fid, '- Tarih: %s\n- MATLAB: %s\n- Mod: measurement_test (koruma ve batarya kapalı)\n', char(datetime('now')), version);
fprintf(fid, '- Senaryo: çamaşır makinesi (1400 W, 1,5 saat) 19:00–20:30 → 02:00–03:30\n');
fprintf(fid, '- Özet: **%d GEÇTİ, %d KALDI**\n\n', ng, nk);
fprintf(fid, '| Sayaç | Referans | Kaydırılmış | Fark |\n|---|---|---|---|\n');
for i = 1:size(ozet,1), fprintf(fid, '| %s | %.4f | %.4f | %+.4f |\n', ozet{i,:}, ozet{i,3}-ozet{i,2}); end
fprintf(fid, '\nTL farkı yazılım katmanında hesaplanır: ΔTL = %.2f kWh × (T2 birim fiyatı − T3 birim fiyatı)\n\n', a.ET2(end) - b.ET2(end));
fprintf(fid, '| Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |\n|---|---|---|---|---|---|---|\n');
for i = 1:size(TS,1)
    fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s |\n', TS{i,2}, TS{i,3}, sayiYaz(TS{i,4}), sayiYaz(TS{i,5}), ...
            hataYaz(TS{i,7}, TS{i,6}), tolYaz(TS{i,8}, TS{i,9}), TS{i,10});
end
fclose(fid);
fprintf('Sonuçlar: testler/test_F_sonuclari.md, testler/test_F_sonuclari.xlsx\n');

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
