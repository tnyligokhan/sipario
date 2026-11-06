// SEPET SATIRI İSKONTOSU sheet'i (saha, 2026-11-05: "Ürün eklenirken iskonto eklenemiyor").
//
// NEDEN SEPETTE, ÜRÜN SEÇERKEN DEĞİL: seçeneksiz ürün karodan tek dokunuşla eklenir ve hiç sheet
// açılmaz (2026-08-22 kararı). Ekleme yolu üçtür (favori, katalog, serbest satır) ama hepsinin
// indiği yer sepettir; iskontonun tek yerde durması her yolu kapsar ve hızlı eklemeyi yavaşlatmaz.
//
// YETKİ: `iskonto` kapalıysa bu sheet'e giden dokunuş hiç çizilmez (kapıda iskontoyla aynı yetki).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/satir_iskontosu.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/tokens.dart';
import '../isletme/isletme_atomlari.dart';
import '../money.dart';

/// İskonto sheet'ini açar. Vazgeçilirse null, kaldırılırsa [SatirIskontosu.yok] döner.
Future<SatirIskontosu?> iskontoSheetAc(
  BuildContext context, {
  required String urunAd,
  required int brutKurus,
  required SatirIskontosu mevcut,
}) =>
    sipSheet<SatirIskontosu>(
      context,
      baslik: 'İskonto',
      govde: (ctx) => _IskontoGovde(urunAd: urunAd, brutKurus: brutKurus, mevcut: mevcut),
    );

class _IskontoGovde extends StatefulWidget {
  const _IskontoGovde({required this.urunAd, required this.brutKurus, required this.mevcut});

  final String urunAd;
  final int brutKurus;
  final SatirIskontosu mevcut;

  @override
  State<_IskontoGovde> createState() => _IskontoGovdeState();
}

class _IskontoGovdeState extends State<_IskontoGovde> {
  late IskontoTuru _tur =
      widget.mevcut.bos ? IskontoTuru.tutar : widget.mevcut.tur;

  late final _deger = TextEditingController(text: _baslangicMetni());

  String _baslangicMetni() {
    final m = widget.mevcut;
    if (m.bos) return '';
    if (m.tur == IskontoTuru.yuzde) return '${m.deger}';
    return sipTutar(m.deger, simge: false);
  }

  @override
  void dispose() {
    _deger.dispose();
    super.dispose();
  }

  /// Girilen değer; boş ya da geçersizse null.
  SatirIskontosu? get _girilen {
    final metin = _deger.text.trim();
    if (metin.isEmpty) return null;
    if (_tur == IskontoTuru.yuzde) {
      final yuzde = int.tryParse(metin);
      return yuzde == null || yuzde <= 0 || yuzde > 100 ? null : SatirIskontosu.yuzde(yuzde);
    }
    final kurus = parseKurus(metin);
    return kurus == null || kurus <= 0 ? null : SatirIskontosu.tutar(kurus);
  }

  /// Tutar türünde satırı aşan girdi kırpılmaz, reddedilir: bayi yanlış yazmıştır ve sessizce
  /// kırpmak ürünü bedava yazardı.
  bool get _asiyor =>
      _tur == IskontoTuru.tutar &&
      _girilen != null &&
      _girilen!.deger > widget.brutKurus;

  @override
  Widget build(BuildContext context) {
    final girilen = _girilen;
    final uygun = girilen != null && !_asiyor;
    final dusen = uygun ? girilen.kurus(widget.brutKurus) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlanNotu(
          '${widget.urunAd} için satır tutarı ${sipTutar(widget.brutKurus)}',
          tur: AlanNotuTuru.bilgi,
        ),
        const SizedBox(height: SipSpace.lg),
        SipSegment(
          secenekler: const ['Tutar (₺)', 'Yüzde (%)'],
          secili: _tur == IskontoTuru.tutar ? 0 : 1,
          onSec: (i) => setState(() {
            _tur = i == 0 ? IskontoTuru.tutar : IskontoTuru.yuzde;
            _deger.clear();
          }),
        ),
        const SizedBox(height: SipSpace.lg),
        SipInput(
          controller: _deger,
          ipucu: _tur == IskontoTuru.tutar ? '0,00' : '10',
          klavye: const TextInputType.numberWithOptions(decimal: true),
          girdiFiltreleri: [
            FilteringTextInputFormatter.allow(
              _tur == IskontoTuru.tutar ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
          ],
          otomatikOdak: true,
          hata: _asiyor,
          onChanged: (_) => setState(() {}),
        ),
        if (_asiyor) const AlanNotu('İskonto satır tutarından büyük olamaz'),
        if (uygun)
          AlanNotu(
            'Yeni satır tutarı ${sipTutar(widget.brutKurus - dusen)}',
            tur: AlanNotuTuru.bilgi,
          ),
        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'İskontoyu Uygula',
          onTap: uygun ? () => Navigator.of(context).pop(girilen) : null,
        ),
        if (!widget.mevcut.bos) ...[
          const SizedBox(height: SipSpace.md),
          SipButon(
            etiket: 'İskontoyu Kaldır',
            tur: SipButonTuru.ikincil,
            onTap: () => Navigator.of(context).pop(SatirIskontosu.yok),
          ),
        ],
      ],
    );
  }
}
