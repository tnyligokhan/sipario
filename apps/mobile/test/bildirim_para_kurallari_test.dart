// Para/veresiye bildirim KURALLARI. Kural saf olduğu için testler de saf: sahte saat, sahte
// veritabanı, widget yok — girdi ver, çıktıyı sına.
//
// ⚠️ BU DOSYA KÜÇÜLDÜ (2026-08-14): borç eşiği (geçiş yüklemi + günlük özet) ve vadesi geçen
// borç (FIFO alacak yaşlandırması) testleri, ölçtükleri kurallarla birlikte kaldırıldı.
// Geriye tek yerel para kuralı kaldı: gün sonu özeti.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/kurallar/para_kurallari.dart';

void main() {
  group('gunSonuOzeti', () {
    GunSonuVerisi veri({int tahsilat = 0, int teslim = 0, int veresiye = 0}) => GunSonuVerisi(
          gun: DateTime(2026, 7, 27),
          tahsilatKurus: tahsilat,
          teslimatSayisi: teslim,
          veresiyeKurus: veresiye,
        );

    test('hiç hareket olmayan günde bildirim ATILMAZ', () {
      expect(gunSonuOzeti(veri()), isNull, reason: 'boş bildirim gürültüdür');
    });

    test('tek bir hareket bile varsa bildirim atılır', () {
      expect(gunSonuOzeti(veri(teslim: 1)), isNotNull);
      expect(gunSonuOzeti(veri(tahsilat: 100)), isNotNull);
      expect(gunSonuOzeti(veri(veresiye: 100)), isNotNull);
    });

    test('üç rakam da metinde ve KURUŞUYLA yazılır', () {
      final b = gunSonuOzeti(veri(tahsilat: 124000, teslim: 8, veresiye: 34000))!;
      expect(b.govde, contains('1.240,00 ₺'));
      expect(b.govde, contains('8 teslim'));
      expect(b.govde, contains('340,00 ₺'));
      expect(b.kategori, BildirimKategori.gunSonuOzeti);
    });

    test('BAŞLIK nötrdür — kilit ekranında tutar sızmaz', () {
      final b = gunSonuOzeti(veri(tahsilat: 124000, teslim: 8))!;
      expect(b.baslik, 'Gün özeti');
      expect(b.baslik, isNot(contains('₺')));
    });

    test('kimlik TR takvim günüdür — aynı gün iki kez tetiklense tek bildirim', () {
      final a = gunSonuOzeti(veri(teslim: 1))!;
      final b = gunSonuOzeti(veri(teslim: 5, tahsilat: 999))!;
      expect(a.kimlik, b.kimlik, reason: 'gün içinde tekrar tetiklenirse bastırılmalı');
      expect(a.kimlik, 'gun_sonu_ozeti:2026-07-27');
    });

    test('dokunuş gün sonu ekranına gider', () {
      final b = gunSonuOzeti(veri(teslim: 1))!;
      expect(bildirimYoluCoz(b.yol), (tur: 'gunsonu', id: null));
    });
  });

  group('taslak servise verildiğinde', () {
    test('kategori kapalıysa taslak üretilir ama GÖSTERİLMEZ (kural dallanmaz)', () async {
      // Kural fonksiyonu "gösterildi mi" diye sormaz; kısma kararı altyapınındır.
      final servis = SahteBildirimServisi(
        kapaliKategoriler: {BildirimKategori.gunSonuOzeti},
      );

      final taslak = gunSonuOzeti(GunSonuVerisi(
        gun: DateTime(2026, 7, 27),
        tahsilatKurus: 5000,
        teslimatSayisi: 2,
        veresiyeKurus: 0,
      ));

      expect(taslak, isNotNull);
      await servis.goster(taslak!);
      expect(servis.gosterilenler, isEmpty);
    });
  });
}
