// MÜŞTERİNİN SİPARİŞ GEÇMİŞİ — müşteri kartındaki KISA bölüm + "Tümü" ekranı.
//
// NEDEN LİMİT: müşteri kartı bir ÖZETTİR; yıllardır alışveriş yapan bir müşteride sınırsız liste,
// kartın altındaki her şeyi (defter hareketleri, tehlikeli işlemler) erişilemez derinliğe iter.
// Kart son [kKartSiparisLimiti] siparişi gösterir, gerisi ayrı ekranda durur.
//
// NEDEN AYRI DOSYA: `customer_detail_screen.dart` (400) ve `customer_detail_cards.dart` (421)
// depo sınırına (500) yakın. Ayrıca bu bölüm KENDİ akışlarına abone bağımsız bir parçadır.
//
// SATIR BİLEŞENİ KOPYALANMADI: hem kart hem "Tümü" ekranı sipariş listesinin satırını
// (`SiparisSatiri`) çizer. İki yüzeyin aynı siparişi farklı biçimde göstermesi, bayiye iki farklı
// ürün gibi görünür; ayrıca kalem dökümü/borç pili mantığı orada bir kez çözülmüş durumda.

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_detail_screen.dart' show siparisDetaySheetAc;
import '../orders/order_queries.dart';
import '../orders/order_row.dart';

/// Müşteri kartında çizilen azami sipariş sayısı.
const int kKartSiparisLimiti = 3;

/// Müşterinin siparişleri — en yeni önce, silinmişler hariç. [limit] verilirse yalnız o kadarı.
///
/// `watchGecmisSiparisler` KULLANILMADI: o akış "bu sipariş HARİÇ" diye kurulmuş (sipariş
/// detayından açılır) ve dışlanacak bir sipariş yokken çağrılamaz. Sınır SQL'de uygulanır —
/// listeyi çekip Dart'ta kesmek, 900 siparişli müşteride her akış tikinde 900 satır taşırdı.
Stream<List<Order>> watchMusteriSiparisleri(
  AppDatabase db,
  String customerId, {
  int? limit,
}) {
  // İKİ AYRI `where` (tek `&` ifadesi değil): drift art arda gelen koşulları AND'ler ve bu
  // dosya drift'i `show OrderingTerm` ile DAR alıyor — `Expression<bool>` üzerindeki `&`
  // operatörünü sağlayan uzantı o yüzden kapsamda değil. Drift'i tümüyle almak Material'daki
  // `Column`/`Table` ile çakışırdı; zincirleme, deponun başka yerlerinde de kullanılan biçim.
  final q = db.select(db.orders)
    ..where((t) => t.customerId.equals(customerId))
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)]);
  if (limit != null) q.limit(limit);
  return q.watch();
}

/// Müşterinin TOPLAM sipariş sayısı.
///
/// AYRI AKIŞ olmak zorunda: kart yalnız 3 satır okuduğu için toplamı o listeden türetemez ve
/// "Son 3" yazarken kaçının gizlendiğini söyleyemezdi. Gizlenen miktarı söylemeyen bir kısaltma,
/// bayiye "müşterinin 3 siparişi var" dedirtir.
Stream<int> watchMusteriSiparisSayisi(AppDatabase db, String customerId) =>
    (db.select(db.orders)
          ..where((t) => t.customerId.equals(customerId))
          ..where((t) => t.deletedAt.isNull()))
        .watch()
        .map((r) => r.length);

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Kart bölümü
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Müşteri kartındaki "Sipariş Geçmişi" bölümü — son [kKartSiparisLimiti] sipariş + tümü girişi.
/// Hiç sipariş yoksa HİÇ çizilmez (sipariş detayındaki geçmiş bölümünün deseni): boş bir kutu,
/// zaten "Hareket yok" diyen defter bölümünün üstünde ikinci bir boşluk olurdu.
class MusteriSiparisGecmisi extends StatelessWidget {
  const MusteriSiparisGecmisi({
    super.key,
    required this.db,
    required this.customerId,
    required this.musteriAdi,
    this.musteriCode,
    this.writable = true,
    this.canAssign = false,
  });

  final AppDatabase db;
  final String customerId;
  final String musteriAdi;
  final int? musteriCode;

  /// Salt-okunur kip — detay sheet'ine olduğu gibi geçer (bölüm kendi başına yazma yapmaz).
  final bool writable;
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<int>(
      stream: watchMusteriSiparisSayisi(db, customerId),
      initialData: 0,
      builder: (context, sayiSnap) {
        final toplam = sayiSnap.data ?? 0;
        if (toplam == 0) return const SizedBox.shrink();
        return StreamBuilder<List<Order>>(
          stream: watchMusteriSiparisleri(db, customerId, limit: kKartSiparisLimiti),
          initialData: const [],
          builder: (context, snap) {
            final siparisler = snap.data ?? const <Order>[];
            if (siparisler.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SipBolumBaslik(
                  'Sipariş Geçmişi',
                  sag: Text(
                    _sayacMetni(toplam),
                    style: SipText.metin(11, w: 700).copyWith(color: t.muted),
                  ),
                ),
                MusteriSiparisListesi(
                  db: db,
                  siparisler: siparisler,
                  musteriAdi: musteriAdi,
                  musteriCode: musteriCode,
                  writable: writable,
                  canAssign: canAssign,
                ),
                // GİRİŞ YALNIZ GİZLENEN VARSA: toplam 3 ya da azsa listenin tamamı zaten yukarıda
                // duruyor; "Tümünü gör" aynı üç satırı ikinci kez açan ölü bir kapı olurdu.
                if (toplam > kKartSiparisLimiti)
                  _TumunuGor(
                    kalan: toplam - kKartSiparisLimiti,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MusteriSiparisleriEkrani(
                        db: db,
                        customerId: customerId,
                        musteriAdi: musteriAdi,
                        musteriCode: musteriCode,
                        writable: writable,
                        canAssign: canAssign,
                      ),
                    )),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Başlığın sağındaki sayaç. Kısaltma yapılmadıysa yalnız sayı yazılır (sipariş detayındaki
  /// `.sdx-adet` deseni); yapıldıysa NE KADARININ gizlendiği açıkça söylenir.
  static String _sayacMetni(int toplam) => toplam > kKartSiparisLimiti
      ? 'Son $kKartSiparisLimiti / toplam $toplam'
      : '$toplam';
}

/// CSS `.md-duzelt-link` kalıbının aynısı — bölümün altındaki metin girişi.
class _TumunuGor extends StatelessWidget {
  const _TumunuGor({required this.kalan, required this.onTap});

  /// Ekranda görünmeyen sipariş sayısı — girişin ne vaat ettiğini rakamla söyler.
  final int kalan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.sm),
      child: SipDokun(
        onTap: onTap,
        zemin: t.surface,
        radius: SipRadius.br2,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Tümünü gör',
                style: SipText.metin(13, w: 700).copyWith(color: t.accent),
              ),
            ),
            Text(
              '+$kalan',
              style: SipText.metin(12, w: 700).copyWith(color: t.muted),
            ),
            const SizedBox(width: SipSpace.sm),
            SipIcon(SipIcons.chevR, boyut: 15, kalinlik: 2.2, renk: t.muted),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Tümü ekranı
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Müşterinin TÜM siparişleri — kart bölümünün "Tümünü gör" girişi buraya açılır.
/// Kart ile AYNI satır bileşenini çizer; farkı yalnız listenin kesilmemesidir.
class MusteriSiparisleriEkrani extends StatelessWidget {
  const MusteriSiparisleriEkrani({
    super.key,
    required this.db,
    required this.customerId,
    required this.musteriAdi,
    this.musteriCode,
    this.writable = true,
    this.canAssign = false,
  });

  final AppDatabase db;
  final String customerId;
  final String musteriAdi;
  final int? musteriCode;
  final bool writable;
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Order>>(
          stream: watchMusteriSiparisleri(db, customerId),
          builder: (context, snap) {
            final siparisler = snap.data;
            return Column(
              children: [
                SipUst(
                  baslik: 'Sipariş Geçmişi',
                  // Alt satır MÜŞTERİYİ söyler: ekran yığında tek başına da açılabilir ve
                  // "kimin geçmişi" sorusunun cevabı başlıktan düşmemeli.
                  alt: siparisler == null
                      ? musteriAdi
                      : '$musteriAdi, ${siparisler.length} sipariş',
                  onGeri: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: SipGovde(
                    children: [
                      if (siparisler == null)
                        const SipIskelet(adet: 3)
                      else if (siparisler.isEmpty)
                        const SipBosDurum(
                          ikon: SipIcons.receipt,
                          baslik: 'Sipariş yok',
                          aciklama: 'Bu müşteriye henüz sipariş girilmedi.',
                        )
                      else
                        MusteriSiparisListesi(
                          db: db,
                          siparisler: siparisler,
                          musteriAdi: musteriAdi,
                          musteriCode: musteriCode,
                          writable: writable,
                          canAssign: canAssign,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Ortak liste
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Verilen siparişleri sipariş listesinin satırıyla çizer (kart ve "Tümü" ekranı ortak).
///
/// Kalem dökümü, tahsilat ve kod tercihi TOPLU akışlardan gelir — satır başına sorgu açmaz.
class MusteriSiparisListesi extends StatelessWidget {
  const MusteriSiparisListesi({
    super.key,
    required this.db,
    required this.siparisler,
    required this.musteriAdi,
    this.musteriCode,
    this.writable = true,
    this.canAssign = false,
  });

  final AppDatabase db;
  final List<Order> siparisler;
  final String musteriAdi;
  final int? musteriCode;
  final bool writable;
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, List<OrderLine>>>(
      stream: watchOrderLinesByOrder(db),
      initialData: const {},
      builder: (context, satirSnap) => StreamBuilder<Map<String, int>>(
        stream: watchSiparisTahsilatlari(db),
        initialData: const {},
        builder: (context, tahsilSnap) => StreamBuilder<String>(
          stream: watchSiparisKoduTercihi(db),
          initialData: 'musteri',
          builder: (context, kodSnap) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final o in siparisler)
                Padding(
                  padding: const EdgeInsets.only(bottom: SipSpace.sm),
                  child: SiparisSatiri(
                    item: OrderListItem(order: o, customerName: musteriAdi),
                    satirlar: (satirSnap.data ?? const {})[o.id] ?? const [],
                    tahsilKurus: (tahsilSnap.data ?? const {})[o.id] ?? 0,
                    musteriCode: musteriCode,
                    kodTercihi: kodSnap.data ?? 'musteri',
                    onAc: () => siparisDetaySheetAc(
                      context,
                      db: db,
                      orderId: o.id,
                      writable: writable,
                      canAssign: canAssign,
                      baslik: musteriAdi,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
