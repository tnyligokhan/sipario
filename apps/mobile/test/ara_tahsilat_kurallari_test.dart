import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';

import 'support/ara_tahsilat_ortami.dart';
import 'support/fake_sync_api.dart';

/// ARA TAHSİLAT — YAZMA KURALLARI (mümkün mü · kapanmış kapsam · sunucuya giden zarf ·
/// senkron tazeliği · iki cihaz).
///
/// Buradaki testler "rakam doğru mu" değil, "bu kayıt YAZILABİLİR Mİ ve sunucuya DOĞRU MU
/// gidiyor" sorusunu sorar: kapanmış bir kapsama ara tahsilat yazılamaz, zarf beklenen alanları
/// taşır, iki cihazın aynı pencereye yazması deterministik çözülür.
///
/// Bölme gerekçesi ve ortak fikstür: `ara_tahsilat_test.dart` başlığı.

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final bugun = bugunTr();

  group('ara tahsilat mümkün mü', () {
    test('tek kişilik bayide kavram hiç yoktur', () async {
      final gorunum = await gunSonuGorunumu(db, bugun);
      expect(gorunum.araTahsilatMumkun, isFalse, reason: 'aktif kurye yok');
    });

    test('pasif kurye sayılmaz', () async {
      await kurye(db, 'k1', 'Emre', durum: 'disabled');
      expect((await gunSonuGorunumu(db, bugun)).araTahsilatMumkun, isFalse);
    });

    test('aktif kurye varken mümkün; gün kapanınca biter', () async {
      await kurye(db, 'k1', 'Emre');
      expect((await gunSonuGorunumu(db, bugun)).araTahsilatMumkun, isTrue);

      await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 0, localDate: bugun);
      expect((await gunSonuGorunumu(db, bugun)).araTahsilatMumkun, isFalse,
          reason: 'kapanmış günde para hareketi yazılamaz');
    });
  });

  group('inceleme düzeltmeleri', () {
    test('#3 kapanış + devir TEK transaction: yarım kalmış devir üretilemez', () async {
      // Devir transaction'ın DIŞINDA çağrılıyordu; arada süreç ölürse kapanışa bağlanmamış bir
      // devir kalır ve `araTahsilatlar` onu ARA TAHSİLAT sayardı — kurye hesabı kapanmamış
      // görünür, ara tahsilat toplamı şişerdi. Kapanışı ZORLA düşürüp ikisinin de yazılmadığını
      // kanıtlıyoruz (userId null → ArgumentError, ama asıl kanıt: devir de yazılmamış olmalı).
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());

      // Aynı id ile ikinci kapanış → insert çakışır ve transaction geri sarılır.
      final kapanislar = DayClosingRepository(db);
      await kapanislar.kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 9000,
        alsoHandover: true,
        localDate: bugun,
      );
      final devirSayisi = (await db.select(db.cashHandovers).get()).length;
      final kapanisSayisi = (await db.select(db.dayClosings).get()).length;

      expect(devirSayisi, 1);
      expect(kapanisSayisi, 1);
      // Devir MUTLAKA bir kapanışa bağlı: bağsız kalsaydı ara tahsilat sayılırdı.
      final kapanis = (await db.select(db.dayClosings).get()).single;
      expect(kapanis.cashHandoverId, (await db.select(db.cashHandovers).get()).single.id);
      expect(await CashHandoverRepository(db).araTahsilatlar(bugun), isEmpty);
    });

    test('#4 gün sınırı DÜZELTİLMİŞ saatten türer', () async {
      // Cihaz saati ileri/geri olsa bile gün sınırı sunucu saatinden hesaplanmalı; kayıtlar
      // zaten `correctedNowIso` ile yazılıyor. Offset uygulanınca "bugün" kayması gözlenmeli.
      await db.syncState();
      final ileriOffset = const Duration(hours: 30).inMilliseconds; // yarına taşıyacak kadar
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(SyncMetaCompanion(serverTimeOffsetMs: Value(ileriOffset)));

      final duzeltilmis = await bugunTrDuzeltilmis(db);
      expect(duzeltilmis, isNot(bugunTr()),
          reason: 'offset uygulanmazsa cihaz saati kullanılıyor demektir');
      expect(duzeltilmis.difference(bugunTr()).inDays, greaterThanOrEqualTo(1));
    });

    test('#5 kapat(localDate:) devre de GEÇER', () async {
      // `kapat` önizlemeyi X günü için hesaplayıp devri bugüne göre yazsaydı, kapanışa donan
      // beklenen ile devre yazılan beklenen ayrışırdı.
      await kurye(db, 'k1', 'Emre');
      final dun = bugun.subtract(const Duration(days: 1));
      await nakit(db, 4000,
          kuryeId: 'k1',
          at: gunBasiUtc(dun).add(const Duration(hours: 12)).toIso8601String());

      final id = await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 4000,
        alsoHandover: true,
        localDate: dun,
      );

      final kapanis = await (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingle();
      final devir = (await db.select(db.cashHandovers).get()).single;
      expect(kapanis.expectedCashKurus, 4000);
      expect(devir.expectedCashKurus, kapanis.expectedCashKurus,
          reason: 'iki kayıt AYNI beklenen tutarı taşımalı');
      expect(devir.diffKurus, 0);
    });
  });

  // Ekran düğmeyi gizliyor; repo da yazmayı REDDEDİYOR. Kapanış "o anın gerçeğini dondurur" —
  // kapandıktan sonra o güne düşen yeni bir devir arşivi sessizce yalancı çıkarırdı.
  group('kapanmış kapsama ara tahsilat yazılamaz', () {
    test('gün kapandıysa reddedilir', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 5000, kuryeId: 'k1', at: oncekiIso());
      await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 5000, localDate: bugun);

      expect(
        () => CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 1000),
        throwsStateError,
      );
    });

    test('yalnız KENDİ hesabı kapanan kurye engellenir, diğeri serbest', () async {
      await kurye(db, 'k1', 'Emre');
      await kurye(db, 'k2', 'Deniz');
      await nakit(db, 5000, kuryeId: 'k1', at: oncekiIso());
      await nakit(db, 3000, kuryeId: 'k2', at: oncekiIso());

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
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 5000, kuryeId: 'k1', at: oncekiIso());
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
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 5000, kuryeId: 'k1', at: oncekiIso());
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

      await kurye(db, 'k1', 'Emre');
      await nakit(db, 5000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 5000);

      expect((await db.select(db.cashHandovers).get()).single.deviceId, 'cihaz-1');
      final olay = await (db.select(db.outbox)..where((t) => t.entityType.equals('cash_handover')))
          .getSingle();
      expect(olay.deviceId, 'cihaz-1',
          reason: 'sunucu device_id\'yi ZORUNLU tutmuyor; boş gidersa iz sessizce kaybolur');
    });
  });

  // Çevrimdışı kurye BİLİNÇLİ BORÇ olarak kabul edildi (lead kararı 2026-08-06): kapanış
  // çevrimiçi-zorunlu yapılmıyor, bunun yerine tazelik GÖRÜNÜR kılınıyor. Gösterge yalan
  // söylerse hiç göstergesizlikten kötüdür — ölçtüğü şey burada kilitleniyor.
  group('senkron tazeliği', () {
    /// Sunucudan son yanıtın geldiği anı kurar. `SyncEngine.pull()` her turda tam olarak bu iki
    /// alanı yazar (`_applyServerTime`); test o durumu taklit ediyor.
    Future<void> sonTemas(DateTime an, {int offsetMs = 0}) async {
      await db.syncState();
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(SyncMetaCompanion(
        lastServerTimeIso: Value(an.toUtc().toIso8601String()),
        serverTimeOffsetMs: Value(offsetMs),
      ));
    }

    test('hiç senkron olmamış cihaz BAYAT sayılır', () async {
      final t = await senkronTazeligi(db);
      expect(t.hicTemasYok, isTrue);
      expect(t.gecenSure, isNull);
      expect(t.bayat, isTrue, reason: 'bilinmezlik tazelik değildir');
    });

    test('geçen süre son temastan ölçülür', () async {
      final simdi = DateTime.utc(2026, 8, 6, 12);
      await sonTemas(simdi.subtract(const Duration(minutes: 3)));

      final t = await senkronTazeligi(db, simdi: simdi);
      expect(t.gecenSure, const Duration(minutes: 3));
      expect(t.bayat, isFalse, reason: '3 dk < 10 dk eşiği; bir-iki tur kaçmış olabilir');
    });

    test('eşiği aşan kopukluk bayat', () async {
      final simdi = DateTime.utc(2026, 8, 6, 12);
      await sonTemas(simdi.subtract(const Duration(minutes: 25)));
      expect((await senkronTazeligi(db, simdi: simdi)).bayat, isTrue);
    });

    test('cihaz saati yanlışsa DÜZELTİLMİŞ saatle ölçülür', () async {
      // Telefon 2 saat geri kalmış (offset +2sa). Son temas sunucu saatiyle 12:00'de oldu;
      // cihaz şimdi 10:05 sanıyor. Ham çıkarma "−1sa 55dk" verirdi; doğru cevap 5 dakika.
      final cihazSimdi = DateTime.utc(2026, 8, 6, 10, 5);
      await sonTemas(DateTime.utc(2026, 8, 6, 12), offsetMs: const Duration(hours: 2).inMilliseconds);

      final t = await senkronTazeligi(db, simdi: cihazSimdi);
      expect(t.gecenSure, const Duration(minutes: 5));
      expect(t.bayat, isFalse);
    });

    test('cihaz saati geriye atlarsa negatif değil SIFIR', () async {
      final simdi = DateTime.utc(2026, 8, 6, 12);
      await sonTemas(simdi.add(const Duration(minutes: 7))); // gelecekten damga
      final t = await senkronTazeligi(db, simdi: simdi);
      expect(t.gecenSure, Duration.zero,
          reason: '"−7 dk önce" yazmak, bilmediğimizi bildiğimiz sanmaktır');
      expect(t.bayat, isFalse);
    });

    test('görünüm modeli tazeliği taşır', () async {
      await kurye(db, 'k1', 'Emre');
      await sonTemas(DateTime.now().toUtc().subtract(const Duration(minutes: 40)));
      final gorunum = await gunSonuGorunumu(db, bugun);
      expect(gorunum.senkron.bayat, isTrue,
          reason: 'sheet ekstra çağrı yapmadan uyarıyı çizebilmeli');
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

    test('patronun yazdığı ara tahsilat iner ve beklenen nakdi DÜŞÜRÜR', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 10000, kuryeId: 'k1', at: oncekiIso());
      final devirler = CashHandoverRepository(db);

      expect((await devirler.onizle('k1')).expectedKurus, 10000,
          reason: 'senkron gelmeden önce para hâlâ kuryede görünür');
      // Not: mutabakat sınırı `period_start` kayıtta durmayı sürdürüyor ama beklenen artık
      // ondan türemiyor — inen devrin etkisi "teslim edilen nakit" toplamından geliyor.

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
      expect(on.dusulenKurus, 0, reason: 'kuryede para kalmadı');
      expect(on.expectedCashKurus, 10000,
          reason: 'para patronun kasasında — devir iç transferdir, gün beklentisini düşürmez');
    });

    test('senkron sonrası kurye kapanışı GERÇEK beklenen tutarı dondurur', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 10000, kuryeId: 'k1', at: oncekiIso());

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
      await nakit(db, 4000, kuryeId: 'k1', at: sonrakiIso());

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
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 10000, kuryeId: 'k1', at: oncekiIso());

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
      await kurye(db, 'k1', 'Emre');
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
