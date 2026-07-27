// Sipariş ekranlarının VERİ katmanı — ekrandan bağımsız Drift akışları ve saf yardımcılar.
// Tasarım kaynağı: tasarım s-siparisler.jsx + s-veri.jsx (`siparisTutar`, `siparisOzet`,
// `birincilAdres`, `birincilTel`, `musteriKod`, `ODEME_TIPLERI`).
//
// NEDEN AYRI DOSYA: sorgu mantığı widget ağacından bağımsız olunca saf async testle sınanabiliyor
// (widget-test sahte zamanı drift akışlarında güvenilmez — Dilim 1 dersi). Ayrıca sipariş ekranları
// BAŞKA ajanların ekranlarından (müşteri/ürün listesi) tek bir sembol bile ödünç almaz; o dosyalar
// eşzamanlı yeniden yazılıyor.
//
// SÖZLEŞME: `watchOrders` / `OrderFilter` / `saatBicimi` / `odemeTipiEtiketi` imzaları DEĞİŞMEZ —
// mevcut testler ve başka ekranlar (kasa devri, defter, menü) bunları doğrudan çağırıyor.

import 'package:drift/drift.dart';

import '../../data/app_database.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sipariş listesi
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Segment filtresi — CSS `.segtab`: Açık · Teslim · Borçlu · Tümü (tasarımın dört sekmesi).
///
/// `benim` DEĞERİ KALDIRILDI (2026-07-26): kuryenin "Benim" sekmesi tasarımda yoktu ve atama
/// kullanmayan bayide boş bir sekme karşılıyordu. Sekme kalkınca sorgu dalının da tek çağıranı
/// kalmadı; enum değerini "ileride gerekebilir" diye tutmak ERİŞİLEMEYEN KOD bırakmak olurdu
/// (bu vardiyanın dersi). Kuryeye atanmış işler gerekirse `assignedTo` parametresi duruyor.
enum OrderFilter { acik, teslim, borclu, tumu }

/// Sıralama seçenekleri — s-siparisler.jsx `SIRALA_SECENEK`.
enum OrderSort { saat, tutar, ad, elle }

/// Sıralama seçeneğinin sheet'te görünen etiketi (s-siparisler.jsx birebir).
String siralamaEtiketi(OrderSort s) => switch (s) {
      OrderSort.saat => 'Saate göre (yeni üstte)',
      OrderSort.tutar => 'Tutara göre (büyük üstte)',
      OrderSort.ad => 'Müşteri adına göre (A→Z)',
      OrderSort.elle => 'Elle sırala (sürükle-bırak)',
    };

/// Liste satırının ihtiyaç duyduğu her şey tek nesnede. `order` + `customerName` alanları
/// SÖZLEŞMEDİR (mevcut testler okur); kalanlar additive.
class OrderListItem {
  OrderListItem({
    required this.order,
    this.customerName,
    this.customerBalanceKurus = 0,
  });

  final Order order;
  final String? customerName;

  /// "Borçlu" sekmesinin dayanağı (müşteri defter bakiyesi önbelleği).
  final int customerBalanceKurus;
}

/// Sipariş listesi sorgusu — müşteri adıyla birlikte, en yeni önce. Ekrandan bağımsız fonksiyon:
/// sorgu mantığı saf async testle sınanır.
/// SÖZLEŞME: testler doğrudan çağırır — imza/davranış DEĞİŞMEZ.
Stream<List<OrderListItem>> watchOrders(AppDatabase db, OrderFilter filter, {String? assignedTo}) {
  final q = db.select(db.orders).join([
    leftOuterJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
  ]);
  q.where(db.orders.deletedAt.isNull());
  switch (filter) {
    case OrderFilter.acik:
      q.where(db.orders.status.equals('open'));
    case OrderFilter.teslim:
      q.where(db.orders.status.equals('delivered'));
    case OrderFilter.borclu:
      // Tasarımdaki "Borçlu" sekmesi: siparişin müşterisinin defter bakiyesi borçtaysa.
      // Müşterisiz (tezgâh) sipariş kimseye borç yazmaz → listeye girmez.
      q.where(db.customers.balanceKurus.isBiggerThanValue(0));
    case OrderFilter.tumu:
      break;
  }
  q.orderBy([OrderingTerm.desc(db.orders.occurredAt), OrderingTerm.desc(db.orders.id)]);
  return q.watch().map((rows) => rows.map((r) {
        final musteri = r.readTableOrNull(db.customers);
        return OrderListItem(
          order: r.readTable(db.orders),
          customerName: musteri?.name,
          customerBalanceKurus: musteri?.balanceKurus ?? 0,
        );
      }).toList());
}

/// Sıralamayı listeye UYGULAR (sorgu değil — `watchOrders` sözleşmesine dokunmamak için Dart
/// tarafında). `elle` kipinde önce kullanıcının SÜRÜKLEDİĞİ [elleSira] (sipariş id'leri) geçerlidir;
/// o boşsa kalıcı `orders.sort_index` önbelleği okunur. İki kaynak KARIŞTIRILMAZ — biri konum
/// (0,1,2…), diğeri seyrek sıra numarası; aynı karşılaştırmaya sokulursa sıra tutarsızlaşır.
///
/// Sıralama KARARLIDIR: anahtarı eşit olan satırlar geldikleri sırayı korur (`List.sort` kararlı
/// değil — sipariş listesi her akış tikinde titrerdi).
List<OrderListItem> siparisleriSirala(
  List<OrderListItem> list,
  OrderSort sort, {
  List<String> elleSira = const [],
}) {
  switch (sort) {
    case OrderSort.saat:
      return [...list]; // sorgu zaten occurred_at DESC döner
    case OrderSort.tutar:
      return _kararliSirala(list, (a, b) => b.order.totalKurus.compareTo(a.order.totalKurus));
    case OrderSort.ad:
      return _kararliSirala(
          list,
          (a, b) => (a.customerName ?? '￿')
              .toLowerCase()
              .compareTo((b.customerName ?? '￿').toLowerCase()));
    case OrderSort.elle:
      final int? Function(OrderListItem) anahtar;
      if (elleSira.isNotEmpty) {
        final yer = {for (var i = 0; i < elleSira.length; i++) elleSira[i]: i};
        anahtar = (x) => yer[x.order.id];
      } else {
        anahtar = (x) => x.order.sortIndex;
      }
      return _kararliSirala(
          list, (a, b) => (anahtar(a) ?? _sonda).compareTo(anahtar(b) ?? _sonda));
  }
}

/// Sıralanmamış satırlar listenin SONUNA gider (yeni gelen sipariş rotanın ortasına düşmesin).
const int _sonda = 1 << 30;

/// Kararlı sıralama — eşit anahtarlarda özgün sıra korunur.
List<OrderListItem> _kararliSirala(
  List<OrderListItem> list,
  int Function(OrderListItem a, OrderListItem b) karsilastir,
) {
  final indeksli = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indeksli.sort((a, b) {
    final c = karsilastir(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indeksli) e.$2];
}

/// Elle sıralamanın kalıcı yazımı için: verilen sırayı `orders.sort_index` değerlerine çevirir.
/// Seyrek adımlar (0, 10, 20…) kullanılır — araya sipariş eklemek tüm listeyi yeniden
/// numaralandırmayı gerektirmesin. Yalnız DEĞİŞEN siparişler döner (gereksiz olay yazılmasın).
Map<String, int> elleSiraYazimi(List<OrderListItem> siraliListe) {
  final degisen = <String, int>{};
  for (var i = 0; i < siraliListe.length; i++) {
    final yeni = i * 10;
    if (siraliListe[i].order.sortIndex != yeni) degisen[siraliListe[i].order.id] = yeni;
  }
  return degisen;
}

/// Üst başlıktaki "Bugün N açık" sayacı (s-siparisler.jsx `Ust alt=`).
Stream<int> watchAcikSiparisSayisi(AppDatabase db) =>
    (db.select(db.orders)..where((t) => t.status.equals('open') & t.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.length);

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sipariş kalemleri
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Sipariş başına AKTİF satırlar (silinmişler hariç), sipariş id'sine göre gruplu.
/// Liste satırındaki ürün dökümü (CSS `.srow-urunler`) ve detay kartı bunu okur.
Stream<Map<String, List<OrderLine>>> watchOrderLinesByOrder(AppDatabase db) {
  final q = db.select(db.orderLines)..where((l) => l.deletedAt.isNull());
  return q.watch().map((lines) {
    final byOrder = <String, List<OrderLine>>{};
    for (final l in lines) {
      byOrder.putIfAbsent(l.orderId, () => []).add(l);
    }
    return byOrder;
  });
}

/// Tek siparişin aktif satırları.
Stream<List<OrderLine>> watchOrderLines(AppDatabase db, String orderId) =>
    (db.select(db.orderLines)..where((t) => t.orderId.equals(orderId) & t.deletedAt.isNull()))
        .watch();

/// Sipariş başına tek satırlık ürün özeti ("2 × 19L Damacana · 1 × 10L"). Geriye dönük uyumluluk
/// için korunur — yeni tasarım dökümü madde madde çizer, bu akış başka ekranlarda kullanılabilir.
Stream<Map<String, String>> watchOrderItemsSummary(AppDatabase db) =>
    watchOrderLinesByOrder(db).map((byOrder) => {
          for (final e in byOrder.entries) e.key: e.value.map(satirOzeti).join(' · '),
        });

/// Bir satırın liste dökümündeki yazımı — s-veri.jsx `siparisOzet`. SERBEST satır (productId null)
/// adet taşımaz, yalnız açıklamasıyla görünür (tasarımda `.srow-uitem` serbest satırı adetsiz yazar).
String satirOzeti(OrderLine l) => serbestMi(l) ? l.productName : '${l.productName} ×${l.qty}';

/// Serbest satır = katalog dışı tek seferlik iş. SÖZLEŞME (backend ajanıyla): `OrderLines.isCustom`.
/// `productId == null` YEDEK ölçüttür: bayrak şemaya v8'de geldi, ondan önce yazılmış serbest
/// satırlarda `false` durur — eski kayıtlar da doğru görünsün. (Silinmiş ürünün satırı da null
/// productId taşır; onu serbest saymak yalnız GÖSTERİMİ etkiler, para hesabına dokunmaz.)
bool serbestMi(OrderLine l) => l.isCustom || l.productId == null;

/// Satırlardan toplam (int kuruş). orders.totalKurus önbelleği ile aynı sonucu verir; henüz
/// kaydedilmemiş taslaklarda tek hesap yolu budur.
int satirlarToplami(List<OrderLine> lines) =>
    lines.fold<int>(0, (s, l) => s + l.lineTotalKurus);

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Müşteri yardımcı akışları (adres · telefon · geçmiş)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Müşterinin birincil adresi — s-veri.jsx `birincilAdres`.
class AdresBilgi {
  const AdresBilgi({required this.metin, this.bolge, this.lat, this.lng});
  final String metin;

  /// Semt/bölge (`CustomerAddresses.region`). Tasarım adresi "metin — bölge" diye yazar.
  final String? bolge;

  final double? lat;
  final double? lng;

  /// CSS `.srow-adres` / `.sdx-adres` — tasarımın `[metin, bolge].filter(…).join(' — ')` yazımı.
  /// Tasarımdaki gibi boş ve "—" değerler ELENİR (kullanıcı "Adres — —" görmesin).
  String get tamMetin =>
      [metin, bolge].where((x) => x != null && x.isNotEmpty && x != '—').join(' — ');

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

/// Sipariş detayındaki "Geçmiş Siparişler" (CSS `.gec-*`): aynı müşterinin BU sipariş dışındaki
/// siparişleri, en yeni önce.
Stream<List<Order>> watchGecmisSiparisler(AppDatabase db, String customerId, String haricOrderId) {
  final q = db.select(db.orders)
    ..where((t) =>
        t.customerId.equals(customerId) & t.id.equals(haricOrderId).not() & t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)]);
  return q.watch();
}

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

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Saf gösterim yardımcıları
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Müşteri kodu rozeti — s-siparisler.jsx `musteriKod`. Tasarım artan tamsayı id'den "M-007"
/// üretiyordu; bizde id UUIDv7 olduğundan rakamlarının SON ÜÇÜ alınır (rozet kısa kalsın).
/// Yalnız GÖSTERİMDİR — hiçbir yerde anahtar olarak kullanılmaz.
String? musteriKod(String? customerId) {
  if (customerId == null) return null;
  final rakam = customerId.replaceAll(RegExp(r'\D'), '');
  if (rakam.isEmpty) return 'M-000';
  final son = rakam.length <= 3 ? rakam.padLeft(3, '0') : rakam.substring(rakam.length - 3);
  return 'M-$son';
}

/// Teslim sheet'inde ÇİZİLEN ödeme karoları (tasarım `ODEME_TIPLERI`) — dördü de HER ZAMAN
/// görünür. Müşterisiz siparişte veresiye karosu listeden DÜŞMEZ, PASİF çizilir
/// (s-siparisler.jsx:620 `disabled` + `opacity .45`): seçeneği gizlemek kullanıcıya "veresiye
/// yok" dedirtir, pasif göstermek "burada kullanılamaz" der ve yanındaki açıklama okunur olur.
const List<String> odemeTipleri = ['nakit', 'kart', 'havale', 'veresiye'];

/// Teslimde SEÇİLEBİLİR ödeme tipleri. veresiye MÜŞTERİ ZORUNLU: borç bir müşteriye yazılır —
/// müşterisiz veresiye kimseye ait olmayan bir borç kaydı üretirdi (defter tutarlılığı;
/// tezgâh satışındaki veresiye kilidi budur). Karo GÖSTERİMİ için [odemeTipleri] kullanılır.
List<String> teslimOdemeTipleri({required bool musteriVar}) =>
    [for (final tip in odemeTipleri) if (odemeTipiSecilebilir(tip, musteriVar: musteriVar)) tip];

/// Tek karonun kilidi — pasif çizim ve dokunma engeli aynı kuraldan okur (iki yerde ayrı
/// koşul yazılırsa görünüşte pasif ama seçilebilir bir karo çıkar).
bool odemeTipiSecilebilir(String tip, {required bool musteriVar}) =>
    tip != 'veresiye' || musteriVar;

/// Ödeme tipinin ekran etiketi (veri değeri değişmez — DB'de 'nakit'/'veresiye'/... durur).
String odemeTipiEtiketi(String paymentType) => switch (paymentType) {
      'nakit' => 'Nakit',
      'kart' => 'Kart',
      'havale' => 'Havale',
      'veresiye' => 'Veresiye',
      _ => paymentType,
    };

/// ISO8601 occurred_at → "14:35" (bugünse) veya "17.07 14:35". Saat cihaz yerelinde gösterilir;
/// kayıtta UTC/sunucu-düzeltilmiş metin OLDUĞU GİBİ durur (DECISIONS — gösterim veriyi değiştirmez).
String saatBicimi(String iso, {DateTime? simdi}) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final local = t.toLocal();
  final now = simdi ?? DateTime.now();
  final saat = '${_ikiHane(local.hour)}:${_ikiHane(local.minute)}';
  final ayniGun = local.year == now.year && local.month == now.month && local.day == now.day;
  return ayniGun ? saat : '${_ikiHane(local.day)}.${_ikiHane(local.month)} $saat';
}

String _ikiHane(int n) => n.toString().padLeft(2, '0');
