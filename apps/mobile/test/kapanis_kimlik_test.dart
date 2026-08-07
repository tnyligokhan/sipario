import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/ids.dart' show kapanisOlayId;
import 'package:sipario/data/tr_gun.dart' show trGunAnahtari;
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/ledger_ops.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';

import 'support/fake_sync_api.dart';

/// KAPANIŞ KİMLİĞİ — cihazlar arası yarış (üçüncü inceleme ①-b, 2026-08-06).
///
/// `kapaliMi` kapısı (bkz. `kapanis_butunlugu_test.dart`) TEK cihazı bağlar. İki cihaz
/// birbirinden habersiz aynı kurye/günü kapatırsa ikisi de yerelde geçer, İKİ `day_closings` +
/// İKİ `cash_handovers` doğar ve `teslimEdilenNakit` ikisini birden sayar.
///
/// Sunucuda tekillik İNDEKSİ denendi ve reddedildi: kapanış sunucuya İKİ AYRI olay olarak gidiyor,
/// indeks yalnız arşiv satırını reddediyor, para hatası aynen kalıyor ve sahipsiz kalan devir
/// sistemin kendi kuralıyla ("kapanışa bağlı olmayan devir ARA tahsilattır") HAYALET bir ara
/// tahsilata terfi ediyordu — yani indeks okuma tarafını daha da bozuyordu.
///
/// Doğru kapak DETERMİNİSTİK ID ve depo bu kalıbı teslim idempotensinde zaten kullanıyor
/// (`deliveryEventId`). Bu dosya çekirdeğin dört ayracını (kiracı · kapsam · kurye · gün) ve
/// ARA TAHSİLATLARIN kapsam DIŞINDA kaldığını kilitler.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final bugun = bugunTr();
  final dun = bugun.subtract(const Duration(days: 1));

  /// TR takvim gününün UTC gün başı.
  DateTime gunBasiUtc(DateTime trGun) =>
      DateTime.utc(trGun.year, trGun.month, trGun.day).subtract(const Duration(hours: 3));

  /// [gun] içinde KESİN kalan bir damga.
  String gunIci(DateTime gun) =>
      gunBasiUtc(gun).add(const Duration(hours: 9)).toIso8601String();

  Future<void> kurye(String id, String ad) => db.into(db.users).insert(
      UsersCompanion.insert(id: id, name: ad, role: 'kurye', status: 'active'));

  Future<void> nakit(int kurus, {required String kuryeId, required String at}) =>
      writeLedgerEntry(db,
          entryType: 'payment',
          amountKurus: -kurus, // tahsilat NEGATİF yazılır; kasaya giren = −amount
          paymentType: 'nakit',
          collectedByUserId: kuryeId,
          occurredAt: at);

  /// Sunucu sahipli firma kodunu yerine koyar — deterministik kimliğin çekirdek girdisi.
  Future<void> firmaKodu(AppDatabase hedef, String kod) async {
    await hedef.syncState();
    await (hedef.update(hedef.syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(tenantCode: Value(kod)));
  }

  group('①-b iki cihaz aynı kapanışı yazsa da tek satır kalır', () {
    /// Laravel `attributesToArray()` damgası (mikrosaniyeli ISO-8601 + 'Z').
    String sunucuDamgasi(DateTime t) =>
        '${t.toUtc().toIso8601String().replaceFirst(RegExp(r'Z$'), '')}000Z';

    /// İKİNCİ CİHAZ: ayrı DB, AYNI firma kodu, AYNI defter. Kapatır ve kendi satırlarını döner.
    Future<(DayClosing, CashHandover)> ikinciCihaz(String kod) async {
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      await firmaKodu(db2, kod);
      await db2.into(db2.users).insert(
          UsersCompanion.insert(id: 'k1', name: 'Emre', role: 'kurye', status: 'active'));
      await writeLedgerEntry(db2,
          entryType: 'payment',
          amountKurus: -10000,
          paymentType: 'nakit',
          collectedByUserId: 'k1',
          occurredAt: gunIci(bugun));

      await DayClosingRepository(db2).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 10000,
        alsoHandover: true,
        localDate: bugun,
      );
      return (
        (await db2.select(db2.dayClosings).get()).single,
        (await db2.select(db2.cashHandovers).get()).single,
      );
    }

    test('aynı kapanış her cihazda AYNI id; senkron ikinci satırı EKLEMEZ', () async {
      await firmaKodu(db, 'BAYI-42');
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: gunIci(bugun));

      final idA = await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 10000,
        alsoHandover: true,
        localDate: bugun,
      );
      final devirA = (await db.select(db.cashHandovers).get()).single;

      final (kapanisB, devirB) = await ikinciCihaz('BAYI-42');
      expect(kapanisB.id, idA,
          reason: 'çekirdek tenant|scope|user|gün — iki cihaz aynı uuid5\'i üretmeli');
      expect(devirB.id, devirA.id, reason: 'kapanışa bağlı devir de aynı çekirdekten');

      // İkinci cihazın satırları sunucudan İNİYOR. Uygulayıcı "yoksa ekle, asla ezme" der;
      // id aynı olduğu için ikisi de atlanır.
      final api = FakeSyncApi();
      final motor = SyncEngine(db, api);
      final at = sunucuDamgasi(DateTime.now().toUtc().add(const Duration(minutes: 1)));
      api.pullQueue.add(PullResponse(
        mode: 'delta',
        cursor: 20,
        hasMore: false,
        currentSeq: 20,
        changes: [
          {
            'seq': 19,
            'entity_type': 'cash_handover',
            'entity_id': devirB.id,
            'op': 'upsert',
            'occurred_at': at,
            'payload': {
              'id': devirB.id,
              'from_user_id': devirB.fromUserId,
              'counted_cash_kurus': devirB.countedCashKurus,
              'expected_cash_kurus': devirB.expectedCashKurus,
              'diff_kurus': devirB.diffKurus,
              'occurred_at': at,
              'device_id': 'ikinci-cihaz',
            },
          },
          {
            'seq': 20,
            'entity_type': 'day_closing',
            'entity_id': kapanisB.id,
            'op': 'upsert',
            'occurred_at': at,
            'payload': {
              'id': kapanisB.id,
              'scope': 'courier',
              'user_id': 'k1',
              'expected_cash_kurus': kapanisB.expectedCashKurus,
              'counted_cash_kurus': kapanisB.countedCashKurus,
              'diff_kurus': kapanisB.diffKurus,
              'cash_handover_id': devirB.id,
              'occurred_at': at,
              'device_id': 'ikinci-cihaz',
            },
          },
        ],
      ));
      await motor.pull();

      expect(await db.select(db.dayClosings).get(), hasLength(1));
      expect(await db.select(db.cashHandovers).get(), hasLength(1));
      expect(await CashHandoverRepository(db).teslimEdilenNakit(bugun, kuryeId: 'k1'), 10000,
          reason: 'ESKİ kod 20.000 sayardı — patron olmayan 10.000\'i arardı');

      final gun = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(gun.expectedCashKurus, 10000, reason: 'çift devirde 0 çıkardı ve "EKSİK" donardı');
      expect(await CashHandoverRepository(db).araTahsilatlar(bugun), isEmpty,
          reason: 'sahipsiz devir kalmadı → hayalet ara tahsilat da yok');
    });

    test('çekirdek KİRACIYI ayırır: farklı firma kodu farklı id', () async {
      // Sunucuda `day_closings.id` GLOBAL primary key. Kiracı ayracı olmasaydı `scope='day'`
      // çekirdeği tüm bayilerde aynı uuid'yi üretir ve ikinci bayinin kapanışı 'duplicate'
      // sayılıp SESSİZCE düşerdi.
      await firmaKodu(db, 'BAYI-42');
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: gunIci(bugun));
      final idA = await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 10000,
        alsoHandover: true,
        localDate: bugun,
      );

      final (baskaBayi, _) = await ikinciCihaz('BAYI-99');
      expect(baskaBayi.id, isNot(idA));
    });

    test('gün ve kurye kapsamları aynı gün ÇAKIŞMAZ; farklı gün farklı id', () async {
      await firmaKodu(db, 'BAYI-42');
      final gunId = kapanisOlayId(
          tenantCode: 'BAYI-42',
          scope: 'day',
          userId: null,
          gunAnahtari: trGunAnahtari(bugun),
          tag: 'closing');
      final kuryeId = kapanisOlayId(
          tenantCode: 'BAYI-42',
          scope: 'courier',
          userId: 'k1',
          gunAnahtari: trGunAnahtari(bugun),
          tag: 'closing');
      final dunId = kapanisOlayId(
          tenantCode: 'BAYI-42',
          scope: 'day',
          userId: null,
          gunAnahtari: trGunAnahtari(dun),
          tag: 'closing');
      final devirId = kapanisOlayId(
          tenantCode: 'BAYI-42',
          scope: 'courier',
          userId: 'k1',
          gunAnahtari: trGunAnahtari(bugun),
          tag: 'handover');

      expect({gunId, kuryeId, dunId, devirId}, hasLength(4),
          reason: 'kapsam · kurye · gün · etiket — dördü de çekirdeği ayırmalı');

      // Ve gerçekten YAZILAN id bu saf hesapla aynı olmalı; aksi hâlde iki cihaz ayrışır.
      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: gunIci(bugun));
      final yazilan = await DayClosingRepository(db).kapat(
          scope: ClosingScope.courier,
          userId: 'k1',
          countedCashKurus: 5000,
          localDate: bugun);
      expect(yazilan, kuryeId);
    });

    test('geçmiş gün kapanışı O GÜNÜN çekirdeğini kullanır ("şimdi"nin değil)', () async {
      await firmaKodu(db, 'BAYI-42');
      await kurye('k1', 'Emre');
      await nakit(4000, kuryeId: 'k1', at: gunIci(dun));

      final id = await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 0, localDate: dun);
      expect(
          id,
          kapanisOlayId(
              tenantCode: 'BAYI-42',
              scope: 'day',
              userId: null,
              gunAnahtari: trGunAnahtari(dun),
              tag: 'closing'),
          reason: 'dünü kapatan iki cihaz da aynı id\'yi üretmeli');
    });

    test('firma kodu HENÜZ İNMEMİŞSE id rastgeleye düşer (bilinçli koruma kaybı)', () async {
      // Kiracı ayracı olmadan deterministik id kiracılar arası ÇAKIŞIR ve o VERİ KAYBIDIR.
      // Korumasız kalmak bugünkü davranışa dönmektir — daha ucuz olan bu.
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: gunIci(bugun));
      final idA = await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 10000,
        alsoHandover: true,
        localDate: bugun,
      );

      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      await db2.into(db2.users).insert(
          UsersCompanion.insert(id: 'k1', name: 'Emre', role: 'kurye', status: 'active'));
      await writeLedgerEntry(db2,
          entryType: 'payment',
          amountKurus: -10000,
          paymentType: 'nakit',
          collectedByUserId: 'k1',
          occurredAt: gunIci(bugun));
      final idB = await DayClosingRepository(db2).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 10000,
        alsoHandover: true,
        localDate: bugun,
      );

      expect(idB, isNot(idA));
    });

    // PAZARLIKSIZ: ara tahsilat gün içinde defalarca alınabilmeli. Deterministik id oraya
    // sızsaydı ikinci tahsilat aynı satır sayılıp SESSİZCE yutulurdu ve özelliğin tamamı ölürdü.
    test('ARA TAHSİLATLAR rastgele id\'de kalır: aynı kurye/gün, üç ayrı satır', () async {
      await firmaKodu(db, 'BAYI-42');
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: gunIci(bugun));

      final devirler = CashHandoverRepository(db);
      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 3000);
      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 2000);
      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 1000);

      final satirlar = await db.select(db.cashHandovers).get();
      expect(satirlar, hasLength(3));
      expect(satirlar.map((r) => r.id).toSet(), hasLength(3), reason: 'üç ayrı kimlik');
      expect(await devirler.araTahsilatToplami(bugun), 6000,
          reason: 'yutulan tahsilat olsaydı toplam eksik çıkardı');
    });
  });
}
