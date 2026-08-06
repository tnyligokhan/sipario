import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sipario/data/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// v13→v14 — IBAN ALICI ADI + HATIRLATMA ŞABLONU (kullanıcı isteği 2026-08-06).
///
/// AYRI DOSYA: `migration_test.dart` 500 satır sınırına dayandı (ui_isletme testlerinin
/// bölünmesiyle aynı gerekçe). Kapsam ve disiplin aynıdır.
void main() {
  test(
      'v13→v14: sahadaki cihaza `iban_owner_name` ve `reminder_template` kolonları eklenir, '
      'veri AYNEN durur. v10..v13 ile AYNI tuzak: adım kendini-onarma kapısından ÖNCE koşmalı — '
      'kapı `tenant_settings` varsa erken döner ve v13 damgalı her cihazda o tablo ZATEN vardır. '
      '`from < 14` koşuluna alınsaydı adım sahadaki hiçbir cihazda koşmaz, bayi alıcı adını '
      'yazar, "kaydedildi" görür ve mesajda hiç göremezdi (hata da vermeden).', () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_v13v14_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // 1) Güncel şemayla kur + korunması gereken veriyi yaz (para + profilin mevcut alanları).
    final v14 = AppDatabase(NativeDatabase(file));
    await v14.into(v14.customers).insert(CustomersCompanion.insert(
        id: 'v13-c1', name: 'Borçlu Müşteri', balanceKurus: const Value(42500),
        updatedOccurredAt: '2026-08-06T00:00:00.000Z'));
    await v14.into(v14.tenantSettings).insertOnConflictUpdate(const TenantSettingsCompanion(
          id: Value(1),
          businessName: Value('Merkez Su Bayii'),
          iban: Value('TR330006100519786457841326'),
          receiptNote: Value('Teşekkürler'),
          courierCanDiscount: Value(true),
          orderCodeDisplay: Value('siparis'),
        ));
    await v14.close();

    // 2) Dosyayı v13'e GERİ SAR: iki kolonu düşür, damgayı 13 yap. Gerçek bir v13 cihazının
    //    diskteki hâli budur.
    final raw = sqlite3.open(file.path);
    raw.execute('ALTER TABLE tenant_settings DROP COLUMN iban_owner_name');
    raw.execute('ALTER TABLE tenant_settings DROP COLUMN reminder_template');
    raw.execute('PRAGMA user_version = 13');
    raw.close();

    // 3) Yeniden aç → onUpgrade(from: 13, to: 14).
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) file.deleteSync();
    });

    // Kolonlar geri geldi ve YAZILABİLİR (senkron bu alanları buraya yazacak).
    await (db.update(db.tenantSettings)..where((t) => t.id.equals(1))).write(
      const TenantSettingsCompanion(
        ibanOwnerName: Value('Mehmet Yılmaz'),
        reminderTemplate: Value('Sayın *musteriadi*, *siparistutar* bekliyoruz.'),
      ),
    );

    final ayar = await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingle();
    expect(ayar.ibanOwnerName, 'Mehmet Yılmaz');
    expect(ayar.reminderTemplate, 'Sayın *musteriadi*, *siparistutar* bekliyoruz.');

    // Profilin ESKİ alanları ezilmedi — yükseltme additif olmalı.
    expect(ayar.businessName, 'Merkez Su Bayii');
    expect(ayar.iban, 'TR330006100519786457841326');
    expect(ayar.receiptNote, 'Teşekkürler');
    expect(ayar.courierCanDiscount, isTrue, reason: 'kapatılabilir yetki varsayılana dönmemeli');
    expect(ayar.orderCodeDisplay, 'siparis');

    // Para verisi de yerinde (kırmızı çizgi #2).
    final cust = await (db.select(db.customers)..where((t) => t.id.equals('v13-c1'))).getSingle();
    expect(cust.balanceKurus, 42500);
    expect(cust.name, 'Borçlu Müşteri');
  });

  test('taze kurulumda iki kolon boş gelir — null "bayi dokunmadı" demektir', () async {
    // Varsayılan DEĞER YAZILMAZ: şablona varsayılan metni kopyalasaydık, metni ileride
    // iyileştirdiğimizde ona hiç dokunmamış bayilerde eski metin donardı.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.tenantSettings).insertOnConflictUpdate(
        const TenantSettingsCompanion(id: Value(1), businessName: Value('Öz Pınar')));

    final ayar = await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingle();
    // `isNull` matcher'ı drift'in aynı adlı ifadesiyle çakışır (courier_test dersi) — düz null.
    expect(ayar.ibanOwnerName, null);
    expect(ayar.reminderTemplate, null);
  });
}
