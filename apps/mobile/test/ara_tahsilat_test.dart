import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/ledger_ops.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';

import 'support/fake_sync_api.dart';

/// ARA TAHSİLAT + KALAN NAKİT (kullanıcı kararı 2026-08-06).
///
/// Patron gün içinde kuryenin cebindeki nakdi alabilir; gün AÇIK kalır. Bu dosyanın koruduğu
/// asıl kural ÇİFTE SAYMA yasağıdır: ara tahsilat gün kapanışının beklentisinden BİR kez düşer.
/// İki ayrı yerde (gün kapsamı ledger'den, kurye kapsamı period_start'tan) hesaplanan "kalan"
/// aynı rakamı vermek zorunda — vermezse patron hangi ekrana bakarsa ona göre para arar.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final bugun = bugunTr();

  /// TR takvim gününün UTC gün başı.
  DateTime gunBasiUtc(DateTime trGun) =>
      DateTime.utc(trGun.year, trGun.month, trGun.day).subtract(const Duration(hours: 3));

  /// Bugünün TR gününde KALMASI garanti "önce"/"sonra" damgaları.
  ///
  /// `araTahsilat()` kaydı gerçek ŞİMDİ ile yazar; ledger kayıtlarını ona göre konumlandırmak
  /// zorundayız. Aynı milisaniyeye düşen iki kayıtta `period_start` süzgeci (`isBefore`)
  /// yazı-tura döner ve sahte kırık üretir — o yüzden 5 dakikalık aralık bırakılıyor, gün
  /// sınırını aşacaksa gün içine kırpılıyor.
  String oncekiIso() {
    final simdi = DateTime.now().toUtc();
    final erken = simdi.subtract(const Duration(minutes: 5));
    final sinir = gunBasiUtc(bugun);
    return (erken.isBefore(sinir) ? sinir : erken).toIso8601String();
  }

  String sonrakiIso() {
    final simdi = DateTime.now().toUtc();
    final gec = simdi.add(const Duration(minutes: 5));
    final sinir = gunBasiUtc(bugun).add(const Duration(hours: 24, seconds: -1));
    return (gec.isAfter(sinir) ? sinir : gec).toIso8601String();
  }

  Future<void> kurye(String id, String ad, {String durum = 'active'}) => db.into(db.users).insert(
      UsersCompanion.insert(id: id, name: ad, role: 'kurye', status: durum));

  Future<void> nakit(int kurus, {required String kuryeId, required String at}) =>
      writeLedgerEntry(db,
          entryType: 'payment',
          amountKurus: -kurus, // tahsilat NEGATİF yazılır; kasaya giren = −amount
          paymentType: 'nakit',
          collectedByUserId: kuryeId,
          occurredAt: at);

  group('kalan nakit', () {
    test('gün kapsamı: beklenen = günün nakdi − alınan ara tahsilat', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());

      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.gunNakitKurus, 10000, reason: 'günün nakdi ara tahsilatla KÜÇÜLMEZ');
      expect(on.araTahsilatKurus, 4000);
      expect(on.expectedCashKurus, 6000,
          reason: 'gün kapanışında sayılacak olan yalnız KALAN nakit');
    });

    test('ara tahsilat gün kapanışından İKİ kez düşmez (kurye kapsamı da aynı kalanı verir)',
        () async {
      // Zaman çizgisi: 4.000 topla → patron 4.000 ara tahsilat aldı → 6.000 daha topla.
      await kurye('k1', 'Emre');
      await nakit(4000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);
      await nakit(6000, kuryeId: 'k1', at: sonrakiIso());

      final kapanislar = DayClosingRepository(db);
      final gun = await kapanislar.onizle(ClosingScope.day, localDate: bugun);
      final kuryeKapsam =
          await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);

      expect(gun.expectedCashKurus, 6000, reason: '10.000 − 4.000; 2.000 çıkarsa çifte sayma var');
      expect(kuryeKapsam.expectedCashKurus, 6000,
          reason: 'period_start zaten ara tahsilat sonrasını kapsar — bir daha düşülmemeli');
      expect(kuryeKapsam.gunNakitKurus, 10000);
      expect(kuryeKapsam.araTahsilatKurus, 4000);
      expect(kuryeKapsam.periodStartIso, isNotNull, reason: 'kurye kapsamı mutabakat sınırı taşır');
    });

    test('iki ardışık ara tahsilat toplanır; kalan sıfıra iner', () async {
      await kurye('k1', 'Emre');
      final devirler = CashHandoverRepository(db);

      await nakit(4000, kuryeId: 'k1', at: oncekiIso());
      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);
      await nakit(6000, kuryeId: 'k1', at: sonrakiIso());
      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);

      expect(await devirler.araTahsilatToplami(bugun), 10000);
      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.expectedCashKurus, 0, reason: 'hepsi gün içinde alındı, kapanışta sayılacak yok');
    });

    test('ara tahsilat + gün kapanışı: arşive KALAN yazılır, fark 0', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);

      final id = await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 6000, localDate: bugun);

      final kayit = await (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingle();
      expect(kayit.cashNakitKurus, 10000, reason: 'günün tam nakdi arşivde durur');
      expect(kayit.expectedCashKurus, 6000, reason: 'beklenen = kalan nakit');
      expect(kayit.diffKurus, 0, reason: 'patron kalanı tam saydı; ara tahsilat farka yazılamaz');
    });

    test('sayım eksik çıkarsa ara tahsilatın FARKI kanıt kalır, kalan sayılana göre iner',
        () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());
      // Patron 4.000 saydı ama sistem 10.000 bekliyordu → −6.000 kanıt olarak devirde durur.
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);

      final kayit = (await CashHandoverRepository(db).araTahsilatlar(bugun)).single;
      expect(kayit.expectedCashKurus, 10000);
      expect(kayit.countedCashKurus, 4000);
      expect(kayit.diffKurus, -6000, reason: 'eksik para silinmez');

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.expectedCashKurus, 6000,
          reason: 'kalan SAYILANa göre; eksik zaten devirde suçlandı, kapanışta ikinci kez değil');
    });
  });

  group('ara tahsilat listesi', () {
    test('kim · ne zaman · sayılan · beklenen · fark döner, eskiden yeniye', () async {
      await kurye('k1', 'Emre');
      await kurye('k2', 'Deniz');
      final devirler = CashHandoverRepository(db);

      await nakit(4000, kuryeId: 'k1', at: oncekiIso());
      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 4000, note: 'birinci');
      await nakit(3000, kuryeId: 'k2', at: sonrakiIso());
      await devirler.araTahsilat(fromUserId: 'k2', countedCashKurus: 3000);

      final hepsi = await devirler.araTahsilatlar(bugun);
      expect(hepsi.map((a) => a.kuryeAdi), ['Emre', 'Deniz'], reason: 'eskiden yeniye');
      expect(hepsi.first.fromUserId, 'k1');
      expect(hepsi.first.countedCashKurus, 4000);
      expect(hepsi.first.expectedCashKurus, 4000);
      expect(hepsi.first.diffKurus, 0);
      expect(hepsi.first.note, 'birinci');

      final yalnizK2 = await devirler.araTahsilatlar(bugun, kuryeId: 'k2');
      expect(yalnizK2, hasLength(1));
      expect(yalnizK2.single.fromUserId, 'k2');
      expect(await devirler.araTahsilatToplami(bugun, kuryeId: 'k2'), 3000);
    });

    test('KAPANIŞA bağlı devir ara tahsilat DEĞİLDİR', () async {
      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: oncekiIso());

      await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 5000,
        alsoHandover: true,
        localDate: bugun,
      );

      expect(await db.select(db.cashHandovers).get(), hasLength(1),
          reason: 'kurye kapanışı devir satırı yazar');
      expect(await CashHandoverRepository(db).araTahsilatlar(bugun), isEmpty,
          reason: 'day_closings.cash_handover_id ile bağlı satır kapanış devridir');
      expect(await CashHandoverRepository(db).araTahsilatToplami(bugun), 0);
    });
  });

  group('geçmiş gün', () {
    /// Dünün kayıtlarını doğrudan yazar: `araTahsilat()` gerçek şimdiyle yazdığı için geçmiş gün
    /// ancak elle kurulabilir (senkronla gelen dünkü kayıt da tam olarak böyle görünür).
    Future<DateTime> dunKur() async {
      final dun = bugun.subtract(const Duration(days: 1));
      final ogleUtc = gunBasiUtc(dun).add(const Duration(hours: 12));
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: ogleUtc.toIso8601String());
      await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
            id: 'dun-devir-1',
            fromUserId: 'k1',
            countedCashKurus: 3000,
            expectedCashKurus: 3000,
            diffKurus: 0,
            occurredAt: ogleUtc.add(const Duration(hours: 1)).toIso8601String(),
          ));
      return dun;
    }

    test('geçmiş günün kasası, ara tahsilatları ve kalanı doğru okunur', () async {
      final dun = await dunKur();
      final gorunum = await gunSonuGorunumu(db, dun);

      expect(gorunum.kapsam.kasa.nakit, 9000);
      expect(gorunum.araTahsilatlar, hasLength(1));
      expect(gorunum.araTahsilatKurus, 3000);
      expect(gorunum.kalanNakitKurus, 6000);
      expect(gorunum.araTahsilatMumkun, isFalse,
          reason: 'dünün kasasını bugün almak parayı dünün hesabına yazmak olurdu');
    });

    test('bugünün kayıtları geçmiş günün görünümüne SIZMAZ', () async {
      final dun = await dunKur();
      await nakit(7777, kuryeId: 'k1', at: oncekiIso()); // bugün
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 1000);

      final gorunum = await gunSonuGorunumu(db, dun);
      expect(gorunum.kapsam.kasa.nakit, 9000);
      expect(gorunum.araTahsilatlar, hasLength(1));
      expect(gorunum.araTahsilatlar.single.id, 'dun-devir-1');
    });

    test('geçmiş günün kapanışı o güne süzülür', () async {
      final dun = await dunKur();
      await db.into(db.dayClosings).insert(DayClosingsCompanion.insert(
            id: 'dun-kapanis',
            scope: 'day',
            occurredAt: gunBasiUtc(dun).add(const Duration(hours: 22)).toIso8601String(),
          ));

      final gorunum = await gunSonuGorunumu(db, dun);
      expect(gorunum.gunKapali, isTrue);
      expect(gorunum.gunKapanislari.map((k) => k.id), ['dun-kapanis']);
      expect(await gunSonuGorunumu(db, bugun).then((g) => g.gunKapanislari), isEmpty,
          reason: 'dünün kapanışı bugünü kapatmaz');
    });

    test('gunKayitVarMi: kayıtsız gün boş, kayıtlı gün dolu', () async {
      final dun = await dunKur();
      expect(await gunKayitVarMi(db, dun), isTrue);
      expect(await gunKayitVarMi(db, dun.subtract(const Duration(days: 5))), isFalse,
          reason: 'çalışılmayan gün "0 ₺" değil, BOŞ durumdur');
    });
  });

  group('ara tahsilat mümkün mü', () {
    test('tek kişilik bayide kavram hiç yoktur', () async {
      final gorunum = await gunSonuGorunumu(db, bugun);
      expect(gorunum.araTahsilatMumkun, isFalse, reason: 'aktif kurye yok');
    });

    test('pasif kurye sayılmaz', () async {
      await kurye('k1', 'Emre', durum: 'disabled');
      expect((await gunSonuGorunumu(db, bugun)).araTahsilatMumkun, isFalse);
    });

    test('aktif kurye varken mümkün; gün kapanınca biter', () async {
      await kurye('k1', 'Emre');
      expect((await gunSonuGorunumu(db, bugun)).araTahsilatMumkun, isTrue);

      await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 0, localDate: bugun);
      expect((await gunSonuGorunumu(db, bugun)).araTahsilatMumkun, isFalse,
          reason: 'kapanmış günde para hareketi yazılamaz');
    });
  });

  // Ekran düğmeyi gizliyor; repo da yazmayı REDDEDİYOR. Kapanış "o anın gerçeğini dondurur" —
  // kapandıktan sonra o güne düşen yeni bir devir arşivi sessizce yalancı çıkarırdı.
  group('kapanmış kapsama ara tahsilat yazılamaz', () {
    test('gün kapandıysa reddedilir', () async {
      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: oncekiIso());
      await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 5000, localDate: bugun);

      expect(
        () => CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 1000),
        throwsStateError,
      );
    });

    test('yalnız KENDİ hesabı kapanan kurye engellenir, diğeri serbest', () async {
      await kurye('k1', 'Emre');
      await kurye('k2', 'Deniz');
      await nakit(5000, kuryeId: 'k1', at: oncekiIso());
      await nakit(3000, kuryeId: 'k2', at: oncekiIso());

      await DayClosingRepository(db).kapat(
          scope: ClosingScope.courier, userId: 'k1', countedCashKurus: 5000, localDate: bugun);

      final devirler = CashHandoverRepository(db);
      expect(() => devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 500),
          throwsStateError);
      await devirler.araTahsilat(fromUserId: 'k2', countedCashKurus: 3000);
      expect(await devirler.araTahsilatToplami(bugun), 3000,
          reason: 'k2 hâlâ açık; onun ara tahsilatı yazılır');
    });

    test('kurye kapanışının kendi devri engele TAKILMAZ', () async {
      // `kapat(alsoHandover: true)` kapanış satırını yazmadan ÖNCE devret() çağırır. Kapıyı
      // devret()'e koysaydık bu yol kendi kendini engellerdi — kanıt burada.
      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: oncekiIso());
      await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 5000,
        alsoHandover: true,
        localDate: bugun,
      );
      expect(await db.select(db.cashHandovers).get(), hasLength(1));
    });
  });

  // Sunucuya giden zarf. İki tuzak burada kilitleniyor (`musteri-sira`nın sunucu ölçümü, 2026-08-06):
  //  • Damga OFFSET'Lİ ('+03:00') gidersa Eloquent'in datetime cast'i timestamptz'e yerel saati
  //    yazıyor ve kayıt 3 saat İLERİ kayıyor. Bizim tek KURGULANAN damgamız `_trDayStartUtcIso()`
  //    (ilk devirde period_start) — TR offset'i "düzeltmek" isteyen bir sonraki düzenleme tam
  //    oradan offset sızdırır ve hata sunucuda, aylar sonra görünür.
  //  • `device_id` sunucuda OPSİYONEL: null gidersa olay yine 'applied' olur ve denetim izi
  //    sessizce boş kalır. Ara tahsilat bir para hareketidir; izsiz yazılamaz.
  group('sunucuya giden zarf', () {
    test('damgalar UTC "Z"; hiçbir alan offset taşımaz', () async {
      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: oncekiIso());
      final devirler = CashHandoverRepository(db);

      // İlk devir: period_start HENÜZ bir devirden gelmiyor, TR gün başından KURGULANIYOR.
      final ilk = await devirler.onizle('k1');
      expect(ilk.periodStartIso, endsWith('Z'));
      expect(ilk.periodStartIso, isNot(contains('+')));
      expect(DateTime.parse(ilk.periodStartIso).isUtc, isTrue);

      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 5000);
      final satir = (await db.select(db.cashHandovers).get()).single;
      expect(satir.occurredAt, endsWith('Z'));
      expect(satir.periodStart, endsWith('Z'));

      final zarf = jsonDecode(
        (await (db.select(db.outbox)..where((t) => t.entityType.equals('cash_handover')))
                .getSingle())
            .payload,
      ) as Map<String, dynamic>;
      expect(zarf['period_start'] as String, endsWith('Z'));
      expect(zarf['period_start'] as String, isNot(contains('+')));
    });

    test('ara tahsilat denetim izini boş bırakmaz (device_id gider)', () async {
      // Cihaz kimliği ilk girişte üretilip kalıcı olur (`auth/session.dart`); burada o durum kuruluyor.
      await db.syncState();
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(deviceId: Value('cihaz-1')));

      await kurye('k1', 'Emre');
      await nakit(5000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 5000);

      expect((await db.select(db.cashHandovers).get()).single.deviceId, 'cihaz-1');
      final olay = await (db.select(db.outbox)..where((t) => t.entityType.equals('cash_handover')))
          .getSingle();
      expect(olay.deviceId, 'cihaz-1',
          reason: 'sunucu device_id\'yi ZORUNLU tutmuyor; boş gidersa iz sessizce kaybolur');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // İKİ CİHAZ: patron kendi telefonundan ara tahsilat alır, KURYENİN telefonu ne görür?
  //
  // Tehlike gerçekti: `period_start` = "o kuryenin SON devri" ve bu değer YERELDEN okunuyor.
  // Kuryenin cihazı patronun yazdığı devri görmezse ekranındaki beklenen nakit ŞİŞİK kalır ve
  // kurye kendi hesabını kapatırsa arşive GERÇEK DIŞI bir beklenen tutar donar — append-only
  // olduğu için o yalan kalıcı olurdu. Aşağısı boşluğun KAPALI olduğunu kilitler; `cash_handover`
  // pull deltasında da snapshot'ta da taşınıyor (SyncService::snapshot + SyncPayload::change).
  // ═══════════════════════════════════════════════════════════════════════════════════════════
  group('iki cihaz', () {
    late FakeSyncApi api;
    late SyncEngine motor;
    setUp(() {
      api = FakeSyncApi();
      motor = SyncEngine(db, api);
    });

    /// Laravel'in `attributesToArray()` damgası: MİKROSANİYELİ ISO-8601 + 'Z'
    /// (`serializeDate` ezilmemiş). Biçim burada bilerek elle kuruluyor — Dart'ın 3 haneli
    /// çıktısını kullansaydık sunucunun gerçek biçimi hiç sınanmamış olurdu ve 'Z' düşerse
    /// `DateTime.parse` damgayı YERELE çevirip gün sınırını sessizce kaydırırdı.
    String sunucuDamgasi(DateTime t) =>
        '${t.toUtc().toIso8601String().replaceFirst(RegExp(r'Z$'), '')}000Z';

    Map<String, Object?> devirDeltasi(String id, DateTime at,
            {int counted = 10000, int expected = 10000}) =>
        {
          'seq': 11,
          'entity_type': 'cash_handover',
          'entity_id': id,
          'op': 'upsert',
          'occurred_at': sunucuDamgasi(at),
          'payload': {
            'id': id,
            'from_user_id': 'k1',
            'to_user_id': 'patron-1',
            'counted_cash_kurus': counted,
            'expected_cash_kurus': expected,
            'diff_kurus': counted - expected,
            'period_start': null,
            'occurred_at': sunucuDamgasi(at),
            'device_id': 'patron-cihazi',
            'note': null,
          },
        };

    test('patronun yazdığı ara tahsilat iner ve period_start\'ı İLERLETİR', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());
      final devirler = CashHandoverRepository(db);

      expect((await devirler.onizle('k1')).expectedKurus, 10000,
          reason: 'senkron gelmeden önce para hâlâ kuryede görünür');

      api.pullQueue.add(PullResponse(
        mode: 'delta',
        cursor: 11,
        hasMore: false,
        currentSeq: 11,
        changes: [devirDeltasi('patron-devri-1', DateTime.now().toUtc())],
      ));
      await motor.pull();

      expect((await devirler.onizle('k1')).expectedKurus, 0,
          reason: 'devir indi → mutabakat sınırı ilerledi, o para artık kuryede değil');

      final kayit = (await devirler.araTahsilatlar(bugun)).single;
      expect(kayit.id, 'patron-devri-1');
      expect(kayit.kuryeAdi, 'Emre');
      expect(kayit.countedCashKurus, 10000);

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.gunNakitKurus, 10000);
      expect(on.araTahsilatKurus, 10000);
      expect(on.expectedCashKurus, 0, reason: 'kalan nakit senkron gelen devirle düşer');
    });

    test('senkron sonrası kurye kapanışı GERÇEK beklenen tutarı dondurur', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());

      final devirAni = DateTime.now().toUtc();
      api.pullQueue.add(PullResponse(
        mode: 'delta',
        cursor: 11,
        hasMore: false,
        currentSeq: 11,
        changes: [devirDeltasi('patron-devri-1', devirAni)],
      ));
      await motor.pull();

      // Devirden SONRA toplanan nakit: kapanışta beklenen YALNIZ bu olmalı.
      await nakit(4000, kuryeId: 'k1', at: sonrakiIso());

      final id = await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 4000,
        alsoHandover: true,
        localDate: bugun,
      );

      final kapanis = await (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingle();
      expect(kapanis.expectedCashKurus, 4000,
          reason: 'senkron gelmeseydi 14.000 donardı ve bu yalan append-only kalırdı');
      expect(kapanis.diffKurus, 0);
    });

    test('senkronla gelen KAPANIŞ, bağlı devri ara tahsilat olmaktan çıkarır', () async {
      // Patron kurye hesabını kendi cihazından kapattı: iki satır aynı deltada iniyor. Ara
      // tahsilat "kapanışa bağlı DEĞİL" diye tanımlandığı için ilişki inince tanım kendiliğinden
      // düzelmeli — `kind` kolonu olsaydı bayat kalırdı, kanıt burada.
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());

      api.pullQueue.add(PullResponse(
        mode: 'delta',
        cursor: 12,
        hasMore: false,
        currentSeq: 12,
        changes: [
          devirDeltasi('patron-devri-1', DateTime.now().toUtc()),
          {
            'seq': 12,
            'entity_type': 'day_closing',
            'entity_id': 'patron-kapanis-1',
            'op': 'upsert',
            'occurred_at': sunucuDamgasi(DateTime.now().toUtc()),
            'payload': {
              'id': 'patron-kapanis-1',
              'scope': 'courier',
              'user_id': 'k1',
              'expected_cash_kurus': 10000,
              'counted_cash_kurus': 10000,
              'diff_kurus': 0,
              'cash_handover_id': 'patron-devri-1',
              'occurred_at': sunucuDamgasi(DateTime.now().toUtc()),
            },
          },
        ],
      ));
      await motor.pull();

      expect(await CashHandoverRepository(db).araTahsilatlar(bugun), isEmpty,
          reason: 'kapanışa bağlandı → artık gün içi ara tahsilat değil');
      final gorunum = await gunSonuGorunumu(db, bugun, kuryeId: 'k1');
      expect(gorunum.kapsamKapali, isTrue, reason: 'senkron gelen kapanış ekranı da kilitler');
      expect(gorunum.araTahsilatMumkun, isTrue,
          reason: 'gün hâlâ açık; bayrak GÜN kapanışına bakar, tek kuryeye değil');
    });

    test('senkronla gelen GÜN kapanışı ara tahsilat kapısını kapatır', () async {
      await kurye('k1', 'Emre');
      api.pullQueue.add(PullResponse(
        mode: 'delta',
        cursor: 13,
        hasMore: false,
        currentSeq: 13,
        changes: [
          {
            'seq': 13,
            'entity_type': 'day_closing',
            'entity_id': 'patron-gun-kapanisi',
            'op': 'upsert',
            'occurred_at': sunucuDamgasi(DateTime.now().toUtc()),
            'payload': {
              'id': 'patron-gun-kapanisi',
              'scope': 'day',
              'user_id': null,
              'occurred_at': sunucuDamgasi(DateTime.now().toUtc()),
            },
          },
        ],
      ));
      await motor.pull();

      expect(
        () => CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 1000),
        throwsStateError,
        reason: 'kapı yereli okur, yerel senkronla dolar — başka cihazın kapanışı da kapatır',
      );
    });
  });
}
