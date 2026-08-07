// KURULUM SİHİRBAZI — s-sihirbaz.jsx + Sipario.html `.siz-*`, `.izb-*`.
//
// Akış: karşılama → her izin AYRI ADIM → deneme çağrısı. Üstte ilerleme çubuğu.
//
// İZİNLER GERÇEKTEN İSTENİR: mevcut `sipario/phase0` MethodChannel'ı kullanılır (yeni kanal
// uydurulmadı) — `status`, `request*`, `openBatterySettings`, `simulateCall`. Eski
// `phase0/setup_wizard.dart` yerinde bırakıldı (ölçüm ekranından hâlâ açılıyor); bu ekran onun
// tasarıma taşınmış hâlidir.
//
// Adım listesi SABİTTİR (`izin_adimlari.dart`): cihaza göre uzayıp kısalmaz, yoksa karşılamadaki
// "N izin isteyeceğiz" ve "Adım k/N" numaraları telefondan telefona kayıyor.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'izin_adimlari.dart';
import 'sihirbaz_parcalari.dart';

/// Faz 0'dan beri kullanılan platform kanalı (MainActivity.kt `channelName`).
const MethodChannel kPhase0Kanali = MethodChannel('sipario/phase0');
class IzinSihirbazi extends StatefulWidget {
  const IzinSihirbazi({
    super.key,
    this.channel = kPhase0Kanali,
    this.onBitti,
    this.onKapat,
  });

  final MethodChannel channel;

  /// Sihirbaz tamamlandığında. Verilmezse rota kapatılır.
  final VoidCallback? onBitti;

  /// Karşılama ekranındaki çarpı. Verilmezse rota kapatılır.
  final VoidCallback? onKapat;

  @override
  State<IzinSihirbazi> createState() => _IzinSihirbaziState();
}

enum _Test { bekliyor, calisiyor, basari, hata }

class _IzinSihirbaziState extends State<IzinSihirbazi> with WidgetsBindingObserver {
  /// 0 karşılama · 1..N izinler · N+1 deneme çağrısı
  int _adim = 0;
  Map<String, dynamic> _status = const {};

  /// Durumu koddan OKUNAMAYAN adımlar (pil muafiyeti): ayar ekranı açıldıktan sonra adım
  /// "verildi" sayılır — tasarımın `ver()` davranışı.
  final Map<String, String> _elle = {};
  final Set<String> _atlanan = {};
  _Test _test = _Test.bekliyor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tazele();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// İzin ekranından dönüldüğünde durumu tazele — verilen izin kendiliğinden "verildi" görünsün.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tazele();
  }

  /// Cihaza özgü EKRAN VARLIĞI (ör. `hasAutostartSettings`). İzin durumu değil, "bu telefonda
  /// böyle bir ayar ekranı var mı" sorusudur; bir kez sorulur ve düğme buna göre çizilir.
  final Map<String, bool> _ekranVar = {};

  Future<void> _ekranlariSorgula() async {
    for (final anahtar in {
      for (final iz in _izinler)
        if (iz.ikincilVarlikAnahtari != null) iz.ikincilVarlikAnahtari!,
    }) {
      try {
        final v = await widget.channel.invokeMethod<bool>(anahtar);
        if (!mounted) return;
        setState(() => _ekranVar[anahtar] = v ?? false);
      } on PlatformException {
        // Eski APK / bilinmeyen metot: düğme çizilmez (var saymaktansa yok saymak güvenli).
      } on MissingPluginException {
        // Kanal yok (test/masaüstü) — aynı gerekçe.
      }
    }
  }

  Future<void> _tazele() async {
    try {
      final s = await widget.channel.invokeMapMethod<String, dynamic>('status') ?? {};
      if (!mounted) return;
      setState(() => _status = s);
      await _ekranlariSorgula();
    } on PlatformException {
      // Kanal yoksa (masaüstü/test) sihirbaz yine gezilebilir; izinler "verilmemiş" görünür.
    } on MissingPluginException {
      // aynı gerekçe
    }
  }

  List<IzinAdimi> get _izinler => izinAdimlari;

  bool _verildi(IzinAdimi iz) => iz.durumAnahtari != null
      ? _status[iz.durumAnahtari] == true
      : _elle[iz.anahtar] == 'verildi';

  bool _atlandi(IzinAdimi iz) => !_verildi(iz) && _atlanan.contains(iz.anahtar);

  int get _testAdimi => _izinler.length + 1;

  double get _oran => _adim / _testAdimi;

  void _ilerle() {
    if (_adim < _testAdimi) setState(() => _adim++);
  }

  void _geri() {
    if (_adim > 0) setState(() => _adim--);
  }

  /// Adımın İKİNCİ ayar ekranını açar (ör. otomatik başlatma).
  ///
  /// Adımı "verildi" SAYMAZ: birincil eylem zaten o işi yapıyor ve iki düğmeden herhangi birine
  /// dokunmayı "tamam" saymak, kullanıcının yalnız birini yaptığı durumu gizlerdi. Buradaki
  /// dokunuş bir ayar ekranı açar, o kadar.
  Future<void> _ikincilAyar(IzinAdimi iz) async {
    final eylem = iz.ikincilEylem;
    if (eylem == null) return;
    try {
      await widget.channel.invokeMethod(eylem);
    } on PlatformException catch (e) {
      if (mounted) SipToast.goster(context, 'Ayar ekranı açılamadı (${e.code})');
    } on MissingPluginException {
      // Kanal yok (test/masaüstü) — akış durmasın.
    }
  }

  /// Bu adımın ikinci düğmesi ÇİZİLECEK Mİ? Hem tanımlı olmalı hem de cihazda o ekran bulunmalı.
  bool _ikincilGorunur(IzinAdimi iz) =>
      iz.ikincilEylem != null &&
      (iz.ikincilVarlikAnahtari == null || _ekranVar[iz.ikincilVarlikAnahtari!] == true);

  Future<void> _izinIste(IzinAdimi iz) async {
    try {
      await widget.channel.invokeMethod(iz.eylem);
    } on PlatformException catch (e) {
      if (mounted) SipToast.goster(context, 'Ayar ekranı açılamadı (${e.code})');
      return;
    } on MissingPluginException {
      // Kanal yok (test/masaüstü) — akış durmasın.
    }
    // Durumu okunamayan adım (pil): sistem ayarı açıldı, sonucu koddan göremiyoruz — tasarımın
    // `ver()` davranışı gibi verildi sayılır. Kullanıcı yapmadıysa "Atla" ile geri dönebilir.
    if (iz.durumAnahtari == null) {
      setState(() => _elle[iz.anahtar] = 'verildi');
    }
    await _tazele();
    if (!mounted) return;
    if (_verildi(iz)) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (mounted) _ilerle();
    }
  }

  void _atla(IzinAdimi iz) {
    setState(() => _atlanan.add(iz.anahtar));
    _ilerle();
  }

  void _bitir() {
    if (widget.onBitti != null) {
      widget.onBitti!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _kapat() {
    if (widget.onKapat != null) {
      widget.onKapat!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _denemeCagrisi() async {
    setState(() => _test = _Test.calisiyor);
    try {
      await widget.channel.invokeMethod('simulateCall', {'phone': ''});
    } on PlatformException {
      // yut — sonuç zorunlu izinlerin durumundan belirlenir
    } on MissingPluginException {
      // aynı gerekçe
    }
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final cekirdekTamam = _izinler.where((i) => i.zorunlu).every(_verildi);
    setState(() => _test = cekirdekTamam ? _Test.basari : _Test.hata);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SipTheme.sistemCubuklari(t),
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          bottom: false,
          child: switch (_adim) {
            0 => _karsilama(),
            _ when _adim >= _testAdimi => _deneme(),
            _ => _izinAdimi(_izinler[_adim - 1]),
          },
        ),
      ),
    );
  }

  // ── Karşılama ──────────────────────────────────────────────────────────────────────────────
  Widget _karsilama() {
    final t = context.sip;
    final n = _izinler.length;
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: _Ortala(
                children: [
                  const SihirbazLogo(ikon: SipIcons.phoneCall),
                  const SihirbazBaslik('Telefon çaldığında\nmüşteriniz ekranda'),
                  SihirbazMetin(
                    'Bunun çalışması için telefonunuzdan $n izin isteyeceğiz. Her adımı tek '
                    'tek, ne işe yaradığını açıklayarak göstereceğiz.',
                  ),
                  SihirbazRozet(
                    etiket: 'İzinler yalnız arayanı tanımak için kullanılır.',
                    renk: t.ok,
                    zemin: t.okSoft,
                    ikon: SipIcons.lock,
                    ustBosluk: 18,
                  ),
                ],
              ),
            ),
            _Alt(children: [SipButon(etiket: 'Kuruluma Başla', onTap: _ilerle)]),
          ],
        ),
        Positioned(
          top: SipSpace.md,
          right: SipSpace.x2,
          child: SipIkonButon(
            ikon: SipIcons.x,
            cap: 36,
            ikonBoyut: 22,
            kalinlik: 2.2,
            renk: t.muted,
            etiket: 'Kapat',
            onTap: _kapat,
          ),
        ),
      ],
    );
  }

  // ── Tek izin adımı ─────────────────────────────────────────────────────────────────────────
  Widget _izinAdimi(IzinAdimi iz) {
    final t = context.sip;
    final n = _izinler.length;
    final verilen = _izinler.where(_verildi).length;
    final verildi = _verildi(iz);

    return Column(
      children: [
        SihirbazIlerleme(oran: _oran),
        SipUst(baslik: 'Adım $_adim/$n', alt: '$verilen izin verildi', onGeri: _geri),
        Expanded(
          child: _Ortala(
            children: [
              IzinIkonu(ikon: iz.ikon, verildi: verildi),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  iz.ad,
                  style: SipText.izinAd.copyWith(color: t.ink),
                  textAlign: TextAlign.center,
                ),
              ),
              if (iz.zorunlu)
                SihirbazRozet(
                  etiket: 'Zorunlu',
                  renk: t.accent,
                  zemin: t.accentSoft,
                  buyukHarf: true,
                ),
              SihirbazMetin(iz.neden),
              if (verildi)
                SihirbazRozet(
                  etiket: 'İzin verildi',
                  renk: t.ok,
                  zemin: t.okSoft,
                  ikon: SipIcons.check,
                  ustBosluk: 18,
                ),
              if (_atlandi(iz))
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 270),
                    child: Text(
                      'Bu izni atladınız — sonra Menü\'den tekrar açabilirsiniz.',
                      style: SipText.metin(12.5).copyWith(color: t.muted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _Alt(
          children: verildi
              ? [SipButon(etiket: 'Devam', onTap: _ilerle)]
              : [
                  SipButon(
                    etiket: iz.birincilEtiket ?? 'İzin Ver',
                    onTap: () => _izinIste(iz),
                  ),
                  // İkinci ayar ekranı (ör. otomatik başlatma) — bir adımın iki ayarı olabilir.
                  // İKİNCİL görünümde: birincil eylem adımın asıl işidir, bu onun tamamlayıcısı.
                  if (_ikincilGorunur(iz))
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: SipButon(
                        etiket: iz.ikincilEtiket ?? 'Diğer Ayar',
                        tur: SipButonTuru.ikincil,
                        onTap: () => _ikincilAyar(iz),
                      ),
                    ),
                  if (iz.zorunlu)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Text(
                        'Bu izin kartın çalışması için zorunludur.',
                        style: SipText.metin(11.5).copyWith(color: t.muted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    SihirbazAtlaButonu(etiket: 'Atla', onTap: () => _atla(iz)),
                ],
        ),
      ],
    );
  }

  // ── Deneme çağrısı ─────────────────────────────────────────────────────────────────────────
  Widget _deneme() {
    return Column(
      children: [
        const SihirbazIlerleme(oran: 1),
        SipUst(baslik: 'Kurulumu Test Et', onGeri: _geri),
        Expanded(child: _Ortala(children: _denemeGovde())),
        _Alt(children: _denemeAlt()),
      ],
    );
  }

  List<Widget> _denemeGovde() => switch (_test) {
        _Test.basari => const [
            SihirbazLogo(ikon: SipIcons.check, tur: SihirbazLogoTuru.basari),
            SihirbazBaslik('Kart çıktı!'),
            SihirbazMetin(
              'Arama tanıma çalışıyor. Artık telefon çaldığında müşteriniz ekranda belirecek.',
            ),
          ],
        _Test.hata => const [
            SihirbazLogo(ikon: SipIcons.alert, tur: SihirbazLogoTuru.hata),
            SihirbazBaslik('Kart çıkmadı'),
            SihirbazMetin(
              'Büyük ihtimalle "üste çizim" izni eksik. Adımlara dönüp kontrol edelim.',
            ),
          ],
        _ => [
            SihirbazLogo(
              ikon: SipIcons.phoneCall,
              nabiz: _test == _Test.calisiyor,
            ),
            const SihirbazBaslik('Kendinizi test arayın'),
            const SihirbazMetin(
              'Başka bir hattan kendi numaranızı arayın. Kart ekranda çıkarsa kurulum tamam '
              'demektir.',
            ),
          ],
      };

  List<Widget> _denemeAlt() => switch (_test) {
        _Test.basari => [SipButon(etiket: 'Bitir', onTap: _bitir)],
        _Test.hata => [
            SipButon(etiket: 'Adımlara Dön', onTap: () => setState(() {
                  _adim = 1;
                  _test = _Test.bekliyor;
                })),
          ],
        _ => [
            SipButon(
              etiket: 'Deneme Çağrısı Yap',
              yukleniyor: _test == _Test.calisiyor,
              onTap: _test == _Test.calisiyor ? null : _denemeCagrisi,
            ),
            SihirbazAtlaButonu(etiket: 'Şimdilik atla', onTap: _bitir),
          ],
      };
}

/// CSS `.siz-govde.ortala` — dikey ortalı, kaydırılabilir gövde.
class _Ortala extends StatelessWidget {
  const _Ortala({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x6, vertical: SipSpace.x4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// CSS `.siz-alt` — ekranın altındaki eylem bloğu.
class _Alt extends StatelessWidget {
  const _Alt({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SipSpace.x5,
        SipSpace.xl,
        SipSpace.x5,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
