// REHBERİN "GÖRÜLDÜ" DURUMU — CİHAZ-YEREL, kalıcı.
//
// NEDEN DOSYA, NEDEN ŞEMAYA ALAN EKLEMİYORUZ (`orders/tutamac_deposu.dart`,
// `theme/tema_deposu.dart` ve `bildirim/bildirim_ayarlari.dart` deseninin dördüncü örneği):
//  • `SyncMeta` tablosuna alan eklemek şema sürümü + migration demek; birkaç bayrak için
//    o risk alınmıyor.
//  • Yeni bağımlılık (shared_preferences / path_provider) EKLENMEDİ; dizin `sqflite`in
//    `getDatabasesPath()`inden gelir (`sipario.db` de orada).
//
// NEDEN SENKRONA GİRMEZ: "bu turu gördüm" bir CİHAZ olgusudur, bir iş verisi değil. Patron
// yeni telefona geçtiğinde turu yeniden görmesi doğrudur — ekran o telefonda gerçekten yeni.
// Ayrıca senkrona sokmak, cihazsız yazımın LWW'de bayat kalması tuzağını davet ederdi.
//
// ⚠️ OKUMA SENKRONDUR, YÜKLEME ASENKRON: tur oynatma kararı bir karenin içinde verilir,
// orada `await` edilemez. Bu yüzden `main.dart` açılışta bir kez [yukle] çağırır (temayla ve
// tutamaçla aynı yerde) ve sonraki bütün okumalar bellekten döner. Yükleme yetişmezse depo
// "hiçbir şey görülmemiş" der; en kötü hâlde tur bir kez fazla oynar, veri kaybı olmaz.
//
// BİÇİM (düz metin, satır başına `anahtar=değer`):
//   gorulen=ana,siparisler
//   atlandi=1
//   gorev=kapali

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'rehber_modeli.dart';

/// Durumun saklandığı dosyanın adı.
const String kRehberDosyaAdi = 'sipario_rehber.txt';

/// Uygulamanın kullandığı depo. Testler [RehberDeposu.bellek] ile değiştirir — diske
/// dokunmadan, deterministik.
RehberDeposu rehberDeposu = RehberDeposu();

class RehberDeposu {
  /// Cihazdaki gerçek depo.
  RehberDeposu() : _dizin = getDatabasesPath;

  /// Test/geçici kip — disk yok, değerler bellekte durur.
  RehberDeposu.bellek() : _dizin = null;

  final Future<String> Function()? _dizin;

  final Set<String> _gorulen = <String>{};
  bool _atlandi = false;
  bool _gorevKartiAcik = true;
  bool _yuklendi = false;

  // ── Okuma (SENKRON — karenin içinde çağrılır) ────────────────────────────────────────

  /// Bu yüzeyin turu daha önce sonuna kadar oynadı mı.
  bool gorulduMu(RehberYuzey y) => _gorulen.contains(y.anahtar);

  /// Kullanıcı bir turda "Atla" dedi mi. TEK BİR ATLA BÜTÜN TURLARI KAPATIR: adım adım
  /// atlatmak, rehberden kurtulmak isteyen bayiye her ekranda aynı düğmeyi bastırırdı.
  /// Kapanan yalnız KENDİLİĞİNDEN AÇILMADIR — `?` düğmesi ve Ayarlar'daki sıfırlama durur.
  bool get tumuAtlandi => _atlandi;

  /// Ana ekrandaki görev kartı çizilsin mi (kullanıcı kapatmadıysa).
  bool get gorevKartiAcik => _gorevKartiAcik;

  /// Durum diskten okundu mu. [yukle] hata yutsa bile `true` olur — soru "dosya var mıydı"
  /// değil, "okumayı denedik mi"dir.
  bool get hazir => _yuklendi;

  /// Kendiliğinden tur oynayabilir mi (durum okunmuş, atlanmamış ve bu yüzey görülmemiş).
  ///
  /// ⚠️ [hazir] DEĞİLKEN HİÇ OYNAMAZ ve bu bilinçli bir "sessiz taraf" seçimidir: durum
  /// okunmadan oynatmak, kullanıcının dün kapattığı turu bugün yeniden açma riskini taşır.
  /// Ters yönün bedeli çok daha küçük — tur bir açılış geç başlar. Ayrıca bu, rehberin var
  /// olan widget testlerine SIZMAMASINI sağlar: `yukle` yalnız `main.dart`ta çağrılır, yani
  /// kabuğu kuran bir test kendiliğinden açılan bir karartmayla karşılaşmaz.
  ///
  /// `?` düğmesi ve "Rehberi baştan göster" bu kapıdan geçmez (`zorla`).
  bool otomatikOynarMi(RehberYuzey y) => _yuklendi && !_atlandi && !gorulduMu(y);

  // ── Yükleme ──────────────────────────────────────────────────────────────────────────

  /// Dosyayı bir kez okur. Sonraki çağrılar hiçbir şey yapmaz.
  Future<void> yukle() async {
    if (_yuklendi) return;
    _yuklendi = true;
    final f = await _dosya();
    if (f == null) return;
    try {
      if (!await f.exists()) return;
      for (final satir in await f.readAsLines()) {
        final ayrac = satir.indexOf('=');
        if (ayrac <= 0) continue;
        final anahtar = satir.substring(0, ayrac).trim();
        final deger = satir.substring(ayrac + 1).trim();
        switch (anahtar) {
          case 'gorulen':
            // TANINMAYAN ANAHTAR ELENİR: bir yüzey üründen kalkarsa eski dosyadaki adı
            // sessizce düşer, ilk yazımda da temizlenir.
            _gorulen
              ..clear()
              ..addAll(deger
                  .split(',')
                  .where((x) => RehberYuzey.anahtardan(x) != null));
          case 'atlandi':
            _atlandi = deger == '1';
          case 'gorev':
            _gorevKartiAcik = deger != 'kapali';
        }
      }
    } on Object catch (e) {
      debugPrint('Rehber durumu okunamadı: $e');
    }
  }

  // ── Yazma ────────────────────────────────────────────────────────────────────────────

  /// Tur sonuna kadar oynadı — bir daha kendiliğinden açılmaz.
  Future<void> goruldu(RehberYuzey y) async {
    if (!_gorulen.add(y.anahtar)) return; // zaten vardı, diske yazmaya gerek yok
    await _yaz();
  }

  /// "Atla" — bütün turların kendiliğinden açılması kapanır.
  Future<void> tumunuAtla() async {
    if (_atlandi) return;
    _atlandi = true;
    await _yaz();
  }

  /// Görev kartı kapatıldı.
  Future<void> gorevKartiniKapat() async {
    if (!_gorevKartiAcik) return;
    _gorevKartiAcik = false;
    await _yaz();
  }

  /// "Rehberi baştan göster" (Ayarlar → Uygulama). Her şeyi ilk kurulum hâline döndürür:
  /// turlar yeniden açılır, görev kartı geri gelir.
  Future<void> sifirla() async {
    _gorulen.clear();
    _atlandi = false;
    _gorevKartiAcik = true;
    await _yaz();
  }

  // ── İç ───────────────────────────────────────────────────────────────────────────────

  Future<File?> _dosya() async {
    final dizin = _dizin;
    if (dizin == null) return null;
    try {
      return File(p.join(await dizin(), kRehberDosyaAdi));
    } on Object {
      return null; // platform kanalı yok (test) ya da dizin çözülemedi
    }
  }

  /// Depo HATA YUTAR: yazılamazsa oturum içinde yine de doğru davranır (bellek aynası).
  /// Rehber bir kolaylıktır; kaybı iş verisi kaybı değildir.
  Future<void> _yaz() async {
    final f = await _dosya();
    if (f == null) return;
    try {
      await f.writeAsString(
        [
          'gorulen=${_gorulen.join(',')}',
          'atlandi=${_atlandi ? 1 : 0}',
          'gorev=${_gorevKartiAcik ? 'acik' : 'kapali'}',
        ].join('\n'),
        flush: true,
      );
    } on Object catch (e) {
      debugPrint('Rehber durumu yazılamadı: $e');
    }
  }
}
