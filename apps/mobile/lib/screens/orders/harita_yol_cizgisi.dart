// YOL ÇİZGİSİ KATMANI — durakları gerçek yollardan bağlayan çizgiyi sağlar (2026-09-29).
//
// VERİ sağlar, çizmez (`KuryeKatmani` deseni): durak dizisi değişince sunucudan çizgiyi ister,
// DOĞRULAR ve [YolCizgisiKatmani.builder]a verir. Harita onu kendi nesnesi olarak çizer.
//
// DOĞRULAMA ŞART: sunucu çizgiyi KENDİ bildiği koordinatlardan kurar. Telefonda henüz
// senkronlanmamış bir konum değişikliği varsa (kurye az önce "Bulunduğum Yeri Kaydet" dedi)
// çizgi eski kapıya giderdi. Yanıttaki durak koordinatları pinlerden [esikKm]'den fazla
// saparsa ya da sayı tutmazsa çizgi KULLANILMAZ — harita kuş uçuşu kesikli çizgiye düşer.
//
// Arıza SESSİZDİR: çevrimdışında, servis kapalıyken ya da oturum yokken builder'a `null` gider.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../auth/session.dart';
import '../../data/app_database.dart';
import '../../sync/rota_cizgisi_api.dart';
import 'harita_icerigi.dart';
import 'harita_sorgulari.dart';

class YolCizgisiKatmani extends StatefulWidget {
  const YolCizgisiKatmani({
    super.key,
    required this.db,
    required this.duraklar,
    required this.builder,
  });

  final AppDatabase db;

  /// Rota sırasında (haritadaki pinlerle aynı liste).
  final List<HaritaDuragi> duraklar;

  /// `yol == null`: çizgi yok (henüz gelmedi / alınamadı / doğrulanamadı).
  final Widget Function(BuildContext context, List<HaritaNoktasi>? yol) builder;

  /// Sunucunun durak koordinatı ile pin arasında izin verilen en büyük sapma.
  static const double esikKm = 0.1;

  /// Uygulama boyunca ortak bellek — harita yeniden açılınca çizgi ANINDA gelir, ağ beklemez.
  /// Anahtar durak dizisidir; sınırlı tutulur (en eski atılır).
  static final Map<String, List<HaritaNoktasi>> _bellek = {};
  static const int _bellekTavani = 20;

  /// Testler arası sızıntıyı önlemek için (ortak bellek statiktir).
  @visibleForTesting
  static void bellegiTemizle() => _bellek.clear();

  /// Dizinin kimliği: sıra + koordinat. İkisinden biri değişince çizgi yeniden istenir.
  static String anahtar(List<HaritaDuragi> duraklar) => [
        for (final d in duraklar)
          '${d.orderId}@${d.lat.toStringAsFixed(6)},${d.lng.toStringAsFixed(6)}',
      ].join('|');

  /// Sunucunun çizgiyi kurduğu duraklar pinlerle örtüşüyor mu?
  static bool ortusur(List<HaritaDuragi> duraklar, List<HaritaNoktasi> sunucu) {
    if (sunucu.length != duraklar.length) return false;
    for (var i = 0; i < duraklar.length; i++) {
      final pin = HaritaNoktasi(duraklar[i].lat, duraklar[i].lng);
      if (HaritaIcerigi.mesafeKm(pin, sunucu[i]) > esikKm) return false;
    }
    return true;
  }

  @override
  State<YolCizgisiKatmani> createState() => _YolCizgisiKatmaniState();
}

class _YolCizgisiKatmaniState extends State<YolCizgisiKatmani> {
  StreamSubscription<SyncMetaData>? _metaAbone;
  String? _token;
  String? _baseUrl;
  List<HaritaNoktasi>? _yol;

  /// Son istenen dizi — geç gelen eski bir yanıt yeni dizinin üstüne yazılmasın.
  String? _istenen;

  @override
  void initState() {
    super.initState();
    _yol = YolCizgisiKatmani._bellek[YolCizgisiKatmani.anahtar(widget.duraklar)];
    // Oturum AKIŞTAN okunur (tek atış değil): giriş sonrası ilk senkron gelmeden token yoktur.
    _metaAbone = widget.db.watchSyncState().listen((meta) {
      final token = meta.authToken, baseUrl = Session.baseUrlOf(meta);
      if (token == _token && baseUrl == _baseUrl) return;
      _token = token;
      _baseUrl = baseUrl;
      _iste();
    });
  }

  @override
  void didUpdateWidget(YolCizgisiKatmani eski) {
    super.didUpdateWidget(eski);
    final yeni = YolCizgisiKatmani.anahtar(widget.duraklar);
    if (yeni == YolCizgisiKatmani.anahtar(eski.duraklar)) return;
    // Dizi değişti: eski çizgi ARTIK YANLIŞTIR (başka sırayla gider) — hemen bırakılır.
    _yol = YolCizgisiKatmani._bellek[yeni];
    _iste();
  }

  @override
  void dispose() {
    _metaAbone?.cancel();
    super.dispose();
  }

  void _iste() {
    final duraklar = widget.duraklar;
    final anahtar = YolCizgisiKatmani.anahtar(duraklar);
    final token = _token, baseUrl = _baseUrl;
    if (duraklar.length < 2 || token == null || baseUrl == null) return;
    if (YolCizgisiKatmani._bellek.containsKey(anahtar) || _istenen == anahtar) return;
    _istenen = anahtar;
    unawaited(() async {
      final sonuc = await rotaCizgisiApiUret(baseUrl, token)
          .cizgi([for (final d in duraklar) d.orderId]);
      if (!mounted || _istenen != anahtar) return;
      _istenen = null;
      if (sonuc == null || !YolCizgisiKatmani.ortusur(duraklar, sonuc.duraklar)) return;
      if (sonuc.noktalar.length < 2) return;
      final bellek = YolCizgisiKatmani._bellek;
      if (bellek.length >= YolCizgisiKatmani._bellekTavani) bellek.remove(bellek.keys.first);
      bellek[anahtar] = sonuc.noktalar;
      setState(() => _yol = sonuc.noktalar);
    }());
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _yol);
}
