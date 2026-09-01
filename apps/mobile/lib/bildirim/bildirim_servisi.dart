// YEREL BİLDİRİM SERVİSİ — [BildirimSozlesmesi]'nin cihazdaki uygulaması.
//
// PAKET: `flutter_local_notifications` (+ `timezone`). Gerekçe: Android'de kanal başına
// yönetim, zamanlanmış bildirim ve API 33 izin akışı hazır geliyor; aynısını native yazmak
// `CallerOverlay`daki NotificationManager kodunun üç katı olurdu ve iOS'ta sıfırdan yazılırdı.
// Bildirim CİHAZDAN ÇIKMAZ — sunucu, hesap, push altyapısı YOK (KVKK açısından sessiz).
//
// KANALLAR: kategori başına AYRI kanal. Bayi sistemden tek tek kısabilmeli. Kanal kimlikleri
// `BildirimKategori.kanalKimligi`den gelir — `wire`dan DEĞİL (2026-08-18). `wire` sunucuyla
// paylaşılan sözleşmedir ve sürümlenemez; kanal kimliği ise kanalın SESİ değiştiğinde değişmek
// ZORUNDADIR, çünkü Android var olan bir kanalın sesini uygulamanın değiştirmesine izin vermez.
// Sürüm artışının bedeli, bayinin o kanalda yaptığı SİSTEM kısmalarının sıfırlanmasıdır; bu
// yüzden ucuz bir hareket değildir ve gerekçesi sözleşme dosyasında yazılıdır.
//
// Arayan kartının kanalı (`sipario_caller`, native tarafta) buraya HİÇ dokunmaz: ayrı kimlik,
// ayrı önem derecesi, ayrı yaşam döngüsü.
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
          // KÜÇÜK İKON AYRI BİR VARLIKTIR — launcher ikonu BURAYA VERİLEMEZ.
          //
          // Android 5'ten beri küçük ikonu renkleriyle çizmez: yalnız SAYDAMLIK kanalını
          // okur, elde ettiği siluetı temaya göre boyar. Launcher ikonu baştan sona opaktır
          // (mor zemin dahil), yani sistemin gördüğü siluet S değil DOLU BİR KAREDİR.
          // Sahada görülen belirti buydu (2026-09-01): aydınlık temada koyu leke, karanlık
          // temada beyaz leke; ikonun kendisi hiç görünmüyordu.
          //
          // ⚠️ Bu ad bir STRING'dir: Android tarafında statik referansı yoktur ve kaynak
          // kısaltıcı onu ölü sayabilir. `res/raw/keep.xml` listesinde tutulur; oradan
          // silinirse bildirimler sahada sessizce ikonsuz kalır.
          android: AndroidInitializationSettings('@drawable/ic_stat_sipario'),
        ),
        onDidReceiveNotificationResponse: (yanit) {
          dokunulanYol.value = _yolaEylemEkle(yanit.payload, yanit.actionId);
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

    // ÖNCE SİL, SONRA KUR (2026-08-18). Sıra önemlidir: v1 ile v2 aynı ADI ve AÇIKLAMAYI
    // taşıyor, yani bir an bile yan yana durdukları bir liste bayiyi yanıltır. Gerekçenin
    // tamamı `BildirimKategori.kanalKimligiV1` üzerinde.
    //
    // Silme İDEMPOTENTTİR: olmayan kanalı silmek Android'de sessizce hiçbir şey yapmaz, yani
    // uygulamayı ilk kez kuran telefonda da güvenle koşar. İkinci açılışta v1 zaten yoktur.
    for (final k in BildirimKategori.values) {
      await android.deleteNotificationChannel(channelId: k.kanalKimligiV1);
    }

    for (final k in BildirimKategori.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          // ⚠️ `wire` DEĞİL `kanalKimligi`: sesi değiştirmenin tek yolu yeni kanal kimliğidir
          // ve `wire` sunucu sözleşmesi olduğu için sürümlenemez (gerekçe sözleşme dosyasında).
          k.kanalKimligi,
          k.ad,
          description: k.aciklama,
          // HEADS-UP YALNIZ ÜÇ KATEGORİDE (gerekçe: `BildirimKategori.headsUp`). Kalanlar
          // rafa düşer, titrer, simge çıkar — ama işi bölmez. Kanal sürümü artarken bu değer
          // BİLEREK DEĞİŞTİRİLMEDİ: kullanıcının istediği ayırt edici SESTİ, daha çok ekran
          // kesintisi değil.
          importance: k.headsUp ? Importance.high : Importance.defaultImportance,
          // Artık her kategorinin kendi tonu var — sistem varsayılanına düşen kategori YOK.
          sound: RawResourceAndroidNotificationSound(k.ses),
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
    final detay = t.detay;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        // Kanal kimliği `_kanallariKur` ile AYNI kaynaktan okunur. İkisi ayrışırsa bildirim
        // hiç var olmayan bir kanala düşer ve Android onu sessizce yok sayar.
        k.kanalKimligi,
        k.ad,
        channelDescription: k.aciklama,
        importance: k.headsUp ? Importance.high : Importance.defaultImportance,
        priority: k.headsUp ? Priority.high : Priority.defaultPriority,
        visibility: _kilitEkraniGorunurlugu(k),
        sound: RawResourceAndroidNotificationSound(k.ses),
        styleInformation: detay == null
            ? null
            : BigTextStyleInformation(
                detay,
                // Başlık genişletilmiş hâlde de AYNI kalır: `contentTitle` verilmezse Android
                // zaten `title`ı kullanır. Farklı bir başlık koymak, bildirimi açan bayiye
                // başka bir şeye baktığını düşündürürdü.
                summaryText: null,
              ),
        /*
         * KARAR DÜĞMELERİ (kullanıcı isteği 2026-08-22): "Onayla" · "Reddet".
         *
         * ⚠️ `showsUserInterface: true` PAZARLIKSIZ. `false` olsaydı Android düğmeyi ARKA PLAN
         * isolate'inde karşılardı ve karar oradan uygulanmak zorunda kalırdı — bu depoda arka
         * plan isolate'inin SQLite'a yazması yasaktır (`push_servisi.dart` başlığı: para ve
         * defter kayıtlarında yarış riski). `true` ile uygulama öne gelir, kararı ön plandaki
         * tek isolate uygular ve bayi sonucu ekranda görür.
         *
         * `cancelNotification` VARSAYILAN (true) BIRAKILIR: karar verildikten sonra bildirim
         * rafta durursa aynı talep ikinci kez onaylanmaya çalışılır.
         *
         * KANAL DONMASI BURAYA İŞLEMEZ: eylemler bildirim başına verilir, kanal ayarı değildir
         * (genişletilmiş metinle aynı sınıf).
         */
        actions: t.kararIster
            ? const [
                AndroidNotificationAction(
                  BildirimEylemi.iptalOnay,
                  BildirimEylemi.iptalOnayEtiketi,
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  BildirimEylemi.iptalRet,
                  BildirimEylemi.iptalRetEtiketi,
                  showsUserInterface: true,
                ),
              ]
            : null,
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

/// Dokunulan yola, basılan DÜĞMENİN kimliğini `#eylem` eki olarak ekler.
///
/// Gövdeye dokunulduğunda `actionId` boştur ve yol olduğu gibi döner — yani mevcut davranış
/// değişmez. Ek, `bildirimYoluCoz` tarafından çözülür; iki uç aynı biçimi bilir.
///
/// SAF ve GÖRÜNÜR (private değil, test edilebilir): bu iki satır "Onayla düğmesine basıldığında
/// ne oluyor" sorusunun tamamıdır ve sessizce yanlış olması en pahalı yer burasıdır.
String? _yolaEylemEkle(String? yol, String? eylemId) {
  final y = yol?.trim();
  if (y == null || y.isEmpty) return yol;
  final e = eylemId?.trim();
  if (e == null || e.isEmpty) return y;
  return '$y#$e';
}

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
