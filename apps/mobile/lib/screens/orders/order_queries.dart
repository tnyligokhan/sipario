// Sipariş ekranlarının VERİ katmanı — ekrandan bağımsız Drift akışları ve saf yardımcılar.
// Tasarım kaynağı: tasarım s-siparisler.jsx + s-veri.jsx (`siparisTutar`, `siparisOzet`,
// `musteriKod`, `ODEME_TIPLERI`).
//
// NEDEN AYRI DOSYA: sorgu mantığı widget ağacından bağımsız olunca saf async testle sınanabiliyor
// (widget-test sahte zamanı drift akışlarında güvenilmez — Dilim 1 dersi). Ayrıca sipariş ekranları
// BAŞKA ajanların ekranlarından (müşteri/ürün listesi) tek bir sembol bile ödünç almaz; o dosyalar
// eşzamanlı yeniden yazılıyor.
//
// BU DOSYA SİPARİŞ LİSTESİNİN SORGUSUDUR: süzgeç · sıralama · borç · kalemler. İki bölüm 500
// satır kuralı için ayrıldı ve ikisi de buradan TEK YÖNLÜ dışa aktarılır (aşağıdaki `export`):
//   • `order_musteri_sorgulari.dart` — adres/telefon/geçmiş/arama, yani "müşteri hakkında ne
//     biliyoruz"; sipariş listesinin kurulmasına hiç girmez.
//   • `order_bicim.dart` — saf gösterim (kod rozeti, saat, ödeme etiketi); hiçbir import'u yok.
// YENİDEN İHRACAT BURADA BİLİNÇLİDİR (harita sorgularının aksine): o dosya bu dosyayı KULLANAN
// bir tüketiciydi, bunlar ise bu dosyadan ÇIKARILMIŞ parçalardır — çağıranların import satırını
// değiştirmek, bölmeyi bir davranış değişikliğine dönüştürme riski taşırdı.
//
// SÖZLEŞME: `watchOrders` / `OrderFilter` / `saatBicimi` / `odemeTipiEtiketi` imzaları DEĞİŞMEZ —
// mevcut testler ve başka ekranlar (kasa devri, defter, menü) bunları doğrudan çağırıyor.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../../data/app_database.dart';
// Gün sınırı (TR, sabit +03:00) TEK yerde tanımlıdır ve gün sonu ekranı da onu kullanır;
// ikinci bir kopya, aynı güne farklı sipariş sayan iki ekran demekti.
import '../isletme/gun_sonu_ozet.dart' show ayniTrGun;

export '../isletme/gun_sonu_ozet.dart' show bugunTr;
export 'order_bicim.dart';
export 'order_musteri_sorgulari.dart';

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

/// Sıralama seçenekleri — s-siparisler.jsx `SIRALA_SECENEK` + `rota`.
///
/// `rota` 2026-08-01'de eklendi: oto sıralama bitince ekran ELLE kipine düşüyordu (tutamaçlar
/// açılıyor, adres/not satırları gizleniyordu) — kullanıcı sadece sonucu görmek isterken kendini
/// bir düzenleme kipinde buluyordu. `rota` aynı sırayı (kalıcı `sort_index`) YAZMADAN gösterir;
/// düzeltmek isteyen `elle`yi kendisi seçer.
enum OrderSort { saat, tutar, ad, rota, elle }

/// Sıralama seçeneğinin sheet'te görünen etiketi (s-siparisler.jsx birebir).
String siralamaEtiketi(OrderSort s) => switch (s) {
      OrderSort.saat => 'Saate göre (yeni üstte)',
      OrderSort.tutar => 'Tutara göre (büyük üstte)',
      OrderSort.ad => 'Müşteri adına göre (A→Z)',
      OrderSort.rota => 'Rota sırası',
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
/// [gun]: TR takvim günü süzgeci (kullanıcı isteği 2026-08-04 — "teslim edilen siparişlerde ileri
/// geri yapılabilen tarih olmalı, bütün siparişleri görmek veri olarak yorucu"). null → süzme yok.
///
/// NEDEN SQL'DE DEĞİL DART'TA SÜZÜLÜYOR: gün sınırı bu üründe SABİT +03:00'tür (`ayniTrGun`) ve
/// `occurred_at` bir METİNDİR. Metin üzerinde aralık karşılaştırması, bütün satırların aynı ISO
/// biçiminde ('…Z') yazıldığını varsayardı; sunucudan offsetli ('+03:00') bir damga geldiği gün
/// sorgu SESSİZCE yanlış gün döndürürdü. Daha önemlisi: gün sonu ekranı ile sipariş listesi AYNI
/// güne aynı siparişleri saymak zorunda — iki ayrı gün-sınırı kodu, er geç ayrışan iki rakam
/// demektir ve bayinin defteriyle tutmayan her rakam ürüne olan güveni bitirir (BRIEF korku #2).
Stream<List<OrderListItem>> watchOrders(
  AppDatabase db,
  OrderFilter filter, {
  String? assignedTo,
  DateTime? gun,
}) {
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
  return q.watch().map((rows) => rows
      .where((r) => gun == null || ayniTrGun(r.readTable(db.orders).occurredAt, gun))
      .map((r) {
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
/// `rota` kipi `elle`nin SÜRÜKLEMESİZ hâlidir: daima kalıcı `sort_index`. Elle kipi bu yüzden
/// rotanın üstünden ince ayar yapmaya açılır — sürükleme sırası boşken ikisi aynı sırayı verir.
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
    case OrderSort.rota:
      // Kalıcı rota sırası — sürükleme sırası GÖRMEZDEN GELİNİR: bu kip yalnız gösterir,
      // iyimser bir düzenleme durumu taşımaz.
      return _kararliSirala(
          list,
          (a, b) => (a.order.sortIndex ?? _sonda).compareTo(b.order.sortIndex ?? _sonda));
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
/// Açık sipariş sayısı. [assignedTo] verilirse YALNIZ o kullanıcıya atananlar sayılır.
///
/// ⚠️ 2026-08-09 SAHA BULGUSU: bu sayaç kurye kısıtlamasını görmezden geliyordu. Kurye
/// ekranında başlık "Bugün 12 açık · yalnız size atananlar" diyor ama listede 2 sipariş
/// vardı — ekran kendi kendisiyle çelişiyordu. Liste süzülürken sayacın süzülmemesi,
/// kısıtlamayı yarım bırakmaktan da kötüdür: kurye "10 siparişim kayboldu" diye arar.
/// Kural: **bir listeyi süzen kapı, o listenin SAYACINI da süzmek zorundadır.**
Stream<int> watchAcikSiparisSayisi(AppDatabase db, {String? assignedTo}) {
  final q = db.select(db.orders)
    ..where((t) => t.status.equals('open') & t.deletedAt.isNull());
  if (assignedTo != null) {
    q.where((t) => t.assignedUserId.equals(assignedTo));
  }

  return q.watch().map((rows) => rows.length);
}

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
          for (final e in byOrder.entries) e.key: e.value.map(satirOzeti).join(', '),
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
// İPTAL ONAY AKIŞI (kullanıcı isteği 2026-08-22)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bekleyen iptal talebi. `null` = bekleyen talep yok.
///
/// SIPARIŞTE BİR ALAN DEĞİL, OLAYLARDAN TÜRETİLİR ([iptalTalebiCoz]) — gerekçe
/// `OrderRepository.iptalTalepEt` başlığında.
@immutable
class IptalTalebi {
  const IptalTalebi({required this.isteyenUserId, required this.occurredAt, this.gerekce});

  /// Talebi açan kullanıcı. `null` olabilir: talep, oturum kimliği henüz inmemiş bir cihazdan
  /// gelmiş olabilir. Ekran o zaman adı yazmaz — yanlış bir isim, bir kuryeyi yapmadığı
  /// talepten sorumlu tutar (çağrı atfındaki kuralın aynısı).
  final String? isteyenUserId;

  final String occurredAt;
  final String? gerekce;

  @override
  bool operator ==(Object other) =>
      other is IptalTalebi &&
      other.isteyenUserId == isteyenUserId &&
      other.occurredAt == occurredAt &&
      other.gerekce == gerekce;

  @override
  int get hashCode => Object.hash(isteyenUserId, occurredAt, gerekce);
}

/// Olay geçmişinden BEKLEYEN iptal talebini çözer — SAF, sunucu tarafıyla aynı kural.
///
/// KURAL: dört olay türü tek bir zaman çizgisinde okunur (`cancel_requested`, `cancel_rejected`,
/// `cancelled`, `delivered`). EN SON olan `cancel_requested` ise talep BEKLİYOR; başka bir şeyse
/// bekleyen talep yoktur. Böylece reddedilen bir talep yeniden açılabilir (müşteri fikir
/// değiştirdi) ve teslim edilmiş siparişte talep asılı kalmaz.
///
/// SIRA (occurredAt, id) ORTAK ANAHTARIDIR — `deriveAssignedUserId` ve `deriveSortIndex` ile
/// birebir aynı. Ayrışırlarsa iki cihaz aynı olay kümesinden farklı bir talep durumu türetir.
IptalTalebi? iptalTalebiCoz(List<OrderEvent> events) {
  const ilgili = {'cancel_requested', 'cancel_rejected', 'cancelled', 'delivered'};
  final zincir = events.where((e) => ilgili.contains(e.eventType)).toList()
    ..sort((a, b) {
      final byTime = a.occurredAt.compareTo(b.occurredAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  if (zincir.isEmpty) return null;

  final son = zincir.last;
  if (son.eventType != 'cancel_requested') return null;

  final ham = son.payload;
  final yuk = ham == null ? const <String, dynamic>{} : jsonDecode(ham) as Map<String, dynamic>;
  final isteyen = yuk['requested_by_user_id'];
  final gerekce = yuk['reason'];

  return IptalTalebi(
    isteyenUserId: isteyen is String && isteyen.isNotEmpty ? isteyen : null,
    occurredAt: son.occurredAt,
    gerekce: gerekce is String && gerekce.trim().isNotEmpty ? gerekce.trim() : null,
  );
}

/// Tek siparişin bekleyen iptal talebi — canlı.
Stream<IptalTalebi?> watchIptalTalebi(AppDatabase db, String orderId) =>
    (db.select(db.orderEvents)..where((t) => t.orderId.equals(orderId)))
        .watch()
        .map(iptalTalebiCoz);
