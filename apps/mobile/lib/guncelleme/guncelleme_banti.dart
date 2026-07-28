// Güncelleme bandı — MÜDAHALESİZ tek satır.
//
// NEDEN DİYALOG DEĞİL: bayi sabah uygulamayı sipariş girmek için açıyor. Ortasına çıkan bir
// güncelleme diyaloğu, o an yapılacak işi bölmektir. Bant görünür ama yolu kapatmaz; bayi
// hazır olduğunda dokunur. Güncelleme yoksa hiçbir şey çizilmez (yükseklik sıfır).
//
// MAĞAZA DİLİ YOK: "Güncelleme var / İndir / Kur" serbest; fiyat, abonelik, satın alma
// sözcüğü ASLA (BRIEF mağaza kuralı). Bu bant zaten yalnız `saha` kanalında çiziliyor.

import 'package:flutter/material.dart';

import '../theme/components/dokunma.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'guncelleme_servisi.dart';
import 'guncelleme_sozlesmesi.dart';

class GuncellemeBanti extends StatelessWidget {
  const GuncellemeBanti({super.key, this.servis, this.kapali, this.ustBosluk = true});

  /// Test/araç yolu — verilmezse uygulamanın tekil servisi.
  final GuncellemeServisi? servis;

  /// Kill-switch. Verilmezse derleme sabitlerinden okunur ([guncellemeKapaliMi]).
  ///
  /// NEDEN ENJEKTE EDİLEBİLİR: sabit doğrudan okunsaydı bu widget varsayılan `flutter test`
  /// altında (kanal `magaza`, yapım 0) HİÇBİR ZAMAN çizmezdi ve "bant gerçekten görünüyor mu"
  /// sorusu test edilemezdi. Bandın aylarca ağaca hiç bağlanmamış olması tam da bu yüzden
  /// fark edilmedi — kill-switch'i dışarı almak o boşluğu kapatır.
  final bool? kapali;

  /// Durum çubuğu boşluğunu bu bant mı eklesin? Üstünde başka bir bant (çevrimdışı/grace)
  /// varsa `false` verilir: iki `SafeArea` üst üste gelince boşluk İKİ KEZ eklenir ve
  /// bantların arasında koca bir delik açılır.
  final bool ustBosluk;

  @override
  Widget build(BuildContext context) {
    // Mağaza derlemesinde ağaçta yer tutar ama HİÇBİR ŞEY çizmez (yükseklik sıfır) ve servis
    // zaten ağa çıkmamıştır. Kabuk bu widget'ı koşulsuz mount eder; koşul buradadır.
    if (kapali ?? guncellemeKapaliMi) return const SizedBox.shrink();
    final s = servis ?? guncellemeServisi;

    return ValueListenableBuilder<GuncellemeDurumu>(
      valueListenable: s.durum,
      builder: (context, durum, _) {
        if (durum == GuncellemeDurumu.yok) return const SizedBox.shrink();
        return ValueListenableBuilder<SurumBilgisi?>(
          valueListenable: s.bulunan,
          builder: (context, bilgi, _) {
            if (bilgi == null) return const SizedBox.shrink();
            final bant = _Bant(servis: s, durum: durum, bilgi: bilgi);
            // SafeArea YALNIZ çizilen bandın etrafında: boş widget'ı sarmak, güncelleme
            // yokken her ekranın tepesinde hayalet bir boşluk bırakırdı.
            return ustBosluk ? SafeArea(bottom: false, child: bant) : bant;
          },
        );
      },
    );
  }
}

class _Bant extends StatelessWidget {
  const _Bant({required this.servis, required this.durum, required this.bilgi});

  final GuncellemeServisi servis;
  final GuncellemeDurumu durum;
  final SurumBilgisi bilgi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final iniyor = durum == GuncellemeDurumu.iniyor;
    final kuruluyor = durum == GuncellemeDurumu.kuruluyor;
    final hata = durum == GuncellemeDurumu.hata;

    return SipDokun(
      // İndirme sürerken dokunuş yok: ikinci bir indirme başlatmak dosyayı bozar.
      onTap: iniyor || kuruluyor ? null : servis.indirVeKur,
      zemin: hata ? t.dangerSoft : t.accentSoft,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(
        horizontal: SipSpace.x2,
        vertical: SipSpace.xl,
      ),
      child: Row(
        children: [
          SipIcon(
            // İkon setinde "indir" YOK. Yeni varlık eklemek yerine mevcut sözlükten en yakın
            // anlam seçildi: `sync` (yenileme/güncelleme), hatada `alert`.
            hata ? SipIcons.alert : SipIcons.sync,
            boyut: 16,
            kalinlik: 2.2,
            renk: hata ? t.danger : t.accent,
          ),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(
              _metin(),
              style: SipText.govdeKalin.copyWith(color: hata ? t.danger : t.accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (iniyor)
            ValueListenableBuilder<double>(
              valueListenable: servis.ilerleme,
              builder: (context, o, _) => Text(
                '%${(o * 100).round()}',
                style: SipText.yardimci.copyWith(color: t.accent),
              ),
            ),
        ],
      ),
    );
  }

  String _metin() => switch (durum) {
        GuncellemeDurumu.iniyor => 'İndiriliyor…',
        GuncellemeDurumu.kuruluyor => 'Kurulum başlatılıyor…',
        GuncellemeDurumu.hata => 'Güncelleme tamamlanamadı — tekrar denemek için dokunun',
        _ => 'Güncelleme var — Sipario ${bilgi.surum} (${bilgi.yapim})',
      };
}
