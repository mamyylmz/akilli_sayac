%% H – RÖLE ADAPTÖRÜ TESTİ – Akıllı Sayaç
% Konum : Akilli_Sayac/simulink/testler/test_H_role_adaptoru.m
% Çalıştırma: simulink klasöründeyken  addpath testler  ve  test_H_role_adaptoru  (~2 dk)
%
% role_adaptoru.m'nin yazılımdan gelen röle komutlarını GERÇEK modelde uyguladığını
% (Kesme_Testi → Role_Komut → Koruma_Mantigi) ve hiçbir hata durumunda "applied" üretmediğini
% (fail-closed) doğrular. Komut dosyaları geçici bir klasöre yazılır, adaptör o klasörle çağrılır,
% test bitince klasör silinir. "Şimdi" sabittir (27.11.2026 12:00 +03:00); süre kontrolü buna göre.
%
%   H1–H4   Kesme komutu (12:00, normal gün): applied; komut sinyali 0, röle 0, durum 3
%   H5–H7   Koruma kilitliyken enerji verme (18:10, aşırı güç senaryosu): rejected, red_maske 2, röle 0
%   H8–H10  Güvenli koşulda enerji verme (18:20, aynı senaryo): applied, red_maske 0, röle 1
%   H11     Süresi dolmuş komut: EXPIRED, model çalıştırılmadı
%   H12     Aynı commandId ikinci kez: tekrar uygulanmadı, cevap değişmedi
%   H13     red_maske loglanamıyor: applied yok (LOG_MISSING)
%   H14     red_maske geçersiz: applied yok (MASK_INVALID)
%   H15     Model çalışmıyor: applied yok (SIMULATION_FAILED)
%   H16     Yarım (.tmp) komut dosyası okunmadı
%   H17     Bozuk JSON: INVALID_COMMAND
% Aşırı güç senaryosu gösteri günündekiyle aynıdır: 18:00–18:15 çamaşır makinesi ve klima da açık,
% ev ≈ 7,1 kW, batarya 2,5 kW → şebeke ≈ 4,6 kW > 4 kW → koruma 18:04'te röleyi açar (kilit).
% Çıktılar: testler/test_H_sonuclari.md / .xlsx

clear;   % (clc yok)
testDir = fileparts(mfilename('fullpath'));
kokDir  = fileparts(testDir);
cd(kokDir);
akilli_sayac_param;
evalin('base', 'clear test_senaryo');
tBas = tic;

TS = cell(0,10);
tmp = fullfile(tempdir, ['role_adaptor_testi_' char(datetime('now', 'Format', 'yyyyMMddHHmmss'))]);
mkdir(fullfile(tmp, 'gelen'));
simdi  = datetime(2026, 11, 27, 9, 0, 0, 'TimeZone', 'UTC');          % = 12:00 (+03:00)
normal = struct();                                                     % normal gün
asiri  = struct('camasir_t', [0 18 18+15*dk 19 20.5 25], 'camasir_u', [0 1 0 1 0 0], ...
                'klima_t',   [0 18 18+15*dk 20 23 25],   'klima_u',   [0 1 0 1 0 0]);
id = @(n) sprintf('%08d-0000-4000-8000-%012d', n, n);

% H1–H4: kesme komutu
c1 = id(1);
komutYaz(tmp, 'k01.json', c1, 'deenergized', 12, 0, 1);
[c, k] = calistir(tmp, simdi, normal, c1);
TS = kSayi(TS, 'H1',  'Kesme komutu (12:00, normal gün): applied (1 = evet)', '-', 1, sonucMu(c, 'applied', 'APPLIED'), 0, 'Mutlak');
TS = kSayi(TS, 'H2',  'Kesme: Kesme_Testi çıkışı (komut sinyali), 12:02', '-', 0, alan(k, 'komut'), 0, 'Mutlak');
TS = kSayi(TS, 'H3',  'Kesme: Koruma_Mantigi röle çıkışı', '-', 0, alan(k, 'role'), 0, 'Mutlak');
TS = kSayi(TS, 'H4',  'Kesme: durum kodu (3 = kullanıcı kesti)', '-', 3, alan(k, 'durum'), 0, 'Mutlak');

% H5–H7: koruma kilitliyken enerji verme
c2 = id(2);
komutYaz(tmp, 'k02.json', c2, 'energized', 18, 10, 1);
[c, k] = calistir(tmp, simdi, asiri, c2);
TS = kSayi(TS, 'H5',  'Koruma kilitliyken enerji verme (18:10): rejected, PROTECTION_REJECTED', '-', 1, sonucMu(c, 'rejected', 'PROTECTION_REJECTED'), 0, 'Mutlak');
TS = kSayi(TS, 'H6',  'Kilitliyken: red_maske (2 = tahmini yük > P_geri)', '-', 2, alan(k, 'redMaske'), 0, 'Mutlak');
TS = kSayi(TS, 'H7',  'Kilitliyken: röle çıkışı (0 = açık kaldı)', '-', 0, alan(k, 'role'), 0, 'Mutlak');

% H8–H10: güvenli koşulda enerji verme
c3 = id(3);
komutYaz(tmp, 'k03.json', c3, 'energized', 18, 20, 1);
[c, k] = calistir(tmp, simdi, asiri, c3);
TS = kSayi(TS, 'H8',  'Güvenli koşulda enerji verme (18:20): applied', '-', 1, sonucMu(c, 'applied', 'APPLIED'), 0, 'Mutlak');
TS = kSayi(TS, 'H9',  'Güvenli koşulda: red_maske', '-', 0, alan(k, 'redMaske'), 0, 'Mutlak');
TS = kSayi(TS, 'H10', 'Güvenli koşulda: röle çıkışı (1 = kapandı)', '-', 1, alan(k, 'role'), 0, 'Mutlak');

% H11: süresi dolmuş komut (10:00–10:01; "şimdi" 12:00)
c4 = id(4);
komutYaz(tmp, 'k04.json', c4, 'deenergized', 10, 0, 1);
[c, k] = calistir(tmp, simdi, normal, c4);
TS = kSayi(TS, 'H11', 'Süresi dolmuş komut: EXPIRED, model çalıştırılmadı', '-', 1, ...
           double(sonucMu(c, 'rejected', 'EXPIRED') && isempty(k)), 0, 'Mutlak');

% H12: aynı commandId ikinci kez
cevap1 = fileread(fullfile(tmp, 'giden', [c1 '.json']));
komutYaz(tmp, 'k05_tekrar.json', c1, 'deenergized', 12, 0, 1);
s = role_adaptoru('klasor', tmp, 'simdi', simdi, 'senaryo', normal);
defter = splitlines(fileread(fullfile(tmp, 'islenen_komutlar.csv')));
uygulanan = sum(startsWith(defter, [c1 ',']) & contains(defter, ',applied,'));
TS = kSayi(TS, 'H12', 'Aynı commandId ikinci kez: tekrar uygulanmadı, cevap değişmedi', '-', 1, ...
           double(numel(s) == 1 && strcmp(s(1).status, 'duplicate') && uygulanan == 1 && ...
                  strcmp(cevap1, fileread(fullfile(tmp, 'giden', [c1 '.json'])))), 0, 'Mutlak');

% H13: red_maske loglanamıyor
c6 = id(6);
komutYaz(tmp, 'k06.json', c6, 'deenergized', 12, 0, 1);
c = calistir(tmp, simdi, normal, c6, 'test_kayitDisi', {'red_maske'});
TS = kSayi(TS, 'H13', 'red_maske loglanamıyor: applied yok (LOG_MISSING)', '-', 1, sonucMu(c, 'rejected', 'LOG_MISSING'), 0, 'Mutlak');

% H14: red_maske geçersiz
c7 = id(7);
komutYaz(tmp, 'k07.json', c7, 'deenergized', 12, 0, 1);
c = calistir(tmp, simdi, normal, c7, 'test_maskeBoz', true);
TS = kSayi(TS, 'H14', 'red_maske geçersiz: applied yok (MASK_INVALID)', '-', 1, sonucMu(c, 'rejected', 'MASK_INVALID'), 0, 'Mutlak');

% H15–H17: model çalışmıyor + yarım dosya + bozuk JSON (aynı çalıştırmada)
c8 = id(8);
komutYaz(tmp, 'k08.json', c8, 'deenergized', 12, 0, 1);
fid = fopen(fullfile(tmp, 'gelen', 'k09_yarim.json.tmp'), 'w');  fprintf(fid, '{"schemaVersion":');  fclose(fid);
fid = fopen(fullfile(tmp, 'gelen', 'k10_bozuk.json'), 'w');      fprintf(fid, '{"schemaVersion": "1.0.0", ');  fclose(fid);
c = calistir(tmp, simdi, normal, c8, 'model', 'Olmayan_Model_H15');
TS = kSayi(TS, 'H15', 'Model çalışmıyor: applied yok (SIMULATION_FAILED)', '-', 1, sonucMu(c, 'rejected', 'SIMULATION_FAILED'), 0, 'Mutlak');
TS = kSayi(TS, 'H16', 'Yarım (.tmp) komut dosyası okunmadı (1 = evet)', '-', 1, ...
           double(exist(fullfile(tmp, 'gelen', 'k09_yarim.json.tmp'), 'file') == 2 && ...
                  isempty(dir(fullfile(tmp, 'giden', '*yarim*')))), 0, 'Mutlak');
cb = jsonOku(fullfile(tmp, 'giden', 'gecersiz_k10_bozuk.json'));
TS = kSayi(TS, 'H17', 'Bozuk JSON: rejected, INVALID_COMMAND', '-', 1, sonucMu(cb, 'rejected', 'INVALID_COMMAND'), 0, 'Mutlak');

try, rmdir(tmp, 's'); catch, end
sure = toc(tBas);
akilli_sayac_param;

%% Rapor
ng = sum(strcmp(TS(:,10),'GEÇTİ')); nk = sum(strcmp(TS(:,10),'KALDI'));
fprintf('\nRÖLE ADAPTÖRÜ TESTİ — %s — MATLAB %s (%.1f s)\n', char(datetime('now')), version, sure);
fprintf('%-4s %-72s %-5s %10s %12s %10s  %s\n', 'No','Kontrol','Birim','Beklenen','Gerçekleşen','Hata','Sonuç');
for i = 1:size(TS,1)
    fprintf('%-4s %-72s %-5s %10.6g %12.6g %10s  %s\n', TS{i,1}, TS{i,2}, TS{i,3}, TS{i,4}, TS{i,5}, hataYaz(TS{i,7}, TS{i,6}), TS{i,10});
end
fprintf('\nÖZET: %d GEÇTİ, %d KALDI\n', ng, nk);

T = cell2table(TS, 'VariableNames', {'No','Kontrol','Birim','Beklenen','Gerceklesen','Fark', ...
                                     'Bagil_hata','Tolerans_turu','Tolerans','Sonuc'});
writetable(T, fullfile(testDir,'test_H_sonuclari.xlsx'), 'Sheet', 'Sonuclar', 'WriteMode', 'replacefile');

fid = fopen(fullfile(testDir,'test_H_sonuclari.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Akıllı Sayaç – Röle Adaptörü Testi (H)\n\n');
fprintf(fid, '- Tarih: %s\n- MATLAB: %s\n- Adaptör: role_adaptoru.m (dosya tabanlı; docs/SIMULINK_RELAY_PROTOCOL.md)\n', char(datetime('now')), version);
fprintf(fid, '- Sinyal yolu: Kesme_Testi → Role_Komut → Koruma_Mantigi (komut, role, durum, olay, red_maske modelden loglanır)\n');
fprintf(fid, '- Özet: **%d GEÇTİ, %d KALDI**\n\n', ng, nk);
fprintf(fid, '| No | Kontrol | Birim | Beklenen | Gerçekleşen | Hata | Tolerans | Sonuç |\n|---|---|---|---|---|---|---|---|\n');
for i = 1:size(TS,1)
    fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s |\n', TS{i,1}, TS{i,2}, TS{i,3}, sayiYaz(TS{i,4}), sayiYaz(TS{i,5}), ...
            hataYaz(TS{i,7}, TS{i,6}), tolYaz(TS{i,8}, TS{i,9}), TS{i,10});
end
fprintf(fid, ['\nKural (fail-closed): applied yalnızca model hatasız çalıştığında, beş sinyalin hepsi loglandığında, ' ...
              'komut sinyali istenen değerde olduğunda, red_maske okunup 0 olduğunda ve röle istenen durumda olduğunda yazılır.\n']);
fclose(fid);
fprintf('Sonuçlar: testler/test_H_sonuclari.md, .xlsx\n');

%% ---------------- yardımcı fonksiyonlar ----------------
function komutYaz(klasor, dosyaAdi, cid, istenen, hh, mm, gecerlilikDk)
    bas = sprintf('2026-11-27T%02d:%02d:00+03:00', hh, mm);
    t2  = hh*60 + mm + gecerlilikDk;
    bit = sprintf('2026-11-27T%02d:%02d:00+03:00', floor(t2/60), mod(t2, 60));
    k = struct('schemaVersion', '1.0.0', 'id', cid, 'commandId', cid, 'meterId', 'SIM-0001', ...
               'actorId', 'operator-1', 'createdAt', bas, 'expiresAt', bit, ...
               'requestedRelayState', istenen, 'reason', 'Kabul testi (H)');
    fid = fopen(fullfile(klasor, 'gelen', dosyaAdi), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', jsonencode(k));
    fclose(fid);
end

function [c, k] = calistir(tmp, simdi, sen, cid, varargin)
    role_adaptoru('klasor', tmp, 'simdi', simdi, 'senaryo', sen, varargin{:});
    c = jsonOku(fullfile(tmp, 'giden', [cid '.json']));
    k = jsonOku(fullfile(tmp, 'kanit', [cid '.json']));
end

function v = jsonOku(f)
    if exist(f, 'file'), v = jsondecode(fileread(f)); else, v = []; end
end

function v = sonucMu(c, st, kod)
    v = double(isstruct(c) && isfield(c, 'status') && isfield(c, 'code') && ...
               strcmp(c.status, st) && strcmp(c.code, kod));
end

function v = alan(k, f)
    if isstruct(k) && isfield(k, f) && ~isempty(k.(f)) && isnumeric(k.(f)), v = double(k.(f)); else, v = NaN; end
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
