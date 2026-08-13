// MÜŞTERİ SİLME + KARA LİSTE (2026-08-01).
//
// İki eylem BİRBİRİNİN YERİNE GEÇMEZ ve bu dosyanın asıl işi o ayrımı kilitlemektir:
//  • Sil  → müşteri listeden DÜŞER (tombstone), geçmiş kayıtlarda adı durur.
//  • Kara liste → müşteri listede KALIR, rozet taşır, yalnız yeni sipariş açılamaz.
//
// Kara listenin listede kalması bilinçlidir: bayi ödemeyen müşteriyi gözden kaybetmek istemez,
// borcunu takip etmek ister. Rozeti "gizleme" yönünde değiştiren bir düzenleme bu testleri kırar.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/customers/customer_list_screen.dart';
import 'package:sipario/screens/customers/kara_liste.dart';
import 'package:sipario/screens/orders/order_form_screen.dart';
import 'package:sipario/screens/team.dart';

import 'support/siparis_yardimci.dart';
import 'support/yetki_yardimcilari.dart';

void main() {
  group('yetkiler() — müşteri yönetimi rol kapısı', () {
    test('patron ve operator müşteri yönetebilir', () {
      expect(yetkiler(rol: 'patron', kuryeVar: true).musteriYonetimi, isTrue);
      expect(yetkiler(rol: 'operator', kuryeVar: false).musteriYonetimi, isTrue);
    });

    test('kurye müşteri YÖNETEMEZ — silmek/kara listelemek bayinin ticari kararıdır', () {
      expect(yetkiler(rol: 'kurye', kuryeVar: true).musteriYonetimi, isFalse);
    });

    test('rol bilinmiyorsa yetki YOK (permissive değil — K2 sözleşmesi)', () {
      expect(yetkiler(rol: null, kuryeVar: false).musteriYonetimi, isFalse);
    });
  });

  group('karaListede() — saf yüklem', () {
    test('damga doluysa kara listede, boşsa değil', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await CustomerRepository(db).create(name: 'Test');
      final once = await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
      expect(karaListede(once), isFalse);

      await CustomerRepository(db).karaListe(id, ekle: true);
      final sonra = await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
      expect(karaListede(sonra), isTrue);
    });

    test('müşteri yoksa kara listede DEĞİLDİR (null güvenli)', () {
      expect(karaListede(null), isFalse);
    });
  });

  group('CustomerRepository — kara liste ve silme', () {
    test('kara listeye alma damgayı yazar, çıkarma temizler', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = CustomerRepository(db);
      final id = await repo.create(name: 'Borçlu Müşteri');

      await repo.karaListe(id, ekle: true);
      var c = await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
      expect(c.blacklistedAt, isNotNull);
      expect(c.deletedAt, isNull, reason: 'kara liste SİLME DEĞİLDİR');

      await repo.karaListe(id, ekle: false);
      c = await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
      expect(c.blacklistedAt, isNull);
    });

    test('kara liste outbox olayı customer upsert olarak çıkar ve damgayı taşır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = CustomerRepository(db);
      final id = await repo.create(name: 'Ahmet');
      await repo.karaListe(id, ekle: true);

      final olaylar = await db.select(db.outbox).get();
      final sonuncu = olaylar.last;
      expect(sonuncu.entityType, 'customer');
      expect(sonuncu.op, 'upsert', reason: 'kara liste ayrı bir op DEĞİL, müşterinin bir alanı');
      expect(sonuncu.payload, contains('blacklisted_at'));
      expect(sonuncu.payload, contains('Ahmet'), reason: 'LWW tam satır uygular — ad da gitmeli');
    });

    test('AD DÜZENLEMEK KARA LİSTEYİ KALDIRMAZ — payload damgayı geri gönderir', () async {
      // Sunucu `customer` upsert'ini TAM SATIR olarak uygular: payload'da olmayan alan null
      // yazılır. rename() damgayı okuyup geri göndermeseydi, yalnız adı düzeltmek müşteriyi
      // sessizce kara listeden çıkarırdı.
      final db = AppDatabase(NativeDatabase.memory());
      final repo = CustomerRepository(db);
      final id = await repo.create(name: 'Eski Ad');
      await repo.karaListe(id, ekle: true);

      await repo.rename(id, name: 'Yeni Ad', note: 'not');

      final c = await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
      expect(c.blacklistedAt, isNotNull, reason: 'yerel satır kara listede kalmalı');

      final sonuncu = (await db.select(db.outbox).get()).last;
      expect(sonuncu.payload, contains('blacklisted_at'));
      expect(
        sonuncu.payload.contains('"blacklisted_at":null'),
        isFalse,
        reason: 'düzenleme payload\'ı damgayı null göndermemeli',
      );
    });

    test('silme müşteriyi listeden düşürür ama satır DURUR (tombstone)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = CustomerRepository(db);
      final id = await repo.create(name: 'Silinecek');

      await repo.archive(id);

      final c = await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
      expect(c.deletedAt, isNotNull, reason: 'silme fiziksel değildir');

      final liste = await watchCustomers(db, '').first;
      expect(liste, isEmpty, reason: 'silinen müşteri listede görünmez');
    });

    test('kara listedeki müşteri LİSTEDE KALIR — borcu takip edilebilmeli', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = CustomerRepository(db);
      final id = await repo.create(name: 'Kara Listelik');
      await repo.karaListe(id, ekle: true);

      final liste = await watchCustomers(db, '').first;
      expect(liste.map((c) => c.name), contains('Kara Listelik'));
    });
  });

  group('Müşteriler listesi — kara liste rozeti', () {
    testWidgets('kara listedeki müşteride rozet çizilir, temizde çizilmez', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final repo = CustomerRepository(db);
        final kara = await repo.create(name: 'Kara Listelik');
        await repo.karaListe(kara, ekle: true);
        await repo.create(name: 'Temiz Müşteri');
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerListScreen(db: db, writable: true, yetki: tamYetki)));
      await akisiBekle(tester);

      expect(find.text('Kara Listelik'), findsOneWidget);
      expect(find.text('Temiz Müşteri'), findsOneWidget);
      expect(find.text(karaListeRozeti), findsOneWidget,
          reason: 'rozet YALNIZ kara listedeki satırda');

      await ekraniKapat(tester);
    });

    testWidgets('silinen müşteri listede hiç görünmez', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final repo = CustomerRepository(db);
        final id = await repo.create(name: 'Silinen Müşteri');
        await repo.create(name: 'Kalan Müşteri');
        await repo.archive(id);
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerListScreen(db: db, writable: true, yetki: tamYetki)));
      await akisiBekle(tester);

      expect(find.text('Kalan Müşteri'), findsOneWidget);
      expect(find.text('Silinen Müşteri'), findsNothing);

      await ekraniKapat(tester);
    });
  });

  group('Müşteri detayı — tehlikeli işlemler', () {
    Future<(AppDatabase, String)> kur({bool karaListe = false, int borcKurus = 0}) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = CustomerRepository(db);
      final id = await repo.create(name: 'Ayşe Yılmaz');
      if (karaListe) await repo.karaListe(id, ekle: true);
      if (borcKurus != 0) {
        await (db.update(db.customers)..where((t) => t.id.equals(id)))
            .write(CustomersCompanion(balanceKurus: Value(borcKurus)));
      }
      return (db, id);
    }

    testWidgets('patronda sil ve kara listeye ekle görünür', (tester) async {
      late AppDatabase db;
      late String id;
      await tester.runAsync(() async => (db, id) = await kur());

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerDetailScreen(
        db: db,
        customerId: id,
        writable: true,
        yetki: yetkiler(rol: 'patron', kuryeVar: false),
      )));
      await akisiBekle(tester);

      expect(find.text(musteriyiSilEtiketi), findsOneWidget);
      expect(find.text(karaListeyeEkleEtiketi), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('KURYEDE tehlikeli işlemler HİÇ ÇİZİLMEZ', (tester) async {
      // Düğmeyi gösterip reddetmek kuryeye olmayan bir rol teklif ederdi.
      late AppDatabase db;
      late String id;
      await tester.runAsync(() async => (db, id) = await kur());

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerDetailScreen(
        db: db,
        customerId: id,
        writable: true,
        yetki: yetkiler(rol: 'kurye', kuryeVar: true),
      )));
      await akisiBekle(tester);

      expect(find.text('Ayşe Yılmaz'), findsWidgets, reason: 'ekran açıldı');
      expect(find.text(musteriyiSilEtiketi), findsNothing);
      expect(find.text(karaListeyeEkleEtiketi), findsNothing);
      expect(find.text(karaListedenCikarEtiketi), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('kara listedeyken etiket ÇIKAR olur ve rozet görünür', (tester) async {
      late AppDatabase db;
      late String id;
      await tester.runAsync(() async => (db, id) = await kur(karaListe: true));

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerDetailScreen(
        db: db,
        customerId: id,
        writable: true,
        yetki: RolYetkileri.tumu,
      )));
      await akisiBekle(tester);

      expect(find.text(karaListedenCikarEtiketi), findsOneWidget);
      expect(find.text(karaListeyeEkleEtiketi), findsNothing);
      expect(find.text(karaListeRozeti), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('kara listeye ekle dokunuşu damgayı yazar ve etiketi çevirir', (tester) async {
      late AppDatabase db;
      late String id;
      await tester.runAsync(() async => (db, id) = await kur());

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerDetailScreen(
        db: db,
        customerId: id,
        writable: true,
        yetki: RolYetkileri.tumu,
      )));
      await akisiBekle(tester);

      await tester.tap(find.text(karaListeyeEkleEtiketi));
      await akisiBekle(tester);

      final c = await tester.runAsync(() async =>
          (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle());
      expect(c!.blacklistedAt, isNotNull);
      expect(find.text(karaListedenCikarEtiketi), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('silme ONAY ister; vazgeçilince müşteri DURUR', (tester) async {
      late AppDatabase db;
      late String id;
      await tester.runAsync(() async => (db, id) = await kur());

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerDetailScreen(
        db: db,
        customerId: id,
        writable: true,
        yetki: RolYetkileri.tumu,
      )));
      await akisiBekle(tester);

      await tester.tap(find.text(musteriyiSilEtiketi));
      await akisiBekle(tester);
      expect(find.text('Ayşe Yılmaz silinsin mi?'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await akisiBekle(tester);

      final c = await tester.runAsync(() async =>
          (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle());
      expect(c!.deletedAt, isNull, reason: 'vazgeçmek silmemelidir');

      await ekraniKapat(tester);
    });

    testWidgets('borçlu müşterinin silme onayında tutar YAZAR', (tester) async {
      // Silmek borcu silmez (defter append-only) ama müşteri listeden düşeceği için bayi o
      // borcu bir daha kendiliğinden görmez — uyarı tam olarak bunu söylemeli.
      late AppDatabase db;
      late String id;
      await tester.runAsync(() async => (db, id) = await kur(borcKurus: 12550));

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerDetailScreen(
        db: db,
        customerId: id,
        writable: true,
        yetki: RolYetkileri.tumu,
      )));
      await akisiBekle(tester);

      await tester.tap(find.text(musteriyiSilEtiketi));
      await akisiBekle(tester);

      // Çıplak tutar ARANMAZ: detay ekranındaki "125,50 ₺ Borç" rozeti de eşleşir ve iki widget
      // bulunur (tam koşuda görüldü). Aranan, DİYALOĞUN kendi cümlesindeki tutardır.
      expect(find.textContaining('125,50 ₺ borcu var'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('onaylanınca müşteri silinir', (tester) async {
      late AppDatabase db;
      late String id;
      await tester.runAsync(() async => (db, id) = await kur());

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerDetailScreen(
        db: db,
        customerId: id,
        writable: true,
        yetki: RolYetkileri.tumu,
      )));
      await akisiBekle(tester);

      await tester.tap(find.text(musteriyiSilEtiketi));
      await akisiBekle(tester);
      await tester.tap(find.text('Sil'));
      await akisiBekle(tester);

      final c = await tester.runAsync(() async =>
          (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle());
      expect(c!.deletedAt, isNotNull);

      await ekraniKapat(tester);
    });
  });

  group('Sipariş engeli', () {
    testWidgets('detaydaki Sipariş kısayolu kara listede DURUR ve gerekçe yazar', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String id;
      await tester.runAsync(() async {
        final repo = CustomerRepository(db);
        id = await repo.create(name: 'Ayşe Yılmaz');
        await repo.karaListe(id, ekle: true);
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(CustomerDetailScreen(
        db: db,
        customerId: id,
        writable: true,
        yetki: RolYetkileri.tumu,
      )));
      await akisiBekle(tester);

      await tester.tap(find.text('Sipariş'));
      await akisiBekle(tester);

      expect(find.text(karaListeSiparisMesaji('Ayşe Yılmaz')), findsOneWidget);
      expect(find.byType(OrderFormScreen), findsNothing, reason: 'form hiç açılmamalı');

      await ekraniKapat(tester);
    });

    testWidgets('sipariş formunda kara listedeki müşteri SEÇİLEMEZ', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final repo = CustomerRepository(db);
        final kara = await repo.create(name: 'Kara Listelik');
        await repo.karaListe(kara, ekle: true);
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.text('Kara Listelik'));
      await akisiBekle(tester);

      expect(find.text(karaListeSiparisMesaji('Kara Listelik')), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('temiz müşteride sipariş akışı ENGELLENMEZ', (tester) async {
      // Engelin fazla geniş olmadığını kanıtlar: kara liste kontrolü yanlışlıkla herkesi
      // durdursaydı bu test yakalar.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CustomerRepository(db).create(name: 'Temiz Müşteri');
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.text('Temiz Müşteri'));
      await akisiBekle(tester);

      expect(find.textContaining('kara listede'), findsNothing);

      await ekraniKapat(tester);
    });
  });
}
