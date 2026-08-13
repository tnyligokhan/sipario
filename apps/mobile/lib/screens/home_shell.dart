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
// satırdır — rol yalnız YÖNETİM bölümünü etkiler (`s-bilesenler.jsx:106`). Gün Özeti sekmesi
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
import '../konum/konum_bildirici.dart';
import '../subscription/subscription_locked_screen.dart';
import '../subscription/subscription_state.dart';
import '../sync/sync_service.dart';
import '../sync/yenileme.dart';
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
import 'cagri/cagri_gunlugu.dart';
import 'cagri/cagri_karti.dart';
import 'cagri/cagri_kuyrugu.dart';
import 'cagri/cagri_model.dart';
import 'customers/borclular_ekrani.dart';
import 'customers/customer_detail_screen.dart';
import 'customers/customer_form_screen.dart' show musteriEkleSheet;
import 'customers/customer_list_screen.dart';
import 'isletme/ayarlar/hesap_ekrani.dart';
import 'isletme/ayarlar_ekrani.dart';
import 'isletme/kuryeler_ekrani.dart';
import 'isletme/muaf_ekrani.dart';
import 'day_end_screen.dart';
import 'orders/order_detail_screen.dart';
import '../phase0/phase0_screen.dart';
import 'orders/order_form_screen.dart';
import 'orders/order_sheets.dart' show SecimSatiri;
import 'orders/order_list_screen.dart';
import 'orders/siparis_harita.dart';
import 'products/product_list_screen.dart';
import 'shell/alt_nav.dart';
import 'shell/cekmece.dart';
import 'shell/sekme_yonlendirme.dart';
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
      SyncHataTuru.sunucu => SipBantTuru.sunucu,
      SyncHataTuru.veri => SipBantTuru.hata,
      SyncHataTuru.ag || SyncHataTuru.yok => SipBantTuru.cevrimdisi,
    };

/// Bandın alt satırında yazacak SUNUCU ADI — taban adresin ana bilgisayar kısmı (varsa portuyla).
///
/// Tam URL yazılmaz: `https://…/api/v1` bandı iki katına çıkarır ve bayiye hiçbir şey katmaz;
/// arızayı ayırt eden kısım ana bilgisayardır (tünel adresi her açılışta değişiyor). Şema
/// çözülemezse ham metin döner — yanlış adresin kendisi zaten aranan kanıttır. Saf fonksiyon.
String? bantAdresi(String? baseUrl) {
  final ham = baseUrl?.trim();
  if (ham == null || ham.isEmpty) return null;
  final u = Uri.tryParse(ham);
  if (u == null || u.host.isEmpty) return ham;
  return u.hasPort ? '${u.host}:${u.port}' : u.host;
}

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

  /// BU OTURUMUN ETKİN kurye yetkileri (2026-08-04; kişiselleştirme 2026-08-10). Bayi
  /// varsayılanı ile kullanıcının kendi ezmeleri çözülmüş hâlde gelir. AKIŞTAN okunur çünkü
  /// tek atış okuma, ayar değiştikten sonra kuryenin ekranını bir sonraki açılışa kadar eski
  /// yetkiyle bırakırdı.
  KuryeIzinleri _kuryeIzin = KuryeIzinleri.varsayilan;

  StreamSubscription<SyncOutcome>? _syncSub;
  StreamSubscription<List<User>>? _kuryeSub;
  StreamSubscription<KuryeIzinleri>? _izinSub;
  StreamSubscription<SyncMetaData>? _metaSub;
  StreamSubscription<int>? _karantinaSub;
  SyncOutcome? _sonSenkron;
  DateTime? _sonSenkronAt;

  /// Karantinadaki (sunucunun kabul etmediği) outbox kaydı sayısı — akıştan gelir, tur bitince
  /// kaybolmaz. Sıfırdan büyükse bant durur.
  int _karantina = 0;

  /// Borçlu müşteri sayısı — çekmecedeki "Borçlular" satırının rozeti. AKIŞTAN okunur:
  /// tahsilat yapıldığında sayı düşmeli, tek atış okuma menüyü bayat bir sayıyla bırakırdı.
  /// null iken rozet çizilmez (uydurma sayı basmaktansa hiç basmamak).
  int? _borcluSayisi;
  StreamSubscription<int>? _borcluSub;

  /// Bandın alt satırında gösterilecek sunucu adresi (sync_meta akışından).
  String? _apiAdres;

  late final TemaKontrol _tema =
      widget.tema ?? TemaKontrol(depo: TemaDeposu.bellek());

  /// Sessiz konum kalp atışı. Kabuk uygulamanın AÇIK olduğu tek yaşam döngüsü noktası:
  /// arka plan izni istenmediği için (verilmiş karar) sayacın ömrü bu ekranınkiyle aynıdır.
  /// OTURUM YOKSA HİÇ BAŞLAMAZ — kapı [_metaUygula] içinde, akıştan okunan token'dadır.
  late final KonumBildirici _konumBildirici = KonumBildirici(widget.db);

  /// Akıştan görülen SON oturum durumu (`_metaUygula` yazar). Yaşam döngüsü geri dönüşünde
  /// sayacı başlatıp başlatmamaya bununla karar verilir — tek atış DB okuması yerine.
  bool _oturumVar = false;

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
    // Karantina AKIŞTAN okunur, `SyncOutcome`dan değil: karantinaya alınan olay bir daha
    // gönderilmediği için sonraki turlar temiz geçer — tur başına bir sayaca bakan bant, uyarıyı
    // ilk turda kaybederdi. Kayıt cihazda durduğu SÜRECE uyarı da durmalı.
    _karantinaSub = widget.db.watchKarantinaSayisi().listen((n) {
      if (mounted) setState(() => _karantina = n);
    });
    _borcluSub = watchDebtCount(widget.db).listen((n) {
      if (mounted) setState(() => _borcluSayisi = n);
    });
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
    // OTURUMUN ETKİN izinleri (2026-08-10): bayi varsayılanı DEĞİL, bu kullanıcının kişisel
    // ezmeleriyle çözülmüş hâli. `watchKuryeIzinleri` artık yalnız şablonu verir; kabuk onu
    // dinlemeye devam etseydi, kişiye özel olarak KAPATILAN bir yetki kuryenin kendi
    // telefonunda açık görünürdü.
    _izinSub = watchOturumKuryeIzinleri(widget.db).listen((i) {
      if (!mounted) return;
      setState(() => _kuryeIzin = i);
    });
    // "Aşağı çekerek yenile" beş ekranda kullanılıyor ve hepsi kabuk tarafından farklı
    // yollardan kuruluyor (sekme · Navigator.push). Servisi her ekranın imzasına eklemek
    // yerine bir kez bağlanır — `guncellemeServisi` tekilinin aynı deseni.
    yenilemeyiBagla(widget.sync);
    // Bitmiş bir işin sonucunu doğru sekmede göstermek için (ör. sipariş kaydı → siparişler).
    // Aynı gerekçe, aynı desen: yönlendirmeyi zincirin dört halkasından geri taşımak yerine
    // kabuk kendini bir kez bağlar (`sekme_yonlendirme.dart` başlığındaki not).
    sekmeYonlendirmeyiBagla(_sekmeyeYonlendir);

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
    // Konum sayacı ARKA PLANDA DURUR (inceleme bulgusu 2026-07-30): eskiden yalnız oturum
    // kapanışı/dispose durduruyordu ve arka planda 30 sn'de bir boşuna uyanıyordu. Bugün OS
    // arka planda konum vermediği için tur zaten düşüyordu — ama "arka planda bildirilmez"
    // sözünün teminatı işletim sistemi değil BU KOD olmalı: biri ileride arka plan iznini
    // eklerse takip kendiliğinden başlamamalı. `inactive`de DURDURULMAZ: bildirim perdesi ve
    // izin diyaloğu gibi geçici örtüler de inactive üretir; her kapanışta yeniden başlatmak
    // (`baslat()` anında bir tur atar) fazladan kalp atışı yağdırırdı.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _konumBildirici.durdur();
      // Senkron aralığı da GEVŞER (2026-08-09 kararı): ekrana bakılmayan cihazda 30 sn'de bir
      // uyanmak pili boşuna yakar. `inactive` BURAYA GİRMEZ — bildirim perdesi ve izin diyaloğu
      // da inactive üretir, kullanıcı hâlâ uygulamanın başındadır (konum sayacının aynı gerekçesi).
      widget.sync.aralikDegistir(SyncService.arkaPlanAralik);
    }
    if (state != AppLifecycleState.resumed) return;
    // Öne gelişte sayaç oturum varsa geri döner; kapı yine akıştan gelen SON token'dadır
    // (`_metaUygula` her meta değişiminde günceller — burada tek atış DB okuması yapılmaz).
    if (_oturumVar) _konumBildirici.baslat();
    // Öne gelen cihaz SIKI aralığa döner. Patronun yazımı artık anında push ediliyor (yazım
    // tetiği) ama KURYE onu ancak kendi pull'unda görür; 2 dakika, elinde telefonla bekleyen
    // kurye için "gelmiyor" demektir ve çözümü "yenilemeye bas" olamaz. `aralikDegistir` tur
    // ATMAZ — aşağıdaki satır zaten atıyor, çift istek olmasın.
    widget.sync.aralikDegistir(SyncService.onPlanAralik);
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
    _izinSub?.cancel();
    _metaSub?.cancel();
    _karantinaSub?.cancel();
    _borcluSub?.cancel();
    _konumBildirici.durdur();
    cagriEylemDurtusunuBirak();
    sekmeYonlendirmeyiCoz();
    YerelBildirimServisi.dokunulanYol.removeListener(_bildirimDokunusu);
    SipToast.temizle();
    super.dispose();
  }

  /// Bir iş bittiğinde (ör. sipariş kaydı) kabuğu hedef sekmeye alır ve ÜSTÜNDEKİ push'ları
  /// kapatır. `popUntil` şart: müşteri kartından açılan formda yalnız sekmeyi değiştirmek,
  /// altta duran siparişler sekmesini kullanıcıya hiç göstermezdi (üstte kart durmaya devam
  /// ederdi) — ve geri tuşu onu yeni bitirdiği forma değil ama bitirdiği işin BAŞLANGICINA
  /// döndürürdü.
  void _sekmeyeYonlendir(SipSekme sekme) {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    _sekmeSec(sekme);
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
    // Konum bildirimi OTURUMA bağlıdır: giriş yapılınca sayaç döner, çıkışta durur. Kabuğun
    // `initState`inde koşulsuz başlatılsaydı, oturumsuz açılan uygulamada (giriş ekranı arkası,
    // testler) 30 sn'de bir boşuna uyanan bir zamanlayıcı kalırdı. `_oturumVar` aynı kapının
    // yaşam döngüsü tarafı: öne gelişte yeniden başlatma kararı bu son değeri okur.
    _oturumVar = meta.authToken != null;
    if (_oturumVar) {
      _konumBildirici.baslat();
    } else {
      _konumBildirici.durdur();
    }
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
      // Bandın adres satırı. `Session.baseUrlOf` varsayılana düşer → adres HER ZAMAN yazılır;
      // "hiçbir adres yok" da bir bilgi olurdu ama gerçekte olmayan bir durum.
      _apiAdres = bantAdresi(Session.baseUrlOf(meta));
      // Çekmecedeki "Oto sıralama bakiyesi" kartı (tasarım `.lst-kart`). Kota 0 ise sunucu
      // henüz bildirmemiş demektir → kart çizilmez (oran hesaplanamaz, uydurma çubuk çizmeyiz).
      _otoHak = meta.routeCreditsMonthly > 0 ? meta.routeCredits : null;
      _otoAylik = meta.routeCreditsMonthly > 0 ? meta.routeCreditsMonthly : null;
    });
  }

  bool get _yazilabilir => SubscriptionState.writable(_access);
  bool get _kilit => _access == AccessLevel.readOnly;

  RolYetkileri get _yetki =>
      yetkiler(rol: _userRole, kuryeVar: _kuryeler.isNotEmpty, izin: _kuryeIzin);

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
      case CekmeceGiris.borclular:
        // Bento kutusuyla AYNI fonksiyon: iki giriş noktası, TEK yetki kapısı. Ayrı yazsaydık
        // ikisi zamanla ayrışırdı — bu depoda aynı ekranın iki girişinin farklı yetkiyle
        // açılması bir güvenlik açığına dönüştü (bkz. `CustomerDetailScreen.yetki`).
        setState(() => _cekmece = false);
        _borclularAc();
      case CekmeceGiris.cagriGunlugu:
        _cagriGecmisiAc();
      case CekmeceGiris.harita:
        _git(SiparisHaritaEkrani(db: widget.db, writable: _yazilabilir));
      case CekmeceGiris.hesap:
        _git(HesapEkrani(db: widget.db, session: widget.session, onCikis: _cikis));
      case CekmeceGiris.urunler:
        if (!_yetki.urunYonetimi) {
          SipToast.goster(context, 'Ürün yönetimi yalnız yöneticilere açıktır.');
          return;
        }
        _git(ProductListScreen(db: widget.db, writable: _yazilabilir, rol: _userRole));
      case CekmeceGiris.kuryeler:
        _git(KuryelerEkrani(db: widget.db, writable: _yazilabilir));
      case CekmeceGiris.muaf:
        if (!_yetki.muafTelefonYonetimi) {
          SipToast.goster(context, 'Muaf telefon yönetimi yalnız yöneticilere açıktır.');
          return;
        }
        _git(MuafEkrani(db: widget.db, writable: _yazilabilir));
      case CekmeceGiris.ayarlar:
        _git(AyarlarEkrani(
          db: widget.db,
          rol: _userRole,
          yetki: _yetki,
          writable: _yazilabilir,
          // Hesap sayfası hem çekmeceden hem ayarlar hub'ından açılır; ikisi de AYNI ekranı
          // ve AYNI çıkış akışını kullanır (çıkış onayı + oturum temizliği tek yerde).
          session: widget.session,
          onCikis: _cikis,
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
    }
  }

  /// Dükkânın çağrı geçmişi. GİRİŞİ ÇEKMECEDEDİR (2026-08-13) — eskiden Ayarlar → Arayan
  /// Tanıma bölümünün içindeydi ve orası yanlış yerdi: bu bir İŞ KAYDIDIR, bir tercih değil.
  /// Ayarların içinde üç dokunuş derinlikteydi; şimdi hangi sekmede olunursa olunsun iki.
  ///
  /// Kapı `cagriGunlugu`dur ve çekmece satırı da aynı ölçütle çizilir; burası ikinci kapı.
  void _cagriGecmisiAc() {
    if (!_yetki.cagriGunlugu) {
      SipToast.goster(context, 'Çağrı geçmişi bu hesaba kapalı.');
      return;
    }
    _git(CagriGunluguSayfasi(
      db: widget.db,
      onGeri: () => Navigator.of(context).maybePop(),
      onAc: _aramayiAc,
    ));
  }

  /// Bir arama satırına dokunulduğunda (s-uygulama.jsx:90 kuralı): kayıtlıysa müşteri defteri,
  /// kayıtsızsa çağrı kartı.
  ///
  /// AYARLAR EKRANINDAN BURAYA TAŞINDI ve taşınırken bir açık kapandı: oradaki kopya müşteri
  /// kartını `yetki` GEÇMEDEN açıyordu, yani `cagriGunlugu` açılmış bir kurye o yoldan yönetici
  /// eylemlerine ulaşıyordu. Kabuk yetkiyi zaten taşıyor; ekranın kabukta yaşaması bu sınıf
  /// hatayı yapısal olarak zorlaştırıyor.
  ///
  /// Kayıt durumu DOKUNMA ANINDA yeniden çözülür: geçmiş satırı çağrı ANINDAKİ eşleşmeyi taşır
  /// ve arayan o çağrıdan sonra müşteri olarak kaydedilmiş olabilir.
  Future<void> _aramayiAc(AramaKaydi arama) async {
    final kisi = await cagriKisiCoz(widget.db, arama.numara);
    if (!mounted) return;

    final musteriId = arama.musteriId ?? kisi.musteriId;
    if (musteriId != null) return _musteriAc(musteriId);

    // Yön GEÇMİŞ SATIRINDAN gelir: kart yönü kendi başına bilemez, verilmezse "GELEN ÇAĞRI"
    // varsayar ve bayi kendi yaptığı aramanın kartında gelen çağrı görürdü.
    final eylem = await cagriKartiGoster(context, kisi: kisi, yon: arama.tip);
    if (eylem != CagriEylemi.kaydet || !mounted) return;

    if (!_yazilabilir) {
      SipToast.goster(context, 'Salt-okunur kip: yeni müşteri eklenemez.');
      return;
    }
    final eklendi = await musteriEkleSheet(context, db: widget.db, onTel: arama.numara);
    if (eklendi != true || !mounted) return;

    final yeni = await cagriKisiCoz(widget.db, arama.numara);
    final yeniId = yeni.musteriId;
    if (yeniId == null || !mounted) return;
    await _musteriAc(yeniId);
  }

  Future<void> _musteriAc(String musteriId) => _git(CustomerDetailScreen(
        db: widget.db,
        customerId: musteriId,
        writable: _yazilabilir,
        yetki: _yetki,
      ));

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

  /// En üstteki senkron bandının türü — çizilecek bant yoksa null.
  ///
  /// ÖNCELİK canlı tur hatasındadır: o AN ne olduğunu anlatır ve genelde eylem gerektirir
  /// (yeniden giriş / bekleme). Karantina uyarısı kalıcıdır, bir sonraki temiz turda zaten
  /// görünür — iki bandı üst üste çizmek ise durum çubuğunu ve yerleşimi bozardı.
  /// ÜÇÜNCÜ SIRA `bekleyen` (2026-08-09 borcu kapatıldı): sunucunun BİLEREK ertelediği kayıtlar
  /// (`locked` = abonelik kilitli · bilinmeyen durum = sürüm çarpıklığı). Karantinanın ALTINDA
  /// çünkü karantina eylem gerektirir (destek), bu ise kendiliğinden çözülür. Ama sessiz de
  /// kalamazdı: sayı hesaplanıp taşınıyordu, hiçbir yüzey OKUMUYORDU — tur "başarılı" sayıldığı
  /// için çip "güncel" derken kayıtlar cihazda birikiyordu. Kilitli bayide zaten kilit ekranı var;
  /// asıl korunan senaryo SÜRÜM ÇARPIKLIĞI — orada hiçbir başka sinyal yok.
  SipBantTuru? get _senkronBandi {
    final o = _sonSenkron;
    if (o != null && !o.ok) return bantTuru(o.tur);
    if (_karantina > 0) return SipBantTuru.karantina;
    return (o?.beklemede ?? 0) > 0 ? SipBantTuru.bekleyen : null;
  }

  /// Güncelleme bandının ÜSTÜNDE çizilen bir bant var mı (senkron / grace)? Durum çubuğu
  /// boşluğunu yalnız EN ÜSTTEKİ bant ekler.
  bool get _ustBantVar => _senkronBandi != null || _access == AccessLevel.grace;

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
                if (_senkronBandi != null)
                  SafeArea(
                    bottom: false,
                    child: SipCevrimdisiBant(tur: _senkronBandi!, adres: _apiAdres),
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
                  onEkle: _yazilabilir ? _ekleMenusu : null,
                ),
              ],
            ),
            SipCekmece(
              acik: _cekmece,
              onKapat: () => setState(() => _cekmece = false),
              isletmeAdi: _isletmeAdi,
              rol: _userRole,
              onGiris: _cekmeceGirisi,
              onCikis: _cikis,
              onDestek: () {
                setState(() => _cekmece = false);
                SipToast.goster(context, 'Destek sohbeti · yakında');
              },
              kullaniciAdi: _userName,
              sonSenkron: _sonSenkronAt,
              // Karantina sayısı çekmecenin DURUM şeridine geçer: "bazı kayıtlar
              // gönderilemedi" bandı ekranın tepesinde çıkıyor ama menüde hiçbir izi yoktu.
              karantina: _karantina,
              // Borçlu sayısı satırda rozet olur — menü "nereye giderim" listesinden
              // "neye bakmam gerek" yüzeyine dönüyor.
              borcluSayisi: _borcluSayisi,
              urunlerGorunur: yetki.urunYonetimi,
              // GÖRÜNÜRLÜK KARARLARI KABUKTA (çekmece hiçbir yetki KARARI vermez, verileni
              // çizer): bento kutusuyla çekmece satırı AYNI kapıdan geçsin diye ölçüt burada
              // tek yerde okunuyor.
              borclularGorunur: yetki.toplamBorclulariGorme,
              cagriGunluguGorunur: yetki.cagriGunlugu,
              koyuTema: _tema,
              onTema: _tema.ayarla,
              lisansBitisi: _validUntil,
              otoSiralamaHakki: _otoHak,
              otoSiralamaAylik: _otoAylik,
            ),
          ],
        ),
      ),
    );
  }

  void _yeniSiparis() =>
      _git(OrderFormScreen(db: widget.db, writable: _yazilabilir));

  /// FAB menüsü (kullanıcı kararı 2026-07-29): "Müşteri Ekle" · "Sipariş Ekle".
  ///
  /// Eskiden FAB doğrudan sipariş formunu açıyordu ve müşteri ekleme yalnız Müşteriler
  /// ekranının "Yeni"sinde yaşıyordu. Menü İKİ SATIRDIR, üçüncü bir şey EKLENMEZ: FAB'ın değeri
  /// bir dokunuşla en sık iki işi başlatmasıdır, dolan bir menü onu bir alt menüye çevirir.
  ///
  /// Kapı `_yazilabilir` üzerinden ÇAĞIRANDA (FAB pasif çizilir); burada ikinci bir kontrol
  /// yapılmaz — iki yerde ayrı koşul, ayrışabilen iki kural demektir.
  Future<void> _ekleMenusu() async {
    // KURYE YETKİLERİ (2026-08-04): bayi kapattıysa satır HİÇ ÇİZİLMEZ — gizlemek burada
    // doğrudur çünkü yetki kalıcı olarak kapalıdır; her dokunuşta aynı reddi okutmak gürültü
    // olurdu (BRIEF'in "tek kişilik bayide o adım hiç görünmesin" ilkesinin aynısı). İkisi de
    // kapalıysa menü hiç açılmaz, tek bir cümleyle sebep söylenir.
    final yetki = _yetki;
    if (!yetki.musteriDuzenleme && !yetki.siparisAcma) {
      SipToast.goster(context, 'Bu hesap yeni kayıt ekleyemez — bayi yetkisi kapalı.');
      return;
    }

    final secim = await sipSheet<String>(
      context,
      baslik: 'Yeni Ekle',
      govde: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (yetki.musteriDuzenleme)
            SecimSatiri(
              etiket: 'Müşteri Ekle',
              ikon: SipIcons.user,
              secili: false,
              onTap: () => Navigator.of(ctx).pop('musteri'),
            ),
          if (yetki.siparisAcma)
            SecimSatiri(
              etiket: 'Sipariş Ekle',
              ikon: SipIcons.list,
              secili: false,
              onTap: () => Navigator.of(ctx).pop('siparis'),
            ),
        ],
      ),
    );
    if (secim == null || !mounted) return;
    if (secim == 'siparis') return _yeniSiparis();
    final eklendi = await musteriEkleSheet(context, db: widget.db);
    if (eklendi == true && mounted) SipToast.goster(context, 'Müşteri kaydedildi');
  }

  /// "Borçlular" bento kutusu — Genel Yetki Matrisinde kuryelere kısıtlıdır.
  void _borclularAc() {
    if (!_yetki.toplamBorclulariGorme) {
      SipToast.goster(context, 'Toplam borçlular listesi yalnız yöneticilere açıktır.');
      return;
    }
    _git(BorclularEkrani(
      db: widget.db,
      writable: _yazilabilir,
      yetki: _yetki,
      canAssign: _yetki.atama,
    ));
  }

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
        // Çağrı kartı native taraftan da gelebilir ve yetkiyi bilmez; kapı BURADA (2026-08-04).
        if (!_yetki.siparisAcma) {
          SipToast.goster(context, 'Bu hesap sipariş oluşturamaz — bayi yetkisi kapalı.');
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
          onBorclular: _borclularAc,
          borclulariGoster: yetki.toplamBorclulariGorme,
          // Sipariş listesiyle AYNI kapsam: kurye kilitliyse bento de yalnız ona atananları sayar.
          acikSiparisKullanicisi: yetki.tumSiparisleriGorme ? null : _userId,
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
          // Kurye kısıtlamalarının kaynağı (2026-08-09): `tumSiparisleriGorme` kapalıysa liste
          // oturum kullanıcısına kilitlenir, `gecmisTeslimatlariGorme` kapalıysa gün şeridi
          // çizilmez. İkisi de burada verilir ki rol yorumu TEK yerde kalsın.
          yetki: yetki,
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
          // Kurye izinleri de geçer (2026-08-09): ekran `gunuKapatma` ve `gecmisHesapArsivi`
          // kapılarını buradan türetiyor. Geçilmezse varsayılan izinlerle karar verir ve
          // bayinin kendi ayarı yok sayılırdı.
          kuryeIzin: _kuryeIzin,
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
