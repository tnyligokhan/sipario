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
import 'isletme/gun_ozeti_eylemleri.dart';
import 'isletme/gun_ozeti_govdesi.dart';
import 'isletme/gun_sonu_kartlari.dart';
import 'isletme/gun_sonu_ozet.dart';
import 'team.dart';

// Veri katmanı bu ekranın genel yüzeyinin parçası olarak kalır: testler ve kabuk `bugunTr` /
// `gunSonuOzeti`yi buradan import ediyor, dosya bölünürken o imzalar kırılmasın.
export 'isletme/gun_sonu_ozet.dart'
    show bugunTr, gunSonuOzeti, GunSonuOzet, kapsamOzeti, KapsamOzeti, GunSonuGorunumu;

class DayEndScreen extends StatefulWidget {
  const DayEndScreen({
    super.key,
    required this.db,
    this.onMenu,
    this.rol,
    this.kullaniciId,
    this.kuryeIzin,
  });

  final AppDatabase db;

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
  /// null = "Tümü"; aksi hâlde kuryenin kullanıcı kimliği.
  late String? _kuryeId = widget.rol == 'kurye' ? widget.kullaniciId : null;

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
    return gunSonuGorunumu(widget.db, gun, kuryeId: _kuryeId);
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

  void _kapsamSec(String? kuryeId) {
    setState(() {
      _kuryeId = kuryeId;
      _gorunum = _yukle();
    });
  }

  String _kapsamAdi(List<User> kuryeler) =>
      _kuryeId == null ? 'Gün hesabı' : (kullaniciAdi(kuryeler, _kuryeId) ?? 'Kurye');

  bool get _kurye => widget.rol == 'kurye';

  /// Kurye ama KİMLİĞİ YOK — kapsam çözülemez.
  ///
  /// Bu hâlde ekran gün hesabına DÜŞMEZ, hiçbir rakam göstermez. Düşseydi kimliği çözülemeyen
  /// bir kurye bütün dükkânın kasasını görürdü; yani kapsam belirsizliği sessizce bir yetki
  /// genişlemesine dönüşürdü. Belirsizlikte AÇILAN değil KAPANAN taraf seçilir.
  bool get _kapsamsizKurye => _kurye && widget.kullaniciId == null;

  /// Segmentte listelenecek kuryeler. Kurye YALNIZ kendini görür: başka kuryenin kasasını
  /// okumak onun işi değil (K2), ve göremediği kapsamı kapatması da mümkün olmaz.
  List<User> _gorunurKuryeler(List<User> kuryeler) => _kurye
      ? kuryeler.where((k) => k.id == widget.kullaniciId).toList()
      : kuryeler;

  /// Seçili kapsamı KAPATMA yetkisi (K2). Yönetici her kapsamı kapatır; kurye yalnız kendi
  /// kurye hesabını — gün hesabı ve başkasının hesabı ona kapalı.
  /// Bu ekranın yetki kümesi. Tek yerden okunur ki üç kapı (kapatma / ara tahsilat / geçmiş)
  /// aynı kaynağa baksın.
  RolYetkileri get _yetki => yetkiler(rol: widget.rol, kuryeVar: true, izin: widget.kuryeIzin);

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
  bool get _kapatabilir => _yetki.gunuKapatma;

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
    if (!g.araTahsilatMumkun || g.kapsamKapali || _kuryeId == null) return false;
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

  Future<void> _araTahsilat(List<User> kuryeler, GunSonuGorunumu g) async {
    if (!_araTahsilatAlabilir(g)) return; // düğme zaten çizilmedi; çift kapı (K2 pazarlıksız)
    final tazelensin = await araTahsilatAl(
      context,
      db: widget.db,
      gorunum: g,
      kuryeId: _kuryeId!,
      kuryeAdi: _kapsamAdi(kuryeler),
      alanUserId: widget.kullaniciId,
      bugun: _bugun,
    );
    if (tazelensin && mounted) _tazele();
  }

  /// Bir ara tahsilatı İPTAL eder (kullanıcı kararı 2026-08-13). Kayıt SİLİNMEZ — repo ters
  /// işaretli ikinci bir devir satırı yazar (BRIEF kırmızı çizgi #2).
  Future<void> _araTahsilatiIptalEt(AraTahsilatKaydi k) async {
    if (!_araTahsilatIptalEdebilir) return; // satır zaten dokunulamaz; çift kapı (K2 pazarlıksız)
    final tazelensin = await araTahsilatIptalEt(
      context,
      db: widget.db,
      kayit: k,
      iptalEdenUserId: widget.kullaniciId,
    );
    if (tazelensin && mounted) _tazele();
  }

  Future<void> _kapat(List<User> kuryeler, GunSonuGorunumu g) async {
    if (!_kapatabilir) return; // düğme zaten kapalı; çift kapı (K2 pazarlıksız)
    final kapsamAdi = _kapsamAdi(kuryeler);
    final scope = _kuryeId == null ? ClosingScope.day : ClosingScope.courier;

    // ÜÇ RAKAM DA REPO'DAN GELİR — ekran hiçbirini çıkarmaz, çıkarmamalı da.
    //
    // TARİHÇE (2026-08-06, iki kez ısırdı): önce burada görünüm modelinin "günün nakdi − ara
    // tahsilat" getter'ı kullanılıyordu. O formül GÜN kapsamında doğru, KURYE kapsamında
    // yanlıştı — kurye kapanışı beklenen tutarı kendi mutabakat penceresinden türetiyordu ve
    // ikisini üst üste koymak aynı parayı iki kez düşürüyordu. Sheet'te yazan tutar arşive
    // donan tutardan AYRIŞACAKTI ve kayıtlar append-only olduğu için o fark kalıcı olurdu.
    // Getter o yüzden repo'dan tamamen kaldırıldı; beklenen nakdin tanımı artık tek yerde
    // (`DayClosingRepository.onizle`) yaşıyor ve iki kapsam onu paylaşıyor.
    //
    // Yani buradaki kural sadece üslup değil: bu ekranda para formülü yazmak, sessizce yalan
    // bir arşiv kaydı üretmenin en kısa yoludur.
    // GÜN, YAZMA ANINDA yeniden okunur (`_gun` alanına güvenilmez): ekran akşamdan beri açık
    // durmuş ve gece yarısını geçmiş olabilir. Damga DÜZELTİLMİŞ sunucu saatinden gelir — cihaz
    // saati 40 dk ileriyken 23:40'ta `bugunTr()` yarını verir ve kapanış yanlış güne yazılırdı.
    final gun = await bugunTrDuzeltilmis(widget.db);
    final onizleme = await DayClosingRepository(widget.db)
        .onizle(scope, userId: _kuryeId, localDate: gun);
    // Çerçeve satırı YALNIZ kurye kapsamındadır: gün kapsamında sheet de ekran da TAKVİM GÜNÜ
    // konuşur, açıklanacak bir aralık farkı yoktur.
    final not = _kuryeId == null
        ? null
        : await cerceveNotu(
            widget.db,
            g,
            _kuryeId!,
            gun,
            pencereNakit: onizleme.gunNakitKurus,
            pencereTeslim: onizleme.dusulenKurus,
          );
    if (!mounted) return;

    final sonuc = await gunKapatmaSheet(
      context,
      kapsamAdi: kapsamAdi,
      gunHesabi: _kuryeId == null,
      beklenen: onizleme.expectedCashKurus,
      tamNakit: onizleme.gunNakitKurus,
      teslimat: onizleme.deliveryCount,
      // ETİKETLER KAPSAMDAN DEĞİL, VERİDEN TÜRER. `_kuryeId == null` diye çıkarım yapmıyoruz:
      // düşülen tutarın ne olduğunu repo `dusulenKalem` ile SÖYLÜYOR. Çıkarım yapsaydık, tanım
      // bir daha değiştiğinde (bu vardiyada üç kez değişti) ekran sessizce eski anlamı yazmaya
      // devam ederdi; enum ise yeni bir değer eklendiği an derlemeyi kırar.
      ustEtiket: switch (onizleme.dusulenKalem) {
        // Kurye kapsamında üst satır günün tamamı DEĞİL, o kuryenin PENCERE nakdidir (son
        // kapanışından beri topladığı). Kurye gün içinde bir kez kapatıp yeniden çalışmışsa
        // "Günün nakdi" yazmak yanlış olur — kimlik ancak aynı çerçevede tutar.
        DusulenKalem.teslimEdilen => 'Topladığı',
        DusulenKalem.kuryelerdeKalan => 'Günün nakdi',
      },
      // "Teslim edilen" EDİLGEN biçimdedir ve bilinçlidir: bu sheet'i kurye de patron da açıyor,
      // edilgen biçim ikisinde de doğru okunuyor ("aldığım"/"verdiğim" ayrımına düşmüyor).
      //
      // GÜN KAPSAMINDA İŞARET KELİMEYİ DE DEĞİŞTİRİR. Düşülen tutar orada kuryelerin O GÜNKÜ NET
      // DEĞİŞİMİDİR ve negatif olabilir: kurye dünden taşıdığı nakdi bugün teslim ettiyse kasaya
      // günün kendi nakdinden FAZLASI girer. "Kuryelerde kalan: + 5.000 ₺" cümlesi o durumda
      // düpedüz yalandır — o para kuryede KALMADI, tam tersine kuryeden GELDİ. İşareti düzeltip
      // kelimeyi bırakmak, bu vardiyanın altı kez ısırdığı hatanın aynısı olurdu: anlamı değişen
      // sayıyı eski kelimesiyle taşımak.
      //
      // KURYE kapsamında böyle bir dal YOK ve olmamalı: teslim ancak AYNI pencerede toplanmış
      // paradan yapılabilir (`_pencere` alttan açıktır), yani orada negatif matematiksel olarak
      // imkânsızdır. Dal açsaydık, hiç oluşamayacak bir hâl için test edilemeyen kopya yazardık.
      ortaEtiket: switch (onizleme.dusulenKalem) {
        DusulenKalem.teslimEdilen => 'Teslim edilen',
        DusulenKalem.kuryelerdeKalan => onizleme.dusulenKurus < 0
            ? 'Kuryelerden devir'
            : 'Kuryelerde kalan',
      },
      ortaTutar: onizleme.dusulenKurus,
      cerceveNotu: not,
      // TAZELİK HER İKİ KAPSAMA DA geçilir (lead kararı 2026-08-06): kurye kendi telefonundan
      // da ara tahsilat teslim edebildiği için "günü kapatan cihaz zaten tahsilatı alan
      // cihazdır" varsayımı tutmuyor — risk simetrik. Gürültü ayarı sheet'in içinde: gün
      // kapsamında şerit yalnız BAYATKEN çizilir.
      senkron: g.senkron,
    );
    if (sonuc == null || !mounted) return;

    // Kapanış rakamları burada YENİDEN hesaplanmaz: repo submit anında kendi önizlemesini
    // çağırır, böylece arşive donan tutar ekranın gösterdiğiyle aynı koddan çıkar.
    // Fark ≠ 0 kapatmayı ENGELLEMEZ (BRIEF: eksik para görünür kalmalı) — kanıt olarak yazılır.
    //
    // ÜÇÜNCÜ KAPI REPODA (ara tahsilattaki desenin aynısı): kapanmış kapsam `StateError` atar.
    // Ekran düğmeyi zaten kapatıyor, ama sheet AÇIKKEN senkron başka bir cihazdan gelen kapanışı
    // indirebilir — o an ekranın bildiği durum bayattır. Yakalamasaydık kullanıcı, sayımını
    // girip "Kapat"a bastıktan sonra hiçbir açıklama görmeden çöken bir ekranla kalırdı. Mesaj
    // repo'dan geldiği gibi basılır: NE olduğunu bilirken "bir şeyler ters gitti" demek bilgi
    // saklamaktır.
    try {
      await DayClosingRepository(widget.db).kapat(
        scope: scope,
        userId: _kuryeId,
        countedCashKurus: sonuc.sayilan,
        note: sonuc.not.isEmpty ? null : sonuc.not,
        alsoHandover: _kuryeId != null,
        localDate: gun,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      SipToast.goster(context, e.message);
      _tazele(); // ekranı gerçeğe döndür: kapanmış kapsam artık kilitli görünsün
      return;
    }
    if (!mounted) return;

    SipToast.goster(
      context,
      _kuryeId == null
          ? 'Gün kapatıldı ve arşivlendi'
          : '$kapsamAdi hesabı kapatıldı ve arşivlendi',
    );
    _tazele();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<User>>(
          stream: watchAktifKuryeler(widget.db),
          builder: (context, kuryeSnap) {
            final kuryeler = kuryeSnap.data ?? const <User>[];
            final gorunur = _gorunurKuryeler(kuryeler);

            // KAPSAM SEÇENEKLERİ (id, etiket) çiftidir; `null` id = gün hesabı ("Tümü").
            //
            // "TÜMÜ" KURYEDE YOKTUR (kullanıcı isteği 2026-08-11: "tümü kısmına gerek yok,
            // kendi hesabını görse yeterli"). Eskiden kurye "Tümü"yü okuyabiliyordu ve bu,
            // bütün dükkânın kasasını kuryeye açıyordu — şikâyetin kendisi buydu. Seçenek
            // listesini role göre kurmak, kapıyı TEK yerde tutar: aşağıdaki `onSec` artık
            // kuryeye gün hesabını verebilecek bir dizin bile üretemez.
            final kapsamlar = <({String? id, String etiket})>[
              if (_kurye) ...[
                for (final k in gorunur) (id: k.id, etiket: k.name),
              ] else ...[
                (id: null, etiket: 'Tümü'),
                for (final k in gorunur) (id: k.id, etiket: k.name),
              ],
            ];

            // Seçili kapsam listede YOKSA (team bloğu henüz inmemiş, kurye kendi aynasında
            // görünmüyor) seçenek olarak EKLENİR. Aksi hâlde şerit bir kapsamı işaretlerken
            // gövde başkasını gösteriyor, yani iki bileşen farklı şey söylüyordu.
            var seciliDizin = kapsamlar.indexWhere((k) => k.id == _kuryeId);
            if (seciliDizin < 0) {
              kapsamlar.add((id: _kuryeId, etiket: _kapsamAdi(kuryeler)));
              seciliDizin = kapsamlar.length - 1;
            }
            final secenekler = [for (final k in kapsamlar) k.etiket];

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
                    if (!_kurye || secenekler.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            SipSpace.govde, 0, SipSpace.govde, SipSpace.xl),
                        child: SipSegment(
                          secenekler: secenekler,
                          secili: seciliDizin,
                          onSec: (i) => _kapsamSec(kapsamlar[i].id),
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

