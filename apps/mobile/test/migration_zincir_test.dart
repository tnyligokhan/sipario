// `isNull` hem drift'te hem matcher'da tanımlı; burada matcher'ınki isteniyor.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';

import 'support/migration_yardimcilari.dart';

/// ZİNCİRLEME YÜKSELTME — "aylardır güncellenmemiş telefon bugün açılıyor".
///
/// NEDEN AYRI DOSYA, NEDEN TEK ADIMLIK TESTLER YETMİYOR: `migration_v14..v21` dosyalarının her
/// biri BİR adımı sınar (vN-1 → vN). Sahadaki cihaz ise adımları TEK SEFERDE koşar ve arıza tam
/// olarak adımların BİRLEŞİMİNDE doğar — bir adımın kendini-onarma kapısının hangi tarafında
/// durduğu, ancak "o kapıyı erken döndüren" bir başlangıç sürümüyle görünür.
///
/// Bu dosya üç gerçek başlangıç noktasını kurar:
///  • **v1** — Faz 0 sqflite kurulumu (en eski desteklenen hâl; native sözleşme oradan gelir),
///  • **v7** — `users` VAR, `tenant_settings` YOK (kapı geçer, `from < N` dalları koşar),
///  • **v8** — `tenant_settings` VAR (kapı ERKEN DÖNER, `from < N` dallarının HİÇBİRİ koşmaz).
///
/// Üçünün de sonunda [semaTamOlmali] çağrılır: yükseltilmiş şema, taze kurulmuş şemanın
/// tamamını içermek ZORUNDADIR. Bu karşılaştırma yazıldığında iki gerçek kusur buldu ve ikisi
/// de aynı vardiyada düzeltildi:
///  1. `users.username` — kolon eklendiğinde `onUpgrade`e ALTER'ı hiç yazılmamıştı. v6 ve
///     öncesinden gelen cihazlarda `createTable(users)` kolonu kendiliğinden kurduğu için
///     eksiklik görünmüyordu; v7+ damgalı cihazda `users`a dokunan HER sorgu patlardı.
///  2. `sync_meta.route_credits_monthly` — adım `if (from < 9)` dalındaydı, yani KAPININ
///     ARKASINDA. Kapı `tenant_settings` görünce erken döner ve o tablo tam olarak v8'de
///     doğar → v8 damgalı cihazda adım hiç koşmazdı.
void main() {
  test(
      'v1 (Faz 0) → bugün: phase0 verisi ve native sözleşmesi korunur, spike çöpü temizlenir, '
      'şema BUGÜNKÜNÜN TAMAMI olur ve sürüm damgası güncellenir', () async {
    final file = faz0V1DosyasiKur('zincir_v1', veriYaz: (raw) {
      raw.execute(
        "INSERT INTO customers (id,name,address,note,balance_kurus) "
        "VALUES ('0190f0f0-0000-7000-8000-000000000001','Faz0 Müşteri','Eski Adres',null,24000)",
      );
      raw.execute(
        "INSERT INTO customer_phones (id,customer_id,phone_e164,phone_last10,label,is_primary) "
        "VALUES ('p1','0190f0f0-0000-7000-8000-000000000001','+905321112233','5321112233','cep',1)",
      );
      // Kaldırılmış Faz 0 ekranının bıraktığı SAHTE kayıtlar (2026-07-22 bulgusu) — temizlenmeli.
      raw.execute(
        "INSERT INTO customers (id,name,address,note,balance_kurus) "
        "VALUES ('c-1700000000','Saha Testi',null,null,0)",
      );
    });

    final db = dosyayiAc(file);

    // Native arayan-tanıma sözleşmesi ve PARA korunur (additif migration kuralı).
    final musteri = await (db.select(db.customers)
          ..where((t) => t.id.equals('0190f0f0-0000-7000-8000-000000000001')))
        .getSingle();
    expect(musteri.name, 'Faz0 Müşteri');
    expect(musteri.balanceKurus, 24000);
    expect(
        (await (db.select(db.customerPhones)..where((t) => t.id.equals('p1'))).getSingle())
            .phoneLast10,
        '5321112233');

    // NOT NULL LWW kolonu eski satıra ESKİ damgayla eklenir → herhangi bir sunucu güncellemesi
    // LWW'de kazanır. Bugünün damgasını yazsaydık, sunucudaki doğru kayıt yenilemeye çalışırken
    // "daha eski" sayılıp REDDEDİLİRDİ.
    expect(musteri.updatedOccurredAt, '1970-01-01T00:00:00.000Z');

    // Spike çöpü temizlendi (beforeOpen), gerçek kayıt durdu.
    expect(await (db.select(db.customers)..where((t) => t.id.equals('c-1700000000'))).get(), isEmpty);

    // ⭐ ZİNCİRİN ASIL İDDİASI: 20 adım sonunda şema BUGÜNKÜ şemanın tamamıdır.
    await semaTamOlmali(db, gerekce: 'v1 → bugün zinciri.');

    // Ve dosya bugünün sürümüyle damgalanır (aksi hâlde her açılışta migration yeniden koşar).
    final damga = await db.customSelect('PRAGMA user_version').getSingle();
    expect(damga.read<int>('user_version'), db.schemaVersion);
  });

  test(
      'v7 → bugün: `users` O SÜRÜMDE DOĞDUĞU için `createTable` yolu bir daha koşmaz — '
      'kolonlarının ALTER\'ı olmak ZORUNDADIR. Ekip verisi durur, `username` boş dizeyle gelir, '
      'kişiye özel yetkiler NULL (bayi varsayılanını devral) kalır', () async {
    final db = await tarihselCihaziYukselt(
      etiket: 'zincir_v7',
      surum: 7,
      tarihselSema: v7Semasi,
      onceDusurulecekIndeksler: v7Indeksleri,
      veriYaz: (v) async {
        // ⚠️ KİMLİK `c-` İLE BAŞLAYAMAZ: `beforeOpen`daki tek seferlik temizlik Faz 0'ın sahte
        // spike müşterilerini siler ve deseni `id LIKE 'c-%'`dir. `c-1` yazıldığında bu satır
        // yükseltmeden SAĞ ÇIKIYOR ama açılışta siliniyordu — test "veri kayboldu" diye
        // kırmızı yanar, oysa kaybeden ürün değil testin kendi kimliğiydi. Depodaki öteki göç
        // testleri de bu yüzden `v7-c1` biçimini kullanır.
        await v.into(v.customers).insert(CustomersCompanion.insert(
              id: 'v7-c1',
              name: 'Saha Müşterisi',
              balanceKurus: const Value(31500),
              updatedOccurredAt: '2026-07-24T00:00:00.000Z',
            ));
        await v.into(v.users).insert(UsersCompanion.insert(
              id: 'u-1',
              name: 'Mehmet Kurye',
              role: 'kurye',
              status: 'active',
            ));
        await v.into(v.cashHandovers).insert(CashHandoversCompanion.insert(
              id: 'h-1',
              fromUserId: 'u-1',
              countedCashKurus: 88000,
              expectedCashKurus: 88000,
              diffKurus: 0,
              occurredAt: '2026-07-24T19:00:00.000Z',
            ));
      },
    );

    // ⭐ REGRESYON: `users` üzerinde herhangi bir sorgu. `username`in ALTER'ı yokken bu satır
    // `no such column: users.username` ile patlıyordu — Kuryeler ekranı, atama hedefi seçimi
    // ve senkronun `team` bloğunu uygulayan yazım komple ölürdü.
    final kurye = await (db.select(db.users)..where((t) => t.id.equals('u-1'))).getSingle();
    expect(kurye.name, 'Mehmet Kurye');
    expect(kurye.role, 'kurye');

    // Giriş adı BOŞ DİZE gelir: cihazda o kolon hiç yoktu, dolayısıyla taşınacak bir değer de
    // yok. Ekran onu "bilinmiyor" gösterir; ilk `team` bloğu gerçek değeri yazar.
    expect(kurye.username, '');
    expect(kurye.phone, isNull);

    // Kişiye özel yetkiler NULL = "bayi varsayılanını devral". Varsayılan yazsaydık sahadaki
    // her kurye yükseltme anındaki değere ÇAKILIR, bayi ayarı sonradan hiçbirine işlemezdi.
    expect(kurye.courierCanDiscount, isNull);
    expect(kurye.courierCanCollect, isNull);

    // Para ve müşteri verisi aynen durur.
    expect(
        (await (db.select(db.customers)..where((t) => t.id.equals('v7-c1'))).getSingle())
            .balanceKurus,
        31500);
    final devir = await (db.select(db.cashHandovers)..where((t) => t.id.equals('h-1'))).getSingle();
    expect(devir.countedCashKurus, 88000);
    expect(devir.reversesHandoverId, isNull);

    // v8'de doğan tablolar kuruldu ve bayi varsayılanları doğru geldi.
    await db.into(db.tenantSettings).insertOnConflictUpdate(
        const TenantSettingsCompanion(id: Value(1), businessName: Value('Öz Pınar')));
    final ayar = await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingle();
    expect(ayar.orderCodeDisplay, 'musteri');
    expect(ayar.courierCanCustomers, isTrue);
    expect(ayar.courierCanDiscount, isFalse);

    await semaTamOlmali(db, gerekce: 'v7 → bugün zinciri.');
  });

  test(
      'v8 → bugün: KAPI ERKEN DÖNER (`tenant_settings` v8\'de doğar), yani `from < N` dallarının '
      'hiçbiri koşmaz — kapıdan önce yazılmayan her adım bu cihazda ÖLÜDÜR. sync_meta okunabilir '
      'olmalı, yetki matrisi ve IBAN alanları eklenmiş olmalı, veri durmalı', () async {
    final db = await tarihselCihaziYukselt(
      etiket: 'zincir_v8',
      surum: 8,
      // İndeks düşürülmez: v8 cihazında üçü de VARDIR ve düşürülselerdi yükseltme onları geri
      // getirmezdi (createIndex çağrıları `from < 8` dalında, yani kapının arkasında).
      tarihselSema: v8Semasi,
      veriYaz: (v) async {
        await (v.update(v.syncMeta)..where((t) => t.id.equals(1))).write(const SyncMetaCompanion(
          lastPulledSeq: Value(1207),
          authToken: Value('bearer-v8'),
          tenantCode: Value('ASP-4213'),
          routeCredits: Value(34),
        ));
        // Kimlik `c-` ile başlayamaz — gerekçe v7 testinde yazılı (`beforeOpen` temizliği).
        await v.into(v.customers).insert(CustomersCompanion.insert(
              id: 'v8-c1',
              name: 'Eski Cihaz Müşterisi',
              balanceKurus: const Value(9900),
              updatedOccurredAt: '2026-07-25T00:00:00.000Z',
            ));
        await v.into(v.users).insert(UsersCompanion.insert(
              id: 'u-1', name: 'Ali Operatör', role: 'operator', status: 'active'));
        await v.into(v.callLogs).insert(CallLogsCompanion.insert(
              id: 'cl-1',
              phoneE164: '+905324152290',
              phoneLast10: '5324152290',
              direction: 'incoming',
              occurredAt: '2026-07-25T09:00:00.000Z',
              updatedOccurredAt: '2026-07-25T09:00:00.000Z',
            ));
      },
    );

    // ⭐ REGRESYON: `route_credits_monthly` adımı kapının ARKASINDAYKEN bu satır
    // `no such column: sync_meta.route_credits_monthly` ile patlıyordu — ve `sync_meta`
    // açılışta okunduğu için arıza "uygulama hiç açılmıyor" kılığında görünürdü.
    final meta = await db.syncState();
    expect(meta.routeCreditsMonthly, 0,
        reason: '"kota bilinmiyor" doğru başlangıçtır; değer ilk senkronda iner');
    expect(meta.lastPulledSeq, 1207, reason: 'imleç ezilmedi (TAM snapshot tetiklenmez)');
    expect(meta.authToken, 'bearer-v8', reason: 'oturum korunur (bayi yeniden giriş yapmaz)');
    expect(meta.routeCredits, 34);
    expect(meta.apiVersion, isNull);
    expect(meta.savedUsername, isNull);

    // ⭐ REGRESYON: `users.username` — kapı erken döndüğü için bu kolonu ancak kapıdan ÖNCE
    // yazılmış bir adım ekleyebilir.
    final kisi = await (db.select(db.users)..where((t) => t.id.equals('u-1'))).getSingle();
    expect(kisi.name, 'Ali Operatör');
    expect(kisi.username, '');
    expect(kisi.courierCanCallLog, isNull);

    // v11/v13/v14 ayar kolonları kapıdan ÖNCE koştu: kod tercihi ve yetki varsayılanları geldi.
    final ayar = await (db.select(db.tenantSettings)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    expect(ayar?.orderCodeDisplay ?? 'musteri', 'musteri');
    await db.into(db.tenantSettings).insertOnConflictUpdate(
        const TenantSettingsCompanion(id: Value(1), iban: Value('TR330006100519786457841326')));
    final ayar2 = await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingle();
    expect(ayar2.iban, 'TR330006100519786457841326');
    expect(ayar2.courierCanToggleStock, isTrue);
    expect(ayar2.ibanOwnerName, isNull);

    // Veri durur ve v21 kolonu eklendi.
    expect(
        (await (db.select(db.customers)..where((t) => t.id.equals('v8-c1'))).getSingle())
            .balanceKurus,
        9900);
    final cagri = await (db.select(db.callLogs)..where((t) => t.id.equals('cl-1'))).getSingle();
    expect(cagri.phoneLast10, '5324152290');
    expect(cagri.userId, isNull, reason: 'eski çağrının atfı bilinmiyor ve UYDURULMAZ');

    await semaTamOlmali(db, gerekce: 'v8 → bugün zinciri (kapı erken dönüyor).');
  });
}
