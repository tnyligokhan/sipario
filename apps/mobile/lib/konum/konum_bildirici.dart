// KONUM BİLDİRİCİ — uygulama AÇIKKEN 30 sn'de bir sessiz kalp atışı.
//
// NEDEN "SESSİZ" AYRI BİR YOL (`cihazKonumuOku` KULLANILMAZ): o dikiş bir DÜĞMENİN arkasındadır.
// 25 sn'lik zaman aşımıyla GPS kilidi bekler, izin yoksa kullanıcıya diyalog açar ve arızayı
// cümle cümle anlatır. Bunların hiçbiri arka planda dönen bir sayaca uygun değil: 30 sn'lik
// turun üstüne 25 sn'lik bir bekleme binerse turlar birbirini kovalar, izin diyaloğu ise
// kullanıcının yaptığı işin ortasında sebepsiz açılır.
//
// KURALLAR (üçü de pazarlıksız):
//  • HATALAR SESSİZ: izin yok · GPS kapalı · ağ yok · sunucu 500 → o TUR ATLANIR, kullanıcıya
//    hiçbir şey gösterilmez. Bu özelliğin kullanıcıya dönük bir yüzeyi yoktur; bir toast
//    göstermek, kimsenin istemediği bir işin arızasını kuryenin ekranına taşımak olurdu.
//  • KOORDİNAT LOGLANMAZ (KVKK): ne başarıda ne hatada. `debugPrint` yok.
//  • ARKA PLAN İZNİ YOK (ACCESS_BACKGROUND_LOCATION eklenmez — verilmiş karar): uygulama
//    kapalıyken/arka plandayken konum bildirilmez. `baslat()`/`durdur()` yaşam döngüsüne bağlıdır
//    ve OTURUM YOKSA hiç başlamaz.
//  • Bütün eklenti çağrıları try İÇİNDE — dışarı taşan tek çağrı, o dosyanın BÜTÜN widget
//    testlerini düşürür (bu depoda kanıtlanmış tuzak).

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../auth/session.dart';
import '../data/app_database.dart';
import '../sync/konum_api.dart';
import 'cihaz_konumu.dart';

/// Sessiz turun konum dikişi. `cihazKonumuOku`dan AYRI durur — ikisi farklı sözler veriyor
/// (biri kullanıcıya cevap verir, bu yalnız denemekle yükümlüdür). Testler bunu değiştirir.
Future<CihazKonumu> Function() sessizKonumOku = gercekSessizKonum;

/// `geolocator` üzerine sessiz sarmalayıcı.
///
/// İZİN İSTEMEZ (`requestPermission` yok): izin akışı kullanıcının başlattığı bir eylemin
/// (Konum Güncelle · sihirbaz) parçasıdır. Buradan istenseydi sistem diyaloğu, kullanıcı
/// sipariş girerken sebepsiz yere önüne çıkardı.
///
/// Doğruluk MEDIUM: haritada kuryenin hangi mahallede olduğu okunur, kapı numarası aranmaz —
/// yüksek doğruluk her turda GPS'i uyandırıp pili yakardı.
Future<CihazKonumu> gercekSessizKonum() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const KonumHatasi('Sessiz tur: konum servisi kapalı');
    }

    final izin = await Geolocator.checkPermission();
    if (izin != LocationPermission.whileInUse && izin != LocationPermission.always) {
      throw const KonumHatasi('Sessiz tur: konum izni yok');
    }

    final konum = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        // Turdan KISA: 30 sn'lik aralığın içinde bitmeyen bir okuma, bir sonraki turla
        // yarışmaktan başka bir şey yapmaz.
        timeLimit: Duration(seconds: 10),
      ),
    );

    return CihazKonumu(
      lat: konum.latitude,
      lng: konum.longitude,
      dogrulukM: konum.accuracy,
    );
  } on KonumHatasi {
    rethrow;
  } on Object {
    // Zaman aşımı, eklentisiz ortam (test/masaüstü), platform arızası: mesaj KULLANICIYA
    // GİTMEZ, yalnız çağıranın "bu tur olmadı" demesini sağlar.
    throw const KonumHatasi('Sessiz tur: konum okunamadı');
  }
}

/// Uygulama açıkken dönen kalp atışı sayacı. Kabuk (`home_shell.dart`) oturum varken
/// [baslat], oturum kapanınca ve sökülürken [durdur] çağırır.
class KonumBildirici {
  KonumBildirici(this.db, {this.aralik = const Duration(seconds: 30)});

  final AppDatabase db;

  /// Tur aralığı. 30 sn: harita 25 sn'de tazeleniyor, daha sık bildirmek yalnız pil yakar;
  /// daha seyrek bildirmek ise patronun gördüğü pini sürekli "bayat" bırakırdı.
  final Duration aralik;

  Timer? _zamanlayici;

  /// Bir tur hâlâ dönüyorken ikincisi başlamasın: yavaş bir ağda turlar üst üste binerse
  /// sunucuya aynı anda birkaç kalp atışı gider ve hiçbiri diğerinden daha doğru olmaz.
  bool _turDonuyor = false;

  bool get calisiyor => _zamanlayici != null;

  /// Sayaç zaten dönüyorsa hiçbir şey yapmaz — kabuk bunu her meta değişiminde çağırır.
  /// İlk tur BEKLENMEDEN atılır: 30 sn boyunca haritada hiç görünmemek, uygulamayı yeni açmış
  /// bir kuryeyi "çevrimdışı" göstermek olurdu.
  void baslat() {
    if (_zamanlayici != null) return;
    _zamanlayici = Timer.periodic(aralik, (_) => unawaited(tur()));
    unawaited(tur());
  }

  void durdur() {
    _zamanlayici?.cancel();
    _zamanlayici = null;
  }

  /// Tek tur: oturumu oku → konumu oku → bildir. Her adım kendi başına atlanabilir ve
  /// HİÇBİRİ dışarı hata sızdırmaz.
  Future<void> tur() async {
    if (_turDonuyor) return;
    _turDonuyor = true;
    try {
      final meta = await db.syncState();
      final token = meta.authToken;
      // Oturum yoksa konum bile OKUNMAZ: kimliksiz bir ölçüm gidecek bir yer bulamaz.
      if (token == null) return;

      final CihazKonumu konum;
      try {
        konum = await sessizKonumOku();
      } on Object {
        return; // izin yok / GPS kapalı / zaman aşımı → tur atlanır
      }

      try {
        await konumApiUret(Session.baseUrlOf(meta), token).kalpAtisiGonder(
          lat: konum.lat,
          lng: konum.lng,
          dogrulukM: konum.dogrulukM,
        );
      } on Object {
        // Ağ yok / sunucu hatası: kuyruklanmaz. Geç bildirilen bir konum, haritaya yanlış
        // bir "şu an burada" demektir — kaçan tur kaybolur ve bu doğrudur.
      }
    } on Object {
      // Veritabanı okunamadı (kapanmakta olan bir db gibi): tur sessizce düşer.
    } finally {
      _turDonuyor = false;
    }
  }
}
