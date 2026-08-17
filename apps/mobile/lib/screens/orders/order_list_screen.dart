// Siparişler ekranı — CSS `.segtab`, `.sliste`, `.srow*`, `.elle-bant`, `.ust-sirala`.
// Kaynak: s-siparisler.jsx `SiparislerEkran`.
//
// Üst: başlık + "Bugün N açık" + Sırala düğmesi (elle kipinde "Bitti").
// Altında segment sekmeleri (Açık · Teslim · Borçlu · Tümü — tasarımın dördü),
// sonra sipariş satırları. Elle sıralama kipinde satırlar sürüklenebilir hale gelir, adres/not/
// eylem şeritleri gizlenir ve sıra `orders.sort_index` olarak KALICI yazılır.
//
// Satırın kendisi order_row.dart'ta, sorgular order_queries.dart'ta, liste/gövde/bant/süzgeç
// parçaları order_list_parts.dart'ta, eylemler (harita · kurye süzgeci · kurye atama · sıralama
// sheet'i) order_list_eylemler.dart'ta, seçim sheet'leri order_sheets.dart'ta. Bu dosya yalnız
// DURUMU tutar: seçili sekme, sıralama kipi, kurye süzgeci, teslim günü.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../team.dart';
import 'order_detail_screen.dart';
import 'order_list_eylemler.dart';
import 'order_list_parts.dart';
import 'order_queries.dart';
import 'siparis_arac_seridi.dart';
import 'siparis_tarih_seridi.dart';
import 'tutamac_deposu.dart';

// Sorgu/biçim yardımcıları bu ekranın YÜZEYİNDEN de erişilebilir olmalı: mevcut testler ve
// başka ekranlar `order_list_screen.dart` üzerinden çağırıyor (sözleşme — imzalar değişmez).
export 'order_queries.dart'
    show
        AdresBilgi,
        OrderFilter,
        OrderListItem,
        OrderSort,
        elleSiraYazimi,
        kAtanmamisKurye,
        gecenSure,
        musteriKodu,
        odemeTipiEtiketi,
        satirKodu,
        siparisKodu,
        saatBicimi,
        satirOzeti,
        serbestMi,
        siparisleriSirala,
        siralamaEtiketi,
        watchOrderItemsSummary,
        watchOrders;

export 'order_list_parts.dart'
    show kTumKuryeler, kuryeSuzgeciGorunur, tutamacSagdaTercihi, watchKuryeSuzgecAdaylari;

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({
    super.key,
    required this.db,
    required this.writable,
    this.userId,
    this.yetki,
    this.canAssign = false,
    this.onMenu,
  });

  final AppDatabase db;
  final bool writable;

  /// Oturumdaki kullanıcı.
  ///
  /// TARİHÇE — İKİ KEZ ANLAM DEĞİŞTİRDİ, İKİSİ DE BİLİNÇLİ:
  ///  1. 2026-07-27: `watchOrders(assignedTo:)`e bağlıydı ama sorgu o parametreyi kullanmıyordu
  ///     (sessiz ölü bağ). Bağ koparıldı ve `assignedTo` PATRONUN seçtiği bir süzgece dönüştü;
  ///     gerekçe "oturum kullanıcısını oraya bağlamak kuryenin listesini HABER VERMEDEN
  ///     daraltırdı" idi — yani sorun kısıtlamanın kendisi değil, SESSİZ olmasıydı.
  ///  2. 2026-08-09 (kullanıcı isteği): kısıtlama geri geldi ama artık **yetkiye bağlı ve
  ///     GÖRÜNÜR**. `yetki.tumSiparisleriGorme` kapalıysa liste bu kullanıcıya sabitlenir ve
  ///     başlık bunu açıkça yazar ("yalnız size atanan"). Böylece 2026-07-27'nin itirazı
  ///     karşılanmış olur: daraltma var, sessizlik yok.
  final String? userId;

  /// Rol + kurye izinlerinden türeyen yetki kümesi (`yetkiler()`), kabuktan geçer.
  ///
  /// Verilmezse `null`: ekran o zaman kısıtlama uygulamaz. Bu, testlerin ve ekranı doğrudan
  /// açan yolların davranışını değiştirmemek içindir — kısıtlamayı kabuk bilerek verir.
  final RolYetkileri? yetki;
  final bool canAssign; // kurye çipine dokununca kurye değiştirilebilir mi (K2)

  /// Kabuk çekmecesini açar. Verilmezse üstte menü düğmesi çizilmez.
  final VoidCallback? onMenu;

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  OrderFilter _filtre = OrderFilter.acik;
  OrderSort _sirala = OrderSort.saat;

  /// Kurye süzgeci (saha hatası 6). null = süzme yok. Adı ayrıca tutulur: üst başlıkta seçili
  /// kuryeyi göstermek için ekip listesini yeniden sorgulamaya değmez.
  String? _kuryeId;
  String? _kuryeAdi;

  /// Oturumdaki rol (`sync_meta.user_role`) — kurye süzgeci YALNIZ patrona görünür.
  String? _rol;

  /// Sürükle-bırak tutamacının tarafı (saha hatası 4). Varsayılan SAĞ.
  bool _tutamacSagda = tutamacSagdaTercihi;

  /// Sürükleme sırasındaki İYİMSER sıra (sipariş id'leri). Boşken kalıcı `sort_index` geçerlidir.
  List<String> _elleSira = const [];

  /// Sipariş akışı filtreye bağlı ama build'de YENİDEN KURULMAZ. `watchOrders` her çağrıda yeni
  /// bir Stream nesnesi döndürür; build'in içinde çağrılırsa StreamBuilder her setState'te akışı
  /// "değişmiş" sayar, aboneliği kopatıp `null` snapshot'a düşer ve liste bir kare iskelete iner.
  /// Kontör/rol akışı tik attıkça bu oluyordu — ve o karede `_sonListe` bayat kalıyordu.
  Stream<List<OrderListItem>>? _siparisAkisi;
  OrderFilter? _akisFiltre;
  String? _akisKurye;
  DateTime? _akisGun;

  /// TESLİM sekmesinin gün süzgeci (kullanıcı isteği 2026-08-04). Yalnız o sekmede uygulanır —
  /// gerekçesi `siparis_tarih_seridi.dart` başlığında. Sekmeler arasında gidip gelirken seçili
  /// gün KORUNUR: bayi dünün teslimatına bakıp açık işlere göz atıp geri döndüğünde kendini
  /// yeniden bugünde bulmamalı.
  DateTime _teslimGunu = bugunTr();

  /// Süzgecin gerçekten uygulanacağı gün; teslim dışı sekmelerde null (süzme yok).
  DateTime? get _aktifGun => _filtre == OrderFilter.teslim ? _teslimGunu : null;

  /// Kurye kendi siparişlerine KİLİTLİ Mİ (`yetkiler().tumSiparisleriGorme` kapalı).
  ///
  /// `userId` şart: kimliği bilinmeyen bir oturumu boş listeye kilitlemek, yetkiyi uygulamak
  /// değil ekranı bozmaktır — o durumda kısıtlama uygulanmaz ve kapı yönetici tarafında kalır.
  bool get _kendiSiparisleriyleSinirli =>
      widget.yetki != null && !widget.yetki!.tumSiparisleriGorme && widget.userId != null;

  /// Sorguya gidecek kurye kimliği. Kilitliyse oturum kullanıcısı, değilse patronun seçtiği süzgeç.
  String? get _etkinKuryeId => _kendiSiparisleriyleSinirli ? widget.userId : _kuryeId;

  /// Teslim sekmesinde geçmiş günlere gezinilebilir mi (`yetkiler().gecmisTeslimatlariGorme`).
  /// Yetki verilmemişse (kabuk dışı açılış, testler) kısıtlama uygulanmaz.
  bool get _gecmisGunlereGidebilir => widget.yetki?.gecmisTeslimatlariGorme ?? true;

  Stream<List<OrderListItem>> _siparisleriIzle() {
    final gun = _aktifGun;
    final kurye = _etkinKuryeId;
    if (_siparisAkisi == null ||
        _akisFiltre != _filtre ||
        _akisKurye != kurye ||
        _akisGun != gun) {
      _akisFiltre = _filtre;
      _akisKurye = kurye;
      _akisGun = gun;
      _siparisAkisi = watchOrders(widget.db, _filtre, assignedTo: kurye, gun: gun);
    }
    return _siparisAkisi!;
  }

  /// Başlıktaki "Bugün N açık" sayacının akışı — LİSTEYLE AYNI KAPSAMDAN ([_etkinKuryeId])
  /// beslenir ve kapsam değişince yeniden kurulur. Önbellekleme kuralı listeninkiyle aynı:
  /// build'de her çağrıda yeni Stream üretilirse StreamBuilder her setState'te aboneliği koparıp
  /// bir kare `initialData`ya (0) düşerdi.
  ///
  /// ⚠️ NEDEN `late final` DEĞİL (2026-08-09 saha bulgusu, ikinci raunt): alan hâlindeyken kapsam
  /// İLK BUILD'de bir kez değerleniyordu — oysa kapsamı belirleyen iki girdi de kabuğa ASENKRON
  /// iner (`home_shell`: `_kuryeIzin` sync_meta akışından, varsayılanı `tumSiparisler=false`;
  /// `_userId` yine akıştan). İlk karede yetki/kimlik henüz yoktur, sayaç dükkân genelinde
  /// DONAR ve veriler indiğinde liste kurye kapsamına süzülürken sayaç süzülmez: başlık
  /// "Bugün 12 açık · yalnız size atananlar" derken listede 2 sipariş kalır. Kural aynı —
  /// bir listeyi süzen kapı, o listenin SAYACINI da süzer — ama tek karelik değil KALICI olmalı.
  Stream<int>? _sayacAkisi;
  String? _sayacKapsam;

  Stream<int> _acikSayisiniIzle() {
    final kurye = _etkinKuryeId;
    if (_sayacAkisi == null || _sayacKapsam != kurye) {
      _sayacKapsam = kurye;
      _sayacAkisi = watchAcikSiparisSayisi(widget.db, assignedTo: kurye);
    }
    return _sayacAkisi!;
  }

  StreamSubscription<SyncMetaData>? _metaAbone;

  @override
  void initState() {
    super.initState();
    // Rol AKIŞTAN okunur, tek atış değil: `sync_meta.user_role` giriş yanıtı ile senkron
    // arasında değişebilir ve tek atış okuma "rol yok" görüp kurye süzgecini sonsuza dek
    // gizlerdi (sunucu sahipli alan kuralı).
    _metaAbone = widget.db.watchSyncState().listen((meta) {
      final rol = meta.userRole;
      if (!mounted || rol == _rol) return;
      setState(() => _rol = rol);
    });
  }

  @override
  void dispose() {
    _metaAbone?.cancel();
    super.dispose();
  }

  // Yardımcı akışlar (ekip · satırlar · tahsilatlar · kod tercihi · adres · telefon) artık
  // `SiparisListesiGovdesi`nin içinde, orada bir kez kuruluyor — filtre değişince yeniden abone
  // olup titremesinler. Açık sipariş SAYACI ise burada kalır: kapsama bağlı olduğu için liste
  // akışıyla aynı yerde, aynı desenle kurulur (bkz. [_acikSayisiniIzle]).

  bool get _elle => _sirala == OrderSort.elle;

  /// Segment sekmeleri — tasarımın DÖRDÜ (s-siparisler.jsx `sekmeler`). Kurye oturumunda başa
  /// eklenen "Benim" sekmesi 2026-07-26'da KALDIRILDI: tasarımda yoktu, atama kullanmayan
  /// bayide boş karşılıyordu ve "Açık" sekmesi kuryenin işini zaten gösteriyor.
  static const _sekmeler = [
    OrderFilter.acik,
    OrderFilter.teslim,
    OrderFilter.borclu,
    OrderFilter.tumu,
  ];

  static String _sekmeEtiketi(OrderFilter f) => switch (f) {
        OrderFilter.acik => 'Açık',
        OrderFilter.teslim => 'Teslim',
        OrderFilter.borclu => 'Borçlu',
        OrderFilter.tumu => 'Tümü',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    const sekmeler = _sekmeler;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<int>(
              stream: _acikSayisiniIzle(),
              initialData: 0,
              builder: (context, snap) => SipUst(
                baslik: 'Siparişler',
                // Süzgeç açıkken kimin listesine bakıldığı BAŞLIKTA yazar: yoksa patron boş
                // listeyi "sipariş yok" sanır, oysa yalnız o kuryede yoktur. RAKAM da o
                // kapsamdan gelir ([_acikSayisiniIzle]): "Bugün 12 açık · Ahmet" cümlesinde
                // sayı dükkân geneliyken adın Ahmet olması, kilitli kurye ekranındaki
                // çelişkinin patron tarafındaki kopyası olurdu.
                //
                // KURYE KİLİDİ DE BURADA SÖYLENİR — bu pazarlıksız. Listeyi haber vermeden
                // daraltmak 2026-07-27'de tam da bu yüzden geri alınmıştı; kısıtlama geri
                // gelirken sessizliği geri gelmemeli. Kurye eksik listeyi "sipariş yok" sanıp
                // teslimat kaçırmamalı, kendi kapsamına baktığını BİLMELİ.
                alt: _kendiSiparisleriyleSinirli
                    ? 'Bugün ${snap.data ?? 0} açık · yalnız size atananlar'
                    : 'Bugün ${snap.data ?? 0} açık'
                        '${_kuryeId == null ? '' : ' · ${_kuryeAdi ?? 'Kurye'}'}',
                onMenu: widget.onMenu,
                // Başlıkta TEK eylem kaldı (2026-08-01). Harita ile kurye süzgeci çıplak ikon
                // düğmeleriydi; ne yaptıkları ancak dokununca anlaşılıyordu. İkisi de sekmelerin
                // altındaki ETİKETLİ araç şeridine indi (`siparis_arac_seridi.dart`).
                sag: [
                  if (_elle)
                    SipMetinButon(etiket: 'Bitti', onTap: _elleBitir)
                  else
                    SipMetinButon(
                      etiket: 'Sırala',
                      ikon: SipIcons.sirala,
                      zemin: t.surface,
                      onTap: _siralamaAc,
                    ),
                ],
              ),
            ),

            // ── .elle-bant ────────────────────────────────────────────────────────────────
            if (_elle)
              ElleBant(
                tutamacSagda: _tutamacSagda,
                onTarafDegis: _tutamacTarafiDegis,
              ),

            // ── .segtab ───────────────────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(SipSpace.govde, 0, SipSpace.govde,
                  _elle ? SipSpace.xl : SipSpace.lg),
              child: SipSegment(
                secenekler: [for (final f in sekmeler) _sekmeEtiketi(f)],
                secili: sekmeler.indexOf(_filtre).clamp(0, sekmeler.length - 1),
                onSec: (i) => setState(() => _filtre = sekmeler[i]),
              ),
            ),

            // ── Gün gezinmesi — YALNIZ "Teslim" sekmesinde ────────────────────────────────
            // Elle sıralama kipinde gizlenir (araç şeridiyle aynı gerekçe: sıra yazılırken
            // listenin altından küme değişmemeli). Teslim sekmesinde elle sıralama zaten
            // anlamsız ama kapı burada da kapalı tutulur — kip kararı tek yerde okunmalı.
            //
            // GEÇMİŞ GÜNLERE GEZİNME YETKİYE BAĞLI (`gecmisTeslimatlariGorme`, 2026-08-09):
            // yetki kapalıysa şerit HİÇ çizilmez ve sekme bugüne sabit kalır. Şeridi çizip
            // dokunuşta reddetmek yerine gizlemek doğrudur — yetki kalıcı olarak kapalıdır ve
            // her dokunuşta aynı reddi okutmak gürültüdür (kurye yetkileri deseninin aynısı).
            // Kurye kendi BUGÜNKÜ teslimatlarını görmeye devam eder; kapanan şey geçmiş gündür.
            if (!_elle && _filtre == OrderFilter.teslim && _gecmisGunlereGidebilir)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SipSpace.govde, 0, SipSpace.govde, SipSpace.xl),
                child: SiparisTarihSeridi(
                  gun: _teslimGunu,
                  onDegis: (g) => setState(() => _teslimGunu = g),
                ),
              ),

            // ── Araç şeridi — "Harita" + kurye süzgeci ────────────────────────────────────
            // Elle kipinde TAMAMEN gizlenir: sıra yazılırken listenin altından küme
            // değişmemeli (kurye süzgecinin eski gizlenme kuralının aynısı).
            if (!_elle)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SipSpace.govde, 0, SipSpace.govde, SipSpace.xl),
                child: SiparisAracSeridi(
                  onHarita: _haritaAc,
                  // Süzgeç yalnız PATRONA çıkar (K2 dışı bir GÖRÜNÜM kapısı; kurye kendi işini
                  // görür, ona süzgeç gürültüdür).
                  onKurye: kuryeSuzgeciGorunur(_rol) ? _kuryeSuzgeciAc : null,
                  kuryeAdi: _kuryeId == null ? null : (_kuryeAdi ?? 'Kurye'),
                ),
              ),

            Expanded(child: _govde()),
          ],
        ),
      ),
    );
  }

  // ── Gövde — akışların birleşimi `order_list_parts.dart`ta ───────────────────────────────
  // `assignedTo` artık KURYE SÜZGECİDİR (saha hatası 6). Önceden oturumdaki kullanıcı
  // geçiliyordu ama sorgu bu parametreyi hiç kullanmıyordu — sessiz ölü koddu. Kurye kendi
  // işini "Açık" sekmesinde zaten görür.
  Widget _govde() => SiparisListesiGovdesi(
        db: widget.db,
        siparisler: _siparisleriIzle(),
        sirala: (ham) => siparisleriSirala(ham, _sirala, elleSira: _elleSira),
        bos: _bos(),
        elle: _elle,
        tutamacSagda: _tutamacSagda,
        onAc: _detayAc,
        // Salt-okunur kipte de GEÇİLİR: çipe dokunan kullanıcı sessizlik değil gerekçe duyar
        // (`_kuryeAc` kapıları tek yerde tutar).
        onKuryeAc: widget.canAssign ? _kuryeAc : null,
        onBildir: (m) => SipToast.goster(context, m),
        onSirala: _yenidenSirala,
        onTekrar: () => setState(() => _siparisAkisi = null),
      );

  /// Boş durum — tasarımda İKİ metin var (s-siparisler.jsx:116): "Açık" sekmesi kullanıcıya ne
  /// yapacağını söyler, kalan sekmeler tek nötr cümleyi paylaşır.
  Widget _bos() => SipBosDurum(
        ikon: SipIcons.list,
        baslik: 'Sipariş yok',
        // Süzgeç açıkken metin SÜZGECİ söyler: "sipariş yok" demek patronu yanıltırdı
        // (sipariş var, o kuryede yok).
        aciklama: _kuryeId != null
            ? '${_kuryeAdi ?? 'Seçili kurye'} için bu filtrede sipariş yok.'
            : _filtre == OrderFilter.acik
                ? 'Açık sipariş yok. Yeni sipariş için + tuşuna bas.'
                : 'Bu filtrede sipariş bulunmuyor.',
      );

  // ── Eylemler ────────────────────────────────────────────────────────────────────────────

  Future<void> _detayAc(OrderListItem item) => siparisDetaySheetAc(
        context,
        db: widget.db,
        orderId: item.order.id,
        writable: widget.writable,
        canAssign: widget.canAssign,
        // Başlık zaten elimizde — sheet açılmadan önce ikinci bir sorgu atılmasın.
        baslik: item.customerName ?? 'Tezgâh satışı',
      );

  /// Harita ekranı. Dönen `true`, orada rota sırası yazıldığını söyler → liste `rota` kipine
  /// geçer (ELLE kipine DEĞİL — gerekçe `siparisHaritasiAc` başlığında).
  Future<void> _haritaAc() async {
    final otoYapildi = await siparisHaritasiAc(
      context,
      db: widget.db,
      writable: widget.writable,
      canAssign: widget.canAssign,
    );
    if (!otoYapildi || !mounted) return;
    setState(() {
      _sirala = OrderSort.rota;
      _elleSira = const [];
    });
  }

  Future<void> _kuryeSuzgeciAc() async {
    final secim = await kuryeSuzgeciSec(context, db: widget.db, seciliId: _kuryeId);
    if (secim == null || !mounted) return;
    setState(() {
      _kuryeId = secim.id;
      _kuryeAdi = secim.ad;
    });
  }

  Future<void> _kuryeAc(OrderListItem item) => siparisKuryesiniDegistir(
        context,
        db: widget.db,
        item: item,
        writable: widget.writable,
      );

  Future<void> _siralamaAc() async {
    final secim = await siralamaSec(context, secili: _sirala, writable: widget.writable);
    if (secim == null || !mounted) return;
    setState(() {
      _sirala = secim;
      if (secim != OrderSort.elle) _elleSira = const [];
    });
    if (secim == OrderSort.elle) {
      SipToast.goster(context, 'Elle sıralama açık — tutamaçtan sürükle');
    }
  }

  /// Tutamaç tarafı değişti: ekran ANINDA döner, disk yazımı arkadan gelir (beklemek dokunmaya
  /// gereksiz gecikme koyardı; depo hata yutar, yazamasa bile tercih oturum içinde geçerli kalır).
  void _tutamacTarafiDegis(bool sagda) {
    setState(() {
      _tutamacSagda = sagda;
      tutamacSagdaTercihi = sagda; // diğer ekranlar/sonraki açılışlar aynı değeri okur
    });
    tutamacDeposu.yaz(sagda);
  }

  /// Elle kipinden çıkış. Sıralama SAAT'e değil ROTAYA döner (2026-08-01): kullanıcı az önce
  /// bir sıra kurmuştu; "Bitti"ye basınca listenin zaman sırasına atlaması, yaptığı işi gözünün
  /// önünde bozmak olurdu. "Rota sırası" aynı sırayı tutamaçsız gösterir.
  void _elleBitir() => setState(() {
        _sirala = OrderSort.rota;
        _elleSira = const [];
      });

  /// Sürükle-bırak sonrası: önce İYİMSER sıra (ekran anında oturur), sonra kalıcı yazım.
  Future<void> _yenidenSirala(List<OrderListItem> yeniSira) async {
    setState(() => _elleSira = [for (final e in yeniSira) e.order.id]);
    if (!widget.writable) {
      SipToast.goster(context, 'Salt-okunur kip: sıra kaydedilmedi.');
      return;
    }
    await elleSirayiYaz(widget.db, yeniSira);
  }
}

