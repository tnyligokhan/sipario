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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../../data/app_database.dart';
import '../../konum/cihaz_konumu.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'harita_kontrolleri.dart';
import 'harita_sorgulari.dart';
import 'order_detail_screen.dart';
import 'siparis_harita_ozet.dart';

/// Karo adresi — CARTO **Positron** (gri-minimal OSM tabanı), ANAHTARSIZ.
///
/// HAM OSM KAROSUNDAN NEDEN VAZGEÇİLDİ (cihazda ekran görüntüsüyle görüldü): standart `tile.
/// openstreetmap.org` katmanı kırmızı otoyollar, yol numarası etiketleri ve yoğun POI
/// simgeleriyle geliyor. Uygulamanın sade/aydınlık dilinin yanında gürültü gibi duruyordu ve
/// asıl iş olan MOR PİNLER bu kalabalıkta kayboluyordu. Positron ana yolları nötr griyle çizer,
/// POI basmaz — pinler tek bakışta öne çıkar.
///
/// Anahtar İSTEMEZ: APK'ya gömülecek sır yok (kırmızı çizgi korunur), sağlayıcı değişimi de tek
/// satırlık bir iş kalır.
///
/// `{s}` alt alan adı (a–d), `{r}` retina ölçeği ("@2x"). `{r}` yalnız yüksek yoğunluklu
/// ekranlarda doldurulur — `retinaMode` kapalıyken flutter_map onu BOŞ metinle değiştirir,
/// yani düşük yoğunluklu cihazlarda ve testlerde adres kendiliğinden sade hâline döner.
const String kHaritaKaroUrlAcik =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

/// KOYU temanın karosu — CARTO **Dark Matter**, Positron'un birebir karanlık kardeşi (aynı
/// sunucu, aynı şartlar, yine ANAHTARSIZ). Saha bulgusu (2026-07-29): uygulama koyu temadayken
/// haritanın bembeyaz açılması hem göz alıyor hem "bozuk" izlenimi veriyordu — karo stili artık
/// temanın parlaklığını İZLER.
const String kHaritaKaroUrlKoyu =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

/// Temaya göre karo adresi. Seçim TEK yerde dursun: hem TileLayer hem testler bunu kullanır.
String haritaKaroUrl({required bool koyu}) =>
    koyu ? kHaritaKaroUrlKoyu : kHaritaKaroUrlAcik;

/// Positron'un alt alan adları. OSM'in kendi sunucusunda subdomain KULLANILMAZ (flutter_map
/// uyarır), CARTO'da ise beklenen kullanım budur.
const List<String> kHaritaAltAlanlar = ['a', 'b', 'c', 'd'];

/// Kullanım şartı: istekler uygulamayı TANITMALI. Gerçek applicationId
/// (`android/app/build.gradle.kts`) yazılır — uydurma bir ad, kotanın kime ait olduğunu gizler.
const String kHaritaUygulamaAdi = 'com.sipario.app';

/// Üretim karo sağlayıcısı — İPTAL EDİLEBİLİR indirme (saha bulgusu 2026-07-29: "harita çok
/// kasıyor"). Varsayılan `NetworkTileProvider` bir karo istemeye başladıysa BİTİRİR: hızlı
/// kaydırma/zoom'da görünürlükten çoktan çıkmış onlarca karo inip çözülmeye devam eder, kuyruk
/// ana iş parçacığını boğar. `CancellableNetworkTileProvider` kadraj dışına düşen karonun
/// isteğini ANINDA keser — flutter_map'in kendi belgelerinin performans için önerdiği yol.
///
/// Ayrı bir fonksiyon olarak duruyor ki "üretimin varsayılanı iptal edilebilir sağlayıcıdır"
/// sözü dikişten bağımsız test edilebilsin (dikiş testlerde sahteyle değiştirilir).
TileProvider varsayilanKaroSaglayici() => CancellableNetworkTileProvider();

/// Karo sağlayıcının TEK dikişi. Üretimde ağdan indirir; widget testleri bunu sahtesiyle
/// değiştirir ve test hiçbir zaman ağa çıkmaz (`adresAdaylariGetir` / `cihazKonumuOku` deseni).
TileProvider Function() haritaKaroSaglayici = varsayilanKaroSaglayici;

/// Açık siparişlerin haritası. Pin numaraları listedeki sırayı (oto sıralamadan sonra ROTA
/// sırasını) taşır.
class SiparisHaritaEkrani extends StatefulWidget {
  const SiparisHaritaEkrani({
    super.key,
    required this.db,
    required this.writable,
    this.canAssign = false,
  });

  final AppDatabase db;

  /// Pine dokununca açılan detay sheet'ine geçirilir — harita kendisi hiçbir kayıt yazmaz.
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

  @override
  void initState() {
    super.initState();
    _cihazKonumunuDene();
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

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<HaritaVerisi>(
          stream: _veri,
          builder: (context, snap) {
            final veri = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SipUst(
                  baslik: 'Harita',
                  alt: veri == null
                      ? 'Yükleniyor'
                      : '${veri.duraklar.length} durak · rota sırası',
                  onGeri: () => Navigator.of(context).maybePop(),
                ),
                if (veri != null && veri.konumsuz > 0)
                  KonumsuzBant(adet: veri.konumsuz),
                Expanded(child: _govde(veri)),
              ],
            );
          },
        ),
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
            ? 'Açık siparişlerin adreslerinde konum kayıtlı değil — sipariş detayından '
                '"Konumu Kaydet" ile ekleyebilirsiniz.'
            : 'Açık sipariş yok. Yeni sipariş girildiğinde durağı burada görünür.',
      );
    }
    return SiparisHaritaGorunumu(
      duraklar: veri.duraklar,
      cihaz: _cihaz,
      onDurak: _durakAc,
      onKonumum: _konumumaGit,
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

/// Koordinatsız açık siparişleri duyuran NÖTR bant. Hata değildir (kimse yanlış bir şey yapmadı),
/// bu yüzden danger değil sönük yüzey rengiyle çizilir — ama görünürdür.
class KonumsuzBant extends StatelessWidget {
  const KonumsuzBant({super.key, required this.adet});

  final int adet;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SipSpace.govde, 0, SipSpace.govde, SipSpace.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.md),
        decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br1),
        child: Row(
          children: [
            SipIcon(SipIcons.info, boyut: 15, kalinlik: 2, renk: t.muted),
            const SizedBox(width: SipSpace.md),
            Expanded(
              child: Text(
                // Metin SÖZLEŞMEDİR (testler bu cümleyi arar).
                '$adet sipariş konumsuz — haritada yok',
                style: SipText.metin(12, w: 600).copyWith(color: t.ink2),
              ),
            ),
          ],
        ),
      ),
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
  });

  final List<HaritaDuragi> duraklar;
  final LatLng? cihaz;

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

    return Stack(
      children: [
        FlutterMap(
          mapController: _kontrolcu,
          options: MapOptions(
            initialCameraFit: _acilisKadraji,
            backgroundColor: t.surface2,
          ),
          children: [
            TileLayer(
              // Tema değişince şablon değişir; ValueKey katmanı KOMPLE değiştirir — eski stilin
              // önbellekteki karoları yeni stille karışıp "yarı aydınlık yarı karanlık" bir
              // yama haritası bırakmasın.
              key: ValueKey(haritaKaroUrl(koyu: t.koyu)),
              urlTemplate: haritaKaroUrl(koyu: t.koyu),
              subdomains: kHaritaAltAlanlar,
              userAgentPackageName: kHaritaUygulamaAdi,
              tileProvider: haritaKaroSaglayici(),
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
      ],
    );
  }
}

/// Numaralı durak işaretçisi — accent zemin, accentInk rakam (tasarımın vurgu jetonları).
class DurakPini extends StatelessWidget {
  const DurakPini({
    super.key,
    required this.sira,
    required this.baslik,
    required this.onTap,
  });

  final int sira;

  /// Erişilebilirlik etiketi: ekran okuyucu "3. durak · Ayşe Yılmaz" der. Sayı tek başına
  /// haritada hangi müşteriyi işaret ettiğini söylemez.
  final String baslik;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      label: '$sira. durak · $baslik',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.accent,
            shape: BoxShape.circle,
            // İnce açık halka: koyu karoların üstünde pin kaybolmasın.
            border: Border.all(color: t.accentInk, width: 2),
          ),
          child: Text(
            '$sira',
            style: SipText.tutar(13, w: 800).copyWith(color: t.accentInk),
          ),
        ),
      ),
    );
  }
}

/// Cihazın bulunduğu nokta — duraklardan AYRI görünür (içi dolu küçük nokta, halkalı).
/// Numarası yoktur: rota duraklardan oluşur, kurye bir durak değildir.
class CihazPini extends StatelessWidget {
  const CihazPini({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      label: 'Bulunduğunuz konum',
      child: Container(
        decoration: BoxDecoration(
          color: t.ok,
          shape: BoxShape.circle,
          border: Border.all(color: SipTokens.onHero, width: 3),
        ),
      ),
    );
  }
}
