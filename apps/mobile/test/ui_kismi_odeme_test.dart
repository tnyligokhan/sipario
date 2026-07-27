// Kısmi ödeme (saha eksiği 7) + sipariş dışı borç tahsilatı (saha eksiği 5b).
//
// DESEN: karar mantığı ekrandan bağımsız SAF fonksiyonlarda sınanır (drift akışları widget-test
// sahte zamanında güvenilmez — Dilim 1 dersi); widget testine yalnız "alan gerçekten
// düzenlenebilir mi" ve "sheet müşteri kimliğinden açılıyor mu" akışları kalır.
//
// KIRMIZI ÇİZGİ #2: hiçbir test kayıt silmez/günceller. Kısmi ödemenin tüm veri akışı
// debit(+tutar) + payment(−tahsil edilen) çift-satırıdır; kalan borç AYRI satır değil, ödenmemiş
// debit'in kendisidir. Testler bunu bakiye ÜZERİNDEN doğrular (bakiye = SUM(amount_kurus)).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/customers/customer_sheets.dart';
import 'package:sipario/screens/orders/delivery_sheet.dart';

import 'package:sipario/screens/orders/order_detail_screen.dart';

import 'support/ekran_yardimcilari.dart';
import 'support/siparis_yardimci.dart';

Future<Customer> _musteri(AppDatabase db, String id) =>
    (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();

Future<List<LedgerEntry>> _defter(AppDatabase db, String customerId) =>
    (db.select(db.ledgerEntries)..where((t) => t.customerId.equals(customerId))).get();

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Teslim — saf kurallar
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('teslimOdemeTipi (hiç para alınmadıysa kayıt veresiyedir)', () {
    test('tahsil 0 iken seçili karo ne olursa olsun veresiye yazılır', () {
      expect(teslimOdemeTipi('nakit', 0), 'veresiye');
      expect(teslimOdemeTipi('kart', 0), 'veresiye');
      expect(teslimOdemeTipi('veresiye', 0), 'veresiye');
    });

    test('para alındıysa seçilen tip korunur — kısmi de olsa', () {
      expect(teslimOdemeTipi('nakit', 12000), 'nakit');
      expect(teslimOdemeTipi('havale', 1), 'havale',
          reason: 'tek kuruş bile tahsilattır; kasa gözü ödeme tipinden çıkar');
    });
  });

  group('teslimBorcFarki (imzalı: + kalan borç, − fazla ödeme)', () {
    test('kısmi ödemede fark borçta kalır', () {
      expect(teslimBorcFarki(toplamKurus: 20000, tahsilKurus: 12000), 8000);
    });

    test('tam ödemede fark yok', () {
      expect(teslimBorcFarki(toplamKurus: 20000, tahsilKurus: 20000), 0);
    });

    test('fazla ödemede fark negatiftir (önceki borcu kapatır)', () {
      expect(teslimBorcFarki(toplamKurus: 20000, tahsilKurus: 25000), -5000);
    });

    test('sıfır tahsilat = tamamı veresiye', () {
      expect(teslimBorcFarki(toplamKurus: 20000, tahsilKurus: 0), 20000);
    });
  });

  group('teslimTahsilatHatasi (müşterili siparişte her tutar geçerli)', () {
    String? hata(int? tahsil, {bool musteriVar = true}) => teslimTahsilatHatasi(
        tahsilKurus: tahsil, toplamKurus: 20000, musteriVar: musteriVar);

    test('sıfır ödeme geçerlidir — tamamı veresiye meşru bir teslimdir', () {
      expect(hata(0), isNull);
    });

    test('kısmi ödeme geçerlidir', () {
      expect(hata(12000), isNull);
      expect(hata(1), isNull);
    });

    test('fazla ödeme geçerlidir — kasaya giren para reddedilmez', () {
      expect(hata(25000), isNull);
    });

    test('okunamayan yazım hatadır (sessiz yuvarlama yok)', () {
      expect(hata(null), isNotNull);
    });
  });

  group('teslimTahsilatHatasi (tezgâh satışı — tutar TAM olmalı)', () {
    String? hata(int? tahsil) => teslimTahsilatHatasi(
        tahsilKurus: tahsil, toplamKurus: 20000, musteriVar: false);

    test('tam tutar geçerli', () => expect(hata(20000), isNull));

    test('eksik tahsilat reddedilir — borcu yazacak müşteri yok', () {
      expect(hata(12000), isNotNull);
    });

    test('fazla tahsilat reddedilir — alacağı yazacak müşteri yok', () {
      expect(hata(25000), isNotNull);
    });

    test('sıfır (tamamı veresiye) reddedilir', () => expect(hata(0), isNotNull));
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Tahsilat sheet — saf kurallar
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('tahsilatSonrasiBakiye', () {
    test('kısmi tahsilat borcu azaltır, kapatmaz', () {
      expect(tahsilatSonrasiBakiye(50000, 20000), 30000);
    });

    test('tam tahsilat bakiyeyi sıfırlar', () {
      expect(tahsilatSonrasiBakiye(50000, 50000), 0);
    });

    test('fazla tahsilat müşteriyi alacaklı yapar (bakiye negatif)', () {
      expect(tahsilatSonrasiBakiye(50000, 60000), -10000);
    });
  });

  group('tahsilatHatasi (tek kural: para gerçekten alınmış olmalı)', () {
    test('0 ve okunamayan yazım reddedilir', () {
      expect(tahsilatHatasi(0), isNotNull);
      expect(tahsilatHatasi(null), isNotNull);
    });

    test('açık borçtan fazlası REDDEDİLMEZ — kasaya giren para deftere girer', () {
      expect(tahsilatHatasi(999999), isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Defter değişmezi — kısmi ödemenin veri akışı (append-only)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('kısmi ödeme defter değişmezi: debit(+tutar) + payment(−tahsil)', () {
    test('200 ₺ satışın 120 ₺si alınırsa bakiye 80 ₺ borç kalır, kasaya 120 ₺ girer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Kısmi Ödeyen');
      final ledger = LedgerRepository(db);

      await ledger.borcEkle(cid, 20000); // satışın debit satırı
      await ledger.tahsilat(cid, 12000, 'nakit'); // alınan para

      expect((await _musteri(db, cid)).balanceKurus, 8000,
          reason: 'kalan borç AYRI kayıt değil, ödenmemiş debit farkıdır');

      final kayitlar = await _defter(db, cid);
      expect(kayitlar.length, 2, reason: 'kısmi ödeme fazladan satır üretmez');
      final odeme = kayitlar.firstWhere((e) => e.entryType == 'payment');
      expect(odeme.amountKurus, -12000, reason: 'kasa gözüne giren gerçek tutar');
      expect(odeme.paymentType, 'nakit');
    });

    test('sıfır tahsilat (tamamı veresiye) yalnız debit yazar', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Veresiyeci');

      await LedgerRepository(db).borcEkle(cid, 20000);

      final kayitlar = await _defter(db, cid);
      expect(kayitlar.length, 1);
      expect(kayitlar.single.entryType, 'debit');
      expect((await _musteri(db, cid)).balanceKurus, 20000);
    });

    test('fazla ödeme önceki borcu kapatır; hiçbir kayıt silinmez/güncellenmez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Eski Borçlu');
      final ledger = LedgerRepository(db);

      await ledger.borcEkle(cid, 30000); // önceki borç
      await ledger.borcEkle(cid, 20000); // yeni satış
      await ledger.tahsilat(cid, 60000, 'nakit'); // hepsini + fazlasını ödedi

      expect((await _musteri(db, cid)).balanceKurus, -10000,
          reason: 'fazlası alacak olarak durur — bakiye eksiye düşebilir');
      expect((await _defter(db, cid)).length, 3,
          reason: 'append-only: üç satır da yerinde, düzeltme/silme yok');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // OrderRepository.deliver — kısmi ödemenin uçtan uca yazımı
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('deliver(tahsilKurus:) — teslim + kısmi tahsilat tek transaction', () {
    Future<(AppDatabase, String, String)> kur({required int tutar}) async {
      final db = AppDatabase(NativeDatabase.memory());
      final cid = await CustomerRepository(db).create(name: 'Teslim Alan');
      final oid = await OrderRepository(db).create(
        customerId: cid,
        lines: [LineInput(productName: 'Damacana', unitPriceKurus: tutar, qty: 1)],
      );
      return (db, cid, oid);
    }

    test('200 ₺ siparişin 120 ₺si alınır: debit +200, payment −120, bakiye 80 borç', () async {
      final (db, cid, oid) = await kur(tutar: 20000);
      addTearDown(db.close);

      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: 12000);

      final kayitlar = await _defter(db, cid);
      expect(kayitlar.length, 2, reason: 'kalan borç için ÜÇÜNCÜ bir satır üretilmez');
      expect(kayitlar.firstWhere((e) => e.entryType == 'debit').amountKurus, 20000,
          reason: 'satışın borcu her zaman TAM tutardır');
      final odeme = kayitlar.firstWhere((e) => e.entryType == 'payment');
      expect(odeme.amountKurus, -12000);
      expect(odeme.paymentType, 'nakit', reason: 'kasa nakit gözüne 120 ₺ girer');
      expect((await _musteri(db, cid)).balanceKurus, 8000);
    });

    test('tahsilKurus verilmezse eski davranış korunur (peşin = tamamı)', () async {
      final (db, cid, oid) = await kur(tutar: 20000);
      addTearDown(db.close);

      await OrderRepository(db).deliver(oid, paymentType: 'nakit');

      expect((await _musteri(db, cid)).balanceKurus, 0, reason: 'geriye uyumluluk');
      expect((await _defter(db, cid)).length, 2);
    });

    test('tahsil 0 ise payment satırı HİÇ yazılmaz (yalnız debit)', () async {
      final (db, cid, oid) = await kur(tutar: 20000);
      addTearDown(db.close);

      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: 0);

      final kayitlar = await _defter(db, cid);
      expect(kayitlar.single.entryType, 'debit',
          reason: '0 tutarlı payment kasayı kirletir, defterde anlamı yok');
      expect((await _musteri(db, cid)).balanceKurus, 20000);
    });

    test('veresiye tahsilKurus verilse bile tahsilat yazmaz', () async {
      final (db, cid, oid) = await kur(tutar: 20000);
      addTearDown(db.close);

      await OrderRepository(db).deliver(oid, paymentType: 'veresiye', tahsilKurus: 5000);

      expect((await _defter(db, cid)).single.entryType, 'debit',
          reason: "payment_type='veresiye' taşıyan ödeme satırını sunucu reddederdi");
    });

    test('sipariş tutarını AŞAN tahsilat önceki borcu kapatır, bakiye alacağa geçer', () async {
      final (db, cid, oid) = await kur(tutar: 20000);
      addTearDown(db.close);
      await LedgerRepository(db).borcEkle(cid, 30000); // önceki borç

      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: 60000);

      expect((await _musteri(db, cid)).balanceKurus, -10000,
          reason: 'kasaya giren para payment olarak yazılmazsa gün sonu kasa özeti yanlış çıkar');
    });

    test('kısmi ödeme teslim idempotensini BOZMAZ (id sipariş kimliğinden türer)', () async {
      final (db, cid, oid) = await kur(tutar: 20000);
      addTearDown(db.close);

      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: 12000);
      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: 12000);

      expect((await _defter(db, cid)).length, 2, reason: 'ikinci dokunma erken döner');
      expect((await _musteri(db, cid)).balanceKurus, 8000);
    });
  });
}
