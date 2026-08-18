// POS ürün kataloğu — CSS `.pos-*`, `.bk-*`. Kaynak: s-siparisler.jsx `PosKatalog` / `UrunGorsel`.
//
// İki sheet: (1) tam ekran katalog ızgarası + arama + barkod düğmesi, (2) "Sepete Ekle" adet
// seçimi. Barkod düğmesi KAMERAYI açar (`screens/barkod/barkod_kamera.dart`) ve okunan kodu
// arama alanına yazar; arada elle doldurulan bir ara sheet YOKTUR (kullanıcı kararı,
// 2026-07-26). Kamera modeli pakete gömülüdür — çalışma anı indirmesi yok, offline-first
// korunur; kamera yoksa/izin verilmezse okuyucu kendi içinde elle girişe düşer.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../barkod/barkod_kamera.dart';
import 'order_queries.dart';

/// Katalogdan sepete eklenen kalem.
class KatalogSecimi {
  const KatalogSecimi(this.urun, this.adet);
  final Product urun;
  final int adet;
}

/// Tam ekran katalog sheet'i. Kullanıcı "Bitti"ye basana kadar açık kalır; her ekleme
/// [onEkle] ile anında dışarı bildirilir (tasarımdaki davranış — sepet arkada dolar).
Future<void> posKatalogAc(
  BuildContext context, {
  required AppDatabase db,
  required void Function(Product urun, int adet) onEkle,
  ValueChanged<String>? onBildir,
}) =>
    sipSheet<void>(
      context,
      baslik: 'Ürün Kataloğu',
      tam: true,
      govde: (ctx) => _KatalogGovde(db: db, onEkle: onEkle, onBildir: onBildir),
    );

class _KatalogGovde extends StatefulWidget {
  const _KatalogGovde({required this.db, required this.onEkle, this.onBildir});

  final AppDatabase db;
  final void Function(Product urun, int adet) onEkle;
  final ValueChanged<String>? onBildir;

  @override
  State<_KatalogGovde> createState() => _KatalogGovdeState();
}

class _KatalogGovdeState extends State<_KatalogGovde> {
  final _arama = TextEditingController();
  String _sorgu = '';
  int _eklenen = 0;

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<void> _sec(Product u) async {
    final adet = await _adetSheetAc(context, u);
    if (adet == null || !mounted) return;
    widget.onEkle(u, adet);
    setState(() => _eklenen++);
    widget.onBildir?.call('${u.name} ×$adet sepete eklendi');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<List<Product>>(
      stream: watchKatalogUrunleri(widget.db),
      initialData: const [],
      builder: (context, snap) {
        final tumu = snap.data ?? const <Product>[];
        // Süzgeç ekrandan BAĞIMSIZ (`katalogSuz`): ad + barkod kuralı orada kilitli.
        final liste = katalogSuz(tumu, _sorgu);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .pos-ust — arama + barkod düğmesi
            Row(
              children: [
                Expanded(
                  child: SipArama(
                    controller: _arama,
                    ipucu: 'Ürün ara…',
                    onChanged: (v) => setState(() => _sorgu = v),
                    onTemizle: () => setState(() {
                      _arama.clear();
                      _sorgu = '';
                    }),
                  ),
                ),
                const SizedBox(width: SipSpace.md),
                SipDokun(
                  onTap: _barkodAc,
                  zemin: t.accentSoft,
                  basiliZemin: t.accentSoft,
                  radius: const BorderRadius.all(Radius.circular(13)),
                  olcekle: true,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: SipIcon(SipIcons.barkod, boyut: 21, kalinlik: 2, renk: t.accent),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SipSpace.xl),
            if (liste.isEmpty)
              // Tasarımda tek boş-durum var: `"{q}" için sonuç yok` (s-siparisler.jsx:190).
              // "ürünleri Menü › Ürünler'den ekleyin" yönlendirmesi kaldırıldı — kullanıcıyı
              // katalog sheet'inin içinden gidemeyeceği bir yere yolluyordu.
              _PosBos(
                ikon: tumu.isEmpty ? SipIcons.box : SipIcons.search,
                metin: tumu.isEmpty ? 'Katalog boş' : '"$_sorgu" için sonuç yok',
              )
            else
              // ÜÇ SÜTUN (kullanıcı kararı 2026-08-18): iki sütunda karolar tezgâhta gereksiz
              // büyüktü ve ekrana ancak dört ürün sığıyordu; sipariş girişi sürekli kaydırma
              // istiyordu. Üç sütun aynı yükseklikte %50 daha fazla ürün gösterir.
              //
              // ⚠️ ORAN SÜTUN SAYISINA BAĞLIDIR: `childAspectRatio` GENİŞLİK/YÜKSEKLİK'tir ve
              // karo yüksekliği sabit parçalar (2 satır ad + fiyat satırı + dolgu ≈ 76 px)
              // ile genişliğe ORANTILI parçadan (5/4 görsel) oluşur. Sütun sayısı artınca
              // genişlik düşer, sabit parçaların payı büyür — eski 0.86 ile karo 40 px kısa
              // kalır ve `Expanded`in altındaki fiyat satırı taşardı. 0.68, en dar telefonda
              // (360 dp) bile ~10 px pay bırakır.
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: SipSpace.md,
                crossAxisSpacing: SipSpace.md,
                childAspectRatio: 0.68,
                children: [
                  for (final u in liste) _PosKarosu(urun: u, onTap: () => _sec(u)),
                ],
              ),
            const SizedBox(height: SipSpace.lg),
            // .pos-alt
            SipButon(
              etiket: _eklenen > 0 ? 'Bitti · $_eklenen kalem eklendi' : 'Bitti',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        );
      },
    );
  }

  /// Barkod ikonu → KAMERA. Okunan kod ARAMA ALANINA yazılır (kullanıcı kararı,
  /// 2026-07-26: "okuduğu barkodu direkt inputa yazsın"); ızgara filtresi barkodu da
  /// eşleştirdiği için ürün anında karo olarak kalır, dokunuş adet sheet'ini açar.
  /// Kod hiçbir ürüne bağlı değilse kataloğun kendi boş durumu `"…" için sonuç yok` der —
  /// ayrı bir hata yolu yok.
  Future<void> _barkodAc() async {
    final kod = await barkodKameraAc(context);
    if (kod == null || !mounted) return;
    setState(() {
      _arama.text = kod;
      _sorgu = kod;
    });
  }
}

/// CSS `.pos-tile` — görsel/baş harf, ad (2 satır), fiyat + birim.
class _PosKarosu extends StatelessWidget {
  const _PosKarosu({required this.urun, required this.onTap});

  final Product urun;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface2,
      basiliZemin: t.line,
      radius: const BorderRadius.all(Radius.circular(16)),
      olcekle: true,
      // Üç sütunda dolgu 8 → 6: kaybedilen her piksel doğrudan görselden ve ad satırından
      // çıkıyordu. Alt dolgu (9) üsttekinden büyük kalır — fiyat satırı kenara yapışmasın.
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UrunGorseli(urun: urun, en: double.infinity, oran: 5 / 4, radius: 10, puntoBoyut: 20),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                urun.name,
                style: SipText.metin(12, w: 700, h: 1.3).copyWith(color: t.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    sipTutar(urun.unitPriceKurus),
                    style: SipText.tutar(12.5).copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 3),
                // BİRİM DARALTILABİLİR: dar telefonda "1.250,00 ₺" + "/ porsiyon" yan yana
                // sığmaz. Kırpılacaksa BİRİM kırpılır, fiyat değil — bayi fiyatı okuyamazsa
                // karo işini yapmıyor demektir.
                Flexible(
                  child: Text(
                    '/ ${urun.unit}',
                    style: SipText.metin(9.5, w: 500).copyWith(color: t.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.pos-img` / `.pos-img.ph` — görsel yoksa ürün adının baş harfi accent-soft daire içinde.
/// Görsel İŞARETÇİSİ (imageUrl) uzak adres olabileceğinden şimdilik yalnız YEREL dosya yolu
/// (imageLocalPath) çizilir; ağdan indirme offline-first sözünü bozar, o boru hattı ayrı iş.
class UrunGorseli extends StatelessWidget {
  const UrunGorseli({
    super.key,
    required this.urun,
    this.en = 52,
    this.oran,
    this.radius = 14,
    this.puntoBoyut = 19,
  });

  final Product urun;
  final double en;

  /// Verilirse kutu bu en/boy oranında çizilir (ızgara karosu), yoksa kare.
  final double? oran;
  final double radius;
  final double puntoBoyut;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final yol = urun.imageLocalPath;
    final harf = urun.name.trim().isEmpty ? '?' : trBuyuk(urun.name.trim()[0]);

    Widget kutu = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(radius),
        image: yol == null
            ? null
            : DecorationImage(image: FileImage(File(yol)), fit: BoxFit.cover),
      ),
      child: yol != null
          ? null
          : Text(harf, style: SipText.tutar(puntoBoyut, w: 800).copyWith(color: t.accent)),
    );

    if (oran != null) kutu = AspectRatio(aspectRatio: oran!, child: kutu);
    return SizedBox(width: en == double.infinity ? null : en, child: kutu);
  }
}

class _PosBos extends StatelessWidget {
  const _PosBos({required this.ikon, required this.metin});
  final String ikon;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 30),
      child: Column(
        children: [
          SipIcon(ikon, boyut: 28, kalinlik: 1.6, renk: t.line2),
          const SizedBox(height: 9),
          Text(metin,
              textAlign: TextAlign.center,
              style: SipText.metin(13, w: 500).copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Adet seçimi — CSS `.pos-sec`, `.pos-stepper`
// ═══════════════════════════════════════════════════════════════════════════════════════════

Future<int?> _adetSheetAc(BuildContext context, Product u) => sipSheet<int>(
      context,
      baslik: 'Sepete Ekle',
      govde: (ctx) => _AdetGovde(urun: u),
    );

class _AdetGovde extends StatefulWidget {
  const _AdetGovde({required this.urun});
  final Product urun;

  @override
  State<_AdetGovde> createState() => _AdetGovdeState();
}

class _AdetGovdeState extends State<_AdetGovde> {
  int _adet = 1;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final u = widget.urun;
    final tutar = u.unitPriceKurus * _adet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .pos-sec-head
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, SipSpace.x2),
          child: Row(
            children: [
              UrunGorseli(urun: u),
              const SizedBox(width: SipSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CSS `.pos-sec-nm` DISPLAY ailesindedir (font-d, 16,5/700, ls -.01 —
                    // _sayfa.html:630); `SipText.metin` gövde ailesini verir. Aynı ölçüdeki
                    // display jetonu `bosBaslik`tır (`.bos-baslik` ile birebir aynı değerler).
                    Text(u.name,
                        style: SipText.bosBaslik.copyWith(color: t.ink),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${sipTutar(u.unitPriceKurus)} / ${u.unit}',
                        style: SipText.metin(12, w: 600).copyWith(color: t.muted)),
                    if ((u.barcode ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SipIcon(SipIcons.barkod, boyut: 12, kalinlik: 1.8, renk: t.muted),
                          const SizedBox(width: 5),
                          Text(u.barcode!,
                              style: SipText.metin(11, w: 600).copyWith(color: t.muted)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SipSpace.md),
              Text(sipTutar(tutar), style: SipText.tutar19.copyWith(color: t.ink)),
            ],
          ),
        ),
        // .pos-stepper
        Container(
          padding: const EdgeInsets.all(SipSpace.md),
          decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepperDugmesi(
                ikon: SipIcons.down,
                pasif: _adet <= 1,
                onTap: () => setState(() => _adet = _adet > 1 ? _adet - 1 : 1),
                etiket: 'Azalt',
              ),
              Text('$_adet', style: SipText.adet24.copyWith(color: t.ink)),
              _StepperDugmesi(
                ikon: SipIcons.plus,
                onTap: () => setState(() => _adet++),
                etiket: 'Artır',
              ),
            ],
          ),
        ),
        const SizedBox(height: SipSpace.x2),
        SipButon(
          etiket: 'Sepete Ekle · ${sipTutar(tutar)}',
          ikon: SipIcons.plus,
          onTap: () => Navigator.of(context).pop(_adet),
        ),
      ],
    );
  }
}

/// CSS `.pos-stepper button` — 52×48 yüzey karosu.
class _StepperDugmesi extends StatelessWidget {
  const _StepperDugmesi({
    required this.ikon,
    required this.onTap,
    required this.etiket,
    this.pasif = false,
  });

  final String ikon;
  final VoidCallback onTap;
  final String etiket;
  final bool pasif;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      label: etiket,
      child: SipDokun(
        onTap: pasif ? null : onTap,
        zemin: t.knob,
        basiliZemin: t.knob,
        radius: const BorderRadius.all(Radius.circular(12)),
        olcekle: true,
        child: SizedBox(
          width: 52,
          height: 48,
          child: Center(
            child: SipIcon(ikon, boyut: 20, kalinlik: 2.4, renk: pasif ? t.line2 : t.ink),
          ),
        ),
      ),
    );
  }
}
