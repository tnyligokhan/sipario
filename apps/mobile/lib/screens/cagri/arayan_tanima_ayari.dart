// ARAYAN TANIMA AÇMA/KAPAMA — Ayarlar'daki anahtar (kullanıcı isteği 2026-07-30).
//
// NEDEN DÜZ DOSYA (tema tercihiyle birebir aynı desen — `lib/theme/tema_deposu.dart`):
// kartı telefon çalarken Kotlin çizer ve o anda Flutter motoru HİÇ BAŞLAMAZ; tercih ancak
// iki tarafın da okuyabildiği bir yerde durabilir. Native okuyucu `ArayanAyari.kt` AYNI
// dosyaya bakar — dosya adı iki tarafta elle senkron tutulur.
//
// NEDEN CİHAZ-YEREL (kiracı ayarı değil): "bu telefonda kart çıkmasın" bir CİHAZ tercihidir —
// patron kendi telefonunda kapatıp kuryede açık bırakabilmeli. Sipariş kodu tercihinin
// (`siparis_kodu_ayari.dart`) aksine bayinin iş sözlüğü değil, tek telefonun davranışıdır.
//
// VARSAYILAN AÇIK: dosya yoksa/okunamazsa kart gösterilir. Arayan tanıma ürünün kendisi;
// bir okuma arızası onu sessizce kapatamaz (native taraftaki duruşun aynısı).

import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../isletme/isletme_atomlari.dart';

/// Tercihin saklandığı dosyanın adı (içerik: `acik` | `kapali`). `ArayanAyari.DOSYA` aynası.
const String kArayanDosyaAdi = 'sipario_arayan.txt';

/// Arayan tanıma tercihini okuyup yazan minik depo (`TemaDeposu` kalıbı).
class ArayanTanimaDeposu {
  /// Cihazdaki gerçek depo.
  ArayanTanimaDeposu() : _dizin = getDatabasesPath;

  /// Test/geçici kip — disk yok, değer bellekte durur.
  ArayanTanimaDeposu.bellek() : _dizin = null;

  final Future<String> Function()? _dizin;
  bool? _bellek;

  Future<File?> _dosya() async {
    final dizin = _dizin;
    if (dizin == null) return null;
    try {
      return File(p.join(await dizin(), kArayanDosyaAdi));
    } on Object {
      return null; // platform kanalı yok (test) ya da dizin çözülemedi
    }
  }

  /// Kayıtlı tercih; hiç yazılmamışsa AÇIK (`true`).
  Future<bool> acikMi() async {
    if (_bellek != null) return _bellek!;
    final f = await _dosya();
    if (f == null) return true;
    try {
      if (!await f.exists()) return true;
      // Tanınmayan içerik AÇIK sayılır — native okuyucuyla aynı kural.
      return (await f.readAsString()).trim() != 'kapali';
    } on Object catch (e) {
      debugPrint('Arayan tercihi okunamadı: $e');
      return true;
    }
  }

  /// Tercihi kalıcılar. Yazılamazsa oturum içinde yine de geçerli kalır (bellek yedeği).
  Future<void> yaz(bool acik) async {
    _bellek = acik;
    final f = await _dosya();
    if (f == null) return;
    try {
      await f.writeAsString(acik ? 'acik' : 'kapali', flush: true);
    } on Object catch (e) {
      debugPrint('Arayan tercihi yazılamadı: $e');
    }
  }
}

/// Ayar satırının okuduğu TEK depo — dikiş. Widget testleri bunu `.bellek()` ile değiştirir
/// ve `addTearDown` ile geri alır (`konumApiUret` deseninin aynısı). Ekranın kendi içinde
/// depo kurmasına İZİN YOK: kill-switch widget'ın içine gömülürse test edilemez olur
/// (bu depoda kanıtlanmış ders — güncelleme bandı vakası).
ArayanTanimaDeposu arayanTanimaDeposu = ArayanTanimaDeposu();

/// Ayarlar → Arayan Tanıma kartındaki AÇ/KAPA satırı.
class ArayanTanimaSatiri extends StatefulWidget {
  const ArayanTanimaSatiri({super.key});

  @override
  State<ArayanTanimaSatiri> createState() => _ArayanTanimaSatiriState();
}

class _ArayanTanimaSatiriState extends State<ArayanTanimaSatiri> {
  /// null → tercih henüz okunmadı; anahtar varsayılan (AÇIK) çizilir ki satır zıplamasın.
  bool? _acik;

  @override
  void initState() {
    super.initState();
    // Depo cihaz-yerel bir dosyadır, sunucu sahipli alan DEĞİLDİR — tek atış okuma burada
    // doğrudur (akış kuralı sync_meta gibi senkronla değişen alanlar içindir). Bu satır
    // dosyanın tek yazarı olduğundan bayat kalma yolu yok.
    unawaited(_yukle());
  }

  Future<void> _yukle() async {
    final acik = await arayanTanimaDeposu.acikMi();
    if (mounted) setState(() => _acik = acik);
  }

  Future<void> _cevir() async {
    final yeni = !(_acik ?? true);
    setState(() => _acik = yeni);
    await arayanTanimaDeposu.yaz(yeni);
  }

  @override
  Widget build(BuildContext context) {
    final acik = _acik ?? true;
    return AyarSatiri(
      ikon: SipIcons.phone,
      baslik: 'Arayan tanıma',
      // Alt başlık SEÇİLİ durumu yazar (sipariş kodu satırındaki kural): kapatan bayi
      // "kart neden çıkmıyor" diye aramadan önce cevabı burada görmeli.
      altBaslik: acik
          ? 'Telefon çalarken müşteri kartı gösterilir'
          : 'Kapalı — çağrıda kart gösterilmez',
      onTap: _cevir,
      sag: SipKnob(acik: acik),
    );
  }
}
