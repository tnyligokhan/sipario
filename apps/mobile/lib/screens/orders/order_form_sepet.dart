// YENİ SİPARİŞ FORMUNUN SEPET YÜZEYİ — ürün ekleme, adet, satır notu, satır iskontosu, müşteri fiyatı.
//
// NEDEN AYRI DOSYA: `order_form_screen.dart` satır iskontosu ve müşteriye özel fiyatla 562 satıra
// çıktı (500 satır kuralı). Ortak payda tek cümle: sepetteki satırları değiştirirler. Durum ekranda
// kalır, buradaki yöntemler onu değiştirir.
//
// NEDEN `part` ve `setState` yerine `_durumDegisti`: gerekçe `home_shell_cagri.dart` başlığında.

part of 'order_form_screen.dart';

/// Formun SEPET yüzeyi.
extension _SepetYuzeyi on _OrderFormScreenState {
  Future<void> _iskontoYetkisiniOku() async {
    final yetki = await oturumYetkileri(widget.db);
    if (mounted && yetki.iskonto != _iskontoYetkisi) {
      _durumDegisti(() => _iskontoYetkisi = yetki.iskonto);
    }
  }

  /// Seçili müşterinin özel fiyatları; müşteri yoksa boş.
  MusteriFiyatlari get _fiyatlar => MusteriFiyatlari.coz(_musteri?.productPricesJson);

  /// Sepet doluyken müşteri değiştiyse ürün satırları yeni müşterinin fiyatına geçer. Geçmeseydi
  /// önceki müşterinin özel fiyatı yeni müşterinin siparişine kalırdı.
  Future<void> _sepetFiyatlariniYenile() async {
    final idler = [for (final l in _satirlar) ?l.productId];
    if (idler.isEmpty) return;
    final urunler = await (widget.db.select(widget.db.products)
          ..where((t) => t.id.isIn(idler)))
        .get();
    if (!mounted) return;
    final katalog = {for (final u in urunler) u.id: u.unitPriceKurus};
    final fiyatlar = _fiyatlar;
    _durumDegisti(() {
      for (final l in _satirlar) {
        final id = l.productId;
        final taban = id == null ? null : katalog[id];
        if (id != null && taban != null) l.unitPriceKurus = fiyatlar.birimFiyat(id, taban);
      }
    });
  }

  void _urunEkle(Product u, int adet, SecenekSecimi secim) {
    _durumDegisti(() {
      // ⚠️ BİRLEŞTİRME SEÇİME DE BAKAR (2026-08-18). Yalnız `productId`ye bakan eski kural,
      // "1 soğanlı + 1 soğansız dürüm" isteğini "2 soğansız dürüm"e çevirirdi — müşterinin
      // siparişini sessizce değiştirmek, hiç kaydetmemekten kötüdür.
      final i = _satirlar.indexWhere((l) => l.ayniKalem(u.id, secim));
      if (i >= 0) {
        // ADET NEGATİF OLABİLİR (2026-08-22): katalog karosundaki `−` düğmesi sepeti buradan
        // azaltır. Sıfıra inen satır SİLİNİR — 0 adetli bir kalem sepette anlamsızdır ve
        // toplamı etkilemeden listeyi kirletirdi.
        _satirlar[i].qty += adet;
        if (_satirlar[i].qty <= 0) _satirlar.removeAt(i);
      } else if (adet > 0) {
        _satirlar.add(LineDraft(
          productId: u.id,
          name: u.name,
          unitPriceKurus: _fiyatlar.birimFiyat(u.id, u.unitPriceKurus),
          unit: u.unit,
          qty: adet,
          secim: secim,
        ));
      }
      _uyari = null;
    });
  }

  void _adetDegis(int i, int delta) {
    _durumDegisti(() {
      final yeni = _satirlar[i].qty + delta;
      if (yeni <= 0) {
        _satirlar.removeAt(i);
      } else {
        _satirlar[i].qty = yeni;
      }
    });
  }

  Future<void> _serbestEkle() async {
    final draft = await serbestSatirSheetAc(context);
    if (draft == null || !mounted) return;
    _durumDegisti(() {
      _satirlar.add(draft);
      _uyari = null;
    });
  }

  /// Sepetteki TEK satırın notu. Sheet `null` dönerse vazgeçilmiştir ve mevcut not DEĞİŞMEZ;
  /// boş dizgi dönerse not silinmiştir ([satirNotuSilindi]).
  Future<void> _satirNotu(int i) async {
    final satir = _satirlar[i];
    final sonuc = await satirNotuSheetAc(context, urunAd: satir.name, mevcut: satir.note);
    if (sonuc == null || !mounted) return;
    // Sheet açıkken sepet değişmiş olabilir (kullanıcı arkada bir şey silemez ama savunma ucuz):
    // satır düştüyse yazacak yer yok.
    if (i >= _satirlar.length || !identical(_satirlar[i], satir)) return;
    _durumDegisti(() => satir.note = notuNormalle(sonuc));
  }

  /// Sepetteki TEK satırın iskontosu. Sheet `null` dönerse vazgeçilmiştir.
  Future<void> _satirIskontosu(int i) async {
    final satir = _satirlar[i];
    final sonuc = await iskontoSheetAc(
      context,
      urunAd: satir.name,
      brutKurus: satir.brutKurus,
      mevcut: satir.iskonto,
    );
    if (sonuc == null || !mounted) return;
    if (i >= _satirlar.length || !identical(_satirlar[i], satir)) return;
    _durumDegisti(() => satir.iskonto = sonuc);
  }
}
