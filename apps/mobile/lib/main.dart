import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:async' show unawaited;

import 'auth/session.dart';
import 'bildirim/bildirim_servisi.dart';
import 'bildirim/bildirim_tetikleyici.dart';
import 'bildirim/kurallar/durum_kurallari.dart';
import 'bildirim/kurallar/durum_ureticileri.dart';
import 'bildirim/kurallar/para_kurallari.dart' show kGunSonuSaati;
import 'bildirim/kurallar/para_ureticileri.dart';
import 'bildirim/push/push_baglama.dart';
import 'bildirim/push/push_servisi.dart';
import 'repo/day_end_repository.dart';
import 'data/app_database.dart';
import 'guncelleme/guncelleme_servisi.dart';
import 'repo/bildirim_kutusu.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/orders/tutamac_deposu.dart';
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
    // Sürükle-bırak tutamacının tarafı da cihaz-yerel bir tercihtir (saha hatası 4); temayla
    // aynı yerde, aynı desenle yüklenir. Beklenmez: sipariş listesi açılmadan çok önce biter,
    // okunamazsa varsayılan SAĞ kalır.
    tutamacDeposu.yukle();
    // Bildirim altyapısı: kanalları kurar, saat dilimini bağlar, kayıtlı tercihleri okur.
    // İZİN İSTEMEZ — izin, bayi Ayarlar'dan bildirimleri açtığında istenir; açılışta izin
    // diyaloğu göstermek kurulum sürtünmesini artırır (BRIEF korku #3). Beklenmez: kurulum
    // birkaç ms'dir ve başarısız olursa uygulama bildirimsiz çalışmaya devam eder.
    bildirimAltyapisiniKur();
    // GEÇİCİ — uygulama içi güncelleme (yalnız `saha` kanalı; mağaza derlemesinde ağa hiç
    // çıkmaz). Beklenmez ve hata yutar: kontrol açılışı ASLA bloklamaz, çevrimdışıyken
    // hiçbir gecikme ya da uyarı üretmez (kırmızı çizgi #3).
    unawaited(guncellemeServisi.sessizKontrol());
    // Açılış hatası SPINNER'DA BIRAKMAZ (2026-07-22 saha bulgusu: migration hatası isLoggedIn'i
    // hiç döndürmeyince iki cihaz sonsuz loading'de kaldı). Hata ekrana çıkar — sessiz kilit yok.
    _session.isLoggedIn().then((v) async {
      if (v) await _startSync();
      // Bildirim kuralları YALNIZ oturum açıkken koşar: hepsi deftere bakar, oturumsuz cihazda
      // defter boştur ve her kural zaten null dönerdi — gereksiz sorgu açılışı yavaşlatmasın.
      // BEKLENMEZ: açılışı bloke etmemeli; taramanın kendisi hata yutar.
      if (v) unawaited(_bildirimKurallariniKos());
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

  /// YEREL bildirim kurallarının BAĞLANDIĞI tek yer.
  ///
  /// Üreticiler kural dosyalarının yanında yaşıyor (`kurallar/*_ureticileri.dart`) çünkü
  /// defteri onlar okuyor; tetikleyici ne Drift'i ne kuralların içini tanıyor, yalnız NE ZAMAN
  /// çağrılacaklarını biliyor. Bağlama burada, main'de: her iki tarafı da tanıyan tek yer.
  ///
  /// SUNUCUDAN İTİLENLER BURADA YOK: push'un yolu ayrıdır (`bildirim/push/`), dürtü geldiğinde
  /// senkron koşar ve taslak orada üretilir. Buradaki liste yalnız telefonun KENDİ verisinden
  /// türeyen kurallardır.
  ///
  /// Altyapı kurulumu ÖNCE beklenir — kanallar ve saat dilimi hazır olmadan zamanlama yapılırsa
  /// bildirim yanlış saate düşer.
  Future<void> _bildirimKurallariniKos() async {
    await bildirimAltyapisiniKur();
    final db = widget.db;

    // BİLDİRİM KUTUSU BAĞLANIR (2026-08-21) — üretilen her taslak uygulama içi listeye de düşer.
    //
    // SARMALAMA ALTYAPI KURULUMUNDAN SONRA: `bildirimAltyapisiniKur` servisin somut tipine
    // bakıyor (`is YerelBildirimServisi`) ve sarmalanmış hâli tanımaz — önce sarsaydık kanallar
    // hiç kurulmazdı, yani bildirimler sessizce çıkmamaya başlardı.
    //
    // İKİ KEZ SARMAYA KARŞI: bu fonksiyon oturum açılışında bir kez koşar ama savunma ucuz.
    if (bildirimServisi is! KutuluBildirimServisi) {
      bildirimServisi = KutuluBildirimServisi(bildirimServisi, BildirimKutusu(db));
    }

    await BildirimTetikleyici(
      servis: bildirimServisi,
      // AÇILIŞTA koşanlar — kimlikleri gün damgalı, tekrar güvenli.
      anlik: [
        senkronUyarisiUretici(db),
        kullanimHakkiUretici(db),
      ],
      // GÜNÜN BELİRLİ ANLARINA kurulanlar. Saatler kuralların yanında sabit duruyor
      // (`kGunSonuSaati` · `kKasaHatirlatmaSaati` · `kSabahHatirlatmaSaati`) — burada yalnız
      // bağlanıyorlar ki "ne zaman" sorusunun cevabı tek yerde kalsın.
      zamanlanan: [
        ZamanlanmisIs(
          ad: 'gunSonu',
          uretici: gunSonuOzetiUretici(DayEndRepository(db)),
          an: (simdi) => BildirimTetikleyici.gunlukAn(simdi, kGunSonuSaati),
        ),
        ZamanlanmisIs(
          ad: 'kasaDevri',
          uretici: kasaDevriHatirlatmasiUretici(db),
          an: (simdi) => BildirimTetikleyici.gunlukAn(simdi, kKasaHatirlatmaSaati),
        ),
        ZamanlanmisIs(
          ad: 'gunKapatilmadi',
          uretici: gunKapatilmadiUretici(db),
          an: (simdi) => BildirimTetikleyici.gunlukAn(simdi, kSabahHatirlatmaSaati),
        ),
      ],
    ).acilistaKos();
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
    // AĞ TETİĞİ (2026-07-27 saha arızası). `connectivity_plus` pubspec'te baştan vardı ve
    // `sync_engine.dart:9` "ağ tetiği (connectivity) ve zamanlayıcı bunları çağırır" diye YAZMIŞTI
    // ama kod hiç yazılmamıştı — tetikleyici yalnız açılıştaki ilk tur ve 2 dakikalık
    // zamanlayıcıydı. Kurye kapsama alanına girdiği ANDA siparişin gitmesi gerekiyor; iki dakika
    // ya da uygulamayı öne getirmesi beklenmemeli. Sunucuya erişimi GARANTİ ETMEZ (captive portal
    // "bağlı" der) — yanlış tetik artık en fazla bir zaman aşımına mal olur.
    _sync.tetikleyiciBagla(
      Connectivity()
          .onConnectivityChanged
          .where((durum) => !durum.contains(ConnectivityResult.none)),
    );
    // YAZIM TETİĞİ (2026-08-09 saha arızası). Ağ tetiğiyle aynı hikâye, bu kez tersten: orada
    // "kayıt hazır, ağ yoktu"; burada "ağ vardı, kaydın gideceğini kimse söylemedi". Patronun
    // kuryeye attığı sipariş outbox'a düşüyor ama turu hiçbir şey açmıyordu — kurye ancak
    // patron uygulamayı öne getirdiğinde (resumed turu) görüyordu. Kaynağı servis kendi
    // veritabanından kurar; burada yalnız BAĞLANIR ki tetik tek bir yerde açılıp kapansın.
    _sync.yazimTetigiBagla();
    _sync.start();
    // PUSH — sunucunun telefonu dürtmesi. Yalnız oturum açıkken kurulur (jetonun yazılacağı
    // cihaz kaydı bir bayiye aittir) ve BEKLENMEZ: Play Services'i olmayan cihazda (Huawei)
    // ya da yapılandırma eksikse sessizce kurulmaz, ürün mevcut senkronla çalışmaya devam
    // eder — push HIZLANDIRICIDIR, taşıyıcı değil.
    unawaited(_pushKur());
  }

  /// Push servisi. `null` = kurulamadı (oturum/yapılandırma yok, Play Services yok).
  PushServisi? _push;

  Future<void> _pushKur() async {
    try {
      _push = await pushKur(widget.db, _sync);
    } on Object catch (e) {
      debugPrint('Push kurulamadı: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_push?.kapat());
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
                  aciklama: 'Uygulama açılamadı. Aşağıdaki mesajı destekle paylaşın.',
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
