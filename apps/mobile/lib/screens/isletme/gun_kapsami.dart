// GÜN ÖZETİ KAPSAMI — "kimin işlemleri" sorusunun seçenekleri + seçici kontrol.
//
// ══ NEDEN SEGMENT DEĞİL DROPDOWN (kullanıcı isteği 2026-08-20) ═══════════════════════════
// Kapsam eskiden yatay bir segment şeridiydi ve içinde yalnız KURYELER vardı: "Tümü · Emre ·
// Hakan". İki sorunu birden taşıyordu:
//
//  1. Patronun kendi yaptığı işleri ayrı görebileceği bir kapsam YOKTU. Malı çoğu zaman patron
//     götürüyor, parayı patron alıyor ve o rakamlar yalnız "Tümü"nün içinde eriyordu.
//  2. Şerit ekip büyüdükçe taşıyor: dört kişilik bir bayide segment ya sıkışıyor ya kaydırma
//     istiyordu. Seçenek sayısı belirsizse doğru kontrol açılır listedir.
//
// Yeni liste ÜÇ KATMANDIR ve sırası bilinçli — genelden özele:
//     Tümü · Kendi işlemlerim · Elemanlar · [kişi kişi herkes]
//
// "ELEMANLAR" = BEN HARİÇ HERKES. `Tümü − Kendi işlemlerim` demek değildir; bu bir çıkarma
// işlemi değil, ayrı bir süzgeçtir (bkz. `repo/islem_sahibi.dart`). Aradaki farkı yaratan şey
// SAHİBİ BİLİNMEYEN kayıtlardır: onlar "Tümü"ye girer ama ne bana ne elemanlarıma yazılır.
// İki rakamın toplamı "Tümü"yü tutmayabilir ve bu bir hata değil, dürüstlüktür.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_sheets.dart' show SecimSatiri;
import '../team.dart' show rolEtiketi;

/// Gün özetinde seçilebilen TEK bir kapsam.
///
/// [userId] ve [haric] AYNI ANDA DOLU OLAMAZ — ikisi de aynı sorunun (kimin işlemleri) iki ayrı
/// cevabıdır. Okuma katmanı da bunu böyle bekler.
class GunKapsamSecenegi {
  const GunKapsamSecenegi({
    required this.etiket,
    this.userId,
    this.haric,
    this.rol,
  });

  /// Açılır listede ve başlıkta görünen ad.
  final String etiket;

  /// Tek kişi kapsamı — o kişinin işlemleri. Gün hesabında ve "Elemanlar"da null.
  final String? userId;

  /// "Elemanlar" kapsamı: BU kişi hariç herkes. Diğer kapsamlarda null.
  final String? haric;

  /// Seçili kişinin rolü (`patron|operator|kurye`). Kapatma/ara tahsilat kapıları buna bakar:
  /// kasa devri yalnız KURYE kapsamında anlamlıdır.
  final String? rol;

  /// Dükkânın tamamı mı?
  bool get gunHesabi => userId == null && haric == null;

  /// Kasa devrinin (kapatma · ara tahsilat) anlamlı olduğu tek kapsam: bir KURYE'nin kendisi.
  ///
  /// Patronun ya da tezgâhın "kendi işlemlerim" kapsamı buna GİRMEZ: kasa devri, nakdi taşıyan
  /// kişiden patrona geçişin kaydıdır; patronun kendi kendine devir yapması diye bir olay yoktur.
  bool get devirKapsami => userId != null && rol == 'kurye';

  bool ayniMi(GunKapsamSecenegi o) => userId == o.userId && haric == o.haric;
}

/// Seçilebilecek kapsamlar — TEK yerde üretilir ki gün özeti ile geçmiş gün ekranı aynı listeyi
/// göstersin.
///
/// KURYE YALNIZ KENDİNİ GÖRÜR (K2, kullanıcı kararı 2026-08-11): "Tümü" bile yok. Kapı burada
/// durur — ekran, kuryeye gün hesabını verebilecek bir seçenek ÜRETEMEZ.
///
/// [benimId] null ise (oturum çözülemedi) "Kendi işlemlerim" ve "Elemanlar" listelenmez: kime
/// ait olduğu bilinmeyen bir "kendi" kapsamı, rastgele bir kişinin rakamlarını gösterirdi.
List<GunKapsamSecenegi> gunKapsamlari({
  required String? rol,
  required String? benimId,
  required List<User> ekip,
}) {
  if (rol == 'kurye') {
    final ben = ekip.where((u) => u.id == benimId).toList();
    return [
      for (final u in ben) GunKapsamSecenegi(etiket: u.name, userId: u.id, rol: u.role),
    ];
  }

  final baskalari = ekip.where((u) => u.id != benimId).toList();
  final benimSatir = ekip.where((u) => u.id == benimId).toList();

  return [
    const GunKapsamSecenegi(etiket: 'Tümü'),
    if (benimId != null && benimSatir.isNotEmpty)
      GunKapsamSecenegi(
        etiket: 'Kendi işlemlerim',
        userId: benimId,
        rol: benimSatir.first.role,
      ),
    if (benimId != null && baskalari.isNotEmpty)
      GunKapsamSecenegi(etiket: 'Elemanlar', haric: benimId),
    for (final u in baskalari)
      GunKapsamSecenegi(
        etiket: '${u.name} (${rolEtiketi(u.role)})',
        userId: u.id,
        rol: u.role,
      ),
  ];
}

/// Kapsam seçici — dokunulunca seçenekleri sheet olarak açan tek satırlık kontrol.
///
/// SHEET, AÇILIR MENÜ DEĞİL: uygulamanın her yerinde seçim sheet ile yapılıyor (kurye seçimi,
/// sıralama, ödeme tipi) ve tek bir ekranda Material `DropdownButton` kullanmak hem tema
/// dilinden hem dokunma hedefi ölçüsünden sapardı.
class GunKapsamSecici extends StatelessWidget {
  const GunKapsamSecici({
    super.key,
    required this.secenekler,
    required this.secili,
    required this.onSec,
  });

  final List<GunKapsamSecenegi> secenekler;
  final GunKapsamSecenegi secili;
  final ValueChanged<GunKapsamSecenegi> onSec;

  /// Kapalı hâlde YAZAN etiket, LİSTEDEN çözülür — [secili]'nin kendi etiketinden değil.
  ///
  /// NEDEN: ekran açılırken kapsam ekip listesi İNMEDEN kuruluyor ve o an elde yalnız kimlik
  /// var, ad yok ("Kendi hesabım" gibi bir yer tutucu yazılıyor). Liste geldiğinde aynı kapsamın
  /// gerçek adı ("Emre") belli olur; kapalı kontrol yer tutucuda kalsaydı seçicinin yazdığı ad
  /// ile listede işaretli satır farklı okunurdu.
  GunKapsamSecenegi get _gorunen =>
      secenekler.firstWhere((s) => s.ayniMi(secili), orElse: () => secili);

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: () async {
        final secim = await sipSheet<GunKapsamSecenegi>(
          context,
          baslik: 'Kapsam',
          govde: (ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in secenekler)
                SecimSatiri(
                  etiket: s.etiket,
                  ikon: s.gunHesabi
                      ? SipIcons.users
                      : (s.haric != null ? SipIcons.users : SipIcons.user),
                  secili: s.ayniMi(secili),
                  onTap: () => Navigator.of(ctx).pop(s),
                ),
            ],
          ),
        );
        if (secim != null) onSec(secim);
      },
      zemin: t.surface2,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 12),
      child: Row(
        children: [
          SipIcon(SipIcons.users, boyut: 16, kalinlik: 2, renk: t.muted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _gorunen.etiket,
              style: SipText.metin(13.5, w: 700).copyWith(color: t.ink2),
            ),
          ),
          SipIcon(SipIcons.down, boyut: 16, kalinlik: 2.2, renk: t.muted),
        ],
      ),
    );
  }
}
