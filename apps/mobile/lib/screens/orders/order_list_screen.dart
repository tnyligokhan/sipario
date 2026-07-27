// Siparişler ekranı — CSS `.segtab`, `.sliste`, `.srow*`, `.elle-bant`, `.ust-sirala`.
// Kaynak: s-siparisler.jsx `SiparislerEkran`.
//
// Üst: başlık + "Bugün N açık" + Sırala düğmesi (elle kipinde "Bitti").
// Altında segment sekmeleri (Açık · Teslim · Borçlu · Tümü — tasarımın dördü),
// sonra sipariş satırları. Elle sıralama kipinde satırlar sürüklenebilir hale gelir, adres/not/
// eylem şeritleri gizlenir ve sıra `orders.sort_index` olarak KALICI yazılır.
//
// Satırın kendisi order_row.dart'ta, sorgular order_queries.dart'ta, seçim sheet'leri
// order_sheets.dart'ta. Bu dosya yalnız DURUM ve akış birleştirmesi yapar.

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../auth/session.dart';
import '../../repo/order_repository.dart';
import '../../sync/route_api.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'order_detail_screen.dart';
import 'order_queries.dart';
import 'order_row.dart';
import 'order_sheets.dart';

// Sorgu/biçim yardımcıları bu ekranın YÜZEYİNDEN de erişilebilir olmalı: mevcut testler ve
// başka ekranlar `order_list_screen.dart` üzerinden çağırıyor (sözleşme — imzalar değişmez).
export 'order_queries.dart'
    show
        AdresBilgi,
        OrderFilter,
        OrderListItem,
        OrderSort,
        elleSiraYazimi,
        musteriKod,
        odemeTipiEtiketi,
        saatBicimi,
        satirOzeti,
        serbestMi,
        siparisleriSirala,
        siralamaEtiketi,
        watchOrderItemsSummary,
        watchOrders;

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

  /// Oturumdaki kullanıcı — kuryeye atanmış siparişleri süzen sorgunun hedefi.
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

  /// Sürükleme sırasındaki İYİMSER sıra (sipariş id'leri). Boşken kalıcı `sort_index` geçerlidir.
  List<String> _elleSira = const [];

  /// Kalan oto-sıralama hakkı (sunucu sahipli, senkronla iner). null = HENÜZ BİLİNMİYOR →
  /// `.sr-oto` düğmesi kontör YAZMADAN, PASİF çizilir. Uydurma bir sayı göstermek yasak:
  /// kullanıcı "34 hakkım var" deyip tıkladığında sunucu 409 dönerse güven kaybolur.
  int? _otoHak;

  /// Ekranda o an gösterilen liste — "Oto Sırala" hangi siparişleri sıralayacağını buradan
  /// okur (kurye filtresi ve seçili sekme dahil, kullanıcının GÖRDÜĞÜ küme).
  List<OrderListItem> _sonListe = const [];

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
      if (mounted && yeni != _otoHak) setState(() => _otoHak = yeni);
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
                alt: 'Bugün ${snap.data ?? 0} açık',
                onMenu: widget.onMenu,
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
              Container(
                margin: const EdgeInsets.fromLTRB(
                    SipSpace.govde, 0, SipSpace.govde, SipSpace.lg),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration:
                    BoxDecoration(color: t.accentSoft, borderRadius: SipRadius.brHap),
                child: Row(
                  children: [
                    SipIcon(SipIcons.info, boyut: 14, kalinlik: 2, renk: t.accent),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Tutamaçtan sürükleyip bırak, bitince “Bitti”ye bas.',
                        style: SipText.metin(12, w: 600).copyWith(color: t.accent),
                      ),
                    ),
                  ],
                ),
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
        builder: (context, satirSnap) => StreamBuilder<Map<String, AdresBilgi>>(
          stream: _adresler,
          initialData: const {},
          builder: (context, adresSnap) => StreamBuilder<Map<String, String>>(
            stream: _telefonlar,
            initialData: const {},
            builder: (context, telSnap) => StreamBuilder<List<OrderListItem>>(
              stream: watchOrders(widget.db, _filtre, assignedTo: widget.userId),
              builder: (context, snap) {
                if (snap.hasError) return SipHataEkran(onTekrar: () => setState(() {}));
                final ham = snap.data;
                if (ham == null) return const SipIskelet(adet: 4);
                if (ham.isEmpty) return _bos();

                final liste = siparisleriSirala(ham, _sirala, elleSira: _elleSira);
                // "Oto Sırala"nın kaynağı: kullanıcının GÖRDÜĞÜ küme. build sırasında
                // setState ÇAĞRILMAZ — bu yalnız bir alan ataması, çizimi etkilemez.
                _sonListe = liste;
                return _Liste(
                  liste: liste,
                  satirlar: satirSnap.data ?? const {},
                  adresler: adresSnap.data ?? const {},
                  telefonlar: telSnap.data ?? const {},
                  ekip: ekipSnap.data ?? const [],
                  elle: _elle,
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
    );
  }

  /// Boş durum — tasarımda İKİ metin var (s-siparisler.jsx:116): "Açık" sekmesi kullanıcıya ne
  /// yapacağını söyler, kalan sekmeler tek nötr cümleyi paylaşır.
  Widget _bos() => SipBosDurum(
        ikon: SipIcons.list,
        baslik: 'Sipariş yok',
        aciklama: _filtre == OrderFilter.acik
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
    final liste = _sonListe;
    if (liste.length < 2) {
      SipToast.goster(context, 'Sıralanacak en az iki sipariş gerekir');
      return;
    }

    final meta = await widget.db.syncState();
    final token = meta.authToken;
    if (!mounted) return;
    if (token == null) {
      SipToast.goster(context, 'Oto sıralama için oturum gerekir');
      return;
    }

    final api = RouteApi(baseUrl: Session.baseUrlOf(meta), token: token);
    final AutoRouteResult sonuc;
    try {
      sonuc = await api.autoRoute([for (final e in liste) e.order.id]);
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
    SipToast.goster(
        context, 'Rota otomatik sıralandı · ${sonuc.kalanHak} hak kaldı$ek');
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

/// CSS `.sliste` — elle kipinde sürüklenebilir, normalde düz liste. İki kip AYNI satır
/// bileşenini çizer (görsel ayrışmasın); fark yalnız tutamaç ve sürükleme tanıyıcısıdır.
class _Liste extends StatelessWidget {
  const _Liste({
    required this.liste,
    required this.satirlar,
    required this.adresler,
    required this.telefonlar,
    required this.ekip,
    required this.elle,
    required this.onAc,
    required this.onKuryeAc,
    required this.onBildir,
    required this.onSirala,
  });

  final List<OrderListItem> liste;
  final Map<String, List<OrderLine>> satirlar;
  final Map<String, AdresBilgi> adresler;
  final Map<String, String> telefonlar;
  final List<User> ekip;
  final bool elle;
  final ValueChanged<OrderListItem> onAc;
  final ValueChanged<OrderListItem>? onKuryeAc;
  final ValueChanged<String> onBildir;
  final ValueChanged<List<OrderListItem>> onSirala;

  static const _dolgu = EdgeInsets.fromLTRB(SipSpace.govde, 0, SipSpace.govde, 96);

  Widget _satir(BuildContext context, int i, {Key? key}) {
    final item = liste[i];
    final musteriId = item.order.customerId;
    return Padding(
      key: key,
      padding: EdgeInsets.only(top: i == 0 ? 0 : SipSpace.md),
      child: SiparisSatiri(
        item: item,
        satirlar: satirlar[item.order.id] ?? const [],
        kuryeAdi: kullaniciAdi(ekip, item.order.assignedUserId),
        adres: musteriId == null ? null : adresler[musteriId],
        telefon: musteriId == null ? null : telefonlar[musteriId],
        elle: elle,
        tutamac: elle
            ? (child) => ReorderableDragStartListener(index: i, child: child)
            : null,
        onAc: () => onAc(item),
        onKuryeAc: onKuryeAc == null ? null : () => onKuryeAc!(item),
        onBildir: onBildir,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!elle) {
      return ListView.builder(
        padding: _dolgu,
        itemCount: liste.length,
        itemBuilder: (context, i) => _satir(context, i),
      );
    }
    return ReorderableListView.builder(
      padding: _dolgu,
      buildDefaultDragHandles: false, // tutamaç tasarımda `.srow-grip`, satırın tamamı değil
      itemCount: liste.length,
      itemBuilder: (context, i) =>
          _satir(context, i, key: ValueKey(liste[i].order.id)),
      onReorder: (eski, yeni) {
        final kopya = [...liste];
        final tasinan = kopya.removeAt(eski);
        kopya.insert(yeni > eski ? yeni - 1 : yeni, tasinan);
        onSirala(kopya);
      },
    );
  }
}
