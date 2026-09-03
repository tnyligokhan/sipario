// ANA KABUK — s-uygulama.jsx (kök state + routing + rol/durum kapıları).
//
// Yerleşim (CSS `.app`): [çevrimdışı bandı] → `.app-icerik` (aktif sekme) → `.altnav` hap
// navigasyon; hepsinin üstünde soldan açılan `.cek` çekmecesi. Material `NavigationBar`/`Drawer`
// KULLANILMAZ — tasarımın hap navigasyonu ve hero zeminli çekmecesi onlarla kurulamıyor.
//
// KAPILAR:
//  • Rol (K2): `yetkiler(rol:, atamaHedefiVar:)` — ürün yönetimi yalnız yöneticide (çekmecenin YÖNETİM
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
import '../rehber/nasil_yapilir_ekrani.dart';
import '../rehber/rehber_hedef.dart';
import '../rehber/rehber_modeli.dart';
import '../rehber/rehber_sahne.dart';
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
import '../repo/call_log_repository.dart';
import '../repo/order_repository.dart';
import 'cagri/cagri_kuyrugu.dart';
import 'cagri/cagri_model.dart';
import 'customers/borclular_ekrani.dart';
import 'customers/customer_detail_screen.dart';
import 'customers/customer_form_screen.dart' show musteriEkleSheet;
import 'customers/customer_list_screen.dart';
import 'isletme/ayarlar/cihazlar_ekrani.dart';
import 'isletme/ayarlar/hesap_ekrani.dart';
import 'isletme/ayarlar_ekrani.dart';
import 'isletme/kuryeler_ekrani.dart';
import 'isletme/muaf_ekrani.dart';
import 'day_end_screen.dart';
import 'bildirimler_ekrani.dart';
import 'orders/order_detail_screen.dart';
import 'orders/order_queries.dart' show watchIptalTalebi;
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

// KABUK DÖRDE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 1022 satırdı). Bölme sınırları keyfi
// değil, kabuğun dört ayrı işi: durumu çevirmek · bir yere gitmek · çağrıya cevap vermek ·
// gövdeyi kurmak. Dördü de kabuğun ÖZEL alanlarını okuduğu için `part`tır (gerekçe
// `home_shell_cagri.dart` başlığında).
part 'home_shell_durum.dart';
part 'home_shell_gezinme.dart';
part 'home_shell_cagri.dart';
part 'home_shell_govde.dart';
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
      // `oturumKapandi` da OTURUM bandına düşer: kök zaten giriş ekranına dönüyor, ama bandın
      // o kareyi doğru anlatması gerekir (dönüş bir sonraki karede olur).
      SyncHataTuru.oturum || SyncHataTuru.oturumKapandi => SipBantTuru.oturum,
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

  /// ATANABİLECEK aktif personel (kendim dahil) — `watchAtamaHedefleri`. "Tek kişilik bayi"
  /// kararının dayanağı buradan çıkar ([_atamaHedefiVar]).
  List<User> _kuryeler = const [];

  /// Bu bayide BENDEN BAŞKA atanabilecek biri var mı?
  ///
  /// KENDİM SAYILMAM ve bu, BRIEF'in tek kişilik bayi kuralının tamamıdır: liste artık patronu
  /// da içerdiği için "liste boş değil" ölçütü tek kişilik bayide de doğru çıkardı ve malı zaten
  /// kendi götüren bayiye her siparişte anlamsız bir "kime atansın" adımı eklerdi.
  bool get _atamaHedefiVar => _kuryeler.any((u) => u.id != _userId);

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
    // Atanabilecek personel varlığı "tek kişilik bayi" kararının dayanağıdır (K2 atamaHedefiVar).
    // ROL SÜZGECİ YOK: siparişi oluşturan kişi kendisini de seçebilmeli (2026-08-20).
    _kuryeSub = watchAtamaHedefleri(widget.db).listen((k) {
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
    // ÇAĞRI KUYRUĞU ÖNE GELİŞTE BOŞALTILIR (2026-08-13 saha bulgusu: "arama yaptım, Son
    // Aramalar'a girdiğimde biraz geç geldi").
    //
    // Telefon çalarken/aranırken Flutter motoru çalışmaz; native, çağrıyı düz metin bir dosyaya
    // yazar. Kuyruğu YALNIZ çağrı geçmişi ekranı boşaltıyordu — yani kayıt, kullanıcı o ekranı
    // AÇTIKTAN SONRA yazılıyordu ve liste ilk karede onsuz çiziliyordu. Oysa uygulamaya dönüş
    // ANI, kuyruğun taze olduğu andır: görüşme biter, kullanıcı uygulamaya döner, satır çoktan
    // yerindedir.
    //
    // Ekrandaki boşaltma KALDI (ikinci güvence): dosya taşıma atomik ve kayıt kimlikleri
    // deterministik olduğu için iki kez boşaltmak çift satır üretmez (`insertOnConflictUpdate`).
    unawaited(CagriKuyrugu(CallLogRepository(widget.db)).bosalt());
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

  /// Durum değişiminin TEK KAPISI — `part` dosyalarındaki yüzeyler buradan geçer.
  ///
  /// NEDEN VAR: `setState` `@protected`tır ve bir extension, sınıfın kendisi değildir; parça
  /// dosyalardan doğrudan çağrılsaydı analizci `invalid_use_of_protected_member` derdi. Kapıyı
  /// daraltmak ayrıca şunu sağlıyor: kabuğun durumunu değiştiren her yol tek satırdan geçiyor.
  void _durumDegisti(VoidCallback f) => setState(f);
  bool get _yazilabilir => SubscriptionState.writable(_access);
  bool get _kilit => _access == AccessLevel.readOnly;

  RolYetkileri get _yetki =>
      yetkiler(rol: _userRole, atamaHedefiVar: _atamaHedefiVar, izin: _kuryeIzin);

  /// ÇEKMECE başlığı: işletme (firma) adı — tasarım `s-bilesenler.jsx:100` `{isletme.ad}`.
  String get _isletmeAdi => _tenantName ?? 'Sipario';

  /// ANA EKRAN hero'su: kullanıcının kendi adı — tasarım `s-ana.jsx:21` `{ISLETME.sahip}`.
  /// İkisine aynı değeri vermek (eski hâl) selamın altına firma unvanı bastırıyordu.
  String get _sahipAdi => _userName ?? _tenantName ?? 'Sipario';

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
                // Rehber hedefi KABUKTA: alt gezinme her sekmede aynı yerde durur, bir ekrana
                // ait değildir. `RehberHedef` yalnız anahtar takar — yerleşim değişmez.
                RehberHedef(
                  id: 'ana.altnav',
                  child: SipAltNav(
                    aktif: sekme,
                    onSec: _sekmeSec,
                    // Kilit kipinde FAB çizilir ama pasif (tasarım kilit dalında da AltNav'ı tam
                    // çizer); silinseydi hap navigasyon yeniden yerleşip atlıyordu.
                    onEkle: _yazilabilir ? _ekleMenusu : null,
                  ),
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
                SipToast.goster(context, 'Destek sohbeti yakında açılacak');
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

}
