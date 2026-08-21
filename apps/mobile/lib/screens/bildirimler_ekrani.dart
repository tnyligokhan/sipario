// BİLDİRİMLER EKRANI — uygulama içi bildirim kutusu (kullanıcı isteği 2026-08-21).
//
// Ana ekrandaki zil düğmesinden açılır. Verisi `BildirimKutusu`dur (cihaz-yerel; gerekçe
// `repo/bildirim_kutusu.dart`).
//
// ══ DOKUNUNCA NE OLUR ═══════════════════════════════════════════════════════════════════════
// Satır OKUNDU işaretlenir ve — yolu varsa — ekran o yolu ÇAĞIRANA döndürerek kapanır.
// Gezinmeyi bu ekran YAPMAZ: hedefler kabuğun bildiği şeylerdir (`_bildirimYoluAc`) ve sistem
// bildirimine dokunmakla buradaki satıra dokunmak AYNI yere gitmeli. İki ayrı yönlendirme
// yazsaydık, bir gün biri ötekinden farklı bir ekran açardı.
//
// ══ SİLME YOK ═══════════════════════════════════════════════════════════════════════════════
// Tek tek silme bilinçli olarak yok: kutu zaten 200 satırda kendini buduyor ve okunmuş satır
// zaten sönük. Silme düğmesi, bayiye "bunu kaybetmeyeyim" kararı verdiren gereksiz bir yük.

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../repo/bildirim_kutusu.dart';
import '../theme/components/atoms.dart';
import '../theme/components/states.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class BildirimlerEkrani extends StatelessWidget {
  const BildirimlerEkrani({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final kutu = BildirimKutusu(db);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<BildirimlerData>>(
          stream: kutu.watchHepsi(),
          builder: (context, snap) {
            final liste = snap.data;
            final okunmamis = liste?.where((b) => b.okunduAt == null).length ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SipUst(
                  baslik: 'Bildirimler',
                  alt: okunmamis == 0 ? 'Tümü okundu' : '$okunmamis okunmamış',
                  onGeri: () => Navigator.of(context).maybePop(),
                  sag: [
                    // DÜĞME YALNIZ OKUNMAMIŞ VARKEN: hiçbir şey değiştirmeyen bir eylem
                    // sunmak, dokunduktan sonra "oldu mu" sorusu bırakır.
                    if (okunmamis > 0)
                      SipMetinButon(
                        etiket: 'Okundu',
                        ikon: SipIcons.check,
                        onTap: () => kutu.hepsiniOkunduIsaretle(
                          okunduAtIso: DateTime.now().toUtc().toIso8601String(),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: liste == null
                      ? const SipGovde(children: [SipIskelet(adet: 4)])
                      : liste.isEmpty
                          ? const SipGovde(children: [
                              SipBosDurum(
                                ikon: SipIcons.info,
                                baslik: 'Bildirim yok',
                                aciklama: 'Hatırlatmalar ve uyarılar burada birikir.',
                              ),
                            ])
                          : SipGovde(
                              children: [
                                for (final b in liste)
                                  _Satir(
                                    kayit: b,
                                    onTap: () async {
                                      await kutu.okunduIsaretle(
                                        b.id,
                                        okunduAtIso:
                                            DateTime.now().toUtc().toIso8601String(),
                                      );
                                      if (!context.mounted) return;
                                      final yol = b.yol;
                                      if (yol != null && yol.isNotEmpty) {
                                        Navigator.of(context).pop(yol);
                                      }
                                    },
                                  ),
                              ],
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir({required this.kayit, required this.onTap});

  final BildirimlerData kayit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final okunmadi = kayit.okunduAt == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: SipSpace.sm),
      child: SipDokun(
        onTap: onTap,
        // OKUNMAMIŞ SATIR ZEMİNLE AYRIŞIR, yalnız kalın yazıyla değil: kalınlık tek başına
        // hızlı bir bakışta seçilmiyor ve bu ekranın tek işi "hangileri yeni" sorusudur.
        zemin: okunmadi ? t.accentSoft : t.surface,
        radius: SipRadius.br2,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: okunmadi ? t.accent : t.line2,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kayit.baslik,
                          style: SipText.metin(13.5, w: okunmadi ? 800 : 700)
                              .copyWith(color: okunmadi ? t.ink : t.ink2),
                        ),
                      ),
                      const SizedBox(width: SipSpace.md),
                      Text(
                        bildirimZamanEtiketi(kayit.occurredAt),
                        style: SipText.metin(11.5).copyWith(color: t.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    // DETAY VARSA O YAZILIR: gövde sistem rafında tek satıra sığsın diye
                    // kısaltılmıştır; burada yer var ve bayi tam cümleyi hak ediyor.
                    kayit.detay ?? kayit.govde,
                    style: SipText.metin(12.5).copyWith(color: t.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 dk önce" · "2 sa önce" · "Dün" · "12.08" — SAF, doğrudan testlenir.
///
/// [simdi] verilmezse cihaz saati. Bu bir GÖSTERİM etiketidir, para hesabı değil: cihaz saati
/// yanlışsa en fazla "5 dk önce" yerine "1 sa önce" yazar, hiçbir kayda dokunmaz.
String bildirimZamanEtiketi(String occurredAtIso, {DateTime? simdi}) {
  final an = DateTime.tryParse(occurredAtIso)?.toLocal();
  if (an == null) return '';
  final fark = (simdi ?? DateTime.now()).difference(an);

  if (fark.inMinutes < 1) return 'şimdi';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
  if (fark.inHours < 24) return '${fark.inHours} sa önce';
  if (fark.inDays == 1) return 'Dün';
  if (fark.inDays < 7) return '${fark.inDays} gün önce';
  return '${an.day.toString().padLeft(2, '0')}.${an.month.toString().padLeft(2, '0')}';
}
