// SAHA GİDERİ — veri katmanı (kullanıcı isteği 2026-08-25).
//
// Gider, kasadan ÇIKAN nakdin defter kaydıdır ve varlık sebebi tek bir cümledir: kuryenin yolda
// aldığı 200 ₺ benzin, akşam kasada "eksik para" olarak görünmemeli. Bu dosya o cümlenin
// aritmetiğini çiviler.
//
// Burada çivilenen kararlar:
//  1. Gider TAHSİLATA KARIŞMAZ: `KasaOzeti.nakit` ve `toplam` değişmez, `gider` ayrı kovadadır.
//     Karıştığı an "Toplam tahsilat" etiketi yalan olurdu.
//  2. Gider MUTABAKATA GİRER: `netNakit` düşer ve kapanışın beklediği nakit onunla birlikte
//     düşer. Girmeseydi her gider kalıcı bir "EKSİK" olarak arşive donardı.
//  3. Gider VERESİYE DEĞİLDİR. Kayıt müşterisiz ve tutarı POZİTİF olduğu için günün veresiye
//     gruplayıcısı onu bir alacak sanabilirdi — tip elenir, işaret bunu yakalayamaz.
//  4. İptal SİLME DEĞİL, ters işaretli ikinci bir 'expense' satırıdır (kırmızı çizgi #2).
//  5. Kapanmış kapsama gider yazılamaz/iptal edilemez (ara tahsilatla AYNI kapı).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/tr_gun.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/gider_repository.dart';
import 'package:sipario/repo/gun_veresiye_repository.dart';
import 'package:sipario/repo/order_repository.dart';

void main() {
  /// Nakit tahsil edilmiş bir teslimat — kasaya giren paranın kaynağı.
  Future<void> nakitTeslim(
    AppDatabase db, {
    required int tutarKurus,
    String? kuryeId,
    String musteri = 'Ayşe',
  }) async {
    final cid = await CustomerRepository(db).create(name: musteri);
    final oid = await OrderRepository(db).create(
      customerId: cid,
      lines: [LineInput(productName: 'Damacana', unitPriceKurus: tutarKurus, qty: 1)],
    );
    if (kuryeId != null) await OrderRepository(db).assign(oid, kuryeId);
    await OrderRepository(db)
        .deliver(oid, paymentType: 'nakit', collectedByUserId: kuryeId);
  }

  group('Kasa özeti — gider ayrı kovada', () {
    test('TAHSİLAT DEĞİŞMEZ, net nakit düşer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final gun = await bugunTrDuzeltilmis(db);
      await nakitTeslim(db, tutarKurus: 10000);
      await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt');

      final kasa = await DayEndRepository(db).kasaOzeti(gun);

      expect(kasa.nakit, 10000, reason: '"Nakit" satırı TAHSİLATTIR; gider oraya karışmaz');
      expect(kasa.toplam, 10000, reason: '"Toplam tahsilat" etiketi doğru kalmalı');
      expect(kasa.gider, 2000);
      expect(kasa.netNakit, 8000, reason: 'çekmecede kalması gereken');

      await db.close();
    });

    test('İPTAL EDİLEN gider toplamdan kendiliğinden düşer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final gun = await bugunTrDuzeltilmis(db);
      await nakitTeslim(db, tutarKurus: 10000);
      final id = await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt');
      await GiderRepository(db).ekle(kurus: 500, aciklama: 'Yemek');
      await GiderRepository(db).iptal(giderId: id);

      final kasa = await DayEndRepository(db).kasaOzeti(gun);

      expect(kasa.gider, 500, reason: 'ters satır aynı kovada netlenir');
      expect(kasa.netNakit, 9500);

      // KAYIT SİLİNMEDİ (kırmızı çizgi #2): orijinal + ters satır defterde DURUYOR.
      final satirlar = await (db.select(db.ledgerEntries)
            ..where((t) => t.entryType.equals('expense')))
          .get();
      expect(satirlar, hasLength(3));
      expect(satirlar.where((e) => e.reversesEntryId == id), hasLength(1));

      await db.close();
    });

    test('TAHSİLAT DÖKÜMÜ gideri LİSTELEMEZ — liste toplamı kartı tutmalı', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final gun = await bugunTrDuzeltilmis(db);
      await nakitTeslim(db, tutarKurus: 10000);
      await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt');

      final satirlar = await DayEndRepository(db).tahsilatDetaylari(gun);

      expect(satirlar, hasLength(1), reason: 'gider bir tahsilat değildir');
      expect(satirlar.fold<int>(0, (a, s) => a + s.kurus), 10000,
          reason: 'dökümün toplamı kasa kartındaki "Nakit" rakamına EŞİT olmalı');

      await db.close();
    });
  });

  group('Gider VERESİYE sanılamaz', () {
    // Gider kaydının müşterisi de siparişi de YOKTUR ve tutarı POZİTİFTİR — yani günün veresiye
    // gruplayıcısı onu kendi başına bir grup yapıp `net > 0` bulabilirdi ve benzin parası akşam
    // "Müşterisiz kayıt · bugün yazılan veresiye" diye görünürdü.
    test('günün veresiye toplamına GİRMEZ', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final gun = await bugunTrDuzeltilmis(db);
      await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt');

      expect(await GunVeresiyeRepository(db).toplam(gun), 0);
      expect(await GunVeresiyeRepository(db).gununVeresiyeleri(gun), isEmpty);

      await db.close();
    });
  });

  group('Mutabakat — beklenen nakit giderden SONRAKİ paradır', () {
    test('GÜN kapsamında beklenen nakit gider kadar düşer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await nakitTeslim(db, tutarKurus: 10000);

      final oncesi = await DayClosingRepository(db).onizle(ClosingScope.day);
      expect(oncesi.expectedCashKurus, 10000);
      expect(oncesi.giderKurus, 0, reason: 'gider yokken döküm eski üçlü kimliğini korur');

      await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt');
      final sonrasi = await DayClosingRepository(db).onizle(ClosingScope.day);

      expect(sonrasi.expectedCashKurus, 8000);
      expect(sonrasi.giderKurus, 2000);
      // ARİTMETİK KAPANIR: gunNakit − gider − dusulen == beklenen.
      expect(
        sonrasi.gunNakitKurus - sonrasi.giderKurus - sonrasi.dusulenKurus,
        sonrasi.expectedCashKurus,
      );

      await db.close();
    });

    test('KURYE kapsamında cebindeki para gider kadar azalır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'k1', name: 'Emre', role: 'kurye', status: 'active'));
      await nakitTeslim(db, tutarKurus: 9000, kuryeId: 'k1');
      await GiderRepository(db).ekle(kurus: 1500, aciklama: 'Yakıt', harcayanId: 'k1');

      final on = await CashHandoverRepository(db).onizle('k1');

      expect(on.toplananKurus, 9000, reason: '"Topladığı" bir TAHSİLAT rakamıdır');
      expect(on.giderKurus, 1500);
      expect(on.expectedKurus, 7500, reason: 'cebinde kalan = toplanan − gider − teslim edilen');

      await db.close();
    });

    test('GÜN kapsamı kuryenin giderini İKİ KEZ düşmez', () async {
      // Tuzak: kuryenin gideri hem gün genelinin `netNakit`inde hem de "kuryelerde kalan"
      // hesabında görünür. İkisi de brüt/net karıştırırsa aynı 15,00 ₺ iki kez düşülür ve
      // patron kasasını FAZLA sanır.
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'k1', name: 'Emre', role: 'kurye', status: 'active'));
      await nakitTeslim(db, tutarKurus: 9000, kuryeId: 'k1');
      await GiderRepository(db).ekle(kurus: 1500, aciklama: 'Yakıt', harcayanId: 'k1');
      // Kurye 5.000 ₺ teslim etti; cebinde 9000 − 1500 − 5000 = 2500 kaldı.
      await CashHandoverRepository(db)
          .araTahsilat(fromUserId: 'k1', countedCashKurus: 5000);

      final on = await DayClosingRepository(db).onizle(ClosingScope.day);

      expect(on.dusulenKurus, 2500, reason: 'kuryede kalan NET paradır');
      expect(on.expectedCashKurus, 5000,
          reason: 'patronun kasasında kuryeden aldığı 50,00 ₺ var — ne eksik ne fazla');

      await db.close();
    });
  });

  group('Kapılar', () {
    test('sıfır ya da negatif tutar reddedilir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await expectLater(GiderRepository(db).ekle(kurus: 0), throwsArgumentError);
      await expectLater(GiderRepository(db).ekle(kurus: -100), throwsArgumentError);
      await db.close();
    });

    test('GÜN kapandıysa gider eklenemez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await DayClosingRepository(db).kapat(scope: ClosingScope.day, countedCashKurus: 0);

      await expectLater(
        () => GiderRepository(db).ekle(kurus: 2000),
        throwsA(isA<StateError>().having((e) => e.message, 'mesaj',
            contains('Gün hesabı kapandı'))),
      );

      await db.close();
    });

    test('KİŞİNİN hesabı kapandıysa ona gider yazılamaz', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'k1', name: 'Emre', role: 'kurye', status: 'active'));
      await DayClosingRepository(db)
          .kapat(scope: ClosingScope.courier, userId: 'k1', countedCashKurus: 0);

      await expectLater(
        () => GiderRepository(db).ekle(kurus: 2000, harcayanId: 'k1'),
        throwsA(isA<StateError>()),
      );

      await db.close();
    });

    test('AYNI gider iki kez iptal edilemez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await GiderRepository(db).ekle(kurus: 2000);
      await GiderRepository(db).iptal(giderId: id);

      await expectLater(
        () => GiderRepository(db).iptal(giderId: id),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'mesaj', contains('zaten iptal'))),
      );

      await db.close();
    });

    test('İPTAL SATIRININ KENDİSİ iptal edilemez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await GiderRepository(db).ekle(kurus: 2000);
      final iptalId = await GiderRepository(db).iptal(giderId: id);

      await expectLater(
        () => GiderRepository(db).iptal(giderId: iptalId),
        throwsA(isA<StateError>()),
      );

      await db.close();
    });

    test('GİDER OLMAYAN bir defter satırı iptal edilemez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await nakitTeslim(db, tutarKurus: 5000);
      final tahsilat = await (db.select(db.ledgerEntries)
            ..where((t) => t.entryType.equals('payment')))
          .getSingle();

      await expectLater(
        () => GiderRepository(db).iptal(giderId: tahsilat.id),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'mesaj', contains('bir gider değil'))),
      );

      await db.close();
    });
  });

  group('Liste', () {
    test('iptal satırı listelenmez, iptal edilen orijinal işaretlenerek KALIR', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final gun = await bugunTrDuzeltilmis(db);
      final id = await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt');
      await GiderRepository(db).ekle(kurus: 500, aciklama: 'Yemek');
      await GiderRepository(db).iptal(giderId: id);

      final liste = await GiderRepository(db).gunGiderleri(gun);

      expect(liste, hasLength(2), reason: 'ters satır listeye GİRMEZ');
      expect(liste.firstWhere((s) => s.id == id).iptalEdildi, isTrue);
      expect(liste.firstWhere((s) => s.aciklama == 'Yemek').iptalEdildi, isFalse);

      await db.close();
    });

    test('KAPSAM süzgeci — kişi kapsamı yalnız onun giderlerini döner', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final gun = await bugunTrDuzeltilmis(db);
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'k1', name: 'Emre', role: 'kurye', status: 'active'));
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'p1', name: 'Patron', role: 'patron', status: 'active'));
      await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt', harcayanId: 'k1');
      await GiderRepository(db).ekle(kurus: 500, aciklama: 'Kırtasiye', harcayanId: 'p1');

      final emre = await GiderRepository(db).gunGiderleri(gun, userId: 'k1');
      expect(emre, hasLength(1));
      expect(emre.single.harcayanAd, 'Emre');

      // "Elemanlar" = patron HARİÇ herkes.
      final elemanlar = await GiderRepository(db).gunGiderleri(gun, haric: 'p1');
      expect(elemanlar, hasLength(1));
      expect(elemanlar.single.harcayanId, 'k1');

      await db.close();
    });

    test('BAŞKA GÜNÜN gideri listeye ve toplama girmez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final gun = await bugunTrDuzeltilmis(db);
      final id = await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt');
      // Kaydı düne kaydır (repo damgayı kendi koyuyor; geçmişe yazmanın tek yolu bu).
      final dun = DateTime(gun.year, gun.month, gun.day - 1);
      await (db.update(db.ledgerEntries)..where((t) => t.id.equals(id))).write(
        LedgerEntriesCompanion(
          occurredAt: Value(
              trGunBasiUtc(dun).add(const Duration(hours: 12)).toIso8601String()),
        ),
      );

      expect(await GiderRepository(db).gunGiderleri(gun), isEmpty);
      expect((await DayEndRepository(db).kasaOzeti(gun)).gider, 0);
      expect((await GiderRepository(db).gunGiderleri(dun)), hasLength(1));

      await db.close();
    });
  });

  group('Senkron yükü', () {
    test('outbox satırı gideri sunucunun beklediği alanlarla taşır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt', harcayanId: 'k1');

      final olay = await (db.select(db.outbox)
            ..where((t) => t.entityType.equals('ledger')))
          .getSingle();

      expect(olay.op, 'entry', reason: 'YENİ bir op AÇILMADI — eski sunucuda sessizce düşerdi');
      expect(olay.payload, contains('"entry_type":"expense"'));
      expect(olay.payload, contains('"payment_type":"nakit"'),
          reason: 'kasaya dokunduğunu söyleyen tek alan budur');
      expect(olay.payload, contains('"amount_kurus":2000'), reason: 'POZİTİF = kasadan çıkan');
      expect(olay.payload, contains('"customer_id":null'),
          reason: 'giderin müşterisi yoktur; dolu olsaydı o müşterinin borcunu şişirirdi');
      expect(olay.payload, contains('"collected_by_user_id":"k1"'));

      await db.close();
    });
  });
}
