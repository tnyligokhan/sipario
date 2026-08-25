import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/day_end_screen.dart';

import 'support/ekran_yardimcilari.dart';

/// GÜN ÖZETİ — tahsilat dökümü YÜZEYİ (kullanıcı isteği 2026-08-11).
///
/// `gun_tahsilat_detay_test.dart` sorguyu sınar ("doğru satırları getiriyor mu"). Bu dosya onun
/// eksik yarısıdır: **ekranda dokunulunca gerçekten açılıyor mu.** Bu depoda o ayrımın bedeli
/// iki kez ölçüldü — `RolYetkileri`nin yedi alanı hesaplanıyordu ama hiçbir ekran okumuyordu ve
/// güncelleme bandı aylarca ağaca hiç bağlanmamıştı. "Widget var" ile "widget bağlı" ayrı
/// iddialardır.
void main() {
  const gun = '2026-08-11';

  Future<void> tahsilat(
    AppDatabase db, {
    required String id,
    required int kurus,
    required String tur,
    String? musteriId,
    String? kuryeId,
  }) =>
      db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
            id: id,
            entryType: 'payment',
            amountKurus: -kurus,
            paymentType: Value(tur),
            customerId: Value(musteriId),
            collectedByUserId: Value(kuryeId),
            occurredAt: '${gun}T10:00:00.000Z',
            clientEventId: 'ev-$id',
          ));

  /// Gün özetinin okuduğu gün CİHAZ saatinden türer; testler bugünün tarihini kullanamaz.
  /// Bu yüzden kayıtlar "bugün"e yazılır ve ekran onları o gün içinde bulur.
  Future<AppDatabase> kur({String? kuryeId}) async {
    final db = AppDatabase(NativeDatabase.memory());
    final bugun = DateTime.now().toUtc();
    final iso = bugun.toIso8601String();
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: 'm-1',
          name: 'Ahmet Yılmaz',
          updatedOccurredAt: iso,
        ));
    await db.into(db.customerAddresses).insert(CustomerAddressesCompanion.insert(
          id: 'a-1',
          customerId: 'm-1',
          addressText: 'Bahçelievler Mah. 12/3',
          isPrimary: const Value(true),
          updatedOccurredAt: iso,
        ));
    await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
          id: 'l-havale',
          entryType: 'payment',
          amountKurus: -224000,
          paymentType: const Value('havale'),
          customerId: const Value('m-1'),
          collectedByUserId: Value(kuryeId),
          occurredAt: iso,
          clientEventId: 'ev-havale',
        ));
    return db;
  }

  testWidgets('HAVALE satırına dokununca o günün havale dökümü açılır', (tester) async {
    final db = await kur();
    await tester.runAsync(() => kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron'));

    await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

    // Döküm HENÜZ yok — satır kartta duruyor.
    expect(find.text('Ahmet Yılmaz'), findsNothing);

    await dokun(tester, find.text('Havale'));
    await sheetAnimasyonu(tester);

    // ⭐ Müşteri, adres ve tutar sheet'te görünür.
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Bahçelievler Mah. 12/3'), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('"Detaylı döküm" anahtarı KAPALI başlar, açılınca liste gelir', (tester) async {
    // Varsayılan kapalı olmalı: gün özeti bir ÖZETTİR ve 60 teslimatlı günde liste kartların
    // hepsini erişilemez derinliğe iterdi.
    final db = await kur();
    await tester.runAsync(() => kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron'));

    await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

    expect(find.text('Günün Teslimatları'), findsOneWidget, reason: 'bölüm başlığı çizilir');
    expect(find.text('Ahmet Yılmaz'), findsNothing, reason: 'anahtar kapalıyken liste yok');

    await dokun(tester, find.text('Detaylı döküm'));

    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Bahçelievler Mah. 12/3'), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('KURYE dökümünde yalnız KENDİ tahsilatı görünür', (tester) async {
    // Şikâyetin özü: "kurye genel raporu görüyor". Döküm ekranın kapsamını devralır.
    final db = await kur(kuryeId: 'k1');
    await tester.runAsync(() async {
      await kuryeEkle(db, id: 'k1', ad: 'Emre');
      // Başka kuryenin tahsilatı — kuryenin dökümünde GÖRÜNMEMELİ.
      await db.into(db.customers).insert(CustomersCompanion.insert(
            id: 'm-2',
            name: 'Başkasının Müşterisi',
            updatedOccurredAt: DateTime.now().toUtc().toIso8601String(),
          ));
      await tahsilat(db, id: 'l-baska', kurus: 90000, tur: 'havale', musteriId: 'm-2',
          kuryeId: 'k2');
    });

    await ekranaKoy(tester, DayEndScreen(db: db, rol: 'kurye', kullaniciId: 'k1'));
    await dokun(tester, find.text('Detaylı döküm'));

    expect(find.text('Ahmet Yılmaz'), findsOneWidget, reason: 'kendi tahsilatı');
    expect(find.text('Başkasının Müşterisi'), findsNothing,
        reason: 'başka kuryenin tahsilatı kuryeye kapalı');

    await kapat(tester);
  });
}
