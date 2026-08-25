// İPTAL ONAY AKIŞI — kurye TALEP açar, patron onaylar ya da reddeder (kullanıcı isteği
// 2026-08-22).
//
// ÜÇ AYRI SORU, ÜÇ AYRI GRUP:
//   1. DURUM TÜRETME — olay geçmişinden "bekleyen talep var mı" doğru okunuyor mu (saf).
//   2. YAZMA YOLU     — talep/ret gerçekten olay + outbox üretiyor mu, sipariş AÇIK kalıyor mu.
//   3. YÜZEY          — düğme etiketi yetkiye göre değişiyor, bant karar düğmesini doğru
//                       kişiye gösteriyor mu.
//
// ⚠️ İKİNCİ GRUP EN ÖNEMLİSİ: bir talebin siparişi iptal ETMEMESİ bu özelliğin tamamıdır.
// Talep siparişi kapatsaydı patronun "Reddet" düğmesi geri alınamaz bir işi düzeltmeye
// çalışırdı ve bu depoda para/durum kayıtları geri alınmaz, telafi edilir.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/push/push_sozlesmesi.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/orders/iptal_onayi.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/orders/order_queries.dart';

import 'support/siparis_yardimci.dart';

/// Tek siparişli, tek müşterili bir bayi — iptal akışının bütün testleri bununla kurulur.
///
/// FİKSTÜR SINIFI (depo kuralı 2026-08-17): kurulum durumu ve onun üzerinde işleyen davranış
/// (talep aç, reddet, oku) tek nesnede kapsüllenir; her testte kopyalanan kapanışlar yerine
/// dar bir yüzey.
class IptalTezgahi {
  IptalTezgahi() : db = AppDatabase(NativeDatabase.memory());

  final AppDatabase db;
  static const siparisId = 'sip-1';

  Future<void> kur({String? oturumKullanicisi}) async {
    await db.into(db.customers).insert(CustomersCompanion.insert(
        id: 'm1', name: 'Ayşe Yılmaz', updatedOccurredAt: '2026-08-22T00:00:00.000Z'));
    await db.into(db.orders).insert(OrdersCompanion.insert(
          id: siparisId,
          customerId: const Value('m1'),
          occurredAt: '2026-08-22T10:00:00.000Z',
        ));
    if (oturumKullanicisi != null) {
      await db.into(db.users).insert(UsersCompanion.insert(
            id: oturumKullanicisi,
            name: 'Kurye Ali',
            role: 'kurye',
            status: 'active',
          ));
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        SyncMetaCompanion(userId: Value(oturumKullanicisi), userRole: const Value('kurye')),
      );
    }
  }

  OrderRepository get depo => OrderRepository(db);

  Future<Order> siparis() =>
      (db.select(db.orders)..where((t) => t.id.equals(siparisId))).getSingle();

  Future<List<OrderEvent>> olaylar() =>
      (db.select(db.orderEvents)..where((t) => t.orderId.equals(siparisId))).get();

  Future<IptalTalebi?> talep() async => iptalTalebiCoz(await olaylar());

  Future<List<String>> outboxOplari() async {
    final satirlar = await db.select(db.outbox).get();
    return satirlar.map((o) => o.op).toList();
  }
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 1. DURUM TÜRETME — saf
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('iptalTalebiCoz — bekleyen talep olaylardan türer', () {
    /// Sunucu tarafıyla AYNI sıralama anahtarını (occurredAt, id) kullandığını da sınamak için
    /// olaylar bilerek KARIŞIK sırayla verilir.
    OrderEvent olay(String id, String tur, String an, {String? yuk}) => OrderEvent(
          id: id,
          orderId: 'o1',
          eventType: tur,
          payload: yuk,
          clientEventId: 'c-$id',
          occurredAt: an,
        );

    test('hiç olay yoksa talep yok', () {
      expect(iptalTalebiCoz(const []), isNull);
    });

    test('son olay cancel_requested ise talep BEKLİYOR', () {
      final t = iptalTalebiCoz([
        olay('2', 'cancel_requested', '2026-08-22T11:00:00.000Z',
            yuk: '{"requested_by_user_id":"k1","reason":"Müşteri vazgeçti"}'),
        olay('1', 'created', '2026-08-22T10:00:00.000Z'),
      ]);

      expect(t, isNotNull);
      expect(t!.isteyenUserId, 'k1');
      expect(t.gerekce, 'Müşteri vazgeçti');
    });

    test('REDDEDİLMİŞ talep bekleyen SAYILMAZ', () {
      final t = iptalTalebiCoz([
        olay('1', 'cancel_requested', '2026-08-22T11:00:00.000Z'),
        olay('2', 'cancel_rejected', '2026-08-22T11:05:00.000Z'),
      ]);
      expect(t, isNull);
    });

    test('REDDEDİLDİKTEN SONRA YENİDEN istenebilir', () {
      // Müşteri kapıda iki kez fikir değiştirebilir; ilk reddin ikinci talebi yutması,
      // kuryenin elinden tek yolunu almak olurdu.
      final t = iptalTalebiCoz([
        olay('1', 'cancel_requested', '2026-08-22T11:00:00.000Z'),
        olay('2', 'cancel_rejected', '2026-08-22T11:05:00.000Z'),
        olay('3', 'cancel_requested', '2026-08-22T11:30:00.000Z',
            yuk: '{"requested_by_user_id":"k2"}'),
      ]);
      expect(t?.isteyenUserId, 'k2');
    });

    test('ONAYLANMIŞ (iptal edilmiş) ya da TESLİM edilmiş siparişte talep asılı kalmaz', () {
      expect(
        iptalTalebiCoz([
          olay('1', 'cancel_requested', '2026-08-22T11:00:00.000Z'),
          olay('2', 'cancelled', '2026-08-22T11:05:00.000Z'),
        ]),
        isNull,
      );
      expect(
        iptalTalebiCoz([
          olay('1', 'cancel_requested', '2026-08-22T11:00:00.000Z'),
          olay('2', 'delivered', '2026-08-22T11:05:00.000Z'),
        ]),
        isNull,
      );
    });

    test('AYNI ANDA gelen iki olayda sıra KİMLİĞE göre çözülür (deterministik)', () {
      // İki cihaz çevrimdışıyken aynı damgayı üretebilir. Sunucu ve istemci AYNI ikinci
      // anahtarı kullanmazsa bir taraf "talep var" der, öteki "yok" — ve bu fark hiçbir yerde
      // hata vermez.
      const an = '2026-08-22T11:00:00.000Z';
      expect(
        iptalTalebiCoz([olay('b', 'cancel_rejected', an), olay('a', 'cancel_requested', an)]),
        isNull,
        reason: 'id sırasında son olan `b` (ret) kazanır',
      );
      expect(
        iptalTalebiCoz([olay('a', 'cancel_rejected', an), olay('b', 'cancel_requested', an)]),
        isNotNull,
        reason: 'id sırasında son olan `b` (talep) kazanır',
      );
    });

    test('BOZUK yük çökertmez, kimliksiz talep döner', () {
      final t = iptalTalebiCoz([olay('1', 'cancel_requested', '2026-08-22T11:00:00.000Z')]);
      expect(t, isNotNull);
      expect(t!.isteyenUserId, isNull, reason: 'ad uydurulmaz');
      expect(t.gerekce, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 2. YAZMA YOLU
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('OrderRepository — talep siparişi İPTAL ETMEZ', () {
    test('iptalTalepEt: olay + outbox yazar, status AÇIK kalır', () async {
      final tezgah = IptalTezgahi();
      await tezgah.kur(oturumKullanicisi: 'k1');

      await tezgah.depo.iptalTalepEt(IptalTezgahi.siparisId, gerekce: 'Müşteri vazgeçti');

      final siparis = await tezgah.siparis();
      expect(siparis.status, 'open',
          reason: 'TALEP İPTAL DEĞİLDİR — patron cevap verene kadar sipariş teslim edilebilir');

      final olaylar = await tezgah.olaylar();
      expect(olaylar.map((e) => e.eventType), contains('cancel_requested'));

      // Senkron yolu: sunucu bu op'u tanımalı (`EventValidator::OPS`).
      expect(await tezgah.outboxOplari(), contains('cancel_requested'));

      final talep = await tezgah.talep();
      expect(talep!.isteyenUserId, 'k1',
          reason: 'reddi kime bildireceğimizin tek kaynağı budur');
      expect(talep.gerekce, 'Müşteri vazgeçti');
    });

    test('gerekçe BOŞSA yükte hiç taşınmaz', () async {
      final tezgah = IptalTezgahi();
      await tezgah.kur(oturumKullanicisi: 'k1');

      await tezgah.depo.iptalTalepEt(IptalTezgahi.siparisId, gerekce: '   ');

      final talep = await tezgah.talep();
      expect(talep, isNotNull, reason: 'gerekçesiz talep MEŞRUDUR');
      expect(talep!.gerekce, isNull);
    });

    test('iptalTalebiniReddet: talep kapanır, sipariş AÇIK kalır', () async {
      final tezgah = IptalTezgahi();
      await tezgah.kur(oturumKullanicisi: 'k1');

      await tezgah.depo.iptalTalepEt(IptalTezgahi.siparisId);
      await tezgah.depo.iptalTalebiniReddet(IptalTezgahi.siparisId);

      expect(await tezgah.talep(), isNull);
      expect((await tezgah.siparis()).status, 'open');
      expect(await tezgah.outboxOplari(), contains('cancel_rejected'));
    });

    test('ONAY = mevcut cancel yolu; ayrı bir "approved" olayı YOK', () async {
      // İptalin tek doğru kaydı `cancelled`tır. İkinci bir onay olayı, siparişin durumunu
      // türeten iki ayrı kural demekti.
      final tezgah = IptalTezgahi();
      await tezgah.kur(oturumKullanicisi: 'k1');

      await tezgah.depo.iptalTalepEt(IptalTezgahi.siparisId);
      await tezgah.depo.cancel(IptalTezgahi.siparisId);

      expect((await tezgah.siparis()).status, 'cancelled');
      expect(await tezgah.talep(), isNull);
      final turler = (await tezgah.olaylar()).map((e) => e.eventType).toSet();
      expect(turler, contains('cancelled'));
      expect(turler.any((t) => t.contains('approve')), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 3. PUSH METNİ — tek kategori, iki yön
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('push — iptal onayı tek kategoride iki yön taşır', () {
    test('TALEP: yönetici karar düğmeleri görür, yol SİPARİŞE gider', () {
      final t = pushTaslagi(
        const PushMesaji(
          kategori: BildirimKategori.siparisIptalOnayi,
          varlikId: 'sip-1',
          olay: PushOlayAdi.iptalTalebi,
        ),
        ayrinti: 'Ayşe Yılmaz',
      );

      expect(t.baslik, 'İptal onayı bekliyor');
      expect(t.govde, contains('Ayşe Yılmaz'));
      expect(t.kararIster, isTrue);
      expect(bildirimYoluCoz(t.yol), (tur: 'siparis', id: 'sip-1', eylem: null));
    });

    test('RET: karar düğmesi YOK — kuryenin verecek kararı yok', () {
      final t = pushTaslagi(
        const PushMesaji(
          kategori: BildirimKategori.siparisIptalOnayi,
          varlikId: 'sip-1',
          olay: PushOlayAdi.iptalReddedildi,
        ),
      );

      expect(t.baslik, 'İptal talebiniz reddedildi');
      expect(t.kararIster, isFalse);
    });

    test('TANINMAYAN olayda TALEP varsayılır', () {
      // Eski sunucu bu kategoriyi hiç göndermez; buraya yalnız yeni sunucudan gelinir.
      // Bilinmeyen bir değerde "bir iş bekliyor" demek, "bir şey oldu" demekten yararlıdır.
      final t = pushTaslagi(
        const PushMesaji(kategori: BildirimKategori.siparisIptalOnayi, varlikId: 'sip-1'),
      );
      expect(t.baslik, 'İptal onayı bekliyor');
      expect(t.kararIster, isTrue);
    });

    test('sunucunun `olay` alanı çözülür (yükte İLK GÜNDEN BERİ vardı)', () {
      final m = pushMesajiCoz({
        'olay': PushOlayAdi.iptalReddedildi,
        'id': 'sip-1',
        'kategori': 'siparis_iptal_onayi',
      });
      expect(m?.olay, PushOlayAdi.iptalReddedildi);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 4. YÜZEY
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('sipariş detayı — düğme etiketi ve karar bandı', () {
    testWidgets('KURYE "İptal İste" görür, "İptal Et" GÖRMEZ', (tester) async {
      genisYuzey(tester);
      final tezgah = IptalTezgahi();
      await tester.runAsync(() => tezgah.kur(oturumKullanicisi: 'k1'));

      await tester.pumpWidget(sipKabuk(OrderDetailScreen(
        db: tezgah.db,
        orderId: IptalTezgahi.siparisId,
        writable: true,
      )));
      await akisiBekle(tester);

      expect(find.text('İptal İste'), findsOneWidget);
      expect(find.text('İptal Et'), findsNothing,
          reason: 'yapamayacağı işi vaat eden düğme, reddin kendisinden çok güven bozar');

      await ekraniKapat(tester);
    });

    testWidgets('PATRON "İptal Et" görür', (tester) async {
      genisYuzey(tester);
      final tezgah = IptalTezgahi();
      await tester.runAsync(() async {
        await tezgah.kur();
        await (tezgah.db.update(tezgah.db.syncMeta)..where((t) => t.id.equals(1)))
            .write(const SyncMetaCompanion(userRole: Value('patron')));
      });

      await tester.pumpWidget(sipKabuk(OrderDetailScreen(
        db: tezgah.db,
        orderId: IptalTezgahi.siparisId,
        writable: true,
      )));
      await akisiBekle(tester);

      expect(find.text('İptal Et'), findsOneWidget);
      expect(find.text('İptal İste'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('bekleyen talepte PATRON Onayla/Reddet görür ve ONAY siparişi iptal eder',
        (tester) async {
      genisYuzey(tester);
      final tezgah = IptalTezgahi();
      await tester.runAsync(() async {
        await tezgah.kur(oturumKullanicisi: 'k1');
        await tezgah.depo.iptalTalepEt(IptalTezgahi.siparisId, gerekce: 'Müşteri vazgeçti');
        // Oturum patrona geçer (talebi kurye açtı, kararı patron veriyor).
        await (tezgah.db.update(tezgah.db.syncMeta)..where((t) => t.id.equals(1)))
            .write(const SyncMetaCompanion(userId: Value(null), userRole: Value('patron')));
      });

      await tester.pumpWidget(sipKabuk(OrderDetailScreen(
        db: tezgah.db,
        orderId: IptalTezgahi.siparisId,
        writable: true,
      )));
      await akisiBekle(tester);

      // ⚠️ İKİNCİ TUR ŞART: bant üç kademeli asenkron kurar (talep akışı → ekip akışı →
      // yetki geleceği) ve her kademe bir tur daha ister. Tek `akisiBekle` ile bant çizilir
      // ama adı ve düğmeleri henüz gelmemiş olur. Gerçek cihazda üçü de milisaniyeler
      // içinde çözülür; testte sahte zaman bunu göstermez.
      await akisiBekle(tester);

      // Bant: kim istedi ve neden.
      expect(find.text('Kurye Ali iptal istedi'), findsOneWidget);
      expect(find.text('Müşteri vazgeçti'), findsOneWidget);
      expect(find.text('Onayla'), findsOneWidget);
      expect(find.text('Reddet'), findsOneWidget);

      await tester.tap(find.text('Onayla'));
      await akisiBekle(tester);
      // Onay sheet'i: geri dönüşü olmayan bir işlem sorulmadan yapılmaz.
      await tester.tap(find.text('Onayla').last);
      await akisiBekle(tester, ms: 300);

      late Order siparis;
      await tester.runAsync(() async => siparis = await tezgah.siparis());
      expect(siparis.status, 'cancelled');

      await ekraniKapat(tester);
    });

    testWidgets('bekleyen talepte KURYE karar düğmesi GÖRMEZ, "Onay bekliyor" okur',
        (tester) async {
      genisYuzey(tester);
      final tezgah = IptalTezgahi();
      await tester.runAsync(() async {
        await tezgah.kur(oturumKullanicisi: 'k1');
        await tezgah.depo.iptalTalepEt(IptalTezgahi.siparisId);
      });

      await tester.pumpWidget(sipKabuk(OrderDetailScreen(
        db: tezgah.db,
        orderId: IptalTezgahi.siparisId,
        writable: true,
      )));
      await akisiBekle(tester);
      // İkinci tur: yetki geleceği çözülmeden "Onay bekliyor" BİLEREK yazılmaz (yanlış cümleyi
      // bir kare göstermek, hiç göstermemekten kötüdür).
      await akisiBekle(tester);

      expect(find.text('Onay bekliyor'), findsOneWidget,
          reason: 'kurye talebinin gidip gitmediğini bilmezse aynı talebi tekrar açar');
      expect(find.text('Onayla'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('talep YOKKEN bant hiç çizilmez', (tester) async {
      genisYuzey(tester);
      final tezgah = IptalTezgahi();
      await tester.runAsync(() => tezgah.kur(oturumKullanicisi: 'k1'));

      await tester.pumpWidget(sipKabuk(OrderDetailScreen(
        db: tezgah.db,
        orderId: IptalTezgahi.siparisId,
        writable: true,
      )));
      await akisiBekle(tester);

      expect(find.text('Onay bekliyor'), findsNothing);
      expect(find.textContaining('iptal istedi'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('KURYE talep açar: sheet gerekçe sorar, talep yazılır', (tester) async {
      genisYuzey(tester);
      final tezgah = IptalTezgahi();
      await tester.runAsync(() => tezgah.kur(oturumKullanicisi: 'k1'));

      await tester.pumpWidget(sipKabuk(OrderDetailScreen(
        db: tezgah.db,
        orderId: IptalTezgahi.siparisId,
        writable: true,
      )));
      await akisiBekle(tester);

      await tester.tap(find.text('İptal İste'));
      await akisiBekle(tester);
      expect(find.text(iptalTalebiBasligi), findsOneWidget);
      expect(find.text('Sipariş şimdi iptal olmaz, onaya gönderilir'), findsOneWidget);

      await tester.tap(find.text('Talebi Gönder'));
      await akisiBekle(tester, ms: 300);

      late IptalTalebi? talep;
      late Order siparis;
      await tester.runAsync(() async {
        talep = await tezgah.talep();
        siparis = await tezgah.siparis();
      });
      expect(talep, isNotNull);
      expect(siparis.status, 'open', reason: 'talep siparişi kapatmaz');

      await ekraniKapat(tester);
    });
  });
}
