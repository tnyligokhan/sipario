import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/team.dart';

import 'support/siparis_yardimci.dart';

/// KURYE KISITLARININ EKRANA GERÇEKTEN BAĞLI OLDUĞUNU KANITLAYAN TESTLER (2026-08-09).
///
/// NEDEN VARLAR — saha raporu: *"yetkilendirme ekranında ayarlar var ama arka planda hiçbir
/// kısıtlama devreye girmiyor; kurye hâlâ her şeyi görüyor."* Ölçüm bunu doğruladı:
/// `RolYetkileri` 26 alan tanımlıyordu ama YEDİSİ hiçbir kapıya bağlı değildi
/// (`tumSiparisleriGorme`, `gecmisTeslimatlariGorme`, `gecmisHesapArsivi`, `gunuKapatma`,
/// `isletmeAbonelikAyarlari`, `cihazAyarlari`, `rotaCalistir`). Yani yetki çözümleyicisi
/// (`yetkiler()`) doğru hesaplıyordu, sonucu KİMSE OKUMUYORDU.
///
/// `kurye_yetkileri_test.dart` saf fonksiyonu sınar — "doğru hesaplıyor mu". Bu dosya onun
/// eksik yarısıdır: **hesaplanan yetki ekranda bir şeyi değiştiriyor mu.** İkisi ayrı sorudur
/// ve bu depoda tam olarak ikincisi kırıktı.
void main() {
  /// Yönetici (kısıtsız) ve kurye (varsayılan izinler) yetki kümeleri.
  final yonetici = yetkiler(rol: 'patron', atamaHedefiVar: true);
  final kurye = yetkiler(rol: 'kurye', atamaHedefiVar: true);

  group('sipariş listesi · kurye kendi siparişlerine kilitli', () {
    /// İki sipariş: biri kuryeye atanmış, biri başkasına. Kurye YALNIZ kendininkini görmeli.
    Future<void> kur(AppDatabase db) async {
      await db.into(db.customers).insert(CustomersCompanion.insert(
          id: 'c1', name: 'Benim Müşterim', updatedOccurredAt: '2026-08-09T00:00:00.000Z'));
      await db.into(db.customers).insert(CustomersCompanion.insert(
          id: 'c2', name: 'Başkasının Müşterisi', updatedOccurredAt: '2026-08-09T00:00:00.000Z'));
      await db.into(db.orders).insert(OrdersCompanion.insert(
          id: 'o-benim',
          customerId: const Value('c1'),
          assignedUserId: const Value('kurye-1'),
          occurredAt: '2026-08-09T10:00:00.000Z'));
      await db.into(db.orders).insert(OrdersCompanion.insert(
          id: 'o-baskasi',
          customerId: const Value('c2'),
          assignedUserId: const Value('kurye-2'),
          occurredAt: '2026-08-09T11:00:00.000Z'));
    }

    testWidgets('kurye YALNIZ kendine atanan siparişi görür', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async => await kur(db));

      await tester.pumpWidget(sipKabuk(OrderListScreen(
        db: db,
        writable: true,
        userId: 'kurye-1',
        yetki: kurye, // tumSiparisleriGorme = false (varsayılan)
      )));
      await akisiBekle(tester);

      expect(find.text('Benim Müşterim'), findsOneWidget);
      expect(find.text('Başkasının Müşterisi'), findsNothing,
          reason: 'kurye başka kuryenin siparişini görmemeli');

      await ekraniKapat(tester);
    });

    testWidgets('kısıtlama SESSİZ DEĞİL — başlık "yalnız size atananlar" der', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async => await kur(db));

      await tester.pumpWidget(sipKabuk(OrderListScreen(
        db: db, writable: true, userId: 'kurye-1', yetki: kurye)));
      await akisiBekle(tester);

      // 2026-07-27'de filtreleme tam da SESSİZ olduğu için geri alınmıştı. Kısıtlama geri
      // geldi ama sessizliği geri gelmemeli: kurye eksik listeyi "iş yok" sanıp teslimat
      // kaçırmamalı.
      expect(find.textContaining('yalnız size atananlar'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('yönetici TÜM siparişleri görür — kısıtlama ona uygulanmaz', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async => await kur(db));

      await tester.pumpWidget(sipKabuk(OrderListScreen(
        db: db, writable: true, userId: 'patron-1', yetki: yonetici)));
      await akisiBekle(tester);

      expect(find.text('Benim Müşterim'), findsOneWidget);
      expect(find.text('Başkasının Müşterisi'), findsOneWidget);
      expect(find.textContaining('yalnız size atananlar'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('yetki VERİLMEZSE kısıtlama uygulanmaz (test/önizleme yolu bozulmaz)',
        (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async => await kur(db));

      await tester.pumpWidget(
          sipKabuk(OrderListScreen(db: db, writable: true, userId: 'kurye-1')));
      await akisiBekle(tester);

      expect(find.text('Başkasının Müşterisi'), findsOneWidget,
          reason: 'yetki yoksa ekran eski davranışını korur — kısıtlamayı KABUK verir');

      await ekraniKapat(tester);
    });
  });
}
