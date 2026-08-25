// KAPANMAMIŞ GÜNLER — tespit algoritmasının tam tablosu (kullanıcı isteği 2026-08-21:
// "algoritmik olarak kusursuz olmalı ve hesaplarda bir sorun çıkmamalı").
//
// Bu dosyanın kilitlediği şey ÜÇ SINIRDIR ve üçü de yanlış kurulursa ürün ya susar ya bağırır:
//   1. ÜST SINIR — bugün listede YOKTUR (henüz kapanmadı, kapanmamış değil).
//   2. ALT SINIR — son geçerli GÜN kapanışından öncesine inilmez VE en fazla N gün geriye.
//   3. HAREKET — hareketsiz gün kapanmamış sayılmaz (bayi o gün çalışmadı).
//
// Ayrıca kapanışın GEÇERLİLİĞİ: geri alınmış bir kapanış günü kapatmaz, geri alma satırının
// kendisi de kapanış değildir. Bu tanım `DayClosingRepository._gecerliKapanislar` ile ORTAKTIR;
// burada davranış üzerinden bir kez daha çivileniyor çünkü yanlışının bedeli sessizdir: gün ya
// listede hiç görünmez ya da kapatıldığı hâlde görünmeye devam eder.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/tr_gun.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/kapanmamis_gunler.dart';
import 'package:sipario/repo/order_repository.dart';

/// Geçmiş günlere kayıt yazabilen küçük bir bayi.
///
/// FİKSTÜR SINIFI (CLAUDE.md kuralı): repo damgayı `correctedNowIso` ile KENDİ koyar, yani
/// geçmişe yazmanın tek yolu oluşturup damgayı geri almaktır. Bu ayrıntı her teste
/// kopyalansaydı biri unutulur ve test gerçekte olmayan bir günü sınardı.
class GunFikstur {
  GunFikstur._(this.db, this.bugun);

  final AppDatabase db;
  final DateTime bugun;

  static Future<GunFikstur> kur() async {
    final db = AppDatabase(NativeDatabase.memory());
    return GunFikstur._(db, await bugunTrDuzeltilmis(db));
  }

  DateTime gunOnce(int n) => DateTime(bugun.year, bugun.month, bugun.day - n);

  String _damga(DateTime gun) =>
      trGunBasiUtc(gun).add(const Duration(hours: 12)).toIso8601String();

  /// O güne teslim edilmiş bir sipariş + tahsilatı yazar (yani gün HAREKET görmüş olur).
  Future<String> teslimat(DateTime gun, {int kurus = 4500, String odeme = 'nakit'}) async {
    final cid = await CustomerRepository(db).create(name: 'M${gun.day}-$kurus');
    final oid = await OrderRepository(db).create(
      customerId: cid,
      lines: [LineInput(productName: 'Damacana', unitPriceKurus: kurus, qty: 1)],
    );
    await OrderRepository(db).deliver(oid, paymentType: odeme);
    await (db.update(db.orders)..where((t) => t.id.equals(oid)))
        .write(OrdersCompanion(occurredAt: Value(_damga(gun))));
    await (db.update(db.ledgerEntries)..where((t) => t.relatedOrderId.equals(oid)))
        .write(LedgerEntriesCompanion(occurredAt: Value(_damga(gun))));
    return oid;
  }

  /// O güne AÇIK (teslim edilmemiş) bir sipariş bırakır — kapatmanın önündeki engel.
  Future<void> acikSiparis(DateTime gun) async {
    final cid = await CustomerRepository(db).create(name: 'Acik${gun.day}');
    final oid = await OrderRepository(db).create(
      customerId: cid,
      lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1)],
    );
    await (db.update(db.orders)..where((t) => t.id.equals(oid)))
        .write(OrdersCompanion(occurredAt: Value(_damga(gun))));
  }

  Future<String> gunuKapat(DateTime gun) =>
      DayClosingRepository(db).kapat(scope: ClosingScope.day, localDate: gun);

  Future<void> kapanisiGeriAl(String kapanisId, DateTime gun) async {
    await db.into(db.dayClosings).insert(DayClosingsCompanion.insert(
          id: 'geri-$kapanisId',
          scope: 'day',
          reversesClosingId: Value(kapanisId),
          occurredAt: _damga(gun),
        ));
  }

  KapanmamisGunlerRepository get repo => KapanmamisGunlerRepository(db);
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // SAF KURAL — tarih aralığı (veritabanı yok)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('taranacakGunler — aralık kuralı', () {
    final bugun = DateTime(2026, 8, 21);

    test('BUGÜN listede YOKTUR; dünden başlar', () {
      final g = taranacakGunler(bugun: bugun, gerideMax: 3);
      expect(g.first, DateTime(2026, 8, 20));
      expect(g.contains(bugun), isFalse);
    });

    test('YENİDEN ESKİYE sıralı ve tam [gerideMax] gün', () {
      expect(taranacakGunler(bugun: bugun, gerideMax: 3),
          [DateTime(2026, 8, 20), DateTime(2026, 8, 19), DateTime(2026, 8, 18)]);
    });

    test('SON KAPANIŞ alt sınırdır — kapanış gününün KENDİSİ dahil değil', () {
      final g = taranacakGunler(
          bugun: bugun, sonKapanisGunu: DateTime(2026, 8, 18), gerideMax: 14);
      expect(g, [DateTime(2026, 8, 20), DateTime(2026, 8, 19)]);
    });

    test('son kapanış DÜNSE liste BOŞ — arada kapanmamış gün yok', () {
      expect(
        taranacakGunler(bugun: bugun, sonKapanisGunu: DateTime(2026, 8, 20), gerideMax: 14),
        isEmpty,
      );
    });

    test('DAR OLAN SINIR KAZANIR — çok eski kapanış pencereyi genişletemez', () {
      // Bayi 6 ay önce bir gün kapatmış ve bir daha hiç kapatmamış olabilir. Alt sınırı ona
      // demirlemek 180 satırlık bir duvar üretir ve uyarıyı körleştirir.
      final g = taranacakGunler(
          bugun: bugun, sonKapanisGunu: DateTime(2026, 2, 1), gerideMax: 14);
      expect(g, hasLength(14));
      expect(g.last, DateTime(2026, 8, 7));
    });

    test('AY/YIL SINIRI doğru geçilir (DateTime normalize eder)', () {
      final g = taranacakGunler(bugun: DateTime(2027, 1, 2), gerideMax: 3);
      expect(g, [DateTime(2027, 1, 1), DateTime(2026, 12, 31), DateTime(2026, 12, 30)]);
    });

    test('gerideMax 0 ya da negatifse liste BOŞ (kapalı özellik gibi davranır)', () {
      expect(taranacakGunler(bugun: bugun, gerideMax: 0), isEmpty);
      expect(taranacakGunler(bugun: bugun, gerideMax: -5), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // REPO — gerçek veriyle
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('KapanmamisGunlerRepository', () {
    test('HAREKETSİZ gün kapanmamış SAYILMAZ — bayi o gün çalışmadı', () async {
      final f = await GunFikstur.kur();
      addTearDown(f.db.close);
      await f.teslimat(f.gunOnce(1));
      // gunOnce(2) ve gunOnce(3) boş.

      expect(await f.repo.gunler(), [f.gunOnce(1)]);
    });

    test('BUGÜNÜN hareketi listeyi doldurmaz — bugün henüz kapanmadı', () async {
      final f = await GunFikstur.kur();
      addTearDown(f.db.close);
      await f.teslimat(f.bugun);

      expect(await f.repo.gunler(), isEmpty);
    });

    test('KAPATILMIŞ gün listeden düşer', () async {
      final f = await GunFikstur.kur();
      addTearDown(f.db.close);
      await f.teslimat(f.gunOnce(1));
      await f.teslimat(f.gunOnce(2));

      expect(await f.repo.sayi(), 2);
      await f.gunuKapat(f.gunOnce(1));
      // gunOnce(1) kapandı → alt sınır oraya çekilir, gunOnce(2) de kapsam dışına çıkar.
      expect(await f.repo.gunler(), isEmpty,
          reason: 'son kapanıştan ÖNCESİ bilinçli olarak geride bırakılmıştır');
    });

    test('ARADAKİ gün kapatılınca yalnız SONRAKİLER kalır', () async {
      final f = await GunFikstur.kur();
      addTearDown(f.db.close);
      await f.teslimat(f.gunOnce(1));
      await f.teslimat(f.gunOnce(2));
      await f.teslimat(f.gunOnce(3));

      await f.gunuKapat(f.gunOnce(2));

      expect(await f.repo.gunler(), [f.gunOnce(1)]);
    });

    test('GERİ ALINMIŞ kapanış günü kapatmaz — gün listeye GERİ döner', () async {
      // Bu, sessiz bozulma adayının ta kendisi: geri alma satırı "kapanış" sayılsaydı bayi
      // kapanışı geri alır ama uyarı hiç geri gelmezdi.
      final f = await GunFikstur.kur();
      addTearDown(f.db.close);
      await f.teslimat(f.gunOnce(1));
      final id = await f.gunuKapat(f.gunOnce(1));
      expect(await f.repo.gunler(), isEmpty);

      await f.kapanisiGeriAl(id, f.gunOnce(1));

      expect(await f.repo.gunler(), [f.gunOnce(1)],
          reason: 'geri alınan kapanış gün açar; geri alma satırının kendisi kapanış DEĞİLDİR');
    });

    test('SINIRIN DIŞINDAKİ gün listeye girmez', () async {
      final f = await GunFikstur.kur();
      addTearDown(f.db.close);
      await f.teslimat(f.gunOnce(20));
      await f.teslimat(f.gunOnce(2));

      expect(await f.repo.gunler(gerideMax: 14), [f.gunOnce(2)]);
    });

    test('AÇIK SİPARİŞ engeli satırda taşınır — kapatılamayan gün sebebini söyler', () async {
      final f = await GunFikstur.kur();
      addTearDown(f.db.close);
      await f.teslimat(f.gunOnce(1), kurus: 12000);
      await f.acikSiparis(f.gunOnce(1));

      final liste = await f.repo.bul();
      expect(liste, hasLength(1));
      expect(liste.single.gun, f.gunOnce(1));
      expect(liste.single.acikSiparis, 1);
      expect(liste.single.kapatilabilir, isFalse);
      expect(liste.single.teslimat, 1);
      expect(liste.single.kasaKurus, 12000, reason: 'o günün kasası — bugünün değil');
    });

    test('ÖZET RAKAMLARI GÜNE AİTTİR, birbirine karışmaz', () async {
      final f = await GunFikstur.kur();
      addTearDown(f.db.close);
      await f.teslimat(f.gunOnce(1), kurus: 1000);
      await f.teslimat(f.gunOnce(2), kurus: 2000);
      await f.teslimat(f.gunOnce(2), kurus: 3000);

      final liste = await f.repo.bul();
      expect(liste.map((k) => k.gun), [f.gunOnce(1), f.gunOnce(2)], reason: 'yeniden eskiye');
      expect(liste[0].kasaKurus, 1000);
      expect(liste[0].teslimat, 1);
      expect(liste[1].kasaKurus, 5000);
      expect(liste[1].teslimat, 2);
    });

    test('VERESİYE günü de HAREKETLİDİR — kasası 0 ama gün çalışılmıştır', () async {
      final f = await GunFikstur.kur();
      addTearDown(f.db.close);
      await f.teslimat(f.gunOnce(1), odeme: 'veresiye');

      final liste = await f.repo.bul();
      expect(liste, hasLength(1));
      expect(liste.single.kasaKurus, 0);
      expect(liste.single.teslimat, 1,
          reason: 'kasa boş diye "çalışılmadı" demek, veresiye günü görünmez kılardı');
    });
  });
}
