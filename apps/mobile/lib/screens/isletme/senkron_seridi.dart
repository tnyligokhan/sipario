// SUNUCUYA SON ULAŞMA şeridi — kurye kapanışı ve ara tahsilat sheet'inde (lead kararı 2026-08-06).
//
// NEDEN AYRI DOSYA: iki sheet de bunu kullanıyor. `gun_sonu_kartlari.dart`a koymak, o dosya
// `gun_kapatma_sheet.dart`ı zaten import ettiği için iki yönlü bir import doğuruyordu; şeridi
// kimsenin altında olmayan kendi dosyasına almak zinciri düzleştiriyor.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_sonu_ozet.dart' show SenkronTazeligi;

/// Cihazın sunucuyla son temasını söyleyen şerit.
///
/// NEDEN VAR: kurye kapanışında ve ara tahsilatta beklenen nakit YEREL `cash_handovers`tan çıkar.
/// Patron kendi telefonundan ara tahsilat alır ve kuryenin telefonu çevrimdışıysa, kurye ŞİŞİK bir
/// beklenen tutar görür; o hâlde kapatırsa arşive gerçek dışı bir rakam DONAR (append-only →
/// kalıcı). Kapanışı çevrimiçi-zorunlu yapmak BRIEF'in "internetsiz TAM çalışır" çizgisini
/// keserdi, o yüzden borç bilinçli tutuluyor ve yalnız GÖRÜNÜR kılınıyor.
///
/// ENGELLEMEZ, SÖYLER: bayatken de kapatma düğmesi çalışır. Karar bayinindir — bodrumdaki kuryeyi
/// kasa kapatamaz hâle getiremeyiz.
///
/// DİL DÜRÜST: "sunucuya son ulaşma" yazar; "son senkron", "veriler güncel", "senkronize" YAZMAZ.
/// Ölçtüğü şey son TEMAStır, eksiksiz uygulanmış tur değil (bkz. [SenkronTazeligi]) — damga
/// satırlar uygulanmadan ÖNCE yazılıyor. Bu depo aynı dersi güncelleme bandında aldı: her şeye
/// "Çevrimdışı" diyen bir gösterge, göstergesizlikten kötüdür.
///
/// TAZEYKEN SESSİZ: her açılışta alarm veren bir satır iki günde görünmez olur.
class SenkronTazeligiSeridi extends StatelessWidget {
  const SenkronTazeligiSeridi({
    super.key,
    required this.tazelik,
    this.yalnizBayatta = false,
  });

  final SenkronTazeligi tazelik;

  /// true ise TAZE durumda hiçbir şey çizilmez (sessiz satır bile).
  ///
  /// GÜN kapanışında böyle kullanılır (lead kararı 2026-08-06): risk kurye kapanışıyla
  /// SİMETRİKTİR — kurye kendi telefonundan da ara tahsilat teslim edebildiği için "günü kapatan
  /// cihaz zaten tahsilatı alan cihazdır" varsayımı tutmuyor, o yüzden uyarı orada da gerekli.
  /// Ama patronun HER GECE gördüğü sheet'e "3 dk önce" satırı eklemek gürültüdür: geri
  /// döndürülemez bir kilidin önünde gerçek bir riski söylemek gürültü değildir, her gece
  /// "her şey yolunda" demek gürültüdür.
  final bool yalnizBayatta;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;

    if (yalnizBayatta && !tazelik.bayat) return const SizedBox.shrink();

    if (!tazelik.bayat) {
      // Sessiz bilgi satırı: kutu yok, ikon yok, soluk metin.
      return Padding(
        padding: const EdgeInsets.only(top: SipSpace.sm, bottom: 2),
        child: Text(
          'Bilgiler ${senkronSuresi(tazelik.gecenSure!)} güncellendi',
          style: SipText.yardimci.copyWith(color: t.muted),
        ),
      );
    }

    // "Hiç temas yok" ile "eski temas" AYRI cümlelerdir: birincisinde yazacak bir süre YOKTUR ve
    // "0 dk önce" demek, bilmediğimizi bildiğimiz sanmaktır.
    final metin = tazelik.hicTemasYok
        ? 'Bu telefon sunucuya henüz hiç bağlanmadı. Başka bir telefondan alınmış ara '
            'tahsilat varsa buradaki tutar onu görmüyor olabilir.'
        : 'Bilgiler ${senkronSuresi(tazelik.gecenSure!)} güncellendi. Başka bir telefondan '
            'alınmış ara tahsilat henüz inmemiş olabilir.';

    return Padding(
      padding: const EdgeInsets.only(bottom: SipSpace.md),
      child: SipNotKutusu(
        tur: SipNotTuru.uyari,
        ikon: SipIcons.alert,
        metin: metin,
      ),
    );
  }
}

/// "az önce" · "12 dk önce" · "3 sa önce" · "2 gün önce".
///
/// Kaba biçim BİLİNÇLİ: saniye hassasiyeti burada bilgi taşımaz ve gereğinden kesin bir rakam,
/// aslında yaklaşık olan bir ölçüme sahte bir kesinlik verir.
String senkronSuresi(Duration d) {
  if (d.inMinutes < 1) return 'az önce';
  if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
  if (d.inHours < 24) return '${d.inHours} sa önce';
  return '${d.inDays} gün önce';
}
