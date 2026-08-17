// ROTA KONUMU + SİPARİŞ HARİTASI (kullanıcı isteği 2026-07-29).
//
// İki iş, tek dert: "Oto Sırala" nereden başlıyor ve o sıra yeryüzünde neye benziyor?
//
//  A. Oto sıralama kuryenin BULUNDUĞU noktadan başlar (`start`). Konum alınamazsa istek yine
//     gider ama kullanıcıya HANGİ KİPTE sıralandığı söylenir — sessiz bozulma yasak.
//  B. Harita ekranı açık siparişleri rota sırasında numaralı pinlerle çizer.
//
// Bu dosyadaki widget testleri AĞA ve PLATFORM KANALINA hiç uzanmaz: `cihazKonumuOku`,
// `rotaApiUret` ve `haritaKaroSaglayici` dikişleri sahtelenir. Sızan bir sahte bir sonraki testte
// sessizce yanlış sonuç üretir — üçü de tearDown'da geri alınır.


import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/tenant_settings_repository.dart';
import 'package:sipario/screens/orders/harita_sorgulari.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';

import 'support/siparis_yardimci.dart';


/// HARİTA VERİSİ — `watchHaritaDuraklari` ve hata görünürlüğü.
///
/// Bölme gerekçesi: `ui_siparis_harita_test.dart` başlığı.
void main() {
  group('watchHaritaDuraklari', () {
    test('birincil adres koordinatsızsa sipariş KONUMSUZ sayılır', () async {
      // İkincil adrese düşmek, kullanıcının listede gördüğü adresin dışında bir kapıya pin
      // koymak olurdu — harita ile liste ayrışır.
      final db = AppDatabase(NativeDatabase.memory());
      final cid = await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        addresses: [
          AddressInput(addressText: 'Birincil — konumsuz', isPrimary: true),
          AddressInput(addressText: 'İkincil — konumlu', lat: 36.9, lng: 30.7),
        ],
      );
      await OrderRepository(db).create(customerId: cid, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);

      final veri = await watchHaritaDuraklari(db).first;

      expect(veri.duraklar, isEmpty);
      expect(veri.konumsuz, 1);
      await db.close();
    });

    test('kod rozeti bayi TERCİHİNİ izler (liste satırıyla tek kural)', () async {
      // Harita başka bir numara gösterseydi bayi aynı siparişi iki farklı kodla anardı.
      final db = AppDatabase(NativeDatabase.memory());
      final cid = await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        addresses: [
          AddressInput(addressText: 'Bahçe Sk.', lat: 36.9, lng: 30.7, isPrimary: true),
        ],
      );
      final oid = await OrderRepository(db).create(customerId: cid, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      // Kodlar SUNUCUDAN gelir (yerelde üretilmez) — senkron sonrası hâli elle kurulur.
      await (db.update(db.customers)..where((t) => t.id.equals(cid)))
          .write(const CustomersCompanion(code: Value(102)));
      await (db.update(db.orders)..where((t) => t.id.equals(oid)))
          .write(const OrdersCompanion(code: Value(248)));

      expect((await watchHaritaDuraklari(db).first).duraklar.single.kod, '102');

      await TenantSettingsRepository(db).siparisKoduTercihiKaydet('siparis');
      expect((await watchHaritaDuraklari(db).first).duraklar.single.kod, '#248');

      await db.close();
    });

    test('duraklar sort_index sırasında döner (oto sıralamanın rota sırası)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = OrderRepository(db);
      final idler = <String>[];
      for (final ad in ['Bir', 'İki', 'Üç']) {
        final cid = await CustomerRepository(db).create(
          name: ad,
          addresses: [
            AddressInput(addressText: '$ad sokağı', lat: 36.9, lng: 30.7, isPrimary: true),
          ],
        );
        idler.add(await repo.create(customerId: cid, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]));
      }
      // Rota sırası listenin yazılma sırasının TERSİ olsun ki sıra gerçekten okunuyor mu görelim.
      await repo.setSortIndex(idler[0], 20);
      await repo.setSortIndex(idler[1], 10);
      await repo.setSortIndex(idler[2], 0);

      final veri = await watchHaritaDuraklari(db).first;

      expect([for (final d in veri.duraklar) d.baslik], ['Üç', 'İki', 'Bir']);
      expect(veri.konumsuz, 0);
      await db.close();
    });
  });

  // ── HATA GÖRÜNÜRLÜĞÜ (2026-08-09 saha arızası) ────────────────────────────
  //
  // Saha raporu: "haritaya tıklıyorum, yükleniyorda kalıyor". Kök neden ekranın kendisiydi:
  // `StreamBuilder` YALNIZ `snap.data`ya bakıyordu, `snap.hasError`a değil. Sorgu patlayınca
  // `veri` sonsuza dek null kalıyor ve iskelet donuyordu — kullanıcı bekliyor, sebep hiçbir
  // yerde görünmüyor. Bu depoda defalarca bedel ödetilen SESSİZ ARIZA sınıfı.
  //
  // Test gerçek senaryoyu taklit eder: şema uyumsuzluğu (tablo yok) → sorgu SQL hatası verir.
  group('harita hata görünürlüğü', () {
    testWidgets('sorgu patlarsa sonsuz iskelet DEĞİL, hata gösterilir', (tester) async {
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async {
        db = AppDatabase(NativeDatabase.memory());
        // Şemayı kur, sonra haritanın join'lediği bir tabloyu DÜŞÜR: gerçek dünyada bu,
        // cihazdaki şemanın sunucu sürümünün gerisinde kalmasıdır.
        await db.select(db.customers).get();
        await db.customStatement('DROP TABLE customer_addresses');
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Başlık altı "Yükleniyor" DEĞİL, gövde iskelet DEĞİL.
      expect(find.text('Yükleniyor'), findsNothing,
          reason: 'hata varken "Yükleniyor" demek yalan söylemektir');
      expect(find.text('Yüklenemedi'), findsOneWidget);
      expect(find.text('Harita yüklenemedi'), findsOneWidget);

      await db.close();
    });
  });
}
