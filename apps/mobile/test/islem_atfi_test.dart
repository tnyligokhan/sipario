// İŞLEM ATFI — "uygulamada yapılan her işlem, o işlemi YAPAN hesaba yazılır"
// (kullanıcı kararı 2026-08-20).
//
// ══ KAPATILAN ARIZA ═════════════════════════════════════════════════════════════════════════
// Saha bildirimi iki maddeydi ve ikisinin de kökü aynıydı:
//   1. "Patron atanmış kuryenin teslimatını yaparsa saçmalıyor."
//   2. "Kurye Ali'ye 1.200 ₺lik sipariş aktarıldı, patron veresiye işaretledi — veresiye
//      KURYENİN hesabında görünüyor."
//
// Sebep: gün özeti teslimatı ve günün veresiyesini `orders.assigned_user_id`den okuyordu.
// ATAMA BİR NİYETTİR ("bunu Ali götürecek"), muhasebe kaydı değil. Parası zaten doğru kişideydi
// (`ledger_entries.collected_by_user_id`), yani AYNI OLAYIN İKİ YARISI İKİ AYRI KİŞİYE gidiyordu.
//
// Bu dosya kuralı üç katmanda birden kilitler: yazma (`deliver` ne yazıyor), okuma (gün özeti
// kimin hesabına sayıyor) ve GERİYE DÖNÜK davranış (v25 öncesi kayıtlar).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/gun_veresiye_repository.dart';
import 'package:sipario/repo/islem_sahibi.dart';
import 'package:sipario/repo/order_repository.dart';

/// Bir bayi: patron (oturumdaki kişi) + kurye Ali + bir müşteri.
///
/// FİKSTÜR SINIFI (CLAUDE.md 2026-08-17 kuralı): durum ve onun üzerinde işleyen davranış aynı
/// nesnede; dışarıya dar bir yüzey açılır. Her teste kopyalanan kurulum kapanışları zamanla
/// ayrışır ve bir dosya "yeşil" görünürken başka bir senaryoyu sınar.
class AtifBayisi {
  AtifBayisi._(this.db, this.musteriId);

  final AppDatabase db;
  final String musteriId;

  static const patronId = 'p1';
  static const aliId = 'k1';

  /// [oturum] uygulamaya GİRMİŞ kullanıcıdır — `deliver` atfı ondan alır.
  static Future<AtifBayisi> kur({String oturum = patronId}) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.users).insert(UsersCompanion.insert(
        id: patronId, name: 'Mehmet Usta', role: 'patron', status: 'active'));
    await db.into(db.users).insert(UsersCompanion.insert(
        id: aliId, name: 'Ali', role: 'kurye', status: 'active'));
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(userId: Value(oturum)));
    final musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
    return AtifBayisi._(db, musteriId);
  }

  /// Ali'ye ATANMIŞ bir sipariş açar (niyet: "bunu Ali götürecek").
  Future<String> aliyeAtanmisSiparis({int kurus = 120000}) async {
    final oid = await OrderRepository(db).create(customerId: musteriId, lines: [
      LineInput(productName: 'Damacana', unitPriceKurus: kurus, qty: 1),
    ]);
    await OrderRepository(db).assign(oid, aliId);
    return oid;
  }

  Future<void> teslimEt(String orderId, {required String odeme}) =>
      OrderRepository(db).deliver(orderId, paymentType: odeme);

  Future<Order> siparis(String orderId) =>
      (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();

  /// v25 ÖNCESİ kaydı taklit eder: teslim eden alanı boş, yalnız atama var.
  Future<void> teslimEdeniSil(String orderId) async {
    await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
        .write(const OrdersCompanion(deliveredByUserId: Value(null)));
  }

  Future<int> teslimat({String? userId, String? haric}) =>
      DayEndRepository(db).teslimatSayisi(DayEndRepository.bugunTr(),
          userId: userId, haric: haric);

  Future<int> veresiye({String? userId, String? haric}) =>
      GunVeresiyeRepository(db)
          .toplam(DayEndRepository.bugunTr(), userId: userId, haric: haric);

  Future<int> kasa({String? userId, String? haric}) async =>
      (await DayEndRepository(db)
              .kasaOzeti(DayEndRepository.bugunTr(), userId: userId, haric: haric))
          .toplam;
}

void main() {
  group('Teslimi KİM yaptı — yazma', () {
    test('teslim eden oturumdaki kullanıcıdır, ATANAN kurye değil', () async {
      final b = await AtifBayisi.kur(); // oturum: PATRON
      addTearDown(b.db.close);
      final oid = await b.aliyeAtanmisSiparis();

      await b.teslimEt(oid, odeme: 'nakit');

      final o = await b.siparis(oid);
      expect(o.assignedUserId, AtifBayisi.aliId, reason: 'atama DEĞİŞMEZ — rota planı odur');
      expect(o.deliveredByUserId, AtifBayisi.patronId, reason: 'işi fiilen patron yaptı');
    });

    test('borç satırı da işlemi yapanı taşır (veresiyenin atfı buradan çıkar)', () async {
      final b = await AtifBayisi.kur();
      addTearDown(b.db.close);
      final oid = await b.aliyeAtanmisSiparis();
      await b.teslimEt(oid, odeme: 'veresiye');

      final borc = await (b.db.select(b.db.ledgerEntries)
            ..where((t) => t.entryType.equals('debit')))
          .getSingle();
      expect(borc.collectedByUserId, AtifBayisi.patronId);
    });

    test('kurye kendi teslimini yaparsa atıf ONA yazılır (olağan hâl bozulmadı)', () async {
      final b = await AtifBayisi.kur(oturum: AtifBayisi.aliId);
      addTearDown(b.db.close);
      final oid = await b.aliyeAtanmisSiparis();

      await b.teslimEt(oid, odeme: 'veresiye');

      expect((await b.siparis(oid)).deliveredByUserId, AtifBayisi.aliId);
      expect(await b.veresiye(userId: AtifBayisi.aliId), 120000);
      expect(await b.veresiye(userId: AtifBayisi.patronId), 0);
    });
  });

  group('Gün özeti — atıf teslim edene gider', () {
    test('MADDE 1: patron, Ali\'ye atanmış siparişi teslim ederse teslimat PATRONUNDUR',
        () async {
      final b = await AtifBayisi.kur();
      addTearDown(b.db.close);
      await b.teslimEt(await b.aliyeAtanmisSiparis(), odeme: 'nakit');

      expect(await b.teslimat(userId: AtifBayisi.patronId), 1);
      expect(await b.teslimat(userId: AtifBayisi.aliId), 0,
          reason: 'Ali bu işi YAPMADI; hesabında görünmesi onu var olmayan bir kasadan '
              'sorumlu tutardı');
      expect(await b.teslimat(), 1, reason: 'gün geneli değişmez');
    });

    test('MADDE 2: patron veresiye işaretlerse borç PATRONUN hesabına yazılır', () async {
      final b = await AtifBayisi.kur();
      addTearDown(b.db.close);
      await b.teslimEt(await b.aliyeAtanmisSiparis(), odeme: 'veresiye');

      expect(await b.veresiye(userId: AtifBayisi.patronId), 120000);
      expect(await b.veresiye(userId: AtifBayisi.aliId), 0, reason: 'saha şikâyetinin ta kendisi');
      expect(await b.veresiye(), 120000);
    });

    test('para ile teslimat AYNI kişide buluşur — olayın iki yarısı ayrışmaz', () async {
      final b = await AtifBayisi.kur();
      addTearDown(b.db.close);
      await b.teslimEt(await b.aliyeAtanmisSiparis(kurus: 4500), odeme: 'nakit');

      expect(await b.kasa(userId: AtifBayisi.patronId), 4500);
      expect(await b.teslimat(userId: AtifBayisi.patronId), 1);
      expect(await b.kasa(userId: AtifBayisi.aliId), 0);
      expect(await b.teslimat(userId: AtifBayisi.aliId), 0);
    });
  });

  group('Geriye dönük — v25 öncesi kayıtlar', () {
    test('teslim eden yazılmamışsa ATAMAYA düşülür (eski günler eskisi gibi görünür)', () async {
      final b = await AtifBayisi.kur();
      addTearDown(b.db.close);
      final oid = await b.aliyeAtanmisSiparis();
      await b.teslimEt(oid, odeme: 'veresiye');
      await b.teslimEdeniSil(oid); // v25 öncesi kayıt

      expect(await b.teslimat(userId: AtifBayisi.aliId), 1,
          reason: 'bilinmeyeni uydurmuyoruz; elimizdeki tek atıf atamadır');
      expect(await b.veresiye(userId: AtifBayisi.aliId), 120000);
    });

    test('siparisSahibi saf kuralı: teslim eden varsa o, yoksa atanan', () {
      expect(siparisSahibi(deliveredByUserId: 'p1', assignedUserId: 'k1'), 'p1');
      expect(siparisSahibi(deliveredByUserId: null, assignedUserId: 'k1'), 'k1');
      expect(siparisSahibi(deliveredByUserId: null, assignedUserId: null), isNull);
    });
  });

  group('"Elemanlar" kapsamı — ben hariç herkes', () {
    test('patronun kendi işi elemanlar kapsamına GİRMEZ, Ali\'ninki girer', () async {
      final b = await AtifBayisi.kur();
      addTearDown(b.db.close);
      // Patron kendi teslim eder.
      await b.teslimEt(await b.aliyeAtanmisSiparis(kurus: 1000), odeme: 'nakit');

      // Ali kendi teslim eder (oturum değişmiş gibi: atıf açıkça geçilir).
      final aliSiparisi = await b.aliyeAtanmisSiparis(kurus: 2000);
      await OrderRepository(b.db)
          .deliver(aliSiparisi, paymentType: 'nakit', collectedByUserId: AtifBayisi.aliId);

      expect(await b.kasa(), 3000, reason: 'Tümü');
      expect(await b.kasa(userId: AtifBayisi.patronId), 1000, reason: 'Kendi işlemlerim');
      expect(await b.kasa(haric: AtifBayisi.patronId), 2000, reason: 'Elemanlar');
      expect(await b.teslimat(haric: AtifBayisi.patronId), 1);
    });

    test('kapsamaDusuyor saf kuralı — sahibi bilinmeyen kayıt "eleman" sayılmaz', () {
      expect(kapsamaDusuyor('k1'), isTrue, reason: 'süzgeç yok = Tümü');
      expect(kapsamaDusuyor(null), isTrue);
      expect(kapsamaDusuyor('k1', userId: 'k1'), isTrue);
      expect(kapsamaDusuyor('p1', userId: 'k1'), isFalse);
      expect(kapsamaDusuyor('k1', haric: 'p1'), isTrue);
      expect(kapsamaDusuyor('p1', haric: 'p1'), isFalse);
      // Bilinmezliği bir iddiaya çevirmiyoruz: atfı olmayan kayıt kimsenin işi sayılmaz.
      expect(kapsamaDusuyor(null, haric: 'p1'), isFalse);
    });
  });
}
