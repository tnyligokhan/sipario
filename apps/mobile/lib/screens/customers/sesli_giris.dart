// SESLİ GİRİŞ — müşteri formundaki mikrofonun MOTOR tarafı (2026-07-27 bayi isteği:
// "inputların yanında mikrofon işareti olabilir").
//
// `customer_form_ops.dart`tan AYRILDI (2026-07-31): dikte birikimi ve otomatik devam kurallarıyla
// büyüyünce o dosya 500 satır sınırını aşıyordu. Yazma/kalıcılık orada kalır, ses burada; ekran
// ikisini de import eder.
//
// Esnafın klavye toleransı düşük; ad ve adres yazmak siparişin en yavaş adımı. Mikrofon
// alanların YANINDA durur (SipInput'un içine gömülmez — o widget tema katmanının ve trailing
// yuvası yok).
//
// KURALLAR:
//  • Dil DAİMA Türkçe. Cihaz dilinde bırakmak yanlış tanıma demektir; cihazda Türkçe yoksa
//    özellik KAPALI sayılır ve kullanıcıya söylenir (sessizce İngilizce dinlemez).
//  • Çevrimdışı: Android tanımayı cihaza göre bulutta ya da cihaz içinde yapar. Zorla cihaz-içi
//    (`onDevice: true`) İSTENMEZ — Türkçe çevrimdışı modeli yüklü olmayan telefonlarda özellik
//    hiç çalışmazdı. Bunun yerine ağ hatası DÜRÜSTÇE söylenir: "internet gerekiyor, elle yazın".
//    Offline-first kırmızı çizgisi korunur, çünkü sesli giriş bir KOLAYLIKTIR: kapalıyken form
//    elle doldurulur, hiçbir iş akışı bloklanmaz.
//  • Ekran bu sınıfın ötesindeki hiçbir eklenti tipini görmez — widget testleri platform kanalı
//    olmadan koşabilsin diye [sesliGirisUret] dikişinden sahte verilir.

import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Sesli girişin ekrana anlattığı durum.
enum SesDurumu {
  /// Henüz hazırlanmadı (ilk dokunuşta izin istenecek).
  bilinmiyor,

  /// Kullanılabilir — dokunulunca dinler.
  hazir,

  /// Dinliyor.
  dinliyor,

  /// Kullanılamaz (izin yok / cihazda tanıma yok / Türkçe yok). Sebep [SesliGiris.gerekce]de.
  kapali,
}

/// Sesli giriş motorunun ekrana bakan yüzü. Testler [sesliGirisUret] ile sahtesini verir.
abstract class SesliGiris {
  SesDurumu get durum;

  /// Kapalıysa kullanıcıya gösterilecek Türkçe gerekçe.
  String? get gerekce;

  /// İzin ister ve motoru kurar. `true` → dinlemeye hazır.
  Future<bool> hazirla();

  /// Dinlemeye başlar. [onMetin] her tanımada çağrılır — ekran alanı canlı tazeler.
  ///
  /// [nihai] AYRIMI ŞART: motor bir cümleyi kesinleştirdikten (`nihai: true`) sonra bir sonraki
  /// cümleye SIFIRDAN başlar, yani ikinci cümlenin metni birincisini İÇERMEZ. Bu ayrım olmadan
  /// ekran "son tanınan cümle"yi alanın tamamı sanar ve her duraklamada öncekini siler
  /// (2026-07-31 saha şikâyeti: "her duraklamada yazılanı silip üstüne yazıyor").
  ///
  /// [onBitis] dinleme durduğunda çağrılır; gerekçe null değilse kullanıcıya söylenir.
  Future<void> dinle({
    required void Function(String metin, {required bool nihai}) onMetin,
    required void Function(String? gerekce) onBitis,
  });

  Future<void> durdur();

  void birak();
}

/// Uygulamanın kullandığı üretici. Widget testleri bunu sahte bir [SesliGiris] ile değiştirir
/// (`uriAcici` / `tutamacDeposu` deseninin aynısı — eklenti çağrısı tek dikiş yerinden geçer).
SesliGiris Function() sesliGirisUret = SpeechSesliGiris.new;

/// `speech_to_text` üzerine ince sarmalayıcı.
class SpeechSesliGiris implements SesliGiris {
  SpeechSesliGiris();

  final stt.SpeechToText _motor = stt.SpeechToText();

  SesDurumu _durum = SesDurumu.bilinmiyor;
  String? _gerekce;
  String? _yerelKod;

  /// Dinleme bittiğinde bir KEZ çağrılır; motor hem `onStatus` hem `onResult(final)` yolundan
  /// bitiş bildirebiliyor, iki kez haber vermek ekranı yanlış duruma sokardı.
  void Function(String? gerekce)? _bitisKancasi;

  @override
  SesDurumu get durum => _durum;

  @override
  String? get gerekce => _gerekce;

  @override
  Future<bool> hazirla() async {
    if (_durum == SesDurumu.hazir) return true;
    try {
      final acildi = await _motor.initialize(
        onError: (e) => _bitir(_hataMetni(e.errorMsg)),
        onStatus: (s) {
          // 'done' / 'notListening' — kullanıcı sustu ya da sistem kapattı.
          if (s == 'done' || s == 'notListening') _bitir(null);
        },
      );
      if (!acildi) {
        return _kapat('Mikrofon izni verilmedi ya da bu telefonda ses tanıma yok');
      }
      // Türkçe YOKSA hiç dinlemeyiz: cihaz dilinde tanıma "Ayşe Kaya"yı "I shall car" yapar.
      final yereller = await _motor.locales();
      final tr = yereller.where((l) => l.localeId.toLowerCase().startsWith('tr'));
      if (tr.isEmpty) {
        return _kapat('Türkçe ses tanıma bu telefonda yüklü değil');
      }
      _yerelKod = tr.first.localeId;
      _durum = SesDurumu.hazir;
      _gerekce = null;
      return true;
    } on Object {
      // Eklenti yok (test/masaüstü) ya da platform patladı: ÇÖKME YOK, özellik kapalı.
      return _kapat('Ses tanıma bu cihazda kullanılamıyor');
    }
  }

  bool _kapat(String neden) {
    _durum = SesDurumu.kapali;
    _gerekce = neden;
    return false;
  }

  @override
  Future<void> dinle({
    required void Function(String metin, {required bool nihai}) onMetin,
    required void Function(String? gerekce) onBitis,
  }) async {
    if (!await hazirla()) {
      onBitis(_gerekce);
      return;
    }
    _bitisKancasi = onBitis;
    _durum = SesDurumu.dinliyor;
    try {
      await _motor.listen(
        onResult: (r) => onMetin(r.recognizedWords, nihai: r.finalResult),
        listenOptions: stt.SpeechListenOptions(
          localeId: _yerelKod,
          // Kısmi sonuç AÇIK: kullanıcı konuşurken metnin alana düştüğünü görür — sessizce
          // dinleyen mikrofon hem güven sorunudur hem "çalışıyor mu?" sorusunu doğurur.
          partialResults: true,
          // Ad/adres/not tek komut değil, serbest metindir.
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          // Sürekli açık mikrofon YOK: 30 sn üst sınır, 3 sn sessizlikte kapanır.
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } on Object {
      _bitir('Ses tanıma başlatılamadı');
    }
  }

  @override
  Future<void> durdur() async {
    if (_durum != SesDurumu.dinliyor) return;
    try {
      await _motor.stop();
    } on Object {
      // yut — durum aşağıda zaten toparlanıyor
    }
    _bitir(null);
  }

  void _bitir(String? neden) {
    if (_durum == SesDurumu.dinliyor) _durum = SesDurumu.hazir;
    if (neden != null && neden == _izinGerekce) _kapat(neden);
    final kanca = _bitisKancasi;
    _bitisKancasi = null;
    kanca?.call(neden);
  }

  @override
  void birak() {
    _bitisKancasi = null;
    try {
      _motor.cancel();
    } on Object {
      // yut
    }
  }

  static const String _izinGerekce = 'Mikrofon izni verilmedi — telefon ayarlarından açın';

  /// Motorun ham hata kodunu kullanıcının anlayacağı tek cümleye çevirir. Ağ hataları
  /// ÖZELLİKLE ayrılır: bu uygulama offline-first, kullanıcı "neden çalışmadı"yı bilmeli.
  static String _hataMetni(String kod) => switch (kod) {
        'error_network' || 'error_network_timeout' || 'error_server' =>
          'Ses tanıma için internet gerekiyor — çevrimdışıyken elle yazın',
        'error_permission' || 'error_insufficient_permissions' => _izinGerekce,
        'error_no_match' || 'error_speech_timeout' => 'Anlaşılmadı, tekrar deneyin',
        'error_language_not_supported' || 'error_language_unavailable' =>
          'Türkçe ses tanıma bu telefonda yüklü değil',
        'error_busy' => 'Mikrofon şu an başka bir uygulamada',
        _ => 'Ses tanıma başarısız oldu',
      };
}

/// Tanınan metni alana yazarken kullanılan birleştirme.
///
/// KURAL: alan doluysa metin SONUNA eklenir, ÜZERİNE YAZILMAZ. Gerekçe: tanıma yanılabilir ve
/// kullanıcının elle yazdığını sessizce silmek geri alınamaz bir kayıptır; fazladan kelimeyi
/// silmek ise tek dokunuş. Bu, projenin "kayıt ezilmez, düzeltme eklenerek yapılır"
/// disiplininin arayüz karşılığıdır.
///
/// [taban] dinleme BAŞLARKEN alanda duran metindir — her kısmi sonuçta yeniden birleştirilir,
/// böylece konuşma sürerken alan büyür ama önceki içerik tekrarlanmaz.
String sesMetniBirlestir(String taban, String taninan) {
  final t = taban.trimRight();
  final y = taninan.trim();
  if (y.isEmpty) return taban;
  return t.isEmpty ? y : '$t $y';
}

/// Bir dikte oturumunun metin birikimi — mikrofon AÇIK kaldığı sürece tanınan her cümleyi alanın
/// sonuna EKLER, hiçbirini silmez.
///
/// NEDEN VAR (2026-07-31 saha şikâyeti: "her duraklamada yazılanı silip üstüne yazıyor"): önceki
/// sürüm dinleme başındaki metni sabit `taban` alıp her sonuçta alanı `taban + sonTanınan` ile
/// YENİDEN yazıyordu. Motor ise bir cümleyi kesinleştirdikten sonra sıfırdan başlar — ikinci
/// cümle geldiğinde birincisi taban'da olmadığı için kayboluyordu. Uzun adres tek nefeste
/// söylenemediğinden bu, özelliği sahada kullanılamaz yapıyordu.
///
/// KURAL: kesinleşen (`nihai`) parçalar birikime EKLENİR; kısmi parça yalnız o ANIN kuyruğudur ve
/// bir sonraki kısmi sonuçla değişir — birikime asla dokunmaz.
class DikteBirikimi {
  DikteBirikimi(this._taban);

  /// Alanda dinleme başlarken duran metin + kapanmış motor oturumlarının kazancı.
  String _taban;

  /// BU motor oturumunda kesinleşmiş parçalar.
  String _oturum = '';

  /// Motordan gelen parçayı işler ve alana yazılacak TAM metni döndürür.
  String parca(String metin, {required bool nihai}) {
    if (nihai) {
      _oturum = sesMetniBirlestir(_oturum, metin);
      return sesMetniBirlestir(_taban, _oturum);
    }
    return sesMetniBirlestir(sesMetniBirlestir(_taban, _oturum), metin);
  }

  /// Motor kendini kapattı ama kullanıcı dinlemeyi sürdürüyor: kesinleşen her şey tabana geçer,
  /// yeni oturum temiz sayfayla başlar (motor da sıfırdan sayacaktır).
  void oturumKapandi() {
    _taban = sesMetniBirlestir(_taban, _oturum);
    _oturum = '';
  }
}

/// Bir alanın dikte oturumunu yürütür: motoru açar, parçaları [DikteBirikimi] ile biriktirir ve
/// motorun KENDİ kapanışında — kullanıcı durdurmadıkça — dinlemeyi sürdürür. Ekran yalnız hangi
/// alanın dinlendiğini bilir; oturum yenileme, birikim ve üst sınır burada durur.
///
/// OTOMATİK DEVAM (aynı saha isteğinin ikinci yarısı: "buton aktif olduğu sürece"): motorun
/// sessizlik sınırı bir adres söylerken kolayca aşılır (kapı numarasını hatırlamaya çalışan
/// kullanıcı susar). Oturumu orada bitirmek, kullanıcının kapatmadığı düğmenin cümlenin
/// ortasında kendi kendine sönmesi demekti.
class DikteSurucusu {
  DikteSurucusu({
    required this.ses,
    required this.canli,
    this.enFazlaOturum = 8,
    this.yenidenGecikme = const Duration(milliseconds: 300),
  });

  final SesliGiris ses;

  /// Ekran hâlâ ağaçta mı — kapanmış sheet'in mikrofonu yeniden başlatılmaz.
  final bool Function() canli;

  /// Yeniden başlatma üst sınırı. Motor tek seferde en çok 30 sn dinler; 8 tur ≈ 4 dk. SINIRSIZ
  /// DEĞİL: cebe giren telefonda sonsuza kadar açık mikrofon hem pil hem güven meselesidir.
  final int enFazlaOturum;

  /// İki oturum arasındaki nefes payı. Android tanıyıcı bitişi bildirdiği anda henüz tam
  /// kapanmamıştır; aynı karede `listen` çağırmak "busy" hatası üretir.
  final Duration yenidenGecikme;

  /// Üst sınırda söylenen tek cümle. Sessizce sönen düğme, kullanıcının söylediğinin
  /// yazılmadığını çok sonra fark etmesi demektir.
  static const String sureDolduMesaji =
      'Dinleme süresi doldu — devam etmek için mikrofona dokunun';

  DikteBirikimi? _birikim;
  void Function(String metin)? _yaz;
  void Function(String? gerekce)? _bitti;
  int _oturumSayaci = 0;
  bool _acik = false;

  /// [taban] alanda dinleme başlarken duran metindir; tanınan her cümle onun SONUNA eklenir.
  /// [yaz] alana yazılacak TAM metni alır, [bitti] yalnız dinleme gerçekten sona erdiğinde
  /// (hata ya da üst sınır) çağrılır — ara oturum yenilemeleri ekrana yansımaz.
  Future<void> basla({
    required String taban,
    required void Function(String metin) yaz,
    required void Function(String? gerekce) bitti,
  }) {
    _birikim = DikteBirikimi(taban);
    _yaz = yaz;
    _bitti = bitti;
    _oturumSayaci = 0;
    _acik = true;
    return _oturumAc();
  }

  Future<void> durdur() async {
    // Bayrak durdurmadan ÖNCE düşer: motorun bitiş kancası bunu okuyup kendini yeniden
    // başlatmasın — kullanıcının kapattığı mikrofon kapalıdır.
    _acik = false;
    await ses.durdur();
  }

  Future<void> _oturumAc() {
    final birikim = _birikim!;
    return ses.dinle(
      onMetin: (metin, {required nihai}) => _yaz?.call(birikim.parca(metin, nihai: nihai)),
      onBitis: (gerekce) {
        if (!_acik) return; // kullanıcı kapattı; ekran zaten haberli
        if (!canli()) {
          _acik = false;
          return;
        }
        if (gerekce == null && _oturumSayaci < enFazlaOturum) {
          _oturumSayaci++;
          birikim.oturumKapandi();
          Future<void>.delayed(yenidenGecikme, () {
            if (_acik && canli()) _oturumAc();
          });
          return;
        }
        _acik = false;
        _bitti?.call(gerekce ?? sureDolduMesaji);
      },
    );
  }
}
