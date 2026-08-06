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

  // GÜN kapsamı ile KURYE kapsamı FARKLI soru sorar (inceleme #1) ve bu ayrım kasıtlıdır:
  //  • kurye: "senin cebinde ne kaldı?"
  //  • gün:   "PATRONUN KASASINDA ne olmalı?" = günün nakdi − kuryelerde kalan
  // Gün kapsamında devir bir İÇ TRANSFERDİR: para kuryeden patrona geçer, işletmeden çıkmaz.
  // Teslim edileni gün kapsamından düşmek, patronun elindeki parayı yok saymak olurdu.
  group('gün kapsamı: patronun kasasında ne olmalı', () {
    test('ara tahsilat sonrası beklenen = patronun aldığı; kalan kuryede görünür', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());

      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.gunNakitKurus, 10000, reason: 'günün nakdi devirle KÜÇÜLMEZ');
      expect(on.dusulenKurus, 6000, reason: 'kuryede kalan 6.000');
      expect(on.expectedCashKurus, 4000,
          reason: 'patron 4.000 aldı; kasasında olması gereken bu');
    });

    test('kurye HEPSİNİ teslim edince gün beklentisi TAM nakde çıkar', () async {
      // İncelemenin bulduğu somut hata: eskiden burada "beklenen 0" yazıyordu ve patron
      // kasasındaki 10.000'i sayınca "FAZLA 10.000" görüyordu.
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 10000);

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.dusulenKurus, 0, reason: 'kuryede para kalmadı');
      expect(on.expectedCashKurus, 10000, reason: 'hepsi patronun kasasında');
    });

    test('kurye kapanışı da iç transferdir: gün beklentisi düşmez', () async {
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());

      final kapanislar = DayClosingRepository(db);
      await kapanislar.kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 9000,
        alsoHandover: true,
        localDate: bugun,
      );

      final gun = await kapanislar.onizle(ClosingScope.day, localDate: bugun);
      expect(gun.dusulenKurus, 0);
      expect(gun.expectedCashKurus, 9000,
          reason: 'kurye verdi, patron aldı — para işletmeden ÇIKMADI');
    });

    test('tek kişilik bayide beklenen = günün tüm nakdi', () async {
      // Hiç kurye yok: kuryelerde kalan 0 → bugünkü doğru davranış korunuyor.
      // Patron OTURUM AÇMIŞ durumdadır (gerçek kurulum): `sync_meta.user_role` onu kurye
      // olmadığını POZİTİF olarak söyler, `users` aynası henüz inmemiş olsa bile.
      await db.syncState();
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
          const SyncMetaCompanion(userId: Value('patron-1'), userRole: Value('patron')));
      await nakit(7500, kuryeId: 'patron-1', at: oncekiIso());

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.dusulenKurus, 0);
      expect(on.expectedCashKurus, 7500);
    });

    test('ara tahsilat + gün kapanışı: arşive patronun kasası yazılır, fark 0', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);

      final id = await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 4000, localDate: bugun);

      final kayit = await (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingle();
      expect(kayit.cashNakitKurus, 10000, reason: 'günün tam nakdi arşivde durur');
      expect(kayit.expectedCashKurus, 4000);
      expect(kayit.diffKurus, 0);
    });

    test('ara tahsilatta EKSİK sayım gün beklentisine karışmaz', () async {
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());
      // Patron 4.000 saydı ama sistem 10.000 bekliyordu → −6.000 kanıt devirde durur.
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);

      final kayit = (await CashHandoverRepository(db).araTahsilatlar(bugun)).single;
      expect(kayit.diffKurus, -6000, reason: 'eksik para silinmez');

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.expectedCashKurus, 4000,
          reason: 'patronun kasasında fiilen 4.000 var; eksik zaten devirde suçlandı');
    });

    test('gün ve kurye kapsamı BİRLİKTE günün nakdini verir', () async {
      // İki kapsamın kimliği: patronun kasası + kuryelerde kalan = günün nakdi.
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);

      final kapanislar = DayClosingRepository(db);
      final gun = await kapanislar.onizle(ClosingScope.day, localDate: bugun);
      final kuryeKapsam =
          await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);

      expect(kuryeKapsam.expectedCashKurus, 3000, reason: 'kuryede kalan');
      expect(gun.expectedCashKurus, 6000, reason: 'patronun kasası');
      expect(gun.expectedCashKurus + kuryeKapsam.expectedCashKurus, gun.gunNakitKurus);
    });

    test('ara tahsilat İKİ KEZ düşmez', () async {
      // 4.000 topla → 4.000 ara tahsilat → 6.000 daha topla.
      await kurye('k1', 'Emre');
      await nakit(4000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);
      await nakit(6000, kuryeId: 'k1', at: sonrakiIso());

      final kapanislar = DayClosingRepository(db);
      final kuryeKapsam =
          await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
      expect(kuryeKapsam.expectedCashKurus, 6000,
          reason: '10.000 topladı, 4.000 verdi; 2.000 çıkarsa çifte sayma var');
      expect(kuryeKapsam.gunNakitKurus, 10000);
      expect(kuryeKapsam.dusulenKurus, 4000);
      expect(kuryeKapsam.periodStartIso, isNotNull, reason: 'denetim izi taşınır');
    });
  });

  // KULLANICI KARARI 2026-08-06: kuryede kalan DEVREDER.
  //
  // Patron ara tahsilatta beklenenin tamamını almayabilir — 90 toplandı, 60 alındı, 30 para üstü
  // için kuryede BİLEREK bırakıldı. Eski `period_start` penceresi o devre kaydığı için akşam
  // beklenen 0 çıkıyor ve kurye o 30'u verince ekran "FAZLA 30" yazıyordu. Veri kaybı yoktu ama
  // okunuşu tersti: bilerek bırakılan para, fazla para gibi görünüyordu.
  group('kuryede kalan devreder', () {
    test('kısmi ara tahsilat sonrası akşam beklenen KALAN kadar; fark 0', () async {
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());

      // Patron 6.000 aldı, 3.000 para üstü için kuryede kaldı (fark −3.000 kanıt olarak durur).
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);
      expect((await CashHandoverRepository(db).araTahsilatlar(bugun)).single.diffKurus, -3000);

      final kapanislar = DayClosingRepository(db);
      final on = await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
      expect(on.expectedCashKurus, 3000,
          reason: 'ESKİ kod 0 derdi; kurye 3.000 verince "FAZLA 3.000" yazardı');

      final id = await kapanislar.kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 3000,
        alsoHandover: true,
        localDate: bugun,
      );
      final kapanis = await (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingle();
      expect(kapanis.expectedCashKurus, 3000);
      expect(kapanis.diffKurus, 0, reason: 'bilerek bırakılan para fark üretmez');
    });

    test('ikinci ara tahsilatta beklenen, kalan + yeni toplananın TOPLAMI', () async {
      await kurye('k1', 'Emre');
      final devirler = CashHandoverRepository(db);

      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 6000); // 3.000 kuryede kaldı
      await nakit(5000, kuryeId: 'k1', at: sonrakiIso());

      expect((await devirler.onizle('k1')).expectedKurus, 8000,
          reason: 'kalan 3.000 + yeni 5.000; ESKİ kod yalnız 5.000 derdi');
    });

    test('tam tahsilatta beklenen 0 (regresyon koruması)', () async {
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 9000);

      final on = await DayClosingRepository(db)
          .onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
      expect(on.expectedCashKurus, 0);
      expect(on.dusulenKurus, 9000);
    });

    test('kapanış sonrası kuryenin cebi BOŞ görünür (devir kapanan pencerede kalır)', () async {
      // Kapanış ile ona bağlanan devir AYNI damgayı taşır. Devir bir milisaniye SONRA
      // damgalansaydı kapanışın AÇTIĞI pencereye düşer ve beklenen −9.000 çıkardı.
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());

      await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 9000,
        alsoHandover: true,
        localDate: bugun,
      );

      expect((await CashHandoverRepository(db).onizle('k1')).expectedKurus, 0,
          reason: 'negatife düşerse devir yanlış pencereye yazılmış demektir');
      expect(await CashHandoverRepository(db).araTahsilatlar(bugun), isEmpty,
          reason: 'kapanışa bağlı devir ara tahsilat listesine girmez');
    });

    test('B · kuryelerde kalan kümesi DEFTERDEN türer: pasif/aynada olmayan kurye düşmez',
        () async {
      // `users` sunucu kaynaklı bir önbellektir ve GEÇ İNEBİLİR; `status='active'` süzgeci gün
      // içinde pasife alınmış kuryeyi düşürürdü. Kümeden düşen kuryenin parası "kuryelerde
      // kalan"a girmez, gün beklentisi ŞİŞER, patron açıklayamadığı bir EKSİK görür.
      await kurye('k1', 'Emre', durum: 'disabled'); // gün içinde pasife alındı
      await nakit(5000, kuryeId: 'k1', at: oncekiIso());
      // k2 aynaya HİÇ inmemiş (users satırı yok) ama defterde parası var.
      await nakit(3000, kuryeId: 'k2', at: oncekiIso());

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.dusulenKurus, 8000,
          reason: 'ikisi de hâlâ para taşıyor; aynadan düşmeleri parayı yok etmez');
      expect(on.expectedCashKurus, 0, reason: 'patronun kasasına henüz hiçbir şey girmedi');
    });

    test('B · patronun kendi topladığı nakit "kuryede" sayılmaz', () async {
      // Dışlama POZİTİF bilgiye dayanır: ayna "bu kişi kurye değil" diyorsa kümeden çıkar.
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'p1', name: 'Patron', role: 'patron', status: 'active'));
      await nakit(4000, kuryeId: 'p1', at: oncekiIso());

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.dusulenKurus, 0);
      expect(on.expectedCashKurus, 4000, reason: 'para zaten patronun kasasında');
    });

    test('E · toplayıcısı NULL nakit kasada sayılır (kuryede değil)', () async {
      // Oturum kurulmadan yazılan tahsilat kimseye atfedilmez. Atfı olmayan para "kuryede"
      // sayılamaz — kasada sayılır. Karar bilinçli ve testle kilitli.
      await writeLedgerEntry(db,
          entryType: 'payment',
          amountKurus: -2500,
          paymentType: 'nakit',
          occurredAt: oncekiIso());

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.dusulenKurus, 0);
      expect(on.expectedCashKurus, 2500);
    });

    test('F3 · geçmiş gün kapanışı O GÜNE damgalanır', () async {
      // `kapaliMi` ve `gununKapanislari` occurred_at'in TR gününe bakıyor; "şimdi"ye
      // damgalarsak dünü kapatan kapanış dünde GÖRÜNMEZ.
      await kurye('k1', 'Emre');
      final dun = bugun.subtract(const Duration(days: 1));
      await nakit(4000,
          kuryeId: 'k1',
          at: gunBasiUtc(dun).add(const Duration(hours: 12)).toIso8601String());

      final kapanislar = DayClosingRepository(db);
      await kapanislar.kapat(scope: ClosingScope.day, countedCashKurus: 0, localDate: dun);

      expect(await kapanislar.kapaliMi(ClosingScope.day, localDate: dun), isTrue,
          reason: 'dün kapatıldı ve dünde görünmeli');
      expect(await kapanislar.kapaliMi(ClosingScope.day, localDate: bugun), isFalse,
          reason: 'dünü kapatmak bugünü kapatmaz');
      expect((await kapanislar.gununKapanislari(dun)), hasLength(1));
    });

    test('YENİ KİMLİK: gün beklenen + kuryelerde kalan == günün nakdi', () async {
      await kurye('k1', 'Emre');
      await kurye('k2', 'Deniz');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      await nakit(4000, kuryeId: 'k2', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.expectedCashKurus + on.dusulenKurus, on.gunNakitKurus);
      expect(on.gunNakitKurus, 13000);
      expect(on.dusulenKurus, 7000, reason: 'k1 3.000 + k2 4.000');
      expect(on.expectedCashKurus, 6000, reason: 'patronun aldığı ara tahsilat');
      expect(on.dusulenKalem, DusulenKalem.kuryelerdeKalan);
    });

    test('düşülen kalemin ANLAMI değerle birlikte taşınır', () async {
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);

      final kapanislar = DayClosingRepository(db);
      final gun = await kapanislar.onizle(ClosingScope.day, localDate: bugun);
      final kuryeKapsam =
          await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);

      expect(gun.dusulenKalem, DusulenKalem.kuryelerdeKalan);
      expect(gun.dusulenKurus, 3000);
      expect(kuryeKapsam.dusulenKalem, DusulenKalem.teslimEdilen);
      expect(kuryeKapsam.dusulenKurus, 6000,
          reason: 'aynı ekran alanı, ZIT yönlü iki büyüklük — etiket enum\'dan seçilmeli');
    });

    test('uç durum: kuryelerde kalan 0 döner (null değil)', () async {
      // gun-ui koşulunu `!= 0` üzerine kuruyor; tek kişilik bayide ve kurye kapattıktan sonra
      // orta satır çizilmeyecek.
      final tekKisilik = await DayClosingRepository(db)
          .onizle(ClosingScope.day, localDate: bugun);
      expect(tekKisilik.dusulenKurus, 0);

      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 9000,
        alsoHandover: true,
        localDate: bugun,
      );
      final kapandiktanSonra = await DayClosingRepository(db)
          .onizle(ClosingScope.day, localDate: bugun);
      expect(kapandiktanSonra.dusulenKurus, 0);
      expect(kapandiktanSonra.expectedCashKurus, 9000);
    });

    test('üç sayı ARİTMETİK OLARAK kapanır: çerçeve nakdi − düşülen = beklenen', () async {
      // Ekran farkı açıklayabilsin diye üçü birden taşınıyor; kapanmayan bir üçlü, patronun
      // toplamdan küçük bir rakam görüp sebebini soramaması demekti.
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);

      final kapanislar = DayClosingRepository(db);
      for (final on in [
        await kapanislar.onizle(ClosingScope.day, localDate: bugun),
        await kapanislar.onizle(ClosingScope.courier, userId: 'k1', localDate: bugun),
      ]) {
        expect(on.gunNakitKurus - on.dusulenKurus, on.expectedCashKurus);
      }
    });

    test('gece toplanan kasa ertesi sabah teslim edilir: beklenen NEGATİFE düşmez', () async {
      // İnceleme #2: pencere takvim gününe demirliyken "bugün toplanan 0 − bugün teslim edilen
      // 5.000 = −5.000" çıkıyor ve kayda diff +5.000 KALICI donuyordu. Cep gece yarısında
      // boşalmaz — pencere o kuryenin SON KAPANIŞINA demirli.
      await kurye('k1', 'Emre');
      final dun = bugun.subtract(const Duration(days: 1));
      // Dün akşam 23:00 TR'de toplandı, hiç kapanış yok.
      await nakit(5000,
          kuryeId: 'k1',
          at: gunBasiUtc(dun).add(const Duration(hours: 23)).toIso8601String());

      final on = await CashHandoverRepository(db).onizle('k1');
      expect(on.expectedKurus, 5000,
          reason: 'dünkü kasa hâlâ kuryenin cebinde; bugünün penceresi onu görmeli');
      expect(on.expectedKurus, isNonNegative);

      // Sabah teslim ediyor: fark 0, kayda "fazla para" yazılmıyor.
      final id = await CashHandoverRepository(db)
          .araTahsilat(fromUserId: 'k1', countedCashKurus: 5000);
      final kayit = await (db.select(db.cashHandovers)..where((t) => t.id.equals(id))).getSingle();
      expect(kayit.expectedCashKurus, 5000);
      expect(kayit.diffKurus, 0, reason: 'ESKİ kod +5.000 "fazla" yazardı ve bu kalıcı olurdu');
    });

    test('kapanış pencereyi KAPATIR: önceki günün nakdi bir daha beklenmez', () async {
      await kurye('k1', 'Emre');
      final dun = bugun.subtract(const Duration(days: 1));
      await nakit(5000,
          kuryeId: 'k1',
          at: gunBasiUtc(dun).add(const Duration(hours: 23)).toIso8601String());

      await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 5000,
        alsoHandover: true,
      );

      expect((await CashHandoverRepository(db).onizle('k1')).expectedKurus, 0,
          reason: 'kapanış yeni pencere açtı; devredilen para yeni pencereye taşınmaz');
    });

    test('period_start kayda YAZILMAYA devam eder (denetim izi)', () async {
      // Beklenen hesabı artık period_start'tan türemiyor; izin kaybolmadığını burada kilitliyoruz,
      // yoksa sonraki vardiya "kullanılmıyor" deyip siler.
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());
      final devirler = CashHandoverRepository(db);

      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);
      final ilk = (await db.select(db.cashHandovers).get()).single;
      expect(ilk.periodStart, isNotNull);
      expect(ilk.periodStart, endsWith('Z'));

      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 3000);
      final ikinci = (await db.select(db.cashHandovers).get())
          .firstWhere((r) => r.id != ilk.id);
      expect(ikinci.periodStart, ilk.occurredAt,
          reason: 'ikinci devrin penceresi birincinin damgasından başlar');
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
      expect(gorunum.araTahsilatlar.single.countedCashKurus, 3000);
      // Para görünüm modelinden TÜRETİLMEZ; tek kaynak kapanış önizlemesidir (#7).
      final on = await DayClosingRepository(db)
          .onizle(ClosingScope.courier, userId: 'k1', localDate: dun);
      expect(on.expectedCashKurus, 6000, reason: 'geçmiş gün de aynı kümülatif tanımı kullanır');
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

  group('inceleme düzeltmeleri', () {
    test('#3 kapanış + devir TEK transaction: yarım kalmış devir üretilemez', () async {
      // Devir transaction'ın DIŞINDA çağrılıyordu; arada süreç ölürse kapanışa bağlanmamış bir
      // devir kalır ve `araTahsilatlar` onu ARA TAHSİLAT sayardı — kurye hesabı kapanmamış
      // görünür, ara tahsilat toplamı şişerdi. Kapanışı ZORLA düşürüp ikisinin de yazılmadığını
      // kanıtlıyoruz (userId null → ArgumentError, ama asıl kanıt: devir de yazılmamış olmalı).
      await kurye('k1', 'Emre');
      await nakit(9000, kuryeId: 'k1', at: oncekiIso());

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
      await kurye('k1', 'Emre');
      final dun = bugun.subtract(const Duration(days: 1));
      await nakit(4000,
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
      await kurye('k1', 'Emre');
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
      await kurye('k1', 'Emre');
      await nakit(10000, kuryeId: 'k1', at: oncekiIso());
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
