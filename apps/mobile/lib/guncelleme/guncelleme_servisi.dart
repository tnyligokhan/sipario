// Güncelleme servisi — ağ, dosya ve native köprü. Kararlar `guncelleme_sozlesmesi.dart`ta.
//
// OFFLINE-FIRST ÇİZGİSİ (kırmızı çizgi #3): bu modül açılışı ASLA bloklamaz ve çevrimdışıyken
// hiçbir uyarı üretmez. Her hata sessizce yutulur — güncelleme bir kolaylıktır, bayinin işi
// değildir. Zaman aşımı 5 sn: sinyal çukurundaki kurye bunu hiç fark etmemeli.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'guncelleme_sozlesmesi.dart';

/// Native köprü — kurulum izni, ABI listesi ve kurulum niyeti.
/// Kanal adı `sipario/cagri` deseninin ikizi (bkz. `MainActivity`).
const MethodChannel _kanal = MethodChannel('sipario/guncelleme');

/// İndirme durumu — bant bunu dinler.
enum GuncellemeDurumu { yok, bulundu, iniyor, kuruluyor, hata }

/// Uygulamanın kullandığı servis (tekil). Testler kendi örneğini kurar.
final GuncellemeServisi guncellemeServisi = GuncellemeServisi();

class GuncellemeServisi {
  GuncellemeServisi({http.Client? istemci}) : _istemci = istemci;

  final http.Client? _istemci;

  /// Bulunan sürüm; yoksa null. Bant bu iki bildirimi dinler.
  final ValueNotifier<SurumBilgisi?> bulunan = ValueNotifier<SurumBilgisi?>(null);
  final ValueNotifier<GuncellemeDurumu> durum =
      ValueNotifier<GuncellemeDurumu>(GuncellemeDurumu.yok);

  /// 0..1 arası indirme ilerlemesi.
  final ValueNotifier<double> ilerleme = ValueNotifier<double>(0);

  /// Açılışta çağrılır. `magaza` kanalında ya da yapı numarası bilinmiyorsa HİÇ AĞA ÇIKMAZ.
  Future<void> sessizKontrol() async {
    if (guncellemeKapaliMi) return;
    try {
      final istemci = _istemci ?? http.Client();
      final yanit = await istemci
          .get(Uri.parse(kSurumJsonAdresi))
          .timeout(const Duration(seconds: 5));
      if (yanit.statusCode != 200) return;
      final bilgi = SurumBilgisi.cozumle(yanit.body);
      if (bilgi == null) return;
      if (!guncellemeVarMi(yerelYapim: kYapim, uzakYapim: bilgi.yapim)) return;
      bulunan.value = bilgi;
      durum.value = GuncellemeDurumu.bulundu;
    } on Object catch (e) {
      // Çevrimdışı, DNS yok, zaman aşımı, bozuk JSON — hepsi aynı: sessizlik.
      debugPrint('Güncelleme kontrolü yapılamadı: $e');
    }
  }

  /// İndirir ve kurulum ekranını açar. Bant dokunuşuyla çağrılır.
  ///
  /// Sıra: izin → indir → boyut doğrula → kur. Her adım hata yutar ve durumu `hata`ya çeker;
  /// bayi bandı yeniden deneyebilir.
  Future<void> indirVeKur() async {
    final bilgi = bulunan.value;
    if (bilgi == null || durum.value == GuncellemeDurumu.iniyor) return;

    try {
      // Android 8+ tek seferlik izin: yoksa kullanıcıyı ayara götür ve BEKLE. Dönüşte tekrar
      // sorulur; hâlâ yoksa sessizce vazgeçilir (bayi izni vermek istememiş olabilir).
      if (!await _kurulumIzniVar()) {
        await _kanal.invokeMethod<void>('kurulumIzniIste');
        if (!await _kurulumIzniVar()) {
          durum.value = GuncellemeDurumu.bulundu;
          return;
        }
      }

      durum.value = GuncellemeDurumu.iniyor;
      ilerleme.value = 0;

      final abiler = await _abiler();
      final hedef = bilgi.indirilecek(abiler);
      final dosya = await _indir(hedef.url);
      if (dosya == null) {
        durum.value = GuncellemeDurumu.hata;
        return;
      }

      final bayt = await dosya.length();
      if (!indirmeSaglamMi(inenBayt: bayt, beklenenBayt: hedef.boyut)) {
        // Yarım/bayat indirme: SİL ve kurma. Sonraki açılışta yeniden denenir.
        await dosya.delete().catchError((_) => dosya);
        durum.value = GuncellemeDurumu.hata;
        return;
      }

      durum.value = GuncellemeDurumu.kuruluyor;
      await _kanal.invokeMethod<void>('kur', {'yol': dosya.path});
    } on Object catch (e) {
      debugPrint('Güncelleme kurulamadı: $e');
      durum.value = GuncellemeDurumu.hata;
    }
  }

  Future<bool> _kurulumIzniVar() async {
    try {
      return await _kanal.invokeMethod<bool>('kurulumIzniVar') ?? false;
    } on Object {
      return false;
    }
  }

  Future<List<String>> _abiler() async {
    try {
      final l = await _kanal.invokeListMethod<String>('abiler');
      return l ?? const [];
    } on Object {
      return const [];
    }
  }

  /// APK'yı uygulamanın KENDİ önbelleğine indirir (FileProvider yalnız orayı paylaşır).
  /// Aynı ada yazılır: yarım kalan bir indirme sonrakinde üzerine yazılır, çöp birikmez.
  Future<File?> _indir(String url) async {
    final istemci = _istemci ?? http.Client();
    try {
      final istek = http.Request('GET', Uri.parse(url));
      final yanit = await istemci.send(istek).timeout(const Duration(seconds: 30));
      if (yanit.statusCode != 200) return null;

      final dizin = Directory('${Directory.systemTemp.parent.path}/guncelleme');
      final klasor = await _onbellekKlasoru() ?? dizin;
      if (!await klasor.exists()) await klasor.create(recursive: true);
      final dosya = File('${klasor.path}/sipario-guncelleme.apk');
      final akis = dosya.openWrite();

      final toplam = yanit.contentLength ?? 0;
      var inen = 0;
      await for (final parca in yanit.stream) {
        akis.add(parca);
        inen += parca.length;
        if (toplam > 0) ilerleme.value = (inen / toplam).clamp(0, 1);
      }
      await akis.flush();
      await akis.close();
      return dosya;
    } on Object catch (e) {
      debugPrint('APK indirilemedi: $e');
      return null;
    }
  }

  /// Native taraftan uygulamanın önbellek dizini (`cacheDir/guncelleme`).
  /// FileProvider yolu tam olarak burayı işaret ediyor — başka yere yazmak kurulumu bozar.
  Future<Directory?> _onbellekKlasoru() async {
    try {
      final yol = await _kanal.invokeMethod<String>('onbellekYolu');
      return yol == null ? null : Directory(yol);
    } on Object {
      return null;
    }
  }
}
