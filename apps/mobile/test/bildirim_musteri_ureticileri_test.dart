// Müşteri ilişkisi ÜRETİCİLERİ — veritabanından kurala uçtan uca.
//
// Kuralların kendisi `bildirim_musteri_kurallari_test.dart`ta saf olarak sınanıyor. Burada
// sınanan tek şey BAĞLANTI: doğru satırlar okunuyor mu, "bugün" enjekte edilebiliyor mu,
// hata yutuluyor mu. Widget yok, sahte zaman yok — gerçek (bellek içi) Drift.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/bildirim/kurallar/musteri_ureticileri.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';

void main() {
  /// [gunlerOnce] listesindeki her gün için bir sipariş açar ve (teslim ise) teslim eder.
  /// Sipariş zamanı geçmişe yazılır — `occurred_at` doğrudan güncellenir, çünkü repo "şimdi"yi
  /// kullanır ve geçmiş bir tarih üretemez.
  Future<String> musteriKur(
    AppDatabase db, {
    required String ad,
    required List<int> teslimGunlerOnce,
    bool acikSiparis = false,
  }) async {
    final musteriId = await CustomerRepository(db).create(name: ad);
    final repo = OrderRepository(db);
    for (final gun in teslimGunlerOnce) {
      final id = await repo.create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 5000, qty: 1),
      ]);
      await repo.deliver(id, paymentType: 'nakit');
      final an = DateTime.now().subtract(Duration(days: gun));
      await db.customStatement(
        'UPDATE orders SET occurred_at = ? WHERE id = ?',
        [an.toIso8601String(), id],
      );
    }
    if (acikSiparis) {
      await repo.create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 5000, qty: 1),
      ]);
    }
    return musteriId;
  }

  test('gecikmiş müşteri üreticisi DB\'den okuyup taslak üretir', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // 15 günde bir alan müşteri, son teslim 30 gün önce → eşik 21, gecikmiş.
    await musteriKur(db, ad: 'Ahmet Yılmaz', teslimGunlerOnce: [75, 60, 45, 30]);

    final uretici = gecikmisMusteriUreticisi(db);
    final taslak = await uretici();

    expect(taslak, isNotNull);
    expect(taslak!.kategori, BildirimKategori.musteriGecikti);
    expect(taslak.baslik, 'Bir müşteri gecikti');
    expect(taslak.govde, contains('Ahmet Yılmaz'));
    expect(taslak.govde, contains('30 gündür'));

    await db.close();
  });

  test('rutin teslim üreticisi bugün sırası geleni bulur', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // 10 günde bir alan müşteri, son teslim TAM 10 gün önce → bugün sırası.
    await musteriKur(db, ad: 'Ayşe Kaya', teslimGunlerOnce: [40, 30, 20, 10]);

    final taslak = await rutinTeslimUreticisi(db)();

    expect(taslak, isNotNull);
    expect(taslak!.kategori, BildirimKategori.rutinTeslimGunu);
    expect(taslak.baslik, 'Bugün 1 rutin teslim var');
    expect(taslak.govde, contains('Ayşe Kaya'));

    await db.close();
  });

  test('"bugün" ENJEKTE edilebilir — sabit yazılmadı', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await musteriKur(db, ad: 'Ahmet Yılmaz', teslimGunlerOnce: [75, 60, 45, 30]);

    // Saati 20 gün GERİ alırsak son teslim 10 gün önce olur → henüz gecikme yok.
    final gecmis = DateTime.now().subtract(const Duration(days: 20));
    final taslak = await gecikmisMusteriUreticisi(db, simdi: () => gecmis)();

    expect(taslak, isNull, reason: 'üretici enjekte edilen günü kullanmalı');
    await db.close();
  });

  test('veri yoksa SUSAR — boş bildirim atılmaz', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(await gecikmisMusteriUreticisi(db)(), isNull);
    expect(await rutinTeslimUreticisi(db)(), isNull);
    await db.close();
  });

  test('geçmişi kısa müşteri taslak üretmez', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // 2 teslimat: ritim hesaplanamaz (alt sınır 4).
    await musteriKur(db, ad: 'Yeni Müşteri', teslimGunlerOnce: [45, 30]);
    expect(await gecikmisMusteriUreticisi(db)(), isNull);
    await db.close();
  });

  test('bekleyen açık siparişi olan müşteri bildirilmez', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await musteriKur(db,
        ad: 'Sipariş Vermiş', teslimGunlerOnce: [75, 60, 45, 30], acikSiparis: true);
    expect(await gecikmisMusteriUreticisi(db)(), isNull,
        reason: 'zaten sipariş vermiş, kurye yolda');
    await db.close();
  });

  test('okuma patlarsa null döner, patlamaz — bildirim uygulamayı düşüremez', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.close(); // kapalı DB → sorgu hata atar

    expect(await gecikmisMusteriUreticisi(db)(), isNull);
    expect(await rutinTeslimUreticisi(db)(), isNull);
  });
}
