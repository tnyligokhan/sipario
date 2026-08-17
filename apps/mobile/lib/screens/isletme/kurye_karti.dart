// KURYE KARTI — listedeki tek satır: avatar · durum noktası · ad · telefon · kullanıcı adı ·
// "özel yetki" rozeti · "Yetkiler" çipi.
//
// NEDEN AYRI DOSYA: `kuryeler_ekrani.dart` 754 satıra çıkmıştı (500 satır kuralı). Kart, ekranın
// geri kalanından bağımsız okunabilir: veri OKUMAZ, yazmaz, hiçbir akışa abone olmaz — kendisine
// verilen `User` satırını çizer ve iki dokunuşu yukarı bildirir. Ekran ise listeyi kurar,
// yetkileri çözer ve sunucuya yazar.
//
// ⚠️ "ÖZEL YETKİ" ROZETİ BURADA ÇİZİLİR ama kararı ekran verir: patron kimin bayi varsayılanından
// ayrıldığını LİSTEYE BAKARAK görebilmeli, tek tek ekran açarak değil.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'isletme_atomlari.dart';
import 'kuryeler_ekrani.dart' show kuryeAktifMi;
import 'kurye_kisisel_yetkiler.dart';

/// Modern Kurye Kartı — Temiz avatar, durum noktası, telefon, kullanıcı adı ve rozet
class KuryeKarti extends StatelessWidget {
  const KuryeKarti({
    super.key,
    required this.kurye,
    required this.onTap,
    required this.onYetkiler,
  });

  final User kurye;
  final VoidCallback onTap;

  /// Satır içi "Yetkiler" çipi — kartın kendi dokunuşundan (düzenleme sheet'i) AYRI eylem.
  final VoidCallback onYetkiler;

  String _basHarfler(String ad) {
    final temiz = ad.trim();
    if (temiz.isEmpty) return 'K';
    final parcalar = temiz.split(RegExp(r'\s+'));
    if (parcalar.length >= 2) {
      return (parcalar[0][0] + parcalar[1][0]).toUpperCase();
    }
    return temiz.substring(0, temiz.length.clamp(1, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final aktif = kuryeAktifMi(kurye);
    final tel = (kurye.phone ?? '').trim();
    final nick = kurye.username.trim();
    // Rozet EZMEDEN okunur, etkin yetkiden değil: soru "bu kurye bayiden ayrık mı?" — 13 yetkisi
    // varsayılanla aynı değere ELLE ayarlanmış bir kurye de ayrıktır (bayi varsayılanı değişince
    // onunla birlikte kaymaz) ve listede öyle görünmelidir.
    final ozelYetki = !kuryeEzmeleriOku(kurye).hepsiDevralindi;

    return Opacity(
      opacity: aktif ? 1.0 : 0.65,
      child: SipDokun(
        onTap: onTap,
        zemin: t.surface,
        basiliZemin: t.surface2,
        radius: SipRadius.br3,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Sol Avatar & Durum Göstergesi
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: aktif ? t.accentSoft : t.surface2,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _basHarfler(kurye.name),
                    style: SipText.metin(14, w: 700).copyWith(
                      color: aktif ? t.accent : t.muted,
                    ),
                  ),
                ),
                // Aktif/Pasif Noktası
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: aktif ? t.ok : t.muted,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: SipSpace.md),

            // Orta Bilgi Alanı
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // İsim & Durum Rozeti
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          kurye.name,
                          style: SipText.metin(14.5, w: 700).copyWith(
                            color: t.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!aktif) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.surface2,
                            borderRadius: SipRadius.brHap,
                          ),
                          child: Text(
                            'PASİF',
                            style: SipText.metin(10, w: 700).copyWith(
                              color: t.muted,
                            ),
                          ),
                        ),
                      ],
                      if (ozelYetki) ...[
                        const SizedBox(width: 6),
                        YetkiRozeti(
                          metin: kuryeOzelYetkiRozeti,
                          renk: t.accent,
                          zemin: t.accentSoft,
                          punto: 10,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Telefon & Kullanıcı Adı
                  Row(
                    children: [
                      if (tel.isNotEmpty) ...[
                        SipIcon(SipIcons.phone, boyut: 11, kalinlik: 2, renk: t.muted),
                        const SizedBox(width: 4),
                        Text(
                          sipTelefon(tel),
                          style: SipText.metin(12, w: 500).copyWith(color: t.ink2),
                        ),
                      ] else ...[
                        Text(
                          'Telefon yok',
                          style: SipText.metin(12, w: 500).copyWith(color: t.muted),
                        ),
                      ],
                      if (nick.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: SipText.metin(12, w: 700).copyWith(color: t.line2),
                        ),
                        Flexible(
                          child: Text(
                            '@$nick',
                            style: SipText.metin(11.5, w: 600).copyWith(color: t.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: SipSpace.sm),

            // Satır içi yetki girişi — kartın kendi dokunuşunu YUTAR (iç GestureDetector
            // önce vurulur), böylece "Yetkiler" düzenleme sheet'ini açmaz.
            SipDokun(
              onTap: onYetkiler,
              zemin: t.surface2,
              basiliZemin: t.line,
              radius: SipRadius.brHap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SipIcon(SipIcons.lock, boyut: 12, kalinlik: 2, renk: t.ink2),
                  const SizedBox(width: 5),
                  Text(
                    'Yetkiler',
                    style: SipText.metin(11.5, w: 700).copyWith(color: t.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SipSpace.sm),

            // Sağ Düzenleme Oku
            SipIcon(
              SipIcons.right,
              boyut: 16,
              kalinlik: 2.0,
              renk: t.muted,
            ),
          ],
        ),
      ),
    );
  }
}
