// SEKMELERİN ALTINDAKİ ARAÇ ŞERİDİ — "Harita" ve kurye süzgeci çipleri.
//
// NEDEN VAR (2026-08-01): bu iki eylem başlıkta, "Sırala" ile yan yana duran ÇIPLAK İKON
// düğmeleriydi. Pin ile kamyonun ne yaptığını ancak dokunarak öğrenebiliyordunuz ve kurye
// süzgecinin açık olduğunu yalnız düğmenin rengi söylüyordu — kimin listesine bakıldığı
// başlığın alt satırına sıkışmıştı. Şerit ikisini de ETİKETLİ hap çipe çevirir: süzgecin
// durumu ("Kurye: Tümü" / "Kurye: Ali") artık okunur, başlık da tek eyleme ("Sırala") iner.
//
// Çipler sipariş satırındaki kurye çipiyle AYNI hap kalıbını kullanır (`order_row.dart`
// `_KuryeCipi`): ekranın iki ayrı yerinde iki farklı çip dili konuşulmaz.
//
// Elle sıralama kipinde şeridin tamamı gizlenir — kararı ÇAĞIRAN verir (bu dosya kip bilmez):
// sıra yazılırken listenin altından küme değişmemeli.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Sekmeler ile liste arasındaki tek satır: solda "Harita", sağda kurye süzgeci.
class SiparisAracSeridi extends StatelessWidget {
  const SiparisAracSeridi({
    super.key,
    required this.onHarita,
    this.onKurye,
    this.kuryeAdi,
  });

  /// Harita ekranını açar. HER ZAMAN çizilir: bu ekran zaten açık siparişleri gösteriyor ve
  /// haritanın göstereceği tam olarak o kümedir — duruma göre gizlemek yeteneği bulunamaz
  /// kılardı.
  final VoidCallback onHarita;

  /// Kurye süzgeci. `null` → çip HİÇ çizilmez (yalnız patron görür — `kuryeSuzgeciGorunur`;
  /// kurye kendi işini görür, ona süzgeç gürültüdür).
  final VoidCallback? onKurye;

  /// Seçili kuryenin adı. `null` = süzgeç kapalı → çip "Kurye: Tümü" der ve sönük çizilir.
  final String? kuryeAdi;

  @override
  Widget build(BuildContext context) {
    final kurye = onKurye;
    return Row(
      children: [
        SiparisAracCipi(
          ikon: SipIcons.pin,
          etiket: 'Harita',
          onTap: onHarita,
        ),
        const Spacer(),
        if (kurye != null)
          SiparisAracCipi(
            ikon: SipIcons.truck,
            // Süzgecin DEĞERİ etiketin içinde yazar: renk tek başına "hangi kurye" sorusunu
            // yanıtlamıyordu ve renk körü kullanıcıya hiçbir şey söylemiyordu.
            etiket: 'Kurye: ${kuryeAdi ?? 'Tümü'}',
            vurgulu: kuryeAdi != null,
            onTap: kurye,
          ),
      ],
    );
  }
}

/// Şeritteki tek çip — hap kalıbı, ikon + etiket. [vurgulu] çip AKTİF bir süzgeci gösterir:
/// accentSoft zemin + accent mürekkep (sipariş satırındaki seçili durumların dili).
class SiparisAracCipi extends StatelessWidget {
  const SiparisAracCipi({
    super.key,
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.vurgulu = false,
  });

  final String ikon;
  final String etiket;
  final VoidCallback onTap;
  final bool vurgulu;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final murekkep = vurgulu ? t.accent : t.ink2;
    return Semantics(
      button: true,
      child: SipDokun(
        onTap: onTap,
        zemin: vurgulu ? t.accentSoft : t.surface,
        basiliZemin: t.surface2,
        radius: SipRadius.brHap,
        kenarlik: Border.all(color: vurgulu ? t.accentSoft : t.line2),
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2),
        child: SizedBox(
          // Dokunma hedefi: hap yüksekliği 40 (harita kontrol düğmeleriyle aynı çap). İç boşluk
          // tek başına 30 pikselde kalıyordu — başparmakla ıskalanan bir süzgeç, olmayan bir
          // süzgeçtir.
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SipIcon(ikon, boyut: 15, kalinlik: 2.2, renk: murekkep),
              const SizedBox(width: SipSpace.sm),
              Text(etiket, style: SipText.ustMetin.copyWith(color: murekkep)),
            ],
          ),
        ),
      ),
    );
  }
}
