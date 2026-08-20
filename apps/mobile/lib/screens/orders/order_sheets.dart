// Sipariş listesinin küçük seçim sheet'leri — CSS `.sr-list`, `.sr-row`, `.sr-oto`.
// Kaynak: s-siparisler.jsx `SiparislerEkran` içindeki "Kurye Seç" ve "Sıralama" sheet'leri.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart' show rolEtiketi;
import 'order_queries.dart';

/// CSS `.sr-row` — seçim listesi satırı; seçili olan accent-soft zeminli ve onay işaretli.
class SecimSatiri extends StatelessWidget {
  const SecimSatiri({
    super.key,
    required this.etiket,
    required this.secili,
    required this.onTap,
    this.ikon,
    this.zemin,
  });

  final String etiket;
  final bool secili;
  final VoidCallback onTap;
  final String? ikon;

  /// Seçili DEĞİLKEN satırın zemini. Varsayılan `bg` — satır bir SHEET'in içinde yaşıyor ve
  /// sheet zemini `surface` olduğu için orada zıtlık verir.
  ///
  /// EKRAN GÖVDESİNDE bu varsayılan görünmezdir: gövde zaten `bg`dir, satır zeminine karışır ve
  /// dokunulabilir bir satır çıplak metne dönerdi (yeni sipariş özetindeki kurye satırı böyle
  /// çizilmişti — koyu temada özellikle). Oradaki çağıran `surface2` geçer ve satır komşusu
  /// kartlarla aynı dili konuşur.
  final Color? zemin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(bottom: SipSpace.sm),
      child: SipDokun(
        onTap: onTap,
        zemin: secili ? t.accentSoft : (zemin ?? t.bg),
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

/// "Görevli Seç" sheet'i. Seçilen kullanıcının id'sini döner; `null` = vazgeçildi.
/// Atanabilecek başka kimse yoksa hiç çağrılmaz (çağıran taraf çipi zaten çizmez — BRIEF tek
/// kişilik gizleme).
///
/// ══ LİSTE ARTIK KURYELERLE SINIRLI DEĞİL (2026-08-20) ═══════════════════════════════════
/// Kullanıcı isteği: "siparişi oluşturan kişi kendisini de görebilmeli". Liste
/// `watchAtamaHedefleri` ile gelir — patron · tezgâh · kurye, hepsi. [benimId] verilirse
/// oturumdaki kişinin satırı "(siz)" ile işaretlenir: karışık bir listede kendini bulmak
/// adı okumakla değil, bir işaretle olur.
///
/// SATIRDA ROL YAZAR: liste tek rolden oluşmadığı andan itibaren "Mehmet" ile "Ali" arasındaki
/// fark ad değil GÖREVdir; rolsüz bir liste patronu kuryeden ayırt ettirmez.
///
/// [atamasizEtiketi] verilirse listenin BAŞINA "atama yok" satırı çizilir ve seçilince
/// [kAtanmamisKurye] döner. Yeni sipariş formunda seçim OPSİYONELDİR: kullanıcı seçtiği kişiden
/// vazgeçebilmeli ve bunu ancak açık bir satırla yapabilir — sheet'i kapatmak "vazgeçtim"
/// demektir, "atamayı kaldır" değil. Atama sheet'lerinde (sipariş detayı/liste) verilmez:
/// oradaki atamayı kaldırma yolu ayrıdır (`unassign`).
Future<String?> kuryeSecSheet(
  BuildContext context, {
  required List<User> kuryeler,
  required String? seciliId,
  String? baslik,
  String? atamasizEtiketi,
  String? benimId,
}) =>
    sipSheet<String>(
      context,
      baslik: baslik ?? 'Görevli Seç',
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
              etiket: gorevliEtiketi(k, benimId: benimId),
              // Kamyon ikonu ARTIK YALNIZ KURYEDE: patronun satırına kamyon çizmek, listenin
              // hâlâ "kuryeler listesi" olduğunu söylerdi.
              ikon: k.role == 'kurye' ? SipIcons.truck : SipIcons.user,
              secili: k.id == seciliId,
              onTap: () => Navigator.of(ctx).pop(k.id),
            ),
        ],
      ),
    );

/// Görevli satırının etiketi — "Ali · Kurye", oturumdaki kişide "Mehmet · Patron (siz)".
/// Sheet ile gün özeti kapsam listesi AYNI etiketten okur; ayrışırlarsa bayi aynı kişiyi iki
/// ekranda iki farklı adla görürdü.
String gorevliEtiketi(User u, {String? benimId}) {
  final ben = benimId != null && u.id == benimId;
  return '${u.name} · ${rolEtiketi(u.role)}${ben ? ' (siz)' : ''}';
}

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
