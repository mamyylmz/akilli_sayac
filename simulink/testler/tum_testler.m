function tum_testler()
%TUM_TESTLER  Akıllı Sayaç Simulink testlerinin hepsini sırayla çalıştırır ve özetler.
% Kullanım: simulink klasöründeyken  addpath testler  ve  tum_testler  (~6 dk)
% Model kaydedilmiş olmalıdır (Ctrl+S). Her test kendi sonuç dosyasını testler/ klasörüne yazar.

testDir = fileparts(mfilename('fullpath'));
liste = { 'test_dogrulama',      'test_sonuclari.md',   'A–C ölçüm, enerji, tarife (measurement_test)';
          'test_D_koruma',       'test_D_sonuclari.md', 'D koruma ve röle (6 senaryo)';
          'test_B_batarya',      'test_B_sonuclari.md', 'Batarya';
          'test_E_guc_kalitesi', 'test_E_sonuclari.md', 'E güç kalitesi (kesinti, çökme, yükselme)';
          'test_F_talep',        'test_F_sonuclari.md', 'F talep yönetimi (yük kaydırma)' };
sonuc = cell(size(liste,1), 1);
for k = 1:size(liste,1)
    fprintf('\n================ %s ================\n', liste{k,1});
    try
        tekTest(fullfile(testDir, [liste{k,1} '.m']));
        sonuc{k} = ozetOku(fullfile(testDir, liste{k,2}));
    catch hata
        sonuc{k} = ['HATA: ' hata.message];
    end
end
fprintf('\n================ GENEL ÖZET (%s) ================\n', char(datetime('now')));
for k = 1:size(liste,1)
    fprintf('%-22s %-46s %s\n', liste{k,1}, liste{k,3}, sonuc{k});
end
end

function tekTest(dosya)
    % Her test kendi çalışma alanında çalışır; testlerin "clear" komutu bu fonksiyonu etkilemez.
    run(dosya);
end

function s = ozetOku(dosya)
    s = 'özet bulunamadı';
    if ~exist(dosya, 'file'), return; end
    satirlar = splitlines(fileread(dosya));
    i = find(contains(satirlar, 'Özet:'), 1);
    if ~isempty(i), s = strtrim(erase(erase(satirlar{i}, '- Özet:'), '*')); end
end
