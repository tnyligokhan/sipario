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
          else if (!kuruluyor)
            // EYLEM DÜĞMESİ — kullanıcı isteği 2026-08-25: *"yükleme butonu pek belirgin
            // değil, orada güncelle şeklinde bir ikon olmalı ya da indirme gibi"*.
            //
            // BURADA ESKİDEN SÜRÜM ROZETİ VARDI ve şikâyetin kaynağı oydu: dolgulu, accent
            // renkli, dokunulacakmış gibi duran bir hap — ama içinde "0.9.0" yazıyordu, yani
            // BİLGİ taşıyordu, EYLEM değil. Bandın tamamı dokunulabilirdi ve bunu söyleyen tek
            // şey alt satırdaki "Kurmak için dokunun" cümlesiydi. Bayi rozete basıyor, bir şey
            // olmuyor sanıyordu (aslında oluyordu — bant zaten dokunuşu alıyor).
            //
            // Sürüm KAYBOLMADI, alt satıra taşındı ([_altBaslik]): 2026-08-11 kararı "sadece
            // sürüm yazsın" diyordu ve o karar duruyor; değişen, sürümün EYLEMİN YERİNİ İŞGAL
            // ETMEMESİ.
            _EylemDugmesi(hata: hata)
        ],
      ),
    );
  }

  /// Üst satır — NE OLDUĞU.
  ///
  /// HATA BAŞLIĞI KISALTILDI (2026-08-25): "Güncelleme tamamlanamadı" 360 punto genişlikte,
  /// yanına "Tekrar Dene" düğmesi geldikten sonra "Güncelleme tamamlan…" diye kırpılıyordu
  /// (golden ile ölçüldü). Kırpılan bir hata başlığı, hatanın kendisinden daha çok
  /// endişelendirir; ne olduğunu alt satır zaten söylüyor.
  String _baslik() => switch (durum) {
        GuncellemeDurumu.iniyor => 'İndiriliyor',
        GuncellemeDurumu.kuruluyor => 'Kurulum başlıyor',
        GuncellemeDurumu.hata => 'Güncellenemedi',
        _ => 'Yeni sürüm hazır',
      };

  /// Alt satır — NE YAPILACAĞI. Kısa tutulur: bant tek satır yüksekliğinde kalmalı.
  ///
  /// SÜRÜM ADI BURADA (2026-08-25): sağ köşe artık eyleme ait. "Kurmak için dokunun" cümlesi
  /// de KALKTI ve gerekmiyor — yanında duran düğme zaten ne yapılacağını söylüyor; cümle,
  /// düğmesiz hâlin kalıntısıydı. Yapım numarası yine YAZILMAZ (2026-08-11 kararı).
  String _altBaslik() => switch (durum) {
        GuncellemeDurumu.iniyor => 'İndirme sürüyor',
        GuncellemeDurumu.kuruluyor => 'Kurulum ekranı birazdan açılacak',
        GuncellemeDurumu.hata => 'İndirme yarım kaldı',
        _ => '${bilgi.surum} sürümü indirilebilir',
      };
}

/// Bandın sağındaki EYLEM DÜĞMESİ — dolgulu, ikonlu, tek bakışta düğme.
///
/// ⚠️ KENDİ `onTap`İ YOK ve bu bilinçli: dokunuşu BANDIN TAMAMI alıyor (`SipDokun`), yani
/// düğmenin yanına, metnine ya da ikonuna basmak da işe yarar. Düğmeye ayrı bir dokunma
/// yüzeyi vermek iki hedefi üst üste bindirir; iç içe iki `GestureDetector`da dıştaki sessizce
/// devre dışı kalır ve bandın geri kalanı ölürdü. Görev paylaşımı nettir: bant DOKUNULUR,
/// düğme SÖYLER.
class _EylemDugmesi extends StatelessWidget {
  const _EylemDugmesi({required this.hata});

  final bool hata;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final zemin = hata ? t.danger : t.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.brHap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SipIcon(
            hata ? SipIcons.sync : SipIcons.indir,
            boyut: 14,
            kalinlik: 2.4,
            renk: t.accentInk,
          ),
          const SizedBox(width: 6),
          Text(
            hata ? 'Tekrar Dene' : 'Güncelle',
            style: SipText.yardimci
                .copyWith(color: t.accentInk, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

