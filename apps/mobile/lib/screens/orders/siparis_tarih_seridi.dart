// TESLİM SEKMESİNİN GÜN GEZİNMESİ — "‹ 4 Ağustos Salı ›".
//
// NEDEN VAR (kullanıcı isteği 2026-08-04): "teslim edilen siparişlerde ileri geri yapılabilen
// tarih olmalı, sonuçta bütün siparişleri görmek veri olarak yorucu olur." Teslim edilmiş sipariş
// hiç eksilmeyen bir listedir: bayi bir yıl sonra o sekmeyi açtığında binlerce satırın en üstünde
// bugünü arar. Gün gezinmesi listeyi bayinin gerçekten sorduğu soruya indirger — "bugün ne
// teslim ettik", "dün ne teslim etmişiz".
//
// NEDEN YALNIZ "TESLİM" SEKMESİNDE: "Açık" zaten kısa ve zamansızdır (iş bitene kadar durur),
// "Borçlu" bir TARİH değil bir DURUM sorusudur (üç ay önceki borç bugün de borçtur) ve gizlenirse
// borç görünmez olur — kırmızı çizgiye yaklaşırdı. "Tümü" bilinçli olarak süzgeçsiz kalır: bir
// kaydı tarihini bilmeden aramanın tek yolu odur.
//
// GELECEĞE GİDİLMEZ: ileri ok bugüne gelince pasifleşir. Yarının teslimatı yoktur; boş bir ekranda
// "acaba veri mi kayboldu" diye düşündürmek, engellemekten pahalıdır.
//
// GÜN SINIRI BU DOSYADA TANIMLI DEĞİL: TR günü (+03:00) `gun_sonu_ozet.dart`ın işidir ve liste
// süzgeci de (`watchOrders(gun:)`) onu kullanır — şerit yalnız hangi günün seçildiğini söyler.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

const List<String> _aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

const List<String> _gunler = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

/// "4 Ağustos Salı" · bugün ve dün için gün adı yerine ANLAM yazılır ("Bugün" / "Dün"):
/// bayi %90 bu iki günü sorar ve tarihi zihninde çevirmek zorunda kalmamalı.
String tarihEtiketi(DateTime gun, {DateTime? bugun}) {
  final b = bugun ?? DateTime.now();
  final bugunTarih = DateTime(b.year, b.month, b.day);
  final fark = DateTime(gun.year, gun.month, gun.day).difference(bugunTarih).inDays;
  final tarih = '${gun.day} ${_aylar[gun.month - 1]}';
  if (fark == 0) return 'Bugün · $tarih';
  if (fark == -1) return 'Dün · $tarih';
  return '$tarih ${_gunler[gun.weekday - 1]}';
}

/// Sekmelerin altındaki gün gezinme şeridi: ‹ · etiket · ›
class SiparisTarihSeridi extends StatelessWidget {
  const SiparisTarihSeridi({
    super.key,
    required this.gun,
    required this.onDegis,
    this.bugun,
    this.adet,
  });

  final DateTime gun;

  /// Yeni seçilen günü bildirir.
  final ValueChanged<DateTime> onDegis;

  /// Test dikişi — "bugün"ün ne olduğu dışarıdan verilebilir (sahte zamanla sınanır).
  final DateTime? bugun;

  /// O güne düşen sipariş sayısı; null iken hiç yazılmaz (veri gelmeden RAKAM YAZILMAZ).
  final int? adet;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final b = bugun ?? DateTime.now();
    final bugunTarih = DateTime(b.year, b.month, b.day);
    final ileriAcik = DateTime(gun.year, gun.month, gun.day).isBefore(bugunTarih);

    return Row(
      children: [
        _Ok(
          ikon: SipIcons.left,
          etiket: 'Önceki gün',
          onTap: () => onDegis(gun.subtract(const Duration(days: 1))),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Bugüne dön',
            child: SipDokun(
              // Etikete dokunmak BUGÜNE döner: on gün geri gidip tek tek dönmek angarya.
              onTap: () => onDegis(bugunTarih),
              zemin: t.surface,
              basiliZemin: t.surface2,
              radius: SipRadius.brHap,
              kenarlik: Border.all(color: t.line2),
              child: SizedBox(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SipIcon(SipIcons.takvim, boyut: 15, kalinlik: 2.2, renk: t.ink2),
                    const SizedBox(width: SipSpace.sm),
                    Flexible(
                      child: Text(
                        adet == null
                            ? tarihEtiketi(gun, bugun: b)
                            : '${tarihEtiketi(gun, bugun: b)} · $adet',
                        style: SipText.ustMetin.copyWith(color: t.ink2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _Ok(
          ikon: SipIcons.right,
          etiket: 'Sonraki gün',
          soluk: !ileriAcik,
          // Pasifken de dokunulabilir kalır ama HİÇBİR ŞEY yapmaz: bugünün ötesi yok ve
          // bunu söyleyecek bir cümle de yok — soluk ok zaten sınırı gösteriyor.
          onTap: ileriAcik ? () => onDegis(gun.add(const Duration(days: 1))) : null,
        ),
      ],
    );
  }
}

class _Ok extends StatelessWidget {
  const _Ok({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.soluk = false,
  });

  final String ikon;
  final String etiket;
  final VoidCallback? onTap;
  final bool soluk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Opacity(
      opacity: soluk ? 0.4 : 1,
      child: Semantics(
        button: true,
        enabled: !soluk,
        label: etiket,
        child: SipDokun(
          onTap: onTap ?? () {},
          zemin: t.surface,
          basiliZemin: t.surface2,
          radius: SipRadius.brHap,
          kenarlik: Border.all(color: t.line2),
          padding: const EdgeInsets.symmetric(horizontal: SipSpace.lg),
          child: SizedBox(
            height: 40,
            width: 20,
            child: Center(child: SipIcon(ikon, boyut: 16, kalinlik: 2.4, renk: t.ink2)),
          ),
        ),
      ),
    );
  }
}
