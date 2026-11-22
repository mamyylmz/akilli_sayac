function h = sha256_dosya(dosya)
%SHA256_DOSYA  Bir dosyanın SHA-256 özetini küçük harfli onaltılık metin olarak döndürür.
% Konum : Akilli_Sayac/simulink/sha256_dosya.m
% Kullanım: h = sha256_dosya('ciktilar/model/olcum_1dk_2026-11-22.csv')
% Dosyanın baytları olduğu gibi okunur (satır sonları dahil). Hesaplanamazsa '' döner.
% Doğrulama (Windows komut satırı): certutil -hashfile <dosya> SHA256

fid = fopen(dosya, 'r');
if fid < 0, error('Dosya açılamadı: %s', dosya); end
b = fread(fid, inf, '*uint8');
fclose(fid);

h = '';
try                                             % 1. yol: Java (MATLAB ile gelir)
    md = java.security.MessageDigest.getInstance('SHA-256');
    d  = typecast(md.digest(b), 'uint8');
    h  = lower(reshape(dec2hex(d, 2)', 1, []));
catch
    try                                         % 2. yol: .NET (Windows)
        sha = System.Security.Cryptography.SHA256.Create();
        d   = uint8(sha.ComputeHash(b));
        h   = lower(reshape(dec2hex(d, 2)', 1, []));
    catch
        warning('SHA-256 hesaplanamadı: %s', dosya);
    end
end
end
