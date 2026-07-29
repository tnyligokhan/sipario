// GEÇMİŞ GÜNLER LİSTESİ — gün sonu ekranının alt bölümü (kullanıcı isteği 2026-07-29).
//
// NEDEN AYRI DOSYA: `day_end_screen.dart` bu bölümle 530 satıra çıktı (depo sınırı 500). Ekran
// DURUM ve kapatma akışını yönetir; geçmiş listesi kendi verisini çeken bağımsız bir parçadır
// ve ekranın kapanış/rol mantığından hiçbir şey bilmez.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_arsivi.dart';
import 'gun_detay_ekrani.dart';

/// GEÇMİŞ günler listesi — hareket olan HER gün (kullanıcı kararı 2026-07-29), yeni üstte.
///
/// Kapatılmamış gün listede KALIR ve işaretlenir: bayi bir günü kapatmayı unuttuğunda o günün
/// cirosunun uygulamadan okunamaz hâle gelmesi, en çok ihtiyaç duyulan anda veriyi gizlerdi
/// (eski "Arşiv" bölümü yalnız kapanış kayıtlarını listeliyordu ve o gün hiç görünmüyordu).
class GecmisListesi extends StatefulWidget {
  const GecmisListesi({super.key, required this.db});

  final AppDatabase db;

  @override
  State<GecmisListesi> createState() => GecmisListesiState();
}

class GecmisListesiState extends State<GecmisListesi> {
  late Future<List<GunSatiri>> _gunler = gecmisGunler(widget.db);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GunSatiri>>(
      future: _gunler,
      builder: (context, snap) {
        if (snap.hasError) {
          return SipHataEkran(
              onTekrar: () => setState(() => _gunler = gecmisGunler(widget.db)));
        }
        final liste = snap.data;
        if (liste == null) return const SipIskelet(adet: 2);
        if (liste.isEmpty) {
          return _GecmisBos();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < liste.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: _GunSatiriKarti(
                  satir: liste[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GunDetayEkrani(db: widget.db, gun: liste[i].gun),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GecmisBos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 14),
      child: Text('Henüz geçmiş gün yok — ilk gün kapandığında burada listelenecek.',
          style: SipText.yardimci.copyWith(color: t.muted)),
    );
  }
}

/// Bir gün satırı: "28.07 Pazartesi · 2.100 ₺ · 18 teslimat" + kapanış işareti.
class _GunSatiriKarti extends StatelessWidget {
  const _GunSatiriKarti({required this.satir, required this.onTap});

  final GunSatiri satir;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final s = satir;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      basiliZemin: t.surface2,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          SipIkonKutu(
            // Kapatılmamış gün UYARI rengiyle çizilir: kilit ikonu ona yanlış bir güven verirdi.
            ikon: s.kapatildi ? SipIcons.lock : SipIcons.info,
            cap: 30,
            ikonBoyut: 15,
            zemin: s.kapatildi ? t.surface2 : t.warnSoft,
            renk: s.kapatildi ? t.muted : t.warn,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(gunBasligi(s.gun),
                    style: SipText.metin(13.5, w: 700).copyWith(color: t.ink)),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '${s.teslimat} teslimat'
                    '${s.kapatildi ? '' : ' · kapatılmadı'}',
                    style: SipText.yardimci
                        .copyWith(color: s.kapatildi ? t.muted : t.warn),
                  ),
                ),
              ],
            ),
          ),
          Text(sipTutar(s.tahsilat),
              style: SipText.metin(14, w: 800).copyWith(color: t.ink)),
          const SizedBox(width: 6),
          SipIcon(SipIcons.right, boyut: 14, kalinlik: 2.2, renk: t.muted),
        ],
      ),
    );
  }
}
