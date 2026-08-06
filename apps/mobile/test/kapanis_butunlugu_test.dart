import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/ledger_ops.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart';

/// KAPANIŞ BÜTÜNLÜĞÜ (üçüncü bağımsız inceleme, 2026-08-06).
///
/// Kusurların hepsi AYNI aileden: append-only bir kayda YANLIŞ bir para rakamı donuyor ve aylar
/// sonra kimse açıklayamıyor. Bu dosya o yolları kilitler:
///   ① kapanmış kapsam YENİDEN kapatılamaz (çift kapanış → beklenen iki katına çıkıyordu),
///   ② kurye kapanış kaydı kendi içinde TUTARLI (kasa rakamı beklenen nakitle aynı çerçeveden),
///   ④ `correction` ters çevirdiği satırın ATFINI devralır (düzeltmeyi yazan kişinin değil).
///
/// ①'in İKİNCİ YARISI — kapının bağlamadığı CİHAZLAR ARASI yarış ve onu kapatan deterministik
/// kimlik — `kapanis_kimlik_test.dart`ta durur (500 satır sınırı).
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final bugun = bugunTr();
  final dun = bugun.subtract(const Duration(days: 1));

  /// TR takvim gününün UTC gün başı.
  DateTime gunBasiUtc(DateTime trGun) =>
      DateTime.utc(trGun.year, trGun.month, trGun.day).subtract(const Duration(hours: 3));

  /// [gun] içinde KESİN kalan bir damga. Gerçek "şimdi"ye yakın durmaya çalışmaz: kapanış kendi
  /// damgasını yazar, ledger kaydının ondan ÖNCE gelmesi yeter.
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

  /// Oturumu değiştirir: kim yazıyorsa `collected_by` ondan türer.
  Future<void> oturum(String userId, String rol) =>
      (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(SyncMetaCompanion(userId: Value(userId), userRole: Value(rol)));

  Future<DayClosing> kapanisKaydi(String id) =>
      (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingle();

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // ① Kapanmış kapsam yeniden kapatılamaz
  // ═════════════════════════════════════════════════════════════════════════════════════════
  //
  // `araTahsilat()` bu kapıyı taşıyordu, `kapat()` TAŞIMIYORDU — oysa gerekçe aynı: sheet
  // açıkken senkron başka bir cihazdan gelen kapanışı indirebilir, ekranın bildiği durum bayattır.
  // İkinci kapanış aynı kurye/gün için İKİ `day_closings` + İKİ `cash_handovers` yazardı;
  // `teslimEdilenNakit` ikisini de sayınca gün beklentisi 10.000 yerine 20.000 çıkar ve patron
  // kasasını sayınca "EKSİK 10.000" görürdü — append-only, yani KALICI.
  group('① kapanmış kapsam reddedilir', () {
    test('gün iki kez kapatılamaz', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: gunIci(bugun));

      final kapanislar = DayClosingRepository(db);
      await kapanislar.kapat(
          scope: ClosingScope.day, countedCashKurus: 0, localDate: bugun);

      await expectLater(
        kapanislar.kapat(scope: ClosingScope.day, countedCashKurus: 0, localDate: bugun),
        throwsA(isA<StateError>()),
      );
      expect(await db.select(db.dayClosings).get(), hasLength(1));
    });

    test('aynı kurye iki kez kapatılamaz; devir de İKİNCİ kez yazılmaz', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: gunIci(bugun));

      final kapanislar = DayClosingRepository(db);
      await kapanislar.kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 10000,
        alsoHandover: true,
        localDate: bugun,
      );

      await expectLater(
        kapanislar.kapat(
          scope: ClosingScope.courier,
          userId: 'k1',
          countedCashKurus: 10000,
          alsoHandover: true,
          localDate: bugun,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await db.select(db.dayClosings).get(), hasLength(1));
      expect(await db.select(db.cashHandovers).get(), hasLength(1),
          reason: 'ikinci devir yazılsaydı teslim edilen 20.000 sayılırdı');

      // ASIL KANIT: gün kapsamının beklentisi bozulmadı.
      final gun = await kapanislar.onizle(ClosingScope.day, localDate: bugun);
      expect(gun.expectedCashKurus, 10000,
          reason: 'çift devir olsaydı 20.000 çıkardı ve arşive öyle donardı');
    });

    test('gün kapandıysa kurye kapsamı da kapatılamaz', () async {
      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: gunIci(bugun));

      final kapanislar = DayClosingRepository(db);
      await kapanislar.kapat(
          scope: ClosingScope.day, countedCashKurus: 0, localDate: bugun);

      await expectLater(
        kapanislar.kapat(
            scope: ClosingScope.courier,
            userId: 'k1',
            countedCashKurus: 5000,
            localDate: bugun),
        throwsA(isA<StateError>()),
      );
    });

    test('SAĞLAM YOL bozulmadı: kurye kapanır, sonra gün kapanır; diğer kurye serbest', () async {
      await kurye('k1', 'Emre');
      await kurye('k2', 'Deniz');
      await nakit(5000, kuryeId: 'k1', at: gunIci(bugun));
      await nakit(3000, kuryeId: 'k2', at: gunIci(bugun));

      final kapanislar = DayClosingRepository(db);
      await kapanislar.kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 5000,
        alsoHandover: true,
        localDate: bugun,
      );
      // k1 kapandı diye k2 engellenmez.
      await kapanislar.kapat(
        scope: ClosingScope.courier,
        userId: 'k2',
        countedCashKurus: 3000,
        alsoHandover: true,
        localDate: bugun,
      );
      // Kuryeler kapandıktan sonra gün kapanışı NORMAL akıştır.
      await kapanislar.kapat(
          scope: ClosingScope.day, countedCashKurus: 8000, localDate: bugun);

      expect(await db.select(db.dayClosings).get(), hasLength(3));
      final gunKaydi = (await db.select(db.dayClosings).get())
          .firstWhere((r) => r.scope == 'day');
      expect(gunKaydi.diffKurus, 0, reason: 'para işletmeden çıkmadı, patron 8.000 sayar');
    });

    test('kapı KAPATILAN GÜNE sorulur: dün kapandı, bugün hâlâ açık', () async {
      await kurye('k1', 'Emre');
      await nakit(4000, kuryeId: 'k1', at: gunIci(dun));
      await nakit(6000, kuryeId: 'k1', at: gunIci(bugun));

      final kapanislar = DayClosingRepository(db);
      await kapanislar.kapat(scope: ClosingScope.day, countedCashKurus: 0, localDate: dun);

      await expectLater(
        kapanislar.kapat(scope: ClosingScope.day, countedCashKurus: 0, localDate: dun),
        throwsA(isA<StateError>()),
        // "bugün" kapalı mı diye sorsaydık dün ikinci kez kapatılabilirdi.
      );
      await kapanislar.kapat(
          scope: ClosingScope.day, countedCashKurus: 6000, localDate: bugun);
      expect(await db.select(db.dayClosings).get(), hasLength(2));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // ② Kurye kapanış kaydı KENDİ İÇİNDE tutarlı
  // ═════════════════════════════════════════════════════════════════════════════════════════
  //
  // `cash_nakit_kurus` GÜN nakdini, `expected_cash_kurus` PENCERE nakdini taşıyordu. Arşiv detayı
  // ikisini yan yana basınca "Toplam Tahsilat 3.000 · Beklenen nakit 8.000" gibi AÇIKLANAMAZ bir
  // kayıt donuyordu — ve kayıt append-only, düzeltilemez.
  group('② kurye kapanışı arşive tutarlı rakam dondurur', () {
    test('hiç kapanışı olmayan kurye: dün 5.000 + bugün 3.000 → kayıt PENCEREYİ yazar', () async {
      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: gunIci(dun));
      await nakit(3000, kuryeId: 'k1', at: gunIci(bugun));

      final kapanislar = DayClosingRepository(db);
      final on = await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
      expect(on.expectedCashKurus, 8000, reason: 'pencere alttan AÇIK; cebinde 8.000 var');
      expect(on.kasa.nakit, 3000, reason: 'GÜN çerçevesi ekran kartları için olduğu gibi kalır');

      final id = await kapanislar.kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 8000,
        alsoHandover: true,
        localDate: bugun,
      );

      final kayit = await kapanisKaydi(id);
      expect(kayit.cashNakitKurus, 8000,
          reason: 'ESKİ kod 3.000 yazardı; "3.000 topladı, 8.000 bekleniyor" açıklanamaz');
      expect(kayit.expectedCashKurus, kayit.cashNakitKurus,
          reason: 'teslim edilmemiş para yokken ikisi AYNI olmak zorunda');
      expect(kayit.diffKurus, 0);
    });

    test('kayıt kendi kimliğini kapatır: toplam == nakit + kart + havale', () async {
      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: gunIci(dun));
      await nakit(3000, kuryeId: 'k1', at: gunIci(bugun));
      await writeLedgerEntry(db,
          entryType: 'payment',
          amountKurus: -2000,
          paymentType: 'kart',
          collectedByUserId: 'k1',
          occurredAt: gunIci(bugun));

      final id = await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 8000,
        alsoHandover: true,
        localDate: bugun,
      );

      final kayit = await kapanisKaydi(id);
      expect(kayit.cashNakitKurus, 8000);
      expect(kayit.cashKartKurus, 2000,
          reason: 'kart GÜN çerçevesinde kalır — devir yalnız nakit üzerinedir');
      expect(
        kayit.totalCollectedKurus,
        kayit.cashNakitKurus + kayit.cashKartKurus + kayit.cashHavaleKurus,
        reason: 'arşivi okuyan üç sayıyı toplayıp dördüncüyü bulabilmeli',
      );
    });

    test('ara tahsilattan sonra da tutarlı: pencere nakdi − teslim edilen == beklenen', () async {
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: gunIci(dun));
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);

      final id = await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 3000,
        alsoHandover: true,
        localDate: bugun,
      );

      final kayit = await kapanisKaydi(id);
      expect(kayit.cashNakitKurus, 9000, reason: 'pencerede toplanan');
      expect(kayit.expectedCashKurus, 3000, reason: '9.000 − 6.000 ara tahsilat');
      expect(kayit.cashNakitKurus - kayit.expectedCashKurus, 6000,
          reason: 'aradaki fark TESLİM EDİLENDİR; iki rakam aynı çerçevedense okunabilir');
      expect(kayit.diffKurus, 0);
    });

    test('GÜN kapsamı DEĞİŞMEDİ: kayıt günün tam nakdini taşır', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: gunIci(bugun));
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);

      final id = await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 4000, localDate: bugun);

      final kayit = await kapanisKaydi(id);
      expect(kayit.cashNakitKurus, 10000, reason: 'gün çerçevesinde takvim günü doğrudur');
      expect(kayit.expectedCashKurus, 4000);
      expect(kayit.diffKurus, 0);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // ④ Nakit `correction` ters çevirdiği satırın ATFINI devralır
  // ═════════════════════════════════════════════════════════════════════════════════════════
  //
  // `collected_by_user_id` DÜZELTMEYİ YAZAN kişiden geliyordu. Emre 10.000 topladı, patron kendi
  // telefonundan 2.000'i ters çevirdi → gün kapsamında beklenen −2.000 ("FAZLA 2.000"), Emre'nin
  // kapsamında beklenen 10.000 kalır ama cebinde 8.000 vardır ve kapanışta "EKSİK 2.000" arşive
  // KALICI donardı. Bugün UI'dan erişilemiyor ama böyle bir kayıt SUNUCUDAN inebilir.
  group('④ düzeltme, düzelttiği kaydın kasasına yazılır', () {
    /// Emre 10.000 nakit topladı, patron kendi oturumundan 2.000'ini ters çevirdi.
    Future<String> hataliTahsilatVeDuzeltme() async {
      await kurye('k1', 'Emre');
      await db.syncState();
      await oturum('k1', 'kurye');

      final cid = await CustomerRepository(db).create(name: 'Ayşe');
      final tahsilatId = await LedgerRepository(db).tahsilat(cid, 10000, 'nakit');

      await oturum('p1', 'patron');
      // Ters kayıt İMZALI verilir: payment −10.000 idi, 2.000'ini geri almak +2.000.
      await LedgerRepository(db).duzeltme(tahsilatId, 2000, customerId: cid);
      return cid;
    }

    test('düzeltme satırı ORİJİNAL toplayıcıya atfedilir', () async {
      await hataliTahsilatVeDuzeltme();

      final duzeltme = (await db.select(db.ledgerEntries).get())
          .firstWhere((e) => e.entryType == 'correction');
      expect(duzeltme.collectedByUserId, 'k1',
          reason: 'kasa katkısı kimin kasasından çıktıysa düzeltmesi de oraya yazılır');
      expect(duzeltme.paymentType, 'nakit', reason: 'ödeme tipi devri korunuyor');
    });

    test('gün kapsamı: beklenen NEGATİFE düşmez, patron FAZLA görmez', () async {
      await hataliTahsilatVeDuzeltme();

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.gunNakitKurus, 8000, reason: '10.000 toplandı, 2.000 geri alındı');
      expect(on.dusulenKurus, 8000, reason: 'hepsi hâlâ Emre\'nin cebinde');
      expect(on.expectedCashKurus, 0,
          reason: 'ESKİ kod −2.000 derdi ve patron "FAZLA 2.000" görürdü');
    });

    test('kurye kapsamı: beklenen düzeltilmiş tutar; kapanış farkı 0', () async {
      await hataliTahsilatVeDuzeltme();

      final kapanislar = DayClosingRepository(db);
      final on = await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
      expect(on.expectedCashKurus, 8000,
          reason: 'ESKİ kod 10.000 derdi; Emre 8.000 verince "EKSİK 2.000" DONARDI');

      final id = await kapanislar.kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 8000,
        alsoHandover: true,
        localDate: bugun,
      );
      expect((await kapanisKaydi(id)).diffKurus, 0,
          reason: 'hiç var olmamış bir eksik Emre\'ye yazılamaz');
    });

    test('DÜZELTME OLMAYAN yazımlar hâlâ YAZANA atfedilir (regresyon)', () async {
      await db.syncState();
      await oturum('k1', 'kurye');
      final cid = await CustomerRepository(db).create(name: 'Ayşe');
      await LedgerRepository(db).tahsilat(cid, 5000, 'nakit');

      final tahsilat = (await db.select(db.ledgerEntries).get())
          .firstWhere((e) => e.entryType == 'payment');
      expect(tahsilat.collectedByUserId, 'k1');
      expect((await DayEndRepository(db).kasaOzeti(bugun, userId: 'k1')).nakit, 5000);
    });
  });
}
