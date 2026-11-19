%% AKILLI SAYAÇ PROJESİ v2 - PARAMETRE DOSYASI
% Bu dosya modelin InitFcn callback'inden her simülasyon öncesi çalışır.
% Tüm değerler burada tutulur; bloklara sayı değil DEĞİŞKEN ADI yazılır.
% Değişiklik yapan kişi tarihi ve adını aşağıya not etsin.
%   17.11.2026 - Poyraz: ilk sürüm
%   17.11.2026 - Poyraz: ev tipi sayaca geçiş; kompanzasyon kaldırıldı, su ısıtıcı eklendi
%   17.11.2026 - Poyraz: ana röle (uzaktan kesme) testi eklendi
%   18.11.2026 - Poyraz: 24 saatlik gün (1 s = 1 saat), su ısıtıcı kullanım programı
%   18.11.2026 - Poyraz: ev yük profili (7 cihaz) parametreleri eklendi
%   18.11.2026 - Poyraz: enerji sayacı (k_kWh) ve üç zamanlı tarife maskeleri eklendi
%   19.11.2026 - Poyraz: görünür güç S, kapasitif test yükü (T12), test senaryosu bölümü

%% Zaman ölçeği
% 1 s simülasyon = 1 saat gerçek zaman  ->  24 s simülasyon = 1 gün.
% Scope'lardaki zaman ekseni doğrudan "saat" olarak okunur (7 = 07:00).
dk     = 1/60;            % 1 dakika, simülasyon saniyesi cinsinden
t_stop = 24;              % s = 24 saat (1 gün)

%% Şebeke
f      = 50;              % Hz, şebeke frekansı
w      = 2*pi*f;          % rad/s, açısal frekans
Vrms   = 230;             % V, faz-nötr etkin değer
Vpk    = Vrms*sqrt(2);    % V, tepe değer (Simscape AC kaynağı TEPE değer ister) = 325.27 V

%% ESKİ TEST YÜKÜ (T1-T4 doğrulama testleri) - Adım 5b-4'te baz yük ile değiştirilecek
% P = 1840 W, Q = 1380 VAR, I = 10 A, cos(phi) = 0.80
R      = 18.4;            % Ohm
XL     = 13.8;            % Ohm, endüktif reaktans
L      = XL/w;            % H  = 0.04393 H (43.93 mH)  [eski raporda 87.5 mH yazıyordu - HATALI]

%% ===================== EV YÜK PROFİLİ (Adım 5b) =====================
% Cihaz güçleri: 6. hafta slaytındaki ev aletleri tablosu.
% Tarife dilimleri: Gündüz 06-17, Puant 17-22, Gece 22-06.
% Her cihaz için: *_t = saat noktaları, *_u = o saatten itibaren 0 (kapalı) / 1 (açık).
% Son nokta (25) gün dışında kalır; tablonun "kapalı" bitmesini garanti eder.
%
% Seri R-L eşdeğeri (P ve cos(phi) verilen cihaz için):
%   R = V^2*pf^2/P ,  X = V^2*pf*sqrt(1-pf^2)/P ,  L = X/w

% --- Baz yük: buzdolabı + bekleme yükleri (24 saat açık) ---
% Varsayım: slayttaki buzdolabı değeri (1.666 kW) sürekli çalışma için yüksek;
% tipik kompresör + bekleme yükleri ortalaması 150 W alındı.
P_baz  = 150;   pf_baz = 0.80;
R_baz  = Vrms^2*pf_baz^2/P_baz;                        % = 225.71 Ohm
L_baz  = Vrms^2*pf_baz*sqrt(1-pf_baz^2)/(P_baz*w);     % = 0.5388 H

% --- Su ısıtıcı: 2 kW, omik ---
P_kettle = 2000;
R_kettle = Vrms^2/P_kettle;                            % = 26.45 Ohm
kettle_t = [0   7   7+10*dk   18   18+10*dk   25];     % 07:00-07:10, 18:00-18:10
kettle_u = [0   1   0         1    0          0 ];

% --- Fırın: 2.4 kW, omik ---
P_firin = 2400;
R_firin = Vrms^2/P_firin;                              % = 22.04 Ohm
firin_t = [0   18   19   25];                          % 18:00-19:00 (puant)
firin_u = [0   1    0    0 ];

% --- TV: 83 W, omik (ileride doğrusal olmayan yük olarak ele alınabilir) ---
P_tv = 83;
R_tv = Vrms^2/P_tv;                                    % = 637.35 Ohm
tv_t = [0   19   25];                                  % 19:00-24:00
tv_u = [0   1    0 ];

% --- Bulaşık makinesi: 1.32 kW, omik (çoğunlukla ısıtıcı) ---
P_bulasik = 1320;
R_bulasik = Vrms^2/P_bulasik;                          % = 40.08 Ohm
bulasik_t = [0   22.5   25];                           % 22:30-24:00 (gece)
bulasik_u = [0   1      0 ];

% --- Çamaşır makinesi: 1.4 kW, motorlu, cos(phi) = 0.80 (varsayım) ---
P_camasir = 1400;   pf_camasir = 0.80;
R_camasir = Vrms^2*pf_camasir^2/P_camasir;                       % = 24.18 Ohm
L_camasir = Vrms^2*pf_camasir*sqrt(1-pf_camasir^2)/(P_camasir*w);% = 0.0577 H
camasir_t = [0   19   20.5   25];                                % 19:00-20:30 (puant)
camasir_u = [0   1    0      0 ];

% --- Klima: 1.14 kW, motorlu, cos(phi) = 0.85 (varsayım) ---
P_klima = 1140;   pf_klima = 0.85;
R_klima = Vrms^2*pf_klima^2/P_klima;                             % = 33.53 Ohm
L_klima = Vrms^2*pf_klima*sqrt(1-pf_klima^2)/(P_klima*w);        % = 0.0661 H
klima_t = [0   20   23   25];                                    % 20:00-23:00
klima_u = [0   1    0    0 ];
% =====================================================================

% Not: Reaktif ceza / otomatik kompanzasyon kaldırıldı (mesken aboneleri
% reaktif bedelden muaf). Sayaç Q, cos(phi) ve kVARh'yi yalnızca güç
% kalitesi izleme amacıyla ölçer.

%% Kapasitif test yükü (yalnızca T12 testi için; normal günde KAPALI)
% Kondansatör akımı gerilimden 90 derece ileridedir -> Q < 0
% Q_kap = V^2 * w * C   ->   C = Q_kap / (V^2 * w)
Q_kap = 1000;                       % VAR
C_kap = Q_kap/(Vrms^2*w);           % F  = 60.17 uF
kap_t = [0 25];                     % normal gün: hiç açılmaz
kap_u = [0 0];

%% Ana röle (uzaktan kesme-açma) - test
t_kesme = 25;     % saat; 24'ten büyük = gün içinde kesme yok (test şimdilik kapalı)

%% Enerji sayacı (Adım 6)
% kWh = integral(P dt) * (3600 s gerçek / 1 s simülasyon) / (3.6e6 J/kWh)
k_kWh = 3600/3.6e6;   % = 1/1000

% Üç zamanlı tarife dilimleri: Gündüz T1 06-17, Puant T2 17-22, Gece T3 22-06
T1_t = [0  6 17 25];   T1_u = [0 1 0 0];   % gündüz
T2_t = [0 17 22 25];   T2_u = [0 1 0 0];   % puant
T3_t = [0  6 22 25];   T3_u = [1 0 1 1];   % gece (gece yarısından önce ve sonra)

%% Sayaç örnekleme (Metroloji / DSP)
Fs     = 4000;            % örnek/s
Ts_adc = 1/Fs;            % s, örnekleme periyodu = 0.25 ms
N      = Fs/f;            % periyot başına örnek = 80

%% Test senaryosu (yalnızca testler için)
% Komut penceresinde 'test_senaryo' adlı bir struct varsa, alanları yukarıdaki
% değerlerin yerine geçer. Örnek: test_senaryo.kap_t = [0 3 4 25];
% Normal çalışmada bu değişken YOKTUR. İş bitince:  clear test_senaryo
if exist('test_senaryo', 'var') && isstruct(test_senaryo)
    ts_alanlar = fieldnames(test_senaryo);
    for ts_i = 1:numel(ts_alanlar)
        eval([ts_alanlar{ts_i} ' = test_senaryo.(ts_alanlar{ts_i});']);
    end
    warning('TEST SENARYOSU AKTİF: %s', strjoin(ts_alanlar', ', '));
    clear ts_alanlar ts_i
end
