// ANA KABUK — s-uygulama.jsx (kök state + routing + rol/durum kapıları).
//
// Yerleşim (CSS `.app`): [çevrimdışı bandı] → `.app-icerik` (aktif sekme) → `.altnav` hap
// navigasyon; hepsinin üstünde soldan açılan `.cek` çekmecesi. Material `NavigationBar`/`Drawer`
// KULLANILMAZ — tasarımın hap navigasyonu ve hero zeminli çekmecesi onlarla kurulamıyor.
//
// KAPILAR:
//  • Rol (K2): `yetkiler(rol:, kuryeVar:)` — ürün yönetimi yalnız yöneticide (çekmecenin YÖNETİM
//    bölümü), atama yalnız yönetici + aktif kurye varken.
//  • Abonelik: salt-okunur kipte gövde `SubscriptionLockedScreen`e düşer; çekmece ve navigasyon
//    erişilebilir kalır (mevcut veri okunabilir), FAB çizilir ama pasiftir.
//
// NAVİGASYON ROLE BAĞLI DEĞİLDİR: tasarımda `AltNav` 5 yuvadır ve `Cekmece`nin MENÜ bölümü 4
// satırdır — rol yalnız YÖNETİM bölümünü etkiler (`s-bilesenler.jsx:106`). Gün Sonu sekmesi
// kuryede de açıktır (kullanıcı kararı, 2026-07-26): kurye kendi kasa devrini oradan görür,
// `yetki.gunSonu` artık sekme değil YETKİ sorusudur (gün kapatma gibi eylemler o ekranın işi).
//
// İLK GİRİŞ: kurulum sihirbazı `main.dart`ta, kabuğun YERİNE tam ekran gösterilir
// (`s-uygulama.jsx:61`); damgası `sync_meta.setup_completed_at` — bkz. [kurulumuDamgala].

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/session.dart';
import '../bildirim/bildirim_servisi.dart';
import '../bildirim/bildirim_sozlesmesi.dart';
import '../data/app_database.dart';
import '../guncelleme/guncelleme_banti.dart';
import '../guncelleme/guncelleme_servisi.dart';
import '../subscription/subscription_locked_screen.dart';
import '../subscription/subscription_state.dart';
import '../sync/sync_service.dart';
import '../theme/app_theme.dart';
import '../theme/components/overlays.dart';
import '../theme/components/states.dart';
import '../theme/icons.dart';
import '../theme/tema_deposu.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'ana_ekran.dart';
import 'cagri/cagri_cozumleyici.dart';
import 'cagri/cagri_eylem_kanali.dart';
import 'cagri/cagri_karti.dart';
import 'cagri/cagri_kuyrugu.dart';
import 'cagri/cagri_model.dart';
import 'customers/customer_detail_screen.dart';
import 'customers/customer_form_screen.dart' show musteriEkleSheet;
import 'customers/customer_list_screen.dart';
import 'isletme/ayarlar_ekrani.dart';
import 'isletme/kuryeler_ekrani.dart';
import 'isletme/muaf_ekrani.dart';
import 'day_end_screen.dart';
import 'orders/order_detail_screen.dart';
import '../phase0/phase0_screen.dart';
import 'orders/order_form_screen.dart';
import 'orders/order_list_screen.dart';
import 'products/product_list_screen.dart';
import 'shell/alt_nav.dart';
import 'shell/cekmece.dart';
import 'sihirbaz/izin_sihirbazi.dart';
import 'team.dart';

/// Kurulum sihirbazının "görüldü" damgası — CİHAZ-YEREL (`sync_meta.setup_completed_at`,
/// sunucuya gitmez). Sihirbaz bittiğinde VE atlandığında yazılır: atlamak da bir karardır,
/// yazılmazsa sihirbaz her açılışta önüne dikilirdi. Kapıyı kilitlemez — sihirbaz Ayarlar'dan
/// (ve çekmeceden) her zaman yeniden açılabilir.
Future<void> kurulumuDamgala(AppDatabase db) async {
  await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
    SyncMetaCompanion(setupCompletedAt: Value(DateTime.now().toUtc().toIso8601String())),
  );
}

/// Kurulum sihirbazı bu cihazda hiç kapatılmamış mı (ilk giriş kontrolü).
Future<bool> kurulumGerekliMi(AppDatabase db) async =>
    (await db.syncState()).setupCompletedAt == null;

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.db,
    required this.session,
    required this.sync,
    required this.onLoggedOut,
    this.tema,
  });

  final AppDatabase db;
  final Session session;
  final SyncService sync;
  final VoidCallback onLoggedOut;

  /// Tema anahtarı (çekmecedeki "Koyu tema"). Verilmezse kabuk kendi geçici anahtarını kurar
  /// (test yolu — diske yazmaz).
  final TemaKontrol? tema;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// Senkron hata cinsini bandın anlatacağı gerçeğe çevirir. Ekrandan AYRI saf fonksiyon: eşleme
/// widget kurmadan test edilir ve tema katmanı `sync` paketine bağımlı olmaz (bağımlılık yönü
/// ekran → tema + ekran → sync olarak kalır).
SipBantTuru bantTuru(SyncHataTuru tur) => switch (tur) {
      SyncHataTuru.oturum => SipBantTuru.oturum,
      SyncHataTuru.veri => SipBantTuru.hata,
      SyncHataTuru.ag || SyncHataTuru.yok => SipBantTuru.cevrimdisi,
    };

/// Durum çubuğu ikonları BEYAZ mı çizilsin (koyu hero'nun üstündeler mi)?
///
/// Ana ekranın tepesi koyu bir hero'dur ve ikonlar orada beyaz olmalıdır. AMA üstte bir BANT
/// varsa (çevrimdışı · grace · güncelleme) durum çubuğunun altındaki artık hero değil, o açık
/// renkli banttır — beyaz ikonlar orada görünmez olur ve bayi saati/pili okuyamaz
/// (2026-07-28 saha bulgusu: güncelleme bandı çıkınca bildirim çubuğu bozuluyordu).
///
/// Saf fonksiyon: widget kurmadan test edilir. Yeni bir bant eklendiğinde [bantVar]'a katılmalı.
bool heroDurumCubugu({
  required bool anaSekme,
  required bool kilit,
  required bool bantVar,
}) =>
    anaSekme && !kilit && !bantVar;

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  /// Açılış sekmesi ANA EKRAN'dır (kullanıcı kararı, 2026-07-26).
  ///
  /// Tasarım `s-uygulama.jsx` `useState('siparis')` ile açıyor ve bir süre öyle duruldu;
  /// bilinçli sapma: Ana ekran yalnız bir karşılama değil, günün ÖZETİ — bento kutuları
  /// son aramayı, günün sayılarını ve kısayolları bir arada verir. Sipariş listesine oradan
  /// tek dokunuşla gidilir, tersi ise özeti hiç görmeden çalışmak demekti.
  SipSekme _sekme = SipSekme.ana;
  bool _cekmece = false;

  AccessLevel _access = AccessLevel.full;
  String? _userRole;
  String? _userId;
  String? _tenantName;
  String? _userName;
  DateTime? _validUntil;

  /// Oto sıralama kontörü — sunucu sahipli (senkronla iner), çekmece kartında gösterilir.
  /// null iken kart hiç çizilmez.
  int? _otoHak;
  int? _otoAylik;

  List<User> _kuryeler = const [];

  StreamSubscription<SyncOutcome>? _syncSub;
  StreamSubscription<List<User>>? _kuryeSub;
  StreamSubscription<SyncMetaData>? _metaSub;
  SyncOutcome? _sonSenkron;
  DateTime? _sonSenkronAt;

  late final TemaKontrol _tema =
      widget.tema ?? TemaKontrol(depo: TemaDeposu.bellek());

  @override
  void initState() {
    super.initState();
    // Öne gelince senkron turu: tetikleyici YALNIZ açılıştaki ilk tur + 2 dk'lık zamanlayıcıydı,
    // öne gelme hiçbir şey tetiklemiyordu ("ancak kapatıp açınca senkronize oluyor" — saha).
    WidgetsBinding.instance.addObserver(this);
    // Bant görünürlüğü durum çubuğu ikon rengini belirliyor — kabuk onu dinlemezse bant
    // çıktığında ikonlar beyaz kalır ve açık zeminde okunmaz.
    guncellemeServisi.durum.addListener(_guncellemeBandiDegisti);
    // sync_meta AKIŞINA abone olunur, tek atış okunmaz. Bu satırın sunucu sahipli alanları
    // (abonelik, firma kodu, rota kontörü) hem senkronla hem ekranlardan (oto sıralama hakkı
    // düştüğünde) değişir; tek atış okuma çekmecedeki kartları bayat bırakıyordu — cihazda
    // "34 hak" gösterirken sunucuda 33 vardı. Drift akışı ilk değeri hemen yayar.
    _metaSub = widget.db.watchSyncState().listen((meta) => _metaUygula(meta));
    // Telefon çalarken Flutter motoru başlamadığından native, çağrıyı düz metin bir kuyruğa
    // yazar; DB'ye ancak burada geçer. Açılışta boşaltılmazsa ana ekrandaki "Son Arama" kutusu
    // bayi Ayarlar'a girene kadar BAYAT kalırdı (kutu dosyayı değil DB'yi okuyor).
    // Beklenmez: yazılan satırlar akışları kendiliğinden tazeler; fonksiyon hata yutar.
    unawaited(cagriKuyrugunuBosalt(widget.db));
    // Native kartın eylem köprüsü. Bayi telefon çalarken karttaki bir düğmeye dokunmuş
    // olabilir ve uygulama O ANDA açılıyordur — bekleyen eylem açılışta çekilir. Uygulama
    // zaten açıkken dokunulduğunda yaşam döngüsü olayı doğmaz; native dürtüyü gönderir.
    cagriEylemDurtusunuDinle(_nativeCagriEylemi);
    unawaited(_nativeCagriEylemi());
    // Bildirime dokunuldu mu? Uygulama KAPALIYKEN dokunulmuşsa değer biz dinlemeye başlamadan
    // ÖNCE düşmüş olur — bu yüzden dinleyiciyi kurmakla kalmayıp mevcut değeri de bir kez
    // yokluyoruz (çağrı kartı köprüsünün `bekleyen` deseninin aynısı).
    YerelBildirimServisi.dokunulanYol.addListener(_bildirimDokunusu);
    _bildirimDokunusu();
    // Aktif kurye varlığı "tek kişilik bayi" kararının dayanağıdır (K2 kuryeVar).
    _kuryeSub = watchAktifKuryeler(widget.db).listen((k) {
      if (!mounted) return;
      setState(() => _kuryeler = k);
    });
    _syncSub = widget.sync.status.listen((o) {
      if (!mounted) return;
      setState(() {
        _sonSenkron = o;
        _sonSenkronAt = DateTime.now();
      });
      // sync_meta'yı burada okumaya GEREK YOK: yukarıdaki akış yazımı kendiliğinden yakalar.
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(widget.sync.syncNow());
    // Güncelleme kontrolü de öne gelmede koşar. Yalnız açılışa bağlıydı ve saha bulgusu şuydu
    // (2026-07-28): son kullanılanlardan kaydırmak süreci ÖLDÜRMÜYOR, `initState` bir daha
    // koşmuyor ve bant ancak "zorla durdur"dan sonra çıkıyordu. Servis kendi aralığını
    // (15 dk) tutar, bu yüzden her öne gelmede ağa çıkılmaz.
    unawaited(guncellemeServisi.sessizKontrol());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    guncellemeServisi.durum.removeListener(_guncellemeBandiDegisti);
    _syncSub?.cancel();
    _kuryeSub?.cancel();
    _metaSub?.cancel();
    cagriEylemDurtusunuBirak();
    YerelBildirimServisi.dokunulanYol.removeListener(_bildirimDokunusu);
    SipToast.temizle();
    super.dispose();
  }

  /// sync_meta satırından rol/abonelik/kontör türevlerini hesaplayıp duruma yazar.
  /// TEK çağıran akış aboneliğidir — ikinci bir tazeleme yolu bilinçli olarak yok.
  void _metaUygula(SyncMetaData meta) {
    final now = SubscriptionState.estimateServerNow(
      serverTimeOffsetMs: meta.serverTimeOffsetMs,
      lastServerTimeIso: meta.lastServerTimeIso,
    );
    final gecerli =
        meta.validUntilIso != null ? DateTime.tryParse(meta.validUntilIso!) : null;
    final level = SubscriptionState.evaluate(
      estimatedServerNow: now,
      validUntil: gecerli,
      status: meta.subscriptionStatus,
    );
    if (!mounted) return;
    setState(() {
      _access = level;
      _userRole = meta.userRole;
      _userId = meta.userId;
      _tenantName = meta.tenantName;
      _userName = meta.userName;
      _validUntil = gecerli;
      // Çekmecedeki "Oto sıralama bakiyesi" kartı (tasarım `.lst-kart`). Kota 0 ise sunucu
      // henüz bildirmemiş demektir → kart çizilmez (oran hesaplanamaz, uydurma çubuk çizmeyiz).
      _otoHak = meta.routeCreditsMonthly > 0 ? meta.routeCredits : null;
      _otoAylik = meta.routeCreditsMonthly > 0 ? meta.routeCreditsMonthly : null;
    });
  }

  bool get _yazilabilir => SubscriptionState.writable(_access);
  bool get _kilit => _access == AccessLevel.readOnly;

  RolYetkileri get _yetki =>
      yetkiler(rol: _userRole, kuryeVar: _kuryeler.isNotEmpty);

  /// ÇEKMECE başlığı: işletme (firma) adı — tasarım `s-bilesenler.jsx:100` `{isletme.ad}`.
  String get _isletmeAdi => _tenantName ?? 'Sipario';

  /// ANA EKRAN hero'su: kullanıcının kendi adı — tasarım `s-ana.jsx:21` `{ISLETME.sahip}`.
  /// İkisine aynı değeri vermek (eski hâl) selamın altına firma unvanı bastırıyordu.
  String get _sahipAdi => _userName ?? _tenantName ?? 'Sipario';

  void _sekmeSec(SipSekme s) {
    setState(() {
      _sekme = s;
      _cekmece = false;
    });
  }

  Future<void> _git(Widget ekran) async {
    setState(() => _cekmece = false);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ekran));
    // Dönüşte elle tazeleme YOK: sync_meta akışı, açılan ekranın yaptığı her yazımı zaten
    // yakalar (tema, profil, kontör…). İki yol tutmak ikisinin ayrışması demekti.
  }

  void _cekmeceGirisi(CekmeceGiris g) {
    switch (g) {
      case CekmeceGiris.urunler:
        _git(ProductListScreen(db: widget.db, writable: _yazilabilir));
      case CekmeceGiris.kuryeler:
        _git(KuryelerEkrani(db: widget.db, writable: _yazilabilir));
      case CekmeceGiris.muaf:
        _git(MuafEkrani(db: widget.db, writable: _yazilabilir));
      case CekmeceGiris.ayarlar:
        _git(AyarlarEkrani(
          db: widget.db,
          rol: _userRole,
          writable: _yazilabilir,
          onSihirbaz: _sihirbaziAc,
          onCagriSimulasyonu: _cagriKartiAc,
          koyuTema: _tema,
          onTema: _tema.ayarla,
          // Faz 0 gecikme ölçüm ekranı: TASARIMDA YOK ama arayan-tanımanın 1 sn bütçesini
          // (kırmızı çizgi) ölçen tek araç. Ayarlar satırı `kDebugMode` ile sarmalı, yani
          // üretimde esnafın menüsünde görünmez. Bu geri çağrım OLMADAN satır hiç çizilmez
          // ve `Phase0Screen` erişilemeyen dosyaya döner (çekmece ölü dalı dersi).
          onOlcumler: () => _git(Phase0Screen(db: widget.db)),
        ));
      case CekmeceGiris.sihirbaz:
        _sihirbaziAc();
    }
  }

  /// Sihirbazı push eder ve BİTİRİLDİYSE tasarımdaki toast'ı basar
  /// (`s-uygulama.jsx:61` `ping('Kurulum tamamlandı')`). Kapatılırsa (çarpı) toast yok.
  Future<void> _sihirbaziAc() async {
    setState(() => _cekmece = false);
    var bitti = false;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (rotaCtx) => IzinSihirbazi(
        onBitti: () {
          bitti = true;
          Navigator.of(rotaCtx).pop();
        },
      ),
    ));
    await kurulumuDamgala(widget.db);
    if (!mounted || !bitti) return;
    SipToast.goster(context, 'Kurulum tamamlandı');
  }

  Future<void> _cikis() async {
    setState(() => _cekmece = false);
    // Tasarımda onay yalnız başlık + "Çıkış" düğmesidir (`s-uygulama.jsx:108`), mesaj YOK:
    // "kayıtlarınız cihazda kalır" cümlesi kullanıcının sormadığı bir soruyu cevaplıyordu.
    final ok = await sipOnay(
      context,
      baslik: 'Çıkış yapılsın mı?',
      onayEtiketi: 'Çıkış',
      tehlike: true,
    );
    if (!ok) return;
    await widget.session.logout();
    widget.onLoggedOut();
  }

  /// Güncelleme bandının ÜSTÜNDE çizilen bir bant var mı (çevrimdışı / grace)? Durum çubuğu
  /// boşluğunu yalnız EN ÜSTTEKİ bant ekler.
  bool get _ustBantVar =>
      (_sonSenkron != null && !_sonSenkron!.ok) || _access == AccessLevel.grace;

  /// Güncelleme bandı göründüğünde/kaybolduğunda kabuk YENİDEN ÇİZİLMELİ: durum çubuğu ikon
  /// rengi bandın varlığına bakıyor. Bant kendi `ValueListenableBuilder`ıyla tazeleniyor ama
  /// onu saran `AnnotatedRegion` kabuğun `build`inde — dinlemezse ikonlar bandın altında
  /// beyaz kalırdı.
  void _guncellemeBandiDegisti() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final yetki = _yetki;
    final sekme = _sekme;
    final heroluEkran = heroDurumCubugu(
      anaSekme: sekme == SipSekme.ana,
      kilit: _kilit,
      bantVar: _ustBantVar || guncellemeBandiGorunurMu(),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SipTheme.sistemCubuklari(t).copyWith(
        statusBarIconBrightness: heroluEkran ? Brightness.light : null,
        statusBarBrightness: heroluEkran ? Brightness.dark : null,
      ),
      child: Scaffold(
        backgroundColor: t.bg,
        body: Stack(
          children: [
            Column(
              children: [
                if (_sonSenkron != null && !_sonSenkron!.ok)
                  SafeArea(
                    bottom: false,
                    child: SipCevrimdisiBant(tur: bantTuru(_sonSenkron!.tur)),
                  ),
                if (_access == AccessLevel.grace)
                  const SafeArea(bottom: false, child: _GraceBandi()),
                // Güncelleme bandı — KOŞULSUZ mount edilir; kapalıyken (mağaza derlemesi ya da
                // güncelleme yokken) kendisi hiçbir şey çizmez. Koşulu buraya yazmamak bilinçli:
                // `if` ile sarılsaydı "ağaçta var mı" testi mağaza varsayılanında hep boş döner
                // ve bandın bağlanmadığı yine fark edilmezdi (2026-07-28 saha bulgusu: servis
                // güncellemeyi buluyordu ama hiçbir ekran onu çizmiyordu).
                //
                // En ALTTAKİ bant: çevrimdışı ve grace uyarıları daha acildir. Durum çubuğu
                // boşluğunu yalnız üstünde başka bant yokken kendisi ekler.
                GuncellemeBanti(ustBosluk: !_ustBantVar),
                Expanded(child: _govde(sekme, yetki)),
                SipAltNav(
                  aktif: sekme,
                  onSec: _sekmeSec,
                  // Kilit kipinde FAB çizilir ama pasif (tasarım kilit dalında da AltNav'ı tam
                  // çizer); silinseydi hap navigasyon yeniden yerleşip atlıyordu.
                  onYeniSiparis: _yazilabilir ? _yeniSiparis : null,
                ),
              ],
            ),
            SipCekmece(
              acik: _cekmece,
              onKapat: () => setState(() => _cekmece = false),
              isletmeAdi: _isletmeAdi,
              rol: _userRole,
              aktif: sekme,
              onTab: _sekmeSec,
              onGiris: _cekmeceGirisi,
              onCikis: _cikis,
              onDestek: () {
                setState(() => _cekmece = false);
                SipToast.goster(context, 'Destek sohbeti · yakında');
              },
              sonSenkron: _sonSenkronAt,
              urunlerGorunur: yetki.urunYonetimi,
              lisansBitisi: _validUntil,
              otoSiralamaHakki: _otoHak,
              otoSiralamaAylik: _otoAylik,
            ),
          ],
        ),
      ),
    );
  }

  /// FAB'ın TEK işi budur (`s-bilesenler.jsx:55` → `s-uygulama.jsx:103`). Müşteri ekleme buradan
  /// başlamaz: tasarımda yalnız Müşteriler ekranının "Yeni"sinden (`s-uygulama.jsx:91`) ve çağrı
  /// kartının "Kaydet"inden (`:113`) açılır.
  void _yeniSiparis() =>
      _git(OrderFormScreen(db: widget.db, writable: _yazilabilir));

  /// "Son aktivite" satırı: sekmeyi siparişe alır VE detayı açar (`s-uygulama.jsx:89`).
  /// Detay sheet'i sipariş katmanının yüzeyidir — buradan yalnız çağrılır.
  Future<void> _siparisAc(String siparisId) async {
    setState(() => _sekme = SipSekme.siparis);
    await siparisDetaySheetAc(
      context,
      db: widget.db,
      orderId: siparisId,
      writable: _yazilabilir,
      canAssign: _yetki.atama,
    );
  }

  /// Çağrı kartını HAM numaradan açar. Kartın modelini `cagriKisiCoz` kurar (defterden çözer);
  /// kabuk numarayı kendisi yorumlamaz. Çözücü null/hata döndürmez — kayıtsızda kart
  /// "Müşteri Olarak Kaydet" varyantına düşer.
  ///
  /// ESKİDEN doğrudan `CagriKisi.kayitsiz(no)` geçiliyordu: kart HER ZAMAN "Kayıtsız" çıkıyor,
  /// bakiye şeridi / müşteri kodu / adres / "Defteri Aç" dalları hiç çizilemiyordu.
  Future<void> _cagriKartiAc(String numara) async {
    final kisi = await cagriKisiCoz(widget.db, numara);
    if (!mounted) return;
    final eylem = await cagriKartiGoster(context, kisi: kisi);
    if (eylem == null || !mounted) return;
    await _cagriEylemiUygula(eylem, kisi);
  }

  /// Kart KAPANDIKTAN sonra çalışan gezinme. Tasarım `s-uygulama.jsx:111-113`: her eylem
  /// önce `setCagri(null)` ile kartı kapatır, sonra hedefe gider — kart kendini pop ederek
  /// kapandığı için burada kapatacak bir şey kalmaz, yalnız hedefe gidilir.
  ///
  /// ESKİDEN dönen eylem ATILIYORDU (`await cagriKartiGoster(...)`, sonuç kullanılmadan):
  /// "Sipariş Oluştur", "Defteri Aç" ve "Müşteri Olarak Kaydet" yalnız kartı kapatıyor,
  /// hiçbiri bir yere gitmiyordu. Cihazda görüldü, 2026-07-26.
  Future<void> _cagriEylemiUygula(CagriEylemi eylem, CagriKisi kisi) async {
    switch (eylem) {
      case CagriEylemi.kapat:
        return;

      case CagriEylemi.siparis:
        if (!_yazilabilir) {
          SipToast.goster(context, 'Salt-okunur kip: yeni sipariş oluşturulamaz.');
          return;
        }
        setState(() => _sekme = SipSekme.siparis);
        // Kayıtsız numarada `initialCustomerId` null kalır: form müşteri SEÇİMİ adımıyla
        // açılır. Düğme kayıtsız kartta zaten çizilmez ama native köprüsünden bayat bir
        // istek gelebilir (kart çizildikten sonra müşteri silinmiş olabilir).
        await _git(OrderFormScreen(
          db: widget.db,
          writable: _yazilabilir,
          initialCustomerId: kisi.musteriId,
        ));

      case CagriEylemi.defter:
        final musteriId = kisi.musteriId;
        // Numara artık deftere bağlı değilse defter açılamaz — sessiz kalmak yerine kartı
        // gösteriyoruz, bayi oradan "Müşteri Olarak Kaydet"e geçebilir.
        if (musteriId == null) return _cagriKartiAc(kisi.numara);
        setState(() => _sekme = SipSekme.musteri);
        await _git(CustomerDetailScreen(
          db: widget.db,
          customerId: musteriId,
          writable: _yazilabilir,
          yetki: _yetki,
        ));

      case CagriEylemi.kaydet:
        if (!_yazilabilir) {
          SipToast.goster(context, 'Salt-okunur kip: yeni müşteri eklenemez.');
          return;
        }
        final eklendi =
            await musteriEkleSheet(context, db: widget.db, onTel: kisi.numara);
        if (eklendi != true || !mounted) return;
        // Tasarım `s-uygulama.jsx:116`: kayıttan sonra müşteri sekmesine geçilir ve YENİ
        // müşterinin defteri açılır. Kimliği çözücüden yeniden okuyoruz — sheet yalnız
        // "kaydedildi" bilgisini döndürür, numara ise az önce deftere yazıldı.
        final yeni = await cagriKisiCoz(widget.db, kisi.numara);
        final yeniId = yeni.musteriId;
        if (yeniId == null || !mounted) return;
        setState(() => _sekme = SipSekme.musteri);
        await _git(CustomerDetailScreen(
          db: widget.db,
          customerId: yeniId,
          writable: _yazilabilir,
          yetki: _yetki,
        ));
    }
  }

  /// Native kartın (telefon çalarken çizilen Kotlin kartı) bekleyen eylemini alır ve
  /// Flutter kartıyla AYNI gezinmeyi uygular — iki kartın davranışı tek yerde tanımlı.
  Future<void> _nativeCagriEylemi() async {
    final istek = await bekleyenCagriEylemi();
    if (istek == null || !mounted) return;
    // Numara kart çizildiği andan beri değişmiş olabilir (o çağrıdan sonra kaydedilmiş
    // ya da silinmiş): karar ANLIK defterden verilir, native'in gördüğüne güvenilmez.
    final kisi = await cagriKisiCoz(widget.db, istek.numara);
    if (!mounted) return;
    await _cagriEylemiUygula(istek.eylem, kisi);
  }

  /// "Son Arama" bento kutusuna dokunma (`s-uygulama.jsx:90` `onAramaAc`): numara KAYITLIYSA
  /// müşteri sekmesine geçilip detayı açılır, KAYITSIZSA çağrı kartı gösterilir. Kararı çağrı
  /// günlüğü değil kabuk verir — o katman ne müşteri ekranını ne çağrı kartını tanır.
  Future<void> _aramaAc(AramaKaydi arama) async {
    final musteriId = arama.musteriId;
    if (musteriId == null) {
      // Çağrı günlüğünde eşleşme yoktu ama numara O ARADAN SONRA kaydedilmiş olabilir —
      // çözücü defteri yeniden okur, o hâlde kart dolu varyanta düşer.
      await _cagriKartiAc(arama.numara);
      return;
    }
    setState(() => _sekme = SipSekme.musteri);
    await _git(CustomerDetailScreen(
      db: widget.db,
      customerId: musteriId,
      writable: _yazilabilir,
      yetki: _yetki,
    ));
  }

  /// Bildirime dokunulduğunda gidilecek yer (Faz 1 sözlüğü: `gunsonu` · `musteri/<id>`).
  ///
  /// NEDEN BURADA: `yol` bildirim yükünde zaten taşınıyordu ama tüketen uç yoktu — bayi
  /// bildirime dokunuyor, uygulama ana ekranda açılıyor ve "ne vardı?" diye arıyordu.
  /// Taşınan bilgi kullanılmıyorsa taşınmıyor demektir.
  ///
  /// TANINMAYAN YOLDA SESSİZCE ANA EKRAN: sözlük ileride büyüyecek (bkz. çok-müşterili liste
  /// rotası, Faz 2) ve eski sürüm yeni bir yolu görebilir. Bilinmeyen yol bir hata değil,
  /// yalnız bilinmeyen bir hedeftir — patlamak yerine kullanıcıyı bulunduğu yerde bırakır.
  Future<void> _bildirimYoluAc(String yol) async {
    // Sözlüğün ÇÖZÜMÜ sözleşmede (`bildirimYoluCoz`): taslağı üreten kural ile onu tüketen
    // kabuk aynı tanıma bakmalı, iki ayrı ayrıştırma olmamalı.
    final hedef = bildirimYoluCoz(yol);
    if (hedef == null) return;
    if (hedef.tur == 'gunsonu') {
      setState(() => _sekme = SipSekme.gunSonu);
      return;
    }
    setState(() => _sekme = SipSekme.musteri);
    await _git(CustomerDetailScreen(
      db: widget.db,
      customerId: hedef.id!,
      writable: _yazilabilir,
      yetki: _yetki,
    ));
  }

  /// [YerelBildirimServisi.dokunulanYol] dinleyicisi. Değer tüketildikten sonra SIFIRLANIR:
  /// aksi hâlde aynı yol, sonraki her dinleyici kurulumunda yeniden açılırdı.
  void _bildirimDokunusu() {
    final yol = YerelBildirimServisi.dokunulanYol.value;
    if (yol == null || yol.isEmpty || !mounted) return;
    YerelBildirimServisi.dokunulanYol.value = null;
    unawaited(_bildirimYoluAc(yol));
  }

  Widget _govde(SipSekme sekme, RolYetkileri yetki) {
    if (_kilit) {
      return Column(
        children: [
          SipUst(baslik: 'Sipario', onMenu: () => setState(() => _cekmece = true)),
          Expanded(child: SubscriptionLockedScreen(bitis: _validUntil)),
        ],
      );
    }
    return switch (sekme) {
      SipSekme.ana => AnaEkran(
          db: widget.db,
          sahipAdi: _sahipAdi,
          onMenu: () => setState(() => _cekmece = true),
          onSekme: _sekmeSec,
          onYeniSiparis: _yeniSiparis,
          onArama: _aramaAc,
          onSiparisAc: _siparisAc,
          sonSenkron: _sonSenkron,
          sonSenkronAt: _sonSenkronAt,
        ),
      // onMenu HER sekmeye geçilir (s-uygulama.jsx: dört ana ekranın dördü de
      // `onMenu={() => setCekmece(true)}` alır). Geçilmezse `SipUst` hamburger yerine ya hiçbir şey
      // ya da geri oku çizer ve çekmece — Ürünler/Kuryeler/Muaf/Ayarlar/çıkış oradadır — yalnız Ana
      // sekmesinden açılabilir hâle gelir.
      SipSekme.musteri => CustomerListScreen(
          db: widget.db,
          writable: _yazilabilir,
          yetki: yetki,
          onMenu: () => setState(() => _cekmece = true),
        ),
      SipSekme.siparis => OrderListScreen(
          db: widget.db,
          writable: _yazilabilir,
          userId: _userId,
          canAssign: yetki.atama,
          onMenu: () => setState(() => _cekmece = true),
        ),
      SipSekme.gunSonu =>
        // `rol` ZORUNLU GİBİ davranılmalı: verilmezse ekran "yetki bilinmiyor" sayar ve HİÇ
        // kapatma sunmaz (`yetkiler(rol: null).gunSonu == false` — K2 sözleşmesi, permissive
        // değil). `kullaniciId` iki iş yapar: kurye ekranı KENDİ kapsamında açar, ve kapatma
        // yetkisinin sahibi odur. Çekmecenin kuryedeki "Kasa Devri" satırı buraya geliyor.
        DayEndScreen(
          db: widget.db,
          onMenu: () => setState(() => _cekmece = true),
          rol: _userRole,
          kullaniciId: _userId,
        ),
    };
  }
}

/// Abonelik süresi dolmuş ama lütuf penceresi sürüyor — NÖTR bilgi şeridi
/// (mağaza kuralı: fiyat/abone-ol/link YOK).
class _GraceBandi extends StatelessWidget {
  const _GraceBandi();

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      width: double.infinity,
      color: t.warnSoft,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SipIcon(SipIcons.info, boyut: 15, kalinlik: 2.2, renk: t.warn),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Abonelik süreniz doldu görünüyor; bağlantı kurulunca netleşecek.',
              style: SipText.metin(11.5, w: 600).copyWith(color: t.warn),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
