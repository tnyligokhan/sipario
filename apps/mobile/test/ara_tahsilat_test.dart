
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart';

import 'support/ara_tahsilat_ortami.dart';

/// ARA TAHSİLAT — KAPSAM KURALLARI (gün kapsamı · liste · geçmiş gün).
///
/// Patron gün içinde kuryenin cebindeki nakdi alabilir; gün AÇIK kalır. Bu dosyanın koruduğu
/// asıl kural ÇİFTE SAYMA yasağıdır: ara tahsilat gün kapanışının beklentisinden BİR kez düşer.
/// İki ayrı yerde (gün kapsamı ledger'den, kurye kapsamı period_start'tan) hesaplanan "kalan"
/// aynı rakamı vermek zorunda — vermezse patron hangi ekrana bakarsa ona göre para arar.
///
/// DOSYA ÜÇE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 1126 satırdı): devir penceresi
/// `ara_tahsilat_devir_test.dart`ta, yazma kuralları `ara_tahsilat_kurallari_test.dart`ta.
/// Ortak fikstür `support/ara_tahsilat_ortami.dart`ta — üç dosya da onu kullanır.

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final bugun = bugunTr();

  group('gün kapsamı: patronun kasasında ne olmalı', () {
    test('ara tahsilat sonrası beklenen = patronun aldığı; kalan kuryede görünür', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 10000, kuryeId: 'k1', at: oncekiIso());

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
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 10000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 10000);

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.dusulenKurus, 0, reason: 'kuryede para kalmadı');
      expect(on.expectedCashKurus, 10000, reason: 'hepsi patronun kasasında');
    });

    test('kurye kapanışı da iç transferdir: gün beklentisi düşmez', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());

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
      await nakit(db, 7500, kuryeId: 'patron-1', at: oncekiIso());

      final on = await DayClosingRepository(db).onizle(ClosingScope.day, localDate: bugun);
      expect(on.dusulenKurus, 0);
      expect(on.expectedCashKurus, 7500);
    });

    test('ara tahsilat + gün kapanışı: arşive patronun kasası yazılır, fark 0', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 10000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);

      final id = await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 4000, localDate: bugun);

      final kayit = await (db.select(db.dayClosings)..where((t) => t.id.equals(id))).getSingle();
      expect(kayit.cashNakitKurus, 10000, reason: 'günün tam nakdi arşivde durur');
      expect(kayit.expectedCashKurus, 4000);
      expect(kayit.diffKurus, 0);
    });

    test('ara tahsilatta EKSİK sayım gün beklentisine karışmaz', () async {
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 10000, kuryeId: 'k1', at: oncekiIso());
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
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: oncekiIso());
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
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 4000, kuryeId: 'k1', at: oncekiIso());
      await CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);
      await nakit(db, 6000, kuryeId: 'k1', at: sonrakiIso());

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

  group('ara tahsilat listesi', () {
    test('kim · ne zaman · sayılan · beklenen · fark döner, eskiden yeniye', () async {
      await kurye(db, 'k1', 'Emre');
      await kurye(db, 'k2', 'Deniz');
      final devirler = CashHandoverRepository(db);

      await nakit(db, 4000, kuryeId: 'k1', at: oncekiIso());
      await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 4000, note: 'birinci');
      await nakit(db, 3000, kuryeId: 'k2', at: sonrakiIso());
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
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 5000, kuryeId: 'k1', at: oncekiIso());

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
      await kurye(db, 'k1', 'Emre');
      await nakit(db, 9000, kuryeId: 'k1', at: ogleUtc.toIso8601String());
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
      await nakit(db, 7777, kuryeId: 'k1', at: oncekiIso()); // bugün
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

}
