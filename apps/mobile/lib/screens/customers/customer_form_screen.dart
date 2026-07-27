// Yeni / düzenle müşteri — CSS `.ym-*`, kaynak s-musteriler.jsx `YeniMusteri` + `MusteriDuzenle`.
// Tasarımda bu bir EKRAN DEĞİL, alttan açılan sayfadır (Sheet).
//
// Alanlar: ad · ÇOKLU telefon (en çok 3, ekle/sil) · adres + konum · bölge · not.
// Telefon E.164'e normalize edilir; aynı numara başka müşteride varsa kayıt DURDURULUR
// (arayan tanıma tek numaraya tek müşteri eşler — mükerrer kayıt sessizce kabul edilmez).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'customer_form_ops.dart';
import 'customer_location_picker.dart';
import 'customer_widgets.dart';

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
  late final TextEditingController _bolge;
  late final TextEditingController _not;

  double? _lat;
  double? _lng;
  List<AdresAdayi>? _adaylar;

  String? _adHatasi;
  String? _adresHatasi;
  final Map<int, String> _telHatalari = {};
  bool _calisiyor = false;

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
    _bolge = TextEditingController(text: widget.adres?.region ?? '');
    _not = TextEditingController(text: m?.note ?? '');
    _lat = widget.adres?.lat;
    _lng = widget.adres?.lng;
  }

  @override
  void dispose() {
    _ad.dispose();
    for (final c in _teller) {
      c.dispose();
    }
    _adres.dispose();
    _bolge.dispose();
    _not.dispose();
    super.dispose();
  }

  void _konumAl() {
    if (_adres.text.trim().isEmpty) {
      setState(() {
        _adresHatasi = 'Önce adresi yazın';
        _adaylar = null;
      });
      return;
    }
    setState(() {
      _lat = null;
      _lng = null;
      _adresHatasi = null;
      _adaylar = adresAdaylari(_adres.text, _bolge.text);
    });
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
      bolge: _bolge.text.trim().isEmpty ? null : _bolge.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipFormEtiket('Ad Soyad *', ustBosluk: SipSpace.md),
        SipInput(
          controller: _ad,
          ipucu: 'Ör. Ayşe Kaya',
          hata: _adHatasi != null,
          buyukHarfKipi: TextCapitalization.words,
          otomatikOdak: !_duzenleme,
          onChanged: (_) {
            if (_adHatasi != null) setState(() => _adHatasi = null);
          },
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
        // DÜZENLEMEDE KONUM ALMA YOK: tasarımın `MusteriDuzenle`si düz "Adres" etiketi + input
        // gösteriyor (s-musteriler.jsx:353-354). Konum, detaydaki koyu karttaki "Konum Al"
        // çipinden alınır. Yeni müşteride ise `YeniMusteri` (:272-277) çipi gösterir.
        if (_duzenleme)
          const SipFormEtiket('Adres')
        else
          _AdresEtiketSatiri(
            konumVar: _lat != null && _lng != null,
            koordinat: (_lat != null && _lng != null) ? konumMetni(_lat!, _lng!) : null,
            onKonumAl: _konumAl,
          ),
        SipInput(
          controller: _adres,
          ipucu: 'Mahalle, sokak, no',
          hata: _adresHatasi != null,
          onChanged: (_) => setState(() {
            _lat = null;
            _lng = null;
            _adaylar = null;
            _adresHatasi = null;
          }),
        ),
        if (_adresHatasi != null) SipHataSatiri(metin: _adresHatasi!),
        if (!_duzenleme && _adaylar != null && _lat == null)
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
        const SipFormEtiket('Bölge'),
        SipInput(controller: _bolge, ipucu: 'Ör. Kepez', buyukHarfKipi: TextCapitalization.words),
        const SipFormEtiket('Not'),
        SipInput(
          controller: _not,
          satirlar: 2,
          ipucu: 'Zil, kapı kodu, özel durum…',
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

/// CSS `.ym-lblrow` — "Adres" etiketi + sağda Konum Al bağlantısı / alınan konum çipi.
class _AdresEtiketSatiri extends StatelessWidget {
  const _AdresEtiketSatiri({
    required this.konumVar,
    required this.koordinat,
    required this.onKonumAl,
  });

  final bool konumVar;
  final String? koordinat;
  final VoidCallback onKonumAl;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, SipSpace.x2, 0, SipSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text('ADRES', style: SipText.formEtiket.copyWith(color: t.muted)),
          ),
          if (konumVar)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SipIcon(SipIcons.check, boyut: 12, kalinlik: 2.8, renk: t.ok),
                const SizedBox(width: 5),
                Text(
                  'Konum alındı · ${koordinat!}',
                  style: SipText.metin(11.5, w: 700).copyWith(color: t.ok),
                ),
              ],
            )
          else
            SipDokun(
              onTap: onKonumAl,
              radius: SipRadius.br1,
              padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SipIcon(SipIcons.pin, boyut: 13, kalinlik: 2.2, renk: t.accent),
                  const SizedBox(width: 5),
                  Text(
                    'Konum Al',
                    style: SipText.metin(12, w: 800).copyWith(color: t.accent),
                  ),
                ],
              ),
            ),
        ],
      ),
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
