// GÜN ÖZETİNİN İKİ EKSİK YARISI (saha isteği 2026-08-18):
//
//   1. "Gün özetinde veresiye işlemleri gözükmüyor" → `GunVeresiyeRepository`
//   2. "Borç tahsilatı kasaya işliyor fakat sipariş gibi gözüküyor" → `TahsilatKaynagi`
//
// İkisi de PARA KURALIDIR, görünüm değil: bu yüzden ekran testine değil repo testine bağlıdır.
// Ekran yalnız buradan çıkan sayıyı çizer.
//
// ⚠️ EN KRİTİK KİLİT `gunun debit toplami DEĞİL` testidir. `deliver` her teslimde tutarın
// TAMAMI kadar `debit` yazar — nakit teslimde bile — ve borç hemen ardından `payment` ile
// kapanır. Bu bilinmeden yazılacak en doğal uygulama (günün debit'lerini toplamak) NAKİT
// SATIŞLARI da veresiye gösterirdi ve gün özeti sistematik olarak yalan söylerdi.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/gun_veresiye_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';

void main() {
  final bugun = DayEndRepository.bugunTr();

  Future<(AppDatabase, String)> kur() async {
    final db = AppDatabase(NativeDatabase.memory());
    final musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
    return (db, musteriId);
  }

  Future<String> siparis(AppDatabase db, String musteriId, int kurus) =>
      OrderRepository(db).create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: kurus, qty: 1),
      ]);

  group('Günün veresiyeleri', () {
    test('NAKİT teslim veresiye ÜRETMEZ — "günün debit toplamı" tuzağı', () async {
      // Bu testin tek işi o tuzağı kapatmak. `deliver` 45,00 ₺'lik `debit` VE 45,00 ₺'lik
      // `payment` yazar; net sıfırdır. Debit'leri toplayan bir uygulama burada 45,00 ₺
      // "veresiye" derdi ve rakam her nakit satışta şişerdi.
      final (db, musteriId) = await kur();
      addTearDown(db.close);
      final oid = await siparis(db, musteriId, 4500);
      await OrderRepository(db).deliver(oid, paymentType: 'nakit');

      expect(await GunVeresiyeRepository(db).toplam(bugun), 0);
      expect(await GunVeresiyeRepository(db).gununVeresiyeleri(bugun), isEmpty);
    });

    test('VERESİYE teslim tutarın tamamını yazar', () async {
      final (db, musteriId) = await kur();
      addTearDown(db.close);
      final oid = await siparis(db, musteriId, 4500);
      await OrderRepository(db).deliver(oid, paymentType: 'veresiye');

      expect(await GunVeresiyeRepository(db).toplam(bugun), 4500);
      final satirlar = await GunVeresiyeRepository(db).gununVeresiyeleri(bugun);
      expect(satirlar, hasLength(1));
      expect(satirlar.single.musteriAd, 'Ayşe Yılmaz');
      expect(satirlar.single.kurus, 4500);
      expect(satirlar.single.elle, isFalse, reason: 'siparişten doğdu, elle girilmedi');
    });

    test('KISMİ ödemede yalnız ÖDENMEYEN kısım veresiyedir', () async {
      // Sahanın en sık hâli: 200 ₺'lik siparişin 120'si alınır, 80'i deftere yazılır.
      final (db, musteriId) = await kur();
      addTearDown(db.close);
      final oid = await siparis(db, musteriId, 20000);
      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: 12000);

      expect(await GunVeresiyeRepository(db).toplam(bugun), 8000);
    });

    test('İSKONTO veresiye SAYILMAZ — kırılan tutar bir alacak değildir', () async {
      final (db, musteriId) = await kur();
      addTearDown(db.close);
      final oid = await siparis(db, musteriId, 20000);
      // 180 ₺ alındı, 20 ₺ kırıldı: borçta hiçbir şey kalmadı.
      await OrderRepository(db)
          .deliver(oid, paymentType: 'nakit', tahsilKurus: 18000, iskontoKurus: 2000);

      expect(await GunVeresiyeRepository(db).toplam(bugun), 0);
    });

    test('ELLE borç girişi listede AYRI rozetle durur', () async {
      final (db, musteriId) = await kur();
      addTearDown(db.close);
      await LedgerRepository(db).borcEkle(musteriId, 5000, note: 'eski hesap');

      final satirlar = await GunVeresiyeRepository(db).gununVeresiyeleri(bugun);
      expect(satirlar, hasLength(1));
      expect(satirlar.single.kurus, 5000);
      expect(satirlar.single.elle, isTrue,
          reason: 'elle giriş bir SATIŞ değil defter düzeltmesidir; ciro sanılmamalı');
    });

    test('FAZLA ödeme BAŞKA bir siparişin veresiyesini GİZLEYEMEZ', () async {
      // ⚠️ Bu, eski hesabın (gün geneli tek toplam) sessizce yanlış cevap verdiği durumdur:
      // A siparişi 50 ₺ veresiye kalır, B siparişinde müşteri 200 ₺ fazla öder (eski borcunu da
      // kapatır). Gün geneli net −150 çıkar, sıfıra kırpılır ve A'nın 50 ₺'si KAYBOLUR.
      final (db, musteriId) = await kur();
      addTearDown(db.close);

      final a = await siparis(db, musteriId, 5000);
      await OrderRepository(db).deliver(a, paymentType: 'veresiye');

      final b = await siparis(db, musteriId, 10000);
      await OrderRepository(db).deliver(b, paymentType: 'nakit', tahsilKurus: 30000);

      expect(await GunVeresiyeRepository(db).toplam(bugun), 5000,
          reason: 'A hâlâ 50 ₺ veresiyedir; B\'deki fazla ödeme onu kapatmaz');
      // Bildirim de AYNI rakamı konuşmalı — iki hesap yasağı.
      final bildirim = await DayEndRepository(db).gunSonuBildirimVerisi(bugun);
      expect(bildirim.veresiyeKurus, 5000);
    });

    test('İPTAL edilen sipariş veresiye üretmez', () async {
      final (db, musteriId) = await kur();
      addTearDown(db.close);
      final oid = await siparis(db, musteriId, 4500);
      await OrderRepository(db).deliver(oid, paymentType: 'veresiye');
      await OrderRepository(db).cancel(oid);

      expect(await GunVeresiyeRepository(db).toplam(bugun), 0);
    });
  });

  group('Tahsilatın kaynağı', () {
    test('saf kural — dört hâlin dördü', () {
      final gun = DateTime(2026, 8, 18);
      // TR günü +03:00; 10:00 UTC = 13:00 TR, yani aynı gün.
      const buguneAit = '2026-08-18T10:00:00.000Z';
      const duneAit = '2026-08-17T10:00:00.000Z';

      expect(
        tahsilatKaynagi(
            entryType: 'payment',
            relatedOrderId: 'o1',
            siparisGunu: buguneAit,
            localDate: gun),
        TahsilatKaynagi.gununSiparisi,
      );
      expect(
        tahsilatKaynagi(
            entryType: 'payment', relatedOrderId: 'o1', siparisGunu: duneAit, localDate: gun),
        TahsilatKaynagi.gecmisSiparis,
      );
      expect(
        tahsilatKaynagi(
            entryType: 'payment', relatedOrderId: null, siparisGunu: null, localDate: gun),
        TahsilatKaynagi.borcTahsilati,
      );
      expect(
        tahsilatKaynagi(
            entryType: 'correction',
            relatedOrderId: 'o1',
            siparisGunu: buguneAit,
            localDate: gun),
        TahsilatKaynagi.duzeltme,
      );
    });

    test('SİPARİŞ BULUNAMAZSA bugüne yazılmaz — belirsizlikte ciro şişirilmez', () {
      expect(
        tahsilatKaynagi(
            entryType: 'payment',
            relatedOrderId: 'silinmis',
            siparisGunu: null,
            localDate: DateTime(2026, 8, 18)),
        TahsilatKaynagi.gecmisSiparis,
      );
    });

    test('bugünün siparişi ROZETSİZ — olağan hâl rozet taşımaz', () {
      expect(TahsilatKaynagi.gununSiparisi.etiket, isNull);
      expect(TahsilatKaynagi.gecmisSiparis.etiket, 'Geçmiş sipariş');
      expect(TahsilatKaynagi.borcTahsilati.etiket, 'Borç tahsilatı');
    });

    test('serbest borç tahsilatı KASAYA girer ama "bugünün siparişi" DEĞİLDİR', () async {
      // Kullanıcının tarifi: "borç tahsilatı yaptıysa kasaya işliyor fakat sipariş gibi
      // gözüküyor". Para kasada kalır (dahil edilir), etiketi değişir.
      final (db, musteriId) = await kur();
      addTearDown(db.close);
      await LedgerRepository(db).borcEkle(musteriId, 10000);
      await LedgerRepository(db).tahsilat(musteriId, 6000, 'nakit');

      final repo = DayEndRepository(db);
      expect((await repo.kasaOzeti(bugun)).nakit, 6000, reason: 'kasaya DAHİL kalır');

      final satirlar = await repo.tahsilatDetaylari(bugun);
      expect(satirlar, hasLength(1));
      expect(satirlar.single.kaynak, TahsilatKaynagi.borcTahsilati);
      expect(await repo.eskiBorcTahsilati(bugun), 6000);
    });

    test('bugünün teslimatı eski borç tahsilatı SAYILMAZ', () async {
      final (db, musteriId) = await kur();
      addTearDown(db.close);
      final oid = await siparis(db, musteriId, 4500);
      await OrderRepository(db).deliver(oid, paymentType: 'nakit');

      final repo = DayEndRepository(db);
      final satirlar = await repo.tahsilatDetaylari(bugun);
      expect(satirlar.single.kaynak, TahsilatKaynagi.gununSiparisi);
      expect(await repo.eskiBorcTahsilati(bugun), 0,
          reason: 'bugün satılıp bugün tahsil edilen para eski borç değildir');
    });
  });
}
