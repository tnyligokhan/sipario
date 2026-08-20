// Yeni Sipariş — CSS `.ys-*` / `.pos-*`. Kaynak: s-siparisler.jsx `YeniSiparis`.
// ÜÇ ADIM: müşteri seç → kalemler → özet. Ödeme tipi BURADA sorulmaz; teslim kapatılırken
// sorulur (BRIEF: mal gidince para konuşulur) — sipariş girişi telefonda birkaç dokunuşta biter.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/urun_secenekleri.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../customers/customer_form_screen.dart' show musteriEkleSheet;
import '../shell/alt_nav.dart' show SipSekme;
import '../shell/sekme_yonlendirme.dart';
import '../team.dart';
import 'order_form_kalemler.dart';
import 'order_form_parts.dart';
import 'order_parts.dart';
import 'order_queries.dart';
import 'order_sheets.dart';
import 'siparis_kapisi.dart';

export 'order_parts.dart' show LineDraft, toplamKurus;

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({
    super.key,
    required this.db,
    required this.writable,
    this.initialCustomerId,
  });

  final AppDatabase db;
  final String? initialCustomerId;

  /// Salt-okunur kip (abonelik süresi dolmuş): sipariş KAYDEDİLEMEZ, ekran okunur kalır.
  ///
  /// ZORUNLU — varsayılanı YOK. Bir kez `= true` varsayılanıyla duruyordu ve üç çağrı yerinin
  /// üçü de geçmeyi unutunca abonelik kilidi açıkken sipariş girilebildi. Yetki bayrağının
  /// varsayılanı, unutulduğunda derleyicinin susması demektir; kapı sessizce açık kalır.
  final bool writable;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  static const _adimlar = ['Müşteri', 'Kalemler', 'Özet'];

  final _arama = TextEditingController();
  final _not = TextEditingController();
  final List<LineDraft> _satirlar = [];

  int _adim = 1;
  String _sorgu = '';
  Customer? _musteri;

  bool _kaydediyor = false;
  String? _uyari;
  int _uyariSayaci = 0;

  /// Sipariş oluşturulurken SEÇİLEN kurye.
  ///
  /// SEÇİM ZORUNLUDUR — ama yalnız ATAMA YAPILABİLDİĞİNDE (bkz. [_kuryeGerekli]). Kural
  /// 2026-08-13'te kullanıcı kararıyla değişti: önce opsiyoneldi, "kimin götüreceği o an belli
  /// olmayabilir" gerekçesiyle. Yeni kural, atanmamış siparişin sahipsiz kalmasını engelliyor.
  String? _kuryeId;
  String? _kuryeAdi;

  /// Atama hedefleri ve oturumdaki rol. İkisi de AKIŞTAN okunur, tek atış değil: `user_role`
  /// sunucu sahiplidir ve giriş yanıtında GELMEZ, ilk senkron yazar — tek atış okuma "rol yok"
  /// görüp satırı sonsuza dek gizlerdi (kontör dersinin aynısı, order_list_screen.dart).
  List<User> _kuryeler = const [];
  String? _rol;

  /// Oturumdaki kullanıcı — "(siz)" işareti ve "başka biri var mı" ölçütü için.
  String? _benimId;
  StreamSubscription<SyncMetaData>? _metaAbone;
  StreamSubscription<List<User>>? _kuryeAbone;

  /// Görevli satırı KİME görünür: atama yetkisi olana (K2 — `yetkiler().atama` = ofis VE
  /// atanabilecek BAŞKA biri var). Kurye kendine iş atamaz; tek kişilik bayide satır hiç çizilmez.
  ///
  /// "BAŞKA biri" ölçütü 2026-08-20'de geldi: liste artık oturumdaki kişiyi de içeriyor, yani
  /// `isNotEmpty` tek kişilik bayide de doğru çıkar ve BRIEF'in gizleme kuralını delerdi.
  bool get _atamaYetkisi =>
      yetkiler(rol: _rol, atamaHedefiVar: _kuryeler.any((u) => u.id != _benimId)).atama;

  /// Kaydetmeden önce kurye seçilmiş OLMALI mı?
  ///
  /// ZORUNLULUK, ATAMA YETKİSİNE BAĞLIDIR — koşulsuz değildir ve olamaz. `yetkiler().atama`
  /// = `yönetici && aktif kurye var`; yani çip iki durumda hiç çizilmez:
  ///   • TEK KİŞİLİK BAYİ (aktif kurye yok) — BRIEF'in saha gerçeği: "tek kişilik bayi çoktur,
  ///     'kuryeye ata' gibi adımlar orada hiç görünmemelidir". Malı patronun kendisi götürür.
  ///   • KURYE ROLÜ (K2) — kurye kendine iş atayamaz.
  /// Zorunluluk koşulsuz olsaydı bu iki kullanıcı HİÇ sipariş oluşturamazdı: seçemeyeceği bir
  /// alan yüzünden kaydı kapanırdı. Kural bu yüzden şöyle okunur: **atama YAPILABİLİYORSA
  /// zorunludur.**
  bool get _kuryeGerekli => _atamaYetkisi && _kuryeId == null;

  /// Adım 1'e geri dönülebilir mi? Müşteri dışarıdan verilmişse (müşteri detayından "Sipariş
  /// oluştur") seçim adımı hiç gösterilmez.
  bool get _musteriKilitli => widget.initialCustomerId != null;

  @override
  void initState() {
    super.initState();
    if (_musteriKilitli) {
      _adim = 2;
      _musteriYukle(widget.initialCustomerId!);
    }
    _metaAbone = widget.db.watchSyncState().listen((meta) {
      if (!mounted || (meta.userRole == _rol && meta.userId == _benimId)) return;
      setState(() {
        _rol = meta.userRole;
        _benimId = meta.userId;
      });
    });
    _kuryeAbone = watchAtamaHedefleri(widget.db).listen((kuryeler) {
      if (!mounted) return;
      setState(() {
        _kuryeler = kuryeler;
        // Seçili görevli bu arada pasifleştiyse seçim DÜŞER. Var olmayan birine atanmış bir
        // sipariş, atanmamış bir siparişten daha kötüdür: kimse üstlenmez ama liste atanmış
        // görünür.
        _kuryeAdi = kullaniciAdi(kuryeler, _kuryeId);
        if (_kuryeId != null && _kuryeAdi == null) _kuryeId = null;
      });
    });
  }

  /// Hazır müşteriyle açılan form (müşteri detayı, çağrı kartı, harita). Kapı BURADA da koşar:
  /// çağıran ekran ne kadar dikkatli olursa olsun bayat bir istek gönderebilir (kart çizildikten
  /// sonra müşteri kara listeye alınmış ya da yeni bir sipariş açılmış olabilir). Kullanıcı
  /// vazgeçerse form hiç açılmış olmaz — geldiği yere döner.
  Future<void> _musteriYukle(String id) async {
    final c = await (widget.db.select(widget.db.customers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (!mounted || c == null) return;
    final devam = await siparisAcmadanOnceDogrula(context, db: widget.db, musteri: c);
    if (!mounted) return;
    if (!devam) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _musteri = c);
  }

  @override
  void dispose() {
    _metaAbone?.cancel();
    _kuryeAbone?.cancel();
    _arama.dispose();
    _not.dispose();
    super.dispose();
  }

  /// "Görevli Seç" — sipariş detayındaki sheet'in AYNISI, tek farkı "Atama yok" satırının da
  /// sunulması (burada seçim opsiyoneldir ve geri alınabilmelidir).
  Future<void> _kuryeSec() async {
    final secim = await kuryeSecSheet(
      context,
      kuryeler: _kuryeler,
      seciliId: _kuryeId,
      atamasizEtiketi: 'Atama yok',
      benimId: _benimId,
    );
    if (secim == null || !mounted) return; // sheet kapatıldı = vazgeçildi, seçim DEĞİŞMEZ
    setState(() {
      _kuryeId = secim == kAtanmamisKurye ? null : secim;
      _kuryeAdi = kullaniciAdi(_kuryeler, _kuryeId);
    });
  }

  int get _toplam => toplamKurus(_satirlar);
  bool get _sepetBos => _satirlar.isEmpty;

  void _geri() {
    if (_adim == 1 || (_adim == 2 && _musteriKilitli)) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _adim--);
  }

  /// Adım rozetine dokunma — YALNIZ GERİ. Şerit bir sekme çubuğuna benziyor ve kullanıcı ona
  /// öyle davranıyor; geçilmiş bir adıma dönmek "Değiştir"/"Düzenle" bağlantılarının zaten
  /// yaptığı iş, rozet de aynısını yapar. Müşteri dışarıdan kilitliyse adım 1 hiç var olmadı,
  /// oraya dönülmez.
  void _adimaGit(int hedef) {
    if (hedef >= _adim) return;
    if (hedef == 1 && _musteriKilitli) return;
    setState(() => _adim = hedef);
  }

  /// Formun İÇİNDEKİ seçim kapısı — müşterinin forma girdiği İKİNCİ (ve son) yol.
  /// Kara listedeki müşteri listede görünmeye devam ettiği için (bilinçli — bayi borcunu takip
  /// etmeli) buradan seçilebilir; kapı ürün adımına geçmeden durdurur.
  Future<void> _musteriSec(Customer c) async {
    final devam = await siparisAcmadanOnceDogrula(context, db: widget.db, musteri: c);
    if (!devam || !mounted) return;
    setState(() {
      _musteri = c;
      _adim = 2;
    });
  }

  /// "Yeni müşteri ekle" — tasarım `.ys-ekle` + `YeniMusteri` sheet (s-siparisler.jsx:311,414).
  /// Sipariş girerken müşteri kayıtlı değilse akıştan çıkıp Müşteriler sekmesine gitmek, telefonu
  /// elinde tutan kullanıcı için sipariş kaybıdır — kayıt burada açılır ve HEMEN seçilir.
  Future<void> _yeniMusteri() async {
    final oncekiler = await musteriKimlikleri(widget.db);
    if (!mounted) return;
    final eklendi = await musteriEkleSheet(context, db: widget.db);
    if (eklendi != true || !mounted) return;
    // Sheet `bool?` döner (imzası o — dosya başka ajanın alanı); eklenen kaydın kimliği
    // önce/sonra kümelerinin farkından bulunur.
    final sonrakiler = await musteriKimlikleri(widget.db);
    final yeniId = sonrakiler.difference(oncekiler).firstOrNull;
    if (!mounted) return;
    if (yeniId == null) return; // kayıt yapılmamış ya da senkron araya girmiş
    final yeni = await musteriOku(widget.db, yeniId);
    if (!mounted || yeni == null) return;
    _musteriSec(yeni);
  }

  void _urunEkle(Product u, int adet, SecenekSecimi secim) {
    setState(() {
      // ⚠️ BİRLEŞTİRME SEÇİME DE BAKAR (2026-08-18). Yalnız `productId`ye bakan eski kural,
      // "1 soğanlı + 1 soğansız dürüm" isteğini "2 soğansız dürüm"e çevirirdi — müşterinin
      // siparişini sessizce değiştirmek, hiç kaydetmemekten kötüdür.
      final i = _satirlar.indexWhere((l) => l.ayniKalem(u.id, secim));
      if (i >= 0) {
        _satirlar[i].qty += adet;
      } else {
        _satirlar.add(LineDraft(
          productId: u.id,
          name: u.name,
          unitPriceKurus: u.unitPriceKurus,
          unit: u.unit,
          qty: adet,
          secim: secim,
        ));
      }
      _uyari = null;
    });
  }

  void _adetDegis(int i, int delta) {
    setState(() {
      final yeni = _satirlar[i].qty + delta;
      if (yeni <= 0) {
        _satirlar.removeAt(i);
      } else {
        _satirlar[i].qty = yeni;
      }
    });
  }

  Future<void> _serbestEkle() async {
    final draft = await serbestSatirSheetAc(context);
    if (draft == null || !mounted) return;
    setState(() {
      _satirlar.add(draft);
      _uyari = null;
    });
  }

  /// Sepetteki TEK satırın notu. Sheet `null` dönerse vazgeçilmiştir ve mevcut not DEĞİŞMEZ;
  /// boş dizgi dönerse not silinmiştir ([satirNotuSilindi]).
  Future<void> _satirNotu(int i) async {
    final satir = _satirlar[i];
    final sonuc = await satirNotuSheetAc(context, urunAd: satir.name, mevcut: satir.note);
    if (sonuc == null || !mounted) return;
    // Sheet açıkken sepet değişmiş olabilir (kullanıcı arkada bir şey silemez ama savunma ucuz):
    // satır düştüyse yazacak yer yok.
    if (i >= _satirlar.length || !identical(_satirlar[i], satir)) return;
    setState(() => satir.note = notuNormalle(sonuc));
  }

  void _devam() {
    if (_sepetBos) {
      setState(() {
        _uyari = 'Sepet boş — önce ürün ekleyin.';
        _uyariSayaci++; // aynı uyarı tekrar gösterilse de sarsıntı yeniden oynasın
      });
      return;
    }
    setState(() {
      _uyari = null;
      _adim = 3;
    });
  }

  Future<void> _kaydet() async {
    if (_sepetBos || _kaydediyor) return;
    // Kurye kapısı — sepet boş kapısının aynısı: engel SESSİZ DEĞİL, sebebini yazar ve
    // sarsıntıyla kendini gösterir. Pasif bir düğme "neden basılmıyor?" sorusunu cevapsız
    // bırakırdı; düğme sönük ama canlı, dokunulunca eksiği söylüyor.
    if (_kuryeGerekli) {
      setState(() {
        _uyari = kuryeZorunluUyarisi;
        _uyariSayaci++;
      });
      return;
    }
    setState(() => _kaydediyor = true);
    try {
      final repo = OrderRepository(widget.db);
      final orderId = await repo.create(
        customerId: _musteri?.id,
        note: _not.text.trim().isEmpty ? null : _not.text.trim(),
        lines: _satirlar
            .map((l) => LineInput(
                  productId: l.productId,
                  productName: l.name,
                  // KATALOG FİYATI gönderilir, ekstralar ta eklenir:
                  // fiyat formülü tek yerde durmalı (bkz. ).
                  unitPriceKurus: l.unitPriceKurus,
                  unit: l.unit,
                  isCustom: l.serbest,
                  qty: l.qty,
                  note: l.note,
                  secim: l.secim,
                ))
            .toList(),
      );
      // Atama MEVCUT yoldan yazılır: `assign` → `assigned` OLAYI → outbox → sync push. Formda
      // ikinci bir yazma yolu YOK; `orders.assigned_user_id` yalnız o olayın önbelleğidir
      // (DECISIONS). Sipariş kaydı ile atama iki ayrı olaydır ve öyle kalmalı — atama sonradan
      // değişebilen bir karardır, siparişin doğuşuna gömülmez.
      final kurye = _kuryeId;
      if (kurye != null) await repo.assign(orderId, kurye);
      if (!mounted) return;
      SipToast.goster(context, 'Sipariş oluşturuldu');
      // İş bitti: kullanıcı formun geldiği yere değil, SONUCUN göründüğü yere gitmeli.
      // Eskiden yalnız form kapanıyordu; müşteri kartından girilen sipariş kaydedilince karta
      // dönülüyor ve yeni kayıt hiçbir yüzeyde görünmüyordu (kullanıcı isteği 2026-08-04).
      // Kabuk bağlı değilse (widget testleri, önizleme) eski davranış aynen korunur.
      if (!sekmeyeGit(SipSekme.siparis)) Navigator.of(context).maybePop(true);
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(
              baslik: 'Yeni Sipariş',
              alt: _musteri?.name ?? 'Müşteri seçin',
              onGeri: _geri,
            ),
            AdimGostergesi(adimlar: _adimlar, adim: _adim, onAdim: _adimaGit),
            // Salt-okunur uyarısı İLK adımdan itibaren durur. Yalnız son adımda göstermek,
            // kullanıcıya sepeti doldurttuktan sonra "kaydedemezsin" demek olurdu.
            if (!widget.writable)
              const Padding(
                padding: EdgeInsets.fromLTRB(SipSpace.govde, SipSpace.lg, SipSpace.govde, 0),
                child: SipNotKutusu(
                  metin: 'Salt-okunur kip: yeni kayıt eklenemez.',
                  ikon: SipIcons.lock,
                  tur: SipNotTuru.hata,
                ),
              ),
            Expanded(
              child: switch (_adim) {
                1 => _adim1(),
                2 => _adim2(),
                _ => _adim3(),
              },
            ),
            if (_adim == 2)
              YsAltCubugu(
                toplamKurus: _toplam,
                uyari: _uyari,
                uyariAnahtar: '$_uyariSayaci',
                // Sepet boşken düğme SÖNÜK ama ölü değil (tasarım `opacity: bosMu ? .6 : 1`,
                // s-siparisler.jsx:363). Tamamen pasif bir düğme sebebini söyleyemez; sönük
                // düğme "burası henüz hazır değil" der, basılınca da nedenini yazar.
                buton: Opacity(
                  opacity: _sepetBos ? 0.6 : 1,
                  child: SipButon(
                    etiket: 'Devam',
                    ikon: SipIcons.right,
                    genisle: false,
                    yatayPadding: 24,
                    onTap: _devam,
                  ),
                ),
              ),
            if (_adim == 3)
              YsAltCubugu(
                toplamKurus: _toplam,
                // SALT-OKUNUR uyarısı burada TEKRARLANMAZ (yukarıdaki kalıcı şerit söylüyor).
                // Buradaki uyarı yalnız kurye kapısınındır ve ancak kaydetmeye çalışınca çıkar —
                // dokunmadan önce hata göstermek, henüz yapılmamış bir şeyi yanlış ilan etmektir.
                uyari: _uyari,
                uyariAnahtar: '$_uyariSayaci',
                // Kurye çipi kaydet düğmesinin YANINDA (kullanıcı isteği 2026-08-13): kararla
                // eylem aynı bakışta. Atama yetkisi yoksa (kurye rolü, tek kişilik bayi) çip
                // hiç verilmez ve çubuk tek eylemli hâline döner.
                yanEylem: _atamaYetkisi
                    ? AltKuryeCipi(
                        kuryeAdi: _kuryeAdi,
                        secili: _kuryeId != null,
                        onTap: _kuryeSec,
                      )
                    : null,
                // Kurye eksikken düğme SÖNÜK ama canlı — adım 2'deki "Devam"la aynı dil.
                buton: Opacity(
                  opacity: _kuryeGerekli ? 0.6 : 1,
                  child: SipButon(
                    etiket: 'Siparişi Kaydet',
                    ikon: SipIcons.check,
                    genisle: false,
                    yatayPadding: 20,
                    yukleniyor: _kaydediyor,
                    onTap: widget.writable ? _kaydet : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Yardımcı akışlar bir kez abone edilir — arama yazılırken yeniden abone olup titremesinler.
  late final Stream<Map<String, String>> _telefonlar = watchBirincilTelefonlar(widget.db);
  late final Stream<Map<String, AdresBilgi>> _adresler = watchBirincilAdresler(widget.db);

  // ── Adım 1 — müşteri seç ────────────────────────────────────────────────────────────────
  // Çizim `order_form_parts.dart`ta; ekran yalnız DURUMU (arama sorgusu, seçim) tutar.
  Widget _adim1() => MusteriSecimAdimi(
        db: widget.db,
        arama: _arama,
        sorgu: _sorgu,
        telefonlar: _telefonlar,
        adresler: _adresler,
        onSorgu: (v) => setState(() => _sorgu = v),
        onTemizle: () => setState(() {
          _arama.clear();
          _sorgu = '';
        }),
        onSec: _musteriSec,
        onYeniMusteri: widget.writable ? _yeniMusteri : null,
      );

  // ── Adım 2 — kalemler ───────────────────────────────────────────────────────────────────
  // Çizim `order_form_kalemler.dart`ta; DURUM (sepet, adetler, satır notları) burada kalır.
  Widget _adim2() => KalemlerAdimi(
        db: widget.db,
        musteri: _musteri,
        musteriKilitli: _musteriKilitli,
        satirlar: _satirlar,
        onMusteriDegistir: () => setState(() => _adim = 1),
        onUrunEkle: _urunEkle,
        onSerbestEkle: _serbestEkle,
        onAdetDegis: _adetDegis,
        onSil: (i) => setState(() => _satirlar.removeAt(i)),
        onSatirNotu: _satirNotu,
        onBildir: (m) => SipToast.goster(context, m),
      );

  // ── Adım 3 — özet ───────────────────────────────────────────────────────────────────────
  // Çizim `order_form_parts.dart`ta.
  Widget _adim3() => SiparisOzetiAdimi(
        musteri: _musteri,
        satirlar: _satirlar,
        toplamKurus: _toplam,
        not: _not,
        telefonlar: _telefonlar,
        adresler: _adresler,
        onKalemleriDuzenle: () => setState(() => _adim = 2),
      );
}
