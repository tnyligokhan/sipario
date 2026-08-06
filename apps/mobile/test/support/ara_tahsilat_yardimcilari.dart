// ARA TAHSİLAT / KAPANIŞ testlerinin paylaşılan kurulumu.
//
// NEDEN AYRI DOSYA: `ui_ara_tahsilat_test.dart` 500 satır sınırına dayanınca kapanış üçlüsü
// grubu `ui_kapanis_ucluk_test.dart`a ayrıldı ve bu iki yardımcı ikisinin de ORTAK dili oldu.
// Kopyalamak yerine paylaşıldı: kurulum kopyaları zamanla ayrışır ve bir dosya "yeşil"
// görünürken diğeri aslında başka bir senaryoyu sınar.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';

import 'ekran_yardimcilari.dart';

/// Kuryenin NAKİT tahsil ettiği bir teslimat — kuryede biriken para budur.
Future<void> nakitTeslim(
  AppDatabase db, {
  required String kuryeId,
  required int tutarKurus,
  String musteri = 'Ayşe',
}) async {
  final cid = await CustomerRepository(db).create(name: musteri);
  final oid = await OrderRepository(db).create(
    customerId: cid,
    lines: [LineInput(productName: 'Damacana', unitPriceKurus: tutarKurus, qty: 1)],
  );
  await OrderRepository(db).assign(oid, kuryeId);
  await OrderRepository(db)
      .deliver(oid, paymentType: 'nakit', collectedByUserId: kuryeId);
}

/// Kurye kapsamına geçer (segmentteki kurye adına dokunur).
Future<void> kapsamaGec(WidgetTester tester, String kuryeAdi) async {
  await tester.tap(find.text(kuryeAdi));
  await akislariBekle(tester, tur: 6);
}
