// GEÇMİŞ GÜNÜ KAPATMA — para güvenliği (kullanıcı isteği 2026-08-21: "kapatılmayan günleri
// kapatabilmeli işletme sahibi… algoritmik olarak kusursuz olmalı ve hesaplarda bir sorun
// çıkmamalı").
//
// Bu dosya ÜÇ GARANTİYİ çiviler. Üçü de sessizce bozulabilecek türden:
//
//   1. SAYIM YOK, FARK UYDURULMAZ. Geçmiş günün kasası bugün sayılamaz; kayıt `counted=null`
//      ve `diff=0` ile geçer. Sayım alınsaydı yanlış bir fark arşive KALICI donardı.
//
//   2. KURYENİN CEBİ DOKUNULMAZ. Gün kapanışı (scope=day) kuryenin mutabakat penceresini
//      OYNATMAZ. Oynatsaydı, o günden bugüne kadar toplanmış ama teslim edilmemiş para
//      beklenenden düşer — yani gerçekten var olan nakit sessizce silinirdi. Bu, tüm
//      özelliğin en tehlikeli yan etkisi ve kapanış kapsamının neden GÜN ile sınırlı
//      olduğunun sebebidir.
//
//   3. GÜNLER BİRBİRİNE KARIŞMAZ. Dünü kapatmak bugünün rakamlarını değiştirmez ve kapanışa
//      donan rakamlar KAPATILAN GÜNÜNKÜLERDİR, bugünün değil.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/tr_gun.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/kapanmamis_gunler.dart';
import 'package:sipario/repo/order_repository.dart';

/// Bir kuryesi olan, geçmişe kayıt yazabilen bayi.
class GecmisBayi {
  GecmisBayi._(this.db, this.bugun);

  final AppDatabase db;
  final DateTime bugun;
  static const kuryeId = 'k1';

  static Future<GecmisBayi> kur() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.users).insert(UsersCompanion.insert(
        id: kuryeId, name: 'Emre', role: 'kurye', status: 'active'));
    return GecmisBayi._(db, await bugunTrDuzeltilmis(db));
  }

  DateTime gunOnce(int n) => DateTime(bugun.year, bugun.month, bugun.day - n);

  String _damga(DateTime gun) =>
      trGunBasiUtc(gun).add(const Duration(hours: 12)).toIso8601String();

  /// KURYENİN nakit tahsil ettiği bir teslimat — para kuryenin cebine girer.
  Future<void> kuryeNakitTeslim(DateTime gun, int kurus) async {
    final cid = await CustomerRepository(db).create(name: 'M${gun.day}-$kurus');
    final oid = await OrderRepository(db).create(
      customerId: cid,
      lines: [LineInput(productName: 'Damacana', unitPriceKurus: kurus, qty: 1)],
    );
    await OrderRepository(db).assign(oid, kuryeId);
    await OrderRepository(db).deliver(oid, paymentType: 'nakit', collectedByUserId: kuryeId);
    await (db.update(db.orders)..where((t) => t.id.equals(oid)))
        .write(OrdersCompanion(occurredAt: Value(_damga(gun))));
    await (db.update(db.ledgerEntries)..where((t) => t.relatedOrderId.equals(oid)))
        .write(LedgerEntriesCompanion(occurredAt: Value(_damga(gun))));
  }

  Future<int> kuryedenBeklenen({DateTime? gun}) async =>
      (await CashHandoverRepository(db).onizle(kuryeId, localDate: gun ?? bugun)).expectedKurus;

  Future<DayClosing> kapanis(String id) =>
      (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingle();
}

void main() {
  group('Geçmiş gün kapanışı — sayım yok, fark uydurulmaz', () {
    test('counted null, diff 0 ve kayıt O GÜNE damgalanır', () async {
      final b = await GecmisBayi.kur();
      addTearDown(b.db.close);
      await b.kuryeNakitTeslim(b.gunOnce(2), 5000);

      final id = await DayClosingRepository(b.db)
          .kapat(scope: ClosingScope.day, localDate: b.gunOnce(2));

      final k = await b.kapanis(id);
      expect(k.countedCashKurus, isNull, reason: 'sayım yapılmadı — sıfır YAZILMAZ');
      expect(k.diffKurus, 0, reason: 'karşılaştırılacak sayım yok; fark uydurulamaz');
      expect(ayniTrGunIso(k.occurredAt, b.gunOnce(2)), isTrue,
          reason: 'kayıt kapatılan güne damgalanmalı, yoksa o gün kapalı SAYILMAZ');
    });

    test('kapanışa donan rakamlar KAPATILAN GÜNÜNKÜLERDİR', () async {
      final b = await GecmisBayi.kur();
      addTearDown(b.db.close);
      await b.kuryeNakitTeslim(b.gunOnce(2), 5000);
      await b.kuryeNakitTeslim(b.bugun, 90000); // bugünün parası kapanışa karışmamalı

      final id = await DayClosingRepository(b.db)
          .kapat(scope: ClosingScope.day, localDate: b.gunOnce(2));

      final k = await b.kapanis(id);
      expect(k.cashNakitKurus, 5000);
      expect(k.deliveryCount, 1);
    });

    test('aynı gün İKİ KEZ kapatılamaz', () async {
      final b = await GecmisBayi.kur();
      addTearDown(b.db.close);
      await b.kuryeNakitTeslim(b.gunOnce(2), 5000);
      await DayClosingRepository(b.db).kapat(scope: ClosingScope.day, localDate: b.gunOnce(2));

      expect(
        () => DayClosingRepository(b.db).kapat(scope: ClosingScope.day, localDate: b.gunOnce(2)),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('⭐ KURYENİN CEBİ — gün kapanışı pencereyi OYNATMAZ', () {
    test('geçmiş günü kapatmak kuryeden beklenen nakdi DEĞİŞTİRMEZ', () async {
      // Senaryonun tamamı: kurye üç gün boyunca para topladı, hiç teslim etmedi. Patron
      // paperwork'ü kapatıyor. Cebindeki para 3 günün toplamıdır ve ÖYLE KALMALIDIR.
      final b = await GecmisBayi.kur();
      addTearDown(b.db.close);
      await b.kuryeNakitTeslim(b.gunOnce(3), 1000);
      await b.kuryeNakitTeslim(b.gunOnce(2), 2000);
      await b.kuryeNakitTeslim(b.gunOnce(1), 3000);

      expect(await b.kuryedenBeklenen(), 6000);

      await DayClosingRepository(b.db).kapat(scope: ClosingScope.day, localDate: b.gunOnce(3));
      await DayClosingRepository(b.db).kapat(scope: ClosingScope.day, localDate: b.gunOnce(2));

      expect(await b.kuryedenBeklenen(), 6000,
          reason: 'GÜN kapanışı kurye penceresine dokunmaz — dokunsaydı 3.000 ₺ sessizce silinir '
              've kurye cebindeki gerçek paradan sorumlu tutulamazdı');
    });

    test('gün kapanışı kasa devri kaydı YAZMAZ', () async {
      final b = await GecmisBayi.kur();
      addTearDown(b.db.close);
      await b.kuryeNakitTeslim(b.gunOnce(1), 4000);

      await DayClosingRepository(b.db).kapat(scope: ClosingScope.day, localDate: b.gunOnce(1));

      expect(await b.db.select(b.db.cashHandovers).get(), isEmpty,
          reason: 'devir, parayı fiilen alan tarafın kaydıdır; geçmişe uydurulamaz');
    });
  });

  group('Kapatınca uyarı söner', () {
    test('kapanmamış gün listesi kapatılan günü bir daha göstermez', () async {
      final b = await GecmisBayi.kur();
      addTearDown(b.db.close);
      await b.kuryeNakitTeslim(b.gunOnce(1), 4000);
      expect(await KapanmamisGunlerRepository(b.db).sayi(), 1);

      await DayClosingRepository(b.db).kapat(scope: ClosingScope.day, localDate: b.gunOnce(1));

      expect(await KapanmamisGunlerRepository(b.db).sayi(), 0);
    });

    test('BUGÜNÜN rakamları geçmiş kapanıştan etkilenmez', () async {
      final b = await GecmisBayi.kur();
      addTearDown(b.db.close);
      await b.kuryeNakitTeslim(b.gunOnce(1), 4000);
      await b.kuryeNakitTeslim(b.bugun, 7000);

      await DayClosingRepository(b.db).kapat(scope: ClosingScope.day, localDate: b.gunOnce(1));

      final kasa = await DayEndRepository(b.db).kasaOzeti(b.bugun);
      expect(kasa.nakit, 7000);
      expect(await DayClosingRepository(b.db).kapaliMi(ClosingScope.day, localDate: b.bugun),
          isFalse, reason: 'dünü kapatmak bugünü kapatmaz');
    });
  });
}
