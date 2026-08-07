// Sipario tasarım sistemi — TİPOGRAFİ.
// tasarım Sipario.html içindeki sınıfların birebir karşılığı. CSS'te `em` cinsinden
// verilen letter-spacing değerleri burada punto ile çarpılıp piksele çevrilir (Flutter px ister).
//
// İKİ AİLE:
//   • Sora (`--font-d`)           → başlıklar ve RAKAMLAR. Sıkı, geometrik, iri.
//   • Hanken Grotesk (`--font-b`) → gövde metni. Nötr, yüksek okunurluk.
// İkisi de DEĞİŞKEN (variable) font: ağırlık `fontVariations` ile `wght` ekseninden verilir;
// `fontWeight` yedek eşleme içindir (yalnız biri verilirse Android'de kalınlık kayar).
//
// STİLLER RENKSİZDİR: renk `DefaultTextStyle`tan miras alınır (ThemeData gövdeyi `ink` yapar,
// hero blokları kendi içinde beyaza çevirir). Böylece aynı stil açık temada, koyu temada ve
// hero üstünde doğru çalışır. Rakam taşıyan her stil TABULAR — defterde kuruş hizası için.



import 'package:flutter/material.dart';

import 'tokens.dart';

FontWeight _fw(int w) => switch (w) {
      400 => FontWeight.w400,
      500 => FontWeight.w500,
      600 => FontWeight.w600,
      700 => FontWeight.w700,
      800 => FontWeight.w800,
      _ => FontWeight.w400,
    };

/// Başlık/rakam ailesi (Sora). [ls] CSS'teki `em` değeridir; punto ile çarpılır.
TextStyle _d(double size, int w, {double? ls, double? h, bool tnum = false}) =>
    TextStyle(
      fontFamily: sipFontDisplay,
      fontSize: size,
      fontWeight: _fw(w),
      fontVariations: [FontVariation('wght', w.toDouble())],
      letterSpacing: ls == null ? null : size * ls,
      height: h,
      fontFeatures: tnum ? const [FontFeature.tabularFigures()] : null,
    );

/// Gövde ailesi (Hanken Grotesk).
TextStyle _b(double size, int w, {double? ls, double? h, bool tnum = false}) =>
    TextStyle(
      fontFamily: sipFontBody,
      fontSize: size,
      fontWeight: _fw(w),
      fontVariations: [FontVariation('wght', w.toDouble())],
      letterSpacing: ls == null ? null : size * ls,
      height: h,
      fontFeatures: tnum ? const [FontFeature.tabularFigures()] : null,
    );

abstract final class SipText {
  // ══ Ana ekran hero (CSS .ana-*) ═════════════════════════════════════════════════════════
  /// Selamlama satırı — hero üstünde soluk.
  static final TextStyle selam = _b(13, 500);

  /// İşletme adı — hero'nun ana başlığı.
  static final TextStyle isletme = _d(24, 700, ls: -0.02);

  /// Senkron durum çipi.
  static final TextStyle syncCip = _b(11.5, 600);

  // ══ Bento kutuları (CSS .bento-*) ═══════════════════════════════════════════════════════
  static final TextStyle bentoEtiket = _b(12, 600, h: 1.25);
  static final TextStyle bentoDeger = _d(40, 800, ls: -0.03, h: 1, tnum: true);
  static final TextStyle bentoDegerKucuk = _d(19, 700, tnum: true);
  static final TextStyle bentoAlt = _b(11, 500);

  /// Ana ekran birincil eylem düğmesi (CSS .ana-cta-t).
  static final TextStyle anaCta = _b(15.5, 700);

  // ══ Üst başlık — iç sayfalar (CSS .ust-*) ═══════════════════════════════════════════════
  static final TextStyle ustBaslik = _d(19, 700, ls: -0.02, h: 1.1);
  static final TextStyle ustAlt = _b(11.5, 500);

  /// Üst çubuktaki metin düğmesi ("Kaydet", "Düzenle").
  static final TextStyle ustMetin = _b(12.5, 700);

  // ══ Bölüm başlığı (CSS .ana-baslik / .md-baslik / .gs-baslik / .sdx-sec) ════════════════
  static final TextStyle bolumBaslik = _d(14.5, 700, ls: -0.01);

  /// Form alanı etiketi — BÜYÜK HARF yazılır (CSS .s-flabel).
  static final TextStyle formEtiket = _b(11, 700, ls: 0.07);

  /// Çekmece bölüm etiketi — BÜYÜK HARF yazılır (CSS .cek-sec).
  static final TextStyle cekmeceBolum = _b(10, 800, ls: 0.14);

  // ══ Liste satırları ═════════════════════════════════════════════════════════════════════
  /// Müşteri adı (CSS .mrow-nm).
  static final TextStyle satirAd = _b(14.5, 700, ls: -0.01);

  /// Sipariş satırındaki müşteri adı (CSS .srow-nm).
  static final TextStyle satirAdSip = _b(14, 700, ls: -0.01);

  static final TextStyle satirTel = _b(12.5, 500);
  static final TextStyle satirAdres = _b(12.5, 700, h: 1.4);

  /// Satır içi tutar (CSS .mrow-amt / .srow-amt).
  static final TextStyle satirTutar = _d(12.5, 700, tnum: true);
  static final TextStyle satirTutarBuyuk = _d(14, 700, tnum: true);

  /// Sipariş kodu rozeti (CSS .srow-kod).
  static final TextStyle siparisKod = _d(11, 700, tnum: true);

  /// Saat / zaman damgası (CSS .srow-saat).
  static final TextStyle saat = _b(11.5, 600);

  /// Avatar baş harfleri (CSS .mrow-av).
  static final TextStyle avatar = _d(13, 700);

  /// Sipariş satırındaki ürün dökümü (CSS .srow-urunler).
  static final TextStyle urunDokum = _b(12.5, 500);

  /// Ürün dökümü başlığı — BÜYÜK HARF (CSS .srow-uhead).
  static final TextStyle urunDokumBaslik = _b(10.5, 800, ls: 0.07);

  // ══ Rozet ve çipler ═════════════════════════════════════════════════════════════════════
  /// Durum pili (CSS .pill).
  static final TextStyle pil = _b(11, 700);

  /// Küçük "PASİF" rozeti — BÜYÜK HARF (CSS .urow-pasif).
  static final TextStyle rozetKucuk = _b(9, 700, ls: 0.05);

  /// Ödeme tipi rozeti — BÜYÜK HARF (CSS .dhar-odeme).
  static final TextStyle rozetOdeme = _b(9.5, 700, ls: 0.05);

  /// Kurye atama çipi (CSS .srow-kurye).
  static final TextStyle kuryeCip = _b(11, 700);

  // ══ Müşteri detay bakiye kartı (CSS .md-bal-*) ══════════════════════════════════════════
  static final TextStyle bakiyeEtiket = _b(11, 600, ls: 0.08);
  static final TextStyle bakiyeDeger = _d(34, 800, ls: -0.03, tnum: true);
  static final TextStyle bakiyeDurum = _b(11.5, 700, ls: 0.07);

  // ══ Tutar hiyerarşisi (rakamlar DAİMA Sora + tabular) ═══════════════════════════════════
  /// Sipariş detay toplamı (CSS .sd-toplam b).
  static final TextStyle tutar19 = _d(19, 800, ls: -0.01, tnum: true);

  /// Kasa devri satırı (CSS .kd-row b).
  static final TextStyle tutar20 = _d(20, 800, ls: -0.02, tnum: true);

  /// Yeni sipariş alt çubuğu toplamı (CSS .ys-toplam b).
  static final TextStyle tutar21 = _d(21, 800, ls: -0.02, tnum: true);

  /// Teslim & ödeme sheet'i tutarı (CSS .teslim-tut b).
  static final TextStyle tutar22 = _d(22, 800, ls: -0.02, tnum: true);

  /// Stepper adedi (CSS .pos-stepper > span).
  static final TextStyle adet24 = _d(24, 800, tnum: true);

  // ══ Düğmeler ve girdiler ════════════════════════════════════════════════════════════════
  static final TextStyle buton = _b(14.5, 700);
  static final TextStyle butonKucuk = _b(13, 700);
  static final TextStyle input = _b(15, 400);

  /// CSS `.s-textarea` — line-height VERİLMEZ (`normal`), fontun doğal metriği geçerlidir.
  static final TextStyle textarea = _b(14, 400);

  /// CSS `.arama input` — 14,5 px; `.s-input`in 15 px'inden kasten farklı.
  static final TextStyle aramaInput = _b(14.5, 400);

  /// Metin bağlantısı (CSS .sdx-link / .ym-telekle / .md-duzelt-link).
  static final TextStyle link = _b(12.5, 700);

  // ══ Sheet · diyalog · toast ═════════════════════════════════════════════════════════════
  static final TextStyle sheetBaslik = _d(15.5, 700, ls: -0.01);
  static final TextStyle diyalogBaslik = _d(16, 700, ls: -0.01);
  static final TextStyle diyalogMesaj = _b(13, 400, h: 1.5);
  static final TextStyle toast = _b(13, 600);

  // ══ Boş durum (CSS .bos-*) ══════════════════════════════════════════════════════════════
  static final TextStyle bosBaslik = _d(16.5, 700, ls: -0.01);
  static final TextStyle bosAciklama = _b(13, 400, h: 1.5);

  // ══ Çağrı kartı (CSS .cagri-*) ══════════════════════════════════════════════════════════
  static final TextStyle cagriCanli = _b(11, 700, ls: 0.12);
  static final TextStyle cagriAd = _d(20, 800, ls: -0.02);
  static final TextStyle cagriNumara = _b(12.5, 500, tnum: true);
  static final TextStyle cagriBakiyeEtiket = _b(11.5, 700, ls: 0.06);
  static final TextStyle cagriBakiyeDeger = _d(20, 800, ls: -0.01, tnum: true);
  static final TextStyle cagriBilgi = _b(12.5, 600, h: 1.45);

  // ══ Giriş (CSS .giris-*) ════════════════════════════════════════════════════════════════
  static final TextStyle wordmark = _d(32, 800, ls: -0.03);
  static final TextStyle slogan = _b(14, 400, h: 1.5);
  static final TextStyle girisAlt = _b(12, 400);

  // ══ Sihirbaz (CSS .siz-*, .izb-*) ═══════════════════════════════════════════════════════
  static final TextStyle sihirbazBaslik = _d(22, 800, ls: -0.02, h: 1.15);
  static final TextStyle sihirbazMetin = _b(13.5, 400, h: 1.55);
  static final TextStyle izinAd = _d(18, 700, ls: -0.01);
  static final TextStyle izinZorunlu = _b(10, 700, ls: 0.06);
  static final TextStyle izinDurum = _b(12.5, 700);

  // ══ Abonelik kilidi (CSS .kilit-*) ══════════════════════════════════════════════════════
  static final TextStyle kilitBaslik = _d(18, 700);
  static final TextStyle kilitMetin = _b(13, 400, h: 1.55);

  // ══ Çekmece (CSS .cek-*, .lst-*) ════════════════════════════════════════════════════════
  static final TextStyle cekmeceIsletme = _d(15.5, 700, ls: -0.01);
  static final TextStyle cekmeceRol = _b(11.5, 500);
  static final TextStyle cekmeceSatir = _b(13.5, 600);
  static final TextStyle istatDeger = _d(19, 700, tnum: true);
  static final TextStyle istatEtiket = _b(10.5, 500, h: 1.35);
  static final TextStyle istatPil = _b(9, 800, ls: 0.06);

  // ══ Gün sonu (CSS .gs-*) ════════════════════════════════════════════════════════════════
  static final TextStyle gsSatirEtiket = _b(13, 600);
  static final TextStyle gsSatirDeger = _d(13.5, 700, tnum: true);
  static final TextStyle gsToplamDeger = _d(15.5, 700, tnum: true);

  // ══ Genel gövde ═════════════════════════════════════════════════════════════════════════
  /// Standart gövde metni.
  static final TextStyle govde = _b(13, 400, h: 1.5);

  /// Vurgulu gövde (kart başlığı gibi).
  static final TextStyle govdeKalin = _b(13.5, 700);

  /// Sönük yardımcı metin.
  static final TextStyle yardimci = _b(11.5, 500);

  /// Not kutusu içeriği (CSS .md-not / .srow-not).
  static final TextStyle not = _b(12.5, 500, h: 1.45);

  /// Serbest punto tutar — rakam ailesi + tabular.
  static TextStyle tutar(double size, {int w = 700}) => _d(size, w, tnum: true);

  /// Serbest punto gövde metni.
  static TextStyle metin(double size, {int w = 400, double? h}) =>
      _b(size, w, h: h);
}
