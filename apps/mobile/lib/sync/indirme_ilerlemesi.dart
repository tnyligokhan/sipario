// VERİ İNDİRME İLERLEMESİ — ilk senkronun (snapshot) "ne kadar kaldı" bilgisi.
//
// NEDEN VAR (kullanıcı isteği 2026-09-26): "Tüm verileri çekme kısmında verileri çekerken ne
// kadar kaldığını gösteren bir şey olmalı." 9.047 müşterili bir bayide "Verileri baştan indir"
// dakikalar sürüyor ve ekran bu süre boyunca hiçbir şey söylemiyordu; bayi işlemin takıldığını
// sanıp uygulamayı kapatıyordu — yarım kalan indirme de baştan başlıyordu.
//
// NEDEN MODÜL DÜZEYİNDE TEK ÖRNEK: ilerlemeyi senkron motoru üretir, ayarlar ekranı okur ve
// ikisi arasında hiçbir nesne yolu yoktur (ekranın elinde yalnız `db` var). `yenileme.dart`taki
// servis bağlamasının ve `guncellemeServisi`nin aynı deseni.
//
// TOPLAM YAKLAŞIKTIR: sunucu onu ilk sayfada sayar; sayfalar inerken başka bir cihaz kayıt
// ekleyebilir. Bu yüzden oran 1'de kırpılır ve tamamlanma kararını sayı değil sunucunun
// `has_more` alanı verir. Toplamı göndermeyen eski sunucuda yalnız inen sayı gösterilir.

import 'package:flutter/foundation.dart';

class IndirmeIlerlemesi extends ChangeNotifier {
  bool _suruyor = false;
  int _inen = 0;
  int? _toplam;

  /// Bir snapshot turu şu an iniyor mu?
  bool get suruyor => _suruyor;

  /// Bu turda uygulanan satır sayısı.
  int get inen => _inen;

  /// Sunucunun bildirdiği toplam; eski sunucuda null.
  int? get toplam => _toplam;

  /// 0..1 arası oran; toplam bilinmiyorsa null (belirsiz çubuk çizilir).
  double? get oran {
    final t = _toplam;
    if (t == null || t <= 0) return null;
    return (_inen / t).clamp(0.0, 1.0);
  }

  /// Snapshot'ın ilk sayfası geldi.
  void basla(int? toplam) {
    _suruyor = true;
    _inen = 0;
    _toplam = toplam;
    notifyListeners();
  }

  /// Bir sayfa uygulandı.
  void sayfaIslendi(int adet) {
    if (!_suruyor) return;
    _inen += adet;
    notifyListeners();
  }

  /// Tur bitti — başarıyla ya da yarıda (sonucu çağıran ayrıca bilir).
  void bitti() {
    if (!_suruyor) return;
    _suruyor = false;
    notifyListeners();
  }
}

/// Uygulamanın tek ilerleme durumu.
final indirmeIlerlemesi = IndirmeIlerlemesi();
