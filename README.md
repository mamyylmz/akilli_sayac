# Akıllı Sayaç

Akıllı Sayaç, mevcut tek fazlı 230 V / 50 Hz Simulink modelini koruyan, yerel ve çevrimdışı
çalışmak üzere tasarlanmış bir yazılım ve siber güvenlik altyapısıdır. Fiziksel şebekeye veya
üçüncü taraf bir sisteme bağlanmaz.

## Bileşenler

- `simulink/`: Değiştirilmeden korunan MATLAB/Simulink elektriksel model ve A–C testleri.
- `packages/contracts`: Zod tabanlı AMI, ölçüm, enerji, durum ve komut sözleşmeleri.
- `packages/security`: HMAC-SHA256, canonical JSON, yetkilendirme ve röle güvenlik politikası.
- `packages/billing`: T1/T2/T3 için tamsayı tabanlı demonstrasyon fatura motoru.
- `apps/api`: Fastify, SQLite head-end/MDM ve güvenli komut akışı.
- `apps/web`: React tabanlı temel HAN ekranı.

Arayüzdeki fixture verileri açıkça **Synthetic / Simulated** olarak gösterilir. Örnek fiyatlar
geçerli EPDK tarifesi değildir. Reaktif ceza veya kompanzasyon hesaplanmaz.

Kurulum için `docs/SETUP.md`, tasarım için `docs/ARCHITECTURE.md`, güvenlik sınırları için
`docs/SECURITY.md`, doğrulama durumu için `docs/TEST_RESULTS.md` ve Simulink aktarımı için
`docs/INTEGRATION.md` belgelerine bakın.
