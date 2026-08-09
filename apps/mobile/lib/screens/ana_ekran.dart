// ANA EKRAN — s-ana.jsx + Sipario.html `.ana-*`, `.bento*`, `.akt-*`.
//
// Koyu mürekkep hero (selam + SAHİP ADI + menü + senkron çipi) · bento özet ızgarası · birincil
// CTA · "Son aktivite" listesi. Rakamlar GERÇEK veriden gelir (bkz. shell/ana_ozet.dart) — demo
// sabiti yok.
//
// HERO'DA İŞLETME ADI DEĞİL SAHİP ADI YAZAR: `s-ana.jsx:21` `{ISLETME.sahip}` ('Mehmet Usta').
// CSS sınıfı `.ana-isletme` adını taşır ama içeriği sahiptir; işletme adı ÇEKMECEDE kullanılır
// (`s-bilesenler.jsx:100`). Selamın ("Günaydın") altına firma unvanı değil kişinin adı gelir.
//
// 4. bento kutusu "Son Arama" (`s-ana.jsx:45`): verisi `cagri/cagri_gunlugu.dart`taki
// [sonAramaAkisi]. Kutuya dokunmanın kuralı `s-uygulama.jsx:90` (`onAramaAc`) — numara
// KAYITLIYSA müşteri detayı, KAYITSIZSA çağrı kartı. Kararı bu ekran vermez, [onArama] ile
// kabuğa devreder (çağrı günlüğü ne müşteri ekranını ne çağrı kartını tanır).

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../guncelleme/guncelleme_servisi.dart';
import '../sync/sync_service.dart';
import '../sync/yenileme.dart';
import '../theme/components/atoms.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'cagri/cagri_model.dart';
import 'shell/alt_nav.dart';
import 'shell/ana_bento.dart';
import 'shell/ana_ozet.dart';

class AnaEkran extends StatelessWidget {
  const AnaEkran({
    super.key,
    required this.db,
    required this.sahipAdi,
    required this.onMenu,
    required this.onSekme,
    required this.onYeniSiparis,
    required this.onArama,
    required this.onSiparisAc,
    required this.onBorclular,
    this.borclulariGoster = true,
    this.acikSiparisKullanicisi,
    this.sonSenkron,
    this.sonSenkronAt,
  });

  final AppDatabase db;

  /// Selamın altındaki ad — kullanıcının kendi adı (tasarım `ISLETME.sahip`).
  final String sahipAdi;

  final VoidCallback onMenu;
  final ValueChanged<SipSekme> onSekme;
  final VoidCallback onYeniSiparis;

  /// "Son Arama" kutusuna dokunulduğunda. Kayıtlı/kayıtsız ayrımını kabuk yapar.
  final ValueChanged<AramaKaydi> onArama;

  /// "Son aktivite" satırına dokunulduğunda: sipariş sekmesine geçilir VE detay açılır
  /// (`s-uygulama.jsx:89` — `setTab('siparis')` + `setSipDetay(veri)`). Detay sheet'i sipariş
  /// katmanının işi; bu ekran yalnız kimliği devreder.
  final ValueChanged<String> onSiparisAc;

  /// "Borçlular" bento kutusu — borçlu müşteriler ekranını kabuk açar (yazma yetkisi orada
  /// bilinir; bu ekran yalnız niyeti devreder, `onArama`/`onSiparisAc` deseninin aynısı).
  final VoidCallback onBorclular;

  /// Borçlular kutusu çizilsin mi (`yetkiler().toplamBorclulariGorme`). Kurye için kapalıdır:
  /// kutu çizilmezse toplam borç tutarı ve borçlu müşteri sayısı ekranda hiç görünmez.
  final bool borclulariGoster;

  /// "Açık Sipariş" kutusunun kapsamı. Kurye kısıtlıysa onun kullanıcı kimliği verilir ve
  /// kutu yalnız ona atananları sayar; yönetici için `null` (dükkân geneli).
  ///
  /// ⚠️ 2026-08-09: bu alan olmadan ana ekran "12 açık" derken sipariş listesi 2 gösteriyordu —
  /// aynı uygulamanın iki yüzeyi farklı sayı konuşuyordu.
  final String? acikSiparisKullanicisi;

  final SyncOutcome? sonSenkron;
  final DateTime? sonSenkronAt;

  /// Saate göre selam (kullanıcı isteği 2026-07-29: dört kuşak).
  ///
  /// Kuşaklar su bayisinin gününe göre biçildi, saat diliminin ortasına değil:
  ///  • 06–11 **Günaydın** — dükkân açılır, günün siparişleri girilir.
  ///  • 12–17 **Kolay gelsin** — teslimatın en yoğun olduğu bant; "iyi günler" burada
  ///    fazla resmî kalıyordu, esnaf birbirine "kolay gelsin" der.
  ///  • 18–21 **İyi akşamlar** — son teslimatlar ve gün sonu kapanışı.
  ///  • 22–05 **İyi geceler** — dükkân kapalı; uygulama bu saatte açılıyorsa ya gün sonu
  ///    hesabı yapılıyordur ya da gece nöbeti vardır, ikisinde de "günaydın" yanlış olur.
  static String selam(DateTime simdi) {
    final s = simdi.hour;
    if (s >= 6 && s < 12) return 'Günaydın';
    if (s >= 12 && s < 18) return 'Kolay gelsin';
    if (s >= 18 && s < 22) return 'İyi akşamlar';
    return 'İyi geceler';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Hero(
          sahipAdi: sahipAdi,
          onMenu: onMenu,
          sonSenkron: sonSenkron,
          sonSenkronAt: sonSenkronAt,
        ),
        Expanded(
          child: StreamBuilder<AnaOzet>(
            stream: watchAnaOzet(db, assignedTo: acikSiparisKullanicisi),
            builder: (context, snap) {
              final o = snap.data ?? const AnaOzet();
              return RefreshIndicator(
                // Ana ekranda yenileme SENKRON + GÜNCELLEME kontrolü yapar (kullanıcı isteği
                // 2026-07-29). Gösterge, gerçek turun bitişini bekler — hemen kapanan bir
                // spinner "yapıldı" der ama hiçbir şeyi kanıtlamaz.
                onRefresh: anaEkranYenile,
                child: ListView(
                // AlwaysScrollable: içerik kısa olsa da (yeni kurulum, boş liste) jest
                // çalışmalı; aksi hâlde yenileme tam da en çok gerektiği kurulumda ölürdü.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    SipSpace.govde, SipSpace.x3, SipSpace.govde, SipSpace.x4),
                children: [
                  AnaBento(
                    db: db,
                    ozet: o,
                    onSekme: onSekme,
                    onArama: onArama,
                    onBorclular: onBorclular,
                    borclulariGoster: borclulariGoster,
                  ),
                  const SizedBox(height: SipSpace.xl),
                  _Cta(onTap: onYeniSiparis),
                  SipBolumBaslik('Son aktivite', ustBosluk: SipSpace.x4),
                  _SonAktivite(db: db, onSiparisAc: onSiparisAc),
                ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// CSS `.ana-hero` — alt köşeleri r4 yuvarlak koyu blok.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.sahipAdi,
    required this.onMenu,
    required this.sonSenkron,
    required this.sonSenkronAt,
  });

  final String sahipAdi;
  final VoidCallback onMenu;
  final SyncOutcome? sonSenkron;
  final DateTime? sonSenkronAt;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        SipSpace.x5,
        SipSpace.x6 + MediaQuery.paddingOf(context).top,
        SipSpace.x5,
        SipSpace.x4,
      ),
      decoration: BoxDecoration(color: t.hero, borderRadius: SipRadius.heroEtek),
      child: DefaultTextStyle(
        style: TextStyle(color: SipTokens.onHero, fontFamily: sipFontBody),
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
                      Text(
                        AnaEkran.selam(DateTime.now()),
                        style: SipText.selam.copyWith(color: SipTokens.onHeroMid),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sahipAdi,
                        style: SipText.isletme.copyWith(color: SipTokens.onHero),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SipSpace.xl),
                SipIkonButon(
                  ikon: SipIcons.menu,
                  cap: 40,
                  ikonBoyut: 20,
                  kalinlik: 2,
                  zemin: SipTokens.onHeroFill,
                  renk: SipTokens.onHero,
                  etiket: 'Menü',
                  onTap: onMenu,
                ),
              ],
            ),
            const SizedBox(height: SipSpace.x3),
            // İki çip yan yana; dar ekranda alt satıra sarar (Wrap) — hero'nun tek satırlık
            // yüksekliği sabit değil ve taşan bir çip metni kırpardı.
            Wrap(
              spacing: SipSpace.sm,
              runSpacing: SipSpace.sm,
              children: [
                _SyncCipi(sonuc: sonSenkron, zaman: sonSenkronAt),
                const _SurumCipi(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// CSS `.ana-sync` — renkli nokta + durum metni.
class _SyncCipi extends StatelessWidget {
  const _SyncCipi({required this.sonuc, required this.zaman});

  final SyncOutcome? sonuc;
  final DateTime? zaman;

  /// Başarısız turun çipteki KISA karşılığı — bandın (`SipBant`) uzun metinlerinin özeti,
  /// AYNI ayrımlarla.
  ///
  /// NEDEN AYRIŞTIRILDI (2026-08-05, cihaz doğrulaması): çip bütün hataları
  /// "Bağlantı yok · tekrar denenecek"e indirgiyordu. Cihaz testinde bant doğru şekilde
  /// "Sunucu yanıt veremiyor" derken çip aynı ekranda "Bağlantı yok" dedi — o an bağlantı
  /// VARDI. Bu, bandın dün kapatılan günahının (ulaşılan sunucuya "çevrimdışı" demek) çipteki
  /// kopyasıydı ve daha kötüsü: aynı ekran iki farklı hikâye anlatıyordu, yani kullanıcı
  /// hangisine inanacağını bilemiyordu.
  ///
  /// "Tekrar denenecek" YALNIZ kendiliğinden düzelecek hâllerde yazılır (`ag`/`sunucu`);
  /// `veri` ve `oturum` beklemekle geçmez, kullanıcı eylemi gerekir — oraya söz verilmez.
  static String _hataMetni(SyncHataTuru tur) => switch (tur) {
        SyncHataTuru.sunucu => 'Sunucu yanıt vermiyor · tekrar denenecek',
        SyncHataTuru.veri => 'Kayıtlar gönderilemiyor · destekle görüşün',
        SyncHataTuru.oturum => 'Oturum doğrulanmadı',
        // `ag` ve `yok`: gerçekten ulaşılamadı — "çevrimdışı" demenin doğru olduğu TEK hâl.
        SyncHataTuru.ag || SyncHataTuru.yok => 'Bağlantı yok · tekrar denenecek',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final ok = sonuc?.ok ?? false;
    final saat = zaman == null
        ? ''
        : ' · ${zaman!.hour.toString().padLeft(2, '0')}:'
            '${zaman!.minute.toString().padLeft(2, '0')}';
    final metin = sonuc == null
        ? 'Senkron bekleniyor'
        : (ok ? 'Senkron güncel$saat' : _hataMetni(sonuc!.tur));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.sm),
      decoration: const BoxDecoration(
        color: SipTokens.onHeroFill,
        borderRadius: SipRadius.brHap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: sonuc == null
                  ? SipTokens.onHeroSoft
                  : (ok ? SipTokens.heroDot : t.danger),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(metin, style: SipText.syncCip.copyWith(color: SipTokens.onHeroMid)),
        ],
      ),
    );
  }
}

/// "Sürüm güncel" çipi — YALNIZ sunucuya gerçekten ulaşılmış bir kontrolden sonra çizilir
/// (kullanıcı isteği 2026-07-29: "gelmediyse senkron güncelin yanında sürüm güncel yazabilir").
///
/// ÜÇ DURUMDA HİÇ ÇİZİLMEZ ve üçü de bilinçli:
///  • Henüz kontrol yapılmadıysa — hiç sorulmamış bir soruya "güncel" diye cevap vermek olurdu.
///  • Çevrimdışı denemede — ulaşılamayan sunucu hakkında "güncelsiniz" demek yanlış bilgidir.
///  • Güncelleme BULUNDUYSA — o durumu güncelleme bandı anlatır; iki yüzey çelişemez.
/// Mağaza derlemesinde kontrol hiç koşmaz, dolayısıyla çip de hiç görünmez (kanal kapısı).
class _SurumCipi extends StatelessWidget {
  const _SurumCipi();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: guncellemeServisi.sonBasariliKontrol,
      builder: (context, kontrol, _) {
        if (kontrol == null) return const SizedBox.shrink();
        return ValueListenableBuilder<GuncellemeDurumu>(
          valueListenable: guncellemeServisi.durum,
          builder: (context, durum, _) {
            if (durum != GuncellemeDurumu.yok) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: SipSpace.xl, vertical: SipSpace.sm),
              decoration: const BoxDecoration(
                color: SipTokens.onHeroFill,
                borderRadius: SipRadius.brHap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SipIcon(SipIcons.check,
                      boyut: 12, kalinlik: 2.4, renk: SipTokens.onHeroMid),
                  const SizedBox(width: 6),
                  Text('Sürüm güncel',
                      style: SipText.syncCip.copyWith(color: SipTokens.onHeroMid)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// CSS `.ana-cta` — hero zeminli birincil eylem.
class _Cta extends StatelessWidget {
  const _Cta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.hero,
      basiliZemin: t.hero2,
      radius: SipRadius.br3,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x3, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
            child: SipIcon(SipIcons.plus, boyut: 20, kalinlik: 2.4, renk: t.accentInk),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Yeni Sipariş',
              style: SipText.anaCta.copyWith(color: SipTokens.onHero),
            ),
          ),
          const SipIcon(SipIcons.chevR,
              boyut: 18, kalinlik: 2.2, renk: SipTokens.onHeroMid),
        ],
      ),
    );
  }
}

/// CSS `.akt-list` / `.ana-bos` — son teslim edilen siparişler.
class _SonAktivite extends StatelessWidget {
  const _SonAktivite({required this.db, required this.onSiparisAc});

  final AppDatabase db;
  final ValueChanged<String> onSiparisAc;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<List<SonHareket>>(
      stream: watchSonHareketler(db),
      builder: (context, snap) {
        final list = snap.data ?? const <SonHareket>[];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, SipSpace.md, 2, SipSpace.md),
            child: Text(
              'Bugün henüz hareket yok.',
              style: SipText.metin(13).copyWith(color: t.muted),
            ),
          );
        }
        return Column(
          children: [
            for (final h in list)
              Padding(
                padding: const EdgeInsets.only(bottom: SipSpace.sm),
                child: SipDokun(
                  onTap: () => onSiparisAc(h.siparisId),
                  zemin: t.surface,
                  radius: SipRadius.br2,
                  padding: const EdgeInsets.symmetric(
                      horizontal: SipSpace.x2, vertical: SipSpace.xl),
                  child: Row(
                    children: [
                      SipIkonKutu(
                        ikon: SipIcons.check,
                        cap: 30,
                        ikonBoyut: 15,
                        kalinlik: 2.4,
                        zemin: t.okSoft,
                        renk: t.ok,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              h.musteriAd,
                              style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            // Alt satır ÜRÜN DÖKÜMÜ + ödeme tipidir (`s-ana.jsx:67`
                            // `{siparisOzet(o)} · {ODEME_TIPLERI[o.odeme].label}`), saat DEĞİL:
                            // "bugün ne sattım"ın cevabı saatte değil kalemde.
                            Text(
                              [h.satirOzeti, odemeEtiketi(h.odemeTipi)]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style: SipText.metin(11.5).copyWith(color: t.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SipSpace.lg),
                      Text(
                        sipTutar(h.tutarKurus),
                        style: SipText.tutar(13).copyWith(color: t.ink),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
