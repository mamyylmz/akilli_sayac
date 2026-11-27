function sonuc = role_adaptoru(varargin)
%ROLE_ADAPTORU  Yazılımdan gelen röle komutlarını Simulink modelinde uygular ve sonucu yazar.
% Yazılım dalındaki docs/SIMULINK_RELAY_PROTOCOL.md ile uyumlu, dosya tabanlı yerel adaptör.
%
% Kullanım (simulink klasöründeyken):
%   role_adaptoru                        % role_komut/gelen/ içindeki bütün komutları işler
%   role_adaptoru('klasor', 'D:\komut')  % başka bir kök klasör
%
% Klasörler (varsayılan kök: simulink/role_komut — çalışma dosyalarıdır, Git'e girmez):
%   gelen/    yazılımın bıraktığı komutlar (*.json). Yazılım dosyayı geçici adla yazıp sonra
%             yeniden adlandırmalıdır; .json ile bitmeyen (yarım) dosyalar okunmaz.
%   giden/    cevaplar: <commandId>.json (önce .tmp yazılır, sonra yeniden adlandırılır)
%   kanit/    her komut için modelden okunan sinyaller: <commandId>.json
%   islenen/  işlenmiş komut dosyaları (tekrar okunmaz)
%   islenen_komutlar.csv   commandId defteri: aynı commandId ikinci kez uygulanmaz
%
% Komutun modele verilmesi:
%   createdAt saati (+03:00) simülasyon saatine çevrilir (12:00 → 12,0 s). O andan itibaren
%   Kesme_Testi komut tablosu (rk_t / rk_u) istenen değere ayarlanır; sinyal yolu
%   Kesme_Testi → Role_Komut → Koruma_Mantigi'dir. Koruma mantığı değiştirilmez.
%     deenergized → komut 0
%     energized   → komut 1 ve aynı anda yetkili yeniden bağlanma isteği (Baglan_Istegi).
%                   Koruma kilitliyse kabul/red kararını Koruma_Mantigi verir (red_maske).
%   Model çalıştırılır; Kesme_Testi çıkışı (komut) ile Koruma_Mantigi'nin role, durum, olay ve
%   red_maske çıkışları MODELDEN loglanır.
%
% Karar (fail-closed): status = applied YALNIZCA şunların hepsi gözlendiğinde yazılır:
%   1) model hatasız çalıştı ve beş sinyalin hepsi loglandı,
%   2) komut sinyali, komut anından sonra istenen değerde (komut sinyal yoluna ulaştı),
%   3) red_maske okunabildi: sonlu, 0..15 arası tamsayı,
%   4) röle çıkışı istenen durumda ve red_maske = 0.
%   Diğer her durumda status = rejected ve bir kod yazılır (aşağıdaki kodlar). Hiçbir hata
%   applied üretmez.
%
% Kodlar: APPLIED, PROTECTION_REJECTED, NOT_APPLIED, COMMAND_NOT_INJECTED, EXPIRED,
%         INVALID_COMMAND, OUT_OF_RANGE, SIMULATION_FAILED, LOG_MISSING, MASK_INVALID
%
% Seçenekler:
%   'senaryo'  test_senaryo struct'ı (verilmezse komut penceresindeki test_senaryo kullanılır;
%              o da yoksa normal gün). struct() verilirse her durumda normal gün.
%   'simdi'    süre kontrolü için "şimdi" (datetime). Verilmezse gerçek saat.
%   'model'    model adı (varsayılan Akilli_Sayac)
%   Yalnızca testler için: 'test_kayitDisi' (loglanmayacak sinyal adları),
%                          'test_maskeBoz'  (red_maske okunamaz yapılır)
%
% İmza: cevap şu an imzasız yazılır; imzanın hangi tarafta atılacağı ekipte netleşince eklenecek.
%
% 27.11.2026 - Poyraz: ilk sürüm

p = inputParser;
p.addParameter('klasor', '', @(x) ischar(x) || isstring(x));
p.addParameter('senaryo', [], @(x) isempty(x) || isstruct(x));
p.addParameter('simdi', NaT('TimeZone', 'UTC'), @isdatetime);
p.addParameter('model', 'Akilli_Sayac', @(x) ischar(x) || isstring(x));
p.addParameter('test_kayitDisi', {}, @iscell);
p.addParameter('test_maskeBoz', false, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
o = p.Results;
o.model = char(o.model);

kok = fileparts(mfilename('fullpath'));
eskiDizin = cd(kok);
geriDon = onCleanup(@() cd(eskiDizin));

if isempty(o.klasor), o.klasor = fullfile(kok, 'role_komut'); end
o.klasor = char(o.klasor);
D = struct('gelen',   fullfile(o.klasor, 'gelen'), ...
           'giden',   fullfile(o.klasor, 'giden'), ...
           'kanit',   fullfile(o.klasor, 'kanit'), ...
           'islenen', fullfile(o.klasor, 'islenen'), ...
           'defter',  fullfile(o.klasor, 'islenen_komutlar.csv'));
for d = {o.klasor, D.gelen, D.giden, D.kanit, D.islenen}
    if ~exist(d{1}, 'dir'), mkdir(d{1}); end
end

% Senaryo: açıkça verilmediyse komut penceresindeki test_senaryo
if isempty(o.senaryo)
    if evalin('base', 'exist(''test_senaryo'', ''var'')')
        o.senaryo = evalin('base', 'test_senaryo');
    else
        o.senaryo = struct();
    end
end
if isnat(o.simdi), o.simdi = datetime('now', 'TimeZone', 'UTC'); end

liste = dir(fullfile(D.gelen, '*.json'));
liste = liste(~startsWith({liste.name}, '.'));
[~, sira] = sort({liste.name});
liste = liste(sira);

sonuc = struct('dosya', {}, 'commandId', {}, 'status', {}, 'code', {}, 'relayState', {});
for k = 1:numel(liste)
    sonuc(end+1) = isle(fullfile(D.gelen, liste(k).name), o, D); %#ok<AGROW>
    s = sonuc(end);
    fprintf('  %-40s %-10s %-20s %s\n', s.dosya, s.status, s.code, s.relayState);
end
if isempty(liste)
    fprintf('Röle adaptörü: %s içinde işlenecek komut yok.\n', D.gelen);
end
end

%% ===================== bir komut =====================
function r = isle(dosya, o, D)
    [~, ad, uz] = fileparts(dosya);
    r = struct('dosya', [ad uz], 'commandId', '', 'status', '', 'code', '', 'relayState', '');

    % 1) oku ve doğrula
    kmt = [];  neden = '';
    try
        kmt = jsondecode(fileread(dosya));
    catch
        neden = 'JSON okunamadı';
    end
    if isempty(neden)
        [kmt, neden] = dogrula(kmt);
    end
    cid = '';
    if isstruct(kmt) && isfield(kmt, 'commandId') && uuidMu(kmt.commandId)
        cid = lower(char(kmt.commandId));
    end
    r.commandId = cid;

    % 2) aynı commandId daha önce işlendiyse: tekrar uygulama, yeni cevap yazma
    if ~isempty(cid) && (defterdeVar(D.defter, cid) || exist(fullfile(D.giden, [cid '.json']), 'file'))
        tasi(dosya, D.islenen, '_tekrar');
        defterYaz(D.defter, cid, r.dosya, 'duplicate', 'DUPLICATE');
        r.status = 'duplicate';  r.code = 'DUPLICATE';  r.relayState = '-';
        return
    end

    cevapAdi = cid;
    if isempty(cevapAdi), cevapAdi = ['gecersiz_' ad]; end

    if ~isempty(neden)
        r = bitir(r, D, dosya, cevapAdi, cid, 'rejected', 'unknown', 'INVALID_COMMAND', ...
                  ['Geçersiz komut: ' neden], []);
        return
    end

    % 3) süre
    if o.simdi > kmt.bitisUTC
        r = bitir(r, D, dosya, cevapAdi, cid, 'rejected', 'unknown', 'EXPIRED', ...
                  'Komutun süresi dolmuş; uygulanmadı', []);
        return
    end

    % 4) simülasyon saati
    tk = kmt.simSaat;
    if tk < 0.1 || tk > 23.9
        r = bitir(r, D, dosya, cevapAdi, cid, 'rejected', 'unknown', 'OUT_OF_RANGE', ...
                  'Komut saati simülasyon günü dışında (00:06–23:54); uygulanmadı', []);
        return
    end

    % 5) modelde uygula ve gözle
    [st, rs, kod, msj, kanit] = uygula(kmt, o);
    r = bitir(r, D, dosya, cevapAdi, cid, st, rs, kod, msj, kanit);
end

function [kmt, neden] = dogrula(kmt)
    neden = '';
    if ~isstruct(kmt) || ~isscalar(kmt), neden = 'nesne değil'; return; end
    gerekli = {'schemaVersion', 'commandId', 'meterId', 'createdAt', 'expiresAt', 'requestedRelayState'};
    eksik = gerekli(~isfield(kmt, gerekli));
    if ~isempty(eksik), neden = ['eksik alan: ' strjoin(eksik, ', ')]; return; end
    if ~strcmp(char(kmt.schemaVersion), '1.0.0'), neden = 'schemaVersion 1.0.0 değil'; return; end
    if ~uuidMu(kmt.commandId), neden = 'commandId UUID değil'; return; end
    if isfield(kmt, 'id') && ~strcmpi(char(kmt.id), char(kmt.commandId))
        neden = 'id ile commandId farklı'; return
    end
    if ~strcmp(char(kmt.meterId), 'SIM-0001'), neden = 'meterId SIM-0001 değil'; return; end
    if ~any(strcmp(char(kmt.requestedRelayState), {'energized', 'deenergized'}))
        neden = 'requestedRelayState energized/deenergized değil'; return
    end
    [bas, yerel, ok1] = zamanCoz(kmt.createdAt);
    [bit, ~, ok2]     = zamanCoz(kmt.expiresAt);
    if ~ok1 || ~ok2, neden = 'createdAt/expiresAt ISO 8601 (saat dilimli) değil'; return; end
    if bit <= bas, neden = 'expiresAt createdAt''ten sonra değil'; return; end
    kmt.bitisUTC = bit;
    kmt.simSaat  = hour(yerel) + minute(yerel)/60 + second(yerel)/3600;
end

function ok = uuidMu(x)
    ok = (ischar(x) || isstring(x)) && ~isempty(regexp(char(x), ...
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$', 'once'));
end

function [utc, yerel, ok] = zamanCoz(s)
    % "2026-11-23T12:00:00+03:00" (kesirli saniye ve Z kabul edilir). yerel = +03:00 saati.
    utc = NaT('TimeZone', 'UTC');  yerel = utc;  ok = false;
    if ~(ischar(s) || isstring(s)), return; end
    tk = regexp(char(s), '^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?(Z|[+-]\d{2}:\d{2})$', 'tokens', 'once');
    if isempty(tk), return; end
    n = str2double(tk(1:6));
    sn = n(6);  if ~isempty(tk{7}), sn = sn + str2double(tk{7}); end
    if strcmp(tk{8}, 'Z')
        ofs = 0;
    else
        ofs = (1 - 2*(tk{8}(1) == '-')) * (str2double(tk{8}(2:3))*60 + str2double(tk{8}(5:6)));
    end
    utc   = datetime(n(1), n(2), n(3), n(4), n(5), sn, 'TimeZone', 'UTC') - minutes(ofs);
    yerel = utc + hours(3);                    % Türkiye saati (+03:00), simülasyon günü bu saatle
    ok = ~isnat(utc);
end

%% ===================== modelde uygulama =====================
function [st, rs, kod, msj, kanit] = uygula(kmt, o)
    dk = 1/60;
    tk = kmt.simSaat;
    hedef = double(strcmp(char(kmt.requestedRelayState), 'energized'));
    sen = o.senaryo;
    veriTuru = 'model';  if ~isempty(fieldnames(sen)), veriTuru = 'test'; end

    % Komut tablosu: komut anına kadar senaryodaki değer, sonra istenen değer
    [rt, ru] = temelKomut(sen);
    once = rt < tk;
    sen.rk_t = [rt(once), tk, 25];
    sen.rk_u = [ru(once), hedef, hedef];
    if hedef == 1
        [bt, bu] = temelBaglan(sen);
        [sen.baglan_t, sen.baglan_u] = darbeEkle(bt, bu, tk, tk + dk);
    end

    kayit = { 'Kesme_Testi',    1, 'komut';
              'Koruma_Mantigi', 1, 'role';
              'Koruma_Mantigi', 2, 'durum';
              'Koruma_Mantigi', 4, 'olay';
              'Koruma_Mantigi', 5, 'red_maske' };
    tumAdlar = kayit(:,3)';
    kayit(ismember(kayit(:,3), o.test_kayitDisi), :) = [];
    tStop = min(24, tk + 0.25);
    tGoz  = tk + 2*dk;                          % gözlem anı: komuttan 2 profil dakika sonra

    kanit = struct('veriTuru', veriTuru, 'requestedRelayState', char(kmt.requestedRelayState), ...
                   'komutSaati', tk, 'gozlemSaati', tGoz, 'model', o.model, 'matlab', version, ...
                   'modelDosyasiSha256', '', 'simulasyonSuresiSn', NaN, 'hata', '', ...
                   'loglananSinyaller', {{}}, 'komut', NaN, 'role', NaN, 'durum', NaN, ...
                   'redMaske', NaN, 'redNedenleri', '', 'olaylar', []);
    try
        mf = which([o.model '.slx']);
        if ~isempty(mf), kanit.modelDosyasiSha256 = sha256_dosya(mf); end
    catch
    end

    [logs, sure, hataMsj] = modeliCalistir(o.model, kayit, sen, tStop);
    kanit.simulasyonSuresiSn = sure;
    if ~isempty(hataMsj)
        kanit.hata = hataMsj;
        [st, rs, kod, msj] = red('unknown', 'SIMULATION_FAILED', 'Model çalıştırılamadı; komut uygulanmadı');
        return
    end

    % Sinyalleri oku: biri bile yoksa fail-closed
    S = struct();  eksik = {};
    for ad = tumAdlar
        try
            el = logs.getElement(ad{1});
            t = el.Values.Time(:);  x = double(squeeze(el.Values.Data));  x = x(:);
            if isempty(t), error('boş'); end
            S.(ad{1}) = struct('t', t, 'x', x);
        catch
            eksik{end+1} = ad{1}; %#ok<AGROW>
        end
    end
    kanit.loglananSinyaller = setdiff(tumAdlar, eksik, 'stable');
    if ~isempty(eksik)
        kanit.hata = ['loglanamayan sinyal: ' strjoin(eksik, ', ')];
        [st, rs, kod, msj] = red('unknown', 'LOG_MISSING', ...
            'Gerekli sinyaller modelden okunamadı; komut uygulanmış sayılmaz');
        return
    end
    if o.test_maskeBoz, S.red_maske.x(:) = NaN; end

    kanit.komut = degerAn(S.komut, tGoz);
    kanit.role  = degerAn(S.role,  tGoz);
    kanit.durum = degerAn(S.durum, tGoz);
    pen = S.red_maske.x(S.red_maske.t >= tk - 1e-9 & S.red_maske.t <= tk + dk);
    ol  = S.olay.x(S.olay.t >= tk - 1e-9 & S.olay.t <= tGoz);
    kanit.olaylar = unique(round(ol(ol ~= 0)))';
    rs = 'unknown';
    if ~isnan(kanit.role), rs = secim(kanit.role > 0.5, 'energized', 'deenergized'); end

    if isempty(pen) || any(~isfinite(pen)) || any(pen < 0 | pen > 15 | pen ~= round(pen))
        kanit.hata = 'red_maske sonlu ve 0..15 arası tamsayı değil';
        [st, ~, kod, msj] = red(rs, 'MASK_INVALID', ...
            'Koruma maskesi okunamadı veya geçersiz; komut uygulanmış sayılmaz');
        rs = 'unknown';
        return
    end
    maske = max(pen);
    kanit.redMaske = maske;  kanit.redNedenleri = redYaz(maske);

    if isnan(kanit.komut) || isnan(kanit.role) || isnan(kanit.durum)
        [st, rs, kod, msj] = red('unknown', 'LOG_MISSING', 'Gözlem anında sinyal değeri yok; uygulanmış sayılmaz');
        return
    end
    if round(kanit.komut) ~= hedef
        [st, rs, kod, msj] = red(rs, 'COMMAND_NOT_INJECTED', 'Komut sinyal yoluna ulaşmadı; uygulanmış sayılmaz');
        return
    end
    if maske > 0
        [st, rs, kod, msj] = red(rs, 'PROTECTION_REJECTED', ['Koruma komutu reddetti: ' redYaz(maske)]);
        return
    end
    if round(kanit.role) == hedef
        st = 'applied';  kod = 'APPLIED';
        if hedef == 1
            msj = 'Simulink koruma mantığı komutu uyguladı; röle kapalı (enerji var)';
        else
            msj = 'Simulink koruma mantığı komutu uyguladı; röle açık (enerji yok)';
        end
    else
        [st, rs, kod, msj] = red(rs, 'NOT_APPLIED', sprintf('Röle istenen duruma geçmedi (durum %d)', round(kanit.durum)));
    end
end

function [st, rs, kod, msj] = red(rs, kod, msj)
    st = 'rejected';
end

function [rt, ru] = temelKomut(sen)
    if isfield(sen, 'rk_t') && isfield(sen, 'rk_u') && ~isempty(sen.rk_t)
        rt = sen.rk_t(:)';  ru = sen.rk_u(:)';
    else
        tkes = 25;
        if isfield(sen, 't_kesme'), tkes = sen.t_kesme; end
        if tkes <= 0,      rt = [0 25];       ru = [0 0];
        elseif tkes < 25,  rt = [0 tkes 25];  ru = [1 0 0];
        else,              rt = [0 25];       ru = [1 1];
        end
    end
end

function [bt, bu] = temelBaglan(sen)
    if isfield(sen, 'baglan_t') && isfield(sen, 'baglan_u')
        bt = sen.baglan_t(:)';  bu = sen.baglan_u(:)';
    else
        bt = [0 25];  bu = [0 0];
    end
end

function [t, u] = darbeEkle(bt, bu, t1, t2)
    % Basamaklı tabloya [t1, t2) aralığında 1 değerli darbe ekler (mevcut değerlerle VEYA).
    t = unique([bt, t1, t2]);
    u = max(interp1(bt, bu, t, 'previous', 'extrap'), double(t >= t1 & t < t2));
end

function v = degerAn(s, tq)
    i = find(s.t <= tq, 1, 'last');
    if isempty(i), v = NaN; else, v = s.x(i); end
end

function s = redYaz(m)
    if m == 0, s = ''; return; end
    p = {};
    if bitand(m,1), p{end+1} = 'bekleme süresi dolmadı'; end
    if bitand(m,2), p{end+1} = 'tahmini yük > P_geri'; end
    if bitand(m,4), p{end+1} = 'gerilim aralık dışı / kararsız'; end
    if bitand(m,8), p{end+1} = 'şebeke yok'; end
    s = strjoin(p, '; ');
end

function s = secim(kosul, a, b)
    if kosul, s = a; else, s = b; end
end

function [logs, sure, hataMsj] = modeliCalistir(mdl, kayit, sen, tStop)
    % veri_aktar / test_* ile aynı yöntem: kaydı geçici açar, çalıştırır, model ayarlarını geri yükler.
    % Hata fırlatmaz; hata mesajını döndürür (çağıran fail-closed karar verir).
    logs = [];  sure = NaN;  hataMsj = '';
    tsVardi = evalin('base', 'exist(''test_senaryo'', ''var'')');
    if tsVardi, tsEski = evalin('base', 'test_senaryo'); end
    try
        acikti = bdIsLoaded(mdl);
        if acikti && strcmp(get_param(mdl, 'Dirty'), 'on')
            error('"%s" açık ve kaydedilmemiş değişiklik var. Önce kaydedin.', mdl);
        end
        load_system(mdl);
        for k = 1:size(kayit,1)
            if getSimulinkBlockHandle([mdl '/' kayit{k,1}]) == -1
                error('Blok bulunamadı: "%s/%s"', mdl, kayit{k,1});
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
        assignin('base', 'test_senaryo', sen);
        try
            tic;
            out = sim(mdl, 'ReturnWorkspaceOutputs', 'on', 'StopTime', sprintf('%.6f', tStop));
            sure = toc;
            logs = out.logsout;
        catch h
            hataMsj = h.message;
        end
        for k = size(kayit,1):-1:1
            ph = get_param([mdl '/' kayit{k,1}], 'PortHandles');  p = ph.Outport(kayit{k,2});
            set_param(p, 'DataLogging', eski{k,1}, 'DataLoggingNameMode', eski{k,2}, 'DataLoggingName', eski{k,3});
        end
        set_param(mdl, 'SignalLogging', eskiLog);
        if ~isempty(eskiPace), set_param(mdl, 'EnablePacing', eskiPace); end
        dosya = get_param(mdl, 'FileName');
        if acikti, set_param(mdl, 'Dirty', 'off'); else, close_system(mdl, 0); end
        asv = [dosya '.autosave'];
        if exist(asv, 'file'), delete(asv); end
    catch h
        if isempty(hataMsj), hataMsj = h.message; end
    end
    if tsVardi
        assignin('base', 'test_senaryo', tsEski);
    else
        evalin('base', 'clear test_senaryo');
    end
    if isempty(hataMsj) && isempty(logs), hataMsj = 'logsout boş'; end
end

%% ===================== dosya işlemleri =====================
function r = bitir(r, D, dosya, cevapAdi, cid, st, rs, kod, msj, kanit)
    simdiYerel = datetime('now', 'TimeZone', 'Europe/Istanbul', 'Format', 'yyyy-MM-dd''T''HH:mm:ssxxx');
    cevap = struct('schemaVersion', '1.0.0', 'commandId', cid, 'meterId', 'SIM-0001', ...
                   'completedAt', char(simdiYerel), 'status', st, 'relayState', rs, ...
                   'code', kod, 'message', msj);
    if ~isempty(kanit)
        kanit.commandId = cid;  kanit.status = st;  kanit.code = kod;
        atomikYaz(fullfile(D.kanit, [cevapAdi '.json']), jsonencode(kanit, 'PrettyPrint', true));
    end
    atomikYaz(fullfile(D.giden, [cevapAdi '.json']), jsonencode(cevap, 'PrettyPrint', true));
    tasi(dosya, D.islenen, '');
    defterYaz(D.defter, cid, r.dosya, st, kod);
    r.status = st;  r.code = kod;  r.relayState = rs;
end

function atomikYaz(hedef, metin)
    gecici = [hedef '.tmp'];
    fid = fopen(gecici, 'w', 'n', 'UTF-8');
    if fid < 0, error('Yazılamadı: %s', gecici); end
    fprintf(fid, '%s\n', metin);
    fclose(fid);
    [ok, m] = movefile(gecici, hedef, 'f');
    if ~ok, error('Yeniden adlandırılamadı: %s (%s)', hedef, m); end
end

function tasi(dosya, klasor, ek)
    [~, ad, uz] = fileparts(dosya);
    hedef = fullfile(klasor, [ad ek uz]);
    if exist(hedef, 'file')
        hedef = fullfile(klasor, [ad ek '_' char(datetime('now', 'Format', 'yyyyMMddHHmmssSSS')) uz]);
    end
    movefile(dosya, hedef, 'f');
end

function var = defterdeVar(defter, cid)
    var = false;
    if ~exist(defter, 'file'), return; end
    satirlar = splitlines(fileread(defter));
    var = any(startsWith(satirlar, [cid ',']));
end

function defterYaz(defter, cid, dosya, st, kod)
    yeni = ~exist(defter, 'file');
    fid = fopen(defter, 'a', 'n', 'UTF-8');
    if yeni, fprintf(fid, 'commandId,dosya,status,code,zaman\n'); end
    fprintf(fid, '%s,%s,%s,%s,%s\n', cid, dosya, st, kod, ...
            char(datetime('now', 'TimeZone', 'Europe/Istanbul', 'Format', 'yyyy-MM-dd''T''HH:mm:ssxxx')));
    fclose(fid);
end
