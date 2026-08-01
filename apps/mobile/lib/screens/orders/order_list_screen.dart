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

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../auth/session.dart';
import '../../konum/cihaz_konumu.dart';
import '../../repo/order_repository.dart';
import '../../sync/route_api.dart';
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
import 'siparis_harita.dart';
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
    this.canAssign = false,
    this.onMenu,
  });

  final AppDatabase db;
  final bool writable;

  /// Oturumdaki kullanıcı. LİSTEYİ SÜZMEZ (2026-07-27): eskiden `watchOrders(assignedTo:)`e
  /// geçiliyordu ama sorgu o parametreyi hiç kullanmıyordu — sessiz ölü bağdı. Artık `assignedTo`
  /// gerçek bir süzgeç ve hedefini PATRON seçer; oturum kullanıcısını oraya bağlamak kuryenin
  /// listesini haber vermeden daraltırdı. Alan `home_shell` sözleşmesinde durduğu için korunuyor.
  final String? userId;
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

  /// Kalan oto-sıralama hakkı (sunucu sahipli, senkronla iner). null = HENÜZ BİLİNMİYOR →
  /// `.sr-oto` düğmesi kontör YAZMADAN, PASİF çizilir. Uydurma bir sayı göstermek yasak:
  /// kullanıcı "34 hakkım var" deyip tıkladığında sunucu 409 dönerse güven kaybolur.
  int? _otoHak;

  /// Ekranda o an gösterilen liste — "Oto Sırala" hangi siparişleri sıralayacağını buradan
  /// okur (kurye filtresi ve seçili sekme dahil, kullanıcının GÖRDÜĞÜ küme).
  ///
  /// DAİMA tazelenir, boş/yükleniyor dallarında da. Eskiden yalnız DOLU listede yazılıyordu;
  /// boş bir sekmeye geçince eski sekmenin listesi burada kalıyor ve "Oto Sırala" kullanıcının
  /// BAKMADIĞI bir kümeyi sıralayabiliyordu (sessiz bozulma).
  List<OrderListItem> _sonListe = const [];

  /// Sipariş akışı filtreye bağlı ama build'de YENİDEN KURULMAZ. `watchOrders` her çağrıda yeni
  /// bir Stream nesnesi döndürür; build'in içinde çağrılırsa StreamBuilder her setState'te akışı
  /// "değişmiş" sayar, aboneliği kopatıp `null` snapshot'a düşer ve liste bir kare iskelete iner.
  /// Kontör/rol akışı tik attıkça bu oluyordu — ve o karede `_sonListe` bayat kalıyordu.
  Stream<List<OrderListItem>>? _siparisAkisi;
  OrderFilter? _akisFiltre;
  String? _akisKurye;

  Stream<List<OrderListItem>> _siparisleriIzle() {
    if (_siparisAkisi == null || _akisFiltre != _filtre || _akisKurye != _kuryeId) {
      _akisFiltre = _filtre;
      _akisKurye = _kuryeId;
      _siparisAkisi = watchOrders(widget.db, _filtre, assignedTo: _kuryeId);
    }
    return _siparisAkisi!;
  }

  /// Rotaya girebilecek küme: görünen listenin YALNIZ açık siparişleri (sunucu da böyle süzer).
  List<OrderListItem> get _rotaKumesi => [
        for (final e in _sonListe)
          if (e.order.status == 'open') e,
      ];

  /// "Oto Sırala" neden kullanılamıyor? null = kullanılabilir. Üç dalın üçü de DOĞRU cümledir;
  /// amaç "sipariş yok" gibi kullanıcının gördüğüyle çelişen bir şey söylememek — açık siparişi
  /// VAR, bu ekranın süzgeci onları elemiştir ve nerede olduklarını söylemek bizim işimiz.
  String? get _otoKumeNedeni {
    if (_rotaKumesi.length >= 2) return null;
    if (_kuryeId != null) {
      return '${_kuryeAdi ?? 'Seçili kurye'} için en az iki açık sipariş yok — süzgeci kaldırın.';
    }
    if (_filtre != OrderFilter.acik) {
      return 'Rota yalnız açık siparişleri sıralar — "Açık" sekmesine geçin.';
    }
    return 'Rota için en az iki açık sipariş gerekir.';
  }

  StreamSubscription<SyncMetaData>? _metaAbone;

  @override
  void initState() {
    super.initState();
    // AKIŞA abone olunur, tek atış okunmaz: kontör sunucu sahiplidir ve GİRİŞ YANITINDA
    // GELMEZ — ilk senkron yazar. Tek atış okuma girişten hemen sonra 0 görür ve ekran
    // sonsuza dek "0 hak" gösterir (cihazda bu hâliyle yakalandı).
    _metaAbone = widget.db.watchSyncState().listen((meta) {
      // Oturum yoksa (token null) çevrimiçi eylem hiç sunulmaz.
      final yeni = meta.authToken == null ? null : meta.routeCredits;
      // Rol de AKIŞTAN okunur (aynı gerekçe): giriş yanıtı ile senkron arasında değişebilir ve
      // tek atış okuma "rol yok" görüp süzgeci sonsuza dek gizlerdi.
      final rol = meta.userRole;
      if (!mounted || (yeni == _otoHak && rol == _rol)) return;
      setState(() {
        _otoHak = yeni;
        _rol = rol;
      });
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
  late final Stream<int> _acikSayisi = watchAcikSiparisSayisi(widget.db);

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
                alt: 'Bugün ${snap.data ?? 0} açık'
                    '${_kuryeId == null ? '' : ' · ${_kuryeAdi ?? 'Kurye'}'}',
                onMenu: widget.onMenu,
                sag: [
                  // HARİTA — her zaman görünür. Bu ekran zaten yalnız açık siparişleri
                  // gösteriyor; haritanın da göstereceği tam olarak o küme. Düğmeyi duruma
                  // göre gizlemek, yeteneği bulunamaz kılardı (`.sr-oto` dersinin aynısı).
                  SipIkonButon(
                    ikon: SipIcons.pin,
                    ikonBoyut: 20,
                    zemin: t.surface,
                    renk: t.ink,
                    etiket: 'Haritada göster',
                    onTap: _haritaAc,
                  ),
                  const SizedBox(width: SipSpace.md),
                  // Kurye süzgeci — yalnız patron (K2 dışı bir GÖRÜNÜM kapısı; kurye kendi
                  // işini görür, ona süzgeç gürültüdür). Elle sıralama kipinde gizlenir:
                  // sıra yazarken listenin altından küme değişmemeli.
                  if (kuryeSuzgeciGorunur(_rol) && !_elle) ...[
                    SipIkonButon(
                      ikon: SipIcons.truck,
                      ikonBoyut: 20,
                      zemin: _kuryeId == null ? t.surface : t.accentSoft,
                      renk: _kuryeId == null ? t.ink : t.accent,
                      etiket: 'Kuryeye göre süz',
                      onTap: _kuryeSuzgeciAc,
                    ),
                    const SizedBox(width: SipSpace.md),
                  ],
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
              padding: const EdgeInsets.fromLTRB(
                  SipSpace.govde, 0, SipSpace.govde, SipSpace.xl),
              child: SipSegment(
                secenekler: [for (final f in sekmeler) _sekmeEtiketi(f)],
                secili: sekmeler.indexOf(_filtre).clamp(0, sekmeler.length - 1),
                onSec: (i) => setState(() => _filtre = sekmeler[i]),
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
                // "Oto Sırala"nın kaynağı: kullanıcının GÖRDÜĞÜ küme. build sırasında setState
                // ÇAĞRILMAZ — bu yalnız bir alan ataması, çizimi etkilemez. Hata/yükleniyor/boş
                // dallarında küme BİLİNMİYOR demektir; bayat listeyi taşımak yerine boşaltılır.
                if (snap.hasError) {
                  _sonListe = const [];
                  // "Tekrar dene" akışı YENİDEN KURMALI: artık akış önbellekli olduğu için
                  // boş bir setState aynı ölü akışa geri abone olurdu (düğme hiçbir şey yapmaz).
                  return SipHataEkran(onTekrar: () => setState(() => _siparisAkisi = null));
                }
                final ham = snap.data;
                if (ham == null) {
                  _sonListe = const [];
                  return const SipIskelet(adet: 4);
                }
                if (ham.isEmpty) {
                  _sonListe = const [];
                  return _bos();
                }

                final liste = siparisleriSirala(ham, _sirala, elleSira: _elleSira);
                _sonListe = liste;
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

  /// Harita ekranı — açık siparişlerin durakları, rota sırasında numaralı.
  Future<void> _haritaAc() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SiparisHaritaEkrani(
          db: widget.db,
          writable: widget.writable,
          canAssign: widget.canAssign,
        ),
      ));

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
      secenekler: [
        for (final s in OrderSort.values)
          if (widget.writable || s != OrderSort.elle) s,
      ],
      // Oto sıralama da sıra YAZAR. Düğme tasarımdaki gibi hep çizilir; salt-okunur kipte ve
      // hak bilinmiyorken PASİF olur (sheet nedeni yazar) — kapı korunur, yetenek gizlenmez.
      otoHak: _otoHak,
      yazilabilir: widget.writable,
      // Küme yetersizse düğme DOKUNULMADAN ÖNCE pasifleşir ve nedenini yazar.
      otoKumeNedeni: _otoKumeNedeni,
      onOtoSirala: _otoSirala,
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

  void _elleBitir() => setState(() {
        _sirala = OrderSort.saat;
        _elleSira = const [];
      });

  /// Sunucunun bildirdiği güncel kontörü ÖNBELLEĞE yazar. Tek doğru kaynak sunucudur; burada
  /// yalnız onun söylediği sayı saklanır (istemci kendi kendine düşürmez). Akış aboneliği
  /// ekranı, `home_shell` de çekmeceyi aynı satırdan tazeler.
  Future<void> _hakkiYaz(int kalan) => (widget.db.update(widget.db.syncMeta)
        ..where((t) => t.id.equals(1)))
      .write(SyncMetaCompanion(routeCredits: Value(kalan)));

  /// "Oto Sırala (rota)" — tasarım `.sr-oto`. Sunucudan SIRA ÖNERİSİ ister, kontörü sunucu
  /// düşer; dönen sırayı normal yazma yolundan (`sort_set` olayı) kalıcılar ve ekranı rota
  /// kipine alır — böylece kullanıcı sonucu görür ve isterse sürükleyip düzeltir.
  ///
  /// Bu, uygulamanın TEK çevrimİÇİ zorunlu eylemidir. Başarısızlıkta mevcut sıra AYNEN kalır;
  /// yarım uygulanmış bir rota bırakmaz.
  Future<void> _otoSirala() async {
    // Kapalılar rotaya HİÇ gönderilmez (`_rotaKumesi`) ama görünen kümeden kaç tanesinin
    // düştüğü toast'ta SÖYLENİR: "sıraladım" deyip listenin bir kısmını sessizce sona atmak
    // yasak (inceleme bulgusu 2026-07-29).
    final liste = _rotaKumesi;
    final kapali = _sonListe.length - liste.length;
    // EMNİYET AĞI: düğme küme yetersizken zaten pasif çizilir (`_otoKumeNedeni`), ama sheet
    // açıkken senkron listeyi değiştirmiş olabilir. Mesaj düğmenin altındakiyle AYNI cümledir —
    // kullanıcı iki farklı gerekçe duymaz.
    final nedeni = _otoKumeNedeni;
    if (nedeni != null) {
      SipToast.goster(context, nedeni);
      return;
    }

    final meta = await widget.db.syncState();
    final token = meta.authToken;
    if (!mounted) return;
    if (token == null) {
      SipToast.goster(context, 'Oto sıralama için oturum gerekir');
      return;
    }

    // ROTA NEREDEN BAŞLAR: kuryenin BULUNDUĞU nokta. Konum alınamazsa (izin yok, GPS kapalı,
    // kapalı alan) ya da ölçüm güvenilmezse (`guvenilir` kuralı — ±100 m üstü bir başlangıç
    // noktası rotayı yanlış şehir köşesinden kurabilir) `start` HİÇ gönderilmez; sunucu eski
    // davranışıyla ilk duraktan sıralar. Fark kullanıcıya SÖYLENİR (aşağıdaki toast eki):
    // sessizce başka bir kipte sıralamak, kuryeye yanlış bir rotaya güvenmesini söylemek olurdu.
    ({double lat, double lng})? baslangic;
    try {
      final konum = await cihazKonumuOku();
      if (konum.guvenilir) baslangic = (lat: konum.lat, lng: konum.lng);
    } on Object {
      // Konum bir KOLAYLIKTIR, ön koşul değil: okunamadıysa sıralama yine yapılır.
    }
    if (!mounted) return;

    final api = rotaApiUret(Session.baseUrlOf(meta), token);
    final AutoRouteResult sonuc;
    try {
      sonuc = await api.autoRoute(
        [for (final e in liste) e.order.id],
        baslangic: baslangic,
      );
    } on RouteException catch (e) {
      // Sunucu güncel hakkı bildirdiyse ÖNBELLEĞİ düzelt: "34 hak" yazan düğmeye basıp
      // "hakkınız kalmadı" duymak, sonra hâlâ 34 görmek kullanıcıyı ikinci kez yanıltırdı.
      // Yerel alana değil sync_meta'ya yazılır — çekmecedeki kart da aynı kaynağı okur.
      if (e.kalanHak != null) await _hakkiYaz(e.kalanHak!);
      if (!mounted) return;
      SipToast.goster(context, e.message);
      return;
    }

    // Dönen sırayı ekrandaki öğelere eşle; sunucunun tanımadığı kimlik varsa (silinmiş/kapanmış)
    // sessizce düşer, kalanlar sırayı korur.
    final indeks = {for (final e in liste) e.order.id: e};
    final yeniSira = [
      for (final id in sonuc.sira)
        if (indeks[id] != null) indeks[id]!,
    ];

    final repo = OrderRepository(widget.db);
    for (final girdi in elleSiraYazimi(yeniSira).entries) {
      await repo.setSortIndex(girdi.key, girdi.value);
    }
    if (!mounted) return;

    await _hakkiYaz(sonuc.kalanHak);
    if (!mounted) return;

    setState(() {
      _sirala = OrderSort.elle;
      _elleSira = [for (final e in yeniSira) e.order.id];
    });

    // Koordinatsız duraklar sona atıldı — bunu SÖYLEMEK zorundayız, yoksa "sıraladım" demek
    // yanıltıcı olur (kullanıcı o siparişlerin neden sonda olduğunu anlamaz).
    final ek = sonuc.konumsuz > 0 ? ' · ${sonuc.konumsuz} sipariş konumsuz, sona alındı' : '';
    // Hangi KİPTE sıralandığı da söylenir: kurye "benim konumumdan başladı" sanıp ilk durağa
    // gitmemeyi seçebilir. Sessiz bozulma yasak — konum alınamadıysa cümlenin sonunda yazar.
    final kip = baslangic == null ? ' · konum alınamadı, ilk duraktan' : '';
    // Görünen sekmedeki kapalı siparişler rotaya GİRMEDİ — bunu da söyleriz; onlar elle
    // sıranın dışında kaldıkları için listenin sonuna iner ve kullanıcı sebebini bilmeli.
    final disarida = kapali > 0 ? ' · $kapali kapalı sipariş rotaya girmedi' : '';
    SipToast.goster(context,
        'Rota otomatik sıralandı · ${sonuc.kalanHak} hak kaldı$ek$kip$disarida');
  }

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

