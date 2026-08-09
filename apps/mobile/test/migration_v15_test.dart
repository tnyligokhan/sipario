import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/orders/harita_sorgulari.dart';
import 'package:sqlite3/sqlite3.dart';

/// v14→v15 — KURYE YETKİ MATRİSİ'NİN 13 KOLONU (2026-08-09 SAHA ARIZASI).
///
/// BU TEST BİR ARIZANIN ÜSTÜNE YAZILDI. Yetki Matrisi (2026-08-08) `tenant_settings`e 13 kolon
/// ekledi ve `onUpgrade` içine ALTER TABLE'larını da yazdı — **ama `schemaVersion` 14'te
/// bırakıldı.** Drift `onUpgrade`'i YALNIZ sürüm değiştiğinde çağırdığı için, sahadaki v14
/// damgalı cihazlarda o ALTER TABLE'lar HİÇ KOŞMADI.
///
/// Sonuç gerçek cihazda (SM-S721B, kablosuz adb ile görüldü):
///   SqliteException(1): no such column: tenant_settings.courier_can_see_all_orders
/// ve `tenant_settings`e dokunan HER sorgunun patlaması — harita ekranı bu yüzden açılmıyordu.
///
/// **1109 yeşil testin hiçbiri bunu göremedi** çünkü hepsi `NativeDatabase.memory()` ile TAZE
/// veritabanı kurar, yani `onCreate` yolundan geçer ve şema her zaman tamdır. Kusur yalnız
/// "önceki sürümü kurulu olan cihazda" görünür. Bu dosya tam olarak o yoldan geçer.
void main() {
  /// Yetki Matrisi'nin `tenant_settings`e eklediği 13 kolon. Sıra `app_database.dart`taki
  /// ALTER TABLE listesiyle birebir aynıdır — ayrışırlarsa bu test yanlış şeyi kanıtlar.
  const kuryeKolonlari = [
    'courier_can_customers',
    'courier_can_orders',
    'courier_can_collect',
    'courier_can_discount',
    'courier_can_day_end',
    'courier_can_see_all_orders',
    'courier_can_view_history',
    'courier_can_expense',
    'courier_phone_mask',
    'courier_can_customer_ledger',
    'courier_can_debt_reminder',
    'courier_can_toggle_stock',
    'courier_can_call_log',
  ];

  test(
      'v14→v15: kurye yetki kolonları sahadaki cihaza EKLENİR, veri aynen durur ve harita '
      'sorgusu tekrar çalışır. Sürüm artışı unutulursa onUpgrade HİÇ çağrılmaz ve ALTER '
      "TABLE'ların yazılmış olması hiçbir işe yaramaz — arıza tam olarak buydu.", () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_v14v15_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // 1) Güncel şemayla kur + korunması gereken veriyi yaz.
    final v15 = AppDatabase(NativeDatabase(file));
    await v15.into(v15.customers).insert(CustomersCompanion.insert(
        id: 'v14-c1',
        name: 'Kadir Doğan',
        balanceKurus: const Value(128000),
        updatedOccurredAt: '2026-08-08T00:00:00.000Z'));
    await v15.into(v15.tenantSettings).insertOnConflictUpdate(const TenantSettingsCompanion(
          id: Value(1),
          businessName: Value('Merkez Su Bayii'),
          iban: Value('TR330006100519786457841326'),
          ibanOwnerName: Value('Mehmet Yılmaz'),
        ));
    await v15.close();

    // 2) Dosyayı v14'e GERİ SAR: 13 kolonu düşür, damgayı 14 yap. Sahadaki bir cihazın
    //    2026-08-09 sabahındaki diskteki hâli birebir budur.
    final raw = sqlite3.open(file.path);
    for (final kolon in kuryeKolonlari) {
      raw.execute('ALTER TABLE tenant_settings DROP COLUMN $kolon');
    }
    raw.execute('PRAGMA user_version = 14');
    raw.close();

    // 3) Yeniden aç → onUpgrade(from: 14, to: 15) koşmalı.
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) file.deleteSync();
    });

    // Kolonların HEPSİ geri geldi mi? (Tek tek: eksik kalan biri bile bütün sorguyu patlatır.)
    final kolonlar = await db
        .customSelect('PRAGMA table_info(tenant_settings)')
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toSet());
    for (final kolon in kuryeKolonlari) {
      expect(kolonlar, contains(kolon), reason: '$kolon migration ile eklenmeliydi');
    }

    // Eski veri AYNEN duruyor (additif migration; para ve profil korunur).
    final ayar = await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingle();
    expect(ayar.businessName, 'Merkez Su Bayii');
    expect(ayar.ibanOwnerName, 'Mehmet Yılmaz');
    final musteri = await (db.select(db.customers)..where((c) => c.id.equals('v14-c1'))).getSingle();
    expect(musteri.balanceKurus, 128000);

    // Varsayılanlar sunucudaki migration `004007` ile aynı olmalı: yanlış varsayılan, senkron
    // gelene kadar geçen ilk karede kuryeye YANLIŞ yetki gösterir.
    expect(ayar.courierCanCustomers, isTrue);
    expect(ayar.courierCanSeeAllOrders, isFalse);
    expect(ayar.courierPhoneMask, isTrue);

    // ⭐ ASIL İDDİA: sahada patlayan sorgunun kendisi. Bu satır, düzeltme öncesi
    // `SqliteException(1): no such column: tenant_settings.courier_can_see_all_orders`
    // ile kırmızı yanardı.
    final veri = await watchHaritaDuraklari(db).first;
    expect(veri.duraklar, isEmpty, reason: 'açık sipariş yok — önemli olan sorgunun PATLAMAMASI');
  });
}
