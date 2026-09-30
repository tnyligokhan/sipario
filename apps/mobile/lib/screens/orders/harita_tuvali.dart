// HARİTA TUVALİ — ekran ile harita motoru arasındaki DAR sözleşme (2026-09-28).
//
// Ekran motoru tanımaz: ona "şu içeriği çiz, şu dokunuşları bana bildir" der ve hazır olunca
// eline bir [HaritaKamerasi] geçer. Üretimde tuval Yandex MapKit'tir (`harita_yandex.dart`).
//
// DİKİŞ ([haritaTuvaliUret]): yerel harita bir platform görünümüdür ve widget testinde
// ÇİZİLEMEZ. Testler dikişi bir sahteyle değiştirir; sahte, içeriği sıradan widget'lar olarak
// çizer ve kamera komutlarını kaydeder (`test/support/sahte_harita_tuvali.dart`). Önceki karo
// dikişinin (`haritaKaroSaglayici`) yerini aldı.

import 'package:flutter/widgets.dart';

import 'harita_icerigi.dart';
import 'harita_yandex.dart';

/// Kameranın ekrana açık yüzü. Komutlar ANİMASYONLUDUR — ani sıçrama kullanıcının nerede
/// olduğunu kaybettirir.
abstract interface class HaritaKamerasi {
  /// Zoom'u [fark] kadar değiştirir (+1 yakınlaş, −1 uzaklaş).
  Future<void> yakinlastir(double fark);

  /// Kadraja sığdırır ("Duraklara sığdır").
  Future<void> kadrajla(HaritaKadraji kadraj);

  /// Noktaya [zoom] ölçeğinde gider ("Konumum").
  Future<void> odakla(HaritaNoktasi nokta, double zoom);

  /// Noktayı ekranın ÜST kısmına kaydırır: ekranın altından [ortulenOran] kadarı bir sayfayla
  /// (durak özeti) örtülecekse pin o sayfanın arkasında kalmasın. Nokta zaten görünen bölgedeyse
  /// kamera OYNAMAZ; yakınlık değişmez.
  Future<void> gorunurAlanaAl(HaritaNoktasi nokta, {required double ortulenOran});
}

/// Tuvalin bütün girdisi. Tek nesne: dikişin imzası yeni bir alan eklendiğinde değişmesin.
class HaritaTuvaliAyari {
  const HaritaTuvaliAyari({
    required this.icerik,
    required this.koyu,
    required this.onDokunus,
    required this.onHazir,
    this.kenarBoslugu = EdgeInsets.zero,
  });

  final HaritaIcerigi icerik;

  /// Koyu tema — taban haritanın stili temayı izler.
  final bool koyu;

  /// Pin dokunuşu. Taban haritanın kendi öğelerine (sokak adı vb.) dokunmak bildirilmez.
  final void Function(HaritaDokunusu dokunus) onDokunus;

  /// Kamera kullanılabilir olduğunda BİR KEZ çağrılır.
  final void Function(HaritaKamerasi kamera) onHazir;

  /// Kadraja sığdırırken haritanın üstündeki düğmelerin kapladığı alan — pinler onların
  /// altında kalmasın.
  final EdgeInsets kenarBoslugu;
}

typedef HaritaTuvaliUretici = Widget Function(HaritaTuvaliAyari ayar);

/// Tuvalin TEK dikişi. Üretimde Yandex MapKit; testler sahteyle değiştirir ve tearDown'da
/// geri alır.
HaritaTuvaliUretici haritaTuvaliUret = YandexTuvali.new;
