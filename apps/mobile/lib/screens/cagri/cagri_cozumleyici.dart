// Gelen numarayı DEFTERE bağlayan adaptör — çağrı kartının verisini kurar.
// Tasarım kaynağı: s-cagri.jsx:5-11 (numarayı son 10 haneyle müşteride arar, birincil adresi,
// bakiyeyi, notu, son siparişi / son defter hareketini toplar).
//
// NEDEN AYRI DOSYA: `cagri_model.dart` bilerek `lib/data`ya bağlı DEĞİL (kart gerçek cihazda
// saf Kotlin'le çizilir). Modeli dolduran "çağıran" işte burada duruyor: kartın kendisi hâlâ
// veri katmanını tanımıyor, bu dosya tanıyor.
//
// PERFORMANS: kart 1 saniyelik bütçeyle açılır. Buradaki sorguların HEPSİ tek satır çeker;
// telefon araması `idx_phones_last10` indeksinden gider (native `CustomerLookup.last10` ile
// aynı anahtar).
//
// KVKK: bu dosya HİÇBİR yere log yazmaz — numara/ad/adres PII'dir.

// Tam import: `&` (BooleanExpressionOperators) bir uzantı metodudur, `show` ile gelmez.
import 'package:drift/drift.dart';

import '../../data/app_database.dart';
import 'cagri_model.dart';

/// Gelen numaradan çağrı kartının modelini kurar. Numara kayıtlı değilse (ya da 10 haneden
/// kısaysa — gizli numara/kısa servis numarası) [CagriKisi.kayitsiz] döner, kart o zaman
/// "Müşteri Olarak Kaydet" varyantına düşer.
///
/// [numara] HAM gelir (native `+90…`, kullanıcı `0…`, test `0532 415 22 90`); eşleşme
/// [sonOnHane] üzerinden yapılır, kartta gösterilen metin verilen ham numaradır.
/// [simdi] yalnız test içindir (saat metni sabitlensin).
Future<CagriKisi> cagriKisiCoz(
  AppDatabase db,
  String numara, {
  DateTime? simdi,
}) async {
  final anahtar = sonOnHane(numara);
  if (anahtar.length < 10) return CagriKisi.kayitsiz(numara);

  // Aynı numara iki müşteride olamaz (form kapısı) ama çevrimdışı iki cihaz aynı numarayı
  // girebilir; birincil telefon önce gelsin ki seçim iki cihazda da aynı olsun.
  final telefon = await (db.select(db.customerPhones)
        ..where((t) => t.phoneLast10.equals(anahtar) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.isPrimary), (t) => OrderingTerm.asc(t.id)])
        ..limit(1))
      .getSingleOrNull();
  if (telefon == null) return CagriKisi.kayitsiz(numara);

  final musteri = await (db.select(db.customers)
        ..where((t) => t.id.equals(telefon.customerId) & t.deletedAt.isNull()))
      .getSingleOrNull();
  // Müşteri arşivlenmiş ama telefon satırı kalmışsa numara "kayıtsız"dır: silinmiş defteri
  // açan bir kart göstermek yanlış olurdu.
  if (musteri == null) return CagriKisi.kayitsiz(numara);

  final adres = await (db.select(db.customerAddresses)
        ..where((t) => t.customerId.equals(musteri.id) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.isPrimary), (t) => OrderingTerm.asc(t.id)])
        ..limit(1))
      .getSingleOrNull();

  final (sonHareket, sonHareketTuru) = await _sonHareket(db, musteri.id, simdi: simdi);

  return CagriKisi(
    numara: numara,
    musteriId: musteri.id,
    ad: musteri.name,
    bakiyeKurus: musteri.balanceKurus,
    adres: adres?.addressText,
    bolge: adres?.region,
    konumVar: adres?.lat != null && adres?.lng != null,
    not: musteri.note,
    sonHareket: sonHareket,
    sonHareketTuru: sonHareketTuru,
  );
}

/// Tasarımın öncelik sırası (s-cagri.jsx:41-42): SİPARİŞ varsa "Son sipariş: …", yoksa son
/// defter hareketi "Son hareket: …". İkisi de yoksa satır hiç çizilmez (null).
Future<(String?, SonHareketTuru)> _sonHareket(
  AppDatabase db,
  String customerId, {
  DateTime? simdi,
}) async {
  final siparis = await (db.select(db.orders)
        ..where((t) => t.customerId.equals(customerId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)])
        ..limit(1))
      .getSingleOrNull();

  if (siparis != null) {
    // id (uuid7) ile sıralı: döküm satırların EKLENME sırasında yazılır, iki cihazda aynı
    // metni verir (order_lines'ın kendi sıra kolonu yok).
    final satirlar = await (db.select(db.orderLines)
          ..where((t) => t.orderId.equals(siparis.id) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final saat = cagriSaatMetni(DateTime.tryParse(siparis.occurredAt), simdi: simdi);
    return (
      cagriSonHareketMetni(
        onEk: 'Son sipariş',
        govde: cagriSiparisOzeti(satirlar),
        saat: saat,
      ),
      SonHareketTuru.siparis,
    );
  }

  final hareket = await (db.select(db.ledgerEntries)
        ..where((t) => t.customerId.equals(customerId))
        ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)])
        ..limit(1))
      .getSingleOrNull();
  if (hareket == null) return (null, SonHareketTuru.siparis);

  final not = hareket.note?.trim();
  return (
    cagriSonHareketMetni(
      onEk: 'Son hareket',
      // Tasarım notu varsa notu yazar (`sonH.not || …`), yoksa hareketin etiketini.
      govde: not != null && not.isNotEmpty ? not : cagriHareketEtiketi(hareket.entryType),
      saat: cagriSaatMetni(DateTime.tryParse(hareket.occurredAt), simdi: simdi),
    ),
    SonHareketTuru.defter,
  );
}

/// Sipariş satırlarının tek satırlık dökümü — s-veri.jsx `siparisOzet`. Serbest satır (katalog
/// dışı tek seferlik iş) adet TAŞIMAZ, yalnız açıklamasıyla görünür.
///
/// `screens/orders`taki eşdeğerinden ÖDÜNÇ ALINMADI (o dosyanın başındaki sözleşme: sipariş
/// ekranları başka ajanların ekranlarıyla sembol paylaşmaz) — kural iki yerde de aynı, kaynağı
/// tasarımın kendisi.
String cagriSiparisOzeti(List<OrderLine> satirlar) {
  final parcalar = [
    for (final l in satirlar)
      (l.isCustom || l.productId == null) ? l.productName : '${l.productName} ×${l.qty}',
  ];
  return parcalar.isEmpty ? '—' : parcalar.join(' · ');
}

/// Defter hareketinin kart üzerindeki sözcüğü — s-musteriler.jsx `HAREKET_META` etiketleri
/// (Borç · Tahsilat · Alacak · Düzeltme). Tanınmayan tip "Borç" sayılır (tasarımın varsayılanı).
String cagriHareketEtiketi(String entryType) => switch (entryType) {
      'payment' => 'Tahsilat',
      'credit' => 'Alacak',
      'correction' => 'Düzeltme',
      _ => 'Borç',
    };

/// "Son sipariş: Damacana 19 L ×2 · 10:24" — ön ek, gövde ve saati tasarımdaki ayraçla
/// (U+00B7) birleştirir. Saat okunamıyorsa ayraç da düşer.
String cagriSonHareketMetni({
  required String onEk,
  required String govde,
  required String saat,
}) =>
    saat.isEmpty ? '$onEk: $govde' : '$onEk: $govde · $saat';
