// Bildirim tercihleri ve günlük bütçe sayacı — CİHAZ-YEREL, kalıcı.
//
// NEDEN DOSYA, NEDEN ŞEMAYA ALAN EKLEMİYORUZ (`orders/tutamac_deposu.dart` ve
// `theme/tema_deposu.dart` deseninin üçüncü örneği, lead'in kararı):
//  • `SyncMeta`/`tenant_settings` tablosuna alan eklemek şema sürümü + migration demek;
//    birkaç bayrak için o risk alınmıyor.
//  • Yeni bağımlılık (shared_preferences / path_provider) EKLENMEDİ; dizin `sqflite`in
//    `getDatabasesPath()`inden gelir (`sipario.db` de orada).
//  • Bildirim tercihi bir CİHAZ tercihidir, senkrona GİRMEZ: aynı bayi masaüstü telefonunda
//    gün sonu özeti isteyip kuryenin telefonunda istemeyebilir.
//
// Depo HATA YUTAR: dosya okunamazsa/yazılamazsa uygulama varsayılanlarla çalışmaya devam eder.
// Bildirim bir kolaylıktır; kaybı iş verisi kaybı değildir.
//
// BİÇİM (düz metin, satır başına `anahtar=değer`):
//   kapali=borc_esigi,sistem
//   sessiz=22-8
//   gun=2026-07-27
//   gosterilen=borc_esigi:2026-07-27;gun_sonu_ozeti:2026-07-27

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'bildirim_sozlesmesi.dart';

/// Tercihlerin saklandığı dosyanın adı.
const String kBildirimDosyaAdi = 'sipario_bildirim.txt';

/// Uygulamanın kullandığı depo. Testler [BildirimAyarlari.bellek] ile değiştirir.
BildirimAyarlari bildirimAyarlari = BildirimAyarlari();

class BildirimAyarlari {
  /// Cihazdaki gerçek depo.
  BildirimAyarlari() : _dizin = getDatabasesPath;

  /// Test/geçici kip — disk yok, değerler bellekte durur.
  BildirimAyarlari.bellek() : _dizin = null;

  final Future<String> Function()? _dizin;

  /// Bellek aynası. Diske yazılamasa bile oturum içinde tutarlı davranmayı sağlar.
  Set<String> _kapaliWire = <String>{};
  SessizSaatler _sessiz = const SessizSaatler();

  /// Borç eşiği (kuruş). 0 = BELİRLENMEMİŞ ve kategori pasif.
  ///
  /// VARSAYILAN YOK, bilinçli (lead kararı): cirosu 2.000 ₺ olan bayiyle 200.000 ₺ olan aynı
  /// eşiği kullanamaz. Uydurulmuş bir varsayılan ya bildirimi hiç çıkarmaz ya da her gün
  /// çıkarıp gürültüye çevirir; ikisi de bayiye "bu özellik bozuk" dedirtir.
  int _borcEsigiKurus = 0;
  String _gun = '';
  Set<String> _gosterilen = <String>{};
  bool _yuklendi = false;

  // ── Okuma ────────────────────────────────────────────────────────────────────────────────

  /// Dosyayı bir kez okur. Sonraki çağrılar bellekten döner.
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
          case 'kapali':
            _kapaliWire = deger.split(',').where((x) => x.isNotEmpty).toSet();
          case 'sessiz':
            _sessiz = _sessizCoz(deger) ?? _sessiz;
          case 'gun':
            _gun = deger;
          case 'gosterilen':
            _gosterilen = deger.split(';').where((x) => x.isNotEmpty).toSet();
          case 'borcEsigi':
            _borcEsigiKurus = int.tryParse(deger) ?? 0;
        }
      }
    } on Object catch (e) {
      debugPrint('Bildirim ayarları okunamadı: $e');
    }
  }

  /// Kategori açık mı? Varsayılan AÇIK — bayi kapatmadıysa bildirim gelir.
  ///
  /// TEK İSTİSNA borç eşiği: eşik girilmeden kategori PASİFTİR. Kapı burada, tek yerde;
  /// böylece servis, ayar ekranı ve tetikleyici ayrı ayrı kontrol etmek zorunda kalmıyor —
  /// eşiksiz bir borç bildirimi hiçbir yoldan çıkamaz.
  bool kategoriAcik(BildirimKategori k) {
    if (_kapaliWire.contains(k.wire)) return false;
    if (k == BildirimKategori.borcEsigi && !borcEsigiBelirlendi) return false;
    return true;
  }

  SessizSaatler get sessizSaatler => _sessiz;

  /// Bayinin belirlediği borç eşiği (kuruş); 0 = belirlenmemiş.
  int get borcEsigiKurus => _borcEsigiKurus;

  bool get borcEsigiBelirlendi => _borcEsigiKurus > 0;

  /// Eşiği yazar. 0 (ya da negatif) yazmak kategoriyi yeniden PASİFE alır — bayi eşiği
  /// silerek bildirimi kapatabilir, ayrı bir anahtar aramak zorunda kalmaz.
  Future<void> borcEsigiYaz(int kurus) async {
    _borcEsigiKurus = kurus > 0 ? kurus : 0;
    await _yaz();
  }

  // ── Yazma ────────────────────────────────────────────────────────────────────────────────

  Future<void> kategoriYaz(BildirimKategori k, bool acik) async {
    if (acik) {
      _kapaliWire.remove(k.wire);
    } else {
      _kapaliWire.add(k.wire);
    }
    await _yaz();
  }

  Future<void> sessizYaz(SessizSaatler s) async {
    _sessiz = s;
    await _yaz();
  }

  // ── Günlük bütçe ─────────────────────────────────────────────────────────────────────────

  /// O güne ait, kategori bazında GÖSTERİLMİŞ kimlikler. Gün değiştiyse boş döner
  /// (sayaç gece yarısı kendiliğinden sıfırlanır — ayrı bir temizlik işi yok).
  Map<BildirimKategori, Set<String>> gunlukKimlikler(DateTime simdi) {
    if (_gun != bildirimGunAnahtari(simdi)) return {};
    final harita = <BildirimKategori, Set<String>>{};
    for (final kimlik in _gosterilen) {
      // Kimlik `<wire>:<ayırt edici>` biçimindedir; kategori önekten çözülür.
      final k = BildirimKategori.wiredan(kimlik.split(':').first);
      if (k == null) continue;
      (harita[k] ??= <String>{}).add(kimlik);
    }
    return harita;
  }

  /// Kimliği o günün bütçesine işler. Aynı kimlik ikinci kez işlenirse sayaç ARTMAZ
  /// (küme) — "aynı bildirimin tazelenmesi bütçe yemez" kuralının uygulaması.
  Future<void> kimlikIsaretle(String kimlik, DateTime simdi) async {
    final bugun = bildirimGunAnahtari(simdi);
    if (_gun != bugun) {
      _gun = bugun;
      _gosterilen = <String>{};
    }
    if (!_gosterilen.add(kimlik)) return; // zaten vardı, diske yazmaya gerek yok
    await _yaz();
  }

  // ── İç ───────────────────────────────────────────────────────────────────────────────────

  Future<File?> _dosya() async {
    final dizin = _dizin;
    if (dizin == null) return null;
    try {
      return File(p.join(await dizin(), kBildirimDosyaAdi));
    } on Object {
      return null; // platform kanalı yok (test) ya da dizin çözülemedi
    }
  }

  Future<void> _yaz() async {
    final f = await _dosya();
    if (f == null) return;
    try {
      await f.writeAsString(
        [
          'kapali=${_kapaliWire.join(',')}',
          'sessiz=${_sessiz.baslangicSaat}-${_sessiz.bitisSaat}',
          'gun=$_gun',
          'gosterilen=${_gosterilen.join(';')}',
          'borcEsigi=$_borcEsigiKurus',
        ].join('\n'),
        flush: true,
      );
    } on Object catch (e) {
      debugPrint('Bildirim ayarları yazılamadı: $e');
    }
  }

  /// "22-8" → SessizSaatler(22, 8). Bozuk değer null döner ve varsayılan korunur.
  static SessizSaatler? _sessizCoz(String ham) {
    final parcalar = ham.split('-');
    if (parcalar.length != 2) return null;
    final b = int.tryParse(parcalar[0]);
    final s = int.tryParse(parcalar[1]);
    if (b == null || s == null) return null;
    if (b < 0 || b > 23 || s < 0 || s > 23) return null;
    return SessizSaatler(baslangicSaat: b, bitisSaat: s);
  }
}
