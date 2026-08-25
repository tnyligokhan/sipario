
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/ledger_ops.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart';

import 'support/ara_tahsilat_ortami.dart';

/// ARA TAHSİLAT — DEVİR PENCERESİ ("kuryede kalan devreder").
///
/// KULLANICI KARARI 2026-08-06: patron ara tahsilatta beklenenin TAMAMINI almayabilir; kuryede
/// BİLEREK bırakılan para bir sonraki pencereye DEVREDER. Eski `period_start` penceresi onu yok
/// sayıyordu: beklenen 0 çıkıyor, kurye o parayı verince ekran "FAZLA" yazıyordu — yani bilerek
/// bırakılan para fazla para gibi görünüyordu.
///
/// Bölme gerekçesi ve ortak fikstür: `ara_tahsilat_test.dart` başlığı.

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final bugun = bugunTr();

  group('kuryede kalan devreder', () {
    test('kısmi ara tahsilat sonrası akşam beklenen KALAN kadar; fark 0', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());

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
      await kurye(db, 'k1', 'Emre');
      final devirler = CashHandoverRepository(db);

      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());
      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 6000); // 3.000 kuryede kaldı
      await nakit(db, 5000, kuryeId: 'k1', at: sonrakiIso());

      expect((await devirler.onizle('k1')).expectedKurus, 8000,
          reason: 'kalan 3.000 + yeni 5.000; ESKİ kod yalnız 5.000 derdi');
    });

    test('tam tahsilatta beklenen 0 (regresyon koruması)', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 9000);

      final on = await DayClosingRepository(db)
          .onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
      expect(on.expectedCashKurus, 0);
      expect(on.dusulenKurus, 9000);
    });

    test('kapanış sonrası kuryenin cebi BOŞ görünür (devir kapanan pencerede kalır)', () async {
      // Kapanış ile ona bağlanan devir AYNI damgayı taşır. Devir bir milisaniye SONRA
      // damgalansaydı kapanışın AÇTIĞI pencereye düşer ve beklenen −9.000 çıkardı.
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());

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
      await kurye(db, 'k1', 'Emre', durum: 'disabled'); // gün içinde pasife alındı
      await nakit(db, 5000, kuryeId: 'k1', at: oncekiIso());
      // k2 aynaya HİÇ inmemiş (users satırı yok) ama defterde parası var.
      await nakit(db, 3000, kuryeId: 'k2', at: oncekiIso());

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.dusulenKurus, 8000,
          reason: 'ikisi de hâlâ para taşıyor; aynadan düşmeleri parayı yok etmez');
      expect(on.expectedCashKurus, 0, reason: 'patronun kasasına henüz hiçbir şey girmedi');
    });

    test('B · patronun kendi topladığı nakit "kuryede" sayılmaz', () async {
      // Dışlama POZİTİF bilgiye dayanır: ayna "bu kişi kurye değil" diyorsa kümeden çıkar.
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'p1', name: 'Patron', role: 'patron', status: 'active'));
      await nakit(db, 4000, kuryeId: 'p1', at: oncekiIso());

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
      await kurye(db, 'k1', 'Emre');
      final dun = bugun.subtract(const Duration(days: 1));
      await nakit(db, 4000,
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

    test('YENİ KİMLİK: gün beklenen + kuryelerin günlük net değişimi == günün nakdi', () async {
      await kurye(db, 'k1', 'Emre');
      await kurye(db, 'k2', 'Deniz');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());
      await nakit(db, 4000, kuryeId: 'k2', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.expectedCashKurus + on.dusulenKurus, on.gunNakitKurus);
      expect(on.gunNakitKurus, 13000);
      expect(on.dusulenKurus, 7000, reason: 'k1 3.000 + k2 4.000 hâlâ kuryelerde');
      expect(on.expectedCashKurus, 6000, reason: 'patronun aldığı ara tahsilat');
      expect(on.dusulenKalem, DusulenKalem.kuryelerdeKalan);
    });

    test('düşülen kalemin ANLAMI değerle birlikte taşınır', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());
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

      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());
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

    // Üçlü kimliği (`gunNakit − dusulen == expected`) TEK BAŞINA ölçmek VAKUMDUR: iki alan da
    // aynı iki değişkenden dolduruluyor, yani kimlik çıkarmanın kendisi ve hiçbir senaryoda
    // kırılamaz. #1 tam da o kimlik yeşilken oluştu. Bu yüzden aşağıdaki testler beklenen'i
    // BAĞIMSIZ yoldan türetiyor:
    //   beklenen = patronun bugün DOĞRUDAN topladığı + bugün alınan devirlerin SAYILAN toplamı
    // yani "bugün kasaya fiilen giren para".
    group('bağımsız türetme: bugün kasaya fiilen giren para', () {
      /// Repo'dan TAMAMEN ayrı yol: defteri ve devirleri elle toplar.
      Future<int> beklenenBagimsiz(DateTime gun, {Set<String> kuryeler = const {}}) async {
        var patronunTopladigi = 0;
        for (final e in await db.select(db.ledgerEntries).get()) {
          if (e.paymentType != 'nakit' || !ayniTrGun(e.occurredAt, gun)) continue;
          final k = e.collectedByUserId;
          if (k != null && kuryeler.contains(k)) continue; // kurye topladı, kasaya girmedi
          patronunTopladigi += -e.amountKurus;
        }
        var devirler = 0;
        for (final h in await db.select(db.cashHandovers).get()) {
          if (ayniTrGun(h.occurredAt, gun)) devirler += h.countedCashKurus;
        }
        return patronunTopladigi + devirler;
      }

      test('kurye hepsini teslim etti (6.000 ara + 4.000 kapanış)', () async {
        await kurye(db, 'k1', 'Emre');
        await nakit(db, 10000, kuryeId: 'k1', at: oncekiIso());
        final devirler = CashHandoverRepository(db);
        await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);
        await DayClosingRepository(db).kapat(
          scope: ClosingScope.courier,
          userId: 'k1',
          countedCashKurus: 4000,
          alsoHandover: true,
          localDate: bugun,
        );

        final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
        expect(on.expectedCashKurus, await beklenenBagimsiz(bugun, kuryeler: {'k1'}));
        expect(on.expectedCashKurus, 10000);
      });

      test('kurye 4.000 elinde tutuyor', () async {
        await kurye(db, 'k1', 'Emre');
        await nakit(db, 10000, kuryeId: 'k1', at: oncekiIso());
        await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);

        final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
        expect(on.expectedCashKurus, await beklenenBagimsiz(bugun, kuryeler: {'k1'}));
        expect(on.expectedCashKurus, 6000);
      });

      test('DÜNDEN 5.000 taşıyan kurye bugün 3.000 topladı, teslim yok → 0 (negatif YOK)',
          () async {
        // İkinci incelemenin bulduğu hata: stok düşülünce 3.000 − 8.000 = −5.000 çıkıyordu ve
        // patronun kasasında 0 varken ekran FAZLA 5.000 yazıyordu.
        await kurye(db, 'k1', 'Emre');
        final dun = bugun.subtract(const Duration(days: 1));
        await nakit(db, 5000,
            kuryeId: 'k1',
            at: gunBasiUtc(dun).add(const Duration(hours: 20)).toIso8601String());
        await nakit(db, 3000, kuryeId: 'k1', at: oncekiIso());

        final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
        expect(on.expectedCashKurus, await beklenenBagimsiz(bugun, kuryeler: {'k1'}));
        expect(on.expectedCashKurus, 0, reason: 'bugün kasaya hiç para girmedi');
        expect(on.dusulenKurus, 3000, reason: 'yalnız BUGÜNKÜ birikim; dünkü stok değil');
        // Kurye kapsamı STOKU gösterir ve göstermelidir — iki kapsam iki farklı soru.
        final kuryeKapsam = await DayClosingRepository(db)
            .onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
        expect(kuryeKapsam.expectedCashKurus, 8000, reason: 'cebinde gerçekten 8.000 var');
      });

      test('DÜNÜN parasını bu sabah teslim etti, bugün hiç toplamadı → 5.000', () async {
        // Orta terim NEGATİF olur (−5.000) ve kimlik yine tutar.
        await kurye(db, 'k1', 'Emre');
        final dun = bugun.subtract(const Duration(days: 1));
        await nakit(db, 5000,
            kuryeId: 'k1',
            at: gunBasiUtc(dun).add(const Duration(hours: 20)).toIso8601String());
        await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 5000);

        final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
        expect(on.expectedCashKurus, await beklenenBagimsiz(bugun, kuryeler: {'k1'}));
        expect(on.gunNakitKurus, 0, reason: 'bugün hiç tahsilat yapılmadı');
        expect(on.dusulenKurus, -5000, reason: 'net değişim EKSİ — kırpma yok');
        expect(on.expectedCashKurus, 5000, reason: 'kasaya dünün parası girdi');
      });

      test('kurye HİÇ kapanış yapmadan 3 gün artık para tutuyor: sapma BİRİKMİYOR', () async {
        // Sinsi varyant: stok her gün büyür, gün beklenen her akşam biraz daha eksik gösterirdi.
        await kurye(db, 'k1', 'Emre');
        for (var i = 3; i >= 1; i--) {
          final g = bugun.subtract(Duration(days: i));
          await nakit(db, 10000,
              kuryeId: 'k1',
              at: gunBasiUtc(g).add(const Duration(hours: 10)).toIso8601String());
          // Her gün 9.000 teslim, 1.000 para üstü için kuryede kalıyor.
          await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
                id: 'devir-$i',
                fromUserId: 'k1',
                countedCashKurus: 9000,
                expectedCashKurus: 9000,
                diffKurus: 0,
                occurredAt:
                    gunBasiUtc(g).add(const Duration(hours: 20)).toIso8601String(),
              ));

          final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: g);
          expect(on.expectedCashKurus, await beklenenBagimsiz(g, kuryeler: {'k1'}),
              reason: '$i gün önce');
          expect(on.expectedCashKurus, 9000, reason: 'her gün kasaya 9.000 girdi — sapma yok');
          expect(on.dusulenKurus, 1000, reason: 'o günün birikimi; biriken stok DEĞİL');
        }
        // Stok gerçekten birikti ve KURYE kapsamında görünüyor.
        final kuryeKapsam = await DayClosingRepository(db)
            .onizle(ClosingScope.courier, userId: 'k1', localDate: bugun);
        expect(kuryeKapsam.expectedCashKurus, 3000, reason: '3 gün × 1.000');
      });

      test('tek kişilik bayi: beklenen = günün tüm nakdi', () async {
        await db.syncState();
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
            const SyncMetaCompanion(userId: Value('p1'), userRole: Value('patron')));
        await nakit(db, 7500, kuryeId: 'p1', at: oncekiIso());

        final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
        expect(on.expectedCashKurus, await beklenenBagimsiz(bugun));
        expect(on.expectedCashKurus, 7500);
      });
    });

    test('gece toplanan kasa ertesi sabah teslim edilir: beklenen NEGATİFE düşmez', () async {
      // İnceleme #2: pencere takvim gününe demirliyken "bugün toplanan 0 − bugün teslim edilen
      // 5.000 = −5.000" çıkıyor ve kayda diff +5.000 KALICI donuyordu. Cep gece yarısında
      // boşalmaz — pencere o kuryenin SON KAPANIŞINA demirli.
      await kurye(db, 'k1', 'Emre');
      final dun = bugun.subtract(const Duration(days: 1));
      // Dün akşam 23:00 TR'de toplandı, hiç kapanış yok.
      await nakit(db, 5000,
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
      await kurye(db, 'k1', 'Emre');
      final dun = bugun.subtract(const Duration(days: 1));
      await nakit(db, 5000,
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
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());
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

}
