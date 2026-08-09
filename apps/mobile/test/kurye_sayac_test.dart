import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/orders/order_queries.dart' show watchAcikSiparisSayisi;
import 'package:sipario/screens/shell/ana_ozet.dart' show watchAnaOzet;

/// SAYAÇLAR KURYE KAPSAMINI SAYAR (2026-08-09 saha bulgusu).
///
/// Kurye telefonunda ölçüldü: başlık **"Bugün 12 açık · yalnız size atananlar"** diyor ama
/// listede **2** sipariş var; ana ekranda da "Açık Sipariş 12" yazıyordu. Liste süzülmüş,
/// SAYAÇLAR süzülmemişti — ekran kendi kendisiyle çelişiyordu ve kurye "10 siparişim
/// kayboldu" diye arardı. **Kural: bir listeyi süzen kapı, o listenin sayacını da süzer.**
///
/// Ana ekran sorgusu HAM SQL ve süzgeç İLK alt sorguda duruyor; `?` işaretleri SQL'de
/// göründükleri sıraya bağlandığı için değişken listesinin BAŞINA konmak zorundaydı. Yanlış
/// sıra SESSİZCE yanlış rakam üretir (sorgu patlamaz) — bu yüzden diğer alanlar da ölçülüyor.
void main() {
  /// İki açık sipariş: biri `kurye-1`'e, biri `kurye-2`'ye atanmış. Ayrıca borçlu bir müşteri
  /// var ki parametre kayması olursa borç/veresiye rakamları da bozulsun ve test bunu görsün.
  Future<AppDatabase> kur() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.customers).insert(CustomersCompanion.insert(
        id: 's1',
        name: 'Borçlu Müşteri',
        balanceKurus: const Value(5000),
        updatedOccurredAt: '2026-08-09T00:00:00.000Z'));
    await db.into(db.orders).insert(OrdersCompanion.insert(
        id: 's-o1',
        customerId: const Value('s1'),
        assignedUserId: const Value('kurye-1'),
        occurredAt: '2026-08-09T10:00:00.000Z'));
    await db.into(db.orders).insert(OrdersCompanion.insert(
        id: 's-o2',
        customerId: const Value('s1'),
        assignedUserId: const Value('kurye-2'),
        occurredAt: '2026-08-09T11:00:00.000Z'));
    return db;
  }

  test('liste sayacı: assignedTo verilince yalnız o kullanıcınınkiler sayılır', () async {
    final db = await kur();
    addTearDown(db.close);

    expect(await watchAcikSiparisSayisi(db).first, 2, reason: 'süzgeçsiz: tüm açıklar');
    expect(await watchAcikSiparisSayisi(db, assignedTo: 'kurye-1').first, 1);
    expect(await watchAcikSiparisSayisi(db, assignedTo: 'kurye-2').first, 1);
    expect(await watchAcikSiparisSayisi(db, assignedTo: 'kimse-yok').first, 0);
  });

  test('ana ekran bento sayacı: assignedTo süzer ve DİĞER rakamlar bozulmaz', () async {
    final db = await kur();
    addTearDown(db.close);
    final gun = DateTime(2026, 8, 9);

    final hepsi = await watchAnaOzet(db, gun: gun).first;
    final kuryeninki = await watchAnaOzet(db, gun: gun, assignedTo: 'kurye-1').first;

    expect(hepsi.acikSiparis, 2);
    expect(kuryeninki.acikSiparis, 1, reason: 'kurye yalnız kendi açığını sayar');

    // PARAMETRE SIRASI KORUMASI: süzgeç değişkeni listenin başına konmazsa gün sınırları
    // kayar ve aşağıdaki rakamlar sessizce değişir. Eşitlik bunu yakalar.
    expect(kuryeninki.borcluMusteri, hepsi.borcluMusteri);
    expect(kuryeninki.acikVeresiyeKurus, hepsi.acikVeresiyeKurus);
    expect(kuryeninki.bugunTahsilatKurus, hepsi.bugunTahsilatKurus);
    expect(kuryeninki.bugunSiparis, hepsi.bugunSiparis);
    expect(kuryeninki.bugunTeslim, hepsi.bugunTeslim);
  });
}
