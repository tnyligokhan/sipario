// HARİTA STİLİ — OpenFreeMap vektör stili: indir, diskte sakla, Türkçeleştir, yedekle (2026-09-28).
//
// NEDEN OPENFREEMAP: ticari kullanıma açık, anahtar/kayıt/kota yok; Positron (açık) ve Dark
// (koyu) stilleri önceki CARTO görünümünün vektör karşılığıdır. Karo trafiği sunucumuza uğramaz.
//
// NEDEN STİLİ KENDİMİZ GETİRİYORUZ (motora adres vermek yerine): MapLibre stil dosyasını
// indiremezse HİÇBİR ŞEY çizmez — pinler dahil. Çevrimdışı ilk açılışta harita tamamen boş
// kalırdı; bu projenin sözü "zemin kaybolur, pinler durur"dur. Sıra şöyle:
//   1. Bellekte varsa o.
//   2. Diskte varsa HEMEN o (açılış ağ beklemez), günden eskiyse arkada tazelenir.
//   3. Yoksa ağdan (kısa zaman aşımıyla) indirilir ve diske yazılır.
//   4. O da olmazsa YEDEK: yalnız zemin rengi olan boş stil. Pinler yine çizilir.
//
// İndirilen metin DOĞRULANIR: otel/kafe Wi-Fi'ının giriş sayfası 200 ile HTML döndürür; onu stil
// diye diske yazmak haritayı ağ düzelene dek kırardı.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

/// Stil kaynağının sabitleri ve saf dönüşümleri.
abstract final class HaritaStili {
  static const String _kok = 'https://tiles.openfreemap.org';

  /// Açık tema Positron, koyu tema Dark.
  static String ad({required bool koyu}) => koyu ? 'dark' : 'positron';

  static String adres({required bool koyu}) => '$_kok/styles/${ad(koyu: koyu)}';

  /// Pin numaraları ve adlar için yazı tipi — OpenFreeMap'in glif sunucusunda bulunur.
  static const List<String> yaziTipi = ['Noto Sans Bold'];

  /// Atıf — HUKUKİ ZORUNLULUK (OpenFreeMap şartı + OSM ODbL). Metin SÖZLEŞMEDİR.
  static const String atif = '© OpenFreeMap © OpenMapTiles © OpenStreetMap';

  /// Uzak stilin zemin renkleri — yedek stil aynısını kullanır ki ağ gelince renk sıçramasın.
  static const String _acikZemin = 'rgb(242,243,240)';
  static const String _koyuZemin = 'rgb(12,12,12)';

  /// Metin geçerli bir MapLibre stili mi? (sürüm 8, katman listesi var)
  static bool gecerliMi(String metin) {
    try {
      final j = jsonDecode(metin);
      return j is Map && j['version'] == 8 && j['layers'] is List && j['sources'] is Map;
    } on Object {
      return false;
    }
  }

  /// Yer adlarını TÜRKÇE önceliğe çevirir ve büyük harf dönüşümünü kaldırır. Uzak stil `name:latin`/`name_en` gösterir: ülkeler
  /// "Ελλάδα Greece" diye çıkıyordu. Yeni sıra `name:tr` → `name:latin` → `name`; Türkiye içinde
  /// üçü zaten aynıdır, fark sınır ötesinde ve deniz adlarında görünür. Yol numarası kalkanları
  /// (`ref`) adı değil numarayı gösterir — onlara dokunulmaz.
  static String uyarla(String hamJson) {
    final stil = jsonDecode(hamJson) as Map<String, dynamic>;
    for (final katman in (stil['layers'] as List).whereType<Map<String, dynamic>>()) {
      final yerlesim = katman['layout'];
      if (yerlesim is! Map<String, dynamic>) continue;
      // BÜYÜK HARF DÖNÜŞÜMÜ KALKAR: motor Türkçe İ/ı kuralını bilmez ve koyu stil "Çeltikköy"ü
      // "ÇELTIKKÖY", "Yiğitali"yi "YIĞITALI" yazıyordu (emülatörde görüldü). Ad, verideki
      // doğal yazımıyla gösterilir — açık stilde olduğu gibi.
      if (yerlesim['text-transform'] == 'uppercase') yerlesim.remove('text-transform');
      final alan = yerlesim['text-field'];
      if (alan == null) continue;
      final metin = jsonEncode(alan);
      if (metin.contains('name:latin') || metin.contains('name_en')) {
        yerlesim['text-field'] = const [
          'coalesce',
          ['get', 'name:tr'],
          ['get', 'name:latin'],
          ['get', 'name'],
        ];
      }
    }
    return jsonEncode(stil);
  }

  /// Ağ da disk de yokken kullanılan boş stil — yalnız zemin. Glif adresi DURUR: yazı tipi
  /// önbellekteyse pin numaraları yine yazılır.
  static String yedek({required bool koyu}) => jsonEncode({
        'version': 8,
        'name': 'sipario-yedek',
        'glyphs': '$_kok/fonts/{fontstack}/{range}.pbf',
        'sources': <String, dynamic>{},
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': koyu ? _koyuZemin : _acikZemin},
          },
        ],
      });
}

/// Stilin kalıcı deposu. Durum (bellek, dizin, istemci) ve davranış (getir, tazele) tek nesnede.
class HaritaStilDeposu {
  HaritaStilDeposu({
    http.Client? istemci,
    Future<String> Function()? dizin,
    this.zamanAsimi = const Duration(seconds: 6),
    this.tazelikSuresi = const Duration(days: 1),
  })  : _istemci = istemci ?? http.Client(),
        _dizin = dizin ?? getDatabasesPath;

  /// Uygulama boyunca tek depo — iki harita açılışı stili iki kez indirmesin.
  static final HaritaStilDeposu varsayilan = HaritaStilDeposu();

  final http.Client _istemci;
  final Future<String> Function() _dizin;
  final Duration zamanAsimi;
  final Duration tazelikSuresi;

  /// Ham (uyarlanmamış) stil metinleri, stil adına göre.
  final Map<String, String> _bellek = {};

  /// Aynı stil için yolda olan indirme — eşzamanlı ikinci istek onu bekler.
  final Map<String, Future<String?>> _yolda = {};

  /// Motora verilecek stil metni. ASLA hata fırlatmaz: en kötü ihtimalle yedek stil döner.
  Future<String> getir({required bool koyu}) async {
    final ad = HaritaStili.ad(koyu: koyu);
    final bellekte = _bellek[ad];
    if (bellekte != null) return HaritaStili.uyarla(bellekte);

    final disk = await _diskten(ad);
    if (disk != null) {
      _bellek[ad] = disk.metin;
      if (disk.bayat) unawaited(_indir(ad, koyu: koyu));
      return HaritaStili.uyarla(disk.metin);
    }

    final ag = await _indir(ad, koyu: koyu);
    return ag != null ? HaritaStili.uyarla(ag) : HaritaStili.yedek(koyu: koyu);
  }

  Future<File?> _dosya(String ad) async {
    try {
      return File(p.join(await _dizin(), 'harita_stili_$ad.json'));
    } on Object {
      return null; // platform kanalı yok (test) ya da dizin çözülemedi
    }
  }

  Future<({String metin, bool bayat})?> _diskten(String ad) async {
    final f = await _dosya(ad);
    if (f == null) return null;
    try {
      if (!await f.exists()) return null;
      final metin = await f.readAsString();
      if (!HaritaStili.gecerliMi(metin)) return null;
      final yas = DateTime.now().difference(await f.lastModified());
      return (metin: metin, bayat: yas > tazelikSuresi);
    } on Object catch (e) {
      debugPrint('Harita stili diskten okunamadı: $e');
      return null;
    }
  }

  /// ⚠️ Temizlik bloğu GÖVDELİ yazılır: `whenComplete(() => _yolda.remove(ad))` silinen Future'ı
  /// yani KENDİSİNİ döndürür, `whenComplete` onu bekler ve Future kendi kendini bekleyerek
  /// sonsuza dek asılı kalır (harita hiç açılmazdı — `harita_stili_test.dart` yakaladı).
  Future<String?> _indir(String ad, {required bool koyu}) =>
      _yolda[ad] ??= _indirBir(ad, koyu: koyu).whenComplete(() {
        _yolda.remove(ad);
      });

  Future<String?> _indirBir(String ad, {required bool koyu}) async {
    try {
      final yanit =
          await _istemci.get(Uri.parse(HaritaStili.adres(koyu: koyu))).timeout(zamanAsimi);
      if (yanit.statusCode != 200) return null;
      final metin = utf8.decode(yanit.bodyBytes);
      if (!HaritaStili.gecerliMi(metin)) return null;
      _bellek[ad] = metin;
      final f = await _dosya(ad);
      if (f != null) {
        try {
          await f.writeAsString(metin, flush: true);
        } on Object catch (e) {
          debugPrint('Harita stili diske yazılamadı: $e');
        }
      }
      return metin;
    } on Object catch (e) {
      debugPrint('Harita stili indirilemedi: $e');
      return null;
    }
  }
}
