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
//  • HARİTA MOTORU tek dikişten geçer ([haritaTuvaliUret]): üretimde Yandex MapKit (vektör, her
//    yakınlıkta keskin — 2026-09-28'e dek resim karolar yakınlaşınca pikselleşiyordu), testte
//    içeriği widget olarak çizen sahte. Widget testi ağa ve platform görünümüne ASLA uzanmaz.
//  • ZEMİN YÜKLENEMEZSE (çevrimdışı) PİNLER YİNE ÇİZİLİR: pinler motorun kendi nesneleridir,
//    zeminden bağımsızdır. MapKit daha önce bakılan bölgeyi kendi önbelleğinden gösterir.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../konum/cihaz_konumu.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import 'harita_icerigi.dart';
import 'harita_gruplari.dart';
import 'harita_isaretler.dart';
import 'harita_kontrolleri.dart';
import 'harita_kurye_katmani.dart';
import 'harita_sorgulari.dart';
import 'harita_yol_cizgisi.dart';
import 'order_detail_screen.dart';
import 'oto_siralama.dart';
import 'siparis_gruplari.dart';
import 'siparis_harita_gorunumu.dart';
import 'siparis_harita_ozet.dart';

// Konumsuz bandı 500 satır sınırı için ayrı dosyada; harita ekranının DIŞ YÜZEYİ değişmez —
// çağıranlar ve testler onu hâlâ bu dosyadan tanır (sözleşme).
export 'harita_isaretler.dart' show KonumsuzBant;
export 'siparis_harita_gorunumu.dart';

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

  /// Kişi şeridinde seçili grup (`SiparisGrubu.anahtar`); null = hepsi. Oto sıralama da buna
  /// uyar: "Ali" seçiliyken yalnız Ali'nin rotası sıralanır.
  String? _seciliGrup;

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
    final sonuc = await otoSiralaKos(widget.db, grup: _seciliGrup);
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
                            : veri.gruplu
                                ? '${veri.duraklar.length} durak, ${veri.gruplar.length} kişi'
                                : '${veri.duraklar.length} durak, rota sırasıyla',
                    onGeri: () => Navigator.of(context).maybePop(),
                  ),
                  if (!hata && veri != null && veri.konumsuz > 0)
                    KonumsuzBant(adet: veri.konumsuz),
                  if (!hata && veri != null && veri.gruplu)
                    HaritaGrupSeridi(
                      gruplar: veri.gruplar,
                      renkler: _grupRenkleri(veri),
                      secili: _seciliGrup,
                      onSec: (g) => setState(() => _seciliGrup = g),
                    ),
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

  /// Grup anahtarı → renk. "Siz" temanın vurgusu, kuryeler kişiye bağlı sabit renk.
  Map<String, Color> _grupRenkleri(HaritaVerisi veri) => {
        for (final g in veri.gruplar)
          g.anahtar: grupRengi(g, vurgu: context.sip.accent, kisiSirasi: veri.kisiSirasi),
      };

  /// Şeritte seçili olanlar; seçili grup artık yoksa (siparişleri bitti) hepsi.
  List<SiparisGrubu<HaritaDuragi>> _gorunenGruplar(HaritaVerisi veri) {
    final secili = [for (final g in veri.gruplar) if (g.anahtar == _seciliGrup) g];
    return secili.isEmpty ? veri.gruplar : secili;
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
  /// Ham hata metni EKRANA YAZILMAZ (kullanıcı kararı 2026-09-29: teknik ayrıntı ve sunucu
  /// bilgisi hiçbir koşulda gösterilmez). Eskiden istisnanın ilk 400 karakteri "destekle
  /// paylaşın" diye basılıyordu; bayiye bir şey anlatmıyor, iç yapıyı ise açığa çıkarıyordu.
  /// Ayrıntı geliştirici günlüğüne gider.
  Widget _hataGovdesi(Object? hata) {
    debugPrint('Harita verisi okunamadı: $hata');
    return const SingleChildScrollView(
      child: SipBosDurum(
        ikon: SipIcons.pin,
        baslik: 'Harita yüklenemedi',
        aciklama: 'Siparişler haritaya yerleştirilemedi. Ekrandan çıkıp yeniden açın, sorun '
            'sürerse uygulamayı güncelleyin.',
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
    // KİŞİ GRUPLARI: görünen gruplar (şeritte seçili olan ya da hepsi) çizilir. Gerçek yol
    // çizgisi yalnız TEK grup gösterilirken istenir — çok grupta her grup kendi kesikli
    // çizgisiyle yetinir, grup başına paralı çağrı açılmaz.
    final gorunen = _gorunenGruplar(veri);
    final duraklar = [for (final g in gorunen) ...g.ogeler];
    final renkler = _grupRenkleri(veri);
    final tekGrup = gorunen.length <= 1;
    // Kuryeye odaklanıldıysa yalnız o kuryenin pini kalır.
    final odakKurye = tekGrup && gorunen.isNotEmpty && !gorunen.single.kendi
        ? gorunen.single.kullaniciId
        : null;
    final enBuyukGrup =
        gorunen.fold<int>(0, (m, g) => g.ogeler.length > m ? g.ogeler.length : m);
    // Kurye katmanı KOŞULSUZ sarılır: rol kapısı katmanın İÇİNDEDİR (`harita_kurye_katmani.dart`).
    // Burada `if (patron)` yazmak, rolü ikinci bir yerde daha yorumlamak ve özelliğin ağaca hiç
    // bağlanmadığı hâli testlerden gizlemek olurdu.
    // Yol çizgisi katmanı da KOŞULSUZ sarılır: oturum/servis kapısı katmanın içindedir.
    return KuryeKatmani(
      db: widget.db,
      builder: (context, kuryeler) => YolCizgisiKatmani(
        db: widget.db,
        duraklar: tekGrup ? duraklar : const [],
        builder: (context, yol) => SiparisHaritaGorunumu(
          duraklar: duraklar,
          gruplar: veri.gruplar.isEmpty ? null : gorunen,
          grupRenkleri: renkler,
          kuryeRengi: (id) => kisiRengi(id, kisiSirasi: veri.kisiSirasi),
          cihaz: _cihaz,
          kuryeler: [
            for (final k in kuryeler)
              if (odakKurye == null || k.userId == odakKurye) k,
          ],
          yol: tekGrup ? yol : null,
          onDurak: _durakAc,
          onKurye: (k) => kuryeOzetSheetAc(context, konum: k),
          onKonumum: _konumumaGit,
          otoDugmesi: _otoDugmesi(enBuyukGrup),
        ),
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

