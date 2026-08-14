// DURUM bildirim kuralları (2026-08-14): senkron uyarısı · kullanım hakkı · kapanış
// hatırlatmaları. Kurallar saf olduğu için testler de saf.
//
// Bu dosyanın çoğu testi kuralın SUSTUĞU durumu kilitler. Sebep ürünle ilgili: üçü de
// "eksik kalan bir şey" söylüyor ve yanlış yere düşen böyle bir uyarı, bayiye olmayan bir işi
// yaptırmaya çalışır. Bir kez yaşandığında bildirimlerin tamamına olan güven gider.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/kurallar/durum_kurallari.dart';

void main() {
  final simdi = DateTime(2026, 8, 14, 10);

  group('senkronUyarisi', () {
    test('eşiğin altında SUSAR — kısa kopukluk bu üründe normaldir', () {
      // BRIEF: tipik kopukluk 10 dakika, azami birkaç saat (bodrum, asansör, sinyal çukuru).
      expect(
        senkronUyarisi(sonBasariliSenkron: simdi.subtract(const Duration(hours: 5)), simdi: simdi),
        isNull,
      );
      expect(
        senkronUyarisi(
            sonBasariliSenkron: simdi.subtract(const Duration(days: 1, hours: 20)), simdi: simdi),
        isNull,
      );
    });

    test('iki gün ve üstünde uyarır, gün sayısını yazar', () {
      final t = senkronUyarisi(
        sonBasariliSenkron: simdi.subtract(const Duration(days: 3)),
        simdi: simdi,
      );

      expect(t, isNotNull);
      expect(t!.kategori, BildirimKategori.sistem);
      expect(t.govde, contains('3 gün'));
    });

    test('HİÇ senkron olmamışsa SUSAR', () {
      // Yeni kurulmuş, henüz bir kez bile bağlanmamış cihazı "2 gündür bağlanamıyor" diye
      // korkutmak yanlış olurdu.
      expect(senkronUyarisi(sonBasariliSenkron: null, simdi: simdi), isNull);
    });

    test('detay önce İÇİNİ RAHATLATIR, sonra iş buyurur', () {
      // Bu uyarıyı gören esnafın ilk düşüncesi "verilerim gitti mi?" olur.
      final t = senkronUyarisi(
        sonBasariliSenkron: simdi.subtract(const Duration(days: 2)),
        simdi: simdi,
      )!;

      expect(t.detay, isNotNull);
      expect(t.detay, contains('kaybolmaz'));
      expect(t.detay!.indexOf('kaybolmaz'), lessThan(t.detay!.indexOf('İnternet')));
    });

    test('kimlik GÜN bazlı — gün içinde tekrar koşmak yeni bildirim doğurmaz', () {
      final a = senkronUyarisi(
          sonBasariliSenkron: simdi.subtract(const Duration(days: 2)), simdi: simdi)!;
      final b = senkronUyarisi(
          sonBasariliSenkron: simdi.subtract(const Duration(days: 2)),
          simdi: DateTime(2026, 8, 14, 18))!;

      expect(a.kimlik, b.kimlik);
    });
  });

  group('kullanimHakkiUyarisi', () {
    final gun = DateTime(2026, 8, 14);

    test('aylık kota 0 ise özellik o bayide YOK — hiç uyarmaz', () {
      // Olmayan bir özelliğin bittiğini haber vermek, var olduğunu sandırırdı.
      expect(kullanimHakkiUyarisi(kalan: 0, aylik: 0, gun: gun), isNull);
    });

    test('hak boldayken susar', () {
      expect(kullanimHakkiUyarisi(kalan: 20, aylik: 30, gun: gun), isNull);
    });

    test('eşiğe inince uyarır', () {
      final t = kullanimHakkiUyarisi(kalan: 3, aylik: 30, gun: gun);
      expect(t, isNotNull);
      expect(t!.baslik, contains('azaldı'));
      expect(t.govde, contains('3'));
    });

    test('bitince farklı konuşur ve ne yapılacağını söyler', () {
      final t = kullanimHakkiUyarisi(kalan: 0, aylik: 30, gun: gun)!;
      expect(t.baslik, contains('bitti'));
      expect(t.detay, contains('elle sıralamaya devam'));
      expect(t.detay, contains('ay başında yenilenir'));
    });

    test('⚠️ MAĞAZA KURALI: fiyat, satın alma ya da yönlendirme YOK', () {
      // BRIEF pazarlıksız: mobil uygulamada fiyat, "abone ol", paket satışı ya da siteye
      // yönlendirme bulunamaz. Bu kural bir SATIN ALMA TEŞVİKİNE dönüşürse mağaza reddi
      // riski doğar — sınır burada, testle kilitli.
      for (final t in [
        kullanimHakkiUyarisi(kalan: 0, aylik: 30, gun: gun)!,
        kullanimHakkiUyarisi(kalan: 2, aylik: 30, gun: gun)!,
      ]) {
        final metin = '${t.baslik} ${t.govde} ${t.detay ?? ''}'.toLowerCase();
        for (final yasak in [
          'satın', 'satin', '₺', 'tl', 'fiyat', 'paket al', 'abone', 'üyelik', 'uyelik',
          'sipario.com', 'http', 'web sitesi', 'siteden',
        ]) {
          expect(metin.contains(yasak), isFalse, reason: 'yasak sözcük: $yasak');
        }
      }
    });
  });

  group('kasaDevriHatirlatmasi', () {
    final gun = DateTime(2026, 8, 14);

    test('devredilecek para yoksa SUSAR', () {
      expect(kasaDevriHatirlatmasi(kuryedeKalanKurus: 0, kuryeSayisi: 1, gun: gun), isNull);
    });

    test('NEGATİF bakiye de sessizdir', () {
      // Kurye kendi cebinden ara tahsilat vermiş olabilir; bu bir eksiklik değildir.
      expect(kasaDevriHatirlatmasi(kuryedeKalanKurus: -5000, kuryeSayisi: 1, gun: gun), isNull);
    });

    test('tek kuryede sayı yazmaz, tutarı yazar', () {
      final t = kasaDevriHatirlatmasi(kuryedeKalanKurus: 45000, kuryeSayisi: 1, gun: gun)!;
      expect(t.govde, contains('450,00 ₺'));
      expect(t.govde, isNot(contains('1 kurye')));
    });

    test('çok kuryede sayı ve toplam yazar', () {
      final t = kasaDevriHatirlatmasi(kuryedeKalanKurus: 45000, kuryeSayisi: 3, gun: gun)!;
      expect(t.govde, contains('3 kuryede'));
      expect(t.govde, contains('450,00 ₺'));
    });

    test('BAŞLIK nötrdür — kilit ekranında tutar sızmaz', () {
      final t = kasaDevriHatirlatmasi(kuryedeKalanKurus: 45000, kuryeSayisi: 1, gun: gun)!;
      expect(t.baslik, isNot(contains('₺')));
    });
  });

  group('gunKapatilmadiHatirlatmasi', () {
    final dun = DateTime(2026, 8, 13);

    test('kapatıldıysa SUSAR', () {
      expect(
        gunKapatilmadiHatirlatmasi(dunKapatildi: true, dunHareketVardi: true, dun: dun),
        isNull,
      );
    });

    test('HAREKETSİZ gün kapatılmaz — bu bir eksiklik değildir', () {
      // Bayi pazar günü çalışmamıştır; uyarmak tatilde iş buyurmak olurdu.
      expect(
        gunKapatilmadiHatirlatmasi(dunKapatildi: false, dunHareketVardi: false, dun: dun),
        isNull,
      );
    });

    test('hareketli ve kapatılmamış günde uyarır, SEBEBİNİ söyler', () {
      final t = gunKapatilmadiHatirlatmasi(
        dunKapatildi: false,
        dunHareketVardi: true,
        dun: dun,
      )!;

      expect(t.kategori, BildirimKategori.gunKapanisHatirlatma);
      expect(t.detay, contains('bugünün rakamlarına karışır'));
      expect(bildirimYoluCoz(t.yol), (tur: 'gunsonu', id: null));
    });

    test('iki kapanış hatırlatması AYNI kategoride ama AYRI kimlikte', () {
      // Aynı kategoride olmaları ayar ekranını sadeleştirir; ayrı kimlikte olmaları ise
      // birinin diğerinin üzerine yazmasını engeller — akşam "kasa devredilmedi" çıkıp
      // sabah "gün kapatılmadı" geldiğinde bayi ikisini de görmeli.
      final kasa = kasaDevriHatirlatmasi(
        kuryedeKalanKurus: 1000,
        kuryeSayisi: 1,
        gun: dun,
      )!;
      final kapanis = gunKapatilmadiHatirlatmasi(
        dunKapatildi: false,
        dunHareketVardi: true,
        dun: dun,
      )!;

      expect(kasa.kategori, kapanis.kategori);
      expect(kasa.kimlik, isNot(kapanis.kimlik));
    });
  });
}
