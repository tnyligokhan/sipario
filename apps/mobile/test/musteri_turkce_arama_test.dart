// TÜRKÇE ARAMA VE SIRALAMA — SAHA ARIZASININ GERİLEME BEKÇİSİ (2026-09-12).
//
// YAŞANAN: bir bayinin 9.047 müşterisi ürüne aktarıldı; adların hepsi BÜYÜK HARFTİ. Kullanıcı
// telefonda küçük harfle arayınca müşterilerin çoğu HİÇ ÇIKMADI — panelde duruyor, telefonda
// yok görünüyordu ve bu "senkron bozuk" sanıldı. Ölçüm sebebi gösterdi: SQLite'ın `LIKE`ı
// büyük/küçük harfi YALNIZ ASCII'de eşler; `ş`↔`Ş`, `ç`↔`Ç`, `ğ`↔`Ğ`, `ö`↔`Ö`, `ü`↔`Ü`,
// `i`↔`İ` eşleşmez.
//
// AYNI KÖK SIRALAMAYI DA BOZMUŞTU: BINARY collation'da Türkçe harfler tüm ASCII'den sonra
// dizildiği için alfabetik sıra 2026-08-06'da kaldırılmıştı. `customers.name_folded` ikisini
// birden çözer; bu dosya ikisini de kilitler.
//
// Sorgular saf async testle sınanır (widget-test sahte zamanı drift akışlarında güvenilmez).

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/ad_anahtari.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/screens/customers/customer_list_screen.dart';

void main() {
  late AppDatabase db;
  late CustomerRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CustomerRepository(db);
  });

  tearDown(() => db.close());

  Future<List<String>> ara(String q) async =>
      (await watchCustomers(db, q).first).map((c) => c.name).toList();

  Future<List<String>> satirAra(String q) async =>
      (await watchCustomerRows(db, q).first).map((r) => r.customer.name).toList();

  Future<void> kodAta(String id, int code) =>
      (db.update(db.customers)..where((t) => t.id.equals(id)))
          .write(CustomersCompanion(code: Value(code)));

  group('adAnahtari — katlama kuralı', () {
    test('Türkçe büyük harfler ASCII karşılığına iner', () {
      expect(adAnahtari('ŞERİFE YILMAZ'), 'serife yilmaz');
      expect(adAnahtari('ÇAĞLAYAN MARKET'), 'caglayan market');
      expect(adAnahtari('GÖKHAN ÖZTÜRK'), 'gokhan ozturk');
      expect(adAnahtari('ÜNAL GÜNEŞ'), 'unal gunes');
      expect(adAnahtari('IŞIL'), 'isil');
    });

    test('büyük ve küçük yazım AYNI anahtara iner — eşleşmenin dayanağı bu', () {
      for (final ad in ['ŞERİFE', 'şerife', 'Şerife', 'SERIFE', 'serife']) {
        expect(adAnahtari(ad), 'serife', reason: '"$ad" aynı anahtara inmeli');
      }
    });

    test("'İ' önce eşlenir, sonra küçültülür — sıra bozulursa birleştiren nokta sızar", () {
      // Dart'ın 'İ'.toLowerCase() çıktısı 'i' + U+0307'dir; anahtarda görünmez bir karakter
      // kalsaydı hiçbir sorgu eşleşmezdi.
      expect(adAnahtari('İ').codeUnits, [0x69]);
      expect(adAnahtari('İSTANBUL'), 'istanbul');
    });

    test('çift boşluk sadeleşir', () {
      expect(adAnahtari('  AHMET   YILMAZ '), 'ahmet yilmaz');
    });
  });

  group('Arama: büyük harfli Türkçe adlar küçük harfle bulunur', () {
    setUp(() async {
      for (final ad in const [
        'TAYFUN PIRTI',
        'ŞERİFE YILMAZ',
        'ÇAĞLAYAN MARKET',
        'GÖKHAN ÖZTÜRK',
        'ÜNAL GÜNEŞ',
      ]) {
        await repo.create(name: ad);
      }
    });

    test('küçük harfle arama bulur — ARIZANIN TA KENDİSİ', () async {
      expect(await ara('şerife'), ['ŞERİFE YILMAZ']);
      expect(await ara('çağlayan'), ['ÇAĞLAYAN MARKET']);
      expect(await ara('gökhan'), ['GÖKHAN ÖZTÜRK']);
      expect(await ara('güneş'), ['ÜNAL GÜNEŞ']);
    });

    test('ŞAPKASIZ yazım da bulur (kullanıcı kararı 2026-09-12)', () async {
      // Telefon klavyesinde kimse şapkalı harf yazmıyor.
      expect(await ara('serife'), ['ŞERİFE YILMAZ']);
      expect(await ara('caglayan'), ['ÇAĞLAYAN MARKET']);
      expect(await ara('gokhan'), ['GÖKHAN ÖZTÜRK']);
      expect(await ara('gunes'), ['ÜNAL GÜNEŞ']);
    });

    test('büyük harfle arama BOZULMADI', () async {
      expect(await ara('ŞERİFE'), ['ŞERİFE YILMAZ']);
      expect(await ara('TAYFUN'), ['TAYFUN PIRTI']);
    });

    test('liste akışı (watchCustomerRows) aynı kuralı uygular', () async {
      // İki sorgu ayrı kod yollarıdır; biri düzelip öteki kalırsa arama ekranda yine kaçırır.
      expect(await satirAra('şerife'), ['ŞERİFE YILMAZ']);
      expect(await satirAra('serife'), ['ŞERİFE YILMAZ']);
    });

    test('eşleşmeyen sorgu boş döner — katlama her şeyi eşleştirmiyor', () async {
      expect(await ara('zzz'), isEmpty);
    });
  });

  group('Sıralama: dört mod', () {
    late String aId, bId, cId;

    setUp(() async {
      // Kaydetme sırası bilerek alfabetik DEĞİL; her mod kendi kuralını göstermeli.
      aId = await repo.create(name: 'ZEYNEP AK');
      bId = await repo.create(name: 'ÇAĞLA DEMİR');
      cId = await repo.create(name: 'AHMET YILMAZ');
      await kodAta(aId, 300);
      await kodAta(bId, 100);
      await kodAta(cId, 200);
      await (db.update(db.customers)..where((t) => t.id.equals(aId)))
          .write(const CustomersCompanion(balanceKurus: Value(5000)));
      await (db.update(db.customers)..where((t) => t.id.equals(bId)))
          .write(const CustomersCompanion(balanceKurus: Value(90000)));
    });

    Future<List<String>> sirali(MusteriSirasi s) async =>
        (await watchCustomers(db, '', sira: s).first).map((c) => c.name).toList();

    test('ada göre A→Z: Türkçe harfler DOĞRU yerde', () async {
      // BINARY collation'da 'Ç' ve 'Z' karşılaştırılsaydı Çağla en sona düşerdi — arızanın
      // sıralamadaki yüzü buydu. Katlanmış ad sayesinde c < z doğru çalışır.
      expect(await sirali(MusteriSirasi.ad),
          ['AHMET YILMAZ', 'ÇAĞLA DEMİR', 'ZEYNEP AK']);
    });

    test('koda göre artan', () async {
      expect(await sirali(MusteriSirasi.kod),
          ['ÇAĞLA DEMİR', 'AHMET YILMAZ', 'ZEYNEP AK']);
    });

    test('bakiyeye göre: en çok borçlu üstte', () async {
      final sonuc = await sirali(MusteriSirasi.bakiye);
      expect(sonuc.first, 'ÇAĞLA DEMİR'); // 900 TL
      expect(sonuc[1], 'ZEYNEP AK'); // 50 TL
    });

    test('varsayılan EKLENME sırası değişmedi (2026-08-06 sözleşmesi)', () async {
      // Kod atandığı için kural "büyük kod üstte"dir.
      expect(await sirali(MusteriSirasi.eklenme),
          ['ZEYNEP AK', 'AHMET YILMAZ', 'ÇAĞLA DEMİR']);
      // Parametresiz çağrı da AYNI sonucu vermeli — varsayılan kaymamalı.
      expect(await ara(''), await sirali(MusteriSirasi.eklenme));
    });

    test('sıra ARAMA sonucuna da uygulanır', () async {
      final sonuc = (await watchCustomers(db, 'a', sira: MusteriSirasi.ad).first)
          .map((c) => c.name)
          .toList();
      expect(sonuc, ['AHMET YILMAZ', 'ÇAĞLA DEMİR', 'ZEYNEP AK']);
    });
  });

  group('Anahtar her yazma yolunda dolar', () {
    test('create anahtarı yazar', () async {
      final id = await repo.create(name: 'ŞÜKRÜ ÇELİK');
      final satir =
          await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
      expect(satir.nameFolded, 'sukru celik');
    });

    test('rename anahtarı TAZELER — yoksa müşteri eski adıyla aranır', () async {
      final id = await repo.create(name: 'ESKİ AD');
      await repo.rename(id, name: 'YENİ ÖZGÜR');
      final satir =
          await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
      expect(satir.nameFolded, 'yeni ozgur');
      expect(await ara('özgür'), ['YENİ ÖZGÜR']);
      expect(await ara('eski'), isEmpty);
    });
  });
}
