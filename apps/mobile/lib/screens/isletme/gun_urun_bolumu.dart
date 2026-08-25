// "SATILAN ÜRÜNLER" bölümü — gün genelinde teslim edilmiş siparişlerin ürün dökümü.
//
// NEDEN AYRI DOSYA: `gun_ozeti_govdesi.dart` bu bölümle 503 satıra çıkmıştı (depo sınırı 500).
// Ayrım keyfi değil KONUYA göre: gövde bölümleri SIRALAR, bu dosya tek bir bölümü ÇİZER ve
// kendi verisini (`satilanUrunler`) kendi açıp kapatarak okur.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_arsivi.dart';
import 'isletme_atomlari.dart';

/// "Satılan Ürünler" — gün genelinde teslim edilmiş siparişlerin ürün dökümü, aç/kapa.
///
/// ESKİ GEÇMİŞ EKRANINDAN DEVRALINDI (2026-08-25) ve iki şey değişti: (1) artık BUGÜN için de
/// çiziliyor, (2) varsayılan KAPALI. Geçmiş ekranında bölüm koşulsuz açıktı ve 30 kalemlik bir
/// günde kapanış kayıtlarını ekranın çok altına itiyordu; özet bir ÖZETTİR.
class GunUrunBolumu extends StatefulWidget {
  const GunUrunBolumu({super.key, required this.db, required this.gun});

  final AppDatabase db;
  final DateTime gun;

  @override
  State<GunUrunBolumu> createState() => _GunUrunBolumuState();
}

class _GunUrunBolumuState extends State<GunUrunBolumu> {
  bool _acik = false;
  Future<List<UrunSatisi>>? _veri;

  void _degistir(bool acik) {
    setState(() {
      _acik = acik;
      _veri ??= satilanUrunler(widget.db, widget.gun);
    });
  }

  @override
  void didUpdateWidget(GunUrunBolumu eski) {
    super.didUpdateWidget(eski);
    if (eski.gun != widget.gun) _veri = _acik ? satilanUrunler(widget.db, widget.gun) : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipBolumBaslik('Satılan Ürünler', ustBosluk: 18),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SipSpace.md, vertical: SipSpace.md),
          decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
          child: SipDokun(
            onTap: () => _degistir(!_acik),
            radius: SipRadius.br1,
            child: Row(
              children: [
                SipIkonKutu(
                  ikon: SipIcons.box,
                  cap: 28,
                  ikonBoyut: 14,
                  kalinlik: 2.0,
                  radius: SipRadius.hap,
                  zemin: t.accentSoft,
                  renk: t.accent,
                ),
                const SizedBox(width: SipSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ürün dökümü',
                        style: SipText.metin(13, w: 700).copyWith(color: t.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Teslim edilen siparişlerden, çok satandan aza',
                        style: SipText.metin(11, w: 500).copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                SipKnob(acik: _acik),
              ],
            ),
          ),
        ),
        if (_acik)
          FutureBuilder<List<UrunSatisi>>(
            future: _veri,
            builder: (ctx, snap) {
              final liste = snap.data;
              if (liste == null) {
                return const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: SipIskelet(adet: 1),
                );
              }
              if (liste.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    decoration: BoxDecoration(
                        color: t.surface, borderRadius: SipRadius.br2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: SipSpace.x2, vertical: 14),
                    child: Text(
                      'Bu gün teslim edilmiş sipariş yok',
                      style: SipText.yardimci.copyWith(color: t.muted),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: DegerKarti(
                  satirlar: [
                    for (final u in liste)
                      DegerSatiri(
                          etiket: '${u.ad} ×${u.adet}', deger: sipTutar(u.tutar)),
                    DegerSatiri(
                      etiket: 'Toplam, '
                          '${liste.fold<int>(0, (s, u) => s + u.adet)} adet',
                      deger: sipTutar(liste.fold<int>(0, (s, u) => s + u.tutar)),
                      toplam: true,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
