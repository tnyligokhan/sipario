// İzin adımlarının TANIMI — s-sihirbaz.jsx `IZINLER` dizisi (BİREBİR: 6 SABİT adım).
//
// `izin_sihirbazi.dart`'tan ayrıldı (500 satır sınırı). Burada yalnız VERİ var: hangi izin,
// hangi kanal metodu, hangi durum anahtarı, kullanıcıya ne denir. Ekranın davranışı orada kalır.
//
// ══ NEDEN CİHAZA GÖRE DEĞİŞMİYOR ═══════════════════════════════════════════════════════════
// Liste eskiden cihaza göre uzayıp kısalıyordu (MIUI'de fazladan bir adım, SDK≤33'te "kilit
// ekranı" adımı hiç yok). Sonuç: karşılamadaki "N izin isteyeceğiz" cümlesi cihaza göre 5/6/7
// oynuyor, "Adım 3/6" numaraları iki telefonda aynı izni göstermiyordu. Tasarımın dizisi SABİT
// altı adımdır; izin verilemeyen adım "Atla" ile geçilir.
//
// Xiaomi/MIUI'nin "Diğer izinler" adımı KALDIRILDI: tasarımda yok, CSS'te de karşılığı yok
// (`.xiaomi-toggle` tanımlıydı ama hiçbir ekran kullanmıyordu).

import '../../theme/icons.dart';

/// Tek bir izin adımı.
class IzinAdimi {
  const IzinAdimi({
    required this.anahtar,
    required this.ad,
    required this.neden,
    required this.ikon,
    required this.eylem,
    this.zorunlu = false,
    this.durumAnahtari,
    this.birincilEtiket,
    this.ikincilEylem,
    this.ikincilEtiket,
    this.ikincilVarlikAnahtari,
  });

  final String anahtar;
  final String ad;
  final String neden;

  /// [SipIcons] anahtarı.
  final String ikon;

  /// Kanalda çağrılacak metot adı.
  final String eylem;

  /// Kart çalışmıyorsa suçlu bu izinlerden biridir — atlanamaz.
  final bool zorunlu;

  /// `status` haritasındaki anahtar; null ise durum okunamaz (pil) ve kullanıcı ayarlardan verir.
  final String? durumAnahtari;

  /// Birincil düğmenin metni; verilmezse "İzin Ver".
  final String? birincilEtiket;

  /// AYNI adımda açılacak İKİNCİ ayar ekranı (kanal metodu). Bir adımın iki ayarı olabilir:
  /// MIUI'de arayan tanımayı iki ayrı mekanizma öldürüyor (pil kısıtlaması VE otomatik
  /// başlatma) ve ikisi de bu adımın konusudur. Adım SAYISI değişmez — sabit altı adım kararı
  /// (bkz. dosya başlığı) adım listesiyle ilgilidir, adımın içindeki düğmelerle değil.
  final String? ikincilEylem;

  final String? ikincilEtiket;

  /// İkinci düğme YALNIZ bu kanal metodu `true` dönerse çizilir. Cihazda böyle bir ekran yoksa
  /// (Pixel'de otomatik başlatma kavramı yok) düğme hiç görünmez — hiçbir yere gitmeyen bir
  /// düğme, kullanıcıya "bir şeyi eksik yaptım" hissi bırakır.
  final String? ikincilVarlikAnahtari;
}

/// Sihirbazın adımları — tasarım `s-sihirbaz.jsx:3-10` ile aynı sıra, aynı metin.
const List<IzinAdimi> izinAdimlari = [
  IzinAdimi(
    anahtar: 'tarama',
    ad: 'Arama tanıma',
    neden: 'Telefon çaldığında arayan numarayı okuyup müşterinizle eşleştirmek için gereklidir.',
    ikon: SipIcons.phone,
    eylem: 'requestScreeningRole',
    durumAnahtari: 'hasScreeningRole',
    zorunlu: true,
  ),
  IzinAdimi(
    anahtar: 'rehber',
    ad: 'Rehber erişimi',
    neden: 'Kayıtlı müşterilerinizi arayan numarayla eşleştirebilmek için rehbere erişiriz.',
    ikon: SipIcons.users,
    eylem: 'requestContactsPermission',
    durumAnahtari: 'hasContactsPermission',
  ),
  IzinAdimi(
    anahtar: 'overlay',
    ad: 'Üste çizim izni',
    neden: 'Çağrı kartını başka uygulamaların üzerinde, en üstte gösterebilmek için gereklidir.',
    ikon: SipIcons.box,
    eylem: 'requestOverlayPermission',
    durumAnahtari: 'canDrawOverlays',
    zorunlu: true,
  ),
  IzinAdimi(
    anahtar: 'bildirim',
    ad: 'Bildirimler',
    neden: 'Yeni sipariş ve borç hatırlatmalarını size iletebilmek için.',
    ikon: SipIcons.info,
    eylem: 'requestNotificationPermission',
    durumAnahtari: 'hasNotificationPermission',
  ),
  IzinAdimi(
    anahtar: 'kilit',
    ad: 'Kilit ekranında göster',
    neden: 'Telefon kilitliyken bile çağrı kartının çıkması için.',
    ikon: SipIcons.lock,
    eylem: 'requestFullScreenIntent',
    durumAnahtari: 'canUseFullScreenIntent',
  ),
  // SAHA HATASI (2026-07-29): adım "Pil optimizasyonu muafiyeti" diyordu ama açtığı ekran
  // OEM'in OTOMATİK BAŞLATMA listesiydi (`openBestSettingsScreen` Xiaomi/Oppo/Vivo/Huawei'de
  // autostart bileşenini açıyordu). Kullanıcı adı verilen ayarı bulamıyor, pil kısıtlaması da
  // hiç kaldırılmıyordu. İkisi AYRI ayarlardır ve MIUI'de arayan tanımayı ikisi de öldürebilir:
  // otomatik başlatma kapalıysa servis hiç uyanmaz, pil kısıtlaması ise uyanmış süreci keser.
  // Adım artık ikisini de kapsıyor ve düğmeler ne açtıklarını YAZIYOR.
  IzinAdimi(
    anahtar: 'pil',
    ad: 'Arka planda çalışma',
    neden: 'Telefon uygulamayı arka planda kapatırsa çağrı kartı çıkmaz. Bu ekranda iki ayar '
        'var: pil kısıtlamasını kaldırın, cihazınızda varsa otomatik başlatmayı da açın.',
    ikon: SipIcons.bolt,
    eylem: 'openBatterySettings',
    birincilEtiket: 'Pil Ayarını Aç',
    ikincilEylem: 'openAutostartSettings',
    ikincilEtiket: 'Otomatik Başlatmayı Aç',
    ikincilVarlikAnahtari: 'hasAutostartSettings',
  ),
];
