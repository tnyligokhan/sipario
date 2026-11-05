// TELEFON NUMARASI değer nesnesi — Türkiye ve yabancı numaranın TEK çözüm kapısı (2026-11-05).
//
// NEDEN VAR: saha "yabancı numara eklenemiyor" dedi. Kapı `normalizePhoneTR`daydı ve yalnız 10 haneli
// ulusal numarayı tanıyordu. Sorun yalnız formda değildi: `sipTelefon` numarayı son 10 haneye kırpıp
// başına 0 koyduğu için kaydedilen +49 numarası ekranda TR numarası gibi görünür, müşteri düzenlenip
// kaydedilince de gerçekten TR numarasına dönerdi. İki kuralın tek yerde durması bu yüzden şart.
//
// KURAL: ülke kodu YAZILMADAN yabancı numara tanınmaz. "4915112345678" (başında + ya da 00 yok) hem
// yazım hatası hem yabancı numara olabilir; yanlış numara arayan tanımayı kör eder, bu yüzden reddedilir
// ve kullanıcıya ülke koduyla yazması söylenir.
//
// EŞLEŞME: arayan tanıma son 10 haneye bakar (`phoneLast10`, native `CustomerLookup.last10`). E.164
// en az 10 hane şartı bu anahtarın her numarada dolu olmasını sağlar. Bilinen sınır: son 10 hanesi
// aynı iki ülkenin numarası aynı kişi sayılır. Uygulamaya yabancı numara nadiren girdiği için kabul
// edildi; anahtarı değiştirmek native tarafı ve bütün eski kayıtları yeniden yazmak demekti.
//
// Saf Dart: testte ve arka plan kodunda da kullanılır.

/// Çözülmüş telefon numarası. Yalnız [coz] üretir; elde tutulan her örnek geçerlidir.
class TelefonNumarasi {
  const TelefonNumarasi._(this.e164);

  /// E.164'ün üst sınırı (ITU): ülke kodu dahil 15 hane.
  static const int azamiHane = 15;

  /// Eşleşme anahtarının dolu olması için alt sınır; bkz. dosya başlığı.
  static const int asgariHane = 10;

  /// Form hatası: yabancı numara ülke koduyla yazılmalı.
  static const String gecersizMetni = 'Geçerli telefon girin, yabancı numarayı +49 gibi ülke koduyla yazın';

  /// "+905321112233" · "+4915112345678".
  final String e164;

  /// Ham metni çözer; geçersizse null. Kabul edilen yazımlar:
  /// 05321112233 · 5321112233 · 905321112233 · +90 532 111 22 33 · +49 151 12345678 · 0049151…
  static TelefonNumarasi? coz(String? ham) {
    if (ham == null) return null;
    final metin = ham.trim();
    final rakam = metin.replaceAll(RegExp(r'\D'), '');
    if (rakam.isEmpty) return null;

    if (metin.startsWith('+')) return _uluslararasi(rakam);
    if (rakam.startsWith('00')) return _uluslararasi(rakam.substring(2));
    return _ulusal(rakam);
  }

  static TelefonNumarasi? _uluslararasi(String rakam) {
    if (rakam.startsWith('0')) return null; // ülke kodu 0 ile başlamaz
    if (rakam.startsWith('90')) return _ulusal(rakam);
    if (rakam.length < asgariHane || rakam.length > azamiHane) return null;
    return TelefonNumarasi._('+$rakam');
  }

  /// Türkiye: ulusal numara 10 hanedir ve 0 ile başlamaz.
  static TelefonNumarasi? _ulusal(String rakam) {
    final String on;
    if (rakam.length == 10) {
      on = rakam;
    } else if (rakam.length == 11 && rakam.startsWith('0')) {
      on = rakam.substring(1);
    } else if (rakam.length == 12 && rakam.startsWith('90')) {
      on = rakam.substring(2);
    } else {
      return null;
    }
    if (on.startsWith('0')) return null;
    return TelefonNumarasi._('+90$on');
  }

  bool get yabanci => !e164.startsWith('+90');

  /// "0532 415 22 90" · "+4915112345678". Yabancı numarada grup kuralı ülkeye göre değişir ve
  /// bilinmeyen kuralla bölmek numarayı yanlış okutur, bu yüzden E.164 olduğu gibi yazılır.
  String get gosterim {
    if (yabanci) return e164;
    final s = e164.substring(3);
    return '0${s.substring(0, 3)} ${s.substring(3, 6)} ${s.substring(6, 8)} ${s.substring(8)}';
  }
}
