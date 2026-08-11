import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/day_end_repository.dart';

/// GÜNÜN TAHSİLAT DÖKÜMÜ — kasa kartındaki rakamların satır satır karşılığı
/// (kullanıcı isteği 2026-08-11).
///
/// DOSYANIN ASIL İDDİASI TUTARLILIK: döküm ile kasa kartı AYNI süzgeçten geçer, yani listenin
/// toplamı kartın rakamına eşittir. Ayrı yazılsalardı bayi "Havale 2.240 ₺" satırına dokunup
/// açılan listede başka bir sayı görür ve ikisine de güvenmezdi. Bu depoda aynı parayı iki
/// yerde ayrı hesaplamak gün sonu tanımında üç kez hataya yol açtı.
void main() {
  const gun = '2026-08-11';
  final tarih = DateTime(2026, 8, 11);

  /// Bir tahsilat defter kaydı. `payment` NEGATİF yazılır (borcu düşürür), kasaya giren
  /// pozitiftir — ekran ve repo bu işaret kuralını paylaşır.
  Future<void> tahsilat(
    AppDatabase db, {
    required String id,
    required int kurus,
    required String tur,
    String? musteriId,
    String? kuryeId,
    String saat = '10:00',
    String tip = 'payment',
  }) =>
      db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
            id: id,
            entryType: tip,
            amountKurus: tip == 'payment' ? -kurus : kurus,
            paymentType: Value(tur),
            customerId: Value(musteriId),
            collectedByUserId: Value(kuryeId),
            occurredAt: '${gun}T$saat:00.000Z',
            clientEventId: 'ev-$id',
          ));

  Future<AppDatabase> kur() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: 'm-1',
          name: 'Ahmet Yılmaz',
          updatedOccurredAt: '2026-08-11T00:00:00.000Z',
        ));
    await db.into(db.customerAddresses).insert(CustomerAddressesCompanion.insert(
          id: 'a-1',
          customerId: 'm-1',
          addressText: 'Bahçelievler Mah. 12/3',
          isPrimary: const Value(true),
          updatedOccurredAt: '2026-08-11T00:00:00.000Z',
        ));
    return db;
  }

  test('satır müşteri adını ve BİRİNCİL adresi taşır', () async {
    final db = await kur();
    addTearDown(db.close);
    await tahsilat(db, id: 'l-1', kurus: 224000, tur: 'kart', musteriId: 'm-1');

    final satirlar = await DayEndRepository(db).tahsilatDetaylari(tarih);
    expect(satirlar, hasLength(1));
    expect(satirlar.single.musteriAd, 'Ahmet Yılmaz');
    expect(satirlar.single.adres, 'Bahçelievler Mah. 12/3');
    expect(satirlar.single.kurus, 224000);
    expect(satirlar.single.odemeTuru, 'kart');
  });

  test('müşterisiz kayıt "Tezgâh satışı"dır ve adresi yoktur', () async {
    final db = await kur();
    addTearDown(db.close);
    await tahsilat(db, id: 'l-1', kurus: 5000, tur: 'nakit');

    final s = (await DayEndRepository(db).tahsilatDetaylari(tarih)).single;
    expect(s.musteriAd, 'Tezgâh satışı');
    expect(s.adres, isNull);
  });

  test('ödeme türü süzgeci yalnız o türü verir', () async {
    final db = await kur();
    addTearDown(db.close);
    await tahsilat(db, id: 'l-1', kurus: 10000, tur: 'nakit');
    await tahsilat(db, id: 'l-2', kurus: 20000, tur: 'havale');
    await tahsilat(db, id: 'l-3', kurus: 30000, tur: 'havale');

    final havale =
        await DayEndRepository(db).tahsilatDetaylari(tarih, odemeTuru: 'havale');
    expect(havale, hasLength(2));
    expect(havale.every((s) => s.odemeTuru == 'havale'), isTrue);
  });

  test('⭐ DÖKÜMÜN TOPLAMI KASA KARTIYLA AYNI — türler tek tek ve toplamda', () async {
    // Bu testin kırılması, ekranın iki yerinde iki farklı para gösterdiği anlamına gelir.
    final db = await kur();
    addTearDown(db.close);
    await tahsilat(db, id: 'l-1', kurus: 10000, tur: 'nakit', musteriId: 'm-1');
    await tahsilat(db, id: 'l-2', kurus: 224000, tur: 'kart', musteriId: 'm-1');
    await tahsilat(db, id: 'l-3', kurus: 50000, tur: 'havale');
    // Ters kayıt: yanlış alınan nakdi geri çevirir → kasadan ÇIKAR.
    await tahsilat(db, id: 'l-4', kurus: 3000, tur: 'nakit', tip: 'correction');

    final repo = DayEndRepository(db);
    final kasa = await repo.kasaOzeti(tarih);

    Future<int> toplam(String? tur) async =>
        (await repo.tahsilatDetaylari(tarih, odemeTuru: tur))
            .fold<int>(0, (a, s) => a + s.kurus);

    expect(await toplam('nakit'), kasa.nakit);
    expect(await toplam('kart'), kasa.kart);
    expect(await toplam('havale'), kasa.havale);
    expect(await toplam(null), kasa.toplam);
  });

  test('TERS KAYIT listede DURUR ve negatiftir — gizlemek listeyi toplamla çelişkiye düşürür',
      () async {
    final db = await kur();
    addTearDown(db.close);
    await tahsilat(db, id: 'l-1', kurus: 10000, tur: 'nakit');
    await tahsilat(db, id: 'l-2', kurus: 3000, tur: 'nakit', tip: 'correction');

    final satirlar = await DayEndRepository(db).tahsilatDetaylari(tarih);
    expect(satirlar, hasLength(2));
    expect(satirlar.any((s) => s.kurus == -3000), isTrue);
  });

  test('KAPSAM: kurye süzgeci başkasının tahsilatını GETİRMEZ', () async {
    // Şikâyetin özü buydu: kurye kendi işlemlerini görmeliydi, genel raporu değil.
    final db = await kur();
    addTearDown(db.close);
    await tahsilat(db, id: 'l-1', kurus: 10000, tur: 'nakit', kuryeId: 'k-1');
    await tahsilat(db, id: 'l-2', kurus: 90000, tur: 'nakit', kuryeId: 'k-2');

    final benim = await DayEndRepository(db).tahsilatDetaylari(tarih, userId: 'k-1');
    expect(benim, hasLength(1));
    expect(benim.single.kurus, 10000);
  });

  test('BAŞKA GÜNÜN tahsilatı listeye girmez', () async {
    final db = await kur();
    addTearDown(db.close);
    await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
          id: 'l-dun',
          entryType: 'payment',
          amountKurus: -70000,
          paymentType: const Value('nakit'),
          occurredAt: '2026-08-10T10:00:00.000Z',
          clientEventId: 'ev-dun',
        ));
    await tahsilat(db, id: 'l-bugun', kurus: 10000, tur: 'nakit');

    final satirlar = await DayEndRepository(db).tahsilatDetaylari(tarih);
    expect(satirlar, hasLength(1));
    expect(satirlar.single.kurus, 10000);
  });

  test('VERESİYE sipariş dökümde YOKTUR — kasaya girmeyen para listelenmez', () async {
    // `payment_type` taşımayan defter kaydı kasaya dokunmamıştır. Listeye girseydi dökümün
    // toplamı kasa kartını aşar ve iki rakam birbirini yalanlardı.
    final db = await kur();
    addTearDown(db.close);
    await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
          id: 'l-veresiye',
          entryType: 'charge',
          amountKurus: 80000,
          customerId: const Value('m-1'),
          occurredAt: '${gun}T11:00:00.000Z',
          clientEventId: 'ev-veresiye',
        ));
    await tahsilat(db, id: 'l-1', kurus: 10000, tur: 'nakit');

    expect(await DayEndRepository(db).tahsilatDetaylari(tarih), hasLength(1));
  });

  test('EN YENİ ÜSTTE sıralanır', () async {
    final db = await kur();
    addTearDown(db.close);
    await tahsilat(db, id: 'l-erken', kurus: 1000, tur: 'nakit', saat: '09:00');
    await tahsilat(db, id: 'l-gec', kurus: 2000, tur: 'nakit', saat: '17:00');

    final satirlar = await DayEndRepository(db).tahsilatDetaylari(tarih);
    expect(satirlar.first.kurus, 2000);
  });
}
