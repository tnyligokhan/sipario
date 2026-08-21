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

/// Bant O AN çiziliyor mu?
///
/// TEK TANIM: hem bandın kendisi hem de kabuk bunu okur. Kabuğun buna ihtiyacı var çünkü bant
/// ekranın EN ÜSTÜNE giriyor ve ana ekranın koyu hero'su artık durum çubuğunun altında değil —
/// ikonları beyaza zorlamak, açık renkli bandın üstünde onları görünmez yapar (2026-07-28 saha
/// bulgusu). İki kopya koşul zamanla ayrışır ve ayrıştığı gün saat/pil okunmaz olur.
bool guncellemeBandiGorunurMu({GuncellemeServisi? servis, bool? kapali}) {
  if (kapali ?? guncellemeKapaliMi) return false;
  final s = servis ?? guncellemeServisi;
  return s.durum.value != GuncellemeDurumu.yok && s.bulunan.value != null;
}

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
        return ValueListenableBuilder<SurumBilgisi?>(
          valueListenable: s.bulunan,
          builder: (context, bilgi, _) {
            // Görünürlük kararı kabukla ORTAK fonksiyondan gelir (durum çubuğu rengi aynı
            // koşula bakıyor); burada ayrı bir `if` yazmak iki kopya kural demek olurdu.
            if (!guncellemeBandiGorunurMu(servis: s, kapali: kapali) || bilgi == null) {
              return const SizedBox.shrink();
            }
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
    final renk = hata ? t.danger : t.accent;

    return SipDokun(
      // İndirme sürerken dokunuş yok: ikinci bir indirme başlatmak dosyayı bozar.
      onTap: iniyor || kuruluyor ? null : servis.indirVeKur,
      zemin: hata ? t.dangerSoft : t.accentSoft,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(
        horizontal: SipSpace.x2,
        vertical: SipSpace.md,
      ),
      child: Row(
        children: [
          SipIcon(
            // İkon setinde "indir" YOK. Yeni varlık eklemek yerine mevcut sözlükten en yakın
            // anlam seçildi: `sync` (yenileme/güncelleme), hatada `alert`.
            hata ? SipIcons.alert : SipIcons.sync,
            boyut: 17,
            kalinlik: 2.2,
            renk: renk,
          ),
          const SizedBox(width: SipSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _baslik(),
                  style: SipText.govdeKalin.copyWith(color: renk),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    _altBaslik(),
                    style: SipText.yardimci.copyWith(color: renk.withValues(alpha: 0.75)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.lg),
          if (iniyor)
            ValueListenableBuilder<double>(
              valueListenable: servis.ilerleme,
              builder: (context, o, _) => Text(
                '%${(o * 100).round()}',
                style: SipText.govdeKalin.copyWith(color: t.accent),
              ),
            )
          else if (!hata && !kuruluyor)
            _SurumRozeti(surum: bilgi.surum),
        ],
      ),
    );
  }

  /// Üst satır — NE OLDUĞU.
  String _baslik() => switch (durum) {
        GuncellemeDurumu.iniyor => 'İndiriliyor',
        GuncellemeDurumu.kuruluyor => 'Kurulum başlatılıyor',
        GuncellemeDurumu.hata => 'Güncelleme tamamlanamadı',
        _ => 'Yeni sürüm hazır',
      };

  /// Alt satır — NE YAPILACAĞI. Kısa tutulur: bant tek satır yüksekliğinde kalmalı.
  String _altBaslik() => switch (durum) {
        GuncellemeDurumu.iniyor => 'İndirme sürüyor',
        GuncellemeDurumu.kuruluyor => 'Kurulum ekranı birazdan açılacak',
        GuncellemeDurumu.hata => 'Tekrar denemek için dokunun',
        _ => 'Kurmak için dokunun',
      };
}

/// Sürüm numarasını taşıyan hap. YALNIZ SÜRÜM ADI yazar — yapı numarası (`bilgi.yapim`) YOK.
///
/// 2026-08-11 kullanıcı kararı: "sadece sürüm yazsın". Eski metin `Sipario 0.13.0 (412)` idi ve
/// parantez içindeki sayı bayiye hiçbir şey söylemiyordu — o, makinenin karşılaştırma anahtarıdır
/// (CLAUDE.md → Sürümleme: "SemVer insan içindir, derleme numarası makine içindir") ve bandın
/// okuru insandır. Sayı ATILMADI, yalnız bu yüzeyden kalktı: karşılaştırma hâlâ ona dayanıyor
/// ve Ayarlar → Sürüm satırı teşhis için ikisini birden yazmaya devam ediyor.
class _SurumRozeti extends StatelessWidget {
  const _SurumRozeti({required this.surum});

  final String surum;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: 3),
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: SipRadius.brHap,
      ),
      child: Text(
        surum,
        style: SipText.yardimci.copyWith(color: t.accentInk, fontWeight: FontWeight.w700),
      ),
    );
  }
}
