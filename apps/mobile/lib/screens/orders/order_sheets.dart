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
/// yazar — yeni kayıt yasağına girer). `rota` için böyle bir kapı YOKTUR: rota seçmek hiçbir
/// şey yazmaz, yalnız kalıcı sırayı gösterir.
///
/// `.sr-oto` DÜĞMESİ BURADAN KALKTI (2026-08-01): oto sıralama HARİTA ekranının alt ortasındaki
/// birincil eyleme taşındı. Gerekçe: eylem bir ROTA üretir ve rotanın saçma olup olmadığı ancak
/// haritada anlaşılır — sonucu göremediğin bir yerden tetiklenen kontörlü bir eylem, kullanıcıyı
/// "acaba iyi mi sıraladı" sorusuyla baş başa bırakıyordu. Kilit gerekçeleri (`otoKilitNedeni`)
/// ve akışın kendisi `oto_siralama.dart`ta durur.
Future<OrderSort?> siralamaSecSheet(
  BuildContext context, {
  required OrderSort secili,
  List<OrderSort>? secenekler,
}) {
  return sipSheet<OrderSort>(
    context,
    baslik: 'Sıralama',
    govde: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in secenekler ?? OrderSort.values)
          SecimSatiri(
            etiket: siralamaEtiketi(s),
            secili: s == secili,
            onTap: () => Navigator.of(ctx).pop(s),
          ),
      ],
    ),
  );
}
