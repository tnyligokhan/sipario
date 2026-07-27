// Yeni Sipariş — CSS `.ys-*` / `.pos-*`. Kaynak: s-siparisler.jsx `YeniSiparis`.
// ÜÇ ADIM: müşteri seç → kalemler → özet. Ödeme tipi BURADA sorulmaz; teslim kapatılırken
// sorulur (BRIEF: mal gidince para konuşulur) — sipariş girişi telefonda birkaç dokunuşta biter.

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
import 'order_parts.dart';
import 'order_queries.dart';
import 'pos_catalog.dart';

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
  }

  Future<void> _musteriYukle(String id) async {
    final c = await (widget.db.select(widget.db.customers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (mounted && c != null) setState(() => _musteri = c);
  }

  @override
  void dispose() {
    _arama.dispose();
    _not.dispose();
    super.dispose();
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

  void _musteriSec(Customer c) {
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
      await OrderRepository(widget.db).create(
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
                ))
            .toList(),
      );
      if (!mounted) return;
      SipToast.goster(context, 'Sipariş oluşturuldu');
      Navigator.of(context).maybePop(true);
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
            AdimGostergesi(adimlar: _adimlar, adim: _adim),
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
                buton: SipButon(
                  etiket: 'Devam',
                  ikon: SipIcons.right,
                  genisle: false,
                  yatayPadding: 24,
                  onTap: _devam,
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
  Widget _adim1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(SipSpace.govde, SipSpace.md, SipSpace.govde, SipSpace.xl),
          child: SipArama(
            controller: _arama,
            ipucu: 'İsim ya da telefon ara…',
            onChanged: (v) => setState(() => _sorgu = v),
            onTemizle: () => setState(() {
              _arama.clear();
              _sorgu = '';
            }),
          ),
        ),
        Expanded(
          // Satırda telefon ve adres var (CSS `.mrow-tel`/`.mrow-adres`) — iki yardımcı akış
          // TEK sorgudur, satır sayısıyla çoğalmaz.
          child: StreamBuilder<Map<String, String>>(
            stream: _telefonlar,
            initialData: const {},
            builder: (context, telSnap) => StreamBuilder<Map<String, AdresBilgi>>(
              stream: _adresler,
              initialData: const {},
              builder: (context, adresSnap) => StreamBuilder<List<Customer>>(
                stream: watchMusteriArama(widget.db, _sorgu),
                builder: (context, snap) {
                  final liste = snap.data;
                  final telefonlar = telSnap.data ?? const <String, String>{};
                  final adresler = adresSnap.data ?? const <String, AdresBilgi>{};
                  return SipGovde(
                    altBosluk: SipSpace.x4,
                    children: [
                      // Tasarım `.ys-ekle` + `YeniMusteri` (s-siparisler.jsx:311). Buradaki
                      // "müşterisiz devam et (tezgâh satışı)" kapısı 2026-07-26'da kaldırıldı;
                      // müşterisiz siparişin GÖRÜNTÜLENMESİ duruyor (senkronla gelebilir),
                      // yalnız oluşturma yolu gitti.
                      YsEkleDugmesi(
                        etiket: 'Yeni müşteri ekle',
                        ikon: SipIcons.userPlus,
                        onTap: widget.writable ? _yeniMusteri : null,
                      ),
                      const SizedBox(height: SipSpace.xl),
                      if (liste == null)
                        const SipIskelet(adet: 4)
                      else if (liste.isEmpty)
                        YsBosDurum(
                          ikon: SipIcons.users,
                          metin: _sorgu.trim().isEmpty
                              ? 'Henüz müşteri yok — yukarıdan ekleyin'
                              : '"$_sorgu" için müşteri yok',
                        )
                      else
                        for (final c in liste)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: MusteriSecimSatiri(
                              musteri: c,
                              telefon: telefonlar[c.id],
                              adres: _mrowAdres(adresler[c.id]),
                              onTap: () => _musteriSec(c),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  static MrowAdres? _mrowAdres(AdresBilgi? a) =>
      a == null ? null : MrowAdres(metin: a.tamMetin, konumVar: a.konumVar);

  // ── Adım 2 — kalemler ───────────────────────────────────────────────────────────────────
  Widget _adim2() {
    final t = context.sip;
    return SipGovde(
      children: [
        // .ys-secili
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
        if (_sepetBos)
          const YsBosDurum(metin: 'Sepet boş — katalogdan ürün ekleyin')
        else
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.lg),
            child: Column(
              children: [
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
                    ),
                  ),
              ],
            ),
          ),
        // .ys-serbest
        SipDokun(
          onTap: _serbestEkle,
          radius: SipRadius.br2,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          child: Text(
            '+ Serbest satır (katalogda olmayan iş)',
            textAlign: TextAlign.center,
            style: SipText.metin(12.5, w: 600).copyWith(color: t.muted),
          ),
        ),
      ],
    );
  }

  // ── Adım 3 — özet ───────────────────────────────────────────────────────────────────────
  Widget _adim3() {
    final t = context.sip;
    final musteri = _musteri;
    return SipGovde(
      children: [
        const SdxSec('Müşteri', ustBosluk: SipSpace.lg),
        // CSS `.sdx-adres` — özette müşterinin TELEFONU ve ADRESİ yazar (s-siparisler.jsx:382-383).
        // Önce burada BAKİYE gösteriliyordu; siparişi teslim edecek kişinin son kontrolü
        // "doğru numara, doğru kapı" sorusudur — para teslimde konuşulur.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
          decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SipIcon(SipIcons.user, boyut: 15, kalinlik: 2.1, renk: t.accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(musteri?.name ?? '',
                        style: SipText.metin(13, w: 600).copyWith(color: t.ink)),
                    if (musteri != null) ...[
                      const SizedBox(height: 3),
                      StreamBuilder<Map<String, String>>(
                        stream: _telefonlar,
                        initialData: const {},
                        builder: (context, snap) {
                          final tel = (snap.data ?? const {})[musteri.id];
                          return Text(
                            (tel ?? '').isEmpty ? 'Telefon yok' : sipTelefon(tel!),
                            style: SipText.metin(11.5, w: 600).copyWith(color: t.muted),
                          );
                        },
                      ),
                      StreamBuilder<Map<String, AdresBilgi>>(
                        stream: _adresler,
                        initialData: const {},
                        builder: (context, snap) {
                          final adres = (snap.data ?? const {})[musteri.id];
                          if (adres == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              adres.tamMetin,
                              style: SipText.metin(11.5, w: 600).copyWith(color: t.muted),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SdxSec(
          'Kalemler',
          sag: SdxLink(etiket: 'Düzenle', onTap: () => setState(() => _adim = 2)),
        ),
        SdKart(
          toplamKurus: _toplam,
          satirlar: [
            for (final l in _satirlar)
              SdSatiri(
                ad: l.name,
                // Tasarım `{r.adet} {r.birim} × {fmtTL(r.fiyat)}` (s-siparisler.jsx:390).
                altMetin: l.serbest
                    ? 'tek seferlik'
                    : '${l.qty} ${l.birimEtiketi} × ${sipTutar(l.unitPriceKurus)}',
                tutarKurus: l.unitPriceKurus * l.qty,
              ),
          ],
        ),
        const SdxSec('Sipariş Notu'),
        SipInput(
          controller: _not,
          ipucu: 'Kapı kodu, teslim saati, özel istek…',
          satirlar: 2,
        ),
      ],
    );
  }
}
