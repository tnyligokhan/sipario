// Sipario paylaşılan atomlar — FORM ÖĞELERİ.
// Kaynak CSS: `.s-flabel`, `.s-input`, `.s-textarea`, `.arama`, `.segtab`, `.aktif-toggle`,
// `.aktif-knob`.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../tokens.dart';
import '../typography.dart';
import 'bicim.dart';
export 'form_kontroller.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Girdi ölçüleri — TEK KAYNAK
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// CSS `.s-input` / `.s-textarea` ölçüleri. Hem [SipInput] hem `SipTheme.inputDecorationTheme`
/// buradan okur — iki yerde ayrı sayı tutulmaz.
///
/// NEDEN BURADA: Flutter'da girdinin BOYANAN yüksekliği `InputDecoration.constraints` ile
/// verilemez. `constraints` yalnız dekoratörün ETRAFINA bir `ConstrainedBox` sarar
/// (`input_decorator.dart` :2673); boyanan kutu ise
/// `containerHeight = contentPadding.vertical + satırYüksekliği` ile hesaplanır (:1107-1123)
/// ve yuvanın ÜSTÜNE, `Offset(x, 0)` ile yapışık çizilir (:1392-1401). Yani dikey dolgu 0
/// verilip `constraints: 46` denirse kutu ~19,5 px çizilir ve ALTTA ~26 px ölü boşluk kalır.
/// Bu yüzden yükseklik DAİMA dolgudan türetilir: `dolgu + satır + dolgu = hedef`.
abstract final class SipInputOlcu {
  /// CSS `.s-input { height: 46px }` — `box-sizing: border-box`, yani kenarlık dâhil.
  static const double yukseklik = 46;

  /// CSS `.s-input { padding: 0 14px }`.
  static const double yatayDolgu = SipSpace.x2;

  /// CSS `.s-textarea { padding: 11px 14px }` — çok satırlıda yükseklik satır sayısından gelir.
  static const double cokSatirDikeyDolgu = 11;

  /// CSS `.s-input { border: 1.5px solid }`.
  static const double kenarKalinlik = 1.5;

  /// Tek satırlı girdide satır yüksekliği çarpanı.
  ///
  /// SABİTLENMEK ZORUNDA: dikey dolguyu Dart tarafında hesaplayabilmek için satır
  /// yüksekliğinin bilinmesi gerekir. Fontun doğal metriğine bırakılırsa (Hanken Grotesk
  /// 1.303, Sora 1.26) değer yalnız çizim anında bilinir ve dolgu türetilemez.
  static const double satirCarpani = 1.2;

  static OutlineInputBorder kenar(Color c) => OutlineInputBorder(
        borderRadius: SipRadius.br2,
        borderSide: BorderSide(color: c, width: kenarKalinlik),
      );

  /// [stil] ile yazılan tek satırın kaplayacağı yükseklik.
  static double satirYuksekligi(TextStyle stil) =>
      (stil.fontSize ?? SipText.input.fontSize!) * (stil.height ?? satirCarpani);

  /// [hedef] yüksekliği tutturmak için gereken dikey iç boşluk.
  static double dikeyDolgu(TextStyle stil, double hedef) =>
      math.max(0, (hedef - satirYuksekligi(stil)) / 2);
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Form öğeleri
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// CSS `.s-flabel` — form alanı üstündeki BÜYÜK HARF etiket.
class SipFormEtiket extends StatelessWidget {
  const SipFormEtiket(this.metin, {super.key, this.ustBosluk = 14});

  final String metin;
  final double ustBosluk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: ustBosluk, bottom: 6),
      child: Text(
        trBuyuk(metin),
        style: SipText.formEtiket.copyWith(color: context.sip.muted),
      ),
    );
  }
}

/// CSS `.s-input` — 46 yüksek, surface-2 zemin, odakta accent kenarlık + surface zemin.
class SipInput extends StatelessWidget {
  const SipInput({
    super.key,
    this.controller,
    this.ipucu,
    this.klavye,
    this.girdiFiltreleri,
    this.onChanged,
    this.onSubmitted,
    this.hata = false,
    this.aktif = true,
    this.gizli = false,
    this.satirlar = 1,
    this.odakDugumu,
    this.stil,
    this.yukseklik,
    this.hizalama = TextAlign.start,
    this.buyukHarfKipi = TextCapitalization.sentences,
    this.otomatikOdak = false,
    this.sonEk,
  });

  final TextEditingController? controller;
  final String? ipucu;
  final TextInputType? klavye;
  final List<TextInputFormatter>? girdiFiltreleri;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// CSS `.s-input.err` — danger kenarlık + danger-soft zemin.
  final bool hata;

  final bool aktif;
  final bool gizli;

  /// >1 ise `.s-textarea` davranışı.
  final int satirlar;

  final FocusNode? odakDugumu;
  final TextStyle? stil;
  final double? yukseklik;
  final TextAlign hizalama;
  final TextCapitalization buyukHarfKipi;
  final bool otomatikOdak;

  /// Alanın SAĞ İÇİNE yerleşen eylem (parolayı göster/gizle gibi).
  ///
  /// Yükseklik sözleşmesi (46 px) korunmak ZORUNDA: `suffixIcon` kısıtsız bırakılırsa
  /// Material varsayılanı 48×48 dayatır ve kutu iki piksel uzayarak yanındaki alanlarla
  /// hizasını kaybeder. Kısıt aşağıda `yukseklik`e bağlanır — çağıran kutuyu büyütürse
  /// son ek de onunla büyür.
  final Widget? sonEk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final cokSatir = satirlar > 1;
    final temel = stil ?? (cokSatir ? SipText.textarea : SipText.input);

    // Tek satırda satır yüksekliği sabitlenir ve dolgu ondan türetilir; çok satırlıda CSS
    // `.s-textarea` line-height vermediği için fontun doğal metriği korunur ve dolgu sabittir.
    final etkin = cokSatir
        ? temel
        : temel.copyWith(height: temel.height ?? SipInputOlcu.satirCarpani);
    final dikey = cokSatir
        ? SipInputOlcu.cokSatirDikeyDolgu
        : SipInputOlcu.dikeyDolgu(etkin, yukseklik ?? SipInputOlcu.yukseklik);

    return TextField(
      controller: controller,
      focusNode: odakDugumu,
      enabled: aktif,
      obscureText: gizli,
      keyboardType: klavye ?? (cokSatir ? TextInputType.multiline : null),
      inputFormatters: girdiFiltreleri,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      minLines: satirlar,
      maxLines: cokSatir ? satirlar : 1,
      textAlign: hizalama,
      textCapitalization: buyukHarfKipi,
      autofocus: otomatikOdak,
      cursorColor: t.accent,
      style: etkin.copyWith(color: aktif ? t.ink : t.muted),
      decoration: InputDecoration(
        hintText: ipucu,
        // İpucu ile metnin satır yüksekliği AYNI olmak ZORUNDA: kutunun yüksekliği
        // `max(ipucuYüksekliği, metinYüksekliği)` (`input_decorator.dart` :1080-1083), yani
        // ipucuya çarpan verilmezse kutu yazmaya başlayınca zıplar.
        hintStyle: etkin.copyWith(color: t.muted),
        suffixIcon: sonEk,
        suffixIconConstraints: BoxConstraints(
          minWidth: 40,
          minHeight: 0,
          maxHeight: yukseklik ?? SipInputOlcu.yukseklik,
        ),
        filled: true,
        fillColor: hata ? t.dangerSoft : t.surface2,
        isDense: true,
        // Yükseklik dolgudan geldiği için yoğunluk sabitlenir — masaüstü varsayılanı
        // (`VisualDensity.compact`) kutuyu 2 px kısaltırdı.
        visualDensity: VisualDensity.standard,
        contentPadding: EdgeInsets.symmetric(
          horizontal: SipInputOlcu.yatayDolgu,
          vertical: dikey,
        ),
        border: SipInputOlcu.kenar(hata ? t.danger : Colors.transparent),
        enabledBorder: SipInputOlcu.kenar(hata ? t.danger : Colors.transparent),
        disabledBorder: SipInputOlcu.kenar(Colors.transparent),
        focusedBorder: SipInputOlcu.kenar(hata ? t.danger : t.accent),
      ),
    );
  }
}

/// CSS `.arama` — hap biçimli arama çubuğu (büyüteç + alan + temizle).
class SipArama extends StatelessWidget {
  const SipArama({
    super.key,
    required this.controller,
    this.ipucu = 'Ara',
    this.onChanged,
    this.onTemizle,
    this.otomatikOdak = false,
  });

  final TextEditingController controller;
  final String ipucu;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTemizle;

  /// Ekran açılır açılmaz klavyeyi getirir. VARSAYILAN KAPALI: aramanın ekranın tek işi
  /// olmadığı yerlerde (liste ekranları) açılışta yükselen klavye içeriğin yarısını yer.
  /// Yalnız aramanın ekranın TEK işi olduğu yerde açılır — sipariş formunun müşteri adımı
  /// gibi (tasarım `autoFocus`, s-siparisler.jsx:305): telefonu elinde tutan kullanıcı adı
  /// duyduğu anda yazmaya başlar, önce alana dokunmak zorunda kalmaz.
  final bool otomatikOdak;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x3),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: SipRadius.brHap,
      ),
      child: Row(
        children: [
          SipIcon(SipIcons.search, boyut: 19, kalinlik: 2, renk: t.muted),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: otomatikOdak,
              cursorColor: t.accent,
              style: SipText.aramaInput.copyWith(color: t.ink),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: ipucu,
                // CSS `.arama input::placeholder` yalnız RENGİ değiştirir — punto aynı kalır.
                hintStyle: SipText.aramaInput.copyWith(color: t.muted),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTemizle,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SipIcon(SipIcons.x, boyut: 17, kalinlik: 2.2, renk: t.muted),
              ),
            ),
        ],
      ),
    );
  }
}
