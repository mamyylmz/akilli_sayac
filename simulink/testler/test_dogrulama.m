%% DOĞRULAMA TESTLERİ – Akıllı Sayaç (A–C aşamaları)
% Konum : Akilli_Sayac/testler/test_dogrulama.m
% Çalıştırma: MATLAB'da Current Folder'ı "testler" yapın ve  test_dogrulama  yazın
%             (ya da dosyayı açıp Run'a basın). Betik ana klasöre geçer, bitince orada kalır.
%
% Bu betik:
%   C0–C4 : parametre dosyası, kWh katsayısı ve tarife dilimleri kontrolleri
%   1. çalıştırma – NORMAL GÜN, 'measurement_test' modu (koruma devre dışı, test yükleri kapalı)
%       T6  24 saatlik profil (I, P, Q, cos φ)      T7  toplam enerji
%       T8  üç zamanlı sayaçlar                      T9  güç faktörü
%       T10 reaktif enerji                           T13 görünür güç S
%   2. çalıştırma – TEST SENARYOSU, 'measurement_test' modu (parametre dosyasındaki "test_senaryo" bölümü ile)
%       T12 kapasitif test yükü 03:00–04:00 (Q < 0, kapasitif sayaç)
%       T4  ana röle 23:00'te açılır (I = P = Q = 0, V = 230 V, sayaç durur)
% Not: Koruma (D aşaması) varsayılan çalışmada AKTİFtir. C aşaması referans ölçüm testleri,
%      sonuçların korunması için 'measurement_test' modunda (koruma devre dışı) yapılır.
%      Koruma senaryoları ayrı betikte test edilir: testler/test_D_koruma.m
% Model KAYDEDİLMEZ: ölçüm kaydı geçici olarak açılır, sonra geri alınır.
% Çıktılar (testler/ klasörüne): test_sonuclari.xlsx ve test_sonuclari.md
% Beklenen değerlerin hesabı: testler/teorik_hesaplar.md

clear;   % (clc yok: arka arkaya çalışan testlerin çıktısı silinmesin)
testDir = fileparts(mfilename('fullpath'));
kokDir  = fileparts(testDir);
cd(kokDir);                              % model ve parametre dosyası ana klasörde
mdl = 'Akilli_Sayac';

TS = cell(0,10);  % {Test, Kontrol, Birim, Beklenen, Gerçekleşen, Fark, Bağıl hata, Tolerans türü, Tolerans, Sonuç}
% Not: Değişken adları parametre dosyasındakilerle (R, L, f, w, N ...) çakışmayacak şekilde seçildi;
% model her çalıştığında InitFcn parametre dosyasını yeniden çalıştırır.

%% C0) Parametre dosyası temiz oturumda eksiksiz mi?
akilli_sayac_param;
gerekli = {'Vpk','f','R_baz','L_baz','R_kettle','R_firin','R_tv','R_bulasik', ...
           'R_camasir','L_camasir','R_klima','L_klima','kettle_t','kettle_u', ...
           'firin_t','tv_t','bulasik_t','camasir_t','klima_t','t_kesme','t_stop', ...
           'k_kWh','T1_t','T1_u','T2_t','T2_u','T3_t','T3_u','C_kap','kap_t','kap_u', ...
           'sebeke_t','sebeke_V','test_modu','kor_par','tahmin_t','tahmin_P','baglan_t','baglan_u','Ts_kontrol'};
eksik = {};
for k = 1:numel(gerekli)
    if ~exist(gerekli{k}, 'var'), eksik{end+1} = gerekli{k}; end %#ok<SAGROW>
end
TS = kSayi(TS, 'C0', 'Parametre dosyasında eksik değişken sayısı', 'adet', 0, numel(eksik), 0, 'Mutlak');
if ~isempty(eksik), fprintf('Eksik değişkenler: %s\n', strjoin(eksik, ', ')); end
TS = kSayi(TS, 'C0', 'Normal günde kapasitif test yükü kapalı (kap_u toplamı)', 'adet', 0, sum(kap_u), 0, 'Mutlak');
TS = kSayi(TS, 'C0', 'Normal günde röle testi kapalı (t_kesme > 24)', 'adet', 1, double(t_kesme > 24), 0, 'Mutlak');
TS = kSayi(TS, 'C0', 'Varsayılan çalışmada koruma aktif (koruma_aktif)', 'adet', 1, koruma_aktif, 0, 'Mutlak');

%% C1–C2) k_kWh dönüşüm katsayısı
TS = kSayi(TS, 'C1', 'k_kWh dönüşüm katsayısı (3600/3,6e6)', '-', 1e-3, k_kWh, 1e-12, 'Mutlak');

tm = 'kWh_birim_testi';
if bdIsLoaded(tm), close_system(tm, 0); end
new_system(tm);
add_block('simulink/Sources/Constant',        [tm '/P'],     'Value', '1000');
add_block('simulink/Math Operations/Gain',    [tm '/k'],     'Gain',  mat2str(k_kWh, 17));   % sayı olarak: test başka bir çalışma alanından çağrılsa da çalışır
add_block('simulink/Continuous/Integrator',   [tm '/E']);
add_block('simulink/Sinks/To Workspace',      [tm '/kayit'], 'VariableName', 'E_birim', 'SaveFormat', 'Array');
add_line(tm, 'P/1', 'k/1');  add_line(tm, 'k/1', 'E/1');  add_line(tm, 'E/1', 'kayit/1');
set_param(tm, 'StopTime', '1');
ob = sim(tm, 'ReturnWorkspaceOutputs', 'on');
Eb = ob.get('E_birim');
close_system(tm, 0);
TS = kSayi(TS, 'C2', 'Test modeli: 1000 W sabit yük x 1 saat', 'kWh', 1, Eb(end), 1e-6, 'Mutlak');

%% C3–C4) Tarife dilimleri: boşluk ve çakışma kontrolü
h  = 0:1/60:24-1/60;                                % günün her dakikası
m1 = interp1(T1_t, T1_u, h, 'previous');            % Lookup Table "Flat" ile aynı mantık
m2 = interp1(T2_t, T2_u, h, 'previous');
m3 = interp1(T3_t, T3_u, h, 'previous');
top = m1 + m2 + m3;
TS = kSayi(TS, 'C3', 'Tarife maskeleri toplamı - günün en küçük değeri (her dakika)', '-', 1, min(top), 0, 'Mutlak');
TS = kSayi(TS, 'C3', 'Tarife maskeleri toplamı - günün en büyük değeri (her dakika)', '-', 1, max(top), 0, 'Mutlak');

sinir = [5+59/60, 6, 16+59/60, 17, 21+59/60, 22];
bekl  = [3 1 1 2 2 3];
M = [interp1(T1_t,T1_u,sinir,'previous'); interp1(T2_t,T2_u,sinir,'previous'); interp1(T3_t,T3_u,sinir,'previous')];
[~, olc] = max(M, [], 1);
TS = kSayi(TS, 'C4', 'Doğru dilime düşen sınır anı (05:59, 06:00, 16:59, 17:00, 21:59, 22:00)', 'adet', 6, sum(olc == bekl), 0, 'Mutlak');

%% Kaydedilecek sinyaller (blok adı, çıkış no, kayıt adı)
kayit = { 'RMS Measurement',    1, 'Vrms';
          'RMS Measurement1',   1, 'Irms';
          'Power Measurement',  1, 'P';
          'Power Measurement',  2, 'Q';
          'Gorunur_Guc',        1, 'S';
          'Enerji_Sayaci',      1, 'E';
          'Sayac_T1',           1, 'ET1';
          'Sayac_T2',           1, 'ET2';
          'Sayac_T3',           1, 'ET3';
          'Sayac_Rend',         1, 'ERend';
          'Sayac_Rkap',         1, 'ERkap';
          'cos_phi_hesap',      1, 'cosphi';
          'Reaktif_Oran_Yuzde', 1, 'oran' };

%% 1. ÇALIŞTIRMA – NORMAL GÜN ('measurement_test': koruma devre dışı)
[logs, sure1] = modeliCalistir(mdl, kayit, struct('test_modu', 'measurement_test'));
[tV,V]  = sinyalAl(logs,'Vrms');   [tI,I]  = sinyalAl(logs,'Irms');
[tP,P]  = sinyalAl(logs,'P');      [tQ,Q]  = sinyalAl(logs,'Q');
[tS,S]  = sinyalAl(logs,'S');      [tE,E]  = sinyalAl(logs,'E');
[t1,E1] = sinyalAl(logs,'ET1');    [t2,E2] = sinyalAl(logs,'ET2');   [t3,E3] = sinyalAl(logs,'ET3');
[~,ER]  = sinyalAl(logs,'ERend');  [~,EK]  = sinyalAl(logs,'ERkap');
[tc,CP] = sinyalAl(logs,'cosphi'); [~,OR]  = sinyalAl(logs,'oran');

% T6 – 24 saatlik profil (dilim ortalarında I / P / Q / cos φ)
%        saat      I(A)    P(W)   Q(VAR)  cosφ     (teorik, bkz. teorik_hesaplar.md)
prof = [ 3.5       0.81    149    111     0.804;
         7+5/60    9.35   2148    111     0.999;
         12        0.81    149    111     0.804;
         18+5/60  19.76   4544    110     1.000;
         18.5     11.09   2547    111     0.999;
         19.5      8.70   1632   1158     0.816;
         20.25    14.51   2770   1861     0.830;
         21.5      6.94   1371    815     0.860;
         22.75    12.22   2690    815     0.957;
         23.5      6.76   1552    111     0.997 ];
np = size(prof,1);
pf_gercek = zeros(np,1);  pf_pq = pf_gercek;  S_olc = pf_gercek;  S_pq = pf_gercek;
for i = 1:np
    tq = prof(i,1);  st = saatYaz(tq);
    Io = degerAn(tI,I,tq); Po = degerAn(tP,P,tq); Qo = degerAn(tQ,Q,tq); Co = degerAn(tc,CP,tq);
    Vo = degerAn(tV,V,tq); So = degerAn(tS,S,tq);
    TS = kSayi(TS, 'T6', ['Profil ' st ' - I_rms'], 'A',   prof(i,2), Io, 0.02,  'Bağıl');
    TS = kSayi(TS, 'T6', ['Profil ' st ' - P'],     'W',   prof(i,3), Po, 0.01,  'Bağıl');
    TS = kSayi(TS, 'T6', ['Profil ' st ' - Q'],     'VAR', prof(i,4), Qo, 0.02,  'Bağıl');
    TS = kSayi(TS, 'T6', ['Profil ' st ' - cos φ'], '-',   prof(i,5), Co, 0.005, 'Mutlak');
    % T13 – görünür güç: beklenen S = √(P² + Q²) (teorik P ve Q'dan)
    TS = kSayi(TS, 'T13', ['Profil ' st ' - S = Vrms·Irms'], 'VA', hypot(prof(i,3), prof(i,4)), So, 0.02, 'Bağıl');
    pf_gercek(i) = Po/(Vo*Io);  pf_pq(i) = Co;
    S_olc(i) = So;  S_pq(i) = hypot(Po, Qo);
end
TS = kSayi(TS, 'T6', 'Vrms (12:00)', 'V', 230, degerAn(tV,V,12), 0.005, 'Bağıl');
TS = kSayi(TS, 'T13', 'En büyük bağıl fark: Vrms·Irms ile √(P²+Q²) (10 nokta)', '-', 0, max(abs(S_olc - S_pq)./S_pq), 0.005, 'Mutlak');
TS = kSayi(TS, 'T13', 'Günün en büyük S değeri (18:00–18:10 tepe)', 'VA', 4545.3, max(S(tS > 18.05 & tS < 18.15)), 0.01, 'Bağıl');

% T7 – Toplam enerji sayacı
TS = kSayi(TS, 'T7', 'Toplam enerji 06:00', 'kWh',  0.897, degerAn(tE,E,6),  0.01, 'Bağıl');
TS = kSayi(TS, 'T7', 'Toplam enerji 17:00', 'kWh',  2.874, degerAn(tE,E,17), 0.01, 'Bağıl');
TS = kSayi(TS, 'T7', 'Toplam enerji 22:00', 'kWh', 10.978, degerAn(tE,E,22), 0.01, 'Bağıl');
TS = kSayi(TS, 'T7', 'Toplam enerji 24:00 (günlük)', 'kWh', 14.56,  E(end),      0.01, 'Bağıl');
negE = -trapz(tP, min(P,0)) * k_kWh;                       % negatif P geçicilerinin enerjisi
TS = kSayi(TS, 'T7', 'Negatif P geçicilerinin enerjisi (tolerans: toplamın %0,1)', 'kWh', 0, negE, 0.001*14.56, 'Mutlak');

% T8 – Üç zamanlı sayaçlar
TS = kSayi(TS, 'T8', 'T1 Gündüz sayacı', 'kWh', 1.977, E1(end), 0.01, 'Bağıl');
TS = kSayi(TS, 'T8', 'T2 Puant sayacı', 'kWh', 8.103, E2(end), 0.01, 'Bağıl');
TS = kSayi(TS, 'T8', 'T3 Gece sayacı', 'kWh', 4.479, E3(end), 0.01, 'Bağıl');
TS = kSayi(TS, 'T8', 'abs(T1 + T2 + T3 - Toplam)', 'kWh', 0, abs(E1(end)+E2(end)+E3(end)-E(end)), 1e-3, 'Mutlak');
TS = kSayi(TS, 'T8', 'T1 sayacının 06:00 öncesi değeri', 'kWh', 0, degerAn(t1,E1,6), 1e-3, 'Mutlak');
TS = kSayi(TS, 'T8', 'T2 sayacının 17:00 öncesi değeri', 'kWh', 0, degerAn(t2,E2,17), 1e-3, 'Mutlak');
TS = kSayi(TS, 'T8', 'T3 sayacının 06:00-22:00 arası artışı', 'kWh', 0, degerAn(t3,E3,22)-degerAn(t3,E3,6), 1e-3, 'Mutlak');

% T9 – Güç faktörü
TS = kSayi(TS, 'T9', 'cos φ (24:00)', '-', 0.997, CP(end), 0.005, 'Mutlak');
TS = kSayi(TS, 'T9', 'En büyük fark: P/√(P²+Q²) ile P/(Vrms·Irms)', '-', 0, max(abs(pf_gercek-pf_pq)), 0.005, 'Mutlak');

% T10 – Reaktif enerji
TS = kSayi(TS, 'T10', 'Endüktif reaktif enerji', 'kVARh', 6.339, ER(end), 0.01, 'Bağıl');
TS = kSayi(TS, 'T10', 'Kapasitif reaktif enerji (normal günde kapasitif yük yok)', 'kVARh', 0, EK(end), 0.02, 'Mutlak');
TS = kSayi(TS, 'T10', 'Reaktif oran E_R / E (izleme göstergesi, ceza değil)', '%', 43.5, OR(end), 0.5, 'Mutlak');

%% 2. ÇALIŞTIRMA – TEST SENARYOSU (kapasitif test yükü + röle kesme)
sen.test_modu = 'measurement_test';   % koruma devre dışı (ölçüm testi)
sen.kap_t   = [0 3 4 25];      % kondansatör 03:00–04:00 açık
sen.kap_u   = [0 1 0 0];
sen.t_kesme = 23;              % ana röle 23:00'te açılır (gün sonuna kadar)
[logs2, sure2] = modeliCalistir(mdl, kayit, sen);
[tV2,V2] = sinyalAl(logs2,'Vrms');  [tI2,I2] = sinyalAl(logs2,'Irms');
[tP2,P2] = sinyalAl(logs2,'P');     [tQ2,Q2] = sinyalAl(logs2,'Q');
[tS2,S2] = sinyalAl(logs2,'S');     [tE2,E2s] = sinyalAl(logs2,'E');
[tR2,ER2] = sinyalAl(logs2,'ERend'); [tK2,EK2] = sinyalAl(logs2,'ERkap');
[tc2,CP2] = sinyalAl(logs2,'cosphi');

% T12 – Kapasitif yük (beklenenler: devre çözümü, bkz. teorik_hesaplar.md §T12)
tq = 3.5;
Qk = degerAn(tQ2,Q2,tq);
TS = kSayi(TS, 'T12', 'Kondansatör açık (03:30) - Q', 'VAR', -889.3, Qk, 0.02, 'Bağıl');
TS = kSayi(TS, 'T12', 'Kondansatör açık (03:30) - Q işareti (−1 = kapasitif)', '-', -1, sign(Qk), 0, 'Mutlak');
TS = kSayi(TS, 'T12', 'Kondansatör açık (03:30) - P (değişmemeli)', 'W', 149.7, degerAn(tP2,P2,tq), 0.01, 'Bağıl');
TS = kSayi(TS, 'T12', 'Kondansatör açık (03:30) - I_rms', 'A', 3.921, degerAn(tI2,I2,tq), 0.02, 'Bağıl');
TS = kSayi(TS, 'T12', 'Kondansatör açık (03:30) - S', 'VA', 901.8, degerAn(tS2,S2,tq), 0.02, 'Bağıl');
TS = kSayi(TS, 'T12', 'Kondansatör açık (03:30) - cos φ (işaretsiz gösterim)', '-', 0.166, degerAn(tc2,CP2,tq), 0.005, 'Mutlak');
a = 3 + 3/60;  b = 4 - 3/60;   % geçici bölgeleri dışarıda bırak: 03:03–03:57 (0,9 saat)
TS = kSayi(TS, 'T12', 'Kapasitif sayaç artışı 03:03–03:57', 'kVARh', 0.8004, degerAn(tK2,EK2,b)-degerAn(tK2,EK2,a), 0.01, 'Bağıl');
TS = kSayi(TS, 'T12', 'Endüktif sayaç artışı 03:03–03:57 (artmamalı)', 'kVARh', 0, degerAn(tR2,ER2,b)-degerAn(tR2,ER2,a), 1e-3, 'Mutlak');
TS = kSayi(TS, 'T12', 'Aktif enerji artışı 03:03–03:57 (kondansatör aktif enerji eklememeli)', 'kWh', 0.1347, degerAn(tE2,E2s,b)-degerAn(tE2,E2s,a), 0.01, 'Bağıl');

% T4 – Ana röle (uzaktan kesme)
tq = 23.5;
TS = kSayi(TS, 'T4', 'Röle açık (23:30) - I_rms', 'A', 0, degerAn(tI2,I2,tq), 0.01, 'Mutlak');
TS = kSayi(TS, 'T4', 'Röle açık (23:30) - P', 'W', 0, degerAn(tP2,P2,tq), 1, 'Mutlak');
TS = kSayi(TS, 'T4', 'Röle açık (23:30) - Q', 'VAR', 0, degerAn(tQ2,Q2,tq), 1, 'Mutlak');
TS = kSayi(TS, 'T4', 'Röle açık (23:30) - V_rms (şebeke tarafı ölçüm)', 'V', 230, degerAn(tV2,V2,tq), 0.005, 'Bağıl');
TS = kSayi(TS, 'T4', 'Röle açıkken enerji sayacı artışı 23:03–24:00 (durmalı)', 'kWh', 0, E2s(end)-degerAn(tE2,E2s,23+3/60), 1e-4, 'Mutlak');

akilli_sayac_param;   % çalışma alanını normal gün değerlerine döndür

%% Rapor
% Satırları test numarasına göre sırala (C0..C4, T4, T6..T13)
anahtar = zeros(size(TS,1),1);
for i = 1:size(TS,1)
    id = TS{i,1};  n = str2double(id(2:end));
    if id(1) == 'C', anahtar(i) = n/10; else, anahtar(i) = n; end
end
[~, sira] = sort(anahtar);  TS = TS(sira,:);

ng = sum(strcmp(TS(:,10),'GEÇTİ')); nk = sum(strcmp(TS(:,10),'KALDI')); nb = sum(strcmp(TS(:,10),'BEKLİYOR'));
fprintf('\nAKILLI SAYAÇ DOĞRULAMA — %s — MATLAB %s\n', char(datetime('now')), version);
fprintf('Normal gün: %.1f s, test senaryosu: %.1f s simülasyon\n', sure1, sure2);
fprintf('%-5s %-75s %-6s %14s %14s %10s  %s\n', 'Test','Kontrol','Birim','Beklenen','Gerçekleşen','Hata','Sonuç');
for i = 1:size(TS,1)
    fprintf('%-5s %-75s %-6s %14.6g %14.6g %10s  %s\n', TS{i,1}, TS{i,2}, TS{i,3}, TS{i,4}, TS{i,5}, hataYaz(TS{i,7}, TS{i,6}), TS{i,10});
end
fprintf('\nÖZET: %d GEÇTİ, %d KALDI, %d BEKLİYOR\n', ng, nk, nb);

% Excel: her sütun gerçek sayı (Türkçe Excel'de virgüllü ondalıkla doğru görünür)
T = cell2table(TS, 'VariableNames', {'Test','Kontrol','Birim','Beklenen','Gerceklesen','Fark', ...
                                     'Bagil_hata','Tolerans_turu','Tolerans','Sonuc'});
xlsDosya = fullfile(testDir, 'test_sonuclari.xlsx');
mdDosya  = fullfile(testDir, 'test_sonuclari.md');
writetable(T, xlsDosya, 'Sheet', 'Sonuclar', 'WriteMode', 'replacefile');

fid = fopen(mdDosya, 'w', 'n', 'UTF-8');
fprintf(fid, '# Akıllı Sayaç – Doğrulama Sonuçları (A–C aşamaları)\n\n');
fprintf(fid, '- Tarih: %s\n- MATLAB: %s\n- Model: %s.slx\n', char(datetime('now')), version, mdl);
fprintf(fid, '- 1. çalıştırma: normal gün, measurement_test modu (koruma devre dışı, test yükleri kapalı), %.1f s\n', sure1);
fprintf(fid, '- 2. çalıştırma: test senaryosu, measurement_test modu (kondansatör 03:00–04:00, ana röle 23:00''te açık), %.1f s\n', sure2);
fprintf(fid, '- Özet: **%d GEÇTİ, %d KALDI, %d BEKLİYOR**\n\n', ng, nk, nb);
fprintf(fid, '| Test | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |\n|---|---|---|---|---|---|---|---|\n');
for i = 1:size(TS,1)
    fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s |\n', TS{i,1}, TS{i,2}, TS{i,3}, sayiYaz(TS{i,4}), sayiYaz(TS{i,5}), ...
            hataYaz(TS{i,7}, TS{i,6}), tolYaz(TS{i,8}, TS{i,9}), TS{i,10});
end
fprintf(fid, '\nNot: Ekrandaki cos φ işaretsizdir; yükün kapasitif mi endüktif mi olduğunu Q''nun işareti gösterir (T12).\n');
fclose(fid);
fprintf('Sonuçlar kaydedildi: testler/test_sonuclari.xlsx, testler/test_sonuclari.md\n');

%% ---------------- yardımcı fonksiyonlar ----------------
function [logs, sure] = modeliCalistir(mdl, kayit, senaryo)
    % Modeli kaydetmeden çalıştırır. senaryo boş değilse parametre dosyasındaki
    % "test_senaryo" bölümü üzerinden değerleri geçici olarak değiştirir.
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
    evalin('base', 'clear test_senaryo');            % senaryo asla açık kalmasın
    for k = 1:size(kayit,1)                          % ayarları geri al
        ph = get_param([mdl '/' kayit{k,1}], 'PortHandles');  p = ph.Outport(kayit{k,2});
        set_param(p, 'DataLogging', eski{k,1}, 'DataLoggingNameMode', eski{k,2}, 'DataLoggingName', eski{k,3});
    end
    set_param(mdl, 'SignalLogging', eskiLog);
    if ~isempty(eskiPace), set_param(mdl, 'EnablePacing', eskiPace); end
    dosya = get_param(mdl, 'FileName');
    if acikti, set_param(mdl, 'Dirty', 'off'); else, close_system(mdl, 0); end
    asv = [dosya '.autosave'];                       % geçici ayarlardan kalan otomatik kayıt
    if exist(asv, 'file'), delete(asv); end          % (asıl model dosyası değişmedi)
    if ~isempty(hata), rethrow(hata); end
end

function TS = kSayi(TS, id, ad, birim, bek, olc, tol, tip)
    fark = olc - bek;
    if strcmp(tip, 'Bağıl')
        bh = abs(fark) / max(abs(bek), eps);  gecti = bh <= tol;
    else
        bh = NaN;                              gecti = abs(fark) <= tol;
    end
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

function v = degerAn(t, d, tq)        % tq anındaki değer (tq'ya eşit ya da önceki son örnek)
    v = d(find(t <= tq, 1, 'last'));
end

function s = saatYaz(x)
    s = sprintf('%02d:%02d', floor(x), round(mod(x,1)*60));
end
