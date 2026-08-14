// YEREL BİLDİRİM SERVİSİ — [BildirimSozlesmesi]'nin cihazdaki uygulaması.
//
// PAKET: `flutter_local_notifications` (+ `timezone`). Gerekçe: Android'de kanal başına
// yönetim, zamanlanmış bildirim ve API 33 izin akışı hazır geliyor; aynısını native yazmak
// `CallerOverlay`daki NotificationManager kodunun üç katı olurdu ve iOS'ta sıfırdan yazılırdı.
// Bildirim CİHAZDAN ÇIKMAZ — sunucu, hesap, push altyapısı YOK (KVKK açısından sessiz).
//
// KANALLAR: kategori başına AYRI kanal. Bayi sistemden tek tek kısabilmeli. Kanal kimlikleri
// `BildirimKategori.wire`dan gelir ve MAĞAZADA DEĞİŞMEZ — değişirse kullanıcının kapattığı
// kanal yeni kanal olarak geri açılır. Arayan kartının kanalı (`sipario_caller`, native
// tarafta) buraya HİÇ dokunmaz: ayrı kimlik, ayrı önem derecesi, ayrı yaşam döngüsü.
//
// TAM ZAMANLI ALARM İZNİ ALINMIYOR: `AndroidScheduleMode.inexactAllowWhileIdle` kullanılıyor,
// bu `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` GEREKTİRMEZ. Bizim bildirimlerimiz alarm değil
// hatırlatma; birkaç dakikalık kayma zararsız, Play'in kısıtlı izin listesine girmek değil
// (kırmızı çizgi #6'nın komşuluğu).

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'bildirim_ayarlari.dart';
import 'bildirim_sozlesmesi.dart';

/// Uygulamanın kullandığı servis. Testler [SahteBildirimServisi] ile değiştirir — tip
/// sözleşmenin kendisidir, uygulama hiçbir yerde somut sınıfa bağlanmaz.
BildirimServisi bildirimServisi = YerelBildirimServisi();

/// Açılışın tek satırlık bağlama noktası (`main.dart`). Sahte servis takılıysa hiçbir şey
/// yapmaz — testler platform kanalına dokunmadan koşar.
Future<void> bildirimAltyapisiniKur() async {
  final servis = bildirimServisi;
  if (servis is YerelBildirimServisi) await servis.kur();
}

class YerelBildirimServisi implements BildirimServisi {
  YerelBildirimServisi({
    FlutterLocalNotificationsPlugin? eklenti,
    BildirimAyarlari? ayarlar,
    DateTime Function()? simdi,
    this.gunlukSinir = const GunlukSinir(),
  })  : _eklenti = eklenti ?? FlutterLocalNotificationsPlugin(),
        _ayarlar = ayarlar,
        _simdi = simdi ?? DateTime.now;

  final FlutterLocalNotificationsPlugin _eklenti;
  final BildirimAyarlari? _ayarlar;
  final DateTime Function() _simdi;
  final GunlukSinir gunlukSinir;

  BildirimAyarlari get _a => _ayarlar ?? bildirimAyarlari;

  bool _kuruldu = false;

  /// Günlük sınıra takıldığı için GÖSTERİLEMEYEN bildirimler (kimlik, an).
  ///
  /// Neden var: sınır bir ürün kararıdır ama sessiz bir kayıp olamaz. Sahadan "bildirim
  /// gelmiyor" şikâyeti geldiğinde bakılacak ilk yer burasıdır; ölçüm ekranına ya da bir
  /// sonraki turun toplu gösterimine bağlanabilir. Süreç ömrüyle sınırlıdır (diske yazılmaz):
  /// tanı verisidir, iş verisi değil.
  final List<(String, DateTime)> atlananlar = [];

  /// Bildirime dokunulduğunda taşınan `yol`. Kabuk bunu okuyup ilgili ekrana gidecek
  /// (Faz 1'de yönlendirme BAĞLI DEĞİL — değer taşınır, tüketen taraf sonraki iş).
  static final ValueNotifier<String?> dokunulanYol = ValueNotifier<String?>(null);

  // ── Kurulum ──────────────────────────────────────────────────────────────────────────────

  /// Açılışta BİR KEZ çağrılır (`main.dart`). İzin İSTEMEZ — izin, bayi ayarlardan
  /// bildirimleri açtığında istenir; açılışta izin diyaloğu göstermek esnafı kaçırır.
  Future<void> kur() async {
    if (_kuruldu) return;
    _kuruldu = true;
    await _a.yukle();
    _saatDilimiKur();
    try {
      await _eklenti.initialize(
        settings: const InitializationSettings(
          // Uygulama ikonu; ayrı bir bildirim ikonu varlığı EKLENMEDİ (kaynak dizini bu
          // vardiyada başka bir ajanın sahasında değil ama gereksiz varlık da üretmiyoruz).
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (yanit) {
          dokunulanYol.value = yanit.payload;
        },
      );
      await _kanallariKur();
    } on Object catch (e) {
      // Bildirim altyapısı kurulamazsa uygulama normal çalışmaya devam eder.
      debugPrint('Bildirim altyapısı kurulamadı: $e');
    }
  }

  /// Türkiye tek saat diliminde (UTC+3, 2016'dan beri yaz saati YOK) ve ürün Türkiye'ye
  /// özel (BRIEF + KVKK veri yerleşimi). Bu yüzden konum SABİT seçildi ve `flutter_timezone`
  /// bağımlılığı eklenmedi — offline-first bir üründe çalışma anında saat dilimi keşfi
  /// gereksiz bir hareketli parça. Konum bulunamazsa `timezone` varsayılanı (UTC) kalır ve
  /// zamanlama saatleri kayar; bu sessiz kalmasın diye loglanır.
  void _saatDilimiKur() {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } on Object catch (e) {
      debugPrint('Saat dilimi kurulamadı, UTC ile devam: $e');
    }
  }

  /// ⚠️ KANAL AYARLARI İLK DOĞUŞTA DONAR — bu metodun en önemli gerçeği budur.
  ///
  /// Android, var olan bir kanalın ÖNEM DERECESİNİ ve SESİNİ uygulamanın değiştirmesine izin
  /// vermez; bu çağrı ikinci kez koştuğunda yalnız AD ve AÇIKLAMA güncellenir. Bilinçli bir
  /// kural: uygulamanın, kullanıcının kıstığı bildirimi arkadan dolanıp geri açmasını
  /// engelliyor.
  ///
  /// PRATİK SONUCU: bir kategoriyi sonradan heads-up yapmak ya da sesini değiştirmek YENİ BİR
  /// `wire` (kanal kimliği) gerektirir — ve yeni kanal, bayinin eskisinde yaptığı kısmaları
  /// hatırlamaz, açık gelir. Bu yüzden yeni bir kategori eklerken [BildirimKategori.headsUp]
  /// ve [BildirimKategori.ses] İLK SEFERDE doğru verilmelidir.
  Future<void> _kanallariKur() async {
    final android = _android();
    if (android == null) return;
    for (final k in BildirimKategori.values) {
      final ses = k.ses;
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          k.wire,
          k.ad,
          description: k.aciklama,
          // HEADS-UP YALNIZ ÜÇ KATEGORİDE (gerekçe: `BildirimKategori.headsUp`). Kalanlar
          // rafa düşer, titrer, simge çıkar — ama işi bölmez.
          importance: k.headsUp ? Importance.high : Importance.defaultImportance,
          // Ses YOKSA sistem varsayılanı çalar; `playSound: false` DEĞİL — sessiz bildirim
          // istemiyoruz, yalnız ayırt edici bir ton istemiyoruz.
          sound: ses == null ? null : RawResourceAndroidNotificationSound(ses),
        ),
      );
    }
  }

  // ── İzin ─────────────────────────────────────────────────────────────────────────────────

  /// Android uygulamasını çözer; PLATFORM YOKSA null döner.
  ///
  /// `resolvePlatformSpecificImplementation` widget testlerinde ATAR (eklenti kaydı yok →
  /// `LateInitializationError`) ve iOS'ta zaten null verir. Çözüm çağrısının kendisi try
  /// dışında kalırsa bu istisna ayarlar ekranını çökertir — depodaki `tutamac_deposu` /
  /// `tema_deposu` deseninin kuralı burada da geçerli: platform yoksa özellik SESSİZCE
  /// pasifleşir, uygulama çalışmaya devam eder.
  AndroidFlutterLocalNotificationsPlugin? _android() {
    try {
      return _eklenti.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
    } on Object catch (e) {
      debugPrint('Bildirim eklentisi çözülemedi (platform yok): $e');
      return null;
    }
  }

  @override
  Future<bool> izinDurumu() async {
    final android = _android();
    if (android == null) return false;
    try {
      return await android.areNotificationsEnabled() ?? false;
    } on Object catch (e) {
      debugPrint('Bildirim izni okunamadı: $e');
      return false;
    }
  }

  @override
  Future<bool> izinIste() async {
    final android = _android();
    if (android == null) return false;
    try {
      return await android.requestNotificationsPermission() ?? false;
    } on Object catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
      return false;
    }
  }

  @override
  Future<bool> kategoriAcikMi(BildirimKategori k) async {
    await _a.yukle();
    return _a.kategoriAcik(k);
  }

  // ── Gösterim ─────────────────────────────────────────────────────────────────────────────

  @override
  Future<void> goster(BildirimTaslagi t) async {
    await _a.yukle();
    if (!_a.kategoriAcik(t.kategori)) return;

    final an = _simdi();
    // SESSİZ SAAT: atılmaz, ERTELENİR. Gece 23:00'te doğan borç uyarısı sabah 08:00'de çıkar;
    // bilgi kaybolmaz, esnafın uykusu bölünmez.
    final sessiz = _a.sessizSaatler;
    if (sessiz.icindeMi(an)) {
      await zamanla(t, sessiz.ertelenmisAn(an));
      return;
    }

    if (!await _butceVarMi(t, an)) {
      // SESSİZ KAYBOLMAZ: bütçe yüzünden atlanan bildirimin izi kalır. Sınır bir ürün kararı
      // olduğu için atlama bir HATA değil, ama görünmez de olmamalı — sahadan "bildirim
      // gelmiyor" bildirimi geldiğinde ilk bakılacak yer burasıdır.
      atlananlar.add((t.kimlik, an));
      debugPrint('Bildirim günlük sınıra takıldı, gösterilmedi: ${t.kimlik}');
      return;
    }
    if (!await izinDurumu()) return;

    try {
      await _eklenti.show(
        id: bildirimSayisalKimlik(t.kimlik),
        title: t.baslik,
        body: t.govde,
        notificationDetails: _ayrinti(t),
        payload: t.yol,
      );
      await _a.kimlikIsaretle(t.kimlik, an);
    } on Object catch (e) {
      debugPrint('Bildirim gösterilemedi: $e');
    }
  }

  @override
  Future<void> zamanla(BildirimTaslagi t, DateTime neZaman) async {
    await _a.yukle();
    if (!_a.kategoriAcik(t.kategori)) return;

    // GÜNLÜK BÜTÇE ZAMANLANMIŞLARA UYGULANMAZ — bilinçli: bildirimi sistem ateşler, o an
    // bizim kodumuz çalışmıyor olabilir (süreç ölü). Zamanlanan bildirimler doğaları gereği
    // az ve tekildir (gün sonu özeti günde bir, rutin teslim günü günde bir); yağmur riski
    // ANLIK bildirimlerde, orada sınır uygulanıyor.
    //
    // Zamanlanan an sessiz saate düşüyorsa sabaha kaydırılır (gün sonu özeti 22:30'a
    // kurulmuşsa ertesi sabah çıkar — atılmaz).
    final sessiz = _a.sessizSaatler;
    final hedef = sessiz.ertelenmisAn(neZaman);
    if (!await izinDurumu()) return;

    try {
      await _eklenti.zonedSchedule(
        id: bildirimSayisalKimlik(t.kimlik),
        title: t.baslik,
        body: t.govde,
        scheduledDate: tz.TZDateTime.from(hedef, tz.local),
        notificationDetails: _ayrinti(t),
        // TAM ZAMANLI ALARM İZNİ İSTEMİYORUZ (dosya başındaki gerekçe): birkaç dakika kayma
        // hatırlatma için zararsız, kısıtlı izin beyanı ise Play riski.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: t.yol,
      );
    } on Object catch (e) {
      debugPrint('Bildirim zamanlanamadı: $e');
    }
  }

  @override
  Future<void> iptal(String kimlik) async {
    try {
      await _eklenti.cancel(id: bildirimSayisalKimlik(kimlik));
    } on Object catch (e) {
      debugPrint('Bildirim iptal edilemedi: $e');
    }
  }

  // ── İç ───────────────────────────────────────────────────────────────────────────────────

  Future<bool> _butceVarMi(BildirimTaslagi t, DateTime an) async {
    final gunluk = _a.gunlukKimlikler(an);
    return gunlukSinir.yerVarMi(t.kategori, gunluk, t.kimlik);
  }

  /// Tek bir bildirimin çizim ayrıntıları.
  ///
  /// `importance`/`priority` BURADA DA VERİLİR ama belirleyici olan KANALDIR (Android 8+):
  /// kanal `high` değilse bu alanlar heads-up üretmez. Yine de tutarlı yazılıyor — Android
  /// 7 ve altı yalnız bunlara bakar ve `minSdk 29` bugün için o cihazları dışarıda bırakıyor
  /// olsa da, iki yerde çelişkili değer bırakmak ileride yanlış teşhise yol açar.
  ///
  /// GENİŞLETİLMİŞ BİLDİRİM (`BigTextStyle`) KANALA BAĞLI DEĞİLDİR: bildirim başına verilir,
  /// yani geriye dönük ve serbestçe eklenebilir — kanal donması kısıtı buraya İŞLEMEZ.
  /// [BildirimTaslagi.detay] boşsa stil hiç verilmez: açılacak bir şeyi olmayan bildirimi
  /// genişletilebilir göstermek, bayiye boş bir hareket yaptırmaktır.
  NotificationDetails _ayrinti(BildirimTaslagi t) {
    final k = t.kategori;
    final ses = k.ses;
    final detay = t.detay;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        k.wire,
        k.ad,
        channelDescription: k.aciklama,
        importance: k.headsUp ? Importance.high : Importance.defaultImportance,
        priority: k.headsUp ? Priority.high : Priority.defaultPriority,
        visibility: _kilitEkraniGorunurlugu(k),
        sound: ses == null ? null : RawResourceAndroidNotificationSound(ses),
        styleInformation: detay == null
            ? null
            : BigTextStyleInformation(
                detay,
                // Başlık genişletilmiş hâlde de AYNI kalır: `contentTitle` verilmezse Android
                // zaten `title`ı kullanır. Farklı bir başlık koymak, bildirimi açan bayiye
                // başka bir şeye baktığını düşündürürdü.
                summaryText: null,
              ),
      ),
    );
  }
}

/// Kategorinin kilit ekranı görünürlüğü.
///
/// PLUGIN SINIRI (denetlendi): `flutter_local_notifications` `publicVersion` alanını AÇMIYOR,
/// yalnız `visibility` var. Yani "kilitliyken nötr özet göster, ayrıntıyı gizle" ikilisi
/// kurulamıyor; `private` seçildiğinde Android bildirimin TAMAMINI gizler ve yalnız uygulama
/// adını gösterir. Bu, güvenli olan taraftır — bayi bir şey geldiğini görür, içeriği kilidi
/// açınca okur. Nötr özet satırı istenirse native bir bildirim köprüsü gerekir (ayrı iş).
///
/// KARAR:
///  • Müşteri ADI ya da PARA taşıyabilen her kategori `private`. Borç eşiği ve vade
///    bildirimleri müşteri adı taşır; gün sonu özeti günlük ciroyu taşır — bayinin telefonu
///    tezgâhta açıkta durur ve müşterisi kendi borcunu, çalışanı günün kasasını başkasının
///    ekranında görmemeli. (Kırmızı çizgi #4 doğrudan kapsamıyor: veri cihazdan çıkmıyor;
///    kapsayan şey bayinin müşterisine karşı sorumluluğu.)
///  • `sistem` `public`: kişisel veri de para da taşımaz, "senkron yapılamıyor" gibi bir
///    uyarının kilitliyken görünmesi işe yarar.
NotificationVisibility _kilitEkraniGorunurlugu(BildirimKategori k) =>
    k == BildirimKategori.sistem
        ? NotificationVisibility.public
        : NotificationVisibility.private;

/// Kimlik dizesinden KARARLI 31 bitlik bildirim kimliği (Android bildirim id'si `int`tir).
///
/// FNV-1a: kendi hesabımız, çünkü `String.hashCode` Dart sürümleri arasında değişebilir ve
/// değişirse "aynı kimlik üzerine yazar" sözleşmesi sessizce kırılır — bayi aynı bildirimin
/// iki kopyasını görür.
int bildirimSayisalKimlik(String kimlik) {
  var h = 0x811c9dc5;
  for (final birim in kimlik.codeUnits) {
    h ^= birim;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h & 0x7FFFFFFF;
}
