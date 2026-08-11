// SATIR NOTU — tek kaleme ait not ("buzlu olsun", "kapıya bırak"). Kullanıcı isteği 2026-08-11.
//
// NEDEN SİPARİŞ NOTU YETMİYOR: sipariş notu teslimatın TAMAMINA dairdir (kapı kodu, saat).
// Üç kalemli bir siparişte "buzlu olsun" yazıldığında hangi kaleme ait olduğunu okuyan kişi
// tahmin etmek zorunda kalıyordu. Satır notu kalemin kendisine yapışır.
//
// BU DOSYA ÜÇ ŞEYİ TEK YERDE TUTAR ve üçü de birbirine bağlıdır:
//  1. `notuNormalle` — yazma kuralı (kırp, boşsa null),
//  2. `SatirNotuRozeti` — GÖRÜNEN işaret (sepet, sipariş detayı, liste satırı aynısını çizer),
//  3. `satirNotuSheetAc` — girme yüzeyi.
// Not girilen yerle notun OKUNDUĞU yer ayrı dosyalarda yaşasaydı, biri değişip diğeri kalırdı:
// not girilir ama kimse okumaz — bu özelliğin en olası ölüm biçimi tam olarak budur.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Kullanıcının yazdığı satır notunu SAKLAMA biçimine çevirir: kırpılır, boşsa `null` olur.
/// Sepet, düzenleme sheet'i ve repo yazımı aynı kuralı uygulamak zorunda; biri boş dizgi
/// yazsaydı rozet "not var" deyip boş bir kutu çizerdi.
String? notuNormalle(String? ham) {
  final t = (ham ?? '').trim();
  return t.isEmpty ? null : t;
}

/// Ekran metinleri SÖZLEŞMEDİR — testler bu sabitlere bağlanır, dizgeye değil.
const String satirNotuEkleEtiketi = '+ Not ekle';
const String satirNotuSheetBasligi = 'Satır Notu';
const String satirNotuIpucu = 'Ör. buzlu olsun, kapıya bırak';
const String satirNotuKaydetEtiketi = 'Notu Kaydet';
const String satirNotuSilEtiketi = 'Notu Sil';

/// [satirNotuSheetAc] "notu sil" sonucunu BOŞ DİZGİYLE bildirir; `null` "vazgeçildi" demektir.
/// İkisi ayrı olmak zorunda: sheet'i kapatmak notu SİLMEK değildir (kurye seçim sheet'indeki
/// kararın aynısı — `order_sheets.dart`).
const String satirNotuSilindi = '';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Rozet — CSS `.srow-not` dili (warn-soft zemin + kalem ikonu)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Notu olan satırın GÖRÜNÜR işareti. Yeni görsel dil icat EDİLMEDİ: sipariş notunun kutusu
/// (`NotBolumu`, `.srow-not`) zaten warn-soft zemin + kalem ikonudur; satır notu onun küçüğüdür.
class SatirNotuRozeti extends StatelessWidget {
  const SatirNotuRozeti({super.key, required this.metin, this.punto = 11});

  final String metin;
  final double punto;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: t.warnSoft, borderRadius: SipRadius.br1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SipIcon(SipIcons.edit, boyut: punto, kalinlik: 2.1, renk: t.warn),
          ),
          const SizedBox(width: 5),
          // Test fontu ~1,8x geniştir; sabit genişlik yerine esneme — dar satırda taşma değil
          // kırpma olsun.
          Flexible(
            child: Text(
              metin,
              style: SipText.metin(punto, w: 700).copyWith(color: t.ink2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satırın not YÜZEYİ: notu varsa rozeti, yoksa sönük "+ Not ekle" bağlantısını çizer.
/// [onTap] null ise (salt-okunur/kayıtlı sipariş) yalnız rozet çizilir, bağlantı hiç görünmez —
/// dokunulamayan bir "+ Not ekle" bozuk düğmedir.
class SatirNotuYuzeyi extends StatelessWidget {
  const SatirNotuYuzeyi({super.key, required this.not, this.onTap});

  final String? not;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final metin = notuNormalle(not);
    if (metin == null && onTap == null) return const SizedBox.shrink();

    final govde = metin == null
        ? Text(satirNotuEkleEtiketi,
            style: SipText.metin(11, w: 700).copyWith(color: t.accent))
        : SatirNotuRozeti(metin: metin);

    if (onTap == null) return Align(alignment: Alignment.centerLeft, child: govde);
    return Align(
      alignment: Alignment.centerLeft,
      child: SipDokun(
        onTap: onTap,
        radius: SipRadius.br1,
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: govde,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Not girme sheet'i
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Satır notunu girer/düzenler. Dönüş: yeni not, [satirNotuSilindi] (boş dizgi) ya da `null`
/// (vazgeçildi — mevcut not DEĞİŞMEZ).
///
/// [urunAd] başlığın altında yazar: sepette üç kalem varken hangi satıra not yazdığını
/// söylemeyen bir kutu, yanlış kaleme not yazdırır.
Future<String?> satirNotuSheetAc(
  BuildContext context, {
  required String urunAd,
  String? mevcut,
}) =>
    sipSheet<String>(
      context,
      baslik: satirNotuSheetBasligi,
      govde: (ctx) => _SatirNotuFormu(urunAd: urunAd, mevcut: mevcut),
    );

class _SatirNotuFormu extends StatefulWidget {
  const _SatirNotuFormu({required this.urunAd, this.mevcut});

  final String urunAd;
  final String? mevcut;

  @override
  State<_SatirNotuFormu> createState() => _SatirNotuFormuState();
}

class _SatirNotuFormuState extends State<_SatirNotuFormu> {
  late final _taslak = TextEditingController(text: widget.mevcut ?? '');

  @override
  void dispose() {
    _taslak.dispose();
    super.dispose();
  }

  void _kaydet() => Navigator.of(context).pop(notuNormalle(_taslak.text) ?? satirNotuSilindi);

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final notVar = notuNormalle(widget.mevcut) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.urunAd,
            style: SipText.metin(13, w: 800).copyWith(color: t.ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: SipSpace.md),
        SipInput(
          controller: _taslak,
          ipucu: satirNotuIpucu,
          satirlar: 2,
          otomatikOdak: true,
        ),
        const SizedBox(height: SipSpace.x3),
        Row(
          children: [
            // Silme yalnız NOTU OLAN satırda sunulur: olmayan bir şeyi silme düğmesi, kullanıcıya
            // "bir şeyi kaçırdım mı" dedirtir.
            if (notVar) ...[
              Expanded(
                child: SipButon(
                  etiket: satirNotuSilEtiketi,
                  tur: SipButonTuru.ikincil,
                  yukseklik: 44,
                  onTap: () => Navigator.of(context).pop(satirNotuSilindi),
                ),
              ),
              const SizedBox(width: SipSpace.md),
            ],
            Expanded(
              child: SipButon(
                etiket: satirNotuKaydetEtiketi,
                yukseklik: 44,
                onTap: _kaydet,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
