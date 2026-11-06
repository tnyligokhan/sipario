// MESAJ METNİ ALANI — Mesajlar ekranının çok satırlı alanı ve yer tutucu çipleri.
// Kullanıcı isteği 2026-08-06: "Mesaj şablonunu bu iki sabit bilgi haricinde düzenleyebilmeli."
//
// NEDEN AYRI DOSYA: `isletme_profili_ekrani.dart` 500 satır sınırına dayanmıştı ve bu bölüm
// tek başına bir çok satırlı alan + çip şeridi + iki nottan oluşuyor. Bölüm kendi içinde
// kapalıdır: dışarıya yalnız bir controller ve bir hata metni ister.
//
// ÇİPLER EZBERİ KALDIRIR: yer tutucular (`*musteriadi*` …) dokunulunca İMLECE eklenir. Bayi
// hangi dizinin ne yaptığını hatırlamak zorunda kalmamalı — hatırlamak zorunda kalırsa ya hiç
// düzenlemez ya da yanlış yazıp mesajın içinde ham bir `*siparistutari*` gönderir.

import 'package:flutter/material.dart';

import '../../screens/customers/borc_hatirlatma.dart'
    show
        HatirlatmaYerTutucu,
        hatirlatmaSablonuUygula,
        hatirlatmaYerTutuculari,
        varsayilanHatirlatmaSablonu;
import '../../theme/components/atoms.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'isletme_atomlari.dart';
import 'whatsapp_bicim_cubugu.dart';

/// İmleç konumuna [jeton] ekler; metin seçiliyse SEÇİMİN YERİNE geçer ve imleç eklenen dizinin
/// sonuna taşınır. SAF — widget kurmadan sınanır.
///
/// Seçim geçersizken (alan hiç odaklanmadıysa `baseOffset` −1'dir) jeton METNİN SONUNA eklenir:
/// 0. konuma yazmak, bayinin yazdığı cümlenin BAŞINA sıkıştırırdı.
TextEditingValue jetonEkle(TextEditingValue mevcut, String jeton) {
  final metin = mevcut.text;
  final secim = mevcut.selection;
  final gecerli = secim.isValid && secim.start >= 0 && secim.end <= metin.length;

  final bas = gecerli ? secim.start : metin.length;
  final son = gecerli ? secim.end : metin.length;

  return TextEditingValue(
    text: metin.replaceRange(bas, son, jeton),
    selection: TextSelection.collapsed(offset: bas + jeton.length),
  );
}

class HatirlatmaSablonuAlani extends StatelessWidget {
  const HatirlatmaSablonuAlani({
    super.key,
    required this.controller,
    this.hata,
    this.onDegis,
    this.baslik = 'Hatırlatma Mesajı',
    this.yerTutucular = hatirlatmaYerTutuculari,
    this.varsayilanMetin = varsayilanHatirlatmaSablonu,
    this.ipucu = 'Boş bırakılırsa varsayılan mesaj gönderilir',
    this.satirlar = 5,
  });

  final TextEditingController controller;
  final String baslik;
  final List<HatirlatmaYerTutucu> yerTutucular;

  /// null ise "Varsayılanı yükle" çipi çizilmez: bayinin kendi mesajının varsayılanı yoktur.
  final String? varsayilanMetin;
  final String ipucu;
  final int satirlar;

  /// Doğrulama hatası (uzunluk sınırı) — yoksa null.
  final String? hata;

  /// Metin ya da çip dokunuşuyla içerik değişti.
  final VoidCallback? onDegis;

  void _ekle(String jeton) {
    controller.value = jetonEkle(controller.value, jeton);
    onDegis?.call();
  }

  /// Boş alana varsayılan metni yazar — bayinin sıfırdan cümle kurması gerekmesin.
  /// DOLU alanı EZMEZ: tek dokunuşla bayinin yazdığı metni silmek geri alınamaz bir kayıptır.
  void _varsayilaniYukle() {
    final metin = varsayilanMetin;
    if (metin == null || controller.text.trim().isNotEmpty) return;
    controller.value = TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(offset: metin.length),
    );
    onDegis?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SipBolumBaslik(baslik, ustBosluk: 20),
        WhatsappBicimCubugu(controller: controller, onDegis: onDegis),
        SipInput(
          controller: controller,
          ipucu: ipucu,
          satirlar: satirlar,
          hata: hata != null,
          onChanged: (_) => onDegis?.call(),
        ),
        if (hata != null) AlanNotu(hata!),
        _CipSeridi(
          yerTutucular: yerTutucular,
          onSec: _ekle,
          onVarsayilan: varsayilanMetin == null ? null : _varsayilaniYukle,
        ),
        // "KENDİ SATIRINA koyun" uyarısı bilinçli (inceleme notu 2026-08-06): IBAN + alıcı adı
        // ÇOK SATIRLI bir bloktur, satır içinde kullanılırsa devamındaki metin bloğun altına
        // düşer. Blok tek satıra sıkıştırılmıyor — IBAN'ın dörderli gruplar hâlinde kendi
        // satırında durması, müşterinin bankadaki biçimle karşılaştırmasının tek güvencesi.
        const AlanNotu(
          'Çipe dokununca imlecin olduğu yere eklenir. IBAN\'ı kendi satırına koyun.',
          tur: AlanNotuTuru.bilgi,
        ),
        _Onizleme(controller: controller, yerTutucular: yerTutucular),
      ],
    );
  }
}

/// Metnin müşteride nasıl görüneceği. Yer tutucular adlarıyla gösterilir: bayi gerçek bir müşteri
/// adı beklemez, ama çözüm yine gerçek yoldan geçer ki kalın yer tutucu da doğru çizilsin.
class _Onizleme extends StatelessWidget {
  const _Onizleme({required this.controller, required this.yerTutucular});

  final TextEditingController controller;
  final List<HatirlatmaYerTutucu> yerTutucular;

  @override
  Widget build(BuildContext context) {
    final degerler = {for (final y in yerTutucular) y.jeton: y.aciklama};
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, deger, _) {
        final metin = hatirlatmaSablonuUygula(deger.text, degerler: degerler);
        if (metin.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SipBolumBaslik('Önizleme', ustBosluk: 18),
            WhatsappOnizleme(metin: metin),
          ],
        );
      },
    );
  }
}

/// Yer tutucu çipleri + "Varsayılanı yükle". Sarmalanır (`Wrap`): dört çip dar ekranda tek
/// satıra sığmaz ve yatay kaydırma, bayinin göremediği bir çipi gizlerdi.
class _CipSeridi extends StatelessWidget {
  const _CipSeridi({
    required this.yerTutucular,
    required this.onSec,
    required this.onVarsayilan,
  });

  final List<HatirlatmaYerTutucu> yerTutucular;
  final ValueChanged<String> onSec;
  final VoidCallback? onVarsayilan;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.md),
      child: Wrap(
        spacing: SipSpace.sm,
        runSpacing: SipSpace.sm,
        children: [
          for (final y in yerTutucular)
            _Cip(
              etiket: y.aciklama,
              renk: t.accent,
              zemin: t.accentSoft,
              onTap: () => onSec(y.jeton),
            ),
          // Ayrı renkte: yer tutucu EKLEMEZ, alanın tamamını doldurur — aynı görünseydi
          // bayi onu da bir yer tutucu sanıp cümlesinin ortasına dokunurdu.
          if (onVarsayilan != null)
            _Cip(
              etiket: 'Varsayılanı yükle',
              renk: t.ink2,
              zemin: t.surface2,
              onTap: onVarsayilan!,
            ),
        ],
      ),
    );
  }
}

class _Cip extends StatelessWidget {
  const _Cip({
    required this.etiket,
    required this.renk,
    required this.zemin,
    required this.onTap,
  });

  final String etiket;
  final Color renk;
  final Color zemin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: SipDokun(
        onTap: onTap,
        zemin: zemin,
        radius: SipRadius.brHap,
        olcekle: true,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(etiket, style: SipText.metin(12, w: 700).copyWith(color: renk)),
      ),
    );
  }
}
