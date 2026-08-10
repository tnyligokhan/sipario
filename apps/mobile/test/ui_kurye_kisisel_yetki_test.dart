import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/isletme/atomlar/yetki_atomlari.dart';
import 'package:sipario/screens/isletme/kurye_kisisel_yetkiler.dart';
import 'package:sipario/screens/isletme/kurye_yetkileri_ekrani.dart';

import 'support/ekran_yardimcilari.dart';

/// KİŞİYE ÖZEL YETKİ EKRANI — üç durumun ekranda GERÇEKTEN çalıştığının kanıtı.
///
/// `kurye_kisisel_yetki_test.dart` çözümü ve yazım sözleşmesini sınar ("doğru hesaplıyor mu").
/// Bu dosya onun eksik yarısıdır: **ekrandaki seçim veritabanına ve outbox'a iniyor mu.**
/// Bu ayrımın bedeli depoda iki kez ölçüldü: `RolYetkileri` 26 alan hesaplıyordu ama yedisini
/// hiçbir ekran okumuyordu (2026-08-09 saha raporu: "ayarlar var, kısıtlama yok"), ve güncelleme
/// bandı aylarca ağaca hiç bağlanmamıştı. "Widget var" ile "widget bağlı" ayrı iddialardır.
///
/// Sahte zaman kuralları `support/ekran_yardimcilari.dart` başlığında yazılıdır: her drift
/// çağrısı `runAsync` içinde beklenir, akışa abone db KAPATILMAZ, kapanışta toast sayacı söner.
void main() {
  /// Bayi varsayılanı + düzenlenecek kurye. Varsayılan: tahsilat AÇIK, iskonto KAPALI.
  Future<AppDatabase> kur(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.into(db.tenantSettings).insertOnConflictUpdate(const TenantSettingsCompanion(
            id: Value(1),
            courierCanCollect: Value(true),
            courierCanDiscount: Value(false),
          ));
      await kuryeEkle(db, id: 'k-1', ad: 'Ahmet Yıldız');
      await db.into(db.syncMeta).insertOnConflictUpdate(const SyncMetaCompanion(
            id: Value(1),
            deviceId: Value('cihaz-A'),
            userId: Value('patron-1'),
            userRole: Value('patron'),
          ));
    });
    return db;
  }

  Future<void> ekranAc(
    WidgetTester tester,
    AppDatabase db, {
    bool writable = true,
    String? rol = 'patron',
  }) =>
      ekranaKoy(
        tester,
        KuryeYetkileriEkrani(
          db: db,
          rol: rol,
          userId: 'k-1',
          kuryeAdi: 'Ahmet Yıldız',
          writable: writable,
        ),
      );

  Future<User> kurye(WidgetTester tester, AppDatabase db) async {
    final satir = await tester.runAsync(
      () => (db.select(db.users)..where((t) => t.id.equals('k-1'))).getSingle(),
    );
    return satir!;
  }

  Future<List<OutboxData>> outbox(WidgetTester tester, AppDatabase db) async =>
      (await tester.runAsync(() => db.select(db.outbox).get()))!;

  testWidgets('kişi kipi başlığı kuryenin ADINI taşır — patron kimi düzenlediğini görmeli',
      (tester) async {
    final db = await kur(tester);
    await ekranAc(tester, db);

    expect(find.text('Ahmet Yıldız — Yetkiler'), findsOneWidget);
    expect(find.text('Kişiye özel · 13 İzin'), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('"Açık" seçimi KAPALI varsayılanı ezer: users satırına true, outbox\'a olay iner',
      (tester) async {
    final db = await kur(tester);
    await ekranAc(tester, db);

    // Başlangıç: iskonto ezmesi YOK (devralıyor → kapalı).
    expect((await kurye(tester, db)).courierCanDiscount, isNull);

    await dokun(tester, find.byKey(UcDurumSecim.hucreAnahtari('iskonto', YetkiEzmeDurumu.acik)));

    // ⭐ Yerel satır: artık kişiye özel AÇIK.
    expect((await kurye(tester, db)).courierCanDiscount, isTrue);

    // ⭐ Ve sunucuya gidecek olay kuyruğa düştü — ekran değişikliği cihazda kalmaz.
    final olaylar = await outbox(tester, db);
    expect(olaylar, hasLength(1));
    expect(olaylar.single.entityType, 'user_profile');
    final payload = jsonDecode(olaylar.single.payload) as Map<String, Object?>;
    expect(payload['id'], 'k-1');
    expect(payload['courier_can_discount'], isTrue);

    await kapat(tester);
  });

  testWidgets('"Kapalı" seçimi AÇIK varsayılanı ezer — false, "ezme yok" ile karıştırılmaz',
      (tester) async {
    final db = await kur(tester);
    await ekranAc(tester, db);

    await dokun(
      tester,
      find.byKey(UcDurumSecim.hucreAnahtari('tahsilat', YetkiEzmeDurumu.kapali)),
    );

    // `false` ezmesi ile "ezme yok" AYRI durumlardır: ilki varsayılan açık olsa bile kapatır.
    // İkisini eşitleyen bir katman burada `null` bırakır ve kurye tahsilat almaya devam eder.
    final satir = await kurye(tester, db);
    expect(satir.courierCanCollect, isFalse);
    expect(satir.courierCanCollect, isNotNull);

    await kapat(tester);
  });

  testWidgets('"Hepsini varsayılana döndür" 13 ezmeyi de NULL yapar', (tester) async {
    final db = await kur(tester);
    // Önce iki kişisel karar yaz — düğmenin gerçekten SİLDİĞİ bir şey olsun.
    await tester.runAsync(() => (db.update(db.users)..where((t) => t.id.equals('k-1')))
        .write(const UsersCompanion(
          courierCanDiscount: Value(true),
          courierCanCollect: Value(false),
        )));

    await ekranAc(tester, db);
    await dokun(tester, find.text('Hepsini varsayılana döndür'));

    final satir = await kurye(tester, db);
    expect(satir.courierCanDiscount, isNull);
    expect(satir.courierCanCollect, isNull);
    expect(find.text(kuryeYetkiSifirlandiMesaji), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('SALT-OKUNUR kipte seçim veritabanına YAZMAZ, uyarı çıkar', (tester) async {
    final db = await kur(tester);
    await ekranAc(tester, db, writable: false);

    await dokun(tester, find.byKey(UcDurumSecim.hucreAnahtari('iskonto', YetkiEzmeDurumu.acik)));

    expect((await kurye(tester, db)).courierCanDiscount, isNull);
    expect(await outbox(tester, db), isEmpty);

    await kapat(tester);
  });

  testWidgets('KURYE bu ekranı açamaz — rol kapısı kişi kipinde de geçerli', (tester) async {
    // Yetki ekranının kendisi bir yetkidir: kurye kendi kısıtlarını düzenleyebilseydi
    // özelliğin tamamı anlamsız olurdu (kapı sunucuda da var — ProfileChangeApplier).
    final db = await kur(tester);
    await ekranAc(tester, db, rol: 'kurye');

    expect(
      find.byKey(UcDurumSecim.hucreAnahtari('iskonto', YetkiEzmeDurumu.acik)),
      findsNothing,
    );

    await kapat(tester);
  });
}
