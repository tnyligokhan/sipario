// Para bildirim ÜRETİCİLERİ — kural ile defter arasındaki katman.
//
// Kural testleri (`bildirim_para_kurallari_test.dart`) saf; burada GERÇEK Drift veritabanı var:
// sınanan şey "defterden okunan veri kurala doğru bağlanıyor mu" ve "hata hâlinde patlamak
// yerine null dönüyor mu".
//
// Üreticiler `TaslakUretici` (= Future<BildirimTaslagi?> Function()) döner; tetikleyici bunları
// açılışta ve zamanlanmış anlarda çağırır. Gün damgalı kimlikler sayesinde tekrar güvenlidir —
// o özellik de burada kilitlenir.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/kurallar/para_ureticileri.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';


void main() {
  late AppDatabase db;
  late DayEndRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DayEndRepository(db);
  });
  tearDown(() => db.close());

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Gün sonu özeti
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('gunSonuOzetiUretici', () {
    test('hiç hareket yokken null döner (boş bildirim atılmaz)', () async {
      expect(await gunSonuOzetiUretici(repo)(), isNull);
    });

    test('gerçek defterden okunan rakamlar taslağa geçer', () async {
      final cid = await CustomerRepository(db).create(name: 'Ali Veli');
      final oid = await OrderRepository(db).create(
        customerId: cid,
        lines: [LineInput(productName: 'Damacana', unitPriceKurus: 20000, qty: 1)],
      );
      // 200 ₺ siparişin 120 ₺si nakit alındı → 80 ₺ veresiye yazıldı.
      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: 12000);

      final t = await gunSonuOzetiUretici(repo)();
      expect(t, isNotNull);
      expect(t!.kategori, BildirimKategori.gunSonuOzeti);
      expect(t.govde, contains('120,00 ₺'), reason: 'kasaya giren');
      expect(t.govde, contains('1 teslim'));
      expect(t.govde, contains('80,00 ₺'), reason: 'bugün yazılan veresiye');
      expect(t.yol, 'gunsonu');
    });

    test('aynı gün iki kez koşarsa AYNI kimlik döner (tekrar güvenli)', () async {
      await LedgerRepository(db)
          .borcEkle(await CustomerRepository(db).create(name: 'X'), 5000);
      final uretici = gunSonuOzetiUretici(repo);
      final a = await uretici();
      final b = await uretici();
      expect(a!.kimlik, b!.kimlik,
          reason: 'açılışta da koşuyor; ikinci koşum yeni bildirim doğurmamalı');
    });
  });

  group('hata hâlinde null döner, patlamaz', () {
    test('kapalı veritabanında üretici null döner', () async {
      // Bildirim bir KOLAYLIKTIR: bozuk bir okuma açılışı düşüremez.
      final kapali = AppDatabase(NativeDatabase.memory());
      final r = DayEndRepository(kapali);
      await kapali.close();

      expect(await gunSonuOzetiUretici(r)(), isNull);
    });
  });
}
