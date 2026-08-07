// Müşteri ilişkisi bildirim kuralları — Faz 1.
//
// Kurallar SAFTIR: veritabanı yok, widget yok, sahte zaman yok. Girdi veri, çıktı metin.
// Bu yüzden testler de düz `test()` — drift akışlarının sahte zaman sorunları buraya hiç girmez.
//
// Testlerin çoğu "SUSMALI" diyor. Bilinçli: yanlış bildirim özelliğin tamamını çöpe atar,
// kaçan bildirim yarın yeniden denenir.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/kurallar/musteri_kurallari.dart';

/// Sabit "bugün" — testler takvimden bağımsız olsun.
final DateTime bugun = DateTime(2026, 7, 27);

/// [araliklar] gün cinsinden teslimatlar arası boşluklar (n aralık → n+1 teslimat).
/// Son teslim [sonTeslimdenBeriGun] gün önce yapılmış sayılır.
MusteriGecmisi musteri({
  String id = 'm1',
  String ad = 'Ahmet Yılmaz',
  required List<int> araliklar,
  required int sonTeslimdenBeriGun,
  bool acikSiparis = false,
}) {
  final gunler = <DateTime>[bugun.subtract(Duration(days: sonTeslimdenBeriGun))];
  for (final a in araliklar.reversed) {
    gunler.insert(0, gunler.first.subtract(Duration(days: a)));
  }
  return MusteriGecmisi(
    customerId: id,
    ad: ad,
    teslimGunleri: gunler,
    acikSiparisVar: acikSiparis,
  );
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Ritim ölçümü
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('musteriRitmi', () {
    test('ORTANCA kullanır — tek uzun ara ritmi bozmaz', () {
      // Tatilde 90 gün ara vermiş 15 günlük müşteri. Ortalama 31 derdi ve müşteri bir daha
      // ASLA gecikmiş görünmezdi; ortanca 15 der.
      final r = musteriRitmi(
        musteri(araliklar: [4, 15, 15, 90], sonTeslimdenBeriGun: 5),
        bugun: bugun,
      );
      expect(r, isNotNull);
      expect(r!.ortancaGun, 15, reason: 'ortalama 31 olurdu — ortanca aykırı değeri yutar');
    });

    test('geçmişi kısa müşteride SUSAR — iki sipariş aralık değil tesadüftür', () {
      // 3 teslimat = 2 aralık; ortanca ikisinin ortalamasıdır, tek aykırı değer yine kaydırır.
      expect(
        musteriRitmi(musteri(araliklar: [15, 15], sonTeslimdenBeriGun: 40), bugun: bugun),
        isNull,
      );
    });

    test('TEK SEFERLİK müşteri hiç değerlendirilmez', () {
      expect(
        musteriRitmi(
          MusteriGecmisi(
            customerId: 'm9',
            ad: 'Bir Kerelik',
            teslimGunleri: [bugun.subtract(const Duration(days: 200))],
          ),
          bugun: bugun,
        ),
        isNull,
      );
    });

    test('DÜZENSİZ müşteride SUSAR — ortancası anlamsızdır', () {
      // 2 · 40 · 5 · 45 gün: ortanca (22,5) hiçbir aralığa benzemiyor, "geciktin" demek kesin
      // yanlış olurdu. MAD ortancanın yarısını aşıyor → kural susuyor.
      expect(
        musteriRitmi(musteri(araliklar: [2, 40, 5, 45], sonTeslimdenBeriGun: 60), bugun: bugun),
        isNull,
      );
    });

    test('TEK aykırı aralık düzenliliği bozmaz — MAD dayanıklıdır', () {
      // 2 · 40 · 5 · 3: dört aralığın üçü 2-5 gün, biri 40. Ortanca 4 der ve bu DOĞRUDUR;
      // tek anomaliyi "bu müşteri düzensiz" diye okumak, gerçek düzeni olan müşteriyi
      // sonsuza dek görünmez yapardı. Ortalama burada 12,5 derdi.
      final r = musteriRitmi(
        musteri(araliklar: [2, 40, 5, 3], sonTeslimdenBeriGun: 4),
        bugun: bugun,
      );
      expect(r, isNotNull);
      expect(r!.ortancaGun, 4);
    });

    test('BEKLEYEN siparişi olan müşteri değerlendirilmez', () {
      // Zaten sipariş vermiş, kurye yolda. Bunu atlamak en utandırıcı yanlış olurdu.
      expect(
        musteriRitmi(
          musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 40, acikSiparis: true),
          bugun: bugun,
        ),
        isNull,
      );
    });

    test('bandın dışındaki ritimler değerlendirilmez', () {
      // Günde birkaç kez alanın döngüsü yok; dört ayda bir alan zaten uykuda.
      expect(musteriRitmi(musteri(araliklar: [1, 1, 1], sonTeslimdenBeriGun: 3), bugun: bugun),
          isNull);
      expect(
          musteriRitmi(musteri(araliklar: [150, 150, 150], sonTeslimdenBeriGun: 400),
              bugun: bugun),
          isNull);
    });

    test('çok düzenli müşteride eşik = ortanca + %40', () {
      final r = musteriRitmi(
        musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 1),
        bugun: bugun,
      );
      expect(r!.gecikmeEsigiGun, 21, reason: '15 + 6; 22. günde bildirilir');
    });

    test('pay üst sınırı uzun aralıklı müşteride devreye girer', () {
      // 90 günlük müşteride oransal pay 36 gün olurdu — bildirim 4 ay sonra çıkardı.
      final r = musteriRitmi(
        musteri(araliklar: [90, 90, 90], sonTeslimdenBeriGun: 1),
        bugun: bugun,
      );
      expect(r!.gecikmeEsigiGun, 120, reason: '90 + 30 (tavan)');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Gecikme eşiği
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('gecikmisMusteriler', () {
    test('eşiğin ALTINDA susar, ÜSTÜNDE bildirir (sahadan gelen 15/22 örneği)', () {
      final erken = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 21);
      expect(gecikmisMusteriler([erken], bugun: bugun), isEmpty,
          reason: '21 gün eşiğe eşit — henüz gecikme değil');

      final gec = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 22);
      expect(gecikmisMusteriler([gec], bugun: bugun).single.sonTeslimdenBeriGun, 22);
    });

    test('sıralama ORANA göre — kısa döngülü müşterinin sessizliği daha alarm verici', () {
      final haftalik = musteri(
          id: 'h', ad: 'Haftalık Hasan', araliklar: [7, 7, 7], sonTeslimdenBeriGun: 14);
      final ikiAylik = musteri(
          id: 'i', ad: 'İki Aylık İrem', araliklar: [60, 60, 60], sonTeslimdenBeriGun: 100);

      final sira = gecikmisMusteriler([ikiAylik, haftalik], bugun: bugun)
          .map((r) => r.gecmis.customerId)
          .toList();
      expect(sira, ['h', 'i'],
          reason: '14/10 oranı 100/84 oranından büyük — ham gün sayısı yanıltıcı olurdu');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // İki kuralın ÇAKIŞMAMASI
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('rutin ve gecikme kesişmez', () {
    test('rutin günü TAM ortancada, bir kez', () {
      final tam = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 15);
      expect(rutinGunuGelenler([tam], bugun: bugun), hasLength(1));
      expect(gecikmisMusteriler([tam], bugun: bugun), isEmpty);
    });

    test('bekleme bandında İKİSİ DE susar', () {
      // 16-21 gün arası: rutin günü geçti, gecikme sayılacak kadar geç değil.
      for (final gun in [16, 18, 21]) {
        final m = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: gun);
        expect(rutinGunuGelenler([m], bugun: bugun), isEmpty, reason: '$gun gün');
        expect(gecikmisMusteriler([m], bugun: bugun), isEmpty, reason: '$gun gün');
      }
    });

    test('gecikmiş müşteri rutin listesine GİRMEZ', () {
      final gec = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 30);
      expect(gecikmisMusteriler([gec], bugun: bugun), hasLength(1));
      expect(rutinGunuGelenler([gec], bugun: bugun), isEmpty);
    });

    test('aynı müşteri aynı gün iki listede birden bulunamaz', () {
      // Kesişimin BOŞ olduğu, tek tek gün denemek yerine bütün pencerede kanıtlanır.
      for (var gun = 1; gun <= 60; gun++) {
        final m = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: gun);
        final rutin = rutinGunuGelenler([m], bugun: bugun).isNotEmpty;
        final gecikmis = gecikmisMusteriler([m], bugun: bugun).isNotEmpty;
        expect(rutin && gecikmis, isFalse, reason: '$gun günde iki bildirim birden');
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Bildirim metni — ÇOKLU müşteride TEK bildirim
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('gecikmisMusteriBildirimi', () {
    test('gecikme yoksa SUSAR — "bugün gecikme yok" da gürültüdür', () {
      final m = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 3);
      expect(gecikmisMusteriBildirimi([m], bugun: bugun), isNull);
      expect(gecikmisMusteriBildirimi([], bugun: bugun), isNull);
    });

    test('tek müşteride ad GÖVDEDE, başlık NÖTR', () {
      final m = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 22);
      final b = gecikmisMusteriBildirimi([m], bugun: bugun)!;
      expect(b.kategori, BildirimKategori.musteriGecikti);
      expect(b.baslik, 'Bir müşteri gecikti');
      expect(b.baslik, isNot(contains('Ahmet')),
          reason: 'başlık bildirim rafında bir bakışta okunur — müşteri adı taşıyamaz; '
              'telefonu birine uzatınca görülür');
      expect(b.govde,
          'Ahmet Yılmaz 22 gündür sipariş vermedi · normalde 15 günde bir alıyordu.');
      expect(b.yol, 'musteri/m1');
    });

    test('çoklu bildirimde ad HİÇBİR başlıkta geçmez', () {
      final iki = [
        musteri(id: 'a', ad: 'Ahmet Yılmaz', araliklar: [15, 15, 15], sonTeslimdenBeriGun: 30),
        musteri(id: 'b', ad: 'Ayşe Kaya', araliklar: [15, 15, 15], sonTeslimdenBeriGun: 25),
      ];
      final b = gecikmisMusteriBildirimi(iki, bugun: bugun)!;
      expect(b.baslik, '2 müşteri gecikti', reason: 'sayı kişisel veri değildir');
      expect(b.govde, 'Ahmet Yılmaz (30 gün), Ayşe Kaya (25 gün)');
      expect(b.yol, isNull, reason: 'Faz 1 yol sözlüğünde çok-müşterili liste rotası yok');
    });

    test('20 müşteri gecikse bile TEK bildirim, en kritik üç ad', () {
      final cok = [
        for (var i = 0; i < 20; i++)
          musteri(
            id: 'm$i',
            ad: 'Müşteri $i',
            araliklar: const [15, 15, 15],
            // i büyüdükçe daha çok gecikmiş → sıralama başa taşır.
            sonTeslimdenBeriGun: 22 + i,
          ),
      ];
      final b = gecikmisMusteriBildirimi(cok, bugun: bugun)!;
      expect(b.baslik, '20 müşteri gecikti');
      expect(b.govde, startsWith('Müşteri 19 (41 gün), Müşteri 18 (40 gün), Müşteri 17'));
      expect(b.govde, endsWith('ve 17 kişi daha'));
    });

    test('kimlik gün başına kararlı — aynı gün ikinci kez hesaplanırsa bildirim ikizlenmez', () {
      final m = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 22);
      final a = gecikmisMusteriBildirimi([m], bugun: bugun)!;
      final b = gecikmisMusteriBildirimi([m], bugun: bugun)!;
      expect(a.kimlik, b.kimlik);
      // Kimlik ELLE kurulmaz — sözleşmenin üreticisi kategori önekini garanti eder.
      expect(a.kimlik,
          bildirimKimligi(BildirimKategori.musteriGecikti, bildirimGunAnahtari(bugun)));
      expect(a.kimlik, 'musteri_gecikti:2026-07-27');
    });

    test('kategori kapalıyken altyapı sessizce atlar — kural yine doğru taslağı üretir', () async {
      // Sözleşme: `goster` kategori kapalıysa çizmez. Kural bunu BİLMEZ ve dallanmaz.
      final servis = SahteBildirimServisi(
        kapaliKategoriler: {BildirimKategori.musteriGecikti},
      );
      final m = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 22);
      await servis.goster(gecikmisMusteriBildirimi([m], bugun: bugun)!);
      expect(servis.gosterilenler, isEmpty);

      final acik = SahteBildirimServisi();
      await acik.goster(gecikmisMusteriBildirimi([m], bugun: bugun)!);
      expect(acik.gosterilenler.single.kategori, BildirimKategori.musteriGecikti);
    });

    test('aynı kimlik ÜZERİNE YAZAR — gün içinde iki kez koşmak iki satır açmaz', () async {
      final servis = SahteBildirimServisi();
      final m = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 22);
      await servis.goster(gecikmisMusteriBildirimi([m], bugun: bugun)!);
      final sonra = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 23);
      await servis.goster(gecikmisMusteriBildirimi([sonra], bugun: bugun)!);

      expect(servis.gosterilenler, hasLength(1), reason: 'tek bildirim, tazelenmiş');
      expect(servis.gosterilenler.single.govde, contains('23 gündür'));
    });
  });

  group('rutinTeslimBildirimi', () {
    test('kimse yoksa SUSAR', () {
      final m = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 3);
      expect(rutinTeslimBildirimi([m], bugun: bugun), isNull);
    });

    test('başlık her zaman SAYI taşır, adlar gövdede kalır', () {
      final tek = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 15);
      final t = rutinTeslimBildirimi([tek], bugun: bugun)!;
      expect(t.baslik, 'Bugün 1 rutin teslim var');
      expect(t.govde, 'Ahmet Yılmaz · normalde 15 günde bir alıyor.');
      expect(t.yol, 'musteri/m1');

      final coklu = [
        for (var i = 0; i < 12; i++)
          musteri(
              id: 'm$i',
              ad: 'Müşteri ${i.toString().padLeft(2, '0')}',
              araliklar: const [10, 10, 10],
              sonTeslimdenBeriGun: 10),
      ];
      final b = rutinTeslimBildirimi(coklu, bugun: bugun)!;
      expect(b.kategori, BildirimKategori.rutinTeslimGunu);
      expect(b.baslik, 'Bugün 12 rutin teslim var');
      expect(b.govde, 'Müşteri 00, Müşteri 01, Müşteri 02 · ve 9 kişi daha');
      expect(b.kimlik, 'rutin_teslim_gunu:2026-07-27');
    });

    test('12 müşteri TEK bildirim üretir — kategori başına günlük sınır 2', () {
      // Müşteri başına taslak üretilseydi üçüncüsü sessizce düşerdi.
      final coklu = [
        for (var i = 0; i < 12; i++)
          musteri(id: 'm$i', ad: 'M$i', araliklar: const [10, 10, 10], sonTeslimdenBeriGun: 10),
      ];
      expect(rutinGunuGelenler(coklu, bugun: bugun), hasLength(12));
      expect(rutinTeslimBildirimi(coklu, bugun: bugun), isNotNull);
    });

    test('bekleyen siparişi olan müşteri rutin listesinde görünmez', () {
      final m = musteri(araliklar: [15, 15, 15], sonTeslimdenBeriGun: 15, acikSiparis: true);
      expect(rutinTeslimBildirimi([m], bugun: bugun), isNull);
    });
  });
}
