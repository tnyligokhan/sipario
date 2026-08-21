// YENİLİKLER — sürüm notları ekranı. Veri ve kurallar `guncelleme/surum_notlari.dart`ta.
//
// Ayarlar → Hakkında → Yenilikler'den açılır. Ağa ÇIKMAZ: metinler derlemenin içindedir
// (gerekçe kaynak dosyanın başlığında), yani çevrimdışı bayide de eksiksiz açılır.
//
// MAĞAZA KURALI (BRIEF): bu ekranda fiyat/abonelik/satın alma/üyelik dili YOKTUR. Notların
// kendisi de aynı kurala tabidir ve testle taranır.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../guncelleme/surum_notlari.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Cihazda KOŞAN sürümün adı ("0.14.0"); okunamazsa null.
///
/// Yapı numarası BİLEREK alınmaz — bu ekranın sorusu "hangi APK?" değil "hangi sürümdeyim?".
/// Platform kanalı yoksa (test ortamı) ÇÖKMEZ, null döner ve ekran yalnız "şu anki" işaretini
/// kaybeder: notlar bir sürüm etiketi yüzünden okunamaz hâle gelemez.
Future<String?> calisanSurumAdi() async {
  try {
    final bilgi = await PackageInfo.fromPlatform();
    final ad = bilgi.version.trim();
    return ad.isEmpty ? null : ad;
  } catch (_) {
    return null;
  }
}

class SurumNotlariEkrani extends StatelessWidget {
  const SurumNotlariEkrani({super.key, this.surumOkuyucu});

  /// Test/önizleme yolu — verilmezse cihazın gerçek sürümü ([calisanSurumAdi]).
  final Future<String?> Function()? surumOkuyucu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sip.bg,
      body: SafeArea(
        child: Column(
          children: [
            SipUst(
              baslik: 'Yenilikler',
              alt: 'Sipario\'da neler değişti',
              onGeri: () => Navigator.of(context).pop(),
            ),
            Expanded(
              // Sürüm okuması ASENKRON ama liste ONA BAĞLI DEĞİL: notlar hemen çizilir,
              // gelen sürüm yalnız bir rozet ekler. Ters kursaydık (FutureBuilder tüm
              // listeyi sarsaydı) platform kanalının yavaş olduğu ilk karede ekran boş
              // görünür ve bayi "yenilik yok" sanırdı.
              child: FutureBuilder<String?>(
                future: (surumOkuyucu ?? calisanSurumAdi)(),
                builder: (context, snap) => _Liste(calisanSurum: snap.data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.calisanSurum});

  final String? calisanSurum;

  @override
  Widget build(BuildContext context) {
    final simdiki = surumNotuBul(calisanSurum);
    return SipGovde(
      children: [
        for (final not in kSurumNotlari)
          Padding(
            padding: const EdgeInsets.only(bottom: SipSpace.xl),
            child: _NotKarti(not: not, simdiki: identical(not, simdiki)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: SipSpace.md, bottom: SipSpace.x2),
          child: Text(
            'Daha eski sürümlerin notları listede tutulmuyor',
            textAlign: TextAlign.center,
            style: SipText.yardimci.copyWith(color: context.sip.muted),
          ),
        ),
      ],
    );
  }
}

class _NotKarti extends StatelessWidget {
  const _NotKarti({required this.not, required this.simdiki});

  final SurumNotu not;

  /// Cihazda KOŞAN sürüm bu mu? Rozet yalnız burada çizilir.
  final bool simdiki;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipKart(
      padding: const EdgeInsets.fromLTRB(SipSpace.x3, SipSpace.x2, SipSpace.x3, SipSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "Sürüm" sözcüğü BİLEREK yazılıyor: çıplak bir "0.14.0" bayiye bir
                    // numara olduğunu söyler ama neyin numarası olduğunu söylemez.
                    Text(
                      'Sürüm ${not.surum}',
                      style: SipText.bolumBaslik.copyWith(color: t.ink),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        not.tarih,
                        style: SipText.yardimci.copyWith(color: t.muted),
                      ),
                    ),
                  ],
                ),
              ),
              if (simdiki) ...[
                const SizedBox(width: SipSpace.lg),
                // METİN "kullandığınız", "güncel" DEĞİL: ekran bir İDDİADA bulunmaz —
                // daha yeni bir sürümün yayınlanmış olup olmadığını bu ekran bilmez
                // (bunu güncelleme bandı bilir). Söylediği tek şey ölçülebilir bir olgu:
                // bu telefonda şu an bu sürüm koşuyor.
                SipPil(
                  etiket: 'Kullandığınız sürüm',
                  renk: t.accent,
                  zemin: t.accentSoft,
                ),
              ],
            ],
          ),
          const SizedBox(height: SipSpace.xl),
          for (final madde in not.maddeler)
            Padding(
              padding: const EdgeInsets.only(bottom: SipSpace.lg),
              child: _Madde(madde),
            ),
        ],
      ),
    );
  }
}

/// Tek bir yenilik satırı — accent noktalı madde.
class _Madde extends StatelessWidget {
  const _Madde(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nokta metnin İLK SATIRIYLA hizalanır (üstle değil): madde sarmalandığında
        // ortalanmış bir nokta listeyi eğri gösterir.
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: SipSpace.lg),
        Expanded(
          child: Text(
            metin,
            style: SipText.metin(13, w: 500, h: 1.45).copyWith(color: t.ink2),
          ),
        ),
      ],
    );
  }
}
