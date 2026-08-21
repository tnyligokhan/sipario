// Sipariş ekranlarının MÜŞTERİ TARAFI sorguları — adres · telefon · sipariş geçmişi · açık
// sipariş uyarısı · müşteri arama · katalog. Tasarım kaynağı: s-veri.jsx (`birincilAdres`,
// `birincilTel`) + s-siparisler.jsx (yeni sipariş adım 1).
//
// NEDEN AYRI DOSYA: `order_queries.dart` 728 satıra çıkmıştı (500 satır kuralı). Sınır burada
// kendiliğinden duruyordu: bu akışların hiçbiri `orders` tablosunun LİSTESİNİ kurmuyor, hepsi
// "sipariş girilirken/okunurken müşteri hakkında ne bilmemiz gerekiyor" sorusunu cevaplıyor.
// Sipariş listesi tarafı (süzgeç, sıralama, borç) `order_queries.dart`ta kaldı; buradan oraya
// bağımlılık YOKTUR (ters yön de yok — iki dosya birbirinden bağımsız derlenir).
//
// SÖZLEŞME: `order_queries.dart` bu dosyayı yeniden dışa aktarır — mevcut
// `import 'order_queries.dart'` yolları ve testler aynen çalışır, imzalar DEĞİŞMEZ.

import 'package:drift/drift.dart';

import '../../data/app_database.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Adres · telefon
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Müşterinin birincil adresi — s-veri.jsx `birincilAdres`.
class AdresBilgi {
  const AdresBilgi({required this.metin, this.bolge, this.lat, this.lng});
  final String metin;

  /// Semt/bölge (`CustomerAddresses.region`). Tasarım adresi "metin — bölge" diye yazar.
  final String? bolge;

  final double? lat;
  final double? lng;

  /// CSS `.srow-adres` / `.sdx-adres` — tasarımın `[metin, bolge].filter(…).join(', ')` yazımı.
  /// Tasarımdaki gibi boş ve "—" değerler ELENİR (kullanıcı "Adres — —" görmesin).
  String get tamMetin =>
      [metin, bolge].where((x) => x != null && x.isNotEmpty && x != '—').join(', ');

  /// CSS `.sdx-konum` — konum kayıtlı mı?
  bool get konumVar => lat != null && lng != null;

  /// "41,0082, 28,9784" — tasarım 4 haneli gösteriyor.
  String get konumMetni =>
      konumVar ? '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}' : '';
}

/// customerId → birincil adres. `isPrimary` işaretlisi varsa o, yoksa ilk kayıt.
Stream<Map<String, AdresBilgi>> watchBirincilAdresler(AppDatabase db) {
  final q = db.select(db.customerAddresses)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.isPrimary), (t) => OrderingTerm.asc(t.id)]);
  return q.watch().map((rows) {
    final map = <String, AdresBilgi>{};
    for (final a in rows) {
      map.putIfAbsent(
        a.customerId,
        () => AdresBilgi(
          metin: a.addressText,
          bolge: a.region,
          lat: a.lat,
          lng: a.lng,
        ),
      );
    }
    return map;
  });
}

/// customerId → birincil telefon (E.164 saklanır, gösterimde `sipTelefon` biçimlenir).
Stream<Map<String, String>> watchBirincilTelefonlar(AppDatabase db) {
  final q = db.select(db.customerPhones)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.isPrimary), (t) => OrderingTerm.asc(t.id)]);
  return q.watch().map((rows) {
    final map = <String, String>{};
    for (final p in rows) {
      map.putIfAbsent(p.customerId, () => p.phoneE164);
    }
    return map;
  });
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sipariş geçmişi
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bir müşterinin sipariş GEÇMİŞİ — en yeni önce. Silinmişler (tombstone) hariç.
///
/// TEK SORGU, iki çağıran: sipariş detayındaki "Geçmiş Siparişler" kartı (CSS `.gec-*`) bir
/// siparişi hariç tutar ve az sayıda satır gösterir; müşteri geçmişi ekranı ise tümünü ister.
/// İki ayrı sorgu yazmak, birinde "silinmiş sayılmaz" kuralını güncellemeyi unutmak ve aynı
/// müşteriye iki farklı geçmiş göstermek demekti.
///
/// [limit] SQL'de uygulanır, Dart'ta kırpılarak değil: 400 siparişlik bir müşteride "ilk 3"ü
/// göstermek için 400 satır çekip 397'sini atmak, listeyi her akış tikinde yeniden kurar.
/// null = sınırsız.
///
/// [haricOrderId] verilirse o sipariş listeden düşer (kendi detayında kendini göstermesin).
Stream<List<Order>> watchMusteriSiparisGecmisi(
  AppDatabase db,
  String customerId, {
  String? haricOrderId,
  int? limit,
}) {
  final q = db.select(db.orders)
    ..where((t) => t.customerId.equals(customerId) & t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)]);
  if (haricOrderId != null) {
    q.where((t) => t.id.equals(haricOrderId).not());
  }
  if (limit != null) q.limit(limit);
  return q.watch();
}

/// Sipariş detayındaki "Geçmiş Siparişler" (CSS `.gec-*`) — mevcut çağrı biçimi korunur.
Stream<List<Order>> watchGecmisSiparisler(AppDatabase db, String customerId, String haricOrderId) =>
    watchMusteriSiparisGecmisi(db, customerId, haricOrderId: haricOrderId);

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Müşterinin AÇIK siparişi var mı? (yeni sipariş açarken uyarı)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Müşterinin AÇIK siparişleri — en yeni ÖNCE. Boş liste = açık siparişi yok.
///
/// NEDEN SARMALAYICI BİR TİP DEĞİL (bir ara `AcikSiparisOzeti` diye bir sınıf denendi ve
/// kaldırıldı): uyarıyı yazan ekranın sorduğu iki şey — KAÇ tane (`length`) ve EN YENİSİ
/// hangisi (`first`) — listenin kendisinde zaten var. Üstelik o sınıf hem burada hem
/// `repo/order_repository.dart`ta tanımlanmıştı; sipariş formu iki dosyayı da import eder
/// (biri `LineInput`, diğeri sorgular için) ve tipe dokunduğu anda "ambiguous import" ile
/// DERLENMEZDİ. Satırın TAMAMI dönüyor çünkü hangi kodun (müşteri mi sipariş mi) yazılacağı
/// kiracı tercihine bağlıdır (`satirKodu`) — o karar ekranın, sorgunun değil.
///
/// TEK ATIŞ (uyarı diyaloğu için): bu, sorulduğu ANIN cevabıdır. Akış olsaydı kullanıcı uyarıyı
/// okurken altındaki metin değişebilirdi. Canlı bir rozet gerekiyorsa [watchAcikSiparisler].
///
/// KAPSAM KARARI (verildi): yalnız `status == 'open'`. Teslim edilmiş sipariş bitmiştir,
/// iptal edilmiş hiç olmamıştır; ikisini de "zaten siparişi var" diye uyarıya sokmak bayiyi
/// her ikinci siparişte yanlış uyarırdı — görmezden gelinen uyarı, olmayan uyarıdır.
/// Silinmiş (`deleted_at`) sipariş sayılmaz ve başka müşterinin siparişi karışmaz.
Future<List<Order>> acikSiparisler(AppDatabase db, String customerId) =>
    _acikSiparisSorgusu(db, customerId).get();

/// [acikSiparisler]'in AKIŞI — müşteri detayındaki canlı rozet için. AYNI sorgu.
Stream<List<Order>> watchAcikSiparisler(AppDatabase db, String customerId) =>
    _acikSiparisSorgusu(db, customerId).watch();

/// Açık sipariş sorgusunun TEK tanımı — akış ve tek atış aynı kuralı paylaşır. İki yerde ayrı
/// yazılsaydı, biri "silinmiş sayılmaz"ı unuttuğunda uyarı ekrana göre farklı çıkardı.
///
/// İkincil anahtar `id`: `occurredAt` aynı milisaniyede eşitlenebilir ve o zaman "en yenisi"
/// çağrıdan çağrıya değişirdi. uuid7 aynı ms içinde sıralı DEĞİLDİR, yani bu ek anahtar doğru
/// sıralamayı değil KARARLI sıralamayı garanti eder — uyarının aynı veriyle hep aynı siparişi
/// göstermesi için bu yeterlidir.
SimpleSelectStatement<$OrdersTable, Order> _acikSiparisSorgusu(
  AppDatabase db,
  String customerId,
) =>
    db.select(db.orders)
      ..where((t) =>
          t.customerId.equals(customerId) & t.status.equals('open') & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)]);

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Müşteri kaydı okuma
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Tek müşteri (detay başlığı, bakiye, ad).
Stream<Customer?> watchMusteri(AppDatabase db, String customerId) =>
    (db.select(db.customers)..where((t) => t.id.equals(customerId))).watchSingleOrNull();

/// Tek atış müşteri okuma — sheet açılmadan ÖNCE başlık/ad gerektiğinde (akış beklenemez).
Future<Customer?> musteriOku(AppDatabase db, String customerId) =>
    (db.select(db.customers)..where((t) => t.id.equals(customerId))).getSingleOrNull();

/// Siparişin sheet BAŞLIĞI — tasarım `baslik={o.musteriAd}` (s-siparisler.jsx:466). `sipSheet`
/// başlığı `String` ister, akış bekleyemez; bu yüzden sheet açılmadan önce tek atış okunur.
Future<String> siparisBasligi(AppDatabase db, String orderId) async {
  final order =
      await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingleOrNull();
  final musteriId = order?.customerId;
  if (musteriId == null) return 'Tezgâh satışı';
  return (await musteriOku(db, musteriId))?.name ?? 'Tezgâh satışı';
}

/// Müşteri düzenleme sheet'inin istediği üçlü. Sheet `screens/customers/`de yaşıyor ve kayıt +
/// telefonlar + birincil adresi HAZIR ister; sipariş detayındaki "Müşteriyi Düzenle" bağlantısı
/// onu tek dokunuşta açabilsin diye tek okumada toplanır.
class MusteriDuzenleVerisi {
  const MusteriDuzenleVerisi({
    required this.musteri,
    required this.telefonlar,
    this.adres,
  });

  final Customer musteri;
  final List<CustomerPhone> telefonlar;
  final CustomerAddressesData? adres;
}

Future<MusteriDuzenleVerisi?> musteriDuzenleVerisiOku(AppDatabase db, String customerId) async {
  final musteri = await musteriOku(db, customerId);
  if (musteri == null) return null;
  final telefonlar = await (db.select(db.customerPhones)
        ..where((t) => t.customerId.equals(customerId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.isPrimary), (t) => OrderingTerm.asc(t.id)]))
      .get();
  final adresler = await (db.select(db.customerAddresses)
        ..where((t) => t.customerId.equals(customerId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.isPrimary), (t) => OrderingTerm.asc(t.id)]))
      .get();
  return MusteriDuzenleVerisi(
    musteri: musteri,
    telefonlar: telefonlar,
    adres: adresler.isEmpty ? null : adresler.first,
  );
}

/// Silinmemiş müşteri kimlikleri. "Yeni müşteri ekle" sheet'i `bool?` döner (sözleşmesi o —
/// dosya başka ajanın alanı), dolayısıyla eklenen kaydın kimliği önce/sonra kümelerinin
/// FARKINDAN bulunur; tek kayıt eklendiği için fark tektir.
Future<Set<String>> musteriKimlikleri(AppDatabase db) async {
  final rows = await (db.select(db.customers)..where((t) => t.deletedAt.isNull())).get();
  return {for (final c in rows) c.id};
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Yeni sipariş adım 1 — müşteri arama · katalog
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Yeni sipariş adım 1 — müşteri arama. Ad VEYA telefonun son 10 hanesi eşleşir (müşteri liste
/// ekranıyla aynı kural; oradan sembol ödünç ALMADAN, çünkü o dosya eşzamanlı yeniden yazılıyor).
Stream<List<Customer>> watchMusteriArama(AppDatabase db, String sorgu) {
  final q = sorgu.trim();
  final sel = db.select(db.customers)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.asc(t.name)]);
  if (q.isEmpty) return sel.watch();

  final rakam = q.replaceAll(RegExp(r'\D'), '');
  return sel.watch().asyncMap((liste) async {
    final adEsleme = liste
        .where((c) => c.name.toLowerCase().contains(q.toLowerCase()))
        .map((c) => c.id)
        .toSet();
    if (rakam.length >= 3) {
      final telefonlar = await (db.select(db.customerPhones)
            ..where((t) => t.deletedAt.isNull() & t.phoneLast10.like('%$rakam%')))
          .get();
      adEsleme.addAll(telefonlar.map((p) => p.customerId));
    }
    return liste.where((c) => adEsleme.contains(c.id)).toList();
  });
}

/// Katalog — aktif ürünler, ada göre. (Ürün ekranı başka ajanın; sorguyu kendimiz kuruyoruz.)
Stream<List<Product>> watchKatalogUrunleri(AppDatabase db) => (db.select(db.products)
      ..where((t) => t.isActive.equals(true) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
    .watch();

/// POS kataloğunun arama süzgeci: ad VE barkod birlikte taranır.
///
/// Barkod okuyucu okuduğu kodu ARAMA ALANINA yazar (2026-07-26 kullanıcı kararı), yani
/// sorgu çoğu zaman bir barkoddur. Yalnız ada bakan bir süzgeç, okutulan ürünü `"…" için
/// sonuç yok` ile karşılardı — okuma başarılıyken.
List<Product> katalogSuz(List<Product> tumu, String sorgu) {
  final q = sorgu.trim().toLowerCase();
  if (q.isEmpty) return tumu;
  return tumu
      .where((u) => u.name.toLowerCase().contains(q) || (u.barcode ?? '').contains(q))
      .toList();
}
