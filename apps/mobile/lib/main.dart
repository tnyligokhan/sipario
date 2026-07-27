import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'auth/session.dart';
import 'data/app_database.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/products/product_form_sheet.dart';
import 'screens/sihirbaz/izin_sihirbazi.dart';
import 'sync/sync_service.dart';
import 'theme/app_theme.dart';
import 'theme/components/overlays.dart';
import 'theme/components/states.dart';
import 'theme/tema_deposu.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ürün görseli seçicisi burada BAĞLANIR (tasarım s-urunler.jsx: gerçek dosya seçici).
  // Form katmanı `image_picker`ı tanımaz, yalnız bir kanca çağırır — böylece widget testleri
  // platform eklentisi olmadan koşabiliyor (kanca null iken form bilgilendirme gösterir).
  // Seçilen dosyanın YOLU `products.image_local_path`e yazılır: cihaz-yerel, senkronlanmaz.
  urunGorselSecici = () async =>
      (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
  final db = AppDatabase.file();
  runApp(SiparioApp(db: db));
}

/// Kök: oturum varsa ana kabuk, yoksa giriş (s-uygulama.jsx `girisli` dalı).
/// Tema AÇIK varsayılan; kullanıcı çekmeceden değiştirir, tercih cihazda saklanır
/// (bkz. theme/tema_deposu.dart).
///
/// KURULUM SİHİRBAZI kabuğun YERİNE tam ekran gösterilir (tasarım `s-uygulama.jsx:61`: sihirbaz
/// dalı `girisli` dalından önce döner). Girişten hemen sonra açılır ama BİR KEZ: damga
/// `sync_meta.setup_completed_at` (cihaz-yerel, bkz. [kurulumuDamgala]) — hem bitirmek hem
/// çarpıyla atlamak damgalar, sihirbaz sonra yalnız Ayarlar/çekmeceden açılır.
class SiparioApp extends StatefulWidget {
  const SiparioApp({super.key, required this.db, this.tema});

  final AppDatabase db;

  /// Test/araç yolu — verilmezse diske yazan gerçek depo kurulur.
  final TemaKontrol? tema;

  @override
  State<SiparioApp> createState() => _SiparioAppState();
}

class _SiparioAppState extends State<SiparioApp> {
  late final Session _session = Session(widget.db);
  late final SyncService _sync = SyncService(widget.db);
  late final TemaKontrol _tema = widget.tema ?? TemaKontrol();

  bool? _loggedIn; // null = açılış kontrolü sürüyor
  String? _startupError;

  /// Kurulum sihirbazı kabuğun yerine gösteriliyor mu (ilk giriş).
  bool _sihirbaz = false;

  @override
  void initState() {
    super.initState();
    _tema.yukle();
    // Açılış hatası SPINNER'DA BIRAKMAZ (2026-07-22 saha bulgusu: migration hatası isLoggedIn'i
    // hiç döndürmeyince iki cihaz sonsuz loading'de kaldı). Hata ekrana çıkar — sessiz kilit yok.
    _session.isLoggedIn().then((v) async {
      if (v) await _startSync();
      final sihirbaz = v && await kurulumGerekliMi(widget.db);
      if (mounted) {
        setState(() {
          _loggedIn = v;
          _sihirbaz = sihirbaz;
        });
      }
    }).catchError((Object e) {
      if (mounted) setState(() => _startupError = e.toString());
    });
  }

  /// Sihirbaz kapandı (bitti ya da atlandı): damgala ve kabuğa geç. [tamamlandi] ise tasarımdaki
  /// toast basılır — [ctx] MaterialApp'in ALTINDAKİ bağlamdır (Overlay orada).
  Future<void> _sihirbazKapandi(BuildContext ctx, {required bool tamamlandi}) async {
    await kurulumuDamgala(widget.db);
    if (!mounted) return;
    setState(() => _sihirbaz = false);
    if (tamamlandi && ctx.mounted) SipToast.goster(ctx, 'Kurulum tamamlandı');
  }

  Future<void> _startSync() async {
    await _sync.configure();
    _sync.start();
  }

  @override
  void dispose() {
    _sync.dispose();
    if (widget.tema == null) _tema.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _tema,
      builder: (context, koyu, _) => MaterialApp(
        title: 'Sipario',
        debugShowCheckedModeBanner: false,
        theme: SipTheme.acik(),
        darkTheme: SipTheme.koyu(),
        themeMode: koyu ? ThemeMode.dark : ThemeMode.light,
        // Durum çubuğu ikonlarının varsayılanı BURADA kurulur — her rota için.
        // Yalnız kabuk ayarlasaydı (eskiden öyleydi), üstüne push edilen ekranlar
        // (Ayarlar, Kuryeler, Muaf, İşletme Profili, Ürünler…) kabuğun bıraktığı son
        // değeri miras alırdı: ana ekranın koyu hero'su için beyaza çevrilmiş ikonlar
        // açık temalı bu ekranlarda beyaz kalıyor ve saat/pil okunmuyordu (cihazda görüldü).
        // Koyu hero'su olan ekranlar kendi `AnnotatedRegion`'larıyla bunu geçersiz kılar.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SipTheme.sistemCubuklari(koyu ? SipTokens.koyuTema : SipTokens.acik),
          child: child ?? const SizedBox.shrink(),
        ),
        // Builder: toast'ın Overlay'i MaterialApp'in İÇİNDEDİR — sihirbaz bitiş toast'ı bu
        // bağlamdan basılır (kökün kendi bağlamında Overlay yok, toast sessizce düşerdi).
        home: Builder(
          builder: (ctx) => switch (_loggedIn) {
            null when _startupError != null => _AcilisHatasi(mesaj: _startupError!),
            null => const _Acilis(),
            false => LoginScreen(
                session: _session,
                onLoggedIn: () async {
                  await _startSync();
                  final sihirbaz = await kurulumGerekliMi(widget.db);
                  if (mounted) {
                    setState(() {
                      _loggedIn = true;
                      _sihirbaz = sihirbaz;
                    });
                  }
                },
              ),
            true when _sihirbaz => IzinSihirbazi(
                onBitti: () => _sihirbazKapandi(ctx, tamamlandi: true),
                onKapat: () => _sihirbazKapandi(ctx, tamamlandi: false),
              ),
            true => HomeShell(
                db: widget.db,
                session: _session,
                sync: _sync,
                tema: _tema,
                onLoggedOut: () {
                  _sync.stop();
                  if (mounted) setState(() => _loggedIn = false);
                },
              ),
          },
        ),
      ),
    );
  }
}

/// Açılış — oturum kontrolü sürerken. Tasarımda spinner yerine sakin bir marka ekranı var.
class _Acilis extends StatelessWidget {
  const _Acilis();

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.hero,
      body: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(t.accent),
          ),
        ),
      ),
    );
  }
}

/// Açılış hatası — sessiz kilit yerine görünür hata + tekrar deneme yolu.
class _AcilisHatasi extends StatelessWidget {
  const _AcilisHatasi({required this.mesaj});

  final String mesaj;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SipSpace.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SipHataEkran(
                  aciklama: 'Uygulama açılamadı. Lütfen destek ile iletişime geçin.',
                ),
                Text(
                  mesaj,
                  style: SipText.metin(11).copyWith(color: t.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
