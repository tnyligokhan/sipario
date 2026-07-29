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
import 'package:latlong2/latlong.dart';

import '../../data/app_database.dart';
import '../../konum/cihaz_konumu.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'order_detail_screen.dart';
import 'order_queries.dart';

/// OSM karo adresi. Anahtar YOK — bu paketin seçilme gerekçesi de buydu (pubspec).
const String kOsmKaroUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// OSM kullanım şartı: istekler uygulamayı TANITMALI. Gerçek applicationId
/// (`android/app/build.gradle.kts`) yazılır — uydurma bir ad, kotanın kime ait olduğunu gizler.
const String kHaritaUygulamaAdi = 'com.sipario.app';

/// Karo sağlayıcının TEK dikişi. Üretimde ağdan indirir; widget testleri bunu sahtesiyle
/// değiştirir ve test hiçbir zaman ağa çıkmaz (`adresAdaylariGetir` / `cihazKonumuOku` deseni).
TileProvider Function() haritaKaroSaglayici = NetworkTileProvider.new;

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
    );
  }

  Future<void> _durakAc(HaritaDuragi durak) => siparisDetaySheetAc(
        context,
        db: widget.db,
        orderId: durak.orderId,
        writable: widget.writable,
        canAssign: widget.canAssign,
        // Başlık elimizde — sheet açılmadan ikinci bir sorgu atılmasın (liste ekranıyla aynı).
        baslik: durak.baslik,
      );
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
class SiparisHaritaGorunumu extends StatelessWidget {
  const SiparisHaritaGorunumu({
    super.key,
    required this.duraklar,
    required this.onDurak,
    this.cihaz,
  });

  final List<HaritaDuragi> duraklar;
  final LatLng? cihaz;
  final void Function(HaritaDuragi durak) onDurak;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final noktalar = [
      for (final d in duraklar) LatLng(d.lat, d.lng),
      ?cihaz,
    ];

    return FlutterMap(
      options: MapOptions(
        // Açılışta TÜM pinler (+ cihaz) kadraja girer. Tek pin varsa `CameraFit.coordinates`
        // sıfır alanlı bir kutu üretir; `maxZoom` onu sokak ölçeğinde tutar.
        initialCameraFit: CameraFit.coordinates(
          coordinates: noktalar,
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
        ),
        backgroundColor: t.surface2,
      ),
      children: [
        TileLayer(
          urlTemplate: kOsmKaroUrl,
          userAgentPackageName: kHaritaUygulamaAdi,
          tileProvider: haritaKaroSaglayici(),
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
                  onTap: () => onDurak(duraklar[i]),
                ),
              ),
            if (cihaz != null)
              Marker(
                point: cihaz!,
                width: 22,
                height: 22,
                child: const CihazPini(),
              ),
          ],
        ),
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
