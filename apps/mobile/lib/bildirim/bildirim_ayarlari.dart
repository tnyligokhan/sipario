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

  /// Push kaydının son durumu — SAHA TEŞHİSİ İÇİN (2026-08-14).
  ///
  /// NEDEN VAR: "bildirim gelmiyor" şikâyeti geldiğinde hiçbir tarafta bakılacak veri yoktu.
  /// Sunucu "gönderecek cihaz bulamadım" diyordu ama telefonun jetonu neden göndermediği
  /// (Play Services yok mu, izin mi yok, ağ mı yoktu) hiçbir yerde durmuyordu. Bu değer
  /// Ayarlar → Bildirimler ekranında gösterilir; bayi tek bakışta söyleyebilir.
  ///
  /// Şema alanı DEĞİL, bu dosyada duruyor: cihaz-yerel bir tanı bilgisi için migration
  /// açmak, bu deponun `tutamac_deposu`/`tema_deposu` deseninin kırılması olurdu.
  String _pushDurumu = '';

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
          case 'push':
            _pushDurumu = deger;
          // `borcEsigi` anahtarı 2026-08-14'te KALDIRILDI. Eski dosyalarda satır DURUYOR
          // olabilir; tanınmayan anahtar zaten sessizce atlanır (switch'in default'u yok) ve
          // ilk yazımda dosya baştan kurulduğu için kendiliğinden temizlenir.
        }
      }
    } on Object catch (e) {
      debugPrint('Bildirim ayarları okunamadı: $e');
    }
  }

  /// Kategori açık mı? Varsayılan AÇIK — bayi kapatmadıysa bildirim gelir.
  ///
  /// (Borç eşiği kategorisinin "eşik girilmeden pasif" istisnası 2026-08-14'te kategoriyle
  /// birlikte kaldırıldı; artık istisna yok.)
  bool kategoriAcik(BildirimKategori k) => !_kapaliWire.contains(k.wire);

  SessizSaatler get sessizSaatler => _sessiz;

  /// Push kaydının son durumu; hiç denenmediyse `null`.
  PushDurumu? get pushDurumu => PushDurumu.wiredan(_pushDurumu);

  /// Push kurulumunun her adımı bunu günceller. HATA YUTAR (depo geneli kural): tanı
  /// bilgisinin yazılamaması, push'un kendisini düşürmemeli.
  Future<void> pushDurumuYaz(PushDurumu durum) async {
    if (_pushDurumu == durum.wire) return; // gereksiz disk yazımı yok
    _pushDurumu = durum.wire;
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
          'push=$_pushDurumu',
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
