// GÜN SONU ekranı — tasarım s-gunsonu.jsx + Sipario.html `.gs-*`, `.segtab`, `.ys-alt`.
//
// Kapsam seçimi (Tümü / tek kurye) → kasa özeti · açık veresiye · arşiv.
// Alt çubuktan gün ya da kurye hesabı KAPATILIR; kapatma sayılan nakitle mutabakat ister ve
// kaydı arşive taşır (append-only, `day_closings` tablosu). Açık sipariş varken kapatma
// ENGELLENİR — kapanmış bir gün açık bir siparişi gizlerdi.
//
// Kasa/borç rakamları defterden TÜRETİLİR; ekran hiçbir bakiyeyi kendi hesaplamaz. 500 satır
// sınırı yüzünden üç komşu dosya: veri `isletme/gun_sonu_ozet.dart` · kartlar
// `isletme/gun_sonu_kartlari.dart` · ara tahsilat akışları `isletme/gun_ozeti_eylemleri.dart`.
// Burada DURUM ve YETKİ kalır.
//
// ══ ROL KAPISI BURADADIR (K2) ══════════════════════════════════════════════════════════════
// Ayrı kasa devri ekranı kaldırılınca çekmecenin "Kasa Devri" satırı bu ekrana bağlandı, yani
// ekran artık KURYE trafiği de alıyor ve kabuk önünde rol kapısı TUTMUYOR. Kural (2026-08-13
// itibarıyla — üç PARA EYLEMİNİN ÜÇÜ DE `yetkiler().gunuKapatma`ya, yani YÖNETİCİYE bağlıdır):
// hesap kapatma · ara tahsilat ALMA · ara tahsilat İPTALİ. Kuryeye kalan tek şey OKUMAKTIR:
// kendi kapsamının tahsilat ve teslimat dökümü — başka kuryenin kapsamını seçemez, segmentte
// yalnız kendisi listelenir ("Tümü" de yok).
//
// ÜÇÜNÜN AYNI ANAHTARI PAYLAŞMASI BİLİNÇLİ: yetki matrisi "Günü Kapatma / Devir İşlemi (Yalnızca
// Yönetici)" diyor ve ara tahsilat da, iptali de birer devir işlemidir. Her biri için ayrı bir
// yetki alanı açmak, matriste karşılığı olmayan bir ayrım uydurmak ve üçünün bir gün sessizce
// ayrışmasına kapı açmak olurdu.
//
// HER KAPI ÇİFTTİR: ekran düğmeyi hiç çizmez VE eylem fonksiyonu yetkiyi yeniden sorar. Tek kapı
// yetmez, çünkü ekranın bildiği durum sheet/diyalog açıkken senkronla bayatlayabilir.

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../auth/session.dart';
import '../sync/yenileme.dart';
import '../repo/cash_handover_repository.dart';
import '../repo/day_closing_repository.dart';
import '../theme/components/atoms.dart';
import '../theme/components/overlays.dart';
import '../theme/components/states.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import 'isletme/gecmis_gun_ekrani.dart';
import 'isletme/gun_kapatma_sheet.dart';
import 'isletme/gun_kapsami.dart';
import 'isletme/gun_ozeti_eylemleri.dart';
import 'isletme/gun_ozeti_govdesi.dart';
import 'isletme/gun_sonu_kartlari.dart';
import 'isletme/gun_sonu_ozet.dart';
import 'isletme/kapanis_geri_alma.dart';
import 'team.dart';


// Veri katmanı bu ekranın genel yüzeyinin parçası olarak kalır: testler ve kabuk `bugunTr` /
// `gunSonuOzeti`yi buradan import ediyor, dosya bölünürken o imzalar kırılmasın.
export 'isletme/gun_sonu_ozet.dart'
    show bugunTr, gunSonuOzeti, GunSonuOzet, kapsamOzeti, KapsamOzeti, GunSonuGorunumu;

// EKRAN İKİYE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 513 satırdı): deftere YAZAN üç eylem
// ayrı parçada. Ekranın özel durumunu yazdıkları için `part`tır.
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
  });

  final AppDatabase db;

  /// Oturum — YALNIZ yönetici parolası doğrulaması için (kapanışı geri alma, 2026-08-18).
  ///
  /// OPSİYONEL ve null iken "Hesabı Geri Al" düğmesi HİÇ çizilmez. Bu, testlerin/önizlemenin
  /// ekranı oturumsuz açabilmesi içindir; ama aynı zamanda doğru varsayılan: parola sunucuda
  /// doğrulanır ve oturumsuz bir ekranda doğrulanacak bir şey yoktur.
  final Session? session;

  /// Bayinin kurye izin ayarları (`tenant_settings`). Rolle birleşip yetkiyi verir.
  ///
  /// Verilmezse `KuryeIzinleri.varsayilan` kullanılır — yani ekran tek başına açıldığında
  /// (test/önizleme) bayinin özel ayarları değil, ürünün varsayılan davranışı geçerlidir.
  final KuryeIzinleri? kuryeIzin;

  /// Verilirse üst çubukta hamburger çizilir (sekme olarak açıldığında); yoksa geri oku.
  final VoidCallback? onMenu;

  /// Oturumdaki rol `patron|operator|kurye`. null → yetki verilmemiş sayılır (yönetici eylemi
  /// yok); tek başına açılan testlerde/önizlemede kapsam yine gezilebilir.
  final String? rol;

  /// Oturumdaki kullanıcı kimliği. İKİ İŞ yapar:
  ///  1. [rol] `kurye` ise ekran KENDİ KAPSAMINDA açılır (kurye çekmeceden "Kasa Devri" ile
  ///     buraya geliyor; "Tümü"de açılınca kendi devrini bulmak için segmenti elle çevirmesi
  ///     gerekiyordu).
  ///  2. Kapatma yetkisinin sahibi budur: kurye yalnız `kullaniciId == kapsam` iken kapatabilir.
  final String? kullaniciId;

  @override
  State<DayEndScreen> createState() => _DayEndScreenState();
}

class _DayEndScreenState extends State<DayEndScreen> {
  /// SEÇİLİ KAPSAM (2026-08-20). Kurye kendi kapsamıyla açılır; yönetici gün hesabıyla.
  ///
  /// Rol bilgisi henüz gelmemişse (`_secili.rol == null`) sorun değil: rol yalnız KAPATMA
  /// kapısını etkiler ve o kapı her koşulda ikinci kez sorulur.
  late GunKapsamSecenegi _secili = widget.rol == 'kurye' && widget.kullaniciId != null
      ? GunKapsamSecenegi(etiket: 'Kendi hesabım', userId: widget.kullaniciId, rol: 'kurye')
      : const GunKapsamSecenegi(etiket: 'Tümü');

  /// Seçili kişinin kimliği; gün hesabında ve "Elemanlar"da null. Ekranın geri kalanı (kapatma,
  /// ara tahsilat, gövde) bu alanı okur — kapsam tipini her yerde yeniden çözmek yerine.
  String? get _kuryeId => _secili.userId;

  /// "Elemanlar" kapsamında hariç tutulan kişi (oturumdaki kullanıcı); diğer kapsamlarda null.
  String? get _haric => _secili.haric;

  // İlk yükleme de kapsamı taşır: ön seçim varken `kuryeId` geçilmezse ekran bir kare boyunca
  // gün toplamlarını kurye kapsamı etiketiyle gösteriyordu.
  late Future<GunSonuGorunumu> _gorunum = _yukle();

  /// Gün, DÜZELTİLMİŞ sunucu saatinden çözülür — cihaz saatinden DEĞİL. Telefon 40 dk ileriyken
  /// saat 23:40'ta `bugunTr()` YARINI verir, oysa kayıt BUGÜNE düşer; ekran bir günün rakamlarını
  /// gösterirken kapanış başka bir güne yazılırdı.
  ///
  /// Gün bir KARAR ALANI OLARAK TUTULMAZ: para yazan her akış onu kendi anında yeniden çözer
  /// (burada ve [_kapat] içinde). Saklansaydı, akşamdan beri açık duran bir ekran gece yarısından
  /// sonra dünün gününe kayıt yazardı.
  Future<GunSonuGorunumu> _yukle() async {
    final gun = await bugunTrDuzeltilmis(widget.db);
    // GÖSTERİM için son çözülen gün saklanır: arşiv satırlarındaki "Bugün/Dün" kelimesi buna
    // göre yazılır. Yazma kararı vermez — yalnız kelime seçer, o yüzden bir kare bayat kalması
    // zararsızdır (gövde zaten ancak bu future çözüldükten SONRA çiziliyor).
    _bugun = gun;
    return gunSonuGorunumu(widget.db, gun, kuryeId: _kuryeId, haric: _haric);
  }

  /// "Bugün/Dün" etiketlerinin referans günü. Cihaz saatiyle başlar, ilk yükleme onu düzeltilmiş
  /// güne çevirir.
  DateTime _bugun = bugunTr();

  void _tazele() {
    setState(() {
      _gorunum = _yukle();
    });
  }

  /// Aşağı çekerek yenile: önce senkron (sunucudan yeni kayıt gelebilir), sonra ekranın
  /// kendi future'ı. Sıra önemli — tersi olsaydı ekran senkrondan ÖNCEKİ veriyi hesaplardı.
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

  /// Kapsamın BAŞLIKTA ve kapanış kaydında görünen adı.
  ///
  /// Kişi kapsamında ekipten çözülür (etiket "Ali · Kurye" gibi rol de taşır; kapanış notunda
  /// sade ad gerekir). Gün hesabında ve "Elemanlar"da seçeneğin kendi etiketi kullanılır.
  String _kapsamAdi(List<User> kuryeler) => _kuryeId == null
      ? (_secili.gunHesabi ? 'Gün hesabı' : _secili.etiket)
      : (kullaniciAdi(kuryeler, _kuryeId) ?? 'Kurye');

  bool get _kurye => widget.rol == 'kurye';

  /// Kurye ama KİMLİĞİ YOK — kapsam çözülemez.
  ///
  /// Bu hâlde ekran gün hesabına DÜŞMEZ, hiçbir rakam göstermez. Düşseydi kimliği çözülemeyen
  /// bir kurye bütün dükkânın kasasını görürdü; yani kapsam belirsizliği sessizce bir yetki
  /// genişlemesine dönüşürdü. Belirsizlikte AÇILAN değil KAPANAN taraf seçilir.
  bool get _kapsamsizKurye => _kurye && widget.kullaniciId == null;

  // KAPSAM SÜZGECİ BURADAN TAŞINDI (2026-08-20): "kurye yalnız kendini görür" kuralı artık
  // `gunKapsamlari()` içinde, seçenek listesinin ÜRETİLDİĞİ yerde duruyor. İki yerde durması
  // (liste + süzgeç) birinin bir gün diğerini yakalayamaması demekti.

  /// Seçili kapsamı KAPATMA yetkisi (K2). Yönetici her kapsamı kapatır; kurye yalnız kendi
  /// kurye hesabını — gün hesabı ve başkasının hesabı ona kapalı.
  /// Bu ekranın yetki kümesi. Tek yerden okunur ki üç kapı (kapatma / ara tahsilat / geçmiş)
  /// aynı kaynağa baksın.
  RolYetkileri get _yetki => yetkiler(rol: widget.rol, atamaHedefiVar: true, izin: widget.kuryeIzin);

  /// Geçmiş gün arşivini görebilir mi (`gecmisHesapArsivi` — yalnız yönetici).
  bool get _gecmisiGorebilir => _yetki.gecmisHesapArsivi;

  /// KAPATMA YALNIZ YÖNETİCİDEDİR (kullanıcı kararı 2026-08-11: "kurye hesap kapatamaz,
  /// sadece kendi hesabının detaylarını görür").
  ///
  /// ÖNCEKİ KARARIN TERSİ ve bilinçli: 2026-08-09'da kurye KENDİ kapsamını kapatabiliyordu
  /// ("kendi kasasının kanıtı odur"). Kapanış geri alınamaz bir mutabakattır ve arşive donar;
  /// yanlış sayımla kapatan kuryenin bıraktığı farkı ertesi gün patron çözemez. Kapatan taraf
  /// artık patrondur.
  ///
  /// ⚠️ DEVİR YOLU DA KURYEDEN ALINDI (2026-08-13). Bu doc bir tur boyunca "ara tahsilat kuryede
  /// DURUYOR, kaldırılsaydı kurye cebindeki parayı sisteme hiç işleyemezdi" diyordu ve o cümle
  /// artık YANLIŞ: kurye ne kapatır ne ara tahsilat verir. Kuryedeki nakdi sisteme geçiren TEK
  /// yol, patronun o kuryeden ara tahsilat ALMASIDIR ([_araTahsilatAlabilir]).
  /// ⚠️ KAPSAM KAPISI DA BURADA (2026-08-20): kapatma yalnız GÜN hesabında ya da bir KURYE
  /// kapsamında yapılır. "Elemanlar" ve "Kendi işlemlerim" birer OKUMA kapsamıdır — ekranda
  /// gösterilen rakam dükkânın tamamı değilken "Günü Kapat" düğmesi, gördüğünden başka bir şeyi
  /// kapatırdı. `day_closings` yalnız iki kapsam tanır (day · courier); üçüncü bir kapsamı
  /// oraya yazmanın yolu yok, dolayısıyla düğmenin çizilmemesi doğru davranıştır.
  bool get _kapatabilir =>
      _yetki.gunuKapatma && (_secili.gunHesabi || _secili.devirKapsami);

  /// Seçili kapsamdan ARA TAHSİLAT alma yetkisi (K2) — [_kapatabilir]in kardeşi, ama üç ek koşul:
  ///  • Kapsam bir KURYE olmalı: ara tahsilat kuryenin cebindeki nakdi almaktır, "gün hesabından"
  ///    para alınmaz (patron zaten kendi kasasını taşır).
  ///  • Kapsam kapalıysa alınmaz — kapanmış bir hesaba sonradan para eklemek mutabakatı bozar.
  ///  • [GunSonuGorunumu.araTahsilatMumkun]: aktif kurye var mı, gün açık mı, gün BUGÜN mü.
  ///
  /// YALNIZ YÖNETİCİ ALIR (kullanıcı kararı 2026-08-13) — ÖNCEKİ KARARIN TERSİ. Burada bir tur
  /// boyunca `_kuryeId == widget.kullaniciId` satırı vardı ve kuryeye kendi kasasını kendi
  /// kaydetme yetkisi veriyordu. O yol KAPANDI: ara tahsilat, nakdin kuryeden patrona GEÇTİĞİNİ
  /// söyleyen bir kayıttır ve onu parayı fiilen ALAN taraf girmelidir. Kurye kendi teslimini
  /// kendi yazabildiği sürece kayıt tek taraflı bir BEYANDI; patron ertesi gün "ben bu parayı
  /// almadım" dediğinde defterde iki tarafın da dayanağı yoktu. Kurye çıkmaza girmez: nakit yine
  /// sisteme girer, yalnız kaydı patron açar.
  bool _araTahsilatAlabilir(GunSonuGorunumu g) {
    // KAPSAM KURYE OLMALI: ara tahsilat, nakdi taşıyan KURYEDEN alınır. Patronun/tezgâhın
    // "kendi işlemlerim" kapsamı da, "Elemanlar" da devir kapsamı değildir.
    if (!g.araTahsilatMumkun || g.kapsamKapali || !_secili.devirKapsami) return false;
    // `_kapatabilir` ile AYNI anahtar: ikisi de birer devir işlemidir (bkz. dosya başındaki K2
    // bloğu). Ayrı bir anahtar, matriste karşılığı olmayan bir ayrım uydurmak olurdu.
    return _yetki.gunuKapatma;
  }

  /// Ara tahsilat İPTALİ — [_araTahsilatAlabilir] ile AYNI yetki, ama kapsam/kilit koşulları YOK.
  ///
  /// NEDEN BU KADAR SADE: iptalin geçerli olup olmadığını REPO bilir (kayıt var mı · zaten iptal
  /// mi · kendisi iptal kaydı mı · kapanışa bağlı mı + kapalı kapsam engeli). Ekran o koşulları
  /// tekrarlasaydı ikisi bir gün ayrışır ve satır dokunulabilir görünürken eylem patlardı.
  ///
  /// KURYE GÖRÜNÜMÜNDE null geçilir → kart satırları DOKUNULAMAZ (pasif değil): dokunup
  /// "yetkiniz yok" görmek, olmayan bir yolu varmış gibi göstermektir.
  bool get _araTahsilatIptalEdebilir => _yetki.gunuKapatma;

  /// KAPANIŞI GERİ ALMA yetkisi (2026-08-18) — üç para eyleminin dördüncüsü ve AYNI anahtarı
  /// paylaşır (`gunuKapatma`). Ayrı bir yetki alanı açmak, yetki matrisinde karşılığı olmayan
  /// bir ayrım uydurmak olurdu: kapatabilen kişi, kapattığını düzeltebilmeli.
  ///
  /// EK KOŞUL OTURUMDUR: parola SUNUCUDA doğrulanıyor (`AuthApi.parolaDogrula`), oturumsuz
  /// açılan bir ekranda (test/önizleme) doğrulanacak bir şey yok.
  bool get _kapanisGeriAlabilir => _yetki.gunuKapatma && widget.session != null;


  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<User>>(
          // EKİP ARTIK TÜM AKTİF PERSONELDİR (2026-08-20), yalnız kuryeler değil: kapsam
          // listesi patronu ve tezgâhı da içeriyor. `kullaniciAdi` çözümleri de bu listeden
          // yapılıyor — dar bir liste, patronun teslim ettiği siparişi "Kurye" diye yazardı.
          stream: watchAtamaHedefleri(widget.db),
          builder: (context, kuryeSnap) {
            final kuryeler = kuryeSnap.data ?? const <User>[];

            // KAPSAM SEÇENEKLERİ tek yerde üretilir (`gun_kapsami.dart`) — rol kapısı dahil:
            // kurye YALNIZ kendini görür, "Tümü" onun listesinde HİÇ doğmaz.
            final kapsamlar = gunKapsamlari(
              rol: widget.rol,
              benimId: widget.kullaniciId,
              ekip: kuryeler,
            );

            // Seçili kapsam listede YOKSA (team bloğu henüz inmemiş) seçenek olarak EKLENİR.
            // Aksi hâlde seçici bir kapsamı yazarken gövde başkasını gösterir, yani iki bileşen
            // farklı şey söylerdi.
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
                      alt: 'Bugün',
                      onMenu: widget.onMenu,
                      onGeri: widget.onMenu == null
                          ? () => Navigator.of(context).maybePop()
                          : null,
                      // GEÇMİŞ AYRI EKRANDIR (kullanıcı kararı 2026-08-06). Eskiden gövdenin
                      // dibinde bir liste olarak duruyordu; bu ekranın işi BUGÜNDÜR ve geçmiş
                      // onu her açılışta aşağı itiyordu. İkon TEK BAŞINA çizilmez — metinsiz bir
                      // takvim, günlük işini yapan bayiye ne açacağını söylemiyordu.
                      //
                      // GEÇMİŞ ARŞİVİ YETKİYE BAĞLI (`gecmisHesapArsivi`, 2026-08-09 kullanıcı
                      // isteği: "kurye geçmişi göremeyecek"). Yetki YALNIZ yöneticidedir; kurye
                      // için düğme HİÇ çizilmez. Gizlemek doğrudur: yetki kalıcı olarak kapalı
                      // ve dokunulamayan bir düğme kuryeye sürekli kapalı bir kapı gösterirdi.
                      // Kuryenin BUGÜNKÜ kendi kapsamı etkilenmez — kapanan yalnız geçmiştir.
                      sag: [
                        if (_gecmisiGorebilir)
                          SipMetinButon(
                            etiket: 'Geçmiş',
                            ikon: SipIcons.takvim,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => GecmisGunEkrani(
                                  db: widget.db,
                                  rol: widget.rol,
                                  kullaniciId: widget.kullaniciId,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Kapsam segmenti YÖNETİCİDE her zaman çizilir (tek kurye ya da hiç kurye
                    // varken de "Tümü" görünür — tasarım `s-gunsonu.jsx:37-41` koşulsuzdur).
                    //
                    // KURYEDE TEK SEÇENEK KALINCA HİÇ ÇİZİLMEZ: seçilecek bir şey olmayan bir
                    // segment, dokunulunca hiçbir şey değiştirmeyen ölü bir kontroldür ve
                    // kuryeye "başka kapsamlar da var ama sana kapalı" izlenimi verirdi.
                    //
                    // KOŞUL YÖNETİCİYİ KAPSAMAZ (regresyon dersi): yalnız `secenekler.length`e
                    // bakan bir kapı, hiç kuryesi olmayan bayide YÖNETİCİNİN segmentini de
                    // gizliyordu — oysa tasarım onu koşulsuz çizer ve "Tümü"nün varlığı orada
                    // bilgidir. Kapı role bağlıdır, seçenek sayısına değil.
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
                                baslik: 'Hesabınız çözülemedi',
                                aciklama: 'Oturum bilgisi eksik olduğu için kendi gün '
                                    'özetiniz getirilemiyor. Çıkış yapıp yeniden girin.',
                              ),
                            ])
                          : g == null
                              ? const SipGovde(children: [SipIskelet(adet: 3)])
                              : GunOzetiGovdesi(
                              db: widget.db,
                              gorunum: g,
                              kapsamAdi: _kapsamAdi(kuryeler),
                              gunKapsami: _kuryeId == null,
                              kuryeId: _kuryeId,
                              ekip: kuryeler,
                              bugun: _bugun,
                              onYenile: _yenile,
                              // null → hiçbir ara tahsilat satırı dokunulamaz (kurye görünümü).
                              onAraTahsilatIptal: _araTahsilatIptalEdebilir
                                  ? (k) => () => _araTahsilatiIptalEt(k)
                                  : null,
                              geriAlinmisKapanislar: g.geriAlinmisKapanislar,
                              // ÇİFT KOŞUL: yetki VE oturum. Oturum yoksa parola doğrulanamaz
                              // (sunucuda doğrulanıyor) ve düğmeyi çizip dokunuşta "oturum yok"
                              // demek, olmayan bir yolu varmış gibi göstermek olurdu.
                              onKapanisGeriAl: _kapanisGeriAlabilir
                                  ? (k) => _kapanisiGeriAl(k, kuryeler)
                                  : null,
                            ),
                    ),
                    // ALT ÇUBUK DA KAPSAMSIZ KURYEDE ÇİZİLMEZ: gövdeyi gizleyip çubuğu
                    // bırakmak, gün toplamını (`kapsam.kasa.toplam`) tam da gizlemeye
                    // çalıştığımız yerden sızdırırdı.
                    if (g != null && !_kapsamsizKurye)
                      GunOzetiAltCubugu(
                        kapsamKapali: g.kapsamKapali,
                        gunKapali: g.gunKapali,
                        kuryeAdi: _kuryeId == null ? null : _kapsamAdi(kuryeler),
                        kapatabilir: _kapatabilir,
                        acikSiparis: g.kapsam.acikSiparis,
                        gunEngeli: g.gunEngeli,
                        acikKuryeAdlari: g.acikKuryeAdlari,
                        toplam: g.kapsam.kasa.toplam,
                        onKapat: () => _kapat(kuryeler, g),
                        // null → düğme HİÇ çizilmez (tek kişilik bayi, gün kapsamı, yetkisiz
                        // kullanıcı ya da kapatılmış kapsam).
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

