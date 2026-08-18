// "SEPETE EKLE" SHEET'İ — adet · malzeme seçimi · müşteri tercihi (CSS `.pos-sec-*`, `.pos-stepper`).
//
// NEDEN AYRI DOSYA: `pos_catalog.dart` seçenek seçimiyle 565 satıra çıkmıştı (depo sınırı 500).
// Ayrım KONUYA göre: katalog ÜRÜN SEÇTİRİR (ızgara · arama · barkod), burası seçilen ürünü
// TARİF ETTİRİR (kaç tane · nasıl · bu müşteri için hatırla).
//
// NEDEN `part` (ayrı kütüphane değil): `_AdetSonucu` ve `_AdetGovde` PRIVATE kalmalı — sheet'in
// dönüş tipi kataloğun iç sözleşmesidir ve dışarıya sızması, başka bir ekranın bu sheet'i
// kataloğu atlayarak açmasına davet olurdu (tercih okuma ve hatırlama yazımı katalogda durur).
// `part` aynı kütüphanede kalmayı ve `_` gizliliğini korur; çağrı yerleri DEĞİŞMEZ.

part of 'pos_catalog.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Adet seçimi — CSS `.pos-sec`, `.pos-stepper`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Adet sheet'inin sonucu: adet + seçim + "hatırla" tercihi.
class _AdetSonucu {
  const _AdetSonucu(this.adet, this.secim, this.hatirla);
  final int adet;
  final SecenekSecimi secim;
  final bool hatirla;
}

Future<_AdetSonucu?> _adetSheetAc(
  BuildContext context,
  Product u, {
  required List<UrunSecenegi> secenekler,
  required SecenekSecimi baslangic,
  required String? musteriAdi,
  required bool tercihUygulandi,
}) =>
    sipSheet<_AdetSonucu>(
      context,
      baslik: 'Sepete Ekle',
      govde: (ctx) => _AdetGovde(
        urun: u,
        secenekler: secenekler,
        baslangic: baslangic,
        musteriAdi: musteriAdi,
        tercihUygulandi: tercihUygulandi,
      ),
    );

class _AdetGovde extends StatefulWidget {
  const _AdetGovde({
    required this.urun,
    this.secenekler = const [],
    this.baslangic = const SecenekSecimi(),
    this.musteriAdi,
    this.tercihUygulandi = false,
  });

  final Product urun;
  final List<UrunSecenegi> secenekler;
  final SecenekSecimi baslangic;
  final String? musteriAdi;
  final bool tercihUygulandi;

  @override
  State<_AdetGovde> createState() => _AdetGovdeState();
}

class _AdetGovdeState extends State<_AdetGovde> {
  int _adet = 1;
  late SecenekSecimi _secim = widget.baslangic;

  /// "Bu müşteri için hatırla" — ZATEN UYGULANMIŞ bir tercih varsa AÇIK başlar.
  ///
  /// Gerekçe: tercihi uygulanan müşteride kullanıcı çoğunlukla onu DEĞİŞTİRMEZ; kapalı
  /// başlasaydı, tercihi bir kez düzenleyen bayi anahtarı açmayı unutur ve düzeltme sonraki
  /// siparişe taşınmazdı — özellik "bazen hatırlıyor" gibi görünürdü.
  late bool _hatirla = widget.tercihUygulandi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final u = widget.urun;
    final birim = u.unitPriceKurus + _secim.ekTutarKurus;
    final tutar = birim * _adet;

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
        // SEÇENEKLER ADET SEÇİCİNİN ALTINDA: adet en sık dokunulan alandır ve parmağın ilk
        // gittiği yerde durmalı. Malzemeler onun altında, düğmenin üstünde — yani karar
        // sırasına göre (kaç tane → nasıl → ekle).
        UrunSecenekSecici(
          secenekler: widget.secenekler,
          secim: _secim,
          onDegis: (s) => setState(() => _secim = s),
        ),
        if (widget.musteriAdi != null || widget.tercihUygulandi)
          MusteriTercihSeridi(
            musteriAdi: widget.musteriAdi,
            tercihUygulandi: widget.tercihUygulandi,
            hatirla: _hatirla,
            secimVar: !_secim.bos,
            onHatirla: (v) => setState(() => _hatirla = v),
          ),

        const SizedBox(height: SipSpace.x2),
        SipButon(
          etiket: 'Sepete Ekle · ${sipTutar(tutar)}',
          ikon: SipIcons.plus,
          onTap: () => Navigator.of(context).pop(_AdetSonucu(_adet, _secim, _hatirla)),
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
