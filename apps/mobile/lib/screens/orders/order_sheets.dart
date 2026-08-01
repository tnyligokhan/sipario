// Sipariş listesinin küçük seçim sheet'leri — CSS `.sr-list`, `.sr-row`, `.sr-oto`.
// Kaynak: s-siparisler.jsx `SiparislerEkran` içindeki "Kurye Seç" ve "Sıralama" sheet'leri.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'order_queries.dart';

/// CSS `.sr-row` — seçim listesi satırı; seçili olan accent-soft zeminli ve onay işaretli.
class SecimSatiri extends StatelessWidget {
  const SecimSatiri({
    super.key,
    required this.etiket,
    required this.secili,
    required this.onTap,
    this.ikon,
  });

  final String etiket;
  final bool secili;
  final VoidCallback onTap;
  final String? ikon;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(bottom: SipSpace.sm),
      child: SipDokun(
        onTap: onTap,
        zemin: secili ? t.accentSoft : t.bg,
        radius: SipRadius.br2,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 13),
        child: Row(
          children: [
            if (ikon != null) ...[
              SipIcon(ikon!, boyut: 16, kalinlik: 2, renk: secili ? t.accent : t.muted),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(
                etiket,
                style: SipText.metin(13.5, w: secili ? 700 : 600)
                    .copyWith(color: secili ? t.accent : t.ink2),
              ),
            ),
            if (secili) SipIcon(SipIcons.check, boyut: 17, kalinlik: 2.4, renk: t.accent),
          ],
        ),
      ),
    );
  }
}

/// "Kurye Seç" sheet'i. Seçilen kullanıcının id'sini döner; `null` = vazgeçildi.
/// AKTİF kurye yoksa hiç çağrılmaz (çağıran taraf çipi zaten çizmez — BRIEF tek kişilik gizleme).
///
/// [atamasizEtiketi] verilirse listenin BAŞINA "atama yok" satırı çizilir ve seçilince
/// [kAtanmamisKurye] döner. Yeni sipariş formunda seçim OPSİYONELDİR: kullanıcı seçtiği kuryeden
/// vazgeçebilmeli ve bunu ancak açık bir satırla yapabilir — sheet'i kapatmak "vazgeçtim"
/// demektir, "atamayı kaldır" değil. Atama sheet'lerinde (sipariş detayı/liste) verilmez:
/// oradaki atamayı kaldırma yolu ayrıdır (`unassign`).
Future<String?> kuryeSecSheet(
  BuildContext context, {
  required List<User> kuryeler,
  required String? seciliId,
  String? baslik,
  String? atamasizEtiketi,
}) =>
    sipSheet<String>(
      context,
      baslik: baslik ?? 'Kurye Seç',
      govde: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (atamasizEtiketi != null)
            SecimSatiri(
              etiket: atamasizEtiketi,
              ikon: SipIcons.user,
              secili: seciliId == null,
              onTap: () => Navigator.of(ctx).pop(kAtanmamisKurye),
            ),
          for (final k in kuryeler)
            SecimSatiri(
              etiket: k.name,
              ikon: SipIcons.truck,
              secili: k.id == seciliId,
              onTap: () => Navigator.of(ctx).pop(k.id),
            ),
        ],
      ),
    );

/// "Sıralama" sheet'i — CSS `.sr-*`. [secenekler] verilmezse tüm sıralama kipleri sunulur;
/// salt-okunur kipte çağıran taraf `elle`yi listeden çıkarır (elle sıralama `sort_set` OLAYI
/// yazar — yeni kayıt yasağına girer).
///
/// `.sr-oto` düğmesi HER ZAMAN çizilir (tasarım s-siparisler.jsx:144). Önceden [otoHak] null
/// iken hiç çizilmiyordu; sonuç, ilk senkron gelmeden Sıralama sheet'ini açan kullanıcının
/// böyle bir yeteneğin varlığını hiç görmemesiydi — "gizli özellik" en kötü kapıdır. Şimdi
/// düğme görünür ama kullanılamadığı durumda PASİF + altında nedenini söyleyen nötr bir satır
/// durur. Sahte sayı hâlâ YOK: hak bilinmiyorsa kontör yazılmaz, yalnız "Oto Sırala (rota)".
/// [otoKumeNedeni]: görünen kümede rotaya girecek yeterli AÇIK sipariş yoksa çağıranın yazdığı
/// gerekçe (saha hatası: "sıralanacak sipariş yok"). Kümeyi yalnız çağıran bilir — seçili sekme
/// ve kurye süzgeci ondadır — ama düğmeyi PASİF çizme kararı burada, kontör/salt-okunur ile aynı
/// yerde verilir. En DÜŞÜK öncelik: hak yoksa ya da kip salt-okunursa asıl engel odur.
Future<OrderSort?> siralamaSecSheet(
  BuildContext context, {
  required OrderSort secili,
  List<OrderSort>? secenekler,
  int? otoHak,
  bool yazilabilir = true,
  String? otoKumeNedeni,
  VoidCallback? onOtoSirala,
}) {
  // Neden pasif? Sıra tek yazma yüzeyinden (`sort_set` olayı) geçer → salt-okunur kipte yasak.
  // Hak bilinmiyorsa (ilk senkron gelmedi / oturum yok) tıklamak 409 ile dönerdi.
  //
  // SAHA HATASI: küme yetersizken düğme ETKİN çiziliyor, dokunulunca hata veriyordu. "Teslim" ve
  // "Borçlu" sekmeleri tanımı gereği KAPALI sipariş listeler; oralarda rota kümesi her zaman boş
  // kalır, yani düğme her dokunuşta başarısız oluyordu. Kullanıcı "sıralanacak sipariş yok"
  // okuyup bir sekme ötede duran açık siparişlerini düşünüyordu. Sebebi dokunmadan ÖNCE söyle.
  final String? kilitNedeni = !yazilabilir
      ? 'Salt-okunur kip: sıra kaydedilemez.'
      : otoHak == null
          ? 'Hak bilgisi bekleniyor — ilk senkrondan sonra kullanılabilir.'
          : otoHak <= 0
              ? 'Oto sıralama hakkı kalmadı.'
              : otoKumeNedeni;

  return sipSheet<OrderSort>(
    context,
    baslik: 'Sıralama',
    govde: (ctx) {
      final t = ctx.sip;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in secenekler ?? OrderSort.values)
            SecimSatiri(
              etiket: siralamaEtiketi(s),
              secili: s == secili,
              onTap: () => Navigator.of(ctx).pop(s),
            ),
          const SizedBox(height: SipSpace.xs),
          SipButon(
            etiket: otoHak == null
                ? 'Oto Sırala (rota)'
                : 'Oto Sırala (rota) · $otoHak hak',
            ikon: SipIcons.bolt,
            onTap: kilitNedeni != null
                ? null
                : () {
                    Navigator.of(ctx).pop();
                    onOtoSirala?.call();
                  },
          ),
          if (kilitNedeni != null)
            Padding(
              padding: const EdgeInsets.only(top: SipSpace.md),
              child: Text(
                kilitNedeni,
                textAlign: TextAlign.center,
                style: SipText.metin(12, w: 600).copyWith(color: t.muted),
              ),
            ),
        ],
      );
    },
  );
}
