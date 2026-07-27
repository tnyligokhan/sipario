// Sipariş listesi satırı — CSS `.srow*` (Sipario.html 212–252) / s-siparisler.jsx `SiparisSatir`.
//
// Yapı (tasarımdaki sırayla):
//   .srow-head   → .srow-ust (tutamaç · kod rozeti · müşteri adı · tutar)
//                  .srow-alt (durum pili · kurye çipi · saat)  + alt ayraç çizgisi
//   .srow-adres  → kenarlıklı adres kutusu (elle sıralama kipinde gizli)
//   .srow-urunler→ "SİPARİŞ KALEMLERİ" başlığı + madde madde döküm
//   .srow-not    → sarı not kutusu (elle kipinde gizli)
//   .srow-acts   → Ara / WhatsApp / Konum (müşterili + açık siparişte, elle kipinde gizli).
//                  Şerit ve düğmelerin davranışı `musteri_eylemleri.dart`ta; telefon/konum yoksa
//                  düğme PASİF çizilir ama gizlenmez (saha hatası 3).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'musteri_eylemleri.dart';
import 'order_queries.dart';

class SiparisSatiri extends StatelessWidget {
  const SiparisSatiri({
    super.key,
    required this.item,
    required this.satirlar,
    this.kuryeAdi,
    this.adres,
    this.telefon,
    this.onAc,
    this.onKuryeAc,
    this.onBildir,
    this.elle = false,
    this.tutamac,
    this.tutamacSagda = true,
  });

  final OrderListItem item;

  /// Siparişin aktif satırları (ürün dökümü).
  final List<OrderLine> satirlar;

  /// Atanmış kuryenin adı. `null` ise kurye çipi HİÇ çizilmez — tek kişilik bayide kurye
  /// adımları görünmez (BRIEF, pazarlıksız).
  final String? kuryeAdi;

  final AdresBilgi? adres;
  final String? telefon;

  final VoidCallback? onAc;

  /// Kurye çipine dokunuldu (açık siparişte kurye değiştirme sheet'i).
  final VoidCallback? onKuryeAc;

  /// Tasarımdaki `ping` — eylem düğmeleri toast gösterir.
  final ValueChanged<String>? onBildir;

  /// Elle sıralama kipi: adres/not/eylemler gizlenir, sol başa tutamaç gelir (CSS `.srow.elle`).
  final bool elle;

  /// `ReorderableListView`in verdiği sürükleme tutamacı sarmalayıcısı.
  final Widget Function(Widget child)? tutamac;

  /// Tutamaç SAĞDA mı çizilsin (varsayılan) yoksa solda mı.
  ///
  /// Saha hatası 4: tasarım tutamacı sola koyuyordu, telefonu sağ eliyle tutan bayinin başparmağı
  /// oraya yetişmiyor. Kullanıcı kararı: "çoğunluk sağ elini kullanıyor, ama sol elle kullananları
  /// da göz ardı edemeyiz" → VARSAYILAN SAĞ, tercih sola alınabilir (elle sıralama bandındaki
  /// anahtar). Tercihin cihazda KALICI saklanması henüz yok — bkz. [tutamacSagdaTercihi].
  final bool tutamacSagda;

  bool get _acik => item.order.status == 'open';

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final o = item.order;
    final kod = musteriKod(o.customerId);

    return SipDokun(
      onTap: elle ? null : onAc,
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── .srow-head ────────────────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.only(bottom: SipSpace.lg),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (elle && !tutamacSagda) ...[
                      _Tutamac(sarmala: tutamac),
                      const SizedBox(width: SipSpace.md),
                    ],
                    if (kod != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.accentSoft,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(kod, style: SipText.siparisKod.copyWith(color: t.accent)),
                      ),
                      const SizedBox(width: SipSpace.md),
                    ],
                    Expanded(
                      child: Text(
                        item.customerName ?? 'Tezgâh satışı',
                        style: SipText.satirAdSip.copyWith(color: t.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: SipSpace.md),
                    Text(
                      sipTutar(o.totalKurus),
                      style: SipText.satirTutarBuyuk.copyWith(color: t.ink),
                    ),
                    if (elle && tutamacSagda) ...[
                      const SizedBox(width: SipSpace.md),
                      _Tutamac(sarmala: tutamac),
                    ],
                  ],
                ),
                const SizedBox(height: SipSpace.md),
                // .srow-alt — sarmalanabilir çip şeridi.
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SipDurumPili(durum: o.status),
                          if (kuryeAdi != null)
                            _KuryeCipi(
                              ad: kuryeAdi!,
                              odeme: o.paymentType,
                              acik: _acik,
                              onTap: elle ? null : onKuryeAc,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SipSpace.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SipIcon(SipIcons.clock, boyut: 12, kalinlik: 2, renk: t.muted),
                        const SizedBox(width: SipSpace.xs),
                        Text(saatBicimi(o.occurredAt),
                            style: SipText.saat.copyWith(color: t.muted)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── .srow-adres ───────────────────────────────────────────────────────────────────
          if (adres != null && !elle) ...[
            const SizedBox(height: SipSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(color: t.line2, width: 1.5),
                // CSS `.srow-adres { border-radius: 10px }` (_sayfa.html:497) — jeton br1 12'dir,
                // bu satır kasten daha sıkı; tema dosyasına dokunmadan yerel değer.
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: SipIcon(SipIcons.pin, boyut: 14, kalinlik: 2.2, renk: t.accent),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child:
                        Text(adres!.tamMetin, style: SipText.satirAdres.copyWith(color: t.ink)),
                  ),
                ],
              ),
            ),
          ],

          // ── .srow-urunler ─────────────────────────────────────────────────────────────────
          if (satirlar.isNotEmpty) ...[
            const SizedBox(height: SipSpace.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SipIcon(SipIcons.box, boyut: 14, kalinlik: 2.1, renk: t.accent),
                      const SizedBox(width: SipSpace.sm),
                      Text('SİPARİŞ KALEMLERİ',
                          style: SipText.urunDokumBaslik.copyWith(color: t.muted)),
                    ],
                  ),
                  const SizedBox(height: SipSpace.xs),
                  for (final l in satirlar)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(color: t.line2, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: SipSpace.md),
                          Expanded(
                            child: Text(
                              satirOzeti(l),
                              style: SipText.urunDokum.copyWith(color: t.ink2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── .srow-not ─────────────────────────────────────────────────────────────────────
          if ((o.note ?? '').isNotEmpty && !elle) ...[
            const SizedBox(height: SipSpace.sm),
            _NotKutusu(metin: o.note!),
          ],

          // ── .srow-acts ────────────────────────────────────────────────────────────────────
          // Şerit MÜŞTERİLİ ve AÇIK siparişte çizilir; telefonu/konumu olmayan müşteride de
          // çizilir ama düğmeler pasif görünür (hata 3: "yok" ile "bozuk" ayırt edilmeliydi).
          // Tezgâh satışında (müşterisiz) hiç çizilmez — arayacak kimse yok.
          if (o.customerId != null && _acik && !elle) ...[
            const SizedBox(height: SipSpace.md),
            MusteriEylemSeridi(
              musteriAd: item.customerName ?? 'Müşteri',
              telefon: telefon,
              adres: adres,
              onBildir: onBildir,
            ),
          ],
        ],
      ),
    );
  }
}

/// CSS `.srow-grip` — 34×34 hap tutamaç. Sürükleme tanıyıcısını `ReorderableListView` sağlar.
class _Tutamac extends StatelessWidget {
  const _Tutamac({this.sarmala});
  final Widget Function(Widget child)? sarmala;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final govde = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.brHap),
      child: SipIcon(SipIcons.grip, boyut: 18, kalinlik: 2.6, renk: t.muted),
    );
    return Semantics(
      label: 'Sürükleyerek taşı',
      child: sarmala == null ? govde : sarmala!(govde),
    );
  }
}

/// CSS `.srow-kurye` — kurye adı + (varsa) ödeme tipi + açık siparişte aşağı ok.
///
/// KAPALI siparişte de TIKLANABİLİR: tasarım (s-siparisler.jsx:24) dokunuşu yutmuyor,
/// "Kapalı siparişte kurye değiştirilemez" diyor. Çipi sessizce ölü yapmak, kullanıcıya neden
/// hiçbir şey olmadığını söylemiyordu; [acik] yalnız aşağı OKUN çizilip çizilmesini belirler.
class _KuryeCipi extends StatelessWidget {
  const _KuryeCipi({
    required this.ad,
    required this.odeme,
    required this.acik,
    this.onTap,
  });

  final String ad;
  final String? odeme;

  /// Sipariş açık mı — açıkken çipte aşağı ok görünür (değiştirilebilir olduğunun işareti).
  final bool acik;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface2,
      basiliZemin: t.line,
      radius: SipRadius.brHap,
      kenarlik: Border.all(color: t.line2),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.lg, vertical: SipSpace.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SipIcon(SipIcons.truck, boyut: 13, kalinlik: 2.2, renk: t.ink2),
          const SizedBox(width: 5),
          Text(ad, style: SipText.kuryeCip.copyWith(color: t.ink2)),
          if (odeme != null)
            Text(' · ${odemeTipiEtiketi(odeme!)}',
                style: SipText.kuryeCip.copyWith(color: t.muted)),
          if (acik) ...[
            const SizedBox(width: 5),
            SipIcon(SipIcons.down, boyut: 12, kalinlik: 2.4, renk: t.muted),
          ],
        ],
      ),
    );
  }
}

/// CSS `.srow-not` — sarı zeminli not kutusu, "Sipariş Notu:" kalın ön etiketiyle.
/// Yarıçap 10 ve punto 12 (_sayfa.html:480): paylaşılan `br1` 12, `SipText.not` 12,5'tir —
/// ikisi de `.md-not`a göre ayarlı, bu kutu kasten daha sıkı.
class _NotKutusu extends StatelessWidget {
  const _NotKutusu({required this.metin});
  final String metin;

  static const _yaricap = BorderRadius.all(Radius.circular(10));

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: SipSpace.md),
      decoration: BoxDecoration(color: t.warnSoft, borderRadius: _yaricap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SipIcon(SipIcons.edit, boyut: 14, kalinlik: 2.1, renk: t.warn),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'Sipariş Notu: ',
                  style: SipText.not
                      .copyWith(color: t.warn, fontSize: 12, fontWeight: FontWeight.w800),
                ),
                TextSpan(text: metin),
              ]),
              style: SipText.not.copyWith(color: t.ink2, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

