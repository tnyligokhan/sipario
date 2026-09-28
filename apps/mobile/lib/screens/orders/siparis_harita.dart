// SİPARİŞ HARİTASI — açık siparişlerin durakları, rota sırasında numaralı pinlerle.
//
// NEDEN VAR: "Oto Sırala (rota)" bir SIRA üretiyordu ama kurye o sıranın yeryüzünde neye
// benzediğini göremiyordu. Liste "1, 2, 3" der; harita "önce şu mahalle, sonra dönüp bu sokak"
// der ve saçma bir rotayı kurye tek bakışta yakalar. Duraklar kesikli bir ROTA ÇİZGİSİYLE
// sırayla bağlanır (cihaz konumu biliniyorsa oradan başlar) — sıra okunmak zorunda kalmaz.
//
// ÜÇ KURAL:
//  • VERİ yalnız AÇIK siparişlerdir (teslim edileni haritada göstermek yapılacak işi şişirir).
//    Koordinatı olmayan açık sipariş haritaya GİRMEZ ama SAYISI üstte yazar — sessizce yutmak
//    kuryeye eksik rota koşturur.
//  • HARİTA MOTORU tek dikişten geçer ([haritaTuvaliUret]): üretimde MapLibre (vektör, her
//    yakınlıkta keskin — 2026-09-28'e dek resim karolar yakınlaşınca pikselleşiyordu), testte
//    içeriği widget olarak çizen sahte. Widget testi ağa ve platform görünümüne ASLA uzanmaz.
//  • ZEMİN YÜKLENEMEZSE (çevrimdışı) harita düz renk kalır, PİNLER YİNE ÇİZİLİR. Offline-first
//    sözü burada da geçerli: internet yoksa özellik kapanmaz, zemin kaybolur
//    (`harita_stili.dart` — stil diskte saklanır, en kötü ihtimalle yedek stile düşülür).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../konum/cihaz_konumu.dart';
import '../../sync/konum_api.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import 'harita_icerigi.dart';
import 'harita_isaretler.dart';
import 'harita_kontrolleri.dart';
import 'harita_kurye_katmani.dart';
import 'harita_sorgulari.dart';
import 'harita_tuvali.dart';
import 'order_detail_screen.dart';
import 'oto_siralama.dart';
import 'siparis_harita_ozet.dart';

// Konumsuz bandı 500 satır sınırı için ayrı dosyada; harita ekranının DIŞ YÜZEYİ değişmez —
// çağıranlar ve testler onu hâlâ bu dosyadan tanır (sözleşme).
export 'harita_isaretler.dart' show KonumsuzBant;

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
  HaritaNoktasi? _cihaz;

  /// Kalan oto-sıralama hakkı (sunucu sahipli, senkronla iner). null = HENÜZ BİLİNMİYOR →
  /// düğme kontör YAZMADAN, PASİF çizilir. Uydurma bir sayı göstermek yasak: kullanıcı
  /// "34 hakkım var" deyip tıkladığında sunucu 409 dönerse güven kaybolur.
  int? _otoHak;
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
      if (!mounted || yeni == _otoHak) return;
      setState(() => _otoHak = yeni);
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
      setState(() => _cihaz = HaritaNoktasi(k.lat, k.lng));
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
  Future<HaritaNoktasi?> _konumumaGit() async {
    try {
      final k = await cihazKonumuOku();
      if (!mounted) return null;
      final nokta = HaritaNoktasi(k.lat, k.lng);
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
    // Kurye katmanı KOŞULSUZ sarılır: rol kapısı katmanın İÇİNDEDİR (`harita_kurye_katmani.dart`).
    // Burada `if (patron)` yazmak, rolü ikinci bir yerde daha yorumlamak ve özelliğin ağaca hiç
    // bağlanmadığı hâli testlerden gizlemek olurdu.
    return KuryeKatmani(
      db: widget.db,
      builder: (context, kuryeler) => SiparisHaritaGorunumu(
        duraklar: veri.duraklar,
        cihaz: _cihaz,
        kuryeler: kuryeler,
        onDurak: _durakAc,
        onKurye: (k) => kuryeOzetSheetAc(context, konum: k),
        onKonumum: _konumumaGit,
        otoDugmesi: _otoDugmesi(veri.duraklar.length),
      ),
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

/// Haritanın kendisi — tuval (MapLibre) + üstündeki kontroller, atıf ve "Oto Sırala".
///
/// Ekranın DURUMUNDAN ayrı bir widget: böylece harita tek başına (sahte duraklarla) test
/// edilebilir ve veri akışı ile çizim birbirine karışmaz. Görünüm motoru tanımaz; içeriği
/// [HaritaIcerigi] olarak kurar ve kamerayı [HaritaKamerasi] üzerinden sürer.
class SiparisHaritaGorunumu extends StatefulWidget {
  const SiparisHaritaGorunumu({
    super.key,
    required this.duraklar,
    required this.onDurak,
    this.cihaz,
    this.kuryeler = const [],
    this.onKurye,
    this.onKonumum,
    this.otoDugmesi,
  });

  final List<HaritaDuragi> duraklar;
  final HaritaNoktasi? cihaz;

  /// Canlı kuryeler — kapıyı [KuryeKatmani] açar; kapalıysa liste boştur.
  final List<CanliKonum> kuryeler;

  /// Alt ORTADAKİ birincil eylem ("Oto Sırala"). Widget olarak alınır ki bu görünüm ne kontörü
  /// ne de rota API'sini tanısın — çizim ile eylem ayrı kalır.
  final Widget? otoDugmesi;

  /// Dokunulan durak ve GÖRÜNEN numarası (1'den başlar) — özet sayfası başlığında aynı sayı
  /// yazar, kullanıcı hangi pine dokunduğunu doğrulayabilsin. Dönen iş bitene (özet kapanana)
  /// dek durak haritada VURGULU kalır.
  final Future<void> Function(HaritaDuragi durak, int sira) onDurak;

  final void Function(CanliKonum kurye)? onKurye;

  /// "Konumum" düğmesi: TAZE konum okur, bulduğunu döner. Kamerayı bu widget taşır, konumu
  /// okumak ve pini güncellemek ekranın işi — iki sorumluluk ayrı kalsın. `null` dönerse kamera
  /// OYNAMAZ.
  final Future<HaritaNoktasi?> Function()? onKonumum;

  /// Kadraja sığdırırken üstteki düğmelerin payı: sağda kontrol sütunu (12 + 40 çap), altta
  /// "Oto Sırala" ve gerekçesi. Pin bir düğmenin altında kalırsa dokunulamaz.
  static const EdgeInsets kenarBoslugu = EdgeInsets.fromLTRB(48, 56, 72, 120);

  @override
  State<SiparisHaritaGorunumu> createState() => _SiparisHaritaGorunumuState();
}

class _SiparisHaritaGorunumuState extends State<SiparisHaritaGorunumu> {
  /// Tuval hazır olunca gelir; o ana dek düğmeler sessizce hiçbir şey yapmaz (motor stilini
  /// yüklerken kamerayı oynatmak kayıp bir komuttur).
  HaritaKamerasi? _kamera;

  /// Özeti açık olan durak — pini büyür ve halelenir.
  String? _seciliId;

  HaritaIcerigi _icerik() => HaritaIcerigi(
        duraklar: [
          for (var i = 0; i < widget.duraklar.length; i++)
            DurakIsareti(
              id: widget.duraklar[i].orderId,
              no: i + 1,
              nokta: HaritaNoktasi(widget.duraklar[i].lat, widget.duraklar[i].lng),
              ad: widget.duraklar[i].baslik,
            ),
        ],
        cihaz: widget.cihaz,
        kuryeler: [for (final k in widget.kuryeler) kuryeIsareti(k)],
        seciliDurakId: _seciliId,
      );

  Future<void> _dokunuldu(HaritaDokunusu dokunus) async {
    switch (dokunus) {
      case DurakDokunusu(:final id):
        final i = widget.duraklar.indexWhere((d) => d.orderId == id);
        if (i < 0 || _seciliId != null) return; // bayat dokunuş ya da özet zaten açık
        setState(() => _seciliId = id);
        try {
          await widget.onDurak(widget.duraklar[i], i + 1);
        } finally {
          if (mounted) setState(() => _seciliId = null);
        }
      case KuryeDokunusu(:final id):
        for (final k in widget.kuryeler) {
          if (k.userId == id) return widget.onKurye?.call(k);
        }
    }
  }

  /// "Duraklara sığdır" — ŞU ANKİ duraklar + cihaz. Açılıştan bu yana yeni sipariş geldiyse
  /// o da kadraja girer.
  void _sigdir() {
    final kadraj = _icerik().kadraj;
    if (kadraj != null) unawaited(_kamera?.kadrajla(kadraj));
  }

  Future<void> _konumum() async {
    final nokta = await widget.onKonumum?.call();
    if (nokta == null || !mounted) return;
    // Sokak ölçeği: kurye "ben neredeyim" derken kapı numarası değil, çevresindeki birkaç sokak
    // görmek ister.
    await _kamera?.odakla(nokta, 15);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: haritaTuvaliUret(
            HaritaTuvaliAyari(
              icerik: _icerik(),
              koyu: context.sip.koyu,
              kenarBoslugu: SiparisHaritaGorunumu.kenarBoslugu,
              onDokunus: (d) => unawaited(_dokunuldu(d)),
              onHazir: (k) => _kamera = k,
            ),
          ),
        ),
        Positioned(
          right: SipSpace.xl,
          bottom: SipSpace.x4,
          child: HaritaKontrolleri(
            onYakinlas: () => unawaited(_kamera?.yakinlastir(1)),
            onUzaklas: () => unawaited(_kamera?.yakinlastir(-1)),
            onSigdir: _sigdir,
            onKonumum: () => unawaited(_konumum()),
          ),
        ),
        // Atıf SOL ÜSTTE (2026-09-28): altta "Oto Sırala" ile çakışıyordu (cihazda görüldü —
        // OpenFreeMap atfı öncekinden uzun). Sağ üstte yerel atıf düğmesi (ⓘ) durur.
        const Positioned(left: SipSpace.md, top: SipSpace.md, child: HaritaAtfi()),
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
