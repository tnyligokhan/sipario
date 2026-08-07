// GİRİŞ — s-giris.jsx + Sipario.html `.giris*`.
//
// Üst yarı koyu mürekkep hero (logo + "Sipario" wordmark + slogan), alt yarı `--bg` zeminli,
// üst köşeleri r4 yuvarlak form. MAĞAZA KURALI (BRIEF — pazarlıksız): kayıt/üyelik/fiyat/satın
// alma bağlantısı YOK; ekranda yalnız giriş vardır.
//
// KİMLİK: **Firma Kodu + Kullanıcı Adı + Parola** (+ gelişmiş: sunucu adresi).
// E-posta ile giriş KALDIRILDI. Gerekçe tasarımın kendi metninde: İşletme Profili ekranı
// firma kodunu "Kullanıcılarınız bu kodla giriş yapar; değiştirilemez" diye yayınlıyor —
// hesapları patron açar, kuryenin e-postası olmayabilir.
//
// Doğrulama kuralları tasarımın `gonder()` işleviyle birebirdir; sunucu da aynılarını
// bağımsız uygular (LoginRequest), yani istemci doğrulaması atlanırsa açık oluşmaz.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_api.dart';
import '../auth/session.dart';
import '../theme/app_theme.dart';
import '../theme/components/atoms.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session, required this.onLoggedIn});

  final Session session;
  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Tasarımın (`s-giris.jsx`) alan doğrulamaları — ekrandan BAĞIMSIZ, saf testle sınanır.
/// Anahtar → hata metni; boş harita "geçerli" demektir.
Map<String, String> girisHatalari({
  required String firma,
  required String kullanici,
  required String parola,
  String sunucu = '',
  bool gelismis = false,
}) {
  final hatalar = <String, String>{};

  final f = firma.trim();
  if (f.isEmpty) {
    hatalar['firma'] = 'Firma kodu boş bırakılamaz';
  } else if (!RegExp(r'^[a-z0-9-]{3,}$', caseSensitive: false).hasMatch(f)) {
    hatalar['firma'] = 'Geçersiz firma kodu (en az 3 harf/rakam)';
  }

  final k = kullanici.trim();
  if (k.isEmpty) {
    hatalar['kullanici'] = 'Kullanıcı adı boş bırakılamaz';
  } else if (!RegExp(r'^[a-z0-9._-]{3,}$', caseSensitive: false).hasMatch(k)) {
    hatalar['kullanici'] = 'Geçersiz kullanıcı adı (en az 3 harf/rakam)';
  }

  if (parola.isEmpty) {
    hatalar['parola'] = 'Parola boş bırakılamaz';
  } else if (parola.length < 4) {
    hatalar['parola'] = 'Parola en az 4 karakter';
  }

  // Sunucu adresi yalnız "Gelişmiş" açıkken ve DOLUYKEN sınanır (boş = varsayılan adres).
  final s = sunucu.trim();
  if (gelismis && s.isNotEmpty && !RegExp(r'^[a-z0-9.:/-]+$', caseSensitive: false).hasMatch(s)) {
    hatalar['sunucu'] = 'Geçersiz sunucu adresi';
  }

  return hatalar;
}

class _LoginScreenState extends State<LoginScreen> {
  final _firma = TextEditingController();
  final _kullanici = TextEditingController();
  final _password = TextEditingController();
  final _baseUrl = TextEditingController();

  bool _busy = false;
  bool _gelismis = false;
  Map<String, String> _hata = const {};
  String? _sunucuHata;

  @override
  void initState() {
    super.initState();
    widget.session.state().then((meta) {
      if (mounted) _baseUrl.text = Session.baseUrlOf(meta);
    });
  }

  @override
  void dispose() {
    _firma.dispose();
    _kullanici.dispose();
    _password.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  /// Tasarımdaki `gonder()` — TÜM alanları birlikte doğrular, hatalı olanların altına yazar.
  bool _dogrula() {
    final hatalar = girisHatalari(
      firma: _firma.text,
      kullanici: _kullanici.text,
      parola: _password.text,
      sunucu: _baseUrl.text,
      gelismis: _gelismis,
    );
    setState(() {
      _hata = hatalar;
      _sunucuHata = null;
    });
    return hatalar.isEmpty;
  }

  /// Kullanıcı yazmaya başlayınca hata satırları kalkar (tasarımda her `onChange` hatayı siler).
  void _temizle() {
    if (_hata.isNotEmpty || _sunucuHata != null) {
      setState(() {
        _hata = const {};
        _sunucuHata = null;
      });
    }
  }

  Future<void> _gonder() async {
    if (_busy) return;
    if (!_dogrula()) return;
    setState(() => _busy = true);
    try {
      await widget.session.login(
        tenantCode: _firma.text,
        username: _kullanici.text,
        password: _password.text,
        baseUrlOverride: _baseUrl.text.trim().isEmpty ? null : _baseUrl.text,
      );
      if (mounted) widget.onLoggedIn();
    } on AuthException catch (e) {
      if (mounted) setState(() => _sunucuHata = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Üst yarı DAİMA koyu hero — durum çubuğu ikonları beyaz.
      value: SipTheme.sistemCubuklari(t).copyWith(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: t.hero,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          // Ekran boyundan kısaysa içerik alta yaslanır (CSS `.giris-marka { margin-top: auto }`),
          // uzunsa kaydırılır (CSS `.giris { overflow-y: auto }`).
          //
          // `IntrinsicHeight` + `Spacer` KULLANILMAZ: intrinsic ölçüm metni sonsuz genişlikte
          // hesapladığından sarmalanan satırları (doğrulama hataları, uzun sunucu hatası) tek
          // satır sayıyor ve kısa ekranda gövde taşıyordu. `mainAxisSize.min` + `end` aynı
          // yerleşimi ölçüm yapmadan verir: yükseklik `minHeight`e uzar, artan boşluk üste gider.
          builder: (context, kutu) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: kutu.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Marka(ustBosluk: MediaQuery.paddingOf(context).top),
                  _Form(
                    firma: _firma,
                    kullanici: _kullanici,
                    parola: _password,
                    sunucu: _baseUrl,
                    busy: _busy,
                    gelismis: _gelismis,
                    hata: _hata,
                    sunucuHata: _sunucuHata,
                    onDegis: _temizle,
                    onGelismis: () => setState(() => _gelismis = !_gelismis),
                    onGonder: _gonder,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CSS `.giris-marka` — logo + wordmark + slogan.
class _Marka extends StatelessWidget {
  const _Marka({required this.ustBosluk});

  final double ustBosluk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: EdgeInsets.fromLTRB(30, SipSpace.x6 + ustBosluk, 30, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(17),
            ),
            child: SipIcon(SipIcons.phoneCall, boyut: 26, kalinlik: 2.2, renk: t.accentInk),
          ),
          const SizedBox(height: SipSpace.x5),
          Text('Sipario', style: SipText.wordmark.copyWith(color: SipTokens.onHero)),
          const SizedBox(height: SipSpace.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Telefon çaldığında müşteriniz ekranda',
              style: SipText.slogan.copyWith(color: SipTokens.onHeroMid),
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.giris-form` — üst köşeleri r4 yuvarlak, `--bg` zeminli form bloğu.
class _Form extends StatelessWidget {
  const _Form({
    required this.firma,
    required this.kullanici,
    required this.parola,
    required this.sunucu,
    required this.busy,
    required this.gelismis,
    required this.hata,
    required this.sunucuHata,
    required this.onDegis,
    required this.onGelismis,
    required this.onGonder,
  });

  final TextEditingController firma;
  final TextEditingController kullanici;
  final TextEditingController parola;
  final TextEditingController sunucu;
  final bool busy;
  final bool gelismis;

  /// Alan anahtarı → hata metni ('firma' | 'kullanici' | 'parola' | 'sunucu').
  final Map<String, String> hata;

  /// Sunucudan dönen nötr hata (401/403/429) — forma değil, düğmenin üstüne yazılır.
  final String? sunucuHata;

  final VoidCallback onDegis;
  final VoidCallback onGelismis;
  final VoidCallback onGonder;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(SipRadius.r4),
          topRight: Radius.circular(SipRadius.r4),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        SipSpace.x6,
        32,
        SipSpace.x6,
        40 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SipFormEtiket('Firma Kodu', ustBosluk: 0),
          SipInput(
            controller: firma,
            ipucu: 'ornek: merkezbayi',
            aktif: !busy,
            hata: hata.containsKey('firma'),
            buyukHarfKipi: TextCapitalization.none,
            onChanged: (_) => onDegis(),
          ),
          if (hata['firma'] != null) _Hata(hata['firma']!),
          const SipFormEtiket('Kullanıcı Adı'),
          SipInput(
            controller: kullanici,
            ipucu: 'ornek: mehmet.usta',
            aktif: !busy,
            hata: hata.containsKey('kullanici'),
            buyukHarfKipi: TextCapitalization.none,
            onChanged: (_) => onDegis(),
          ),
          if (hata['kullanici'] != null) _Hata(hata['kullanici']!),
          const SipFormEtiket('Parola'),
          SipInput(
            controller: parola,
            ipucu: '••••••••',
            gizli: true,
            aktif: !busy,
            hata: hata.containsKey('parola'),
            buyukHarfKipi: TextCapitalization.none,
            onChanged: (_) => onDegis(),
            onSubmitted: (_) => onGonder(),
          ),
          if (hata['parola'] != null) _Hata(hata['parola']!),
          if (gelismis) ...[
            const SipFormEtiket('Sunucu adresi'),
            SipInput(
              controller: sunucu,
              ipucu: 'https://sipario.com.tr/api/v1',
              klavye: TextInputType.url,
              aktif: !busy,
              hata: hata.containsKey('sunucu'),
              buyukHarfKipi: TextCapitalization.none,
              onChanged: (_) => onDegis(),
            ),
            if (hata['sunucu'] != null) _Hata(hata['sunucu']!),
          ],
          if (sunucuHata != null) _Hata(sunucuHata!),
          // CSS `.giris-gelismis` — sola dayalı düz metin bağlantısı.
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onGelismis,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, SipSpace.x3, SipSpace.md, 2),
                child: Text(
                  gelismis ? '− Gelişmiş' : '+ Gelişmiş (sunucu adresi)',
                  style: SipText.link.copyWith(color: t.accent),
                ),
              ),
            ),
          ),
          const SizedBox(height: SipSpace.x5),
          SipButon(etiket: 'Giriş Yap', onTap: onGonder, yukleniyor: busy),
          const SizedBox(height: SipSpace.x4),
          Text(
            'Firma kodunuzu ve hesabınızı işletme yöneticiniz oluşturur.',
            textAlign: TextAlign.center,
            style: SipText.girisAlt.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}

/// CSS `.ym-err` — alan altındaki kırmızı hata satırı.
class _Hata extends StatelessWidget {
  const _Hata(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SipIcon(SipIcons.alert, boyut: 13, kalinlik: 2.2, renk: t.danger),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(12, w: 700).copyWith(color: t.danger),
            ),
          ),
        ],
      ),
    );
  }
}
