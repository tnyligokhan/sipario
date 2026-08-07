// GÜN SONU ekranı — tasarım s-gunsonu.jsx + Sipario.html `.gs-*`, `.segtab`, `.ys-alt`.
//
// Kapsam seçimi (Tümü / tek kurye) → kasa özeti · açık veresiye · arşiv.
// Alt çubuktan gün ya da kurye hesabı KAPATILIR; kapatma sayılan nakitle mutabakat ister ve
// kaydı arşive taşır (append-only, `day_closings` tablosu). Açık sipariş varken kapatma
// ENGELLENİR — kapanmış bir gün açık bir siparişi gizlerdi.
//
// Kasa/borç rakamları defterden TÜRETİLİR; ekran hiçbir bakiyeyi kendi hesaplamaz.
// Veri katmanı `isletme/gun_sonu_ozet.dart`, kartlar `isletme/gun_sonu_kartlari.dart` içinde
// (500 satır sınırı).
//
// ══ ROL KAPISI BURADADIR (K2) ══════════════════════════════════════════════════════════════
// Ayrı kasa devri ekranı kaldırılınca çekmecenin "Kasa Devri" satırı bu ekrana bağlandı, yani
// ekran artık KURYE trafiği de alıyor ve kabuk önünde rol kapısı TUTMUYOR. Kural:
//  • GÜN hesabını yalnız yönetici kapatır (`yetkiler().gunSonu`).
//  • Kurye YALNIZ kendi kurye hesabını kapatabilir — kendi kasasının kanıtı odur.
//  • Kurye başka kuryenin kapsamını SEÇEMEZ: segmentte yalnız "Tümü" + kendisi listelenir.
// Kurye "Tümü"yü okuyabilir (gün toplamları bilgi), ama oradan kapatma düğmesi çalışmaz.

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
import 'isletme/ara_tahsilat_sheet.dart';
import 'isletme/gecmis_gun_ekrani.dart';
import 'isletme/gun_kapatma_sheet.dart';
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
  });

  final AppDatabase db;

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

  /// Segmentte listelenecek kuryeler. Kurye YALNIZ kendini görür: başka kuryenin kasasını
  /// okumak onun işi değil (K2), ve göremediği kapsamı kapatması da mümkün olmaz.
  List<User> _gorunurKuryeler(List<User> kuryeler) => widget.rol == 'kurye'
      ? kuryeler.where((k) => k.id == widget.kullaniciId).toList()
      : kuryeler;

  /// Seçili kapsamı KAPATMA yetkisi (K2). Yönetici her kapsamı kapatır; kurye yalnız kendi
  /// kurye hesabını — gün hesabı ve başkasının hesabı ona kapalı.
  bool get _kapatabilir {
    if (yetkiler(rol: widget.rol, kuryeVar: true).gunSonu) return true;
    return _kuryeId != null && _kuryeId == widget.kullaniciId;
  }

  /// Seçili kapsamdan ARA TAHSİLAT alma yetkisi (K2) — [_kapatabilir]in kardeşi, ama üç ek koşul:
  ///  • Kapsam bir KURYE olmalı: ara tahsilat kuryenin cebindeki nakdi almaktır, "gün hesabından"
  ///    para alınmaz (patron zaten kendi kasasını taşır).
  ///  • Kapsam kapalıysa alınmaz — kapanmış bir hesaba sonradan para eklemek mutabakatı bozar.
  ///  • [GunSonuGorunumu.araTahsilatMumkun]: aktif kurye var mı, gün açık mı, gün BUGÜN mü.
  ///
  /// Yönetici her kuryeden alır; kurye YALNIZ kendi kapsamında (kendi kasasını patrona
  /// devrediyor). Başkasının kapsamı ona kapalı — segmentte zaten göremez, burası ikinci kapı.
  bool _araTahsilatAlabilir(GunSonuGorunumu g) {
    if (!g.araTahsilatMumkun || g.kapsamKapali || _kuryeId == null) return false;
    if (yetkiler(rol: widget.rol, kuryeVar: true).gunSonu) return true;
    return _kuryeId == widget.kullaniciId;
  }

  /// KURYE KAPSAMINDA SHEET İLE EKRAN AYNI ARALIĞI KONUŞMAYABİLİR — bunu söyleyen satırın metni.
  ///
  /// Sheet'lerin rakamları o kuryenin PENCERESİNDEN gelir (son hesap kapanışından beri; kapanışı
  /// yoksa alttan açık), ekrandaki kasa kartı ve ara tahsilat kartı ise TAKVİM GÜNÜNDEN. Hiç
  /// kapanış yapmamış bir kurye dün 5.000, bugün 3.000 topladıysa ekran 3.000, sheet 8.000 der ve
  /// bir tur boyunca bu ikisinin arasını açıklayan HİÇBİR satır yoktu — bayi hangisinin doğru
  /// olduğunu soramıyordu.
  ///
  /// KARŞILAŞTIRMA, HESAP DEĞİLDİR: burada hiçbir para türetilmiyor, iki çerçevenin AYNI parayı
  /// kapsayıp kapsamadığı soruluyor. Rakamların ikisi de repo'dan geliyor. Çakışıyorlarsa (çoğu
  /// gün böyle) satır çizilmez — açıklanacak bir fark yokken yazılan uyarı gürültüdür.
  ///
  /// TEK METİN VAR, çünkü tek hâl ULAŞILABİLİR: pencere ancak kuryenin BUGÜNKÜ bir kapanışıyla
  /// günün içinden başlayabilirdi, ama o kapanış kapsamı KİLİTLER (`kapsamKapali`) ve o hâlde ne
  /// kapatma ne ara tahsilat sheet'i açılır. Yani ayrışma her zaman "pencere geriye sarkıyor"
  /// yönündedir. İkinci bir dal yazmak, hiç oluşamayacak bir hâl için test edilemeyen kopya
  /// yazmak olurdu.
  Future<String?> _cerceveNotu(
    GunSonuGorunumu g,
    String kuryeId,
    DateTime gun, {
    required int pencereNakit,
    required int pencereTeslim,
  }) async {
    final gunTeslim =
        await CashHandoverRepository(widget.db).teslimEdilenNakit(gun, kuryeId: kuryeId);
    if (pencereNakit == g.kapsam.kasa.nakit && pencereTeslim == gunTeslim) return null;
    // Metin FORMÜL İDDİA ETMEZ (beklenen nakdin tanımı repo'nundur ve bu vardiyada iki kez
    // değişti) — yalnız hangi ARALIĞIN kapsandığını söyler.
    return 'Önceki günden devreden nakit dahil — ekrandaki gün toplamıyla aynı aralık değil.';
  }

  Future<void> _araTahsilat(List<User> kuryeler, GunSonuGorunumu g) async {
    if (!_araTahsilatAlabilir(g)) return; // düğme zaten çizilmedi; çift kapı (K2 pazarlıksız)
    final kuryeId = _kuryeId!;
    final kuryeAdi = _kapsamAdi(kuryeler);

    // Beklenen tutar REPO'DAN gelir, ekranın kasa kartından DEĞİL. Kasa kartı günün TOPLAM
    // nakdini gösterir; kuryede fiilen kalan tutar ondan farklıdır ve tanımı repo'nundur
    // (2026-08-06'da kümülatife döndü). Ekran kendi çıkarmasını yapsaydı her tanım değişikliğinde
    // sessizce ayrışır, sheet'te yazan tutar kayda geçenden farklı olurdu.
    final repo = CashHandoverRepository(widget.db);
    final onizleme = await repo.onizle(kuryeId);
    final not = await _cerceveNotu(
      g,
      kuryeId,
      _bugun,
      pencereNakit: onizleme.toplananKurus,
      pencereTeslim: onizleme.teslimEdilenKurus,
    );
    if (!mounted) return;

    final sonuc = await araTahsilatSheet(
      context,
      kuryeAdi: kuryeAdi,
      beklenen: onizleme.expectedKurus,
      cerceveNotu: not,
      senkron: g.senkron,
    );
    if (sonuc == null || !mounted) return;

    // ÜÇÜNCÜ KAPI repoda: kapsam kapalıysa `araTahsilat` StateError atar. Ekran kapıyı zaten
    // tutuyor (düğme çizilmiyor), ama sheet açıkken senkron başka bir cihazdan gelen kapanışı
    // indirebilir — o an ekranın bildiği durum bayattır. Mesaj repo'dan geldiği gibi basılır:
    // kullanıcıya "bir şeyler ters gitti" demek, tam olarak NE olduğunu bilirken bilgi saklamaktır.
    try {
      // Gün AÇIK kalır: `araTahsilat` kapanış yazmaz (bkz. repo'daki gerekçe).
      await repo.araTahsilat(
        fromUserId: kuryeId,
        toUserId: widget.kullaniciId,
        countedCashKurus: sonuc.sayilan,
        note: sonuc.not.isEmpty ? null : sonuc.not,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      SipToast.goster(context, e.message);
      _tazele(); // ekranı gerçeğe döndür: kapanmış kapsam artık kilitli görünsün
      return;
    }
    if (!mounted) return;

    SipToast.goster(context, '$kuryeAdi · ${sipTutar(sonuc.sayilan)} tahsil edildi');
    _tazele();
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
        : await _cerceveNotu(
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
            final secenekler = ['Tümü', for (final k in gorunur) k.name];

            // Seçili kapsam segmentte YOKSA (team bloğu henüz inmemiş, kurye kendi aynasında
            // görünmüyor) seçenek olarak EKLENİR. Aksi hâlde şerit "Tümü"yü işaretlerken
            // gövde kurye kapsamını gösteriyor, yani iki bileşen farklı şey söylüyordu.
            var seciliDizin = 0;
            if (_kuryeId != null) {
              final i = gorunur.indexWhere((k) => k.id == _kuryeId);
              if (i >= 0) {
                seciliDizin = i + 1;
              } else {
                secenekler.add(_kapsamAdi(kuryeler));
                seciliDizin = secenekler.length - 1;
              }
            }

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
                      sag: [
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
                    // Kapsam segmenti HER ZAMAN çizilir — tek kurye (ya da hiç kurye) varken de
                    // "Tümü" görünür (tasarım `s-gunsonu.jsx:37-41` şeridi koşulsuzdur). Segment
                    // gizlenince kurye kapsamının varlığı keşfedilemez oluyordu.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          SipSpace.govde, 0, SipSpace.govde, SipSpace.xl),
                      child: SipSegment(
                        secenekler: secenekler,
                        secili: seciliDizin,
                        // Son seçenek "çözülemeyen kapsam" olabilir (yukarıdaki dal): ona
                        // dokunmak kapsamı DEĞİŞTİRMEZ, zaten seçili olandır.
                        onSec: (i) => _kapsamSec(i == 0
                            ? null
                            : (i - 1 < gorunur.length ? gorunur[i - 1].id : _kuryeId)),
                      ),
                    ),
                    Expanded(
                      child: g == null
                          ? const SipGovde(children: [SipIskelet(adet: 3)])
                          : GunOzetiGovdesi(
                              gorunum: g,
                              kapsamAdi: _kapsamAdi(kuryeler),
                              gunKapsami: _kuryeId == null,
                              ekip: kuryeler,
                              bugun: _bugun,
                              onYenile: _yenile,
                            ),
                    ),
                    if (g != null)
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

