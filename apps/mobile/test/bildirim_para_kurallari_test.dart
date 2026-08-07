// Para/veresiye bildirim KURALLARI (Faz 1). Kurallar saf olduğu için testler de saf: sahte saat,
// sahte veritabanı, widget yok — girdi ver, çıktıyı sına.
//
// En kritik iki davranış: (1) borç eşiği MÜKERRER bildirim üretmemeli, (2) "30 gün" ölçüsü FIFO
// yaşlandırmayla hesaplanmalı — düzenli ödeyen müşteri gecikmiş görünmemeli, sembolik ödeme
// yapan müşteri de temiz görünmemeli.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/kurallar/para_kurallari.dart';

DefterHareketi _h(DateTime t, int kurus) =>
    DefterHareketi(occurredAt: t, amountKurus: kurus);

void main() {
  final simdi = DateTime.utc(2026, 7, 27, 12);
  DateTime gunOnce(int n) => simdi.subtract(Duration(days: n));

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 1) Gün sonu özeti
  // ═════════════════════════════════════════════════════════════════════════════════════════

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

    test('kimlik TR takvim günüdür — aynı gün iki kez tetiklense tek bildirim', () {
      final a = gunSonuOzeti(veri(teslim: 1))!;
      final b = gunSonuOzeti(veri(teslim: 5, tahsilat: 999))!;
      expect(a.kimlik, b.kimlik, reason: 'gün içinde tekrar tetiklenirse bastırılmalı');
      expect(a.kimlik, 'gun_sonu_ozeti:2026-07-27');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 2) Borç eşiği — MÜKERRER BİLDİRİM OLMAMALI
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('esikAsildiMi (geçiş/edge yüklemi)', () {
    BorcEsigiOlayi olay(int onceki, int yeni) => BorcEsigiOlayi(
          customerId: 'm1',
          ad: 'Mehmet Usta',
          oncekiBakiyeKurus: onceki,
          yeniBakiyeKurus: yeni,
          occurredAtIso: '2026-07-27T10:00:00Z',
        );

    test('eşiğin altından üstüne geçişte true', () {
      expect(esikAsildiMi(olay(190000, 205000), esikKurus: 200000), isTrue);
    });

    test('ZATEN eşiğin üstündeyken borç artarsa false', () {
      expect(esikAsildiMi(olay(205000, 260000), esikKurus: 200000), isFalse,
          reason: 'mükerrer bildirimin kökten çözümü: seviye değil GEÇİŞ görülür');
    });

    test('eşiğin altında kalan artış false', () {
      expect(esikAsildiMi(olay(100000, 150000), esikKurus: 200000), isFalse);
    });

    test('borç azalırken false', () {
      expect(esikAsildiMi(olay(260000, 205000), esikKurus: 200000), isFalse);
    });

    test('eşik tam yakalandığında true (>=)', () {
      expect(esikAsildiMi(olay(199999, 200000), esikKurus: 200000), isTrue);
    });

    test('altına düşüp TEKRAR aşmak yeni bir geçiştir', () {
      expect(esikAsildiMi(olay(205000, 150000), esikKurus: 200000), isFalse); // düşüş
      expect(esikAsildiMi(olay(150000, 210000), esikKurus: 200000), isTrue,
          reason: 'ikinci geçiş meşrudur ve yeniden bildirilmelidir');
    });

    test('eşik 0/negatifse kural kapalıdır', () {
      expect(esikAsildiMi(olay(0, 999999), esikKurus: 0), isFalse);
    });
  });

  group('borcEsigiBildirimi (GÜNLÜK TEK ÖZET — müşteri başına DEĞİL)', () {
    final gun = DateTime(2026, 7, 27);
    const esik = 200000;

    test('aşan yoksa bildirim atılmaz', () {
      expect(borcEsigiBildirimi(const [], gun: gun, esikKurus: esik), isNull);
    });

    // Faz 1 kararı: özellik VARSAYILAN OLARAK KAPALI. Bayi ayarlarda bir eşik girene kadar
    // hiçbir bildirim doğmaz — anlamsız bir varsayılan sayı uydurmak yerine sessiz kalınır.
    test('eşik girilmemişken (kapalı) aşan müşteri olsa bile bildirim ÜRETİLMEZ', () {
      expect(
        borcEsigiBildirimi(
          const [EsikAsanMusteri(customerId: 'a', ad: 'A', bakiyeKurus: 999999)],
          gun: gun,
          esikKurus: kBorcEsigiKapali,
        ),
        isNull,
      );
    });

    test('tek müşteride adı ve borcu gövdede, yol müşteri kartına gider', () {
      final b = borcEsigiBildirimi(
        const [EsikAsanMusteri(customerId: 'm1', ad: 'Mehmet Usta', bakiyeKurus: 205000)],
        gun: gun,
        esikKurus: esik,
      )!;
      expect(b.kategori, BildirimKategori.borcEsigi);
      expect(b.baslik, 'Borç eşiği aşıldı');
      expect(b.govde, contains('Mehmet Usta'));
      expect(b.govde, contains('2.050,00 ₺'));
      expect(b.yol, 'musteri/m1');
    });

    test('BAŞLIK nötrdür — kilit ekranında ad/tutar sızmaz', () {
      final b = borcEsigiBildirimi(
        const [EsikAsanMusteri(customerId: 'm1', ad: 'Mehmet Usta', bakiyeKurus: 205000)],
        gun: gun,
        esikKurus: esik,
      )!;
      expect(b.baslik, isNot(contains('Mehmet')));
      expect(b.baslik, isNot(contains('₺')));
    });

    test('çok müşteride TEK özet üretilir (kategori başına 2 sınırı yenmesin)', () {
      final b = borcEsigiBildirimi(
        const [
          EsikAsanMusteri(customerId: 'a', ad: 'A', bakiyeKurus: 205000),
          EsikAsanMusteri(customerId: 'b', ad: 'B', bakiyeKurus: 300000),
          EsikAsanMusteri(customerId: 'c', ad: 'C', bakiyeKurus: 250000),
        ],
        gun: gun,
        esikKurus: esik,
      )!;
      expect(b.govde, contains('3 müşterinin'));
      expect(b.govde, contains('7.550,00 ₺'), reason: 'toplam borç');
      expect(b.yol, isNull, reason: 'Faz 1 yol sözlüğünde borçlu listesi yok');
    });

    test('kimlik GÜN bazlıdır — gün içinde müşteri eklenirse ÜZERİNE yazar', () {
      final tek = borcEsigiBildirimi(
        const [EsikAsanMusteri(customerId: 'a', ad: 'A', bakiyeKurus: 205000)],
        gun: gun,
        esikKurus: esik,
      )!;
      final iki = borcEsigiBildirimi(
        const [
          EsikAsanMusteri(customerId: 'a', ad: 'A', bakiyeKurus: 205000),
          EsikAsanMusteri(customerId: 'b', ad: 'B', bakiyeKurus: 210000),
        ],
        gun: gun,
        esikKurus: esik,
      )!;
      expect(iki.kimlik, tek.kimlik, reason: 'aynı gün = aynı bildirim, bütçeden ikinci kez düşmez');
      expect(tek.kimlik, 'borc_esigi:2026-07-27');

      final ertesiGun = borcEsigiBildirimi(
        const [EsikAsanMusteri(customerId: 'a', ad: 'A', bakiyeKurus: 205000)],
        gun: DateTime(2026, 7, 28),
        esikKurus: esik,
      )!;
      expect(ertesiGun.kimlik, isNot(tek.kimlik));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 3) FIFO yaşlandırma — "30 gün" neye göre
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('gecikmisTutar (FIFO alacak yaşlandırma)', () {
    test('borcu olmayan müşteride 0', () {
      expect(gecikmisTutar(const [], simdi: simdi), 0);
      expect(gecikmisTutar([_h(gunOnce(60), 10000), _h(gunOnce(59), -10000)], simdi: simdi), 0);
    });

    test('30 günden yeni borç gecikmiş SAYILMAZ', () {
      expect(gecikmisTutar([_h(gunOnce(10), 50000)], simdi: simdi), 0);
    });

    test('30 günden eski ödenmemiş borç gecikmiştir', () {
      expect(gecikmisTutar([_h(gunOnce(45), 50000)], simdi: simdi), 50000);
    });

    test('DÜZENLİ ÖDEYEN müşteri gecikmiş görünmez — ödemeler EN ESKİ borcu kapatır', () {
      // Her ay borç yazılıyor ve her ay ödeniyor; bakiye hiç sıfırlanmıyor ama hep taze.
      final hareketler = [
        _h(gunOnce(90), 30000),
        _h(gunOnce(75), -30000),
        _h(gunOnce(60), 30000),
        _h(gunOnce(45), -30000),
        _h(gunOnce(20), 30000), // güncel borç, 30 günden yeni
      ];
      expect(gecikmisTutar(hareketler, simdi: simdi), 0,
          reason: '"en eski debit tarihi" ölçüsü bu iyi müşteriyi yanlışlıkla alarma sokardı');
    });

    test('SEMBOLİK ödeme yapan müşteri temiz görünmez — eski borç tüketilmeden kalır', () {
      final hareketler = [
        _h(gunOnce(120), 100000), // 1.000 ₺ eski borç
        _h(gunOnce(2), -5000), // dün 50 ₺ ödedi
      ];
      expect(gecikmisTutar(hareketler, simdi: simdi), 95000,
          reason: '"son tahsilat tarihi" ölçüsü bunu temiz gösterirdi');
    });

    test('kısmi ödeme eski borcu KISMEN tüketir, kalanı gecikmiş sayılır', () {
      final hareketler = [
        _h(gunOnce(50), 40000),
        _h(gunOnce(40), 20000),
        _h(gunOnce(5), -30000), // önce en eskiyi kapatır (40.000'in 30.000'i)
      ];
      // Kalan: eski borçtan 10.000 (50 gün) + 20.000 (40 gün) = 30.000, ikisi de 30 günden eski.
      expect(gecikmisTutar(hareketler, simdi: simdi), 30000);
    });

    test('fazla ödeme (alacaklı müşteri) gecikmiş borç üretmez', () {
      final hareketler = [_h(gunOnce(60), 20000), _h(gunOnce(5), -50000)];
      expect(gecikmisTutar(hareketler, simdi: simdi), 0);
    });

    test('gün eşiği parametreyle değişir', () {
      final h = [_h(gunOnce(20), 50000)];
      expect(gecikmisTutar(h, simdi: simdi, gunEsigi: 30), 0);
      expect(gecikmisTutar(h, simdi: simdi, gunEsigi: 15), 50000);
    });

    test('hareketler sırasız gelse de sonuç aynıdır (kural içeride sıralar)', () {
      final sirali = [_h(gunOnce(50), 40000), _h(gunOnce(5), -30000)];
      final sirasiz = [_h(gunOnce(5), -30000), _h(gunOnce(50), 40000)];
      expect(gecikmisTutar(sirasiz, simdi: simdi), gecikmisTutar(sirali, simdi: simdi));
      expect(gecikmisTutar(sirasiz, simdi: simdi), 10000);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 3b) Haftalık bildirim metni
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('vadesiGecenBorclar', () {
    final hafta = haftaninBasi(DateTime(2026, 7, 27)); // pazartesi

    test('gecikmiş müşteri yoksa bildirim ATILMAZ', () {
      expect(vadesiGecenBorclar(const [], haftaBasi: hafta), isNull);
      expect(
        vadesiGecenBorclar(
          const [GecikmisMusteri(customerId: 'a', ad: 'A', gecikmisKurus: 0)],
          haftaBasi: hafta,
        ),
        isNull,
      );
    });

    test('çok müşteride sayı ve toplam yazılır', () {
      final b = vadesiGecenBorclar(
        const [
          GecikmisMusteri(customerId: 'a', ad: 'A', gecikmisKurus: 200000),
          GecikmisMusteri(customerId: 'b', ad: 'B', gecikmisKurus: 220000),
        ],
        haftaBasi: hafta,
      )!;
      expect(b.govde, contains('2 müşterinin'));
      expect(b.govde, contains('30 günü geçti'));
      expect(b.govde, contains('4.200,00 ₺'));
    });

    test('TEK müşteride adıyla seslenir (sayı yazmak bilgi gizlemek olurdu)', () {
      final b = vadesiGecenBorclar(
        const [GecikmisMusteri(customerId: 'a', ad: 'Ayşe Yılmaz', gecikmisKurus: 150000)],
        haftaBasi: hafta,
      )!;
      expect(b.govde, contains('Ayşe Yılmaz'));
      expect(b.govde, isNot(contains('1 müşterinin')));
    });

    test('kimlik HAFTALIKtır — aynı hafta ikinci tetikleme bastırılır', () {
      final pazartesi = vadesiGecenBorclar(
          const [GecikmisMusteri(customerId: 'a', ad: 'A', gecikmisKurus: 100)],
          haftaBasi: haftaninBasi(DateTime(2026, 7, 27)))!;
      final persembe = vadesiGecenBorclar(
          const [GecikmisMusteri(customerId: 'a', ad: 'A', gecikmisKurus: 100)],
          haftaBasi: haftaninBasi(DateTime(2026, 7, 30)))!;
      expect(persembe.kimlik, pazartesi.kimlik);

      final sonrakiHafta = vadesiGecenBorclar(
          const [GecikmisMusteri(customerId: 'a', ad: 'A', gecikmisKurus: 100)],
          haftaBasi: haftaninBasi(DateTime(2026, 8, 3)))!;
      expect(sonrakiHafta.kimlik, isNot(pazartesi.kimlik),
          reason: 'borç durmuyorsa hatırlatma da durmamalı');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Sözleşmeyle uçtan uca — SahteBildirimServisi (cagri'nin test ikizi)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('taslaklar servise verildiğinde', () {
    final gun = DateTime(2026, 7, 27);

    test('gün içinde eşiği aşan müşteri eklendikçe TEK satır güncellenir (yağmur yok)', () async {
      final servis = SahteBildirimServisi();

      await servis.goster(borcEsigiBildirimi(
        const [EsikAsanMusteri(customerId: 'a', ad: 'A', bakiyeKurus: 205000)],
        gun: gun,
        esikKurus: 200000,
      )!);
      await servis.goster(borcEsigiBildirimi(
        const [
          EsikAsanMusteri(customerId: 'a', ad: 'A', bakiyeKurus: 205000),
          EsikAsanMusteri(customerId: 'b', ad: 'B', bakiyeKurus: 210000),
        ],
        gun: gun,
        esikKurus: 200000,
      )!);

      expect(servis.gosterilenler, hasLength(1),
          reason: 'aynı kimlik ÜZERİNE yazar — üç müşteri üç bildirim yapmaz');
      expect(servis.gosterilenler.single.govde, contains('2 müşterinin'),
          reason: 'kalan tek satır GÜNCEL olanıdır');
    });

    test('üç para bildirimi üç AYRI kategoriye düşer (biri diğerinin bütçesini yemez)', () async {
      final servis = SahteBildirimServisi();

      await servis.goster(gunSonuOzeti(GunSonuVerisi(
        gun: gun,
        tahsilatKurus: 124000,
        teslimatSayisi: 8,
        veresiyeKurus: 34000,
      ))!);
      await servis.goster(borcEsigiBildirimi(
        const [EsikAsanMusteri(customerId: 'a', ad: 'A', bakiyeKurus: 205000)],
        gun: gun,
        esikKurus: 200000,
      )!);
      await servis.goster(vadesiGecenBorclar(
        const [GecikmisMusteri(customerId: 'a', ad: 'A', gecikmisKurus: 100000)],
        haftaBasi: haftaninBasi(gun),
      )!);

      expect(servis.gosterilenler.map((t) => t.kategori).toSet(), {
        BildirimKategori.gunSonuOzeti,
        BildirimKategori.borcEsigi,
        BildirimKategori.vadesiGecenBorc,
      });
    });

    test('kategori kapalıysa taslak üretilir ama GÖSTERİLMEZ (kural dallanmaz)', () async {
      final servis = SahteBildirimServisi(
        kapaliKategoriler: {BildirimKategori.borcEsigi},
      );
      final taslak = borcEsigiBildirimi(
        const [EsikAsanMusteri(customerId: 'a', ad: 'A', bakiyeKurus: 205000)],
        gun: gun,
        esikKurus: 200000,
      );
      expect(taslak, isNotNull, reason: 'kural kategorinin açık olup olmadığını BİLMEZ');

      await servis.goster(taslak!);
      expect(servis.gosterilenler, isEmpty, reason: 'susturmayı altyapı uygular');
    });
  });

  group('haftaninBasi', () {
    test('haftanın her günü aynı pazartesiyi verir', () {
      final pzt = DateTime(2026, 7, 27);
      for (var i = 0; i < 7; i++) {
        expect(haftaninBasi(pzt.add(Duration(days: i))), pzt);
      }
      expect(haftaninBasi(DateTime(2026, 8, 3)), DateTime(2026, 8, 3));
    });
  });
}
