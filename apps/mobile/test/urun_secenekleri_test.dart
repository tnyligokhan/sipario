// ÜRÜN SEÇENEKLERİ — "içinde şu olsun / olmasın" (kullanıcı isteği 2026-08-18).
//
// Kullanıcının tarifi: "bir hızlı gıda işletmesi — gözlemeci, dönerci, dürümcü — müşteri içinde
// şu olsun olmasın diyebilir. İşletmede her seferinde bunu sormak istemeyebilir."
//
// ⚠️ BU DOSYANIN ÜÇ KRİTİK TESTİ (üçü de sessizce yanlış davranabilecek yerler):
//   • `farklı seçim AYRI SEPET SATIRI` — birleştirme yalnız `productId`ye baksaydı "1 soğanlı +
//     1 soğansız" isteği "2 soğansız"a dönerdi. Müşterinin siparişini sessizce değiştirmek,
//     hiç kaydetmemekten kötüdür.
//   • `ekstra birim fiyata ADET BAŞINA biner` — satır toplamı `birim * adet` kimliğini korumak
//     zorunda; bozulursa gün sonu, defter ve teslim hesaplarının hepsi kayar.
//   • `seçim satır NOTUNA da yazılır` — ekranların tamamı (sipariş detayı, kurye görünümü,
//     geçmiş) o alanı çiziyor. Yazılmasaydı kurye kapıda "soğansız"ı hiç görmezdi.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/urun_secenekleri.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/orders/order_parts.dart';

void main() {
  group('Saf model — biçim ve dayanıklılık', () {
    test('seçenek listesi yazılır ve geri okunur', () {
      const liste = [
        UrunSecenegi(ad: 'Soğan'),
        UrunSecenegi(ad: 'Ekstra peynir', varsayilan: false, ekKurus: 1000),
      ];
      final metin = secenekleriYaz(liste);
      expect(metin, isNotNull);
      expect(secenekleriCoz(metin), liste);
    });

    test('BOŞ LİSTE null yazar — "seçeneği yok" tek bir hâldir', () {
      expect(secenekleriYaz(const []), isNull);
      expect(secenekleriYaz([const UrunSecenegi(ad: '   ')]), isNull);
    });

    test('BOZUK metin ÇÖKMEZ, boş listeye düşer', () {
      // Alan `text` kolonda bütün olarak duruyor ve sunucudan iniyor. Tek bozuk kayıt, ürün
      // ekranının tamamını açılmaz yapamaz.
      for (final ham in ['', '   ', 'düz metin', '{"a":1}', '[1,2,3]', '[{"yok":true}]']) {
        expect(secenekleriCoz(ham), isEmpty, reason: 'girdi: $ham');
      }
    });

    test('AYNI AD iki kez duramaz — ilk görülen kazanır', () {
      // Seçim `ad` üzerinden eşleşiyor; tekrar eden ad hangi satırın kastedildiğini belirsiz
      // kılardı.
      final liste = secenekleriCoz(
          '[{"ad":"Soğan","varsayilan":true},{"ad":"soğan","varsayilan":false}]');
      expect(liste, hasLength(1));
      expect(liste.single.varsayilan, isTrue, reason: 'ilk görülen kazanır');
    });

    test('NEGATİF ek ücret sıfıra çekilir — "eksi ekstra" diye bir şey yok', () {
      final liste = secenekleriCoz('[{"ad":"İndirim","varsayilan":false,"ekKurus":-5000}]');
      expect(liste.single.ekKurus, 0);
    });

    test('özet metni mutfağın okuduğu cümledir', () {
      const secim = SecenekSecimi(
        cikarilan: ['Soğan', 'Turşu'],
        eklenen: [UrunSecenegi(ad: 'Ekstra peynir', varsayilan: false, ekKurus: 1000)],
      );
      expect(secim.ozet(), 'Soğan, Turşu olmasın · + Ekstra peynir');
      expect(secim.ekTutarKurus, 1000);
    });

    test('ürünün GÜNCEL listesiyle uyumlulaştırma', () {
      // Tercih aylar önce kaydedildi; menü o günden beri değişti. Artık var olmayan malzemeyi
      // "çıkarılan" diye taşımak mutfağa anlamsız talimat göndermektir; ücreti değişen bir
      // ekstrayı eski fiyatıyla uygulamak ise bayiye para kaybettirir.
      const eski = SecenekSecimi(
        cikarilan: ['Soğan', 'Kaldırılmış malzeme'],
        eklenen: [UrunSecenegi(ad: 'Ekstra peynir', varsayilan: false, ekKurus: 500)],
      );
      const guncel = [
        UrunSecenegi(ad: 'Soğan'),
        UrunSecenegi(ad: 'Ekstra peynir', varsayilan: false, ekKurus: 1500),
      ];

      final yeni = eski.urunleUyumlu(guncel);
      expect(yeni.cikarilan, ['Soğan'], reason: 'menüden kalkan malzeme düşer');
      expect(yeni.eklenen.single.ekKurus, 1500, reason: 'fiyat BUGÜNKÜ değerden alınır');
    });

    test('hazır şablonlar dolu ve adları benzersiz', () {
      // "İşletme türüne göre değişkenlik gösteren ürün listesi" — şablonlar özelliğin ilk
      // dokunuşunu taşıyor; boş bir şablon listesi onu kullanılamaz yapardı.
      expect(kSecenekSablonlari, isNotEmpty);
      expect(
        kSecenekSablonlari.map((s) => s.ad).toSet().length,
        kSecenekSablonlari.length,
      );
      for (final s in kSecenekSablonlari) {
        expect(s.secenekler, isNotEmpty, reason: '${s.ad} boş');
        expect(secenekleriYaz(s.secenekler), isNotNull,
            reason: '${s.ad} yazılabilir olmalı');
      }
    });
  });

  group('Sepet — satır kimliği ve fiyat', () {
    test('farklı seçim AYRI SEPET SATIRIDIR', () {
      final soganli = LineDraft(productId: 'u1', name: 'Dürüm', unitPriceKurus: 10000);
      const soganiz = SecenekSecimi(cikarilan: ['Soğan']);

      expect(soganli.ayniKalem('u1', const SecenekSecimi()), isTrue);
      expect(soganli.ayniKalem('u1', soganiz), isFalse,
          reason: '"1 soğanlı + 1 soğansız" isteği "2 soğansız"a dönemez');
    });

    test('ekstra BİRİM fiyata biner, toplam adetle çarpılır', () {
      final draft = LineDraft(
        productId: 'u1',
        name: 'Dürüm',
        unitPriceKurus: 10000,
        qty: 2,
        secim: const SecenekSecimi(
          eklenen: [UrunSecenegi(ad: 'Ekstra et', varsayilan: false, ekKurus: 2500)],
        ),
      );
      expect(draft.birimFiyat, 12500);
      expect(toplamKurus([draft]), 25000, reason: 'iki dürümün ikisine de ekstra binmeli');
    });
  });

  group('Sipariş kaydı — uçtan uca', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('seçim satıra YAPILANDIRILMIŞ ve METİN olarak birlikte yazılır', () async {
      final musteriId = await CustomerRepository(db).create(name: 'Ayşe');
      final orderId = await OrderRepository(db).create(customerId: musteriId, lines: [
        LineInput(
          productName: 'Tavuk Dürüm',
          unitPriceKurus: 10000,
          qty: 2,
          secim: const SecenekSecimi(
            cikarilan: ['Soğan'],
            eklenen: [UrunSecenegi(ad: 'Ekstra peynir', varsayilan: false, ekKurus: 1000)],
          ),
        ),
      ]);

      final satir = (await (db.select(db.orderLines)
                ..where((t) => t.orderId.equals(orderId)))
              .get())
          .single;

      // FİYAT: ekstra birim fiyata bindi ve toplam adetle çarpıldı.
      expect(satir.unitPriceKurus, 11000);
      expect(satir.lineTotalKurus, 22000);

      // METİN: ekranların tamamı bu alanı çiziyor.
      expect(satir.note, 'Soğan olmasın · + Ekstra peynir');

      // YAPILANDIRILMIŞ: satır KENDİ KENDİNE YETER — çıkarılanın adı ve eklenenin FİYATI
      // satırda durur, ürüne bakılarak çözülmez.
      final geri = SecenekSecimi.coz(satir.optionsJson);
      expect(geri.cikarilan, ['Soğan']);
      expect(geri.eklenen.single.ekKurus, 1000);
    });

    test('elle yazılan not ile seçim özeti BİRLİKTE durur', () async {
      final orderId = await OrderRepository(db).create(lines: [
        LineInput(
          productName: 'Dürüm',
          unitPriceKurus: 10000,
          qty: 1,
          note: 'acı sos ayrı',
          secim: const SecenekSecimi(cikarilan: ['Soğan']),
        ),
      ]);
      final satir = (await (db.select(db.orderLines)
                ..where((t) => t.orderId.equals(orderId)))
              .get())
          .single;
      expect(satir.note, 'Soğan olmasın · acı sos ayrı');
    });

    test('seçimsiz satır eskisi gibi davranır — alan null kalır', () async {
      final orderId = await OrderRepository(db).create(lines: [
        LineInput(productName: 'Su', unitPriceKurus: 500, qty: 1),
      ]);
      final satir = (await (db.select(db.orderLines)
                ..where((t) => t.orderId.equals(orderId)))
              .get())
          .single;
      expect(satir.optionsJson, isNull);
      expect(satir.note, isNull);
      expect(satir.unitPriceKurus, 500);
    });
  });

  group('Müşteri tercihi — "her seferinde sormak istemeyebilir"', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('kaydedilir, okunur ve ürünle uyumlulaştırılır', () async {
      final repo = CustomerRepository(db);
      final musteriId = await repo.create(name: 'Ayşe');
      final urunId = await ProductRepository(db).create(
        name: 'Tavuk Dürüm',
        unitPriceKurus: 10000,
        secenekler: const [
          UrunSecenegi(ad: 'Soğan'),
          UrunSecenegi(ad: 'Ekstra peynir', varsayilan: false, ekKurus: 1500),
        ],
      );

      await repo.urunTercihiKaydet(
          musteriId, urunId, const SecenekSecimi(cikarilan: ['Soğan']));

      final urun =
          await (db.select(db.products)..where((t) => t.id.equals(urunId))).getSingleOrNull();
      final secenekler = secenekleriCoz(urun!.optionsJson);
      final tercih = await repo.urunTercihi(musteriId, urunId, secenekler: secenekler);

      expect(tercih.cikarilan, ['Soğan']);
      expect(secenekler, hasLength(2), reason: 'ürünün listesi de kaydedilmiş olmalı');
    });

    test('BOŞ seçim yazmak tercihi SİLER — ayrı bir silme yolu yok', () async {
      final repo = CustomerRepository(db);
      final musteriId = await repo.create(name: 'Ayşe');
      await repo.urunTercihiKaydet(
          musteriId, 'u1', const SecenekSecimi(cikarilan: ['Soğan']));
      expect(await repo.urunTercihleriniOku(musteriId), hasLength(1));

      await repo.urunTercihiKaydet(musteriId, 'u1', const SecenekSecimi());
      expect(await repo.urunTercihleriniOku(musteriId), isEmpty);
    });

    test('AD DEĞİŞTİRME tercihleri SİLMEZ', () async {
      // ⚠️ Bu, favori listesinde bir kez ödenmiş hata sınıfı: sunucu `customer` upsert'ini TAM
      // SATIR olarak uyguluyor ve payload'da olmayan alan null yazılıyor. Adı düzelten bir çağrı
      // tercihleri geçmezse müşterinin bütün tercihleri sessizce yok olur.
      final repo = CustomerRepository(db);
      final musteriId = await repo.create(name: 'Ayşe');
      await repo.urunTercihiKaydet(
          musteriId, 'u1', const SecenekSecimi(cikarilan: ['Soğan']));

      await repo.rename(musteriId, name: 'Ayşe Yılmaz');

      expect(await repo.urunTercihleriniOku(musteriId), hasLength(1),
          reason: 'ad düzeltmesi tercihleri silemez');

      // Outbox payload'ı da taşımalı — yerelde duran ama sunucuya gitmeyen bir tercih, ikinci
      // telefonda HİÇ olmamış demektir.
      final kuyruk = await db.select(db.outbox).get();
      final sonMusteri =
          kuyruk.where((o) => o.entityType == 'customer').toList().last;
      expect(sonMusteri.payload, contains('product_options'));
      expect(sonMusteri.payload, contains('Soğan'));
    });
  });
}
