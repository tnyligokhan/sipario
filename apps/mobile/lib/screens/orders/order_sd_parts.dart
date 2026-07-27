// Sipariş DETAY/ÖZET kartı parçaları + serbest satır sheet'i.
// CSS: `.sd-kart`, `.sd-satir`, `.sd-toplam`, `.sdx-link`, `.sdx-bos`, `.sb-form`, `.ym-err`.
//
// Yeni sipariş özeti, sipariş detayı ve düzenleme sheet'i AYNI kart dilini konuşur — tek yerde
// durur. `order_parts.dart` bu dosyayı yeniden dışa aktarır; ekranlar tek import ile ikisine erişir.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'order_parts.dart' show LineDraft;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Detay kartı — CSS `.sd-kart`, `.sd-satir`, `.sd-toplam`
// ═══════════════════════════════════════════════════════════════════════════════════════════

class SdKart extends StatelessWidget {
  const SdKart({
    super.key,
    required this.satirlar,
    required this.toplamKurus,
    this.toplamEtiketi = 'Toplam',
  });

  final List<Widget> satirlar;
  final int toplamKurus;
  final String toplamEtiketi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      margin: const EdgeInsets.only(top: SipSpace.xs),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x3),
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...satirlar,
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 13, 0, 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(toplamEtiketi,
                      style: SipText.metin(13, w: 600).copyWith(color: t.ink2)),
                ),
                Text(sipTutar(toplamKurus), style: SipText.tutar19.copyWith(color: t.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.sd-satir` — ad + birim açıklaması solda, satır toplamı sağda; altta ince ayraç.
class SdSatiri extends StatelessWidget {
  const SdSatiri({
    super.key,
    required this.ad,
    required this.altMetin,
    required this.tutarKurus,
    this.orta,
  });

  final String ad;
  final String altMetin;
  final int tutarKurus;

  /// Düzenleme kipinde araya giren stepper / sil düğmesi.
  final Widget? orta;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: SipSpace.xl),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad, style: SipText.metin(13.5, w: 600).copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Text(altMetin, style: SipText.metin(11, w: 500).copyWith(color: t.muted)),
              ],
            ),
          ),
          if (orta != null) ...[
            const SizedBox(width: SipSpace.xl),
            orta!,
          ],
          const SizedBox(width: SipSpace.xl),
          Text(sipTutar(tutarKurus), style: SipText.tutar(13).copyWith(color: t.ink)),
        ],
      ),
    );
  }
}

/// CSS `.sdx-sec` — sipariş ekranlarının bölüm başlığı. Paylaşılan [SipBolumBaslik] KULLANILMAZ:
/// o `.ana-baslik`/`.md-baslik`/`.gs-baslik` (14,5 px) karşılığıdır, `.sdx-sec` ise 14 px
/// (_sayfa.html:563) ve yalnız s-siparisler.jsx'te geçer — punto farkı bu ekranlara özgü.
class SdxSec extends StatelessWidget {
  const SdxSec(
    this.metin, {
    super.key,
    this.sag,
    this.ustBosluk = 18,
    this.altBosluk = 7,
  });

  final String metin;

  /// Sağdaki `.sdx-link` bağlantısı ya da `.sdx-adet` sayacı.
  final Widget? sag;

  final double ustBosluk;
  final double altBosluk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, ustBosluk, 2, altBosluk),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              metin,
              style: SipText.bolumBaslik
                  .copyWith(color: context.sip.ink, fontSize: 14),
            ),
          ),
          ?sag,
        ],
      ),
    );
  }
}

/// CSS `.sdx-link` — bölüm başlığının sağındaki düz accent bağlantı (zemin YOK).
/// Punto 12 (_sayfa.html:564); paylaşılan [SipText.link] 12,5'tir çünkü `.ym-telekle` öyle.
class SdxLink extends StatelessWidget {
  const SdxLink({super.key, required this.etiket, required this.onTap});

  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      radius: SipRadius.br1,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: 2),
      child: Text(etiket, style: SipText.link.copyWith(color: t.accent, fontSize: 12)),
    );
  }
}

/// CSS `.sdx-bos` — bölümün boş olduğunu söyleyen sönük tek satır.
class SdxBos extends StatelessWidget {
  const SdxBos(this.metin, {super.key});
  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
        child: Text(metin,
            style: SipText.metin(12.5, w: 500).copyWith(color: context.sip.muted)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Serbest satır sheet'i — CSS `.sb-form`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// "Serbest Satır" sheet'i: katalogda olmayan tek seferlik iş (nakliye, montaj…).
/// Ürün kaydı OLUŞTURMAZ — satır `productId == null` + `isCustom == true` olarak saklanır.
Future<LineDraft?> serbestSatirSheetAc(BuildContext context) => sipSheet<LineDraft>(
      context,
      baslik: 'Serbest Satır',
      govde: (ctx) => const _SerbestForm(),
    );

class _SerbestForm extends StatefulWidget {
  const _SerbestForm();

  @override
  State<_SerbestForm> createState() => _SerbestFormState();
}

class _SerbestFormState extends State<_SerbestForm> {
  final _ad = TextEditingController();
  final _tutar = TextEditingController();
  String? _adHata;
  String? _tutarHata;

  @override
  void dispose() {
    _ad.dispose();
    _tutar.dispose();
    super.dispose();
  }

  void _ekle() {
    final ad = _ad.text.trim();
    final lira = int.tryParse(_tutar.text.trim());
    setState(() {
      _adHata = ad.length < 2 ? 'Açıklama girin (en az 2 karakter)' : null;
      _tutarHata = (lira == null || lira <= 0) ? 'Tutar 0’dan büyük olmalı' : null;
    });
    if (_adHata != null || _tutarHata != null) return;
    // Tasarım tam lira alıyor (`Number(sbTutar) * 100`); para int kuruşa burada çevrilir.
    Navigator.of(context).pop(LineDraft(name: ad, unitPriceKurus: lira! * 100));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipFormEtiket('Açıklama', ustBosluk: 2),
        SipInput(
          controller: _ad,
          ipucu: 'Ör. Nakliye, montaj, ek iş',
          otomatikOdak: true,
          hata: _adHata != null,
          onChanged: (_) {
            if (_adHata != null) setState(() => _adHata = null);
          },
        ),
        if (_adHata != null) HataSatiri(_adHata!),
        const SipFormEtiket('Tutar (₺)'),
        SipInput(
          controller: _tutar,
          ipucu: '0',
          klavye: TextInputType.number,
          girdiFiltreleri: [FilteringTextInputFormatter.digitsOnly],
          hata: _tutarHata != null,
          onChanged: (_) {
            if (_tutarHata != null) setState(() => _tutarHata = null);
          },
          onSubmitted: (_) => _ekle(),
        ),
        if (_tutarHata != null) HataSatiri(_tutarHata!),
        const SizedBox(height: SipSpace.x3),
        SipButon(etiket: 'Ekle', onTap: _ekle),
      ],
    );
  }
}

/// CSS `.ym-err` — alan altındaki tek satırlık kırmızı hata.
class HataSatiri extends StatelessWidget {
  const HataSatiri(this.metin, {super.key});
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.sm),
      child: Row(
        children: [
          SipIcon(SipIcons.alert, boyut: 13, kalinlik: 2.2, renk: t.danger),
          const SizedBox(width: 5),
          Expanded(
            child: Text(metin, style: SipText.metin(12, w: 700).copyWith(color: t.danger)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Yeni siparişin müşteri seçim satırı — CSS `.mrow`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Adım 1'in müşteri satırı — CSS `.mrow`. Müşteri liste ekranından sembol ödünç ALINMAZ — o ekran
/// başka bir ajanın alanı ve eşzamanlı yeniden yazılıyor; ödünç alınan bir satır iki ekranı
/// birbirine kilitlerdi.
///
/// Tasarımın `.mrow`u AVATAR ÇİZMEZ (s-siparisler.jsx:316-324): satırda ad, telefon ve adres var.
/// Sipariş açan kişi doğru müşteriyi telefondan/adresten ayırt eder — aynı adı taşıyan iki
/// müşteride baş harf avatarı hiçbir şey söylemez, telefon söyler.
class MusteriSecimSatiri extends StatelessWidget {
  const MusteriSecimSatiri({
    super.key,
    required this.musteri,
    required this.onTap,
    this.telefon,
    this.adres,
  });

  final Customer musteri;
  final VoidCallback onTap;

  /// CSS `.mrow-tel` — birincil telefon (E.164 saklanır, burada biçimlenir).
  final String? telefon;

  /// CSS `.mrow-adres` — birincil adresin tam metni; ikon konum kayıtlıysa yeşil.
  final MrowAdres? adres;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // .mrow-mid — gap 3
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  musteri.name,
                  style: SipText.satirAd.copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // .mrow-tel — telefon yoksa tasarım "—" yazar (satır hiç kaybolmaz).
                Row(
                  children: [
                    SipIcon(SipIcons.phone, boyut: 12.5, kalinlik: 2, renk: t.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (telefon ?? '').isEmpty ? '—' : sipTelefon(telefon!),
                        style: SipText.satirTel.copyWith(color: t.ink2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (adres != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: SipIcon(SipIcons.pin,
                            boyut: 12.5, kalinlik: 2, renk: adres!.konumVar ? t.ok : t.muted),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          adres!.metin,
                          style: SipText.satirAdres.copyWith(color: t.ink2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: SipSpace.lg),
          // .mrow-bal — `align-self: center`; bakiye 0 ise hiç çizilmez.
          Center(child: SipBakiyeCipi(kurus: musteri.balanceKurus)),
          const SizedBox(width: SipSpace.sm),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SipIcon(SipIcons.chevR, boyut: 17, kalinlik: 2, renk: t.line2),
          ),
        ],
      ),
    );
  }
}

/// [MusteriSecimSatiri]nin adres girdisi. `AdresBilgi`ye bağlanmaz: bu satır sorgu katmanını
/// değil yalnız iki alanı bilir (metin + konum var mı), böylece özet ekranı da aynı tipi verir.
class MrowAdres {
  const MrowAdres({required this.metin, this.konumVar = false});
  final String metin;
  final bool konumVar;
}
