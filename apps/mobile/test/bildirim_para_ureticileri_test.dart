// Para bildirim ÜRETİCİLERİ — kural ile defter arasındaki katman.
//
// Kural testleri (`bildirim_para_kurallari_test.dart`) saf; burada GERÇEK Drift veritabanı var:
// sınanan şey "defterden okunan veri kurala doğru bağlanıyor mu" ve "hata hâlinde patlamak
// yerine null dönüyor mu".
//
// Üreticiler `TaslakUretici` (= Future<BildirimTaslagi?> Function()) döner; tetikleyici bunları
// açılışta ve zamanlanmış anlarda çağırır. Gün damgalı kimlikler sayesinde tekrar güvenlidir —
// o özellik de burada kilitlenir.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_ayarlari.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/kurallar/para_kurallari.dart';
import 'package:sipario/bildirim/kurallar/para_ureticileri.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';

/// Ayar deposu diske YAZMAZ: dizin sağlayıcı verilmezse depo hata yutup bellekte çalışır.
BildirimAyarlari _ayarlar() => BildirimAyarlari();

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

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Borç eşiği
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('borcEsigiUretici', () {
    test('eşik BELİRLENMEMİŞKEN (varsayılan kapalı) null döner', () async {
      final cid = await CustomerRepository(db).create(name: 'Borçlu');
      await LedgerRepository(db).borcEkle(cid, 999999);

      final ayarlar = _ayarlar();
      expect(ayarlar.borcEsigiKurus, kBorcEsigiKapali, reason: 'Faz 1 varsayılanı kapalı');
      expect(await borcEsigiUretici(repo, ayarlar)(), isNull);
    });

    test('eşik belirlenince bugün aşan müşteri bildirilir', () async {
      final cid = await CustomerRepository(db).create(name: 'Mehmet Usta');
      await LedgerRepository(db).borcEkle(cid, 205000);

      final ayarlar = _ayarlar();
      await ayarlar.borcEsigiYaz(200000);

      final t = await borcEsigiUretici(repo, ayarlar)();
      expect(t, isNotNull);
      expect(t!.kategori, BildirimKategori.borcEsigi);
      expect(t.govde, contains('Mehmet Usta'));
      expect(t.yol, 'musteri/$cid');
      expect(t.baslik, isNot(contains('Mehmet')),
          reason: 'başlık kilit ekranında görünür — ad sızmamalı');
    });

    test('eşiğin ALTINDA kalan borç bildirilmez', () async {
      final cid = await CustomerRepository(db).create(name: 'Az Borçlu');
      await LedgerRepository(db).borcEkle(cid, 150000);

      final ayarlar = _ayarlar();
      await ayarlar.borcEsigiYaz(200000);
      expect(await borcEsigiUretici(repo, ayarlar)(), isNull);
    });

    test('gün içinde tekrar koşmak AYNI kimliği döner (bütçe yemez)', () async {
      final cid = await CustomerRepository(db).create(name: 'A');
      await LedgerRepository(db).borcEkle(cid, 205000);
      final ayarlar = _ayarlar();
      await ayarlar.borcEsigiYaz(200000);

      final uretici = borcEsigiUretici(repo, ayarlar);
      final a = await uretici();
      final b = await uretici();
      expect(a!.kimlik, b!.kimlik);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Vadesi geçen borçlar
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('vadesiGecenUretici', () {
    test('gecikmiş borç yokken null döner', () async {
      final cid = await CustomerRepository(db).create(name: 'Taze Borçlu');
      await LedgerRepository(db).borcEkle(cid, 50000); // bugün yazıldı, 30 günden yeni
      expect(await vadesiGecenUretici(repo)(), isNull);
    });

    test('30 günden eski ödenmemiş borç bildirilir', () async {
      final cid = await CustomerRepository(db).create(name: 'Eski Borçlu');
      await _eskiBorc(db, cid, 50000, gunOnce: 45);

      final t = await vadesiGecenUretici(repo)();
      expect(t, isNotNull);
      expect(t!.kategori, BildirimKategori.vadesiGecenBorc);
      expect(t.govde, contains('Eski Borçlu'), reason: 'tek müşteride adıyla seslenir');
      expect(t.govde, contains('500,00 ₺'));
      expect(t.yol, 'musteri/$cid');
    });

    test('DÜZENLİ ÖDEYEN müşteri bildirilmez (FIFO eski borcu tüketir)', () async {
      final cid = await CustomerRepository(db).create(name: 'Düzenli');
      await _eskiBorc(db, cid, 30000, gunOnce: 90);
      await _eskiOdeme(db, cid, 30000, gunOnce: 75);
      await LedgerRepository(db).borcEkle(cid, 30000); // güncel, taze borç

      expect(await vadesiGecenUretici(repo)(), isNull,
          reason: 'bakiyesi var ama eski borcu ödemelerle kapanmış');
    });

    test('gün eşiği parametreyle daraltılabilir', () async {
      final cid = await CustomerRepository(db).create(name: 'Yirmi Günlük');
      await _eskiBorc(db, cid, 40000, gunOnce: 20);

      expect(await vadesiGecenUretici(repo)(), isNull, reason: '30 gün eşiğinde taze');
      expect(await vadesiGecenUretici(repo, gunEsigi: 15)(), isNotNull);
    });

    test('aynı hafta iki kez koşarsa AYNI kimlik döner', () async {
      final cid = await CustomerRepository(db).create(name: 'E');
      await _eskiBorc(db, cid, 50000, gunOnce: 45);
      final uretici = vadesiGecenUretici(repo);
      final a = await uretici();
      final b = await uretici();
      expect(a!.kimlik, b!.kimlik);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Dayanıklılık — üretici PATLAMAZ
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('hata hâlinde null döner, patlamaz', () {
    test('kapalı veritabanında üç üretici de null döner', () async {
      final kapali = AppDatabase(NativeDatabase.memory());
      final r = DayEndRepository(kapali);
      await kapali.close();

      expect(await gunSonuOzetiUretici(r)(), isNull);
      expect(await vadesiGecenUretici(r)(), isNull);
      final ayarlar = _ayarlar();
      await ayarlar.borcEsigiYaz(200000);
      expect(await borcEsigiUretici(r, ayarlar)(), isNull);
    });
  });
}

/// Geçmiş tarihli borç yazımı — `LedgerRepository` daima "şimdi" yazdığı için doğrudan tabloya
/// eklenir (yaşlandırma testlerinin tek yolu budur).
Future<void> _eskiBorc(AppDatabase db, String cid, int kurus, {required int gunOnce}) =>
    _eskiHareket(db, cid, kurus, gunOnce: gunOnce, tip: 'debit');

Future<void> _eskiOdeme(AppDatabase db, String cid, int kurus, {required int gunOnce}) =>
    _eskiHareket(db, cid, -kurus, gunOnce: gunOnce, tip: 'payment');

Future<void> _eskiHareket(
  AppDatabase db,
  String cid,
  int imzaliKurus, {
  required int gunOnce,
  required String tip,
}) async {
  final an = DateTime.now().toUtc().subtract(Duration(days: gunOnce));
  final id = 'test-$tip-$gunOnce-${imzaliKurus.abs()}';
  await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
        id: id,
        customerId: Value(cid),
        entryType: tip,
        amountKurus: imzaliKurus,
        paymentType: Value(tip == 'payment' ? 'nakit' : null),
        occurredAt: an.toIso8601String(),
        clientEventId: id,
      ));
  // Bakiye önbelleği defterden yeniden kurulur (kırmızı çizgi #2: bakiye elle EZİLMEZ).
  final hepsi =
      await (db.select(db.ledgerEntries)..where((t) => t.customerId.equals(cid))).get();
  await (db.update(db.customers)..where((t) => t.id.equals(cid))).write(
    CustomersCompanion(
      balanceKurus: Value(hepsi.fold<int>(0, (s, e) => s + e.amountKurus)),
    ),
  );
}
