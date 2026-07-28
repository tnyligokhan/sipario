// BORÇLULAR — ana ekrandaki bento kutusunun açtığı liste.
//
// NEDEN VAR (kullanıcı kararı 2026-07-29): kutu "Açık Veresiye" adıyla toplam bir rakam yazıyor
// ve dokununca MÜŞTERİLER sekmesine gidiyordu — yani borcu olmayan yüzlerce müşterinin arasına.
// Bayinin o rakama dokunma sebebi tektir: "kim borçlu, ne kadar, hangi siparişten". Kutu artık
// "Borçlular" adını taşır ve bu ekranı açar: yalnız bakiyesi borçta olan müşteriler, her birinin
// altında ÖDENMEMİŞ siparişleri.
//
// İKİ SAYI AYRI DURUR ve toplanmaz: müşterinin DEFTER bakiyesi (tek doğru kaynak, tahsilatın
// yapıldığı büyüklük) ile siparişlerden kalanların toplamı eşit olmak ZORUNDA DEĞİLDİR — elle
// düzeltme, sipariş dışı borç ve teslimden önce alınan avans ikisini ayırır. Fark varsa ekran
// bunu SÖYLER; sessizce bir tarafı seçmek bayiye "rakamlar tutmuyor" dedirtirdi.

// `hide Column`: drift'in `Column`u ile Flutter'ınki çakışır (müşteri listesi ekranının deseni).
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_detail_screen.dart' show siparisDetaySheetAc;
import '../orders/order_queries.dart'
    show saatBicimi, siparisKalanBorcu, watchSiparisTahsilatlari;
import '../team.dart';
import 'customer_detail_screen.dart';
import 'customer_sheets.dart' show borcTahsilatiAc;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Veri
// ═══════════════════════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Ekran
// ═══════════════════════════════════════════════════════════════════════════════════════════

class BorclularEkrani extends StatelessWidget {
  const BorclularEkrani({
    super.key,
    required this.db,
    required this.writable,
    this.yetki,
    this.canAssign = false,
  });

  final AppDatabase db;
  final bool writable;
  final RolYetkileri? yetki;

  /// Sipariş detayına geçilir (kurye ataması orada K2 kapısıyla açılır).
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Customer>>(
          stream: watchBorcluMusteriler(db),
          builder: (context, musteriSnap) {
            final musteriler = musteriSnap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SipUst(
                  baslik: 'Borçlular',
                  alt: _altBaslik(musteriler),
                  onGeri: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: musteriler == null
                      ? const SipIskelet(adet: 4)
                      : musteriler.isEmpty
                          ? SipBosDurum(
                              ikon: SipIcons.wallet,
                              baslik: 'Borçlu yok',
                              aciklama: 'Tüm hesaplar temiz — tahsil edilmemiş borç görünmüyor.',
                            )
                          : _Liste(
                              db: db,
                              musteriler: musteriler,
                              writable: writable,
                              yetki: yetki,
                              canAssign: canAssign,
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// "3 müşteri · 4.250,00 ₺" — kaç kişi ve ne kadar. Veri gelmeden RAKAM YAZILMAZ.
  static String _altBaslik(List<Customer>? musteriler) {
    if (musteriler == null) return '';
    if (musteriler.isEmpty) return 'Tüm hesaplar temiz';
    final toplam = musteriler.fold<int>(0, (s, c) => s + c.balanceKurus);
    return '${musteriler.length} müşteri · ${sipTutar(toplam)}';
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.db,
    required this.musteriler,
    required this.writable,
    required this.yetki,
    required this.canAssign,
  });

  final AppDatabase db;
  final List<Customer> musteriler;
  final bool writable;
  final RolYetkileri? yetki;
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    // Sipariş akışı borçlu kümesine göre daraltılır; küme değişince yeniden abone olunur.
    return StreamBuilder<List<Order>>(
      stream: watchBorcluSiparisleri(db, [for (final c in musteriler) c.id]),
      initialData: const [],
      builder: (context, siparisSnap) => StreamBuilder<Map<String, int>>(
        stream: watchSiparisTahsilatlari(db),
        initialData: const {},
        builder: (context, tahsilatSnap) {
          final liste = borcluListesiKur(
            musteriler,
            siparisSnap.data ?? const [],
            tahsilatSnap.data ?? const {},
          );
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                SipSpace.govde, 0, SipSpace.govde, SipSpace.x5),
            itemCount: liste.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : SipSpace.md),
              child: _BorcluKarti(
                db: db,
                veri: liste[i],
                writable: writable,
                yetki: yetki,
                canAssign: canAssign,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bir borçlunun kartı: ad + toplam borç · ödenmemiş siparişleri · "Tahsilat Al".
class _BorcluKarti extends StatelessWidget {
  const _BorcluKarti({
    required this.db,
    required this.veri,
    required this.writable,
    required this.yetki,
    required this.canAssign,
  });

  final AppDatabase db;
  final BorcluMusteri veri;
  final bool writable;
  final RolYetkileri? yetki;
  final bool canAssign;

  Future<void> _musteriAc(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(
            db: db,
            customerId: veri.musteri.id,
            writable: writable,
            yetki: yetki,
          ),
        ),
      );

  Future<void> _tahsilat(BuildContext context) async {
    if (!writable) {
      SipToast.goster(context, 'Salt-okunur kip: yeni kayıt eklenemez.');
      return;
    }
    final ok = await borcTahsilatiAc(context, db: db, customerId: veri.musteri.id);
    if (ok == true && context.mounted) SipToast.goster(context, 'Tahsilat kaydedildi');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ad + toplam borç. Dokunuş müşteri detayına gider (defterin tamamı oradadır).
          SipDokun(
            onTap: () => _musteriAc(context),
            zemin: t.surface,
            basiliZemin: t.surface2,
            radius: SipRadius.br1,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    veri.musteri.name,
                    style: SipText.satirAdSip.copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: SipSpace.md),
                Text(sipTutar(veri.borcKurus),
                    style: SipText.satirTutarBuyuk.copyWith(color: t.danger)),
              ],
            ),
          ),
          const SizedBox(height: SipSpace.sm),

          if (veri.siparisler.isEmpty)
            // Borç var ama ödenmemiş sipariş yok: kaynağı sipariş dışı bir defter kaydıdır.
            // Boş bir kart bırakmak yerine sebebi söylenir.
            Text('Ödenmemiş sipariş yok — borç defter kaydından geliyor.',
                style: SipText.metin(12, w: 600).copyWith(color: t.muted))
          else
            for (final s in veri.siparisler)
              _SiparisSatiri(
                siparis: s,
                onTap: () => siparisDetaySheetAc(
                  context,
                  db: db,
                  orderId: s.order.id,
                  writable: writable,
                  canAssign: canAssign,
                  baslik: veri.musteri.name,
                ),
              ),

          // Siparişlere bağlanamayan fark — yalnız varsa. Sessiz kalmak, kartın toplamıyla
          // satırların toplamını tutturamayan bayiye "rakamlar yanlış" dedirtirdi.
          if (veri.siparisler.isNotEmpty && veri.farkKurus > 0)
            Padding(
              padding: const EdgeInsets.only(top: SipSpace.xs),
              child: Text(
                'Bu siparişler dışında ${sipTutar(veri.farkKurus)} borç (defter kaydı)',
                style: SipText.metin(12, w: 600).copyWith(color: t.muted),
              ),
            ),

          const SizedBox(height: SipSpace.md),
          SipDokun(
            onTap: () => _tahsilat(context),
            zemin: t.surface2,
            basiliZemin: t.line,
            radius: SipRadius.br2,
            olcekle: true,
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SipIcon(SipIcons.wallet, boyut: 15, kalinlik: 2.2, renk: t.ink2),
                  const SizedBox(width: 7),
                  Text('Tahsilat Al · ${sipTutar(veri.borcKurus)}',
                      style: SipText.metin(13, w: 700).copyWith(color: t.ink2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kart içindeki tek sipariş satırı: tarih/saat · kalan borç. Dokunuş sipariş detayını açar.
class _SiparisSatiri extends StatelessWidget {
  const _SiparisSatiri({required this.siparis, required this.onTap});

  final BorcluSiparis siparis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      basiliZemin: t.surface2,
      radius: SipRadius.br1,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SipIcon(SipIcons.box, boyut: 13, kalinlik: 2.1, renk: t.muted),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(saatBicimi(siparis.order.occurredAt),
                style: SipText.metin(12.5, w: 600).copyWith(color: t.ink2)),
          ),
          Text(sipTutar(siparis.kalanKurus),
              style: SipText.metin(12.5, w: 700).copyWith(color: t.danger)),
          const SizedBox(width: SipSpace.xs),
          SipIcon(SipIcons.right, boyut: 13, kalinlik: 2.2, renk: t.muted),
        ],
      ),
    );
  }
}
