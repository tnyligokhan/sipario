// BORÇLULAR ekranının VERİSİ — kim borçlu, ne kadar, hangi siparişten.
//
// NEDEN AYRI DOSYA: `borclular_ekrani.dart` 533 satıra çıkmıştı (500 satır kuralı). Sınır kendini
// gösteriyordu: bu dosyadaki hiçbir şey widget kurmuyor — üç akış (borçlu müşteriler · onların
// teslim edilmiş siparişleri · sipariş tahsilatları) ve bunları tek listeye bağlayan SAF
// `borcluListesiKur`. Ekranın gösterdiği her sayının dayanağı burasıdır ve widget kurmadan,
// saf async testle sınanır. Çizim tarafı `borclu_karti.dart`ta, kabuk `borclular_ekrani.dart`ta.
//
// SÖZLEŞME: `borclular_ekrani.dart` bu dosyayı yeniden dışa aktarır — mevcut
// `import 'borclular_ekrani.dart'` yolları ve testler aynen çalışır, imzalar DEĞİŞMEZ.
//
// İKİ SAYI AYRI DURUR ve toplanmaz: müşterinin DEFTER bakiyesi (tek doğru kaynak, tahsilatın
// yapıldığı büyüklük) ile siparişlerden kalanların toplamı eşit olmak ZORUNDA DEĞİLDİR — elle
// düzeltme, sipariş dışı borç ve teslimden önce alınan avans ikisini ayırır. Fark varsa ekran
// bunu SÖYLER; sessizce bir tarafı seçmek bayiye "rakamlar tutmuyor" dedirtirdi.

import 'package:drift/drift.dart';

import '../../data/app_database.dart';
import '../orders/order_queries.dart' show siparisKalanBorcu;

/// Bir borçlunun ödenmemiş siparişi.
class BorcluSiparis {
  const BorcluSiparis({required this.order, required this.kalanKurus});

  final Order order;

  /// Bu siparişten kalan borç (pozitif kuruş) — [siparisKalanBorcu].
  final int kalanKurus;
}

/// Ekranın bir kartı: müşteri + defter bakiyesi + ödenmemiş siparişleri.
class BorcluMusteri {
  const BorcluMusteri({
    required this.musteri,
    required this.borcKurus,
    required this.siparisler,
  });

  final Customer musteri;

  /// DEFTER bakiyesi (`customers.balance_kurus`) — tahsilat bu büyüklükten yapılır.
  final int borcKurus;

  final List<BorcluSiparis> siparisler;

  /// Siparişlerden kalanların toplamı. [borcKurus]tan KÜÇÜK olabilir (sipariş dışı borç,
  /// elle düzeltme) ya da BÜYÜK olabilir (müşteri önceden avans ödemiş, bakiye o kadar düşük).
  int get siparisToplami =>
      siparisler.fold<int>(0, (s, x) => s + x.kalanKurus);

  /// Siparişlere bağlanamayan borç farkı; 0 ise ekran bu satırı hiç yazmaz.
  int get farkKurus {
    final fark = borcKurus - siparisToplami;
    return fark > 0 ? fark : 0;
  }
}

/// Bakiyesi borçta olan müşteriler — borcu BÜYÜK olan üstte.
///
/// Ölçüt `balance_kurus > 0`: müşteri listesi ve ana ekran bento sayacı da aynı ölçütü kullanır
/// (`watchDebtCount`), üç yüzey aynı kümeyi konuşur.
Stream<List<Customer>> watchBorcluMusteriler(AppDatabase db) => (db.select(db.customers)
      ..where((t) => t.deletedAt.isNull() & t.balanceKurus.isBiggerThanValue(0))
      ..orderBy([(t) => OrderingTerm.desc(t.balanceKurus), (t) => OrderingTerm.asc(t.name)]))
    .watch();

/// Verilen müşterilerin TESLİM EDİLMİŞ siparişleri, en yeni önce.
///
/// Yalnız `delivered`: teslim edilmemiş mal borç değildir (2026-07-27 kararı — "Borçlu" sekmesi
/// bu yüzden düzeltilmişti). Sorgu müşteri kimlikleriyle DARALTILIR; borçlu olmayan müşterilerin
/// siparişleri hiç okunmaz, defter yıllara yayıldığında da liste kısa kalır.
Stream<List<Order>> watchBorcluSiparisleri(AppDatabase db, List<String> musteriIdler) {
  if (musteriIdler.isEmpty) return Stream.value(const []);
  return (db.select(db.orders)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.status.equals('delivered') &
            t.customerId.isIn(musteriIdler))
        ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)]))
      .watch();
}

/// İşletme profili satırı (cihazda TEK SATIR, id=1) — hatırlatma metni buradan beslenir.
Stream<TenantSetting?> watchIsletmeProfili(AppDatabase db) =>
    (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).watchSingleOrNull();

/// Üç kaynağı tek listeye bağlar. SAF fonksiyon — ekranın gösterdiği her sayının dayanağı budur
/// ve widget kurmadan test edilir.
///
/// Ödenmiş siparişler listeye GİRMEZ (kalan 0), müşteri kartı yine durur: borcu sipariş dışı bir
/// kayıttan geliyor olabilir ve o müşteriyi listeden düşürmek borcu görünmez yapardı.
List<BorcluMusteri> borcluListesiKur(
  List<Customer> musteriler,
  List<Order> siparisler,
  Map<String, int> tahsilatlar,
) {
  final gruplu = <String, List<BorcluSiparis>>{};
  for (final o in siparisler) {
    final musteriId = o.customerId;
    if (musteriId == null) continue;
    final kalan = siparisKalanBorcu(
      durum: o.status,
      toplamKurus: o.totalKurus,
      tahsilKurus: tahsilatlar[o.id] ?? 0,
    );
    if (kalan <= 0) continue;
    gruplu.putIfAbsent(musteriId, () => []).add(BorcluSiparis(order: o, kalanKurus: kalan));
  }
  return [
    for (final c in musteriler)
      BorcluMusteri(
        musteri: c,
        borcKurus: c.balanceKurus,
        siparisler: gruplu[c.id] ?? const [],
      ),
  ];
}
