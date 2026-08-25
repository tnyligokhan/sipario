// KAPANIŞI GERİ ALMA (kullanıcı kararı 2026-08-18: "patron hata yapabilir, kasayı kapattığında
// yönetici şifresi ile geriye alabilir, hesapta düzeltme yapabilir").
//
// Kapanış bugüne kadar TEK YÖNLÜYDÜ: yanlış sayılmış nakit arşive KALICI donuyordu. Geri alma,
// `day_closings`e yazılan TERS BİR SATIRdır — orijinal kanıt olarak yerinde kalır.
//
// ⚠️ BU DOSYANIN EN KRİTİK İKİ TESTİ:
//   • `yeniden kapatma AYRI BİR KAYIT olur` — kapanış id'si `tenant|scope|user|gün`
//     çekirdeğinden TÜRETİLİYOR. Deneme sırası çekirdeğe girmeseydi ikinci kapanış AYNI id'yi
//     üretir, yerelde birincil anahtar çakışır ve sunucuda 'duplicate' olurdu: düzeltilmiş
//     sayım HİÇ kaydedilmez, kullanıcı "düzelttim" sanırdı.
//   • `bağlı kasa devri de geri alınır` — atlanırsa yeniden kapatma İKİNCİ bir devir yazar,
//     `teslimEdilenNakit` ikisini birden sayar ve gün kapsamında beklenen nakit teslim edilen
//     paranın iki katı kadar düşer. Append-only olduğu için kalıcı.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart' show bugunTr;

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Kiracı kodu YAZILIR: kapanış id'si ondan türüyor. Yoksa id rastgeleye düşer ve
  /// "deneme sırası çekirdeğe giriyor mu" sorusu hiç sınanmamış olurdu.
  Future<void> kiraciKur() async {
    await db.syncState();
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(const SyncMetaCompanion(tenantCode: Value('bayi-a')));
  }

  Future<String> nakitSiparisTeslim(int kurus) async {
    final musteriId = await CustomerRepository(db).create(name: 'Ayşe');
    final oid = await OrderRepository(db).create(customerId: musteriId, lines: [
      LineInput(productName: 'Damacana', unitPriceKurus: kurus, qty: 1),
    ]);
    await OrderRepository(db).deliver(oid, paymentType: 'nakit');
    return oid;
  }

  group('gün hesabı', () {
    test('geri alma SİLMEZ — ters satır yazar, gün yeniden AÇILIR', () async {
      await kiraciKur();
      await nakitSiparisTeslim(5000);
      final repo = DayClosingRepository(db);

      final kapanisId = await repo.kapat(scope: ClosingScope.day, countedCashKurus: 4800);
      expect(await repo.kapaliMi(ClosingScope.day), isTrue);

      await repo.geriAl(closingId: kapanisId);

      expect(await repo.kapaliMi(ClosingScope.day), isFalse,
          reason: 'geri alınan gün yeniden açılmalı — özelliğin bütün amacı bu');

      // ORİJİNAL YERİNDE: append-only defterde düzeltme silmeyle değil ters kayıtla yapılır.
      final satirlar = await db.select(db.dayClosings).get();
      expect(satirlar, hasLength(2));
      final orijinal = satirlar.firstWhere((r) => r.id == kapanisId);
      expect(orijinal.countedCashKurus, 4800, reason: 'orijinal kayıt DEĞİŞMEMELİ');
      expect(satirlar.where((r) => r.reversesClosingId == kapanisId), hasLength(1));
    });

    test('geri alma satırının KENDİSİ kapanış sayılmaz', () async {
      // Sayılsaydı geri alma günü yeniden kapatır ve kullanıcı "geri aldım ama hâlâ kilitli"
      // derdi — özellik kendi kendini iptal ederdi.
      await kiraciKur();
      final repo = DayClosingRepository(db);
      final kapanisId = await repo.kapat(scope: ClosingScope.day);
      await repo.geriAl(closingId: kapanisId);

      expect(await repo.kapaliMi(ClosingScope.day), isFalse);
    });

    test('yeniden kapatma AYRI BİR KAYIT olur — düzeltilmiş sayım kaydedilir', () async {
      await kiraciKur();
      await nakitSiparisTeslim(5000);
      final repo = DayClosingRepository(db);

      final ilk = await repo.kapat(scope: ClosingScope.day, countedCashKurus: 4800);
      await repo.geriAl(closingId: ilk);
      final ikinci = await repo.kapat(scope: ClosingScope.day, countedCashKurus: 5000);

      expect(ikinci, isNot(ilk),
          reason: 'id deneme sırasını taşımalı; aynı id yerelde çakışır, sunucuda "duplicate" olur');
      expect(await repo.kapaliMi(ClosingScope.day), isTrue);

      final satirlar = await db.select(db.dayClosings).get();
      final gecerli =
          satirlar.where((r) => r.reversesClosingId == null && r.id == ikinci).single;
      expect(gecerli.countedCashKurus, 5000, reason: 'düzeltilmiş sayım kayda geçmeli');
    });

    test('aynı kapanış İKİ KEZ geri alınamaz', () async {
      await kiraciKur();
      final repo = DayClosingRepository(db);
      final kapanisId = await repo.kapat(scope: ClosingScope.day);
      await repo.geriAl(closingId: kapanisId);

      expect(() => repo.geriAl(closingId: kapanisId), throwsStateError);
    });

    test('geri alma kaydının kendisi geri alınamaz', () async {
      await kiraciKur();
      final repo = DayClosingRepository(db);
      final kapanisId = await repo.kapat(scope: ClosingScope.day);
      final geriAlmaId = await repo.geriAl(closingId: kapanisId);

      expect(() => repo.geriAl(closingId: geriAlmaId), throwsStateError);
    });

    test('outbox\'a `reverses_closing_id` taşıyan bir olay düşer', () async {
      // Sunucuya inmeyen bir geri alma, diğer telefonlarda HİÇ OLMAMIŞ demektir: kurye günü
      // hâlâ kapalı görür.
      await kiraciKur();
      final repo = DayClosingRepository(db);
      final kapanisId = await repo.kapat(scope: ClosingScope.day);
      await repo.geriAl(closingId: kapanisId);

      final kuyruk = await db.select(db.outbox).get();
      final geriAlma = kuyruk.where((o) => o.payload.contains('reverses_closing_id')).toList();
      expect(geriAlma, hasLength(1));
      expect(geriAlma.single.entityType, 'day_closing');
      expect(geriAlma.single.op, 'closing',
          reason: 'yeni bir op AÇILMAZ — eski sunucuda bilinmeyen op sessizce düşerdi');
      expect(geriAlma.single.payload, contains(kapanisId));
    });
  });

  group('kurye hesabı', () {
    /// Bir kurye + ona atanmış, teslim edilmiş nakit sipariş.
    Future<String> kuryeliGun(int kurus) async {
      final kuryeId = 'kurye-1';
      await db.into(db.users).insert(UsersCompanion.insert(
            id: kuryeId,
            name: 'Emre',
            role: 'kurye',
            status: 'active',
          ));
      final musteriId = await CustomerRepository(db).create(name: 'Ayşe');
      final oid = await OrderRepository(db).create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: kurus, qty: 1),
      ]);
      await OrderRepository(db).assign(oid, kuryeId);
      await OrderRepository(db)
          .deliver(oid, paymentType: 'nakit', collectedByUserId: kuryeId);
      return kuryeId;
    }

    test('BAĞLI KASA DEVRİ de geri alınır — yoksa para iki kez düşerdi', () async {
      await kiraciKur();
      final kuryeId = await kuryeliGun(10000);
      final repo = DayClosingRepository(db);
      final devirler = CashHandoverRepository(db);

      final kapanisId = await repo.kapat(
        scope: ClosingScope.courier,
        userId: kuryeId,
        countedCashKurus: 10000,
        alsoHandover: true,
      );

      final gun = bugunTr();
      expect(await devirler.teslimEdilenNakit(gun, kuryeId: kuryeId), 10000);

      await repo.geriAl(closingId: kapanisId);

      // NET SIFIR: orijinal(+) ve ters(−) satır birlikte toplanır. Süzme YOK — ters satır
      // parayı kendiliğinden geri getirir (`araTahsilatIptal` ile aynı aritmetik).
      expect(await devirler.teslimEdilenNakit(gun, kuryeId: kuryeId), 0,
          reason: 'kapanışla alınan devir de geri alınmalı, yoksa yeniden kapatma onu ikinci '
              'kez sayar ve beklenen nakit iki katı kadar düşer');

      final devirSatirlari = await db.select(db.cashHandovers).get();
      expect(devirSatirlari, hasLength(2));
      expect(devirSatirlari.where((h) => h.reversesHandoverId != null), hasLength(1));
    });

    test('gün hesabı KAPALIYKEN kurye hesabı geri alınamaz', () async {
      // Kilitli bir günün içindeki hesabı açmak, gün toplamının çoktan yuttuğu bir kapanışı
      // sessizce geçersiz kılardı. Sıra: önce gün, sonra kurye.
      await kiraciKur();
      final kuryeId = await kuryeliGun(10000);
      final repo = DayClosingRepository(db);

      final kuryeKapanis = await repo.kapat(
        scope: ClosingScope.courier,
        userId: kuryeId,
        countedCashKurus: 10000,
        alsoHandover: true,
      );
      await repo.kapat(scope: ClosingScope.day, countedCashKurus: 10000);

      expect(() => repo.geriAl(closingId: kuryeKapanis), throwsStateError);
    });
  });
}
