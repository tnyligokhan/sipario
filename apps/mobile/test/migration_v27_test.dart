import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/team.dart';

import 'support/migration_yardimcilari.dart';

/// v26→v27 — KURYE MÜŞTERİ GÖRÜNÜRLÜĞÜ (`courier_can_see_all_customers`, 2026-08-22).
///
/// AYNI ADLI KOLON İKİ TABLOYA girer ve İKİ FARKLI VARSAYILANLA — üç durumlu yetki modelinin
/// tamamı bu farkta yaşar:
///   `tenant_settings` → NOT NULL DEFAULT 0 (bayi varsayılanı: kapalı)
///   `users`           → NULLABLE           (null = "bayi varsayılanını devral")
/// `users` tarafına varsayılan koymak devralmayı yok ederdi: sahadaki her kurye, bayi ayarını
/// sonradan değiştirse bile yükseltme anındaki değere çakılı kalırdı (v17 dersi).
///
/// BEDELİ AĞIR OLURDU: Drift kolonları AÇIK LİSTEYLE sorgular. `tenant_settings`te kolon
/// eksikse ayarlar ekranı ve senkronun profil yazımı, `users`ta eksikse Kuryeler ekranı, atama
/// hedefi listesi ve `team` bloğunun uygulanması topluca "no such column" ile düşer.
void main() {
  test(
      'v26→v27: courier_can_see_all_customers İKİ TABLOYA da eklenir; tenant KAPALI, kişi '
      'DEVRALIR ve mevcut veri aynen durur', () async {
    final db = await eskiCihaziYukselt(
      etiket: 'v26v27',
      surum: 26,
      veriYaz: (v27) async {
        // Yükseltmenin korumak zorunda olduğu veri: bir bayi ayarı satırı + bir kurye.
        await v27.into(v27.tenantSettings).insertOnConflictUpdate(
              const TenantSettingsCompanion(
                id: Value(1),
                businessName: Value('Merkez Su Bayii'),
                // Başka bir kurye yetkisi AÇIK bırakılır: yeni kolonun eklenmesi, komşusunun
                // değerini bozmamalı.
                courierCanCollect: Value(true),
              ),
            );
        await v27.into(v27.users).insert(UsersCompanion.insert(
              id: 'k-1',
              name: 'Kurye Ali',
              role: 'kurye',
              status: 'active',
              courierCanCollect: const Value(false),
            ));
      },
      geriSar: [
        'ALTER TABLE tenant_settings DROP COLUMN courier_can_see_all_customers',
        'ALTER TABLE users DROP COLUMN courier_can_see_all_customers',
      ],
    );

    expect(await kolonlar(db, 'tenant_settings'), contains('courier_can_see_all_customers'));
    expect(await kolonlar(db, 'users'), contains('courier_can_see_all_customers'));

    // Korunması gereken veri yerinde ve KOMŞU YETKİ BOZULMADI.
    final ayar = await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingle();
    expect(ayar.businessName, 'Merkez Su Bayii');
    expect(ayar.courierCanCollect, isTrue);

    // ⭐ BAYİ VARSAYILANI KAPALI DOĞAR — istek kısıtlamanın kendisiydi.
    expect(ayar.courierCanSeeAllCustomers, isFalse);

    // ⭐ KİŞİ TARAFI NULL DOĞAR = "devral". `false` yazılsaydı, bayi sonradan yetkiyi açtığında
    // sahadaki kuryeler kişisel bir KAPALI ezmeyle donmuş kalırdı ve patron sebebini bulamazdı.
    final kurye = await (db.select(db.users)..where((t) => t.id.equals('k-1'))).getSingle();
    expect(kurye.courierCanSeeAllCustomers, isNull);
    expect(kurye.courierCanCollect, isFalse, reason: 'komşu ezme bozulmadı');

    // Devralma çözümü uçtan uca: tenant kapalı + ezme yok → etkin yetki KAPALI.
    final etkin = kuryeIzinleriCoz(kuryeIzinleriOku(ayar), kuryeEzmeleriOku(kurye));
    expect(etkin.tumMusteriler, isFalse);

    // Yetki matrisi de aynı sonucu vermeli (K2 tek kapıdır).
    final yetki = yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: etkin);
    expect(yetki.tumMusterileriGorme, isFalse);

    await semaTamOlmali(db);
  });
}
