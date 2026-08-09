// Siparişler ekranı — CSS `.segtab`, `.sliste`, `.srow*`, `.elle-bant`, `.ust-sirala`.
// Kaynak: s-siparisler.jsx `SiparislerEkran`.
//
// Üst: başlık + "Bugün N açık" + Sırala düğmesi (elle kipinde "Bitti").
// Altında segment sekmeleri (Açık · Teslim · Borçlu · Tümü — tasarımın dördü),
// sonra sipariş satırları. Elle sıralama kipinde satırlar sürüklenebilir hale gelir, adres/not/
// eylem şeritleri gizlenir ve sıra `orders.sort_index` olarak KALICI yazılır.
//
// Satırın kendisi order_row.dart'ta, sorgular order_queries.dart'ta, liste/bant/süzgeç parçaları
// order_list_parts.dart'ta, seçim sheet'leri order_sheets.dart'ta. Bu dosya yalnız DURUM ve akış
// birleştirmesi yapar.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../team.dart';
import 'order_detail_screen.dart';
import 'order_list_parts.dart';
import 'order_queries.dart';
import 'order_sheets.dart';
import 'siparis_arac_seridi.dart';
import 'siparis_harita.dart';
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

  // Yardımcı akışlar bir kez abone edilir — filtre değişince yeniden abone olup titremesinler.
  // Sipariş akışı filtreye bağlı olduğundan build'de kurulur.
  late final Stream<List<User>> _ekip = watchTeam(widget.db);
  late final Stream<Map<String, List<OrderLine>>> _satirlar =
      watchOrderLinesByOrder(widget.db);
  late final Stream<Map<String, int>> _tahsilatlar = watchSiparisTahsilatlari(widget.db);
  late final Stream<String> _kodTercihi = watchSiparisKoduTercihi(widget.db);
  late final Stream<Map<String, AdresBilgi>> _adresler = watchBirincilAdresler(widget.db);
  late final Stream<Map<String, String>> _telefonlar = watchBirincilTelefonlar(widget.db);
  /// Başlıktaki açık sipariş sayısı — LİSTEYLE AYNI KAPSAMI sayar (2026-08-09).
  /// Kurye kilitliyse yalnız kendine atananlar sayılır; yoksa başlık listeyle çelişirdi.
  late final Stream<int> _acikSayisi =
      watchAcikSiparisSayisi(widget.db, assignedTo: _kendiSiparisleriyleSinirli ? widget.userId : null);

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
              stream: _acikSayisi,
              initialData: 0,
              builder: (context, snap) => SipUst(
                baslik: 'Siparişler',
                // Süzgeç açıkken kimin listesine bakıldığı BAŞLIKTA yazar: yoksa patron boş
                // listeyi "sipariş yok" sanır, oysa yalnız o kuryede yoktur.
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

  // ── Gövde — dört akış tek listede birleşir ──────────────────────────────────────────────
  Widget _govde() {
    return StreamBuilder<List<User>>(
      stream: _ekip,
      initialData: const [],
      builder: (context, ekipSnap) => StreamBuilder<Map<String, List<OrderLine>>>(
        stream: _satirlar,
        initialData: const {},
        builder: (context, satirSnap) => StreamBuilder<String>(
          stream: _kodTercihi,
          initialData: 'musteri',
          builder: (context, kodSnap) => StreamBuilder<Map<String, int>>(
          stream: _tahsilatlar,
          initialData: const {},
          builder: (context, tahsilatSnap) => StreamBuilder<Map<String, AdresBilgi>>(
            stream: _adresler,
            initialData: const {},
            builder: (context, adresSnap) => StreamBuilder<Map<String, String>>(
              stream: _telefonlar,
              initialData: const {},
              builder: (context, telSnap) => StreamBuilder<List<OrderListItem>>(
              // `assignedTo` artık KURYE SÜZGECİDİR (saha hatası 6). Önceden oturumdaki
              // kullanıcı geçiliyordu ama sorgu bu parametreyi hiç kullanmıyordu — sessiz
              // ölü koddu. Kurye kendi işini "Açık" sekmesinde zaten görür.
              stream: _siparisleriIzle(),
              builder: (context, snap) {
                if (snap.hasError) {
                  // "Tekrar dene" akışı YENİDEN KURMALI: artık akış önbellekli olduğu için
                  // boş bir setState aynı ölü akışa geri abone olurdu (düğme hiçbir şey yapmaz).
                  return SipHataEkran(onTekrar: () => setState(() => _siparisAkisi = null));
                }
                final ham = snap.data;
                if (ham == null) return const SipIskelet(adet: 4);
                if (ham.isEmpty) return _bos();

                final liste = siparisleriSirala(ham, _sirala, elleSira: _elleSira);
                return SiparisListesi(
                  liste: liste,
                  satirlar: satirSnap.data ?? const {},
                  tahsilatlar: tahsilatSnap.data ?? const {},
                  kodTercihi: kodSnap.data ?? 'musteri',
                  adresler: adresSnap.data ?? const {},
                  telefonlar: telSnap.data ?? const {},
                  ekip: ekipSnap.data ?? const [],
                  elle: _elle,
                  tutamacSagda: _tutamacSagda,
                  onAc: _detayAc,
                  // Salt-okunur kipte de GEÇİLİR: çipe dokunan kullanıcı sessizlik değil
                  // gerekçe duyar (`_kuryeAc` kapıları tek yerde tutar).
                  onKuryeAc: widget.canAssign ? _kuryeAc : null,
                  onBildir: (m) => SipToast.goster(context, m),
                  onSirala: _yenidenSirala,
                );
              },
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }

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

  /// Harita ekranı — açık siparişlerin durakları, rota sırasında numaralı. "Oto Sırala" ORADA
  /// durur; dönen `true`, orada sıra yazıldığını söyleyen SİNYALDİR.
  ///
  /// Oto sıralamadan sonra liste ELLE kipine ALINMAZ (2026-08-01 kullanıcı şikâyeti: "oto
  /// sıralamadan sonra tekrar elle sıralama alanı geliyor, mantıksız"). Kullanıcı sonucu
  /// görmek istiyordu, düzenlemek değil; `rota` kipi aynı sırayı tutamaçsız gösterir ve ince
  /// ayar isteyen Sırala → "Elle sırala"yı kendisi seçer.
  Future<void> _haritaAc() async {
    final otoYapildi = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => SiparisHaritaEkrani(
        db: widget.db,
        writable: widget.writable,
        canAssign: widget.canAssign,
      ),
    ));
    if (otoYapildi != true || !mounted) return;
    setState(() {
      _sirala = OrderSort.rota;
      _elleSira = const [];
    });
  }

  /// "Kuryeye Göre" süzgeci (saha hatası 6 — patron hiçbir listede kuryeye göre süzemiyordu).
  ///
  /// Aday listesi tek atış okunur: sheet açılırken bir akış tikini beklemek, dokunma ile ekran
  /// arasına gereksiz gecikme koyardı. Süzgeç yalnız GÖRÜNÜMÜ değiştirir, hiçbir kayıt yazmaz —
  /// bu yüzden salt-okunur kipte de çalışır.
  Future<void> _kuryeSuzgeciAc() async {
    final adaylar = await watchKuryeSuzgecAdaylari(widget.db).first;
    if (!mounted) return;
    if (adaylar.isEmpty) {
      SipToast.goster(context, 'Süzülecek kullanıcı yok — ekip henüz senkronlanmadı');
      return;
    }
    final secim = await kuryeSuzgecSheet(context, adaylar: adaylar, seciliId: _kuryeId);
    if (secim == null || !mounted) return;
    setState(() {
      _kuryeId = secim == kTumKuryeler ? null : secim;
      _kuryeAdi = _kuryeId == null ? null : kuryeSuzgecEtiketi(_kuryeId, adaylar);
    });
  }

  Future<void> _kuryeAc(OrderListItem item) async {
    // Kapalı sipariş: tasarım dokunuşu YUTMAZ, nedenini söyler (s-siparisler.jsx:24).
    if (item.order.status != 'open') {
      SipToast.goster(context, 'Kapalı siparişte kurye değiştirilemez');
      return;
    }
    if (!widget.writable) {
      SipToast.goster(context, 'Salt-okunur kip: kurye atanamaz.');
      return;
    }
    final kuryeler = await watchAktifKuryeler(widget.db).first;
    if (!mounted) return;
    if (kuryeler.isEmpty) {
      SipToast.goster(context, 'Atanacak aktif kurye yok');
      return;
    }
    final secili = await kuryeSecSheet(
      context,
      kuryeler: kuryeler,
      seciliId: item.order.assignedUserId,
      baslik: 'Kurye Seç · ${item.customerName ?? 'Tezgâh satışı'}',
    );
    if (secili == null || secili == item.order.assignedUserId || !mounted) return;
    await OrderRepository(widget.db).assign(item.order.id, secili);
    if (!mounted) return;
    SipToast.goster(
        context, 'Kurye değiştirildi: ${kullaniciAdi(kuryeler, secili) ?? ''}');
  }

  Future<void> _siralamaAc() async {
    final secim = await siralamaSecSheet(
      context,
      secili: _sirala,
      // Elle sıralama `sort_set` OLAYI yazar → salt-okunur kipte sunulmaz (yeni kayıt yasağı).
      // "Rota sırası" için böyle bir kapı YOK: seçmek hiçbir şey yazmaz, kalıcı sırayı gösterir.
      secenekler: [
        for (final s in OrderSort.values)
          if (widget.writable || s != OrderSort.elle) s,
      ],
    );
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
  /// Yazma yolu repo → olay → outbox; `sort_index` yalnız türetilmiş önbellektir.
  Future<void> _yenidenSirala(List<OrderListItem> yeniSira) async {
    setState(() => _elleSira = [for (final e in yeniSira) e.order.id]);
    if (!widget.writable) {
      SipToast.goster(context, 'Salt-okunur kip: sıra kaydedilmedi.');
      return;
    }
    final repo = OrderRepository(widget.db);
    for (final girdi in elleSiraYazimi(yeniSira).entries) {
      await repo.setSortIndex(girdi.key, girdi.value);
    }
  }
}

