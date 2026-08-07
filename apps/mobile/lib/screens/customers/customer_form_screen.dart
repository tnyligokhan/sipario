// Yeni / düzenle müşteri — CSS `.ym-*`, kaynak s-musteriler.jsx `YeniMusteri` + `MusteriDuzenle`.
// Tasarımda bu bir EKRAN DEĞİL, alttan açılan sayfadır (Sheet).
//
// Alanlar: ad · ÇOKLU telefon (en çok 3, ekle/sil) · adres + konum · bölge · not.
// Telefon E.164'e normalize edilir; aynı numara başka müşteride varsa kayıt DURDURULUR
// (arayan tanıma tek numaraya tek müşteri eşler — mükerrer kayıt sessizce kabul edilmez).
//
// SESLİ GİRİŞ (bayi isteği): ad · adres · bölge · not alanlarının yanında mikrofon var.
// TELEFONDA MİKROFON YOK — gerekçe `_sesleYaz` üstünde.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../konum/cihaz_konumu.dart';
import '../../sync/geocode_api.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'customer_form_ops.dart';
import 'customer_location_picker.dart';
import 'customer_widgets.dart';
import 'sesli_giris.dart';

/// Yeni müşteri sheet'i. [onTel] gelen çağrıdan geliyorsa ilk telefon alanı onunla açılır.
/// `true` dönerse kayıt yapıldı.
Future<bool?> musteriEkleSheet(BuildContext context, {required AppDatabase db, String? onTel}) {
  return sipSheet<bool>(
    context,
    baslik: 'Yeni Müşteri',
    govde: (ctx) => _MusteriFormu(db: db, onTel: onTel),
  );
}

/// Mevcut müşteriyi düzenleme sheet'i.
Future<bool?> musteriDuzenleSheet(
  BuildContext context, {
  required AppDatabase db,
  required Customer musteri,
  required List<CustomerPhone> telefonlar,
  CustomerAddressesData? adres,
}) {
  return sipSheet<bool>(
    context,
    baslik: 'Müşteriyi Düzenle',
    govde: (ctx) => _MusteriFormu(
      db: db,
      musteri: musteri,
      telefonlar: telefonlar,
      adres: adres,
    ),
  );
}

class _MusteriFormu extends StatefulWidget {
  const _MusteriFormu({
    required this.db,
    this.musteri,
    this.telefonlar = const [],
    this.adres,
    this.onTel,
  });

  final AppDatabase db;
  final Customer? musteri;
  final List<CustomerPhone> telefonlar;
  final CustomerAddressesData? adres;
  final String? onTel;

  @override
  State<_MusteriFormu> createState() => _MusteriFormuState();
}

class _MusteriFormuState extends State<_MusteriFormu> {
  static const int _enFazlaTelefon = 3;

  late final TextEditingController _ad;
  late final List<TextEditingController> _teller;
  late final TextEditingController _adres;
  late final TextEditingController _not;

  double? _lat;
  double? _lng;
  List<AdresAdayi>? _adaylar;

  /// Adres araması ya da cihaz konumu okuması sürüyor. Aynı anda tek iş; ikinci dokunuş yutulur
  /// (iki paralel arama kotayı iki kez yakar ve hangi sonucun geldiği belirsizleşir).
  bool _konumCalisiyor = false;

  static const String _bulunamadiMesaji = konumBulunamadiMesaji;

  String? _adHatasi;
  String? _adresHatasi;
  final Map<int, String> _telHatalari = {};
  bool _calisiyor = false;

  // ── Sesli giriş ────────────────────────────────────────────────────────────────────────
  late final SesliGiris _ses = sesliGirisUret();

  /// Motor oturumlarını, metin birikimini ve otomatik devamı yürütür — ekran yalnız HANGİ alanın
  /// dinlendiğini bilir.
  late final DikteSurucusu _dikte = DikteSurucusu(ses: _ses, canli: () => mounted);

  /// O an dinlenen alanın adı (aynı anda TEK alan dinlenir); null = dinleme yok.
  String? _dinlenenAlan;

  /// Son ses gerekçesi ve hangi alanın altında gösterileceği.
  String? _sesMesaji;
  String? _sesMesajAlani;

  bool get _duzenleme => widget.musteri != null;

  @override
  void initState() {
    super.initState();
    final m = widget.musteri;
    _ad = TextEditingController(text: m?.name ?? '');
    _teller = [
      if (widget.telefonlar.isEmpty)
        TextEditingController(text: widget.onTel == null ? '' : sipTelefon(widget.onTel!))
      else
        for (final p in widget.telefonlar.take(_enFazlaTelefon))
          TextEditingController(text: sipTelefon(p.phoneE164)),
    ];
    _adres = TextEditingController(text: widget.adres?.addressText ?? '');
    _not = TextEditingController(text: m?.note ?? '');
    _lat = widget.adres?.lat;
    _lng = widget.adres?.lng;
  }

  @override
  void dispose() {
    // Sheet kapanırken mikrofon AÇIK KALMAZ — sahipsiz bir kayıt oturumu bırakmak hem pil
    // hem güven meselesi.
    _ses.birak();
    _ad.dispose();
    for (final c in _teller) {
      c.dispose();
    }
    _adres.dispose();
    _not.dispose();
    super.dispose();
  }

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
      setState(() => _dinlenenAlan = null);
      await _dikte.durdur();
      if (!mounted) return;
      if (ayniAlan) return; // ikinci dokunuş = durdur
    }
    setState(() {
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
        setState(() {
          _dinlenenAlan = null;
          _sesMesaji = gerekce;
          _sesMesajAlani = gerekce == null ? null : alan;
        });
      },
    );
  }

  /// Adres metni değişti: alınmış konum artık o adrese ait değildir, aday listesi ve hata düşer.
  /// Hem klavye hem sesli giriş bu tek yoldan geçer (iki kopya kural ayrışırdı).
  void _adresDegisti() => setState(() {
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
      setState(() {
        _adresHatasi = 'Önce adresi yazın';
        _adaylar = null;
      });
      return;
    }
    if (_konumCalisiyor) return;

    setState(() {
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
      setState(() {
        _konumCalisiyor = false;
        _adresHatasi = e.message;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _konumCalisiyor = false;
      _adaylar = adaylar;
      _adresHatasi = adaylar.isEmpty ? _bulunamadiMesaji : null;
    });
  }

  /// Cihazın BULUNDUĞU noktayı yazar. Kayıt kapının önünde açıldığında en doğru yol budur;
  /// adresten kodlama sokağı bulur, kapıyı bulmaz.
  Future<void> _konumGuncelle() async {
    if (_konumCalisiyor) return;
    setState(() {
      _adresHatasi = null;
      _konumCalisiyor = true;
    });

    final CihazKonumu konum;
    try {
      konum = await cihazKonumuOku();
    } on KonumHatasi catch (e) {
      if (!mounted) return;
      setState(() {
        _konumCalisiyor = false;
        _adresHatasi = e.mesaj;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
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

  Future<void> _kaydet() async {
    final ad = _ad.text.trim();
    _telHatalari.clear();
    var adHatasi = ad.length < 2 ? 'Ad soyad girin' : null;

    // Telefonlar: ilki ZORUNLU, ek alanlar dolu ise geçerli olmalı (sessizce atılmaz).
    final numaralar = <String>[];
    for (var i = 0; i < _teller.length; i++) {
      final ham = _teller[i].text.trim();
      if (i > 0 && ham.isEmpty) continue;
      final e164 = normalizePhoneTR(ham);
      if (e164 == null) {
        _telHatalari[i] = i == 0
            ? 'Geçerli telefon girin (10-11 hane)'
            : 'Geçerli telefon girin ya da boş bırakın';
        continue;
      }
      // Aynı numarayı iki alana yazmak HATA DEĞİL: tasarım yalnız KAYITLI müşterilerde arar
      // (s-musteriler.jsx:241-245). Mükerrer alan sessizce tekilleşir.
      if (!numaralar.contains(e164)) numaralar.add(e164);
    }
    if (numaralar.isEmpty && !_telHatalari.containsKey(0)) {
      _telHatalari[0] = 'Geçerli telefon girin (10-11 hane)';
    }

    if (adHatasi == null && _telHatalari.isEmpty) {
      final sahip = await mukerrerTelefonSahibi(widget.db, numaralar.first,
          haricCustomerId: widget.musteri?.id);
      if (sahip != null) _telHatalari[0] = 'Bu numara zaten kayıtlı: $sahip';
    }

    if (adHatasi != null || _telHatalari.isNotEmpty) {
      setState(() => _adHatasi = adHatasi);
      return;
    }

    setState(() => _calisiyor = true);
    final veri = MusteriFormVerisi(
      ad: ad,
      telefonlar: numaralar,
      adres: _adres.text.trim().isEmpty ? null : _adres.text.trim(),
      not: _not.text.trim().isEmpty ? null : _not.text.trim(),
      lat: _lat,
      lng: _lng,
    );
    if (_duzenleme) {
      await musteriGuncelle(widget.db,
          customerId: widget.musteri!.id,
          v: veri,
          eskiTelefonlar: widget.telefonlar,
          eskiAdres: widget.adres);
    } else {
      await musteriOlustur(widget.db, veri);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Alan + yanında mikrofon + altında dinleme/gerekçe satırı. Mikrofon HER ZAMAN çizilir;
  /// izin yoksa ya da cihazda Türkçe tanıma yoksa soluk görünür ve dokunuş nedenini söyler.
  Widget _sesliAlan({
    required String ad,
    required TextEditingController kontrol,
    required Widget alan,
    VoidCallback? degisince,
    bool ustHizala = false,
  }) {
    final t = context.sip;
    final dinliyor = _dinlenenAlan == ad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SesliAlanSatiri(
          alan: alan,
          ustHizala: ustHizala,
          mikrofon: SesliGirisDugmesi(
            dinliyor: dinliyor,
            kapali: _ses.durum == SesDurumu.kapali,
            alanAdi: ad,
            onTap: () => _sesleYaz(ad, kontrol, degisince: degisince),
          ),
        ),
        if (dinliyor)
          SipHataSatiri(metin: 'Dinleniyor… konuşun', renk: t.accent, ikon: SipIcons.info),
        if (_sesMesajAlani == ad && _sesMesaji != null)
          SipHataSatiri(metin: _sesMesaji!, renk: t.warn, ikon: SipIcons.info),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipFormEtiket('Ad Soyad *', ustBosluk: SipSpace.md),
        _sesliAlan(
          ad: 'Ad Soyad',
          kontrol: _ad,
          degisince: () {
            if (_adHatasi != null) setState(() => _adHatasi = null);
          },
          alan: SipInput(
            controller: _ad,
            ipucu: 'Ör. Ayşe Kaya',
            hata: _adHatasi != null,
            buyukHarfKipi: TextCapitalization.words,
            otomatikOdak: !_duzenleme,
            onChanged: (_) {
              if (_adHatasi != null) setState(() => _adHatasi = null);
            },
          ),
        ),
        if (_adHatasi != null) SipHataSatiri(metin: _adHatasi!),
        for (var i = 0; i < _teller.length; i++) ...[
          SipFormEtiket(i == 0 ? 'Telefon *' : 'Telefon ${i + 1}'),
          Row(
            children: [
              Expanded(
                child: SipInput(
                  controller: _teller[i],
                  klavye: TextInputType.phone,
                  ipucu: '05XX XXX XX XX',
                  stil: SipText.tutar(15, w: 400),
                  hata: _telHatalari.containsKey(i),
                  onChanged: (_) {
                    if (_telHatalari.remove(i) != null) setState(() {});
                  },
                ),
              ),
              if (i > 0) ...[
                const SizedBox(width: SipSpace.md),
                SipIkonButon(
                  ikon: SipIcons.x,
                  cap: 40,
                  ikonBoyut: 17,
                  kalinlik: 2.2,
                  zemin: t.surface2,
                  renk: t.muted,
                  etiket: 'Telefonu sil',
                  onTap: () => setState(() {
                    _teller.removeAt(i).dispose();
                    _telHatalari.clear();
                  }),
                ),
              ],
            ],
          ),
          if (_telHatalari.containsKey(i)) SipHataSatiri(metin: _telHatalari[i]!),
        ],
        if (_teller.length < _enFazlaTelefon)
          Align(
            alignment: Alignment.centerLeft,
            child: SipDokun(
              onTap: () => setState(() => _teller.add(TextEditingController())),
              padding: const EdgeInsets.only(top: SipSpace.lg, bottom: 2, right: SipSpace.md),
              radius: SipRadius.br1,
              child: Text(
                '+ Telefon ekle (${_teller.length}/$_enFazlaTelefon)',
                style: SipText.link.copyWith(color: t.accent),
              ),
            ),
          ),
        // DÜZENLEMEDE DE KONUM ALINIR (kullanıcı isteği 2026-07-29: "müşteri bilgisi
        // düzenlerken konum aldır çıkmıyor").
        //
        // ÖNCESİ: düzenleme kipi düz bir "Adres" etiketine düşüyordu — tasarımın
        // `MusteriDuzenle`si öyle çiziyordu (s-musteriler.jsx:353-354) ve konumun tek yolu
        // müşteri DETAYINDAKİ koyu karttı. Sahada bu tutmadı: adres yanlışsa bayi zaten
        // düzenleme ekranını açıyor, adresi düzeltiyor ve konumu TAM ORADA almak istiyor;
        // kaydedip detaya dönüp ikinci bir ekrandan almak fazladan üç dokunuş ve akış kesintisi.
        // Tasarım dosyası ölçü/renk çatışmalarında bağlayıcıdır; bu bir ÜRÜN kararıdır ve
        // sahibi kullanıcıdır.
        AdresEtiketSatiri(
          konumVar: _lat != null && _lng != null,
          koordinat: (_lat != null && _lng != null) ? konumMetni(_lat!, _lng!) : null,
          onKonumAl: _konumAl,
          calisiyor: _konumCalisiyor,
          // Konum alındıktan sonra çipe dokunmak CİHAZ konumuyla günceller: kayıt çoğu zaman
          // müşterinin kapısında açılır ve oradaki ölçüm adresten türetilenden iyidir.
          onKonumGuncelle: _konumGuncelle,
        ),
        _sesliAlan(
          ad: 'Adres',
          kontrol: _adres,
          degisince: _adresDegisti,
          // ÇOK SATIRLI (2026-07-31 saha şikâyeti: "adres kaydı esnasında sesli yazdırırken
          // uzun adresin sonu gözükmüyor"). Tek satırlık kutuda mahalle-sokak-no-tarif yan yana
          // akıyor ve kullanıcı SÖYLEDİĞİNİN doğru yazıldığını göremiyordu; göremediğini de
          // düzeltemiyordu. Üç satır tipik bir adresi bütün olarak gösterir, taşan kısımda ise
          // imleç sonda tutulduğu için kutu kendi içinde sona kayar.
          ustHizala: true,
          alan: SipInput(
            controller: _adres,
            satirlar: 3,
            ipucu: 'Mahalle, sokak, no',
            hata: _adresHatasi != null,
            onChanged: (_) => _adresDegisti(),
          ),
        ),
        if (_adresHatasi != null) SipHataSatiri(metin: _adresHatasi!),
        // Aday listesi DÜZENLEMEDE de çizilir — düğme açıldığı hâlde liste kapalı kalsaydı
        // "Konum Al" sunucuya gider, adayları alır ve HİÇBİR ŞEY göstermezdi (bu depoda dört
        // kez ödenen "kopmuş son halka" arızası: hata yok, sonuç da yok).
        if (_adaylar != null && _lat == null)
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdayBilgi(
                    metin: 'API sonuçları — adres bazen yanlış algılanır, doğrusunu seçin.'),
                for (final a in _adaylar!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SipSpace.sm),
                    child: AdaySatiri(
                      aday: a,
                      onSec: () => setState(() {
                        _lat = a.lat;
                        _lng = a.lng;
                        _adaylar = null;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        // BÖLGE ALANI KALDIRILDI (kullanıcı kararı 2026-07-28: "gerek yok, tamamen kaldır").
        // Semt/ilçe zaten adres metninin içine yazılıyordu; iki alan aynı bilgiyi iki kez
        // soruyor ve esnafın en yavaş adımını (yazmak) uzatıyordu.
        const SipFormEtiket('Not'),
        _sesliAlan(
          ad: 'Not',
          kontrol: _not,
          // Çok satırlı kutu büyüdükçe mikrofon ortada asılı kalmasın.
          ustHizala: true,
          alan: SipInput(
            controller: _not,
            satirlar: 2,
            ipucu: 'Zil, kapı kodu, özel durum…',
          ),
        ),
        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: _duzenleme ? 'Değişiklikleri Kaydet' : 'Müşteriyi Kaydet',
          yukleniyor: _calisiyor,
          onTap: _kaydet,
        ),
      ],
    );
  }
}

/// TR telefonunu E.164'e çevirir; geçersizse null. Kabul edilen yazımlar:
/// 05321112233 / 5321112233 / +905321112233 / 90 532 111 22 33 (boşluk-tire önemsiz).
String? normalizePhoneTR(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  String ten;
  if (digits.length == 10) {
    ten = digits; // 5321112233
  } else if (digits.length == 11 && digits.startsWith('0')) {
    ten = digits.substring(1); // 05321112233
  } else if (digits.length == 12 && digits.startsWith('90')) {
    ten = digits.substring(2); // 905321112233
  } else {
    return null;
  }
  // Mobil ve sabit hatlar: TR'de ulusal numara 10 hane ve 0 ile başlamaz.
  if (ten.startsWith('0')) return null;
  return '+90$ten';
}
