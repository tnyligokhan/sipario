// SİPARİŞ HARİTASI — açık siparişlerin durakları, rota sırasında numaralı pinlerle.
//
// NEDEN VAR: "Oto Sırala (rota)" bir SIRA üretiyordu ama kurye o sıranın yeryüzünde neye
// benzediğini göremiyordu. Liste "1, 2, 3" der; harita "önce şu mahalle, sonra dönüp bu sokak"
// der ve saçma bir rotayı kurye tek bakışta yakalar.
//
// ÜÇ KURAL:
//  • VERİ yalnız AÇIK siparişlerdir (teslim edileni haritada göstermek yapılacak işi şişirir).
//    Koordinatı olmayan açık sipariş haritaya GİRMEZ ama SAYISI üstte yazar — sessizce yutmak
//    kuryeye eksik rota koşturur.
//  • KARO SAĞLAYICI tek dikişten geçer ([haritaKaroSaglayici]): üretimde ağ, testte sahte.
//    Widget testi ağa ASLA çıkmaz (`adresAdaylariGetir` deseninin aynısı).
//  • KARO YÜKLENEMEZSE (çevrimdışı) harita gri kalır, PİNLER YİNE ÇİZİLİR. Offline-first sözü
//    burada da geçerli: internet yoksa özellik kapanmaz, zemin kaybolur.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/app_database.dart';
import '../../konum/cihaz_konumu.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import 'harita_isaretler.dart';
import 'harita_karo_kaynagi.dart';
import 'harita_kontrolleri.dart';
import 'harita_kurye_katmani.dart';
import 'harita_sorgulari.dart';
import 'order_detail_screen.dart';
import 'oto_siralama.dart';
import 'siparis_harita_ozet.dart';

// Pinler ve konumsuz bandı 500 satır sınırı için ayrı dosyaya taşındı; harita ekranının DIŞ
// YÜZEYİ değişmez — çağıranlar ve testler onları hâlâ bu dosyadan tanır (sözleşme).
export 'harita_isaretler.dart' show CihazPini, DurakPini, KonumsuzBant;

// KARO STİLİ — CARTO **Positron** (açık) / **Dark Matter** (koyu), gri-minimal OSM tabanı.
//
// HAM OSM KAROSUNDAN NEDEN VAZGEÇİLDİ (cihazda ekran görüntüsüyle görüldü): standart `tile.
// openstreetmap.org` katmanı kırmızı otoyollar, yol numarası etiketleri ve yoğun POI
// simgeleriyle geliyor. Uygulamanın sade/aydınlık dilinin yanında gürültü gibi duruyordu ve
// asıl iş olan MOR PİNLER bu kalabalıkta kayboluyordu. Positron ana yolları nötr griyle çizer,
// POI basmaz — pinler tek bakışta öne çıkar. Koyu tema Dark Matter'a geçer (saha bulgusu
// 2026-07-29: koyu temada bembeyaz harita "bozuk" izlenimi veriyordu).
//
// ADRES ARTIK KENDİ SUNUCUMUZ (2026-09-26): CARTO anahtarsız karo vermeyi kesti ve her karonun
// yerinde "API KEY REQUIRED" filigranı çıktı. Anahtar sunucuda kalır; şablon ve jeton
// [HaritaKaroKaynagi]'ndadır.

/// Kullanım şartı: istekler uygulamayı TANITMALI. Gerçek applicationId
/// (`android/app/build.gradle.kts`) yazılır — uydurma bir ad, kotanın kime ait olduğunu gizler.
const String kHaritaUygulamaAdi = 'com.sipario.app';

/// Üretim karo sağlayıcısı — İPTAL + DİSK ÖNBELLEĞİ. İptal (2026-07-29 "harita çok kasıyor"):
/// kadraj dışı karonun isteği kesilir (`abortObsoleteRequests`, varsayılan açık). Önbellek
/// (2026-09-28 "gri kareler uzun süre boş kalıyor"): önceki `CancellableNetworkTileProvider`
/// eklentisinin diske önbelleği YOKTU, her açılışta bütün karolar sıfırdan iniyordu. Çekirdek
/// sağlayıcı `BuiltInMapCachingProvider` kullanır, tazeliği sunucunun `max-age`inden okur.
/// Ayrı fonksiyon: bu söz, testlerin sahteyle değiştirdiği dikişten bağımsız sınanır.
TileProvider varsayilanKaroSaglayici() => NetworkTileProvider();

/// Karo sağlayıcının TEK dikişi. Üretimde ağdan indirir; widget testleri bunu sahtesiyle
/// değiştirir ve test hiçbir zaman ağa çıkmaz (`adresAdaylariGetir` / `cihazKonumuOku` deseni).
TileProvider Function() haritaKaroSaglayici = varsayilanKaroSaglayici;

/// Açık siparişlerin haritası. Pin numaraları listedeki sırayı (oto sıralamadan sonra ROTA
/// sırasını) taşır ve "Oto Sırala" düğmesi de burada durur — sıra üretildiği ekranda görünür.
class SiparisHaritaEkrani extends StatefulWidget {
  const SiparisHaritaEkrani({
    super.key,
    required this.db,
    required this.writable,
    this.canAssign = false,
  });

  final AppDatabase db;

  /// Pine dokununca açılan detay sheet'ine geçirilir; ayrıca "Oto Sırala" KAPISIDIR — sıra
  /// `sort_set` olayı yazar, salt-okunur kipte düğme pasif çizilir ve gerekçesi yazar.
  final bool writable;
  final bool canAssign;

  @override
  State<SiparisHaritaEkrani> createState() => _SiparisHaritaEkraniState();
}

class _SiparisHaritaEkraniState extends State<SiparisHaritaEkrani> {
  late final Stream<HaritaVerisi> _veri = watchHaritaDuraklari(widget.db);

  /// Cihazın konumu — alınabildiyse ayrı bir işaretle çizilir. Alınamazsa harita ENGELLENMEZ:
  /// kuryenin nerede olduğu bir kolaylıktır, durakların yeri ise asıl iştir.
  LatLng? _cihaz;

  /// Kalan oto-sıralama hakkı (sunucu sahipli, senkronla iner). null = HENÜZ BİLİNMİYOR →
  /// düğme kontör YAZMADAN, PASİF çizilir. Uydurma bir sayı göstermek yasak: kullanıcı
  /// "34 hakkım var" deyip tıkladığında sunucu 409 dönerse güven kaybolur.
  int? _otoHak;

  /// Karo adresi + jeton — ilk senkron durumu okunana dek null (karo katmanı henüz çizilmez).
  HaritaKaroKaynagi? _karo;
  StreamSubscription<SyncMetaData>? _metaAbone;

  /// İstek yolda mı — kontörlü eylemde ikinci dokunuş ikinci hak demektir.
  bool _otoKosuyor = false;

  /// Bu ekranda EN AZ BİR kez sıra yazıldı mı. Geri dönerken listeye sinyal olarak verilir;
  /// liste bunu görünce "Rota sırası" kipine geçer. Sinyal Navigator sonucudur: iki ekran
  /// arasında paylaşılan bir bayrak tutmak, ekranlardan biri kapandığında bayat kalırdı.
  bool _otoYapildi = false;

  @override
  void initState() {
    super.initState();
    _cihazKonumunuDene();
    // AKIŞA abone olunur, tek atış okunmaz: kontör sunucu sahiplidir ve GİRİŞ YANITINDA
    // GELMEZ — ilk senkron yazar. Tek atış okuma girişten hemen sonra 0 görür ve ekran
    // sonsuza dek "0 hak" gösterir (cihazda bu hâliyle yakalandı).
    _metaAbone = widget.db.watchSyncState().listen((meta) {
      // Oturum yoksa (token null) çevrimiçi eylem hiç sunulmaz.
      final yeni = meta.authToken == null ? null : meta.routeCredits;
      // Karo kaynağı da buradan: API adresi ve oturum jetonu senkron durumundadır.
      final karo = HaritaKaroKaynagi.meta(meta);
      if (!mounted || (yeni == _otoHak && karo == _karo)) return;
      setState(() {
        _otoHak = yeni;
        _karo = karo;
      });
    });
  }

  @override
  void dispose() {
    _metaAbone?.cancel();
    super.dispose();
  }

  Future<void> _cihazKonumunuDene() async {
    try {
      final k = await cihazKonumuOku();
      if (!mounted) return;
      setState(() => _cihaz = LatLng(k.lat, k.lng));
    } on Object {
      // İzin yok / GPS kapalı / eklenti yok: SESSİZ. Kullanıcı buraya duraklarını görmeye geldi,
      // konum uyarısı almaya değil (o uyarıyı "Konum Güncelle" akışı zaten veriyor).
    }
  }

  /// "Konumum" düğmesi — TAZE okuma. Açılıştaki denemeden farklı olarak SESSİZ DEĞİLDİR:
  /// kullanıcı bilerek dokundu, bir şey olmazsa nedenini duymalı.
  ///
  /// Dönen değer kamerayı taşımak için görünüme geri verilir; `null` = konum yok, kamera oynamaz
  /// (kuryeyi bilmediğimiz bir noktaya götürmek, hiç götürmemekten kötüdür).
  Future<LatLng?> _konumumaGit() async {
    try {
      final k = await cihazKonumuOku();
      if (!mounted) return null;
      final nokta = LatLng(k.lat, k.lng);
      setState(() => _cihaz = nokta);
      return nokta;
    } on Object catch (e) {
      if (!mounted) return null;
      // Sebep AYRI AYRI söylenir (`cihaz_konumu.dart` kuralı): "izin verilmedi" ile "GPS kapalı"
      // kullanıcının yapacağı işi değiştirir. Tanınmayan arızada nötr cümleye düşülür.
      SipToast.goster(context, e is KonumHatasi ? e.mesaj : 'Konum alınamadı');
      return null;
    }
  }

  /// "Oto Sırala" — akış `oto_siralama.dart`ta, burada yalnız kilit, bekleme ve toast var.
  Future<void> _otoSirala() async {
    if (_otoKosuyor) return;
    setState(() => _otoKosuyor = true);
    final sonuc = await otoSiralaKos(widget.db);
    if (!mounted) return;
    setState(() {
      _otoKosuyor = false;
      // Sıra yazıldıysa pinler AKIŞTAN kendiliğinden yeniden numaralanır; ekranın yapacağı
      // tek şey listeye dönüşte verilecek sinyali işaretlemek.
      if (sonuc.basarili) _otoYapildi = true;
    });
    SipToast.goster(context, sonuc.mesaj);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    // Donanım geri tuşu da sonucu TAŞIMALI: `pop()` sonuçsuz dönseydi kullanıcı rotayı
    // sıralayıp geri tuşuna bastığında liste hâlâ saat sırasında kalırdı.
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_otoYapildi);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<HaritaVerisi>(
            stream: _veri,
            builder: (context, snap) {
              final veri = snap.data;
              // HATA YUTULMAZ (2026-08-09 saha arızası): eskiden yalnız `snap.data`ya bakılıyordu,
              // yani sorgu PATLADIĞINDA `veri` sonsuza dek null kalıyor ve ekran "Yükleniyor"
              // iskeletinde donuyordu. Kullanıcı bekliyor, hiçbir şey gelmiyor, sebep hiçbir yerde
              // görünmüyor. Bu deponun defalarca bedel ödediği SESSİZ ARIZA sınıfının aynısı.
              final hata = snap.hasError;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SipUst(
                    baslik: 'Harita',
                    alt: hata
                        ? 'Yüklenemedi'
                        : veri == null
                            ? 'Yükleniyor'
                            : '${veri.duraklar.length} durak, rota sırasıyla',
                    onGeri: () => Navigator.of(context).maybePop(),
                  ),
                  if (!hata && veri != null && veri.konumsuz > 0)
                    KonumsuzBant(adet: veri.konumsuz),
                  Expanded(
                    child: hata ? _hataGovdesi(snap.error) : _govde(veri),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Alt ortadaki birincil eylem. Kontör bilinmiyorsa etikette SAYI YAZMAZ (sahte sayı yasağı).
  Widget _otoDugmesi(int durakSayisi) => HaritaOtoDugmesi(
        etiket: _otoHak == null ? 'Oto Sırala' : 'Oto Sırala ($_otoHak hak)',
        neden: otoKilitNedeni(
          yazilabilir: widget.writable,
          hak: _otoHak,
          durakSayisi: durakSayisi,
        ),
        yukleniyor: _otoKosuyor,
        onTap: _otoSirala,
      );

  /// Sorgu patladığında gösterilir. Teknik mesaj EKRANA YAZILIR — çünkü bu ekranın arızası
  /// yalnız sahada görülüyor ve kullanıcının okuyup iletebileceği tek kanal burası. KVKK açısından
  /// güvenli: mesaj Drift/SQLite'ın kendi metnidir (tablo/kolon adları), müşteri verisi taşımaz.
  ///
  /// KAYDIRILABİLİR ve KIRPILMIŞ olması şart — ilk yazımda ikisi de yoktu ve widget testi
  /// **3864 piksellik taşma** ile kırmızı yandı. Yani "hatayı göster" düzeltmesinin kendisi
  /// ikinci bir arıza üretiyordu: uzun bir yığın izi ekranı taşırıp okunamaz hâle getiriyordu.
  Widget _hataGovdesi(Object? hata) {
    final metin = hata.toString();
    final kisa = metin.length > 400 ? '${metin.substring(0, 400)}…' : metin;

    return SingleChildScrollView(
      child: SipBosDurum(
        ikon: SipIcons.pin,
        baslik: 'Harita yüklenemedi',
        aciklama: 'Sipariş verisi okunurken bir hata oluştu. Uygulamayı güncellemek çözmezse '
            'bu mesajı destekle paylaşın:\n\n$kisa',
      ),
    );
  }

  Widget _govde(HaritaVerisi? veri) {
    if (veri == null) return const SipIskelet(adet: 3);
    if (veri.duraklar.isEmpty) {
      // Veri yokken haritayı bir yere sabitlemek (Antalya vb.) anlamsız: kullanıcı boş bir
      // şehir görüp "pinlerim nerede" diye arar. Boş durum ne olduğunu söyler.
      return SipBosDurum(
        ikon: SipIcons.pin,
        baslik: 'Haritada gösterilecek sipariş yok',
        aciklama: veri.konumsuz > 0
            ? 'Açık siparişlerin adreslerinde konum kayıtlı değil. Sipariş detayındaki '
                '"Konumu Kaydet" ile ekleyebilirsiniz.'
            : 'Açık sipariş yok. Yeni sipariş girildiğinde durağı burada görünür.',
      );
    }
    return SiparisHaritaGorunumu(
      duraklar: veri.duraklar,
      cihaz: _cihaz,
      onDurak: _durakAc,
      onKonumum: _konumumaGit,
      otoDugmesi: _otoDugmesi(veri.duraklar.length),
      // KOŞULSUZ verilir: rol kapısı katmanın İÇİNDEDİR (`harita_kurye_katmani.dart`). Burada
      // `if (patron)` yazmak, rolü ikinci bir yerde daha yorumlamak ve özelliğin ağaca hiç
      // bağlanmadığı hâli testlerden gizlemek olurdu.
      kuryeKatmani: KuryeKatmani(db: widget.db),
      karoKaynagi: _karo,
    );
  }

  /// Pine dokunuldu: önce ÖZET, detay ondan sonra. Kurye haritada "burada ne var" sorusunu
  /// haritayı kaybetmeden sorabilmeli; tam detay bir dokunuş uzakta durur.
  Future<void> _durakAc(HaritaDuragi durak, int sira) async {
    final secim = await durakOzetSheetAc(context, durak: durak, sira: sira);
    if (secim != DurakOzetSonucu.detay || !mounted) return;
    await siparisDetaySheetAc(
      context,
      db: widget.db,
      orderId: durak.orderId,
      writable: widget.writable,
      canAssign: widget.canAssign,
      // Başlık elimizde — sheet açılmadan ikinci bir sorgu atılmasın (liste ekranıyla aynı).
      baslik: durak.baslik,
    );
  }
}

/// Haritanın kendisi — karo katmanı + numaralı duraklar + (varsa) cihaz konumu.
///
/// Ekranın DURUMUNDAN ayrı bir widget: böylece harita tek başına (sahte duraklarla) test
/// edilebilir ve veri akışı ile çizim birbirine karışmaz.
class SiparisHaritaGorunumu extends StatefulWidget {
  const SiparisHaritaGorunumu({
    super.key,
    required this.duraklar,
    required this.onDurak,
    this.cihaz,
    this.onKonumum,
    this.kuryeKatmani,
    this.otoDugmesi,
    this.karoKaynagi,
  });

  /// Karo adresi ve jetonu. null = henüz bilinmiyor → karo katmanı çizilmez, pinler yine çizilir.
  final HaritaKaroKaynagi? karoKaynagi;

  final List<HaritaDuragi> duraklar;
  final LatLng? cihaz;

  /// Alt ORTADAKİ birincil eylem ("Oto Sırala"). Widget olarak alınır ki bu görünüm ne kontörü
  /// ne de rota API'sini tanısın — çizim ile eylem ayrı kalır ([kuryeKatmani] ile aynı gerekçe).
  final Widget? otoDugmesi;

  /// Canlı kurye pinleri — haritanın ÜSTÜNDE ayrı bir `FlutterMap` çocuğu olarak çizilir.
  /// Widget olarak alınır ki bu görünüm ne `sync_meta`yı ne de konum API'sini tanısın:
  /// duraklar ile kuryeler iki ayrı dünya, tek harita.
  final Widget? kuryeKatmani;

  /// Dokunulan durak ve GÖRÜNEN numarası (1'den başlar) — özet sayfası başlığında aynı sayı
  /// yazar, kullanıcı hangi pine dokunduğunu doğrulayabilsin.
  final void Function(HaritaDuragi durak, int sira) onDurak;

  /// "Konumum" düğmesi: TAZE konum okur, bulduğunu döner. Kamerayı bu widget taşır (kontrolcü
  /// burada), konumu okumak ve pini güncellemek ekranın işi — iki sorumluluk ayrı kalsın.
  /// `null` dönerse kamera OYNAMAZ.
  final Future<LatLng?> Function()? onKonumum;

  @override
  State<SiparisHaritaGorunumu> createState() => _SiparisHaritaGorunumuState();
}

class _SiparisHaritaGorunumuState extends State<SiparisHaritaGorunumu> {
  final MapController _kontrolcu = MapController();

  /// Açılış kadrajı BİR KEZ hesaplanır: `initialCameraFit` yalnız ilk yerleşimde uygulanır ve
  /// her build'de yeni bir nesne üretmek MapOptions'ı boş yere değiştirirdi. "Duraklara sığdır"
  /// düğmesi de aynı kadrajı yeniden kurar — açılışa dönmek tek dokunuş olsun.
  late final CameraFit _acilisKadraji = _kadraj();

  /// Sağlayıcı yalnız (kaynak, koyu) değişince kurulur: 2026-09-28'e dek her build yeni bir HTTP
  /// istemcisi açıyor, eskisini hiç kapatmıyordu. Eskisini `TileLayer` dispose'unda kapatır.
  TileProvider? _saglayici;
  Object? _saglayiciAnahtari;
  TileProvider _karoSaglayici(HaritaKaroKaynagi karo, bool koyu) {
    if (_saglayici == null || (karo, koyu) != _saglayiciAnahtari) {
      _saglayici = haritaKaroSaglayici()..headers.addAll(karo.basliklar);
      _saglayiciAnahtari = (karo, koyu);
    }
    return _saglayici!;
  }

  @override
  void dispose() {
    _kontrolcu.dispose();
    super.dispose();
  }

  /// Tüm duraklar + (varsa) cihaz konumu. Tek pin varsa kutu sıfır alanlıdır; `maxZoom` onu
  /// sokak ölçeğinde tutar (yoksa kamera dünyanın sonuna kadar yakınlaşırdı).
  CameraFit _kadraj() => CameraFit.coordinates(
        coordinates: [
          for (final d in widget.duraklar) LatLng(d.lat, d.lng),
          ?widget.cihaz,
        ],
        padding: const EdgeInsets.all(48),
        maxZoom: 16,
      );

  /// Zoom ±1 — ANİMASYONSUZ. flutter_map'in kendi animasyonu yok, `TickerProvider` ile elle
  /// yazmak dokunma başına bir kare gecikme katardı; harita zaten kaydırmada anlık tepki veriyor.
  void _zoom(double fark) => _kontrolcu.move(
        _kontrolcu.camera.center,
        (_kontrolcu.camera.zoom + fark).clamp(2.0, 18.0),
      );

  void _sigdir() => _kontrolcu.fitCamera(_kadraj());

  Future<void> _konumum() async {
    final nokta = await widget.onKonumum?.call();
    if (nokta == null || !mounted) return;
    // Sokak ölçeği: kurye "ben neredeyim" derken kapı numarası değil, çevresindeki birkaç sokak
    // görmek ister.
    _kontrolcu.move(nokta, 15);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final duraklar = widget.duraklar;
    final karo = widget.karoKaynagi;

    return Stack(
      children: [
        FlutterMap(
          mapController: _kontrolcu,
          options: MapOptions(
            initialCameraFit: _acilisKadraji,
            backgroundColor: t.surface2,
          ),
          children: [
            if (karo != null)
              TileLayer(
                // Tema ya da oturum değişince ValueKey katmanı KOMPLE değiştirir: eski stilin
                // karoları yeni stille karışıp yama gibi bir harita bırakmasın.
                key: ValueKey((karo, t.koyu)),
                urlTemplate: karo.sablon(koyu: t.koyu),
                userAgentPackageName: kHaritaUygulamaAdi,
                // Oturum jetonu sağlayıcının başlıklarında (sunucu aracısı oturum ister).
                tileProvider: _karoSaglayici(karo, t.koyu),
                // Yüksek yoğunluklu ekranda "@2x" karo istenir (`{r}`); düşük yoğunlukta ve
                // testlerde flutter_map yer tutucuyu BOŞ metinle doldurur, yani ek istek yok.
                retinaMode: RetinaMode.isHighDensity(context),
                // ÇEVRİMDIŞI: karo inmezse harita gri kalır ve PİNLER durur. Geri çağrı SESSİZDİR —
                // ekranda kaydırma başına onlarca karo denenir; her biri için toast göstermek
                // uygulamayı kullanılamaz hâle getirirdi.
                errorTileCallback: (_, _, _) {},
              ),
            MarkerLayer(
              markers: [
                for (var i = 0; i < duraklar.length; i++)
                  Marker(
                    point: LatLng(duraklar[i].lat, duraklar[i].lng),
                    width: 34,
                    height: 34,
                    child: DurakPini(
                      sira: i + 1,
                      baslik: duraklar[i].baslik,
                      onTap: () => widget.onDurak(duraklar[i], i + 1),
                    ),
                  ),
                if (widget.cihaz != null)
                  Marker(
                    point: widget.cihaz!,
                    width: 22,
                    height: 22,
                    child: const CihazPini(),
                  ),
              ],
            ),
            // Kurye pinleri duraklardan SONRA: hareket eden nokta, sabit duraklardan daha
            // acil bir bilgidir ve üst üste düştüklerinde görünen o olmalı.
            ?widget.kuryeKatmani,
          ],
        ),
        Positioned(
          right: SipSpace.xl,
          bottom: SipSpace.x4,
          child: HaritaKontrolleri(
            onYakinlas: () => _zoom(1),
            onUzaklas: () => _zoom(-1),
            onSigdir: _sigdir,
            onKonumum: _konumum,
          ),
        ),
        // Atıf SOL ALTTA: sağ alt kontrol sütununun altına girmez, dokunma hedeflerini kapatmaz.
        const Positioned(left: SipSpace.md, bottom: SipSpace.md, child: HaritaAtfi()),
        // "Oto Sırala" ALT ORTADA. Yatay iç boşluk 64: sağdaki kontrol sütunu (12 + 40 çap)
        // ile çakışmasın — ortalanmış düğme dar telefonda o sütunun altına girerdi.
        if (widget.otoDugmesi != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: SipSpace.x4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: widget.otoDugmesi!,
            ),
          ),
      ],
    );
  }
}
