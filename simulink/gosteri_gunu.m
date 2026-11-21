function gosteri_gunu(islem)
%GOSTERI_GUNU  Sunum için hazır senaryo: sayacın bütün özellikleri tek bir günde.
% Konum : Akilli_Sayac/simulink/gosteri_gunu.m
%
% Kullanım (simulink klasöründeyken, komut penceresine):
%   gosteri_gunu            % senaryoyu yükler; modelde Run'a basınca HAN ekranında canlı izlenir
%   gosteri_gunu('veri')    % senaryoyla modeli çalıştırır: TEST verisi (ciktilar/test/), olay
%                           % tablosu, kontroller ve grafik (raporlar/gosteri_gunu.png) üretir
%   gosteri_gunu('kapat')   % senaryoyu kaldırır; model normal güne döner
%
% Senaryo (normal günden farkları):
%   12:30-12:40  şebeke kesintisi                               -> durum 4 (lacivert), olay 40/41
%   18:00        su ısıtıcı + fırın + çamaşır + klima aynı anda (~7,1 kW). Batarya 2,5 kW
%                verse de şebekeden ~4,6 kW çekilir -> 1 dk sonra uyarı (durum 1, sarı),
%                3 dk sonra koruma röleyi açar (durum 2, kırmızı)
%   18:06        yeniden bağlanma isteği -> RED: bekleme dolmadı + tahmini yük yüksek (maske 1+2 = 3)
%   18:12        istek -> RED: çamaşır ve klima hâlâ açık, tahmini yük > 3800 W (maske 2)
%   18:15        kullanıcı çamaşır makinesini ve klimayı kapatır
%   18:20        istek -> KABUL (olay 30); röle kapanır, batarya yeniden evi besler
%   20:10-20:20  gerilim çökmesi 184 V (%80)                     -> durum 5 (turuncu)
%   21:10-21:20  gerilim yükselmesi 264,5 V (%115)               -> durum 5
%   22:00        batarya gece şarjı (şarj, 3800 W'ı aşmamak için kısılır)
%   23:30        kullanıcı uygulamadan sayacı kapatır            -> durum 3 (gri), olay 50
% Bu bir TEST senaryosudur: veri ciktilar/test/ klasörüne, dosya adına _TEST eklenerek yazılır.
% Modelde ve parametre dosyasında hiçbir şey değişmez.

if nargin < 1, islem = 'yukle'; end
dk = 1/60;

%% Senaryo (test_senaryo alanları parametre dosyasındaki değerlerin yerine geçer)
s = struct();
s.sebeke_t  = [0  12.5  12.5+10*dk  20+10*dk  20+20*dk  21+10*dk  21+20*dk  25];
s.sebeke_V  = [230  0   230         184       230       264.5     230       230];
s.camasir_t = [0  18  18+15*dk  19  20.5  25];      % 18:00-18:15 (+ her zamanki 19:00-20:30)
s.camasir_u = [0  1   0         1   0     0 ];
s.klima_t   = [0  18  18+15*dk  20  23    25];      % 18:00-18:15 (+ her zamanki 20:00-23:00)
s.klima_u   = [0  1   0         1   0     0 ];
s.baglan_t  = [0  18+6*dk 18+7*dk  18+12*dk 18+13*dk  18+20*dk 18+21*dk  25];
s.baglan_u  = [0  1       0        1        0         1        0         0 ];
s.t_kesme   = 23.5;                                 % 23:30 kullanıcı kesmesi

switch lower(islem)
    case 'yukle'
        assignin('base', 'test_senaryo', s);
        fprintf('\nGÖSTERİ GÜNÜ yüklendi (test senaryosu).\n');
        fprintf('  1. Modelde Run''a basın ve HAN ekranını izleyin.\n');
        fprintf('     Yavaş izlemek için: SIMULATION > Run (alttaki ok) > Simulation Pacing > Enable,\n');
        fprintf('     hız 0.1 (bütün gün yaklaşık 4 dakika). Önemli anlarda Pause ile durdurabilirsiniz.\n');
        fprintf('  2. Önemli anlar: 12:30 kesinti (lacivert) | 18:00 aşırı güç (sarı, sonra kırmızı)\n');
        fprintf('     18:06 ve 18:12 red | 18:20 kabul | 20:10 çökme, 21:10 yükselme (turuncu)\n');
        fprintf('     22:00 batarya şarjı | 23:30 kullanıcı kesti (gri)\n');
        fprintf('  3. Bitince normal güne dönmek için:  gosteri_gunu(''kapat'')\n\n');

    case 'kapat'
        evalin('base', 'clear test_senaryo');
        fprintf('Gösteri senaryosu kaldırıldı; model normal güne döndü.\n');

    case 'veri'
        assignin('base', 'test_senaryo', s);
        temizle = onCleanup(@() evalin('base', 'clear test_senaryo')); %#ok<NASGU>
        sonuc = veri_aktar();
        T = readtable(sonuc.olcum,   'Encoding', 'UTF-8', 'Delimiter', ',', 'TextType', 'string');
        E = readtable(sonuc.olaylar, 'Encoding', 'UTF-8', 'Delimiter', ',', 'TextType', 'string');

        % Olay tablosu
        fprintf('\nGÖSTERİ GÜNÜ – OLAY KAYDI (%d olay)\n', height(E));
        fprintf('  %-6s %-5s %-40s %-6s %s\n', 'Saat', 'Kod', 'Olay', 'Durum', 'Red nedeni');
        for j = 1:height(E)
            fprintf('  %-6s %-5d %-40s %-6d %s\n', saatYaz(E.saat(j)), E.olay_kodu(j), ...
                    metin(E.olay(j)), E.durum(j), metin(E.red_nedeni(j)));
        end

        % Senaryonun beklenen olayları gerçekten oldu mu?
        K = cell(0, 3);
        r = bul(E, 40, 12.5, 12.5+3*dk);
        K(end+1,:) = {'12:30 kesinti algılandı (40)', ~isempty(r), zamanlar(r)};
        r = bul(E, 41, 12.5+10*dk, 12.5+13*dk);
        K(end+1,:) = {'12:40 şebeke geri geldi (41)', ~isempty(r), zamanlar(r)};
        r = bul(E, 10, 18, 18+5*dk);
        K(end+1,:) = {'18:00 aşırı güç uyarısı (10)', ~isempty(r), zamanlar(r)};
        r = bul(E, 20, 18, 18+6*dk);
        K(end+1,:) = {'Koruma röleyi açtı (20), 18:06 isteğinden önce', ~isempty(r), zamanlar(r)};
        r = bul(E, 31, 18+5*dk, 18+8*dk);
        K(end+1,:) = {'18:06 istek RED, maske 3 (bekleme + yük)', ~isempty(r) && r.red_maske(1) == 3, maskeler(r)};
        r = bul(E, 31, 18+11*dk, 18+14*dk);
        K(end+1,:) = {'18:12 istek RED, maske 2 (yük)', ~isempty(r) && r.red_maske(1) == 2, maskeler(r)};
        r = bul(E, 30, 18+19*dk, 18+22*dk);
        K(end+1,:) = {'18:20 istek KABUL (30)', ~isempty(r), zamanlar(r)};
        r = bul(E, 42, 20+10*dk, 20+13*dk);
        K(end+1,:) = {'20:10 gerilim çökmesi algılandı (42)', ~isempty(r), zamanlar(r)};
        r = bul(E, 42, 21+10*dk, 21+13*dk);
        K(end+1,:) = {'21:10 gerilim yükselmesi algılandı (42)', ~isempty(r), zamanlar(r)};
        r = bul(E, 50, 23.5, 23.5+2*dk);
        K(end+1,:) = {'23:30 kullanıcı kesti (50)', ~isempty(r), zamanlar(r)};
        gorulen = unique(T.durum)';
        K(end+1,:) = {'Altı durum kodunun hepsi görüldü (0-5)', all(ismember(0:5, gorulen)), mat2str(gorulen)};
        i = 18*60 + 25 + 1;                                     % 18:25 satırı
        K(end+1,:) = {'18:25 batarya yeniden evi besliyor (> 2000 W)', T.p_bat_W(i) > 2000, sprintf('%.0f W', T.p_bat_W(i))};
        K(end+1,:) = {'Veri aktarımı kontrolleri', sonuc.kontroller_gecti, sonuc.veri_turu};

        fprintf('\nGÖSTERİ GÜNÜ – KONTROLLER\n');
        for k = 1:size(K,1)
            if K{k,2}, d = 'GEÇTİ'; else, d = 'KALDI'; end
            fprintf('  [%s] %s (%s)\n', d, K{k,1}, K{k,3});
        end
        fprintf('  Özet: %d/%d geçti\n', nnz([K{:,2}]), size(K,1));

        % Grafik
        kok = fileparts(mfilename('fullpath'));
        rDir = fullfile(kok, 'raporlar');
        if ~exist(rDir, 'dir'), mkdir(rDir); end
        png = fullfile(rDir, 'gosteri_gunu.png');
        cizGrafik(T, E, png);
        fprintf('  Grafik: raporlar/gosteri_gunu.png\n');
        fprintf('  Veri  : ciktilar/test/ (_TEST)\n');
        fprintf('  Senaryo kaldırıldı; model normal güne döndü.\n\n');

    otherwise
        error('Bilinmeyen işlem: %s. Kullanım: gosteri_gunu, gosteri_gunu(''veri''), gosteri_gunu(''kapat'')', islem);
end
end

%% ---------------- yardımcı fonksiyonlar ----------------
function r = bul(E, kod, t1, t2)
    r = E(E.olay_kodu == kod & E.saat >= t1 & E.saat <= t2, :);
end

function c = metin(x)
    % Tablo hücresini yazdırılabilir metne çevirir (boş / eksik hücre -> '').
    if isstring(x) || ischar(x) || iscell(x)
        x = string(x);
        if ismissing(x), c = ''; else, c = char(x); end
    else
        c = '';
    end
end

function s = saatYaz(t)
    sn = round(t*3600);
    s = sprintf('%02d:%02d', floor(sn/3600), floor(mod(sn,3600)/60));
end

function s = zamanlar(r)
    if isempty(r), s = 'yok'; return; end
    s = strjoin(arrayfun(@saatYaz, r.saat, 'UniformOutput', false)', ', ');
end

function s = maskeler(r)
    if isempty(r), s = 'yok'; return; end
    s = sprintf('%s, maske %d', saatYaz(r.saat(1)), r.red_maske(1));
end

function s = kisaAd(kod, maske)
    switch kod
        case 10, s = 'uyarı';
        case 11, s = 'uyarı bitti';
        case 20, s = 'KESME';
        case 30, s = 'KABUL';
        case 31, s = sprintf('RED (maske %d)', maske);
        case 40, s = 'kesinti';
        case 41, s = 'şebeke geldi';
        case 42, s = 'gerilim dışı';
        case 43, s = 'gerilim normal';
        case 50, s = 'kullanıcı kesti';
        case 51, s = 'kullanıcı açtı';
        otherwise, s = sprintf('%d', kod);
    end
end

function deger(ax, saat, y, t, bicim, renk, yon)
    % t anına en yakın dakikadaki değeri nokta ve yazıyla gösterir (yon: 1 üstte, -1 altta).
    [~, i] = min(abs(saat - t));
    plot(ax, saat(i), y(i), 'o', 'MarkerFaceColor', renk, 'MarkerEdgeColor', 'w', ...
         'MarkerSize', 7, 'HandleVisibility', 'off');
    if yon > 0, va = 'bottom'; else, va = 'top'; end
    text(ax, saat(i), y(i) + yon*250, sprintf(bicim, y(i)), 'Color', renk, 'FontSize', 9, ...
         'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', va);
end

function cizGrafik(T, E, dosya)
    saat = T.dakika/60 + 1/120;                          % dakikanın ortası, saat
    renk = [0.20 0.65 0.30;    % 0 normal       yeşil
            0.95 0.80 0.10;    % 1 uyarı        sarı
            0.85 0.15 0.15;    % 2 kesildi      kırmızı
            0.55 0.55 0.55;    % 3 kullanıcı    gri
            0.10 0.15 0.45;    % 4 şebeke yok   lacivert
            0.95 0.55 0.10];   % 5 gerilim dışı turuncu
    durumAd = {'0 normal', '1 uyarı', '2 kesildi / onay bekliyor', '3 kullanıcı kesti', ...
               '4 şebeke yok', '5 gerilim aralık dışı'};
    mavi = [0.10 0.35 0.75];  turuncu = [0.85 0.40 0.10];

    fig = figure('Name', 'Gösteri günü', 'Position', [80 60 1150 900]);
    try, theme(fig, 'light'); catch, end      % MATLAB koyu temada olsa da grafik açık renkli olsun (rapor için)
    fig.Color = 'w';
    tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'Gösteri günü – akıllı sayaç (test senaryosu, 1 dakikalık veri)', 'FontWeight', 'bold');

    % 1) Güç, bütün gün
    ax1 = nexttile(tl);  hold(ax1, 'on');  grid(ax1, 'on');
    plot(ax1, saat, T.p_W, 'Color', mavi, 'LineWidth', 1.2, 'DisplayName', 'Şebekeden çekilen güç');
    plot(ax1, saat, T.p_bat_W, 'Color', turuncu, 'LineWidth', 1.2, 'DisplayName', 'Batarya (+ evi besliyor, − şarj)');
    yline(ax1, 4000, '--', 'Sınır 4000 W', 'Color', [0.8 0 0], 'Interpreter', 'none', ...
          'LabelHorizontalAlignment', 'center', 'HandleVisibility', 'off');
    ylabel(ax1, 'Güç (W)');  xlim(ax1, [0 24]);  xticks(ax1, 0:2:24);
    legend(ax1, 'Location', 'northwest');

    % 2) Gerilim, bütün gün
    ax2 = nexttile(tl);  hold(ax2, 'on');  grid(ax2, 'on');  ax2.Layer = 'top';
    patch(ax2, [0 24 24 0], [207 207 253 253], [0.82 0.93 0.82], 'EdgeColor', 'none', ...
          'DisplayName', 'İzin verilen aralık 207–253 V');
    plot(ax2, saat, T.v_rms_V, 'Color', [0.05 0.20 0.55], 'LineWidth', 2, 'DisplayName', 'Gerilim (RMS)');
    text(ax2, 12.5 + 15/60, 60,  'Kesinti 12:30–12:40 (0 V)', 'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.10 0.15 0.45]);
    text(ax2, 20 + 10/60, 150, 'Çökme 184 V (20:10)  →',      'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.80 0.40 0.05], 'HorizontalAlignment', 'right');
    text(ax2, 21 + 25/60, 272, '←  Yükselme 264,5 V (21:10)',     'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.80 0.40 0.05]);
    ylabel(ax2, 'Gerilim (V)');  ylim(ax2, [0 300]);  xlim(ax2, [0 24]);  xticks(ax2, 0:2:24);
    legend(ax2, 'Location', 'southwest');

    % 3) Sayaç durumu, bütün gün (HAN ekranındaki renkler)
    ax3 = nexttile(tl);  hold(ax3, 'on');
    image(ax3, 'XData', saat([1 end]), 'YData', [0 1], 'CData', T.durum' + 1);   % 1..6 -> renk satırı
    colormap(ax3, renk);
    for k = 1:6
        patch(ax3, NaN, NaN, renk(k,:), 'DisplayName', durumAd{k});
    end
    xlim(ax3, [0 24]);  ylim(ax3, [0 1]);  xticks(ax3, 0:2:24);  yticks(ax3, []);
    ax3.YDir = 'normal';  box(ax3, 'on');
    ylabel(ax3, 'Durum');  xlabel(ax3, 'Saat');
    legend(ax3, 'Orientation', 'horizontal', 'Location', 'southoutside', 'NumColumns', 3);

    % 4) 18:00 olayı yakından
    ax4 = nexttile(tl);  hold(ax4, 'on');  grid(ax4, 'on');
    ev = T.p_W + T.p_bat_W;                              % evin toplam yükü = şebeke + batarya
    area(ax4, saat, T.p_W, 'FaceColor', mavi, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax4, saat, ev, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.5, 'DisplayName', 'Evin toplam yükü');
    plot(ax4, saat, T.p_W, 'Color', mavi, 'LineWidth', 2.2, 'DisplayName', 'Şebekeden çekilen');
    plot(ax4, saat, T.p_bat_W, 'Color', turuncu, 'LineWidth', 2.2, 'DisplayName', 'Batarya');
    yline(ax4, 4000, '--', 'Sınır 4000 W', 'Color', [0.8 0 0], 'Interpreter', 'none', ...
          'LabelHorizontalAlignment', 'center', 'HandleVisibility', 'off');
    % Değer etiketleri (dakika ortalamaları)
    deger(ax4, saat, ev,        18 + 3/60,  'ev %.0f W',            [0.30 0.30 0.30],  1);
    deger(ax4, saat, T.p_W,     18 + 3/60,  'şebeke %.0f W',        mavi,               1);
    deger(ax4, saat, T.p_bat_W, 18 + 3/60,  'batarya %.0f W',       turuncu,            1);
    deger(ax4, saat, T.p_W,     18 + 10/60, 'röle açık: %.0f W',    mavi,               1);
    deger(ax4, saat, T.p_bat_W, 18 + 26/60, 'batarya %.0f W',       turuncu,            1);
    deger(ax4, saat, T.p_W,     18 + 26/60, 'şebeke %.0f W',        mavi,               1);
    secili = E(E.saat >= 17 + 55/60 & E.saat <= 18 + 30/60 & E.olay_kodu ~= 11, :);   % "uyarı bitti" kesmeyle üst üste biner
    for j = 1:height(secili)
        xline(ax4, secili.saat(j), '-', sprintf('%s  %s', saatYaz(secili.saat(j)), ...
              kisaAd(secili.olay_kodu(j), secili.red_maske(j))), ...
              'Color', [0.3 0.3 0.3], 'Interpreter', 'none', 'FontSize', 8, ...
              'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
    end
    xlim(ax4, [17 + 55/60, 18 + 30/60]);
    xt = (17 + 55/60):(5/60):(18 + 30/60);
    xticks(ax4, xt);  xticklabels(ax4, arrayfun(@saatYaz, xt, 'UniformOutput', false));
    ylabel(ax4, 'Güç (W)');  xlabel(ax4, 'Saat (17:55 – 18:30 yakından)');  ylim(ax4, [-400 8200]);
    legend(ax4, 'Location', 'northwest');
    title(ax4, '18:00 aşırı güç → uyarı → kesme → iki red → kabul', 'FontWeight', 'normal');

    exportgraphics(fig, dosya, 'Resolution', 150);
end
