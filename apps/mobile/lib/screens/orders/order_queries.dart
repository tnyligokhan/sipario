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
    this.customerCode,
    this.customerBalanceKurus = 0,
  });

  final Order order;
  final String? customerName;

  /// Müşterinin sıra kodu (`customers.code`) — satır rozetinin bir seçeneği.
  final int? customerCode;

  /// "Borçlu" sekmesinin dayanağı (müşteri defter bakiyesi önbelleği).
  final int customerBalanceKurus;
}

/// Kurye süzgecinde "kuryesi atanmamış siparişler" seçeneğinin id yerine geçen değeri.
/// Gerçek bir kullanıcı id'si (UUIDv7) ile ÇAKIŞMAZ — uuid biçiminde değildir.
const String kAtanmamisKurye = '__atanmamis__';

/// Sipariş listesi sorgusu — müşteri adıyla birlikte, en yeni önce. Ekrandan bağımsız fonksiyon:
/// sorgu mantığı saf async testle sınanır.
/// SÖZLEŞME: testler doğrudan çağırır — imza/davranış DEĞİŞMEZ.
///
/// [assignedTo]: kurye süzgeci (saha hatası 6). null → süzme yok. [kAtanmamisKurye] → kuryesi
/// olmayanlar. Diğer değerler kullanıcı id'sidir; PATRON da bir kurye gibi süzülebilir (kullanıcı
/// kararı: "patronun kendisi de aslında bir kurye olarak görünmeli") — sorgu role bakmaz, yalnız
/// `orders.assigned_user_id`e bakar, dolayısıyla bu kendiliğinden çalışır.
Stream<List<OrderListItem>> watchOrders(AppDatabase db, OrderFilter filter, {String? assignedTo}) {
  final q = db.select(db.orders).join([
    leftOuterJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
  ]);
  q.where(db.orders.deletedAt.isNull());
  if (assignedTo == kAtanmamisKurye) {
    q.where(db.orders.assignedUserId.isNull());
  } else if (assignedTo != null) {
    q.where(db.orders.assignedUserId.equals(assignedTo));
  }
  switch (filter) {
    case OrderFilter.acik:
      q.where(db.orders.status.equals('open'));
    case OrderFilter.teslim:
      q.where(db.orders.status.equals('delivered'));
    case OrderFilter.borclu:
      // SAHA HATASI (2026-07-27): sekme yalnız "bakiyesi borçta" diyordu ve TESLİM EDİLMEMİŞ
      // siparişleri de listeliyordu. Teslim edilmemiş mal borç değildir — deftere borç teslim
      // anında yazılır (`deliver` → debit). Üç şartın kesişimi: teslim edilmiş · tahsilat tutarın
      // altında · müşteri bakiyesi hâlâ borçta.
      //
      // İkinci şart neden `payment_type = 'veresiye'` DEĞİL: kısmi ödeme "50 ver kalanı yaz"
      // teslimi `nakit` taşır ama borç bırakır; tipe bakan sorgu onu kaçırırdı. Ölçüt defterin
      // kendisidir — siparişe bağlı `payment` toplamı (negatif) + tutar > 0 ise ödenmemiş bakiye
      // var. Ters kayıtla iptal edilen tahsilat da toplamda kendiliğinden geri döner.
      // Müşterisiz (tezgâh) sipariş kimseye borç yazmaz → join null, listeye girmez.
      //
      // `discount` de sayılır (kapıda iskonto, 2026-07-30): kırılan tutar tahsil EDİLMEMİŞTİR ama
      // borç da DEĞİLDİR — bayi "borçlu gösterme" dediği için yazılmıştır. Yalnız `payment`a
      // bakan sorgu, 420 ₺lik siparişten 400 alıp 20 kıran teslimi ilelebet "borçlu" gösterirdi;
      // yani kullanıcının istediği şeyin tam tersini yapardı. İki tip de NEGATİFTİR, toplama
      // aynı işaretle girer.
      final tahsilat = subqueryExpression<int>(
        db.selectOnly(db.ledgerEntries)
          ..addColumns([db.ledgerEntries.amountKurus.sum()])
          ..where(db.ledgerEntries.relatedOrderId.equalsExp(db.orders.id) &
              db.ledgerEntries.entryType.isIn(siparisKapatanTipler)),
      );
      q.where(db.orders.status.equals('delivered'));
      q.where((coalesce([tahsilat, const Constant(0)]) + db.orders.totalKurus)
          .isBiggerThanValue(0));
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
          customerCode: musteri?.code,
          customerBalanceKurus: musteri?.balanceKurus ?? 0,
        );
      }).toList());
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sipariş başına ÖDENMEMİŞ kalan (borç)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// orderId → o siparişe işlenmiş TAHSİLAT toplamı (POZİTİF kuruş).
///
/// SAHA HATASI (2026-07-29): "Borçlu" sekmesindeki satır siparişin TUTARINI yazıyordu, borcunu
/// değil — veresiye teslim edilmiş bir siparişte ikisi aynı sayı olduğu için kimse fark etmemişti,
/// ama kısmi ödemede satır 500 ₺ derken borç 200 ₺ oluyordu. Bayi kalan borcu ancak "Tahsilat Al"a
/// dokununca görebiliyordu; borcu görmek için bir tahsilat akışına girmek zorunda kalmak yanlış.
///
/// NEDEN AYRI AKIŞ (watchOrders'a kolon olarak eklenmedi): korelasyonlu alt sorgu HER SEKMEDE her
/// satır için koşardı. Bu akış defteri TEK taramada gruplayıp Dart tarafında eşler — `satirlar` /
/// `adresler` / `telefonlar` akışlarının deseninin aynısı, ve `watchOrders` sözleşmesi (testler
/// doğrudan çağırıyor) hiç değişmez.
///
/// Defterde `payment` satırları NEGATİFTİR (bakiyeyi düşürürler); burada işaret çevrilir çünkü
/// çağıran "ne kadar tahsil edildi" sorusunu sorar. Ters kayıtla iptal edilen tahsilat toplamda
/// kendiliğinden geri döner (append-only: silme yok, ters kayıt var).
///
/// İSKONTO da (`discount`) bu toplama girer — bkz. [siparisKapatanTipler]. Çağıranların hepsi
/// "bu siparişten borç kaldı mı" sorusunu sorar; kırılan tutar kalan borcun İÇİNDE sayılırsa
/// kapıda iskonto yapılmış sipariş sonsuza kadar borçlu görünürdü. Kasa rakamları bu akıştan
/// DEĞİL `DayEndRepository.kasaOzeti`den gelir — orası hâlâ yalnız `payment_type` taşıyan
/// satırları toplar, yani iskonto kasaya sızmaz.
Stream<Map<String, int>> watchSiparisTahsilatlari(AppDatabase db) {
  final toplam = db.ledgerEntries.amountKurus.sum();
  final q = db.selectOnly(db.ledgerEntries)
    ..addColumns([db.ledgerEntries.relatedOrderId, toplam])
    ..where(db.ledgerEntries.entryType.isIn(siparisKapatanTipler) &
        db.ledgerEntries.relatedOrderId.isNotNull())
    ..groupBy([db.ledgerEntries.relatedOrderId]);
  return q.watch().map((rows) {
    final map = <String, int>{};
    for (final r in rows) {
      final id = r.read(db.ledgerEntries.relatedOrderId);
      if (id != null) map[id] = -(r.read(toplam) ?? 0);
    }
    return map;
  });
}

/// Siparişin borcunu KAPATAN defter tipleri: alınan para (`payment`) ve kırılan tutar
/// (`discount`). İkisi de negatiftir; ikisi de o siparişten geriye borç bırakmaz. Liste sorgusu,
/// toplu akış ve tek-sipariş akışı AYNI listeyi kullanır — üç yerde ayrı ayrı yazılsaydı, biri
/// güncellenmediğinde sipariş listesi ile detay ekranı farklı borç konuşurdu.
const siparisKapatanTipler = ['payment', 'discount'];

/// Tek siparişin tahsilat toplamı (detay ekranı — liste akışını tek kayıt için kurmaya değmez).
Stream<int> watchSiparisTahsilati(AppDatabase db, String orderId) {
  final toplam = db.ledgerEntries.amountKurus.sum();
  final q = db.selectOnly(db.ledgerEntries)
    ..addColumns([toplam])
    ..where(db.ledgerEntries.entryType.isIn(siparisKapatanTipler) &
        db.ledgerEntries.relatedOrderId.equals(orderId));
  return q.watchSingleOrNull().map((r) => -(r?.read(toplam) ?? 0));
}

/// Bir siparişin ÖDENMEMİŞ kalanı. Saf fonksiyon — gösterimin dayanağı budur ve widget kurmadan
/// test edilir.
///
/// İKİ KURAL:
/// 1. TESLİM EDİLMEMİŞ sipariş borç DEĞİLDİR (2026-07-27 kararının aynısı: deftere borç teslim
///    anında yazılır). Açık siparişte 0 döner — yoksa liste "borç" diyerek henüz doğmamış bir
///    alacağı rapor ederdi. İptal edilen siparişte de 0.
/// 2. FAZLA tahsilat bu siparişin borcunu eksiye çevirmez, 0 döner: fazlası müşterinin ÖNCEKİ
///    borcunu kapatır ve o müşteri bakiyesinde görünür — siparişe "−50 ₺ borç" yazmak yanlış yerde
///    doğru sayı göstermek olurdu.
///
/// [tahsilKurus] siparişi KAPATAN toplamdır ([siparisKapatanTipler]): alınan para + kapıda kırılan
/// iskonto. İskonto edilmiş sipariş bu yüzden 0 borç yazar — kullanıcının "borçlu gösterme"
/// dediği davranışın sayısal karşılığı burasıdır.
int siparisKalanBorcu({
  required String durum,
  required int toplamKurus,
  required int tahsilKurus,
}) {
  if (durum != 'delivered') return 0;
  final kalan = toplamKurus - tahsilKurus;
  return kalan > 0 ? kalan : 0;
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

/// Sipariş satırındaki kod tercihi (`tenant_settings.order_code_display`), canlı.
///
/// Ayar KİRACI düzeyindedir ve senkronla iner; cihaz-yerel olsaydı iki telefonlu bir bayide
/// aynı liste iki farklı numara gösterirdi. Satır henüz senkronlanmamışsa varsayılan `musteri`.
Stream<String> watchSiparisKoduTercihi(AppDatabase db) =>
    (db.select(db.tenantSettings)..where((t) => t.id.equals(1)))
        .watchSingleOrNull()
        .map((r) => r?.orderCodeDisplay ?? 'musteri');

/// Üst başlıktaki "Bugün N açık" sayacı (s-siparisler.jsx `Ust alt=`).
Stream<int> watchAcikSiparisSayisi(AppDatabase db) =>
    (db.select(db.orders)..where((t) => t.status.equals('open') & t.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.length);

// HARİTA SORGULARI BU DOSYADA DEĞİL: `harita_sorgulari.dart`. Bölüm 500 satır kuralı için
// ayrıldı ve sipariş listesinin sorgularıyla hiçbir şey paylaşmıyordu; oradan buraya TEK YÖNLÜ
// bağımlılık var (harita `OrderListItem` / `siparisleriSirala` / `satirKodu` / `AdresBilgi`
// kullanır). Yeniden ihracat YAPILMAZ — tek doğru import kalsın.

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

/// Müşteri kodu rozeti — "102".
///
/// ESKİ HÂLİ (2026-07-29'a kadar): kod UUID'nin son üç RAKAMINDAN türetiliyordu ve "M-007"
/// yazıyordu. Bu bir kimlik değil, bir SÜSTÜ: iki müşteri aynı üçlüyü alabiliyordu, sayı hiçbir
/// sırayı anlatmıyordu ve bayi "102 numaralı abone" diyemiyordu. Artık kod sunucudan gelen
/// gerçek sıra numarasıdır (`customers.code`).
///
/// Kod YOKSA null döner ve çağıran rozeti HİÇ çizmez — sıfır ya da "M-000" gibi uydurma bir
/// numara basmak, senkronlanmamış bir müşteriyi var olmayan bir kodla anmak olurdu.
String? musteriKodu(int? code) => code == null ? null : '$code';

/// Sipariş kodu rozeti — "#248". Kullanıcı isteği: "her siparişin bir kodu olmalı #xxx gibi".
String? siparisKodu(int? code) => code == null ? null : '#$code';

/// Sipariş satırında hangi kod görünecek? Bayi tercihi (`tenant_settings.order_code_display`).
///
/// Tek karar noktası: liste satırı, sipariş detayı ve testler aynı fonksiyonu çağırır. Tanınmayan
/// bir değer (eski/yeni istemci ayrışması) MÜŞTERİ koduna düşer — sunucudaki beyaz listenin aynısı.
/// Seçilen kod yoksa (ör. tezgâh satışında müşteri kodu) DİĞERİNE düşülür: satırda hiç numara
/// olmamasındansa var olan numara gösterilir.
String? satirKodu({
  required String tercih,
  required int? musteriCode,
  required int? siparisCode,
}) {
  final musteri = musteriKodu(musteriCode);
  final siparis = siparisKodu(siparisCode);
  return tercih == 'siparis' ? (siparis ?? musteri) : (musteri ?? siparis);
}

/// Açık siparişin ÜZERİNDEN GEÇEN süre — "12 dk" · "1 sa 5 dk" · "2 gün".
///
/// Kullanıcı isteği (2026-07-29): açık siparişte kartta "Açık" yazmak yerine siparişin kaç
/// dakikadır beklediği görünsün. Gerekçe sahadan: "açık" bilgisi zaten listenin adında var
/// (Açık sekmesi), asıl merak edilen BEKLEME SÜRESİDİR — geciken teslimat böyle fark edilir.
///
/// Kurallar:
///  • 1 dakikadan yeni → "yeni" (0 dk yazmak siparişin daha girilmediğini düşündürür).
///  • 60 dakikaya kadar dakika; sonrasında saat + dakika (ilk gün dakika ÖNEMLİDİR — 1 sa 5 dk
///    ile 1 sa 55 dk arasındaki fark bayinin telefonla özür dileyip dilemeyeceğini belirler).
///  • 24 saatten sonra gün (o noktada dakika gürültüdür).
///  • İLERİ tarihli damga "yeni" sayılır: cihaz saati ileri kaymış olabilir ve "−3 dk" yazmak
///    veriye güveni sarsar (senkron zaten sunucu saatiyle düzeltilmiş damga yazar).
String gecenSure(String iso, {DateTime? simdi}) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final fark = (simdi ?? DateTime.now()).difference(t.toLocal());
  if (fark.inMinutes < 1) return 'yeni';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dk';
  if (fark.inHours < 24) {
    final dk = fark.inMinutes % 60;
    return dk == 0 ? '${fark.inHours} sa' : '${fark.inHours} sa $dk dk';
  }
  return '${fark.inDays} gün';
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
