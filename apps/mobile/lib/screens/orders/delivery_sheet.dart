// Teslim & Ödeme sheet'i — CSS `.teslim`, `.teslim-tut`, `.odeme-grid`, `.odeme-b`,
// `.teslim-uyari`. Kaynak: s-siparisler.jsx `SiparisDetay` içindeki "Teslim & Ödeme" sheet'i.
//
// ÖDEME TİPİ 'nakit' ÖN-SEÇİLİ başlar (tasarım s-siparisler.jsx:443). Bir süre "hiçbiri seçili
// değil + düğme pasif" denendi; 2026-07-26'da tasarıma dönüldü: nakit teslimlerin ezici
// çoğunluğudur, her teslimde fazladan bir dokunuş istemek işi yavaşlatıyordu. Yanlış tipe karşı
// koruma kaydın kendisinde: tutar ekranda yazılı, defter append-only ve düzeltme yolu var.
//
// Veresiye karosu müşterisiz siparişte GİZLENMEZ, PASİF çizilir (tasarım `disabled` + `opacity
// .45`) — altındaki açıklama neden kapalı olduğunu söyler.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'order_queries.dart';

/// Teslim sheet'ini açar; kullanıcı onaylarsa seçilen ödeme tipini ('nakit'|'kart'|…) döner.
/// `null` = vazgeçildi. ÇAĞIRAN TARAF teslim işini `OrderRepository.deliver` ile yapar — bu dosya
/// hiçbir yazma yapmaz (defter/olay yazımı tek yerden geçsin).
Future<String?> teslimSheetAc(
  BuildContext context, {
  required int toplamKurus,
  required bool musteriVar,
}) =>
    sipSheet<String>(
      context,
      baslik: 'Teslim & Ödeme',
      govde: (ctx) => _TeslimGovde(
        toplamKurus: toplamKurus,
        musteriVar: musteriVar,
      ),
    );

class _TeslimGovde extends StatefulWidget {
  const _TeslimGovde({
    required this.toplamKurus,
    required this.musteriVar,
  });

  final int toplamKurus;
  final bool musteriVar;

  @override
  State<_TeslimGovde> createState() => _TeslimGovdeState();
}

class _TeslimGovdeState extends State<_TeslimGovde> {
  /// Tasarım `React.useState('nakit')` — ön-seçili gelir.
  String _odeme = 'nakit';

  @override
  Widget build(BuildContext context) {
    final t = context.sip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .teslim-tut
        Padding(
          padding: const EdgeInsets.fromLTRB(2, SipSpace.xs, 2, SipSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('Tahsil edilecek',
                    style: SipText.gsSatirEtiket.copyWith(color: t.ink2)),
              ),
              Text(sipTutar(widget.toplamKurus),
                  style: SipText.tutar22.copyWith(color: t.ink)),
            ],
          ),
        ),
        const SipFormEtiket('Ödeme tipi'),
        // .odeme-grid — 3 sütun; karo yüksekliği CSS'te SABİT 44 px (_sayfa.html:645).
        // `childAspectRatio` kullanılırsa yükseklik cihaz genişliğine göre kayar (dar telefonda
        // 44, geniş ekranda 55) — `mainAxisExtent` ölçüyü sabitler.
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            mainAxisExtent: 44,
          ),
          children: [
            for (final tip in odemeTipleri)
              _OdemeKarosu(
                etiket: odemeTipiEtiketi(tip),
                secili: _odeme == tip,
                // Pasif karo DOKUNMAYI YUTAR (tasarım `disabled`): veresiye müşterisiz
                // siparişte seçilemez — borç yazılacak müşteri yoktur.
                onTap: odemeTipiSecilebilir(tip, musteriVar: widget.musteriVar)
                    ? () => setState(() => _odeme = tip)
                    : null,
              ),
          ],
        ),
        if (!widget.musteriVar) ...[
          const SizedBox(height: SipSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: SipIcon(SipIcons.info, boyut: 13, kalinlik: 2.2, renk: t.muted),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Tezgâh satışında veresiye kullanılamaz — kayıtlı müşteri gerekir.',
                  style: SipText.metin(12, w: 600).copyWith(color: t.muted),
                ),
              ),
            ],
          ),
        ],
        if (_odeme == 'veresiye') ...[
          const SizedBox(height: SipSpace.xl),
          _Uyari(
            metin: 'Tutar müşterinin borcuna eklenecek.',
            renk: t.danger,
            zemin: t.dangerSoft,
            ikon: SipIcons.alert,
          ),
        ],
        const SizedBox(height: 18),
        SipButon(
          etiket: 'Teslim Et ve Kaydet',
          ikon: SipIcons.check,
          onTap: () => Navigator.of(context).pop(_odeme),
        ),
      ],
    );
  }
}

/// CSS `.odeme-b` — seçilince accent kenarlık + accent-soft zemin. [onTap] null ise tasarımdaki
/// `disabled` karo: `opacity: .45` ile soluk çizilir ama YERİNDE DURUR (kullanıcı seçeneğin var
/// olduğunu ve neden kapalı olduğunu görsün).
class _OdemeKarosu extends StatelessWidget {
  const _OdemeKarosu({required this.etiket, required this.secili, required this.onTap});

  final String etiket;
  final bool secili;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: SipDokun(
        onTap: onTap,
        zemin: secili ? t.accentSoft : t.surface2,
        basiliZemin: secili ? t.accentSoft : t.line,
        radius: SipRadius.br2,
        kenarlik: Border.all(
          color: secili ? t.accent : Colors.transparent,
          width: 1.5,
        ),
        child: Center(
          child: Text(
            etiket,
            style: SipText.metin(13, w: secili ? 700 : 600)
                .copyWith(color: secili ? t.accent : t.ink2),
          ),
        ),
      ),
    );
  }
}

/// CSS `.teslim-uyari` — tek satırlık renkli uyarı şeridi.
class _Uyari extends StatelessWidget {
  const _Uyari({
    required this.metin,
    required this.renk,
    required this.zemin,
    required this.ikon,
  });

  final String metin;
  final Color renk;
  final Color zemin;
  final String ikon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.br1),
      child: Row(
        children: [
          SipIcon(ikon, boyut: 15, kalinlik: 2.2, renk: renk),
          const SizedBox(width: 7),
          Expanded(
            child: Text(metin, style: SipText.metin(12, w: 700).copyWith(color: renk)),
          ),
        ],
      ),
    );
  }
}
