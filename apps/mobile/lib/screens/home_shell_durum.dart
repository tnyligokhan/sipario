// KABUĞUN DURUM YÜZEYİ — `sync_meta` satırının duruma çevrilmesi + üstteki bandın seçimi.
//
// NEDEN AYRI DOSYA: `home_shell.dart` 1022 satıra çıkmıştı (500 satır kuralı). Buradaki kod
// ne çizer ne gezinir: SUNUCUDAN İNEN TEK SATIRI (abonelik · rol · kontör · adres) ekranın
// anlayacağı alanlara çevirir ve "en üstte hangi bant durmalı?" sorusunu cevaplar.
//
// ⚠️ TEK ÇAĞIRAN AKIŞTIR: `_metaUygula`yı yalnız `watchSyncState()` aboneliği çağırır. İkinci
// bir tazeleme yolu (tek atış okuma) bilinçli olarak YOKTUR — sunucu sahipli alanlar hem
// senkronla hem ekranlardan değişir ve iki yol tutmak ikisinin ayrışması demekti.
//
// NEDEN `part` ve `setState` yerine `_durumDegisti`: gerekçe `home_shell_cagri.dart` başlığında.

part of 'home_shell.dart';

/// Kabuğun DURUM yüzeyi — sunucu satırını ekran durumuna çevirir.
extension _DurumYuzeyi on _HomeShellState {
  /// Bir iş bittiğinde (ör. sipariş kaydı) kabuğu hedef sekmeye alır ve ÜSTÜNDEKİ push'ları
  /// kapatır. `popUntil` şart: müşteri kartından açılan formda yalnız sekmeyi değiştirmek,
  /// altta duran siparişler sekmesini kullanıcıya hiç göstermezdi (üstte kart durmaya devam
  /// ederdi) — ve geri tuşu onu yeni bitirdiği forma değil ama bitirdiği işin BAŞLANGICINA
  /// döndürürdü.
  void _sekmeyeYonlendir(SipSekme sekme) {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    _sekmeSec(sekme);
  }

  /// sync_meta satırından rol/abonelik/kontör türevlerini hesaplayıp duruma yazar.
  /// TEK çağıran akış aboneliğidir — ikinci bir tazeleme yolu bilinçli olarak yok.
  void _metaUygula(SyncMetaData meta) {
    final now = SubscriptionState.estimateServerNow(
      serverTimeOffsetMs: meta.serverTimeOffsetMs,
      lastServerTimeIso: meta.lastServerTimeIso,
    );
    final gecerli =
        meta.validUntilIso != null ? DateTime.tryParse(meta.validUntilIso!) : null;
    // Konum bildirimi OTURUMA bağlıdır: giriş yapılınca sayaç döner, çıkışta durur. Kabuğun
    // `initState`inde koşulsuz başlatılsaydı, oturumsuz açılan uygulamada (giriş ekranı arkası,
    // testler) 30 sn'de bir boşuna uyanan bir zamanlayıcı kalırdı. `_oturumVar` aynı kapının
    // yaşam döngüsü tarafı: öne gelişte yeniden başlatma kararı bu son değeri okur.
    _oturumVar = meta.authToken != null;
    if (_oturumVar) {
      _konumBildirici.baslat();
    } else {
      _konumBildirici.durdur();
    }
    final level = SubscriptionState.evaluate(
      estimatedServerNow: now,
      validUntil: gecerli,
      status: meta.subscriptionStatus,
    );
    if (!mounted) return;
    _durumDegisti(() {
      _access = level;
      _userRole = meta.userRole;
      _userId = meta.userId;
      _tenantName = meta.tenantName;
      _userName = meta.userName;
      _validUntil = gecerli;
      // Bandın adres satırı. `Session.baseUrlOf` varsayılana düşer → adres HER ZAMAN yazılır;
      // "hiçbir adres yok" da bir bilgi olurdu ama gerçekte olmayan bir durum.
      _apiAdres = bantAdresi(Session.baseUrlOf(meta));
      // Çekmecedeki "Oto sıralama bakiyesi" kartı (tasarım `.lst-kart`). Kota 0 ise sunucu
      // henüz bildirmemiş demektir → kart çizilmez (oran hesaplanamaz, uydurma çubuk çizmeyiz).
      _otoHak = meta.routeCreditsMonthly > 0 ? meta.routeCredits : null;
      _otoAylik = meta.routeCreditsMonthly > 0 ? meta.routeCreditsMonthly : null;
    });
  }

  /// En üstteki senkron bandının türü — çizilecek bant yoksa null.
  ///
  /// ÖNCELİK canlı tur hatasındadır: o AN ne olduğunu anlatır ve genelde eylem gerektirir
  /// (yeniden giriş / bekleme). Karantina uyarısı kalıcıdır, bir sonraki temiz turda zaten
  /// görünür — iki bandı üst üste çizmek ise durum çubuğunu ve yerleşimi bozardı.
  /// ÜÇÜNCÜ SIRA `bekleyen` (2026-08-09 borcu kapatıldı): sunucunun BİLEREK ertelediği kayıtlar
  /// (`locked` = abonelik kilitli · bilinmeyen durum = sürüm çarpıklığı). Karantinanın ALTINDA
  /// çünkü karantina eylem gerektirir (destek), bu ise kendiliğinden çözülür. Ama sessiz de
  /// kalamazdı: sayı hesaplanıp taşınıyordu, hiçbir yüzey OKUMUYORDU — tur "başarılı" sayıldığı
  /// için çip "güncel" derken kayıtlar cihazda birikiyordu. Kilitli bayide zaten kilit ekranı var;
  /// asıl korunan senaryo SÜRÜM ÇARPIKLIĞI — orada hiçbir başka sinyal yok.
  SipBantTuru? get _senkronBandi {
    final o = _sonSenkron;
    if (o != null && !o.ok) return bantTuru(o.tur);
    if (_karantina > 0) return SipBantTuru.karantina;
    return (o?.beklemede ?? 0) > 0 ? SipBantTuru.bekleyen : null;
  }

  /// Güncelleme bandının ÜSTÜNDE çizilen bir bant var mı (senkron / grace)? Durum çubuğu
  /// boşluğunu yalnız EN ÜSTTEKİ bant ekler.
  bool get _ustBantVar => _senkronBandi != null || _access == AccessLevel.grace;

  /// Güncelleme bandı göründüğünde/kaybolduğunda kabuk YENİDEN ÇİZİLMELİ: durum çubuğu ikon
  /// rengi bandın varlığına bakıyor. Bant kendi `ValueListenableBuilder`ıyla tazeleniyor ama
  /// onu saran `AnnotatedRegion` kabuğun `build`inde — dinlemezse ikonlar bandın altında
  /// beyaz kalırdı.
  void _guncellemeBandiDegisti() {
    if (mounted) _durumDegisti(() {});
  }
}
