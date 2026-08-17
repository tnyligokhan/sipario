// ANA EKRANIN ÜST PARÇALARI — hero (selam + firma) · senkron çipi · sürüm çipi · birincil eylem.
//
// NEDEN AYRI DOSYA: `ana_ekran.dart` 509 satıra çıkmıştı (500 satır kuralı). Buradaki dört
// widget ekranın DURUMUNU okumaz: kendilerine verilen değeri çizerler. Bento kutuları, son
// aktivite listesi ve akış abonelikleri ana dosyada kaldı.
//
// ⚠️ SÜRÜM ÇİPİ İKİ NUMARA GÖSTERİR (ağaç → canlı) ve bu bilinçli: sunucudaki sözleşme sürümü
// telefondakinden farklıysa bunu GÖRMEK gerekir; tek numara farkı gizlerdi.

part of 'ana_ekran.dart';
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

