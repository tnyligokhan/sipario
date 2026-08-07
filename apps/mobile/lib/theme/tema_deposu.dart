// Sipario — TEMA TERCİHİ deposu (açık/koyu, çalışma anında değişir, kalıcı saklanır).
//
// Tasarım kaynağı: s-uygulama.jsx `tema` state'i + `localStorage.setItem('sipario_tema', …)`.
// Varsayılan AÇIK (tasarımın varsayılanı).
//
// NEDEN DOSYA, NEDEN YENİ PAKET YOK:
//  • `SyncMeta` tablosuna alan eklemek `backend` ajanının alanı — oraya dokunulmuyor.
//  • Yeni bağımlılık (shared_preferences / path_provider) EKLENMEDİ; tek satırlık bir tercih için
//    paket eklemek offline-first APK'sını gereksiz şişirir.
//  • Yazma yolu daima repo→outbox kuralı İŞ VERİSİ içindir; tema bir cihaz tercihidir, senkrona
//    girmez (aynı bayi iki cihazda farklı tema kullanabilir) — bu yüzden DB'ye hiç girmiyor.
//  • Dizin `sqflite`in `getDatabasesPath()`inden gelir (zaten bağımlılıkta ve `sipario.db` de orada
//    duruyor); böylece ek platform kanalı gerekmez.
//
// Depo HATA YUTAR: tercih okunamazsa/yazılamazsa uygulama açık temayla çalışmaya devam eder.
// Widget testlerinde platform kanalı yoktur — bu yüzden `TemaDeposu.bellek()` kullanılır.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

/// Tercihin saklandığı dosyanın adı (içerik: `acik` | `koyu`).
const String kTemaDosyaAdi = 'sipario_tema.txt';

/// Tema tercihini okuyup yazan minik depo.
class TemaDeposu {
  /// Cihazdaki gerçek depo.
  TemaDeposu() : _dizin = getDatabasesPath;

  /// Test/geçici kip — disk yok, değer bellekte durur.
  TemaDeposu.bellek() : _dizin = null;

  final Future<String> Function()? _dizin;
  bool? _bellek;

  Future<File?> _dosya() async {
    final dizin = _dizin;
    if (dizin == null) return null;
    try {
      return File(p.join(await dizin(), kTemaDosyaAdi));
    } on Object {
      return null; // platform kanalı yok (test) ya da dizin çözülemedi
    }
  }

  /// Kayıtlı tercih; hiç yazılmamışsa AÇIK (`false`).
  Future<bool> koyuMu() async {
    if (_bellek != null) return _bellek!;
    final f = await _dosya();
    if (f == null) return false;
    try {
      if (!await f.exists()) return false;
      return (await f.readAsString()).trim() == 'koyu';
    } on Object catch (e) {
      debugPrint('Tema tercihi okunamadı: $e');
      return false;
    }
  }

  /// Tercihi kalıcılar. Yazılamazsa oturum içinde yine de geçerli kalır (bellek yedeği).
  Future<void> yaz(bool koyu) async {
    _bellek = koyu;
    final f = await _dosya();
    if (f == null) return;
    try {
      await f.writeAsString(koyu ? 'koyu' : 'acik', flush: true);
    } on Object catch (e) {
      debugPrint('Tema tercihi yazılamadı: $e');
    }
  }
}

/// Uygulama kökünün dinlediği tema anahtarı. `value == true` → KOYU.
///
/// `MaterialApp` bunu bir [ValueListenableBuilder] ile dinler; tema değişimi ekranları yeniden
/// kurmaz, yalnız `ThemeData`yı değiştirir (CSS'teki `.app.koyu` sınıfının karşılığı).
class TemaKontrol extends ValueNotifier<bool> {
  TemaKontrol({TemaDeposu? depo, bool koyu = false})
      : _depo = depo ?? TemaDeposu(),
        super(koyu);

  final TemaDeposu _depo;

  /// Açılışta kayıtlı tercihi yükler (hata durumunda açık temada kalır).
  Future<void> yukle() async {
    final k = await _depo.koyuMu();
    if (k != value) value = k;
  }

  /// Ayarlar ekranındaki anahtar bunu çağırır.
  Future<void> ayarla(bool koyu) async {
    value = koyu;
    await _depo.yaz(koyu);
  }

  Future<void> tersineCevir() => ayarla(!value);
}
