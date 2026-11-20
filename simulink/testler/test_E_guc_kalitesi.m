%% E AŞAMASI – GÜÇ KALİTESİ TESTLERİ – Akıllı Sayaç
% Konum : Akilli_Sayac/simulink/testler/test_E_guc_kalitesi.m
% Çalıştırma: simulink klasöründeyken  addpath testler  ve  test_E_guc_kalitesi  (~30 s)
%
% Tek simülasyonda üç şebeke olayı (koruma AKTİF, batarya KAPALI – etkileri ayrı görülsün;
% 18:00 aşırı güç kesmesi karışmasın diye su ısıtıcının akşam kullanımı 17:00'ye alınır):
%   E1 Kesinti            12:30–12:40   V = 0 V
%   E2 Gerilim çökmesi    20:10–20:20   V = 0,80 × 230 = 184 V
%   E3 Gerilim yükselmesi 21:10–21:20   V = 1,15 × 230 = 264,5 V
% Her olay için: başlangıç, bitiş, süre, ölçülen en küçük/en büyük gerilim, güç değişimi
% ve sistemin tepkisi (olay kodu, durum kodu, röle) kaydedilir.
% Not: Olaylar RMS ölçümünden algılanır; RMS penceresi 1 periyot (20 ms = 1,2 profil dk)
%      olduğu için algılama zamanları gerçek olaydan bir miktar gecikir (teorik_hesaplar.md §15).
% Çıktılar: testler/test_E_sonuclari.md / .xlsx, testler/guc_kalitesi_olaylari.md

clear;   % (clc yok)
testDir = fileparts(mfilename('fullpath'));
kokDir  = fileparts(testDir);
cd(kokDir);
mdl = 'Akilli_Sayac';
akilli_sayac_param;

TS = cell(0,10);
kayit = { 'RMS Measurement',    1, 'Vrms';
          'RMS Measurement1',   1, 'Irms';
          'Power Measurement',  1, 'P';
          'Enerji_Sayaci',      1, 'E';
          'Koruma_Mantigi',     1, 'role';
          'Koruma_Mantigi',     2, 'durum';
          'Koruma_Mantigi',     4, 'olay' };

V_cok = 0.80*Vrms;  V_yuk = 1.15*Vrms;
sen = struct('test_modu', 'normal', 'batarya_aktif', 0);
sen.kettle_t = [0 7 7+10*dk 17 17+10*dk 25];   % 18:00 aşırı güç kesmesi gerilim olaylarına karışmasın (S1 ile aynı)
sen.kettle_u = [0 1 0 1 0 0];
sen.sebeke_t = [0  12.5  12.5+10*dk  20+10*dk  20+20*dk  21+10*dk  21+20*dk  25];
sen.sebeke_V = [Vrms  0  Vrms  V_cok  Vrms  V_yuk  Vrms  Vrms];

fprintf('Güç kalitesi senaryosu çalışıyor...\n');
[logs, sure] = modeliCalistir(mdl, kayit, sen);
SN = struct();
for j = 1:size(kayit,1)
    [SN.(['t_' kayit{j,3}]), SN.(kayit{j,3})] = sinyalAl(logs, kayit{j,3});
end
[ot, oc] = olaylar(SN);
ilkOlay = @(kod, t1, t2) ilk(ot(oc == kod & ot >= t1 & ot <= t2));

% Olay tanımları: {kimlik, ad, gerçek başlangıç, gerçek bitiş, başlangıç kodu, bitiş kodu,
%                  beklenen algılama başlangıcı (dk sonra), beklenen algılama bitişi (dk sonra),
%                  beklenen gerilim, beklenen güç oranı, beklenen durum kodu}
OD = { 'E1', 'Kesinti (V < 23 V)',          12.5,    12.5+10*dk, 40, 41, 1.19, 0.01, 0,     0,      4;
       'E2', 'Gerilim çökmesi (184 V)',     20+10*dk, 20+20*dk,  42, 43, 0.63, 0.57, V_cok, 0.64,   5;
       'E3', 'Gerilim yükselmesi (264,5 V)', 21+10*dk, 21+20*dk, 42, 43, 0.78, 0.42, V_yuk, 1.3225, 5 };
OL = cell(0,9);   % {Olay, Gerçek başlangıç, Algılama başlangıcı, Algılama bitişi, Süre (dk), V min, V max, Güç (öncesi→sırası), Sistem tepkisi}

for k = 1:size(OD,1)
    [id, ad, tb, te, kb, ke, db, de, Vbek, poran, dbek] = OD{k,:};
    tm   = (tb + te)/2;                                % olayın ortası
    tonc = tb - 5*dk;                                  % olaydan 5 dk önce
    tab  = ilkOlay(kb, tb - dk, te);                   % algılanan başlangıç
    tae  = ilkOlay(ke, te - dk, te + 3*dk);            % algılanan bitiş
    i_ol = SN.t_Vrms > tb + 2*dk & SN.t_Vrms < te - dk;    % olay içi (geçiciler hariç)
    Vmin = min(SN.Vrms(i_ol));  Vmax = max(SN.Vrms(i_ol));
    Ponc = degerAn(SN.t_P, SN.P, tonc);  Pol = degerAn(SN.t_P, SN.P, tm);
    TS = kSayi(TS, id, [ad ' - algılama başlangıcı (saat)'], 'saat', tb + db*dk, tab, 0.25*dk, 'Mutlak');
    TS = kSayi(TS, id, [ad ' - algılama bitişi (saat)'],     'saat', te + de*dk, tae, 0.25*dk, 'Mutlak');
    TS = kSayi(TS, id, [ad ' - ölçülen süre (dk)'], 'dk', 10 + de - db, (tae - tab)/dk, 0.5, 'Mutlak');
    if Vbek == 0
        TS = kSayi(TS, id, [ad ' - olay sırasında V_rms'], 'V', 0, Vmax, 0.5, 'Mutlak');
        TS = kSayi(TS, id, [ad ' - olay sırasında P'], 'W', 0, Pol, 1, 'Mutlak');
        TS = kSayi(TS, id, [ad ' - enerji sayacı artışı (durmalı)'], 'kWh', 0, ...
                   degerAn(SN.t_E,SN.E,te-dk) - degerAn(SN.t_E,SN.E,tb+2*dk), 1e-4, 'Mutlak');
    else
        TS = kSayi(TS, id, [ad ' - olay sırasında V_rms'], 'V', Vbek, (Vmin+Vmax)/2, 0.005, 'Bağıl');
        TS = kSayi(TS, id, [ad ' - güç oranı P(olay)/P(önce) = (V/230)²'], '-', poran, Pol/Ponc, 0.01, 'Bağıl');
    end
    TS = kSayi(TS, id, [ad ' - durum kodu olay ortasında'], '-', dbek, degerAn(SN.t_durum,SN.durum,tm), 0, 'Mutlak');
    TS = kSayi(TS, id, [ad ' - röle kapalı kaldı (gerilim olayında kesme yapılmaz)'], '-', 1, min(SN.role(SN.t_role > tb & SN.t_role < te + 3*dk)), 0, 'Mutlak');
    TS = kSayi(TS, id, [ad ' - olay sonrası durum (0 = normal)'], '-', 0, degerAn(SN.t_durum,SN.durum,te+5*dk), 0, 'Mutlak');
    tepki = sprintf('olay %d/%d kaydedildi, durum %d, röle kapalı', kb, ke, dbek);
    OL(end+1,:) = {ad, saatYaz(tb), saatYaz(tab), saatYaz(tae), (tae-tab)/dk, Vmin, Vmax, ...
                   sprintf('%.0f → %.0f W', Ponc, Pol), tepki}; %#ok<SAGROW>
end
TS = kSayi(TS, 'E', 'Gün boyunca aşırı güç kesmesi (gerilim olayları kesme üretmemeli)', 'adet', 0, sum(oc == 20), 0, 'Mutlak');
akilli_sayac_param;

%% Rapor
ng = sum(strcmp(TS(:,10),'GEÇTİ')); nk = sum(strcmp(TS(:,10),'KALDI'));
fprintf('\nGÜÇ KALİTESİ TESTLERİ — %s — MATLAB %s (%.1f s)\n', char(datetime('now')), version, sure);
fprintf('%-4s %-72s %-5s %12s %12s %10s  %s\n', 'Olay','Kontrol','Birim','Beklenen','Gerçekleşen','Hata','Sonuç');
for i = 1:size(TS,1)
    fprintf('%-4s %-72s %-5s %12.6g %12.6g %10s  %s\n', TS{i,1}, TS{i,2}, TS{i,3}, TS{i,4}, TS{i,5}, hataYaz(TS{i,7}, TS{i,6}), TS{i,10});
end
fprintf('\nÖZET: %d GEÇTİ, %d KALDI\n', ng, nk);

T = cell2table(TS, 'VariableNames', {'Olay','Kontrol','Birim','Beklenen','Gerceklesen','Fark', ...
                                     'Bagil_hata','Tolerans_turu','Tolerans','Sonuc'});
writetable(T, fullfile(testDir,'test_E_sonuclari.xlsx'), 'Sheet', 'Sonuclar', 'WriteMode', 'replacefile');
TO = cell2table(OL, 'VariableNames', {'Olay','Gercek_baslangic','Algilama_baslangic','Algilama_bitis', ...
                                      'Sure_dk','V_min','V_max','Guc','Sistem_tepkisi'});
writetable(TO, fullfile(testDir,'test_E_sonuclari.xlsx'), 'Sheet', 'Olaylar');

fid = fopen(fullfile(testDir,'test_E_sonuclari.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Akıllı Sayaç – Güç Kalitesi Testleri (E aşaması)\n\n');
fprintf(fid, '- Tarih: %s\n- MATLAB: %s\n- Mod: normal (koruma aktif), batarya kapalı\n', char(datetime('now')), version);
fprintf(fid, '- Özet: **%d GEÇTİ, %d KALDI**\n\n', ng, nk);
fprintf(fid, '| Olay | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |\n|---|---|---|---|---|---|---|---|\n');
for i = 1:size(TS,1)
    fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s |\n', TS{i,1}, TS{i,2}, TS{i,3}, sayiYaz(TS{i,4}), sayiYaz(TS{i,5}), ...
            hataYaz(TS{i,7}, TS{i,6}), tolYaz(TS{i,8}, TS{i,9}), TS{i,10});
end
fprintf(fid, '\nNot: "saat" birimindeki değerler profil saatidir.\n');
fclose(fid);

fid = fopen(fullfile(testDir,'guc_kalitesi_olaylari.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Güç Kalitesi Olay Kaydı\n\n%s\n\n', char(datetime('now')));
fprintf(fid, '| Olay | Gerçek başlangıç | Algılandı | Bitti (algılanan) | Süre (dk) | V min (V) | V max (V) | Güç | Sistem tepkisi |\n|---|---|---|---|---|---|---|---|---|\n');
for i = 1:size(OL,1)
    fprintf(fid, '| %s | %s | %s | %s | %.1f | %.1f | %.1f | %s | %s |\n', OL{i,:});
end
fprintf(fid, ['\nAlgılama zamanları RMS ölçüm penceresi (1 periyot = 20 ms = 1,2 profil dk) nedeniyle ' ...
              'gerçek olaydan bir miktar sonradır; ayrıntı: teorik_hesaplar.md §15.\n']);
fclose(fid);
fprintf('Sonuçlar: testler/test_E_sonuclari.md, .xlsx, testler/guc_kalitesi_olaylari.md\n');

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

function s = saatYaz(x)
    if isnan(x), s = '-'; return; end
    h = floor(x);  m = (x - h)*60;
    s = sprintf('%02d:%04.1f', h, m);
end
