import 'dart:io';

// `show Value`: drift'in `isNull` yardımcısı matcher'ınkiyle çakışır ve bu dosyanın ASIL
// iddiası "kolon NULL mı" olduğu için matcher'ınki kazanmalı.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/team.dart';
import 'package:sqlite3/sqlite3.dart';

/// v16→v17 — KİŞİYE ÖZEL KURYE YETKİLERİNİN 13 KOLONU (`users`).
///
/// `migration_v15_test.dart`ın ikizidir ve AYNI ARIZAYA karşı yazılmıştır: 2026-08-09'da Yetki
/// Matrisi'nin 13 kolonu `tenant_settings`e eklendi, `onUpgrade` yazıldı ama `schemaVersion`
/// artırılmadı — sahadaki cihazlarda ALTER TABLE'lar HİÇ koşmadı ve `tenant_settings`e dokunan
/// her sorgu patladı. Bellek içi veritabanıyla koşan 1109 test bunu göremedi, çünkü hepsi
/// `onCreate` yolundan geçer ve orada şema her zaman tamdır.
///
/// Bu göç aynı riski `users` üzerinde taşır ve BEDELİ DAHA AĞIRDIR: `users` her senkron turunda
/// toptan silinip yeniden yazılır (`_applyTeam`), yani kolonlar eksikse yalnız yetki ekranı
/// değil EKİP LİSTESİNİN TAMAMI çöker — atama, ad çözümü, kurye seçici.
void main() {
  /// Migration'ın `users`a eklediği 13 kolon. Sıra `app_database.dart`taki ALTER TABLE
  /// listesiyle birebir aynıdır — ayrışırlarsa bu test yanlış şeyi kanıtlar.
  const ezmeKolonlari = [
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
      'v16→v17: kişisel yetki kolonları sahadaki cihaza EKLENİR, ekip verisi aynen durur ve '
      'yeni kolonlar NULL (devral) gelir — false gelseydi bayinin AÇIK varsayılanları '
      'yükseltmeden sonra her kuryede sessizce kapanırdı', () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_v16v17_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // 1) Güncel şemayla kur + korunması gereken ekip verisini yaz.
    final v17 = AppDatabase(NativeDatabase(file));
    await v17.into(v17.users).insert(UsersCompanion.insert(
          id: 'k-1',
          name: 'Ahmet Yıldız',
          role: 'kurye',
          status: 'active',
          phone: const Value('+905321112233'),
          username: const Value('ahmet'),
        ));
    await v17.into(v17.tenantSettings).insertOnConflictUpdate(const TenantSettingsCompanion(
          id: Value(1),
          businessName: Value('Merkez Su Bayii'),
          // Bayi varsayılanı: tahsilat AÇIK, iskonto KAPALI.
          courierCanCollect: Value(true),
          courierCanDiscount: Value(false),
        ));
    await v17.close();

    // 2) Dosyayı v16'ya GERİ SAR: 13 kolonu düşür, damgayı 16 yap. Sahadaki bir cihazın
    //    yükseltmeden önceki diskteki hâli birebir budur.
    final raw = sqlite3.open(file.path);
    for (final kolon in ezmeKolonlari) {
      raw.execute('ALTER TABLE users DROP COLUMN $kolon');
    }
    raw.execute('PRAGMA user_version = 16');
    raw.close();

    // 3) Yeniden aç → onUpgrade(from: 16, to: 17) koşmalı.
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) file.deleteSync();
    });

    // Kolonların HEPSİ geri geldi mi? Eksik kalan biri bile ekip listesinin tamamını patlatır.
    final kolonlar = await db
        .customSelect('PRAGMA table_info(users)')
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toSet());
    for (final kolon in ezmeKolonlari) {
      expect(kolonlar, contains(kolon), reason: '$kolon migration ile eklenmeliydi');
    }

    // Eski ekip verisi AYNEN duruyor (additif migration).
    final kullanici = await (db.select(db.users)..where((t) => t.id.equals('k-1'))).getSingle();
    expect(kullanici.name, 'Ahmet Yıldız');
    expect(kullanici.phone, '+905321112233');
    expect(kullanici.username, 'ahmet');

    // ⭐ ASIL İDDİA: yeni kolonlar NULL, yani "devral". `false` varsayılanı verilseydi
    // yükseltmeyi yapan HER cihazda bayinin açık bıraktığı yetkiler (müşteri/sipariş/
    // tahsilat/stok) sessizce kapanır ve kurye sabah işini yapamazdı.
    expect(kullanici.courierCanCollect, isNull);
    expect(kullanici.courierCanDiscount, isNull);
    expect(kuryeEzmeleriOku(kullanici).hepsiDevralindi, isTrue);

    // Ve çözüm bayi varsayılanını verir — yükseltme öncesi davranışla BİREBİR aynı.
    final ayar = await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingle();
    final etkin = kuryeIzinleriCoz(kuryeIzinleriOku(ayar), kuryeEzmeleriOku(kullanici));
    expect(etkin.tahsilat, isTrue);
    expect(etkin.iskonto, isFalse);
  });
}
