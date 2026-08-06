// ANA EKRAN testleri — bento ızgarası (s-ana.jsx) ve "Son Arama" kutusu.
//
// Kabuğun geri kalanı (alt navigasyon, çekmece, sihirbaz, tema) `ui_kabuk_test.dart`ta;
// bu dosya 500 satır sınırı için ayrıldı. Ortak yardımcılar `support/kabuk_yardimcilari.dart`.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/call_log_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/ana_ekran.dart';
import 'package:sipario/screens/cagri/cagri_model.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/screens/shell/alt_nav.dart';
import 'package:sipario/sync/sync_service.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'package:sipario/theme/tokens.dart';

import 'support/kabuk_yardimcilari.dart';

void main() {
  group('Ana ekran — s-ana.jsx bento ızgarası', () {
    testWidgets('sahip adı ve dört bento kutusu görünür; açık sipariş sayısı gerçek veriden',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final musteri = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        await LedgerRepository(db).borcEkle(musteri, 5000);
        final siparis = OrderRepository(db);
        // Üç sipariş açılır, biri teslim edilir → açık = 2.
        for (var i = 0; i < 3; i++) {
          await siparis.create(
            customerId: musteri,
            lines: [LineInput(productName: '19 L damacana', unitPriceKurus: 4500, qty: 1)],
          );
        }
        final ilk = await (db.select(db.orders)..limit(1)).getSingle();
        await siparis.deliver(ilk.id, paymentType: 'nakit');
      });

      await ekranaKoy(
        tester,
        AnaEkran(
          db: db,
          sahipAdi: 'Mehmet Usta',
          onMenu: () {},
          onSekme: (_) {},
          onYeniSiparis: () {},
          onBorclular: () {},
          onArama: (_) {},
          onSiparisAc: (_) {},
        ),
      );

      // Hero'da SAHİP adı yazar, işletme adı DEĞİL (`s-ana.jsx:21` `{ISLETME.sahip}`);
      // işletme adı çekmecenin başlığındadır.
      expect(find.text('Mehmet Usta'), findsOneWidget);

      // Dört kutunun etiketi (CSS .bento-k .bento-etiket)
      expect(find.text('Açık Sipariş'), findsOneWidget);
      expect(find.text('Bugün Kasa'), findsOneWidget);
      // "Açık Veresiye" → "Borçlular" (kullanıcı kararı 2026-07-29): kutu artık borçluları
      // listeleyen ekranı açıyor, müşteriler sekmesine gitmiyor.
      expect(find.text('Borçlular'), findsOneWidget);
      expect(find.text('Son Arama'), findsOneWidget);

      // Rakam demo sabiti DEĞİL, watchAnaOzet'ten gelir: 3 sipariş − 1 teslim = 2 açık.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('teslim bekliyor'), findsOneWidget);
      // Borçlu müşterinin bakiyesi "Borçlular" kutusuna düşer.
      expect(find.text('50,00 ₺'), findsOneWidget);
      expect(find.text('1 borçlu müşteri'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('bento kutusuna dokununca doğru sekmeye gidilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final gidilen = <SipSekme>[];
      var borclular = 0;

      await ekranaKoy(
        tester,
        AnaEkran(
          db: db,
          sahipAdi: 'Bayi',
          onMenu: () {},
          onSekme: gidilen.add,
          onYeniSiparis: () {},
          onBorclular: () => borclular++,
          onArama: (_) {},
          onSiparisAc: (_) {},
        ),
      );

      await tester.tap(find.text('Açık Sipariş'));
      await tester.pump();
      await tester.tap(find.text('Borçlular'));
      await tester.pump();
      await tester.tap(find.text('Bugün Kasa'));
      await tester.pump();

      // "Bugün Kasa" KOŞULSUZ gün sonuna gider (`s-ana.jsx:35`): Gün Özeti sekmesi artık
      // kuryede de açık (alt navigasyon 5 yuva, kullanıcı kararı 2026-07-26).
      // "Borçlular" bir SEKME DEĞİL ekran açar — sekme listesine girmemesi kuralın kendisidir.
      expect(gidilen, [SipSekme.siparis, SipSekme.gunSonu]);
      expect(borclular, 1);

      await kapat(tester);
    });

    testWidgets('"Borçlular" değeri 0 TL\'de de danger renginde yazılır', (tester) async {
      // Tasarım sınıfı KOŞULSUZ veriyor (`s-ana.jsx:42` `bento-v kucuk tabular eksi`). Kırmızı
      // burada alarm değil KATEGORİ rengi: kutu tahsil edilmemiş parayı sayar. Koşullu olsaydı
      // rakam veri yüklenirken nötrden kırmızıya atlıyordu.
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(
        tester,
        AnaEkran(
          db: db,
          sahipAdi: 'Bayi',
          onMenu: () {},
          onSekme: (_) {},
          onYeniSiparis: () {},
          onBorclular: () {},
          onArama: (_) {},
          onSiparisAc: (_) {},
        ),
      );

      // Borçlu yokken alt satır sayı değil DURUM yazar (0 borçlu müşteri bir bilgi değil).
      expect(find.text('tüm hesaplar temiz'), findsOneWidget);
      // "Bugün Kasa" kutusu da 0,00 ₺ yazar — değer YALNIZ borç kutusunda aranır.
      final veresiyeKutusu = find.ancestor(
        of: find.text('Borçlular'),
        matching: find.byType(SipDokun),
      );
      final deger = tester.widget<Text>(
        find.descendant(of: veresiyeKutusu, matching: find.text('0,00 ₺')),
      );
      expect(deger.style?.color, SipTokens.acik.danger);

      final kasaDegeri = tester.widget<Text>(find.descendant(
        of: find.ancestor(of: find.text('Bugün Kasa'), matching: find.byType(SipDokun)),
        matching: find.text('0,00 ₺'),
      ));
      expect(kasaDegeri.style?.color, isNot(SipTokens.acik.danger),
          reason: 'kırmızı kategori rengi yalnız borç kutusuna ait');

      await kapat(tester);
    });
  });

  group('Son aktivite — s-ana.jsx:63,67', () {
    testWidgets('satır sipariş DETAYINI açar (yalnız sekme değiştirmez) ve ürün dökümü yazar',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      String? acilan;
      await tester.runAsync(() async {
        final musteri = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        final siparis = OrderRepository(db);
        await siparis.create(
          customerId: musteri,
          lines: [
            LineInput(productName: '19 L damacana', unitPriceKurus: 4500, qty: 2),
            LineInput(productName: 'Tüp', unitPriceKurus: 1000, qty: 1),
          ],
        );
        final o = await (db.select(db.orders)..limit(1)).getSingle();
        await siparis.deliver(o.id, paymentType: 'nakit');
      });

      final gidilen = <SipSekme>[];
      await ekranaKoy(
        tester,
        AnaEkran(
          db: db,
          sahipAdi: 'Bayi',
          onMenu: () {},
          onSekme: gidilen.add,
          onYeniSiparis: () {},
          onBorclular: () {},
          onArama: (_) {},
          onSiparisAc: (id) => acilan = id,
        ),
      );

      // Alt satır ÜRÜN DÖKÜMÜ + ödeme tipidir (`siparisOzet(o) · ODEME_TIPLERI[...]`), SAAT DEĞİL.
      expect(find.text('19 L damacana ×2 · Tüp ×1 · Nakit'), findsOneWidget);

      await tester.tap(find.text('Ayşe Yılmaz'));
      await tester.pump();

      // Tasarım sekmeyi sipariş yapar VE detayı açar; eski hâl yalnız sekme değiştiriyordu.
      expect(acilan, isNotNull, reason: 'siparisId detay sheet\'ine devredilmeli');
      expect(gidilen, isEmpty, reason: 'sekme geçişini kabuk detayla birlikte yapar');

      await kapat(tester);
    });
  });

  group('Son Arama kutusu — s-ana.jsx:45', () {
    Future<void> anaEkraniKur(
      WidgetTester tester,
      AppDatabase db, {
      required List<AramaKaydi> yakalanan,
    }) =>
        ekranaKoy(
          tester,
          AnaEkran(
            db: db,
            sahipAdi: 'Bayi',
            onMenu: () {},
            onSekme: (_) {},
            onYeniSiparis: () {},
            onBorclular: () {},
            onArama: yakalanan.add,
            onSiparisAc: (_) {},
          ),
        );

    testWidgets('kayıtlı numarada müşteri ADI, kayıtsızda numara yazılır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CustomerRepository(db).create(
          name: 'Ayşe Yılmaz',
          phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)],
        );
        // Kayıtsız önce, kayıtlı sonra → kutu EN SON aramayı (kayıtlıyı) gösterir.
        final log = CallLogRepository(db);
        await log.log(phoneE164: '+905559998877', direction: CallDirection.missed);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await log.log(phoneE164: '+905321112233', direction: CallDirection.incoming);
      });

      final yakalanan = <AramaKaydi>[];
      await anaEkraniKur(tester, db, yakalanan: yakalanan);

      expect(find.text('Son Arama'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget,
          reason: 'kayıtlı numarada ad baskın gösterilir (tasarım: ad || no)');
      expect(find.textContaining('gelen · '), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('cevapsız arama "cevapsız" yazar; kayıtsız numara biçimlenmiş gösterilir',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CallLogRepository(db)
            .log(phoneE164: '+905324152290', direction: CallDirection.missed);
      });

      final yakalanan = <AramaKaydi>[];
      await anaEkraniKur(tester, db, yakalanan: yakalanan);

      expect(find.text(sipTelefon('+905324152290')), findsOneWidget);
      expect(find.textContaining('cevapsız · '), findsOneWidget);

      // CEVAPSIZ ALT SATIRI KIRMIZI. `Sipario.html`de `.bento-alt.eksi` kuralı yok ama
      // `s-ana.jsx:48` sınıfı koşullu ekliyor; lead kararı (2026-07-26): eksik kural, tercih
      // değil — cevapsız çağrı "kaçırılmış sipariş"tir, dikkat çekmelidir.
      // Bu test o kararı kilitler: "CSS'te yok" denip sessizce geri alınmasın.
      final cevapsizSatiri =
          tester.widget<Text>(find.textContaining('cevapsız · '));
      expect(cevapsizSatiri.style?.color, SipTokens.acik.danger);

      await kapat(tester);
    });

    testWidgets('cevapsız DEĞİLSE alt satır sönük kalır (kırmızı yalnız cevapsıza ait)',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CallLogRepository(db)
            .log(phoneE164: '+905324152290', direction: CallDirection.incoming);
      });

      final yakalanan = <AramaKaydi>[];
      await anaEkraniKur(tester, db, yakalanan: yakalanan);

      final gelenSatiri = tester.widget<Text>(find.textContaining('gelen · '));
      expect(gelenSatiri.style?.color, isNot(SipTokens.acik.danger));

      await kapat(tester);
    });

    testWidgets('hiç arama yoksa kutu sönük çizilir ve dokunma bir şey yapmaz',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final yakalanan = <AramaKaydi>[];
      await anaEkraniKur(tester, db, yakalanan: yakalanan);

      expect(find.text('Son Arama'), findsOneWidget);
      expect(find.text('henüz arama yok'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      await tester.tap(find.text('Son Arama'));
      await tester.pump();
      expect(yakalanan, isEmpty, reason: 'uydurma numarayla çağrı kartı açılmaz');

      await kapat(tester);
    });

    testWidgets('kutuya dokununca kaydı olduğu gibi kabuğa devreder', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CallLogRepository(db)
            .log(phoneE164: '+905559998877', direction: CallDirection.incoming);
      });

      final yakalanan = <AramaKaydi>[];
      await anaEkraniKur(tester, db, yakalanan: yakalanan);

      await tester.tap(find.text('Son Arama'));
      await tester.pump();

      expect(yakalanan.single.numara, '+905559998877');
      expect(yakalanan.single.kayitli, isFalse,
          reason: 'kayıtsız → kabuk çağrı kartını açacak (kararı ekran vermez)');

      await kapat(tester);
    });
  });

  // Tasarım (`s-uygulama.jsx`) `useState('siparis')` ile açar; bu BİLİNÇLİ SAPMADIR
  // (kullanıcı kararı, 2026-07-26). Test bu yüzden var: tasarımı kaynak alan bir denetim
  // bunu "gerileme" sanıp sipariş sekmesine geri çevirebilir.
  group('Kabuk açılış sekmesi', () {
    testWidgets('uygulama ANA ekranla açılır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(
        tester,
        HomeShell(
          db: db,
          session: Session(db),
          sync: SyncService(db), // start() çağrılmaz: ağ/timer yok
          onLoggedOut: () {},
        ),
      );

      expect(find.byType(AnaEkran), findsOneWidget,
          reason: 'açılış sekmesi Ana olmalı');
      // Seçili sekme etiketini AÇAR (CSS `.altnav-b span`), diğerleri ikon-only kalır.
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Sipariş'), findsNothing);

      await kapat(tester);
    });
  });

  group('Senkron çipi — hatanın CİNSİNİ söyler', () {
    // Cihaz doğrulamasında yakalandı (2026-08-05): bant "Sunucu yanıt veremiyor" derken çip
    // AYNI ekranda "Bağlantı yok" diyordu — o an bağlantı vardı. Çip tüm hataları tek metne
    // indirgiyordu; aynı ekranın iki farklı hikâye anlatması kullanıcıyı telefonunu
    // kurcalamaya yollar. Çip kısa kalır ama bandın AYRIMLARINI paylaşır.

    Future<void> cipiKur(WidgetTester tester, AppDatabase db, SyncOutcome sonuc) => ekranaKoy(
          tester,
          AnaEkran(
            db: db,
            sahipAdi: 'Mehmet Usta',
            onMenu: () {},
            onSekme: (_) {},
            onYeniSiparis: () {},
            onBorclular: () {},
            onArama: (_) {},
            onSiparisAc: (_) {},
            sonSenkron: sonuc,
          ),
        );

    testWidgets('sunucu hatasında "Bağlantı yok" GEÇMEZ', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await cipiKur(
        tester,
        db,
        const SyncOutcome(ok: false, error: '5xx', tur: SyncHataTuru.sunucu),
      );

      expect(find.text('Bağlantı yok · tekrar denenecek'), findsNothing,
          reason: 'sunucuya ULAŞILDI — "bağlantı yok" demek yalan');
      expect(find.text('Sunucu yanıt vermiyor · tekrar denenecek'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('veri hatasında bekleme sözü VERİLMEZ', (tester) async {
      // `veri` beklemekle geçmez; "tekrar denenecek" yazmak tutulamayacak bir sözdür.
      final db = AppDatabase(NativeDatabase.memory());
      await cipiKur(
        tester,
        db,
        const SyncOutcome(ok: false, error: 'red', tur: SyncHataTuru.veri),
      );

      expect(find.text('Kayıtlar gönderilemiyor · destekle görüşün'), findsOneWidget);
      expect(find.textContaining('tekrar denenecek'), findsNothing);

      await kapat(tester);
    });

    testWidgets('ağ hatasında metin DEĞİŞMEDİ (doğru olduğu tek hâl)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await cipiKur(
        tester,
        db,
        const SyncOutcome(ok: false, error: 'ağ', tur: SyncHataTuru.ag),
      );

      expect(find.text('Bağlantı yok · tekrar denenecek'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('başarılı tur ve ilk açılış metinleri KORUNDU', (tester) async {
      // Ekran metni sözleşmedir: bu iki metne dokunulmadı.
      final db = AppDatabase(NativeDatabase.memory());
      await cipiKur(tester, db, const SyncOutcome(ok: true));
      expect(find.textContaining('Senkron güncel'), findsOneWidget);
      await kapat(tester);

      final db2 = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(
        tester,
        AnaEkran(
          db: db2,
          sahipAdi: 'Mehmet Usta',
          onMenu: () {},
          onSekme: (_) {},
          onYeniSiparis: () {},
          onBorclular: () {},
          onArama: (_) {},
          onSiparisAc: (_) {},
        ),
      );
      expect(find.text('Senkron bekleniyor'), findsOneWidget);
      await kapat(tester);
    });
  });
}
