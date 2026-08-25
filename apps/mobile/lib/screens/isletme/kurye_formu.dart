// KURYE DÜZENLEME SHEET'İ — ad · telefon · aktiflik · giriş bilgileri (kullanıcı adı/parola).
//
// NEDEN AYRI DOSYA: `kuryeler_ekrani.dart` 754 satıra çıkmıştı (500 satır kuralı). Form kendi
// başına bir bütündür: alan doğrulaması, kullanıcı adı çakışma kontrolü ve parola kuralı burada
// yaşar; ekran yalnız sonucu (`KuryeGirdisi`) alır ve kaydeder.
//
// ⚠️ SÖZLEŞME DEĞİŞMEDİ: dışarıya açılan tek kapı yine `kuryeFormuAc` ve döndürdüğü
// `KuryeGirdisi`dir; formun kendisi (`_KuryeFormu`) bu dosyada ÖZEL kalır.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'isletme_atomlari.dart';
import 'kuryeler_ekrani.dart' show kuryeAktifMi;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Düzenleme sheet'i — CSS `.sb-form`
// ═══════════════════════════════════════════════════════════════════════════════════════════

@immutable
class KuryeGirdisi {
  const KuryeGirdisi({
    required this.ad,
    required this.telefon,
    required this.aktif,
    required this.kullaniciAdi,
    this.parola,
  });

  final String ad;
  final String? telefon;
  final bool aktif;
  final String kullaniciAdi;
  final String? parola;
}

Future<KuryeGirdisi?> kuryeFormuAc(
  BuildContext context, {
  required User kurye,
  required List<User> tumKuryeler,
}) {
  return sipSheet<KuryeGirdisi>(
    context,
    baslik: 'Kuryeyi Düzenle',
    govde: (ctx) => _KuryeFormu(kurye: kurye, tumKuryeler: tumKuryeler),
  );
}

class _KuryeFormu extends StatefulWidget {
  const _KuryeFormu({required this.kurye, required this.tumKuryeler});

  final User kurye;
  final List<User> tumKuryeler;

  @override
  State<_KuryeFormu> createState() => _KuryeFormuState();
}

class _KuryeFormuState extends State<_KuryeFormu> {
  late final TextEditingController _ad = TextEditingController(text: widget.kurye.name);
  late final TextEditingController _telefon =
      TextEditingController(text: widget.kurye.phone ?? '');

  late final TextEditingController _kullaniciAdi =
      TextEditingController(text: widget.kurye.username);

  final TextEditingController _parola = TextEditingController();

  late bool _aktif = kuryeAktifMi(widget.kurye);

  Map<String, String> _hata = const {};

  @override
  void dispose() {
    _ad.dispose();
    _telefon.dispose();
    _kullaniciAdi.dispose();
    _parola.dispose();
    super.dispose();
  }

  void _temizle() {
    if (_hata.isNotEmpty) setState(() => _hata = const {});
  }

  void _kaydet() {
    final hatalar = kuryeFormHatalari(
      ad: _ad.text,
      telefon: _telefon.text,
      aktif: _aktif,
      duzenlenenId: widget.kurye.id,
      tumKuryeler: widget.tumKuryeler,
      kullaniciAdi: _kullaniciAdi.text,
      parola: _parola.text,
    );
    if (hatalar.isNotEmpty) {
      setState(() => _hata = hatalar);
      return;
    }
    final tel = _telefon.text.trim();
    final parola = _parola.text;
    Navigator.of(context).pop(KuryeGirdisi(
      ad: _ad.text.trim(),
      telefon: tel.isEmpty ? null : tel,
      aktif: _aktif,
      kullaniciAdi: _kullaniciAdi.text.trim().toLowerCase(),
      parola: parola.isEmpty ? null : parola,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipFormEtiket('AD', ustBosluk: 2),
        SipInput(
          controller: _ad,
          ipucu: 'Ör. Emre',
          hata: _hata.containsKey('ad'),
          otomatikOdak: true,
          onChanged: (_) => _temizle(),
        ),
        if (_hata['ad'] != null) AlanNotu(_hata['ad']!),

        const SipFormEtiket('TELEFON'),
        SipInput(
          controller: _telefon,
          ipucu: '05XX XXX XX XX',
          klavye: TextInputType.phone,
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]'))],
          stil: SipText.tutar(15, w: 500),
          hata: _hata.containsKey('telefon'),
          onChanged: (_) => _temizle(),
        ),
        if (_hata['telefon'] != null) AlanNotu(_hata['telefon']!),

        AktifToggle(
          acik: _aktif,
          etiket: _aktif ? 'Aktif, sipariş atanabilir' : 'Pasif, sipariş atanamaz',
          onDegis: (v) => setState(() {
            _aktif = v;
            _hata = const {};
          }),
        ),
        if (_hata['aktif'] != null) AlanNotu(_hata['aktif']!),

        // ── GİRİŞ BİLGİLERİ ───────────────────────────────────────────────
        const SipBolumBaslik('Giriş Bilgileri', ustBosluk: 20),
        const SipFormEtiket('KULLANICI ADI', ustBosluk: 2),
        SipInput(
          controller: _kullaniciAdi,
          ipucu: 'Ör. emre',
          hata: _hata.containsKey('kullaniciAdi'),
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]'))],
          onChanged: (_) => _temizle(),
        ),
        if (_hata['kullaniciAdi'] != null) AlanNotu(_hata['kullaniciAdi']!),

        const SipFormEtiket('YENİ PAROLA'),
        SipInput(
          controller: _parola,
          ipucu: 'Değiştirmeyecekseniz boş bırakın',
          hata: _hata.containsKey('parola'),
          onChanged: (_) => _temizle(),
        ),
        if (_hata['parola'] != null)
          AlanNotu(_hata['parola']!)
        else
          const AlanNotu(
            'Parolayı değiştirirseniz kuryenin açık oturumu kapanır. Bu işlem internet ister.',
            tur: AlanNotuTuru.bilgi,
          ),

        const SizedBox(height: SipSpace.x3),
        SipButon(etiket: 'Kaydet', onTap: _kaydet),
      ],
    );
  }
}

/// Kurye formu doğrulaması — saf test edilebilir.
Map<String, String> kuryeFormHatalari({
  required String ad,
  required String telefon,
  required bool aktif,
  required String duzenlenenId,
  required List<User> tumKuryeler,
  String? kullaniciAdi,
  String? parola,
}) {
  final hatalar = <String, String>{};
  final temizAd = ad.trim();
  final digerleri = tumKuryeler.where((k) => k.id != duzenlenenId);

  if (temizAd.length < 2) {
    hatalar['ad'] = 'Kurye adı girin (en az 2 karakter)';
  } else if (digerleri.any((k) => trKucuk(k.name) == trKucuk(temizAd))) {
    hatalar['ad'] = 'Bu adla kayıtlı kurye zaten var';
  }

  final haneler = telefon.replaceAll(RegExp(r'\D'), '');
  if (telefon.trim().isNotEmpty && (haneler.length < 10 || haneler.length > 11)) {
    hatalar['telefon'] = 'Geçerli telefon girin (10-11 hane) ya da boş bırakın';
  }

  if (!aktif && !digerleri.any(kuryeAktifMi)) {
    hatalar['aktif'] = 'Son aktif kurye pasif yapılamaz, sipariş atanacak kimse kalmaz';
  }

  if (kullaniciAdi != null && kullaniciAdi.trim().isNotEmpty) {
    final k = kullaniciAdi.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._-]{3,60}$').hasMatch(k)) {
      hatalar['kullaniciAdi'] =
          'Kullanıcı adı en az 3 karakter; harf, rakam, nokta, tire ve alt çizgi kullanılabilir';
    }
  }

  if (parola != null && parola.isNotEmpty && parola.length < 4) {
    hatalar['parola'] = 'Parola en az 4 karakter olmalı';
  }

  return hatalar;
}
