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
// ══ TEMİZLEME (kullanıcı isteği 2026-09-29) ═════════════════════════════════════════════════
// Eskiden silme bilinçli olarak yoktu ("kutu 200 satırda kendini buduyor"). Sahada bunun bedeli
// görüldü: okunmuş uyarılar haftalarca listede kalıyor ve yeni geleni aralarında aratıyordu.
// İki yol var: üstteki "Temizle" bütün listeyi (onayla) kaldırır, satırı SOLA KAYDIRMAK yalnız
// o satırı kaldırır. Kaldırılan satır silinmez, damgalanır — gerekçe `Bildirimler.temizlendiAt`.

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../repo/bildirim_kutusu.dart';
import '../theme/components/atoms.dart';
import '../theme/components/overlays.dart';
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
                    // Liste boşken temizlenecek bir şey yoktur (aynı ilke: etkisiz eylem sunma).
                    if (liste != null && liste.isNotEmpty)
                      SipMetinButon(
                        etiket: 'Temizle',
                        ikon: SipIcons.trash,
                        onTap: () => _hepsiniTemizle(context, kutu),
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
                                aciklama: 'Hatırlatmalar ve uyarılar burada birikir',
                              ),
                            ])
                          : SipGovde(
                              children: [
                                for (final b in liste)
                                  _Satir(
                                    key: ValueKey(b.id),
                                    kayit: b,
                                    onKaldir: () => kutu.temizle(
                                      b.id,
                                      anIso: DateTime.now().toUtc().toIso8601String(),
                                    ),
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

  /// Bütün listeyi ONAYLA temizler. Onay şart: tek dokunuşla geri alınamaz bir toplu eylemdir
  /// ve düğme "Okundu"nun hemen yanında duruyor — yanlış düğmeye basmak kolay.
  static Future<void> _hepsiniTemizle(BuildContext context, BildirimKutusu kutu) async {
    final onay = await sipOnay(
      context,
      baslik: 'Bildirimler temizlensin mi?',
      mesaj: 'Listedeki bütün bildirimler kaldırılır. Yeni bildirimler gelmeye devam eder.',
      onayEtiketi: 'Temizle',
      tehlike: true,
    );
    if (!onay) return;
    await kutu.hepsiniTemizle(anIso: DateTime.now().toUtc().toIso8601String());
  }
}

class _Satir extends StatelessWidget {
  const _Satir({
    super.key,
    required this.kayit,
    required this.onTap,
    required this.onKaldir,
  });

  final BildirimlerData kayit;
  final VoidCallback onTap;

  /// Satır sola kaydırılınca çağrılır.
  final VoidCallback onKaldir;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final okunmadi = kayit.okunduAt == null;

    // SOLA KAYDIR = KALDIR. Tek yön: sağa kaydırma Android'de geri hareketiyle karışır.
    // Onay SORULMAZ: tek satırdır ve kaydırmanın kendisi bilinçli bir harekettir.
    return Dismissible(
      key: ValueKey('kaldir-${kayit.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onKaldir(),
      background: Container(
        margin: const EdgeInsets.only(bottom: SipSpace.sm),
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: t.danger, borderRadius: SipRadius.br2),
        child: Semantics(
          label: 'Bildirimi kaldır',
          child: SipIcon(SipIcons.trash, boyut: 18, kalinlik: 2.2, renk: t.durumInk),
        ),
      ),
      child: _govde(t, okunmadi),
    );
  }

  Widget _govde(SipTokens t, bool okunmadi) {
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
