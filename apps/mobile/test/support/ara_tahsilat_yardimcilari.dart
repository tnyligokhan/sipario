// ARA TAHSİLAT / KAPANIŞ testlerinin paylaşılan kurulumu.
//
// NEDEN AYRI DOSYA: `ui_ara_tahsilat_test.dart` 500 satır sınırına dayanınca kapanış üçlüsü
// grubu `ui_kapanis_ucluk_test.dart`a ayrıldı ve bu iki yardımcı ikisinin de ORTAK dili oldu.
// Kopyalamak yerine paylaşıldı: kurulum kopyaları zamanla ayrışır ve bir dosya "yeşil"
// görünürken diğeri aslında başka bir senaryoyu sınar.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/tr_gun.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/isletme/gun_kapsami.dart';

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

/// Bir kuryenin şimdiye kadar yazılmış hareketlerini DÜNE kaydırır — "dün topladı" senaryosu.
///
/// Repo damgayı `correctedNowIso` ile KENDİ koyar (istemci saatini uydurmaz, doğru tasarım), bu
/// yüzden geçmişe kayıt yazmanın tek yolu oluşturduktan sonra damgayı geri almaktır. Sipariş VE
/// onun defter satırı BİRLİKTE kaydırılır: ayrı günlerde kalırlarsa teslimat bir güne, tahsilat
/// başka güne düşer ve test gerçekte olmayan bir durumu sınar.
///
/// [devirlerDe] true ise o kuryenin KASA DEVİRLERİ de kaydırılır ("dün ara tahsilat alınmıştı"
/// senaryosu) — devir bugünde kalsaydı gün süzgeçli kart onu yine gösterir ve pencere/gün
/// ayrışması hiç oluşmazdı.
///
/// DAMGA GÜNÜN ORTASINA KIRPILIR, "şimdi − 24 saat" DEĞİL: gün sınırına yakın saatlerde koşan bir
/// test yazı-turaya döner ve bu depoda daha önce döndü.
///
/// NEDEN PAYLAŞILAN DOSYADA: bir zamanlar yalnız `ui_kapanis_ucluk_test.dart` içindeydi; çerçeve
/// notu testleri ara tahsilat tarafında da aynı kurulumu isteyince kopyalamak yerine buraya
/// taşındı (kurulum kopyaları zamanla ayrışır ve bir dosya "yeşil" görünürken başka bir senaryoyu
/// sınar).
Future<void> duneKaydir(
  AppDatabase db, {
  required String kuryeId,
  bool devirlerDe = false,
}) async {
  final b = await bugunTrDuzeltilmis(db);
  final dun = DateTime(b.year, b.month, b.day - 1); // ay başında da doğru (constructor normalize eder)
  final damga = trGunBasiUtc(dun).add(const Duration(hours: 12)).toIso8601String();
  await (db.update(db.orders)..where((t) => t.assignedUserId.equals(kuryeId)))
      .write(OrdersCompanion(occurredAt: Value(damga)));
  await (db.update(db.ledgerEntries)..where((t) => t.collectedByUserId.equals(kuryeId)))
      .write(LedgerEntriesCompanion(occurredAt: Value(damga)));
  if (!devirlerDe) return;
  // Devir bir saat SONRAYA damgalanır: para önce toplanır, sonra teslim edilir. Aynı damga
  // olsaydı pencere sınırı (`isAfter`, alt sınır hariç) hesabı bulanıklaştırırdı.
  await (db.update(db.cashHandovers)..where((t) => t.fromUserId.equals(kuryeId))).write(
    CashHandoversCompanion(
      occurredAt: Value(
        trGunBasiUtc(dun).add(const Duration(hours: 13)).toIso8601String(),
      ),
    ),
  );
}

/// Bir kişinin kapsamına geçer.
///
/// KAPSAM ARTIK SEGMENT DEĞİL AÇILIR LİSTE (2026-08-20): seçiciye dokunulur, açılan sheet'te
/// kişinin "Ad (Rol)" satırı seçilir. Rol satırda yazdığı için [rol] parametresi var — tezgâh
/// kapsamına geçen bir test aynı yardımcıyı kullanabilsin.
Future<void> kapsamaGec(WidgetTester tester, String kisiAdi, {String rol = 'Kurye'}) async {
  await tester.tap(find.byType(GunKapsamSecici));
  await sheetAnimasyonu(tester);
  await tester.tap(find.text('$kisiAdi ($rol)'));
  await akislariBekle(tester, tur: 6);
}
