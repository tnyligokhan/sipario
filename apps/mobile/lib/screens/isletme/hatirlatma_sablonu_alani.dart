// HATIRLATMA MESAJI ŞABLONU — İşletme Profili'nin "Hatırlatma Mesajı" bölümü.
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
    show hatirlatmaYerTutuculari, varsayilanHatirlatmaSablonu;
import '../../theme/components/atoms.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'isletme_atomlari.dart';

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
  });

  final TextEditingController controller;

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
    if (controller.text.trim().isNotEmpty) return;
    controller.value = TextEditingValue(
      text: varsayilanHatirlatmaSablonu,
      selection: TextSelection.collapsed(offset: varsayilanHatirlatmaSablonu.length),
    );
    onDegis?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipBolumBaslik('Hatırlatma Mesajı', ustBosluk: 20),
        SipInput(
          controller: controller,
          ipucu: 'Boş bırakılırsa varsayılan mesaj gönderilir',
          satirlar: 5,
          hata: hata != null,
          onChanged: (_) => onDegis?.call(),
        ),
        if (hata != null) AlanNotu(hata!),
        _CipSeridi(onSec: _ekle, onVarsayilan: _varsayilaniYukle),
        // "KENDİ SATIRINA koyun" uyarısı bilinçli (inceleme notu 2026-08-06): IBAN + alıcı adı
        // ÇOK SATIRLI bir bloktur, satır içinde kullanılırsa devamındaki metin bloğun altına
        // düşer. Blok tek satıra sıkıştırılmıyor — IBAN'ın dörderli gruplar hâlinde kendi
        // satırında durması, müşterinin bankadaki biçimle karşılaştırmasının tek güvencesi.
        const AlanNotu(
          'Çipe dokununca imlecin olduğu yere eklenir. IBAN\'ı kendi satırına koyun.',
          tur: AlanNotuTuru.bilgi,
        ),
      ],
    );
  }
}

/// Yer tutucu çipleri + "Varsayılanı yükle". Sarmalanır (`Wrap`): dört çip dar ekranda tek
/// satıra sığmaz ve yatay kaydırma, bayinin göremediği bir çipi gizlerdi.
class _CipSeridi extends StatelessWidget {
  const _CipSeridi({required this.onSec, required this.onVarsayilan});

  final ValueChanged<String> onSec;
  final VoidCallback onVarsayilan;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.md),
      child: Wrap(
        spacing: SipSpace.sm,
        runSpacing: SipSpace.sm,
        children: [
          for (final y in hatirlatmaYerTutuculari)
            _Cip(
              etiket: y.aciklama,
              renk: t.accent,
              zemin: t.accentSoft,
              onTap: () => onSec(y.jeton),
            ),
          // Ayrı renkte: yer tutucu EKLEMEZ, alanın tamamını doldurur — aynı görünseydi
          // bayi onu da bir yer tutucu sanıp cümlesinin ortasına dokunurdu.
          _Cip(
            etiket: 'Varsayılanı yükle',
            renk: t.ink2,
            zemin: t.surface2,
            onTap: onVarsayilan,
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
