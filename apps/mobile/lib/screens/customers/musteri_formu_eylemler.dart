// MÜŞTERİ FORMUNUN İKİ YAN YÜZEYİ — SESLİ DİKTE ve KONUM.
//
// NEDEN AYRI DOSYA: `customer_form_screen.dart` 559 satıra çıkmıştı (500 satır kuralı). Bu iki
// yüzey formun alanlarını DOLDURUR ama form mantığının parçası değildir: ikisi de cihaz
// yeteneğine (mikrofon · GPS) dayanır, ikisi de izin isteyebilir, ikisi de başarısız olabilir ve
// başarısızlıkta forma dokunmadan geri döner. Doğrulama, kaydetme ve çizim ana dosyada kaldı.
//
// ⚠️ TELEFON ALANINDA DİKTE YOKTUR ve bu bilinçli: Türkçe tanıma rakamları tutarsız döndürür,
// tek hane kayması ARAYAN TANIMAYI kör eder — ürünün varlık sebebi. Gerekçenin tamamı
// `_sesleYaz` başlığında.
//
// NEDEN `part` ve `setState` yerine `_durumDegisti`: extension sınıfın kendisi değildir ve
// `setState` `@protected`tır (gerekçe `home_shell_cagri.dart` başlığında).

part of 'customer_form_screen.dart';

/// Formun DİKTE ve KONUM yüzeyi.
extension _FormEylemleri on _MusteriFormuState {
  /// Alanı sesle doldurur. Aynı mikrofona ikinci dokunuş dinlemeyi DURDURUR (kullanıcı kaydı
  /// bitirmek için beklemek zorunda kalmasın), başka alanın mikrofonu öncekini kapatır.
  ///
  /// TELEFON ALANINDA ÇAĞRILMAZ. Gerekçe: Türkçe tanıma rakamları tutarsız döndürür ("beş yüz
  /// otuz iki" / "532" / "5 32"); tek hane kayması yanlış numara kaydeder ve o numara ARAYAN
  /// TANIMAYI kör eder — ürünün varlık sebebi. Risk simetrik değil: 10 haneyi klavyeden yazmak
  /// birkaç saniye, yanlış numara ise sessizce kaybedilen bir müşteri. `normalizePhoneTR` sözel
  /// çıktının çoğunu zaten reddeder ve kullanıcı hatayı uygulamaya yazardı.
  Future<void> _sesleYaz(
    String alan,
    TextEditingController kontrol, {
    VoidCallback? degisince,
  }) async {
    if (_dinlenenAlan != null) {
      final ayniAlan = _dinlenenAlan == alan;
      // Bant durdurmadan ÖNCE söner: sürücü motorun kapanışını otomatik devamdan ayırt eder,
      // ekranın da aynı anda "artık dinlemiyoruz" demesi gerekir.
      _durumDegisti(() => _dinlenenAlan = null);
      await _dikte.durdur();
      if (!mounted) return;
      if (ayniAlan) return; // ikinci dokunuş = durdur
    }
    _durumDegisti(() {
      _dinlenenAlan = alan;
      _sesMesaji = null;
      _sesMesajAlani = null;
    });

    // Taban BOŞ verilir (kullanıcı kararı 2026-08-01): mikrofona basmak TEMİZ SAYFA açar —
    // alanda ne varsa dikte onun YERİNE geçer. Eski kural ("dolu alanın sonuna ekle") sahada
    // reddedildi: kullanıcı yanlış/yarım metni düzeltmek için mikrofona basıyor, eskisinin
    // korunmasını değil gitmesini bekliyor. Oturum İÇİNDEKİ esler yine birikir ve hiçbir şey
    // silinmez (bkz. [DikteSurucusu]) — silme yalnız DÜĞMEYE BASMA anında olur.
    await _dikte.basla(
      taban: '',
      yaz: (yeni) {
        kontrol.value = TextEditingValue(
          text: yeni,
          // İmleç SONA konur: alan çok satırlı ve dolduğunda kendi içinde kayar; imleci sonda
          // tutmak yazılanın SONUNU görünür kılar (uzun adreste asıl dert budur).
          selection: TextSelection.collapsed(offset: yeni.length),
        );
        // SipInput.onChanged YALNIZ kullanıcı yazınca tetiklenir; programatik yazımda alanın
        // yan etkilerini (hata temizleme, konum sıfırlama) elle çağırmak zorundayız.
        degisince?.call();
      },
      bitti: (gerekce) {
        if (!mounted) return;
        _durumDegisti(() {
          _dinlenenAlan = null;
          _sesMesaji = gerekce;
          _sesMesajAlani = gerekce == null ? null : alan;
        });
      },
    );
  }

  /// Adres metni değişti: alınmış konum artık o adrese ait değildir, aday listesi ve hata düşer.
  /// Hem klavye hem sesli giriş bu tek yoldan geçer (iki kopya kural ayrışırdı).
  void _adresDegisti() => _durumDegisti(() {
        _lat = null;
        _lng = null;
        _adaylar = null;
        _adresHatasi = null;
      });

  /// Adresten konum: sunucu ADAY döner, doğrusunu KULLANICI seçer (otomatik atama yok).
  ///
  /// Sonuç boşsa bu bir ARIZA DEĞİLDİR — adres metni yetersizdir ve kullanıcıya öyle söylenir.
  /// Ağ/servis arızası ise ayrı bir cümledir: ikisini "konum alınamadı" diye birleştirmek
  /// kullanıcıyı yanlış işi yapmaya (aynı adresi tekrar tekrar denemeye) iter.
  Future<void> _konumAl() async {
    if (_adres.text.trim().isEmpty) {
      _durumDegisti(() {
        _adresHatasi = 'Önce adresi yazın';
        _adaylar = null;
      });
      return;
    }
    if (_konumCalisiyor) return;

    _durumDegisti(() {
      _lat = null;
      _lng = null;
      _adresHatasi = null;
      _adaylar = null;
      _konumCalisiyor = true;
    });

    List<AdresAdayi> adaylar;
    try {
      adaylar = await adresAdaylariGetir(widget.db, _adres.text);
    } on GeocodeException catch (e) {
      if (!mounted) return;
      _durumDegisti(() {
        _konumCalisiyor = false;
        _adresHatasi = e.message;
      });
      return;
    }

    if (!mounted) return;
    _durumDegisti(() {
      _konumCalisiyor = false;
      _adaylar = adaylar;
      _adresHatasi = adaylar.isEmpty ? _MusteriFormuState._bulunamadiMesaji : null;
    });
  }

  /// Cihazın BULUNDUĞU noktayı yazar. Kayıt kapının önünde açıldığında en doğru yol budur;
  /// adresten kodlama sokağı bulur, kapıyı bulmaz.
  Future<void> _konumGuncelle() async {
    if (_konumCalisiyor) return;
    _durumDegisti(() {
      _adresHatasi = null;
      _konumCalisiyor = true;
    });

    final CihazKonumu konum;
    try {
      konum = await cihazKonumuOku();
    } on KonumHatasi catch (e) {
      if (!mounted) return;
      _durumDegisti(() {
        _konumCalisiyor = false;
        _adresHatasi = e.mesaj;
      });
      return;
    }

    if (!mounted) return;
    _durumDegisti(() {
      _konumCalisiyor = false;
      _lat = konum.lat;
      _lng = konum.lng;
      _adaylar = null;
    });
    // Zayıf ölçüm SESSİZCE kaydedilmez: kurye "konum kayıtlı" yazısına güvenir.
    if (!konum.guvenilir) {
      SipToast.goster(context, konumDogrulukUyarisi(konum.dogrulukM));
    }
  }

}
