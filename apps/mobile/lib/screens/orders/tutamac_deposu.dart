// Sürükle-bırak TUTAMACININ TARAFI — cihaz-yerel tercih, kalıcı saklanır.
//
// SAHA HATASI 4 (2026-07-27): tasarım tutamacı sola koyuyordu; telefonu sağ eliyle tutan bayinin
// başparmağı oraya yetişmiyor. Varsayılan SAĞ oldu, sol elini kullananlar için tercih var —
// ama tercih süreç ömrüyle sınırlı kalırsa sol elli bayi HER AÇILIŞTA yeniden seçmek zorunda
// kalır, ki kullanıcının "sol elle kullananları da göz ardı edemeyiz" isteği tam olarak bunu
// engellemek içindi. Bu yüzden diske yazılır.
//
// NEDEN DOSYA, NEDEN YENİ PAKET YOK (theme/tema_deposu.dart deseninin ikizi):
//  • `SyncMeta` tablosuna alan eklemek şema sürümü + migration demek; tek bayrak için o risk
//    gereksiz (bu, lead'in verdiği karar).
//  • Yeni bağımlılık (shared_preferences / path_provider) EKLENMEDİ.
//  • Dizin `sqflite`in `getDatabasesPath()`inden gelir (zaten bağımlılıkta, `sipario.db` de orada).
//  • Yazma yolu daima repo→outbox kuralı İŞ VERİSİ içindir; tutamaç tarafı bir CİHAZ tercihidir,
//    senkrona girmez (aynı bayi masaüstü telefonunda sağ, kuryenin telefonunda sol isteyebilir).
//
// Depo HATA YUTAR: tercih okunamazsa/yazılamazsa uygulama varsayılanla (SAĞ) çalışmaya devam eder.
// Widget testlerinde platform kanalı yoktur — dosya çözülemez, varsayılan döner; deterministik
// test isteyen `TutamacDeposu.bellek()` kullanır.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'order_list_parts.dart' show tutamacSagdaTercihi;

/// Tercihin saklandığı dosyanın adı (içerik: `sag` | `sol`).
const String kTutamacDosyaAdi = 'sipario_tutamac.txt';

/// Uygulamanın kullandığı depo. Testler `TutamacDeposu.bellek()` ile değiştirir — diske
/// dokunmadan, deterministik.
TutamacDeposu tutamacDeposu = TutamacDeposu();

class TutamacDeposu {
  /// Cihazdaki gerçek depo.
  TutamacDeposu() : _dizin = getDatabasesPath;

  /// Test/geçici kip — disk yok, değer bellekte durur.
  TutamacDeposu.bellek() : _dizin = null;

  final Future<String> Function()? _dizin;
  bool? _bellek;

  Future<File?> _dosya() async {
    final dizin = _dizin;
    if (dizin == null) return null;
    try {
      return File(p.join(await dizin(), kTutamacDosyaAdi));
    } on Object {
      return null; // platform kanalı yok (test) ya da dizin çözülemedi
    }
  }

  /// Kayıtlı tercih; hiç yazılmamışsa SAĞ (`true`) — varsayılan, çoğunluk sağ elini kullanıyor.
  Future<bool> sagdaMi() async {
    if (_bellek != null) return _bellek!;
    final f = await _dosya();
    if (f == null) return true;
    try {
      if (!await f.exists()) return true;
      // Yalnız açıkça "sol" yazılmışsa sol; bozuk/yarım dosya varsayılana düşer.
      return (await f.readAsString()).trim() != 'sol';
    } on Object catch (e) {
      debugPrint('Tutamaç tercihi okunamadı: $e');
      return true;
    }
  }

  /// Tercihi kalıcılar. Yazılamazsa oturum içinde yine de geçerli kalır (bellek yedeği).
  Future<void> yaz(bool sagda) async {
    _bellek = sagda;
    final f = await _dosya();
    if (f == null) return;
    try {
      await f.writeAsString(sagda ? 'sag' : 'sol', flush: true);
    } on Object catch (e) {
      debugPrint('Tutamaç tercihi yazılamadı: $e');
    }
  }

  /// Açılışta çağrılır: kayıtlı tercihi ekranların okuduğu [tutamacSagdaTercihi] değişkenine
  /// basar. Tek satırlık bağlama noktası — `main.dart` bunu `TemaKontrol.yukle()` ile aynı
  /// yerde çağırır.
  Future<void> yukle() async => tutamacSagdaTercihi = await sagdaMi();
}
