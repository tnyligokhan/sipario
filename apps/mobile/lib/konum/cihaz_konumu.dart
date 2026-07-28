// "Konum Güncelle" — cihazın BULUNDUĞU noktayı okur.
//
// NEDEN İKİ AYRI YOL VAR (adresten kodlama + cihaz konumu): coğrafi kodlama sokağı bulur, kapıyı
// bulmaz. Kurye ilk teslimatta kapının önünde durup "Konum Güncelle"ye bastığında adres metni
// hiç değişmeden pin gerçeğe oturur. Adresten alınan koordinat başlangıç tahmini, bu ise ölçüm.
//
// KURALLAR:
//  • Eklenti çağrılarının TAMAMI try İÇİNDE. Widget testleri platform kanalı olmadan koşar;
//    dışarı taşan tek çağrı o dosyadaki BÜTÜN testleri düşürür (ve iOS'ta çöker).
//  • Hata sebepleri AYRI AYRI söylenir: "izin verilmedi" ile "GPS kapalı" farklı şeylerdir ve
//    kullanıcının yapacağı iş de farklıdır. Tek bir "konum alınamadı" onu ekranda bırakır.
//  • Arka plan konumu İSTENMEZ (ACCESS_BACKGROUND_LOCATION yok): kurye takibi bu sürümde yok,
//    Play'in kısıtlı izin beyan formunu tetiklemenin karşılığı yok.

import 'package:geolocator/geolocator.dart';

/// Cihazdan okunan tek nokta.
class CihazKonumu {
  const CihazKonumu({required this.lat, required this.lng, required this.dogrulukM});

  final double lat;
  final double lng;

  /// Yatay doğruluk (metre). Büyükse kullanıcıya söylenir — "±800 m" bir kapı adresi değildir.
  final double dogrulukM;

  /// Bina kapısı için makul üst sınır. Üstündeki ölçüm reddedilmez ama UYARIYLA gösterilir:
  /// bodrumda/kapalı otoparkta alınmış 500 m'lik bir pin sessizce kaydedilirse kurye ona güvenir.
  bool get guvenilir => dogrulukM > 0 && dogrulukM <= 100;
}

/// Kullanıcıya gösterilebilir konum hatası.
class KonumHatasi implements Exception {
  const KonumHatasi(this.mesaj, {this.ayarlaraYonlendir = false});

  final String mesaj;

  /// Kullanıcının telefon AYARLARINDAN düzeltmesi gereken bir durum mu (kalıcı ret / servis
  /// kapalı)? Uygulama içi tekrar denemek bunu çözmez, söylemek gerekir.
  final bool ayarlaraYonlendir;

  @override
  String toString() => mesaj;
}

/// Zayıf ölçüm kullanıcıya SÖYLENİR (kayıt yine de yapılır — hiçbir konum, yanlış konumdan
/// iyidir demiyoruz; ama "konum kayıtlı" yazısına güvenen kurye ±800 m'yi bilmeli).
String konumDogrulukUyarisi(double metre) =>
    'Konum ±${metre.round()} m doğrulukla alındı — kapının önünde tekrar deneyebilirsiniz.';

/// Ekranların gördüğü tek yüzey. Widget testleri bunu sahtesiyle değiştirir
/// (`sesliGirisUret` / `uriAcici` deseninin aynısı — eklenti çağrısı tek dikişten geçer).
Future<CihazKonumu> Function() cihazKonumuOku = gercekCihazKonumu;

/// `geolocator` üzerine ince sarmalayıcı. Bütün eklenti çağrıları try içindedir.
Future<CihazKonumu> gercekCihazKonumu() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const KonumHatasi(
        'Konum servisi kapalı — telefonun konum ayarını açıp tekrar deneyin.',
        ayarlaraYonlendir: true,
      );
    }

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }

    if (izin == LocationPermission.deniedForever) {
      throw const KonumHatasi(
        'Konum izni kapalı — telefon ayarlarından Sipario için konum iznini açın.',
        ayarlaraYonlendir: true,
      );
    }

    if (izin != LocationPermission.whileInUse && izin != LocationPermission.always) {
      throw const KonumHatasi('Konum izni verilmedi — konum alınamadı.');
    }

    final konum = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Kapalı alanda GPS kilidi uzun sürer; süresiz bekleyen bir düğme "bozuk" sayılır.
        timeLimit: Duration(seconds: 25),
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
    // Zaman aşımı, eklentinin bulunmadığı ortam (test/masaüstü) ya da platform arızası:
    // ÇÖKME YOK, kullanıcı ne yapacağını bilsin.
    throw const KonumHatasi(
      'Konum alınamadı — açık alana çıkıp tekrar deneyin ya da adresten konum alın.',
    );
  }
}
