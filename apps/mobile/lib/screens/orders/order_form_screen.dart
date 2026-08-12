// Yeni Sipariş — CSS `.ys-*` / `.pos-*`. Kaynak: s-siparisler.jsx `YeniSiparis`.
// ÜÇ ADIM: müşteri seç → kalemler → özet. Ödeme tipi BURADA sorulmaz; teslim kapatılırken
// sorulur (BRIEF: mal gidince para konuşulur) — sipariş girişi telefonda birkaç dokunuşta biter.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../customers/customer_form_screen.dart' show musteriEkleSheet;
import '../shell/alt_nav.dart' show SipSekme;
import '../shell/sekme_yonlendirme.dart';
import '../team.dart';
import 'order_form_parts.dart';
import 'order_parts.dart';
import 'order_queries.dart';
import 'order_sheets.dart';
import 'pos_catalog.dart';
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

  /// Sipariş oluşturulurken SEÇİLEN kurye. null = atamasız kaydedilir (seçim ZORUNLU DEĞİL —
  /// telefonu elinde tutan kullanıcı kimin götüreceğini o an bilmeyebilir; atama sipariş
  /// detayından her zaman yapılabilir).
  String? _kuryeId;
  String? _kuryeAdi;

  /// Atama hedefleri ve oturumdaki rol. İkisi de AKIŞTAN okunur, tek atış değil: `user_role`
  /// sunucu sahiplidir ve giriş yanıtında GELMEZ, ilk senkron yazar — tek atış okuma "rol yok"
  /// görüp satırı sonsuza dek gizlerdi (kontör dersinin aynısı, order_list_screen.dart).
  List<User> _kuryeler = const [];
  String? _rol;
  StreamSubscription<SyncMetaData>? _metaAbone;
  StreamSubscription<List<User>>? _kuryeAbone;

  /// Kurye satırı KİME görünür: atama yetkisi olana (K2 — `yetkiler().atama` = yönetici VE
  /// aktif kurye var). Kurye kendine iş atamaz; tek kişilik bayide satır hiç çizilmez.
  bool get _atamaYetkisi => yetkiler(rol: _rol, kuryeVar: _kuryeler.isNotEmpty).atama;

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
      if (!mounted || meta.userRole == _rol) return;
      setState(() => _rol = meta.userRole);
    });
    _kuryeAbone = watchAktifKuryeler(widget.db).listen((kuryeler) {
      if (!mounted) return;
      setState(() {
        _kuryeler = kuryeler;
        // Seçili kurye bu arada pasifleştiyse seçim DÜŞER. Var olmayan birine atanmış bir
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

  /// "Kurye Seç" — sipariş detayındaki sheet'in AYNISI, tek farkı "Atama yok" satırının da
  /// sunulması (burada seçim opsiyoneldir ve geri alınabilmelidir).
  Future<void> _kuryeSec() async {
    final secim = await kuryeSecSheet(
      context,
      kuryeler: _kuryeler,
      seciliId: _kuryeId,
      atamasizEtiketi: 'Atama yok',
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

  void _urunEkle(Product u, int adet) {
    setState(() {
      final i = _satirlar.indexWhere((l) => l.productId == u.id);
      if (i >= 0) {
        _satirlar[i].qty += adet;
      } else {
        _satirlar.add(LineDraft(
          productId: u.id,
          name: u.name,
          unitPriceKurus: u.unitPriceKurus,
          unit: u.unit,
          qty: adet,
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
                  unitPriceKurus: l.unitPriceKurus,
                  unit: l.unit,
                  isCustom: l.serbest,
                  qty: l.qty,
                  note: l.note,
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
                // Uyarı metni yukarıdaki kalıcı şeritte duruyor — burada TEKRARLANMAZ.
                // Düğmenin pasif olması (onTap: null) ile şerit birlikte yeterli.
                toplamKurus: _toplam,
                buton: SipButon(
                  etiket: 'Siparişi Kaydet',
                  ikon: SipIcons.check,
                  genisle: false,
                  yatayPadding: 20,
                  yukleniyor: _kaydediyor,
                  onTap: widget.writable ? _kaydet : null,
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
  //
  // EKRAN İKİ BÖLGEDİR: önce "nasıl eklerim", sonra "ne ekledim".
  //
  // Eskiden üç ekleme yolu (favori hapları · katalog düğmesi · serbest satır bağlantısı) sepetin
  // ÜSTÜNE, ALTINA ve ARASINA dağılmıştı; sepet ikiye bölünmüş, ekran da altı ayrı yüzeye. Aynı
  // işi yapan üç düğme birbirinden uzağa serpildiğinde kullanıcı hangisine basacağını her
  // seferinde yeniden karar vermek zorunda kalır. Üçü artık hız sırasına dizili tek bir blok:
  // her zamanki ürünler (tek dokunuş) → katalog (arama/barkod) → serbest satır (istisna).
  Widget _adim2() {
    final t = context.sip;
    return SipGovde(
      children: [
        // .ys-secili — sipariş KİMİN için giriliyor; ekranın çapası, en üstte kalır.
        Container(
          margin: const EdgeInsets.only(top: SipSpace.lg),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(color: t.accentSoft, borderRadius: SipRadius.br2),
          child: Row(
            children: [
              SipIcon(SipIcons.user, boyut: 15, kalinlik: 2.1, renk: t.accent),
              const SizedBox(width: SipSpace.md),
              Expanded(
                child: Text(
                  // Müşteri dışarıdan kilitli geldiyse (müşteri detayından "Sipariş oluştur")
                  // kayıt bir kare gecikmeyle iner — boş satır yerine bekleme işareti.
                  _musteri?.name ?? '…',
                  style: SipText.metin(13.5, w: 800).copyWith(color: t.accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_musteriKilitli)
                SdxLink(etiket: 'Değiştir', onTap: () => setState(() => _adim = 1)),
            ],
          ),
        ),

        // ── Ekleme yolları — hız sırasına göre ────────────────────────────────────────────
        // Favori ürünler: müşterinin "her zamankileri", tek dokunuşla sepete. Sipariş girişinin
        // en sık hâli zaten budur; katalogu açmak istisnadır. Favorisi olmayan müşteride bölüm
        // hiç çizilmez.
        FavoriSeridi(
          db: widget.db,
          musteriId: _musteri?.id,
          onEkle: (u) {
            _urunEkle(u, 1);
            SipToast.goster(context, '${u.name} sepete eklendi');
          },
        ),
        YsEkleDugmesi(
          etiket: 'Katalogdan ürün ekle',
          ikon: SipIcons.plus,
          onTap: () => posKatalogAc(
            context,
            db: widget.db,
            onEkle: _urunEkle,
            onBildir: (m) => SipToast.goster(context, m),
          ),
        ),
        // .ys-serbest — katalog düğmesinin hemen ALTINDA. İkisi de "sepete bir şey koy" demek;
        // aralarına sepeti sokmak, ikinci yolu listenin dibinde kaybediyordu.
        SipDokun(
          onTap: _serbestEkle,
          radius: SipRadius.br2,
          // CSS `.ys-serbest { padding: 13px 2px }` (_sayfa.html:522) — ölçü tasarımdan.
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          child: Text(
            '+ Serbest satır (katalogda olmayan iş)',
            textAlign: TextAlign.center,
            style: SipText.metin(12.5, w: 600).copyWith(color: t.muted),
          ),
        ),

        // ── Sepet ────────────────────────────────────────────────────────────────────────
        // Bölüm başlığı sepet BOŞKEN DE durur: ekleme yapıldığında düzen yerinden oynamaz,
        // kullanıcı eklediği kalemin nereye düşeceğini önceden görür. Sayaç yalnız dolu
        // sepette yazar — "0 kalem" bir bilgi değil, gürültüdür.
        SdxSec(
          // Adım rozeti "Kalemler" diyor, özet ekranı "Kalemler" diyor — sepet de aynı adı
          // taşır. Aynı şeyin akış boyunca tek adı olur.
          'Kalemler',
          sag: _sepetBos ? null : SdxAdet('${_satirlar.length} kalem'),
        ),
        if (_sepetBos)
          // BOŞ DURUM METNİ DEĞİŞTİ (2026-08-12): eski hâli "Sepet boş — katalogdan ürün
          // ekleyin" diyerek tam üstündeki düğmenin sözünü tekrarlıyordu. Boş bölüm, ne
          // yapılacağını değil BURAYA NE GELECEĞİNİ söyler; eylem zaten iki parmak yukarıda ve
          // kendi adını taşıyor.
          const YsBosDurum(metin: 'Eklenen kalemler burada listelenir')
        else
          for (var i = 0; i < _satirlar.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 7),
              child: YsSatiri(
                ad: _satirlar[i].name,
                // CSS `.ys-birim` YALNIZ birimi yazar (s-siparisler.jsx:346) — birim
                // fiyat sağdaki satır toplamının yanında ikinci kez okunmaz.
                altMetin: _satirlar[i].birimEtiketi,
                tutarKurus: _satirlar[i].unitPriceKurus * _satirlar[i].qty,
                adet: _satirlar[i].serbest ? null : _satirlar[i].qty,
                onAzalt: () => _adetDegis(i, -1),
                onArtir: () => _adetDegis(i, 1),
                onSil: () => setState(() => _satirlar.removeAt(i)),
                not: _satirlar[i].note,
                onNot: () => _satirNotu(i),
              ),
            ),
      ],
    );
  }

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
        atamaYetkisi: _atamaYetkisi,
        kuryeAdi: _kuryeAdi,
        kuryeSecili: _kuryeId != null,
        onKuryeSec: _kuryeSec,
      );
}
