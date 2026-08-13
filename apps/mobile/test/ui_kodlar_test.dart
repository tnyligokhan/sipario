// SIRA KODLARI + BEKLEME SÜRESİ — kullanıcı isteği 2026-07-29.
//
// Üç istek:
//  1. Müşteriler ekranında ad'ın başında müşteri kodu (100, 101, 102 — "M100" DEĞİL).
//  2. Her siparişin bir kodu (#248); satırda hangi kodun görüneceği bayi ayarı.
//  3. Açık siparişte "Açık" yazısı yerine siparişin kaç dakikadır beklediği.
//
// Kodlar SUNUCU tarafından atanır (bkz. `Customers.code`), bu yüzden yerel veritabanına koşan
// testlerde kod ancak elle yazıldığında vardır — bu dosya iki durumu da sınar: kod varken ve
// kod yokken (senkronlanmamış kayıt).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/tenant_settings_repository.dart';
import 'package:sipario/screens/customers/customer_list_screen.dart';
import 'package:sipario/screens/orders/gecen_sure_pili.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';

import 'support/siparis_yardimci.dart';
import 'support/yetki_yardimcilari.dart';

void main() {
  group('gecenSure — açık siparişin bekleme süresi', () {
    final t0 = DateTime(2026, 7, 29, 10, 0);
    String olc(Duration d) =>
        gecenSure(t0.toIso8601String(), simdi: t0.add(d));

    test('1 dakikadan yeni sipariş "yeni" der', () {
      // "0 dk" yazmak siparişin daha girilmediğini düşündürür.
      expect(olc(const Duration(seconds: 5)), 'yeni');
      expect(olc(const Duration(seconds: 59)), 'yeni');
    });

    test('bir saate kadar dakika', () {
      expect(olc(const Duration(minutes: 1)), '1 dk');
      expect(olc(const Duration(minutes: 42)), '42 dk');
      expect(olc(const Duration(minutes: 59)), '59 dk');
    });

    test('bir saatten sonra saat + dakika — ilk gün dakika ÖNEMLİDİR', () {
      // 1 sa 5 dk ile 1 sa 55 dk arasındaki fark, bayinin müşteriyi arayıp aramayacağını
      // belirler; saate yuvarlamak o kararı görünmez yapardı.
      expect(olc(const Duration(hours: 1, minutes: 5)), '1 sa 5 dk');
      expect(olc(const Duration(hours: 1)), '1 sa');
      expect(olc(const Duration(hours: 23, minutes: 59)), '23 sa 59 dk');
    });

    test('bir günden sonra gün', () {
      expect(olc(const Duration(hours: 24)), '1 gün');
      expect(olc(const Duration(days: 3, hours: 5)), '3 gün');
    });

    test('İLERİ tarihli damga "yeni" sayılır — eksi süre yazılmaz', () {
      // Cihaz saati ileri kaymış olabilir; "−3 dk" yazmak veriye güveni sarsar.
      expect(olc(const Duration(minutes: -10)), 'yeni');
    });

    test('çözümlenemeyen damga boş döner, ÇÖKMEZ', () {
      expect(gecenSure('bozuk-tarih'), '');
    });
  });

  group('Kod rozetleri — saf kural', () {
    test('müşteri kodu düz sayıdır (M ÖNEKİ YOK)', () {
      // Kullanıcı isteği birebir: "m100 değil 100 101 102 gibi".
      expect(musteriKodu(102), '102');
      expect(siparisKodu(248), '#248');
    });

    test('kod yoksa null — uydurma numara BASILMAZ', () {
      // Senkronlanmamış kayıtta kod henüz yoktur; "0" ya da "M-000" yazmak var olmayan bir
      // numarayla anmak olurdu.
      expect(musteriKodu(null), isNull);
      expect(siparisKodu(null), isNull);
    });

    test('tercih satırda hangi kodun görüneceğini seçer', () {
      expect(satirKodu(tercih: 'musteri', musteriCode: 102, siparisCode: 248), '102');
      expect(satirKodu(tercih: 'siparis', musteriCode: 102, siparisCode: 248), '#248');
    });

    test('tanınmayan tercih MÜŞTERİ koduna düşer (sunucudaki beyaz listenin aynısı)', () {
      expect(satirKodu(tercih: 'uydurma', musteriCode: 102, siparisCode: 248), '102');
    });

    test('seçilen kod yoksa DİĞERİNE düşülür', () {
      // Tezgâh satışında müşteri yoktur; satırı numarasız bırakmaktansa sipariş kodu yazılır.
      expect(satirKodu(tercih: 'musteri', musteriCode: null, siparisCode: 248), '#248');
      expect(satirKodu(tercih: 'siparis', musteriCode: 102, siparisCode: null), '102');
      expect(satirKodu(tercih: 'musteri', musteriCode: null, siparisCode: null), isNull);
    });
  });

  group('Müşteriler ekranı — kod adın başında', () {
    testWidgets('kodu olan müşteride kod, olmayanda yalnız ad çizilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final kodlu = await CustomerRepository(db).create(name: 'Kodlu Müşteri');
        await (db.update(db.customers)..where((t) => t.id.equals(kodlu)))
            .write(const CustomersCompanion(code: Value(102)));
        await CustomerRepository(db).create(name: 'Kodsuz Müşteri');
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerListScreen(db: db, writable: true, yetki: tamYetki)));
      await akisiBekle(tester);

      expect(find.text('102'), findsOneWidget);
      expect(find.text('Kodlu Müşteri'), findsOneWidget);
      expect(find.text('Kodsuz Müşteri'), findsOneWidget);
      expect(find.textContaining('M-'), findsNothing, reason: 'eski sahte kod biçimi gitti');

      await ekraniKapat(tester);
    });
  });

  group('Sipariş satırı — kod tercihi', () {
    Future<AppDatabase> kur() async {
      final db = AppDatabase(NativeDatabase.memory());
      final cid = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      await (db.update(db.customers)..where((t) => t.id.equals(cid)))
          .write(const CustomersCompanion(code: Value(102)));
      final oid = await OrderRepository(db).create(
        customerId: cid,
        lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1)],
      );
      await (db.update(db.orders)..where((t) => t.id.equals(oid)))
          .write(const OrdersCompanion(code: Value(248)));
      return db;
    }

    testWidgets('varsayılan MÜŞTERİ kodu gösterir', (tester) async {
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur());

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.text('102'), findsOneWidget);
      expect(find.text('#248'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('ayar "siparis" olunca SİPARİŞ kodu gösterir', (tester) async {
      late AppDatabase db;
      await tester.runAsync(() async {
        db = await kur();
        await TenantSettingsRepository(db).siparisKoduTercihiKaydet('siparis');
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.text('#248'), findsOneWidget);
      expect(find.text('102'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('tercih değişikliği SUNUCUYA da gider (outbox)', (tester) async {
      // Ayar kiracı düzeyindedir: yalnız cihaza yazılsaydı ikinci telefon eski tercihi
      // gösterirdi. Ayrıca profil alanları KORUNMALI — LWW upsert satırı payload'la değiştirir.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final repo = TenantSettingsRepository(db);
        await repo.save(businessName: 'Öz Pınar Su', phone: '02422222222');
        await repo.siparisKoduTercihiKaydet('siparis');

        final kuyruk = await db.select(db.outbox).get();
        final son = kuyruk.last;
        expect(son.entityType, 'tenant_settings');
        expect(son.payload, contains('"order_code_display":"siparis"'));
        expect(son.payload, contains('Öz Pınar Su'),
            reason: 'profil alanları tercih yazımında KAYBOLMAMALI');

        final ayar = await repo.get();
        expect(ayar?.orderCodeDisplay, 'siparis');
        expect(ayar?.businessName, 'Öz Pınar Su');
      });
    });
  });

  group('Bekleme süresi pili — kendiliğinden ilerler', () {
    testWidgets('paylaşılan tikleyici pilleri tazeler', (tester) async {
      // Süre kendiliğinden ilerlemezse "3 dk" yazan bir sipariş ekran yeniden çizilene kadar
      // öyle kalır — yani YANLIŞ bilgi verir (Drift akışı veri değişmedikçe tik yayınlamaz).
      SureTikleyici.zamanlayiciAcik = false; // sahte zamanda gerçek Timer testi düşürür
      addTearDown(() => SureTikleyici.zamanlayiciAcik = true);

      // Zaman ELLE kurulur: pil paylaşılan tikleyicinin DEĞERİNİ okur ve o değer en fazla
      // 60 sn eski olabilir (tik aralığı). `DateTime.now()` ile karşılaştıran bir test, o
      // saniyeler yüzünden "3 dk" yerine "2 dk" görüp rastgele kırılırdı.
      final simdi = DateTime(2026, 7, 29, 10, 0);
      SureTikleyici.ornek.tiklat(simdi);
      final acilis = simdi.subtract(const Duration(minutes: 3));

      genisYuzey(tester);
      await tester.pumpWidget(
          sipKabuk(GecenSurePili(occurredAt: acilis.toIso8601String())));
      await tester.pump();
      expect(find.text('3 dk'), findsOneWidget);

      SureTikleyici.ornek.tiklat(simdi.add(const Duration(minutes: 5)));
      await tester.pump();
      expect(find.text('8 dk'), findsOneWidget, reason: 'tik gelince süre ilerlemeli');

      await ekraniKapat(tester);
    });
  });
}
