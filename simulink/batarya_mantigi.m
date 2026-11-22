function [P_bat, SOC, mod] = batarya_mantigi(u, par) %#codegen
%BATARYA_MANTIGI  Ev tipi batarya şarj/deşarj kararı ve doluluk (SOC) hesabı
% Modeldeki "Batarya_Mantigi" MATLAB Function bloğu bu fonksiyonu çağırır (Ts_kontrol = 1 ms).
%
% GİRİŞ u (5x1):
%   u(1) t         simülasyon zamanı [s]  (profil ölçeği: 1 s = 1 saat)
%   u(2) P_tahmin  evin tahmini yükü [W] (cihaz programlarından)
%   u(3) T2        puant dilimi maskesi (1 = 17:00–22:00)
%   u(4) T3        gece dilimi maskesi  (1 = 22:00–06:00)
%   u(5) role      ana röle (1 = kapalı / enerji var)
%
% PARAMETRE par = bat_par (akilli_sayac_param.m):
%   [etkin E_bat SOC_min SOC_max SOC_0 P_sarj P_desarj eta_sarj eta_desarj P_geri]
%
% ÇIKIŞLAR:
%   P_bat  batarya gücü [W]:  > 0 deşarj (eve güç verir),  < 0 şarj (şebekeden çeker)
%   SOC    doluluk oranı (0–1)
%   mod    0 bekleme, 1 şarj, 2 deşarj
%
% Kurallar:
%   - Gece (T3) ve SOC < SOC_max ise şarj: P = min(P_sarj, P_geri − P_tahmin)
%     (şarj yüzünden bağlantı gücü sınırı aşılmasın)
%   - Puant (T2) ve SOC > SOC_min ise deşarj: P = min(P_desarj, P_tahmin)
%     (şebekeye enerji verilmez)
%   - Röle açıksa ya da batarya etkin değilse P = 0
%   - SOC: dSOC/dt = −(P_deşarj/eta_desarj − P_şarj·eta_sarj) / (1000·E_bat)
%     (t profil saati, P watt, E_bat kWh)

t = u(1);  P_tahmin = u(2);  T2 = u(3);  T3 = u(4);  role = u(5);
etkin = par(1);  E_bat = par(2);  SOC_min = par(3);  SOC_max = par(4);  SOC_0 = par(5);
P_sarj = par(6);  P_desarj = par(7);  eta_s = par(8);  eta_d = par(9);  P_geri = par(10);

persistent soc t_eski P_eski
if isempty(soc)
    soc = SOC_0;  t_eski = t;  P_eski = 0;
end

% --- Önceki adımın gücüyle doluluğu güncelle ---
dt = t - t_eski;
t_eski = t;
if P_eski > 0
    soc = soc - (P_eski / eta_d) * dt / (1000 * E_bat);     % deşarj
else
    soc = soc - (P_eski * eta_s) * dt / (1000 * E_bat);     % şarj (P_eski < 0 -> soc artar)
end
soc = min(max(soc, 0), 1);

% --- Bu adımın kararı ---
P_bat = 0;
mod = 0;
if etkin > 0.5 && role > 0.5
    if T3 > 0.5 && soc < SOC_max
        p = min(P_sarj, max(P_geri - P_tahmin, 0));
        if p > 0
            P_bat = -p;
            mod = 1;
        end
    elseif T2 > 0.5 && soc > SOC_min
        P_bat = min(P_desarj, P_tahmin);
        mod = 2;
    end
end
P_eski = P_bat;
SOC = soc;
end
