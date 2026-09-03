// GÜN ÖZETİ ekranı — TEK ekran, HER gün (yeniden tasarım, kullanıcı isteği 2026-08-25).
//
// ══ NE DEĞİŞTİ VE NEDEN ═════════════════════════════════════════════════════════════════════
// Kullanıcı şunu söyledi: *"Gün Özeti sayfası çok uğraştırıcı. Geçmiş için ayrı bir yere gitmek
// gerekiyor, oysa sayfanın içinde takvimle geçmişe gidebilmeli. Ayrıca burada Gider Ekleme de
// olmalı."* Üçü de yapıldı:
//
//  1. GEÇMİŞ ARTIK BU EKRANDA. `isletme/gecmis_gun_ekrani.dart` SİLİNDİ. Başlıktaki "Geçmiş"
//     düğmesinin yerini tarih şeridi (‹ gün ›) ve takvim aldı; kapsam, bölümler ve eylemler
//     hangi güne bakılırsa bakılsın AYNI. İki ekran olduğu sürece ikisi ayrışıyordu: "Satılan
//     Ürünler" yalnız geçmişte vardı, gider/ara tahsilat yalnız bugünde; bir bölüm eklendiğinde
//     hangi ekrana ekleneceği her seferinde ayrı bir karar oluyordu.
//  2. TAKVİM, oklara ek olarak uzağa atlamayı verir ve her günün altında hesabın hâlini
//     (kapatıldı / kapatılmadı) nokta olarak gösterir — "kapanmamış gün" bandının aylık hâli.
//  3. GİDER EKLEME, kasa kartının hemen altındaki "Giderler" bölümünde. Yetki matrisindeki
//     "Saha Gideri Girme (Benzin vb.)" satırı aylardır vardı ama ÜRÜNDE KARŞILIĞI YOKTU.
//
// ══ GÜN BİR DURUM ALANIDIR, PARA KARARI DEĞİL ═══════════════════════════════════════════════
// [_gun] yalnız NE GÖSTERİLECEĞİNİ söyler. Deftere yazan her akış (kapatma, ara tahsilat, gider)
// kendi anında günü YENİDEN çözer (`bugunTrDuzeltilmis`) — akşamdan beri açık duran bir ekran
// gece yarısından sonra dünün gününe kayıt yazmasın diye. Yazma yolları ayrıca "bugün mü"
// kapısından geçer: geçmiş bir güne ara tahsilat ve gider YAZILAMAZ.
//
// ══ ROL KAPISI BURADADIR (K2) ══════════════════════════════════════════════════════════════
// Ekran KURYE trafiği de alıyor (çekmecedeki "Kasa Devri" buraya bağlı) ve kabuk önünde rol
// kapısı TUTMUYOR. Kurallar:
//   • hesap kapatma · ara tahsilat ALMA · ara tahsilat İPTALİ · kapanışı geri alma →
//     `yetkiler().gunuKapatma` (YÖNETİCİ). Dördü de birer DEVİR işlemidir ve matriste tek satır
//     olarak durur; ayrı anahtarlar uydurmak, karşılığı olmayan bir ayrım yaratmak olurdu.
//   • saha gideri girme/iptal → `yetkiler().sahaGideri` (bayi kuryeye açabilir; varsayılan
//     KAPALI). Ayrı bir anahtar OLMASI matrisin kendi kararıdır: benzin parasını yolda harcayan
//     kişi kuryedir ve kaydı ondan istemek, akşamki farkın tek açıklamasıdır.
//   • geçmiş günlere gitme → `yetkiler().gecmisHesapArsivi` (YÖNETİCİ). Kuryede tarih şeridi ve
//     takvim HİÇ çizilmez; ekran bugüne kilitlidir.
//
// HER KAPI ÇİFTTİR: ekran düğmeyi hiç çizmez VE eylem fonksiyonu yetkiyi yeniden sorar. Tek kapı
// yetmez, çünkü ekranın bildiği durum sheet/diyalog açıkken senkronla bayatlayabilir.

import 'package:flutter/material.dart';

import '../rehber/rehber_modeli.dart';
import '../rehber/rehber_sahne.dart';

import '../data/app_database.dart';
import '../auth/session.dart';
import '../sync/yenileme.dart';
import '../repo/cash_handover_repository.dart';
import '../repo/day_closing_repository.dart';
import '../repo/gider_repository.dart';
import '../theme/components/atoms.dart';
import '../theme/components/overlays.dart';
import '../theme/components/states.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import 'isletme/gider_sheet.dart';
import 'isletme/gun_arsivi.dart';
import 'isletme/gun_kapatma_sheet.dart';
import 'isletme/gun_kapsami.dart';
import 'isletme/gun_ozeti_eylemleri.dart';
import 'isletme/gun_ozeti_govdesi.dart';
import 'isletme/gun_sonu_kartlari.dart';
import 'isletme/gun_sonu_ozet.dart';
import 'isletme/gun_takvimi.dart';
import 'isletme/kapanmamis_gun_banti.dart';
import 'isletme/kapanis_geri_alma.dart';
import 'orders/siparis_tarih_seridi.dart';
import 'team.dart';

// Veri katmanı bu ekranın genel yüzeyinin parçası olarak kalır: testler ve kabuk `bugunTr` /
// `gunSonuOzeti`yi buradan import ediyor, dosya bölünürken o imzalar kırılmasın.
export 'isletme/gun_sonu_ozet.dart'
    show bugunTr, gunSonuOzeti, GunSonuOzet, kapsamOzeti, KapsamOzeti, GunSonuGorunumu;

// EKRAN İKİYE BÖLÜNDÜ (2026-08-17, 500 satır kuralı): deftere YAZAN eylemler ayrı parçada.
// Ekranın özel durumunu yazdıkları için `part`tır.
part 'gun_sonu_eylemleri.dart';

class DayEndScreen extends StatefulWidget {
  const DayEndScreen({
    super.key,
    required this.db,
    this.onMenu,
    this.rol,
    this.kullaniciId,
    this.kuryeIzin,
    this.session,
    this.bugun,
  });

  final AppDatabase db;

  /// Oturum — YALNIZ yönetici parolası doğrulaması için (kapanışı geri alma, 2026-08-18).
  /// null iken "Hesabı Geri Al" düğmesi HİÇ çizilmez: parola sunucuda doğrulanır ve oturumsuz
  /// bir ekranda doğrulanacak bir şey yoktur.
  final Session? session;

  /// Bayinin kurye izin ayarları (`tenant_settings`). Rolle birleşip yetkiyi verir.
  /// Verilmezse `KuryeIzinleri.varsayilan` — ürünün varsayılan davranışı.
  final KuryeIzinleri? kuryeIzin;

  /// Verilirse üst çubukta hamburger çizilir (sekme olarak açıldığında); yoksa geri oku.
  final VoidCallback? onMenu;

  /// Oturumdaki rol `patron|operator|kurye`. null → yetki verilmemiş sayılır.
  final String? rol;

  /// Oturumdaki kullanıcı kimliği. İKİ İŞ yapar: kurye bu ekranı KENDİ kapsamında açar, ve
  /// gün hesabı kapsamında girilen gider bu kişiye yazılır.
  final String? kullaniciId;

  /// Test dikişi — "bugün"ün ne olduğu dışarıdan verilebilir. Verilmezse düzeltilmiş sunucu
  /// saatinden çözülür (ilk yüklemede). Tarih şeridinin ileri sınırı da buna bağlıdır.
  final DateTime? bugun;

  @override
  State<DayEndScreen> createState() => _DayEndScreenState();
}

class _DayEndScreenState extends State<DayEndScreen> {
  /// SEÇİLİ KAPSAM. Kurye kendi kapsamıyla açılır; yönetici gün hesabıyla.
  late GunKapsamSecenegi _secili = widget.rol == 'kurye' && widget.kullaniciId != null
      ? GunKapsamSecenegi(etiket: 'Kendi hesabım', userId: widget.kullaniciId, rol: 'kurye')
      : const GunKapsamSecenegi(etiket: 'Tümü');

  String? get _kuryeId => _secili.userId;
  String? get _haric => _secili.haric;

  /// "Bugün/Dün" etiketlerinin ve ileri okun referans günü. Cihaz saatiyle başlar; ilk yükleme
  /// onu DÜZELTİLMİŞ sunucu gününe çeker (telefon 40 dk ileriyken 23:40'ta `bugunTr()` YARINI
  /// verir ve ekran bir günün rakamlarını gösterirken kapanış başka bir güne yazılırdı).
  late DateTime _bugun = widget.bugun ?? bugunTr();

  /// GÖSTERİLEN gün. Kullanıcı henüz gün seçmediyse düzeltilmiş "bugün"le birlikte kayar.
  late DateTime _gun = _bugun;

  /// Kullanıcı bir gün SEÇTİ mi? Saat düzeltmesi "bugün"ü kaydırabilir ama kullanıcının elle
  /// seçtiği günü kaydırmaz — ezseydik, takvimden üç gün öncesini seçen bayi bir kare sonra
  /// kendini bugünde bulurdu.
  bool _gunSecildi = false;

  late Future<GunSonuGorunumu> _gorunum = _yukle();

  /// Kapanmamış gün bandının sayaç anahtarı — artırılınca bant yeniden sayar.
  int _kapanmamisTazeleme = 0;

  /// Gider dökümünün sayaç anahtarı — ekleme/iptal sonrası açık liste yeniden okunsun diye.
  int _giderTazeleme = 0;

  /// Gün DÜZELTİLMİŞ sunucu saatinden çözülür — cihaz saatinden DEĞİL.
  Future<GunSonuGorunumu> _yukle() async {
    if (widget.bugun == null) {
      final duzeltilmis = await bugunTrDuzeltilmis(widget.db);
      _bugun = duzeltilmis;
      if (!_gunSecildi) _gun = duzeltilmis;
    }
    return gunSonuGorunumu(
      widget.db,
      _gun,
      kuryeId: _kuryeId,
      haric: _haric,
      devirKapsami: _secili.devirKapsami,
    );
  }

  void _tazele() {
    // GÖVDE BLOĞU ŞART, ok gösterimi DEĞİL: `setState(() => _gorunum = _yukle())` yazımında
    // kapanışın DEĞERİ atamanın sonucudur, yani bir `Future` — Flutter bunu "setState içinde
    // asenkron iş" sanıp assertion atar ve ekran tazelenmez.
    setState(() {
      _gorunum = _yukle();
    });
  }

  /// Gider yazıldıktan/iptal edildikten sonra: rakamlar VE açık gider dökümü birlikte tazelenir.
  /// İkisi ayrı çağrılsaydı bölüm bir kare boyunca eski listeyi yeni toplamla gösterirdi.
  void _giderTazele() {
    setState(() {
      _giderTazeleme++;
      _gorunum = _yukle();
    });
  }

  /// Bir gün kapatıldıktan sonra: rakamlar VE kapanmamış gün bandı birlikte tazelenir.
  void _kapanistanSonraTazele() {
    setState(() {
      _kapanmamisTazeleme++;
      _gorunum = _yukle();
    });
  }

  /// Aşağı çekerek yenile: önce senkron (sunucudan yeni kayıt gelebilir), sonra ekranın kendi
  /// future'ı. Sıra önemli — tersi olsaydı ekran senkrondan ÖNCEKİ veriyi hesaplardı.
  Future<void> _yenile() async {
    await yenile();
    if (mounted) _tazele();
  }

  void _kapsamSec(GunKapsamSecenegi secim) {
    setState(() {
      _secili = secim;
      _gorunum = _yukle();
    });
  }

  void _gunSec(DateTime gun) {
    final yeni = DateTime(gun.year, gun.month, gun.day);
    if (yeni == _gun) return;
    setState(() {
      _gun = yeni;
      _gunSecildi = true;
      _gorunum = _yukle();
    });
  }

  Future<void> _takvimAc() async {
    final secim = await gunTakvimiAc(
      context,
      db: widget.db,
      secili: _gun,
      bugun: _bugun,
    );
    if (secim != null) _gunSec(secim);
  }

  /// Kapsamın BAŞLIKTA ve kapanış kaydında görünen adı.
  String _kapsamAdi(List<User> kuryeler) => _kuryeId == null
      ? (_secili.gunHesabi ? 'Gün hesabı' : _secili.etiket)
      : (kullaniciAdi(kuryeler, _kuryeId) ?? 'Kurye');

  bool get _kurye => widget.rol == 'kurye';

  /// Kurye ama KİMLİĞİ YOK — kapsam çözülemez. Ekran gün hesabına DÜŞMEZ, hiçbir rakam
  /// göstermez: kapsam belirsizliği sessizce bir yetki genişlemesine dönüşmemeli.
  bool get _kapsamsizKurye => _kurye && widget.kullaniciId == null;

  /// Bu ekranın yetki kümesi. Tek yerden okunur ki bütün kapılar aynı kaynağa baksın.
  RolYetkileri get _yetki =>
      yetkiler(rol: widget.rol, atamaHedefiVar: true, izin: widget.kuryeIzin);

  /// Geçmiş günlere gidebilir mi (`gecmisHesapArsivi` — yalnız yönetici)? Kuryede tarih şeridi
  /// ve takvim HİÇ çizilmez: yetki kalıcı olarak kapalıyken dokunulamayan bir kontrol
  /// göstermek, ona sürekli kapalı bir kapı göstermektir.
  bool get _gecmisiGorebilir => _yetki.gecmisHesapArsivi;

  /// KAPATMA YALNIZ YÖNETİCİDEDİR (kullanıcı kararı 2026-08-11) ve yalnız GÜN ya da KURYE
  /// kapsamında: "Elemanlar" ve "Kendi işlemlerim" birer OKUMA kapsamıdır — `day_closings`
  /// onları tanımaz ve ekranda görünen rakam dükkânın tamamı değilken "Günü Kapat", gördüğünden
  /// başka bir şeyi kapatırdı.
  bool get _kapatabilir => _yetki.gunuKapatma && (_secili.gunHesabi || _secili.devirKapsami);

  /// GEÇMİŞ günde yalnız GÜN hesabı kapatılabilir (kullanıcı isteği 2026-08-21).
  ///
  /// Kurye kapanışı bir MUTABAKAT PENCERESİNİ kapatır; geçmiş bir güne yazmak pencereyi o güne
  /// taşır ve o günden bugüne toplanmış ama teslim edilmemiş para beklenenden DÜŞER — kuryenin
  /// cebindeki gerçek nakit sessizce silinir. Kurye mutabakatı her zaman BUGÜN yapılır.
  bool _kapatmaCubugu(GunSonuGorunumu g) =>
      g.bugunMu ? _kapatabilir : (_yetki.gunuKapatma && _secili.gunHesabi && g.kayitVar);

  /// Seçili kapsamdan ARA TAHSİLAT alma yetkisi (K2). Kapsam bir KURYE olmalı, kapsam açık
  /// olmalı ve gün BUGÜN olmalı ([GunSonuGorunumu.araTahsilatMumkun] son ikisini taşır).
  ///
  /// YALNIZ YÖNETİCİ ALIR (kullanıcı kararı 2026-08-13): ara tahsilat, nakdin kuryeden patrona
  /// GEÇTİĞİNİ söyleyen bir kayıttır ve onu parayı fiilen ALAN taraf girmelidir.
  bool _araTahsilatAlabilir(GunSonuGorunumu g) {
    if (!g.araTahsilatMumkun || g.kapsamKapali || !_secili.devirKapsami) return false;
    return _yetki.gunuKapatma;
  }

  /// Ara tahsilat İPTALİ — aynı yetki, kapsam/kilit koşulu YOK: iptalin geçerliliğini REPO bilir.
  /// null geçilirse kart satırları DOKUNULAMAZ (kurye görünümü).
  bool get _araTahsilatIptalEdebilir => _yetki.gunuKapatma;

  /// KAPANIŞI GERİ ALMA — dört devir eyleminin sonuncusu, aynı anahtar. Ek koşul OTURUMDUR:
  /// parola SUNUCUDA doğrulanıyor.
  bool get _kapanisGeriAlabilir => _yetki.gunuKapatma && widget.session != null;

  /// GİDER EKLEME kapısı (2026-08-25). Dört koşul birlikte:
  ///  • `sahaGideri` yetkisi (patron/tezgâh her zaman; kurye bayinin ayarına göre),
  ///  • gün BUGÜN — geçmiş bir güne bugünün parasını yazmak, kapanmış ya da kapanmaya hazır bir
  ///    günün kasasını geriye dönük değiştirmek olurdu (ara tahsilatla aynı kapı),
  ///  • kapsam AÇIK — kapanış o anın gerçeğini dondurur,
  ///  • kapsamın tek bir SAHİBİ olmalı. "Elemanlar" kapsamı birden çok kişiyi kapsar ve gider
  ///    tek bir `collected_by_user_id`ye yazılır; orada düğmeyi çizmek, parayı hangi cepten
  ///    düşeceğimizi bilmeden yazmak olurdu.
  bool _giderEkleyebilir(GunSonuGorunumu g) =>
      _yetki.sahaGideri && g.bugunMu && !g.kapsamKapali && _haric == null;

  /// Gider İPTALİ — ekleme ile AYNI yetki, kapsam/gün koşulu YOK: iptalin geçerliliğini (kayıt
  /// var mı · zaten iptal mi · o günün kapsamı kapalı mı) REPO bilir ve ekran onu tekrarlarsa
  /// ikisi bir gün ayrışır, satır dokunulabilir görünürken eylem patlardı.
  bool get _giderIptalEdebilir => _yetki.sahaGideri;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<User>>(
          // EKİP = TÜM AKTİF PERSONEL: kapsam listesi patronu ve tezgâhı da içerir. Dar bir
          // liste, patronun teslim ettiği siparişi "Kurye" diye yazardı.
          stream: watchAtamaHedefleri(widget.db),
          builder: (context, kuryeSnap) {
            final kuryeler = kuryeSnap.data ?? const <User>[];

            // KAPSAM SEÇENEKLERİ tek yerde üretilir — rol kapısı dahil: kurye YALNIZ kendini
            // görür, "Tümü" onun listesinde HİÇ doğmaz.
            final kapsamlar = gunKapsamlari(
              rol: widget.rol,
              benimId: widget.kullaniciId,
              ekip: kuryeler,
            );
            // Seçili kapsam listede YOKSA seçenek olarak EKLENİR; aksi hâlde seçici bir kapsamı
            // yazarken gövde başkasını gösterirdi.
            if (!kapsamlar.any((k) => k.ayniMi(_secili))) kapsamlar.insert(0, _secili);

            return FutureBuilder<GunSonuGorunumu>(
              future: _gorunum,
              builder: (context, snap) {
                final g = snap.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SipUst(
                      baslik: 'Gün Özeti',
                      // ALT SATIR ARTIK SEÇİLİ GÜNDÜR, sabit "Bugün" değil: ekran her günü
                      // gösterebiliyor ve hangi güne bakıldığı başlıkta okunmalı.
                      alt: gunTamBasligi(_gun),
                      onMenu: widget.onMenu,
                      onGeri: widget.onMenu == null
                          ? () => Navigator.of(context).maybePop()
                          : null,
                      sag: const [RehberYardimDugmesi(yuzey: RehberYuzey.gunSonu)],
                    ),

                    // ══ GÜN GEZİNMESİ ═══════════════════════════════════════════════════
                    // ‹ › günlük kullanımın tamamıdır; takvim uzağa atlamak içindir ve her
                    // günün hesabını nokta olarak gösterir. İkisi de YALNIZ geçmişi görme
                    // yetkisi olanda çizilir — kurye bugüne kilitlidir.
                    if (_gecmisiGorebilir && !_kapsamsizKurye)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            SipSpace.govde, 0, SipSpace.govde, SipSpace.lg),
                        child: Row(
                          children: [
                            Expanded(
                              child: SiparisTarihSeridi(
                                gun: _gun,
                                bugun: _bugun,
                                onDegis: _gunSec,
                              ),
                            ),
                            const SizedBox(width: SipSpace.md),
                            SipIkonButon(
                              ikon: SipIcons.takvim,
                              etiket: 'Takvimden gün seç',
                              onTap: _takvimAc,
                            ),
                          ],
                        ),
                      ),

                    // KAPANMAMIŞ GÜN BANDI kapsam seçicisinin ÜSTÜNDE (kullanıcı isteği
                    // 2026-08-21): bandın konusu seçili kapsam değil, DEFTERİN KENDİSİDİR.
                    //
                    // ARTIK EKRAN AÇMAZ, GÜNÜ DEĞİŞTİRİR (2026-08-25): geçmiş aynı ekranda
                    // olduğu için bir güne dokunmak yalnız o güne geçmektir. Eskiden yeni bir
                    // ekran push ediyordu ve geri dönünce bant yeniden sayılmak zorundaydı.
                    if (_kapatabilir)
                      KapanmamisGunBandi(
                        db: widget.db,
                        yenilemeAnahtari: _kapanmamisTazeleme,
                        onGunSec: _gunSec,
                      ),

                    // Kapsam segmenti YÖNETİCİDE her zaman çizilir. KURYEDE TEK SEÇENEK
                    // KALINCA HİÇ ÇİZİLMEZ: seçilecek bir şey olmayan bir kontrol ölüdür ve
                    // kuryeye "başka kapsamlar var ama sana kapalı" izlenimi verirdi.
                    if (!_kurye || kapsamlar.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            SipSpace.govde, 0, SipSpace.govde, SipSpace.xl),
                        child: GunKapsamSecici(
                          secenekler: kapsamlar,
                          secili: _secili,
                          onSec: _kapsamSec,
                        ),
                      ),

                    Expanded(
                      child: _kapsamsizKurye
                          ? const SipGovde(children: [
                              SipBosDurum(
                                ikon: SipIcons.wallet,
                                baslik: 'Gün özetiniz açılamadı',
                                aciklama:
                                    'Oturum bilgileriniz eksik. Çıkış yapıp yeniden girin.',
                              ),
                            ])
                          : g == null
                              ? const SipGovde(children: [SipIskelet(adet: 3)])
                              : GunOzetiGovdesi(
                                  db: widget.db,
                                  gorunum: g,
                                  kapsamAdi: _kapsamAdi(kuryeler),
                                  gunKapsami: _secili.gunHesabi,
                                  kuryeId: _kuryeId,
                                  haric: _haric,
                                  ekip: kuryeler,
                                  gun: _gun,
                                  bugun: _bugun,
                                  onYenile: _yenile,
                                  giderTazeleme: _giderTazeleme,
                                  // null → satırlar dokunulamaz (yetkisiz görünüm).
                                  onAraTahsilatIptal: _araTahsilatIptalEdebilir
                                      ? (k) => () => _araTahsilatiIptalEt(k)
                                      : null,
                                  onGiderEkle: _giderEkleyebilir(g)
                                      ? () => _giderEkle(kuryeler, g)
                                      : null,
                                  onGiderIptal: _giderIptalEdebilir
                                      ? (s) => () => _giderIptalEt(s)
                                      : null,
                                  geriAlinmisKapanislar: g.geriAlinmisKapanislar,
                                  // ÇİFT KOŞUL: yetki VE oturum (parola sunucuda doğrulanıyor).
                                  onKapanisGeriAl: _kapanisGeriAlabilir
                                      ? (k) => _kapanisiGeriAl(k, kuryeler)
                                      : null,
                                ),
                    ),

                    // ALT ÇUBUK KAPSAMSIZ KURYEDE ÇİZİLMEZ: gövdeyi gizleyip çubuğu bırakmak,
                    // gün toplamını tam da gizlemeye çalıştığımız yerden sızdırırdı.
                    // KAYITSIZ GEÇMİŞ GÜNDE DE ÇİZİLMEZ: hiç çalışılmamış bir günü "kapatmak"
                    // boş bir arşiv kaydı üretirdi.
                    if (g != null && !_kapsamsizKurye && (g.bugunMu || g.kayitVar))
                      GunOzetiAltCubugu(
                        kapsamKapali: g.kapsamKapali,
                        gunKapali: g.gunKapali,
                        bugunMu: g.bugunMu,
                        kuryeAdi: _kuryeId == null ? null : _kapsamAdi(kuryeler),
                        kapatabilir: _kapatmaCubugu(g),
                        acikSiparis: g.kapsam.acikSiparis,
                        // GÜN ENGELİ GEÇMİŞTE UYGULANMAZ: "bugün yarım kalmış bir kurye devrini
                        // tamamla" demektir ve geçmiş bir günde o devir zaten tamamlanamaz —
                        // engeli uygulamak kapatılması İMKÂNSIZ bir gün üretirdi.
                        gunEngeli: g.bugunMu && g.gunEngeli,
                        acikKuryeAdlari: g.bugunMu ? g.acikKuryeAdlari : const [],
                        toplam: g.kapsam.kasa.toplam,
                        onKapat: () => _kapat(kuryeler, g),
                        // null → düğme HİÇ çizilmez.
                        onAraTahsilat: _araTahsilatAlabilir(g)
                            ? () => _araTahsilat(kuryeler, g)
                            : null,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
