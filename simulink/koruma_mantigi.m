function [role, durum, uyari, olay, red_maske] = koruma_mantigi(u, par) %#codegen
%KORUMA_MANTIGI  Akıllı sayaç aşırı güç koruması ve röle mantığı (D aşaması)
% Modeldeki "Koruma_Mantigi" MATLAB Function bloğu bu fonksiyonu çağırır.
% Blok Ts_kontrol (1 ms) ile örneklenir; zamanlayıcılar u(1) = t üzerinden çalışır.
%
% GİRİŞ u (6x1):
%   u(1) t         simülasyon zamanı [s]   (profil ölçeği: 1 s = 1 saat)
%   u(2) P         ölçülen aktif güç [W]
%   u(3) V         ölçülen şebeke gerilimi, rms [V] (şebeke tarafı)
%   u(4) P_tahmin  cihaz programlarından tahmini yük [W]
%   u(5) komut     kullanıcı / uzaktan komut: 1 = enerji ver, 0 = kes
%   u(6) baglan    yetkili kullanıcının yeniden bağlanma isteği (yükselen kenar okunur)
%
% PARAMETRE par = kor_par (akilli_sayac_param.m):
%   [P_sinir P_geri t_uyari t_asim t_bekle t_kararli V_min V_max V_kesinti koruma_aktif]
%
% ÇIKIŞLAR:
%   role       1 = röle kapalı (enerji var), 0 = röle açık
%   durum      0 normal
%              1 aşırı güç uyarısı (röle kapalı)
%              2 aşırı güç kesmesi – kilitli, yetkili onay bekliyor
%              3 kullanıcı / uzaktan komutla açık
%              4 şebeke yok (kesinti)
%              5 şebeke gerilimi 207–253 V aralığı dışında
%   uyari      1 = aşırı güç uyarısı
%   olay       o adımda gerçekleşen olay (yoksa 0):
%              10 uyarı başladı           11 uyarı bitti
%              20 aşırı güç kesmesi
%              30 yeniden bağlantı KABUL  31 yeniden bağlantı RED
%              40 şebeke kesildi          41 şebeke geri geldi
%              50 kullanıcı kesti         51 kullanıcı açtı
%   red_maske  red nedenleri (toplam):  1 bekleme süresi dolmadı
%                                       2 tahmini yük > P_geri
%                                       4 gerilim aralık dışı ya da kararlı değil
%                                       8 şebeke yok
%
% Notlar:
%  - Yeniden bağlantı kararında ölçülen P kullanılmaz (röle açıkken P = 0); cihaz
%    programlarından hesaplanan tahmini yük kullanılır.
%  - Koşullar sağlansa bile röle kendiliğinden kapanmaz; yetkili istek gerekir.
%  - koruma_aktif = 0 ('measurement_test' modu): uyarı izlenir, kesme yapılmaz.
%  - İlk 3 periyot (t < t_kararli) başlangıçtır: ölçüm pencereleri dolmadığı için
%    olay üretilmez ve durum 0 gösterilir.

t = u(1);  P = u(2);  V = u(3);  P_tahmin = u(4);  komut = u(5);  baglan = u(6);
P_sinir = par(1);  P_geri = par(2);  t_uyari = par(3);  t_asim = par(4);  t_bekle = par(5);
t_kararli = par(6);  V_min = par(7);  V_max = par(8);  V_kesinti = par(9);  koruma_aktif = par(10);

persistent kilit t_kesme t_asim_bas t_vok_bas baglan_eski uyari_eski sebeke_eski komut_eski
if isempty(kilit)
    kilit = 0;  t_kesme = 0;  t_asim_bas = -1;  t_vok_bas = -1;
    baglan_eski = 0;  uyari_eski = 0;  sebeke_eski = 1;  komut_eski = 1;
end

olay = 0;
red_maske = 0;
baslangic = t < t_kararli;

% --- Şebeke ve gerilim durumu ---
sebeke  = double(V > V_kesinti);
v_uygun = double(V >= V_min && V <= V_max);
if v_uygun > 0.5
    if t_vok_bas < 0
        t_vok_bas = t;                       % gerilim aralığa bu anda girdi
    end
else
    t_vok_bas = -1;
end
v_kararli = double(v_uygun > 0.5 && (t - t_vok_bas) >= t_kararli);

% --- Aşırı güç izleme (ölçülen P) ---
if P > P_sinir
    if t_asim_bas < 0
        t_asim_bas = t;                      % aşım bu anda başladı
    end
    asim_sure = t - t_asim_bas;
else
    t_asim_bas = -1;
    asim_sure = 0;
end
uyari = double(P > P_sinir && asim_sure >= t_uyari);

% --- Kesme (yalnızca koruma aktifken) ---
if koruma_aktif > 0.5 && kilit < 0.5 && P > P_sinir && asim_sure >= t_asim
    kilit = 1;
    t_kesme = t;
    olay = 20;
end

% --- Yetkili yeniden bağlanma isteği (yükselen kenar) ---
istek = baglan > 0.5 && baglan_eski < 0.5;
baglan_eski = baglan;
if istek && kilit > 0.5
    if (t - t_kesme) < t_bekle
        red_maske = red_maske + 1;
    end
    if P_tahmin > P_geri
        red_maske = red_maske + 2;
    end
    if v_kararli < 0.5
        red_maske = red_maske + 4;
    end
    if sebeke < 0.5
        red_maske = red_maske + 8;
    end
    if red_maske == 0
        kilit = 0;
        olay = 30;
    else
        olay = 31;
    end
end

% --- Röle komutu ---
role = double(komut > 0.5 && kilit < 0.5);

% --- Diğer olaylar (bir adımda tek olay; kesme ve bağlantı olayları önceliklidir) ---
if olay == 0 && ~baslangic
    if uyari > 0.5 && uyari_eski < 0.5
        olay = 10;
    elseif uyari < 0.5 && uyari_eski > 0.5
        olay = 11;
    elseif sebeke < 0.5 && sebeke_eski > 0.5
        olay = 40;
    elseif sebeke > 0.5 && sebeke_eski < 0.5
        olay = 41;
    elseif komut < 0.5 && komut_eski > 0.5
        olay = 50;
    elseif komut > 0.5 && komut_eski < 0.5
        olay = 51;
    end
end
uyari_eski = uyari;
sebeke_eski = sebeke;
komut_eski = komut;

% --- Durum kodu ---
if baslangic
    durum = 0;
elseif sebeke < 0.5
    durum = 4;
elseif v_uygun < 0.5
    durum = 5;
elseif kilit > 0.5
    durum = 2;
elseif komut < 0.5
    durum = 3;
elseif uyari > 0.5
    durum = 1;
else
    durum = 0;
end
end
