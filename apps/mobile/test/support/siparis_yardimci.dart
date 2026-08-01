// Sipariş ekranı widget testlerinin ortak koşum yardımcıları (`ui_siparis_test.dart`).
//
// Drift + modal sheet birleşimi widget testinde iki tuzak çıkarıyor; ikisinin de çözümü burada
// tek yerde durur ki her testte yeniden keşfedilmesin.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';
import 'package:sipario/theme/app_theme.dart';

/// Dar telefon değil UZUN bir yüzey: `ListView` tembel çizer, alttaki bölümler hiç kurulmaz ve
/// `find.text` boş döner. Test yüzeyi 800×2400 olunca liste tek seferde görünür.
void genisYuzey(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Ekranı gerçek temayla sarar — `context.sip` jetonları uzantıdan gelsin.
Widget sipKabuk(Widget ekran) => MaterialApp(theme: SipTheme.acik(), home: ekran);

/// KOYU temalı kabuk — temaya bağlı davranışlar (ör. harita karo stili) ancak bununla sınanır.
Widget sipKabukKoyu(Widget ekran) => MaterialApp(theme: SipTheme.koyu(), home: ekran);

/// Drift akışları GERÇEK zamanda dolar; sahte zaman onları ilerletmez → `runAsync` ile beklenir.
/// Ardından iki pump: biri akışın verisini ağaca işler, ikincisi sheet/geçiş animasyonlarını
/// SONUNA taşır. İkincisi olmadan modal sheet hâlâ yukarı kayarken dokunma noktası ekranın
/// dışında kalır ve `tap` sessizce ıskalar. (`pumpAndSettle` KULLANILMAZ: iskelet parıltısı
/// sonsuz döngü animasyonudur, hiç oturmaz.)
Future<void> akisiBekle(WidgetTester tester, {int ms = 150}) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Testte kullanılan karo sağlayıcı: her karo için TEK saydam görsel döner, hiçbir istek atmaz.
/// `flutter_map` bu baytları kendi "yüklenemedi" yolu için de kullanıyor — geçerli bir PNG'dir.
class SahteKaroSaglayici extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

/// Harita ekranının İKİ dikişini birden sahteler: karo sağlayıcı ve cihaz konumu. Test ağa ve
/// platform kanalına ASLA çıkmaz; sızan bir sahte bir sonraki testte sessizce yanlış sonuç
/// üretir, bu yüzden ikisi de `addTearDown` ile geri alınır.
///
/// [konum] verilmezse konum ALINAMAZ sayılır: eklentisiz ortamın gerçeği budur ve haritanın
/// onsuz da çalıştığı her testte kanıtlanmış olur.
void haritaDikisleriniSahtele({CihazKonumu? konum}) {
  final eskiKaro = haritaKaroSaglayici;
  haritaKaroSaglayici = SahteKaroSaglayici.new;
  addTearDown(() => haritaKaroSaglayici = eskiKaro);

  final eskiKonum = cihazKonumuOku;
  cihazKonumuOku = konum == null
      ? (() async => throw const KonumHatasi('Konum alınamadı'))
      : (() async => konum);
  addTearDown(() => cihazKonumuOku = eskiKonum);
}

/// Ekranı söküp abone akışları kapatır. DB BİLEREK kapatılmaz: akış abonelikli drift db'sini
/// widget-test zonunda kapatmak asılı kalıyor (Dilim 1 dersi). 3 sn'lik pump toast'ın kendini
/// kapatma sayacını (2,2 sn) tüketir; yoksa test "A Timer is still pending" ile düşer.
Future<void> ekraniKapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
}
