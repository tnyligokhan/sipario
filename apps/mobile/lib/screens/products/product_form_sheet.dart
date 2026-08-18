// Ürün ekle / düzenle formu — tasarım s-urunler.jsx (`Sheet` içindeki `.sb-form`).
// Alanlar: görsel (.uf-gorsel*) · ad · birim fiyat + birim · barkod (.sdx-sb + .pos-barkod) ·
// aktiflik anahtarı (.aktif-toggle) · silme notu (.silme-notu).
//
// Ürün SİLİNMEZ (geçmiş sipariş satırları ad/fiyatı kendi içinde taşır); kullanılmayan PASİF yapılır.

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/urun_secenekleri.dart';
import '../../repo/product_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../isletme/isletme_atomlari.dart';
import '../barkod/barkod_kamera.dart';
import 'birimler.dart';
import 'urun_secenek_alani.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Barkod / görsel
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Ürünün barkodu. Kayıt YALNIZ RAKAM tutar — `ProductRepository.findByBarcode` de aramadan
/// önce rakama indirger; ikisi aynı anahtarda buluşsun diye biçimlendirme saklanmaz.
String? urunBarkodu(Product p) => p.barcode;

/// Ürün görseli: önce bu cihazda seçilen yerel dosya, yoksa sunucudan gelen işaretçi.
/// (`imageLocalPath` senkronlanmaz — cihaz-yerel; `imageUrl` sunucudan iner.)
String? urunGorseli(Product p) => p.imageLocalPath ?? p.imageUrl;

/// Cihaz galerisinden bir dosya YOLU döndüren seçici; kullanıcı vazgeçerse null.
typedef GorselSecici = Future<String?> Function();

/// Ürün görseli seçicisinin bağlantı noktası.
///
/// GERÇEK SEÇİCİ HENÜZ BAĞLI DEĞİL: galeri erişimi bir eklenti ister (`image_picker`) ve o
/// bağımlılık `pubspec.yaml`de YOK — bu vardiyada paket eklenmedi. Kanca burada duruyor ki paket
/// geldiğinde uygulama kökünde TEK satırla bağlanabilsin ve form kodu hiç değişmesin:
///
///   urunGorselSecici = () async =>
///       (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
///
/// Seçilen yol cihaz-yerel `products.imageLocalPath` kolonuna yazılır (senkronlanmaz).
GorselSecici? urunGorselSecici;

/// Formu açar; kaydedildiyse `true` döner.
Future<bool> urunFormuAc(
  BuildContext context, {
  required AppDatabase db,
  Product? urun,
}) async {
  final sonuc = await sipSheet<bool>(
    context,
    baslik: urun == null ? 'Yeni Ürün' : 'Ürünü Düzenle',
    govde: (ctx) => _UrunFormu(db: db, urun: urun),
  );
  return sonuc ?? false;
}

class _UrunFormu extends StatefulWidget {
  const _UrunFormu({required this.db, required this.urun});

  final AppDatabase db;
  final Product? urun;

  @override
  State<_UrunFormu> createState() => _UrunFormuState();
}

class _UrunFormuState extends State<_UrunFormu> {
  late final TextEditingController _ad =
      TextEditingController(text: widget.urun?.name ?? '');
  late final TextEditingController _fiyat = TextEditingController(
    text: widget.urun == null ? '' : _fiyatMetni(widget.urun!.unitPriceKurus),
  );
  /// KAYITTAKİ birim metni. Menü bunu DEĞİŞTİRMEZ, yalnız gösterir: sahadaki serbest değer
  /// ("damacana") kullanıcı başka bir şey seçmedikçe olduğu gibi geri yazılır.
  late String _birim = widget.urun?.unit ?? kVarsayilanBirim;

  /// "Diğer…" seçildi — alan menü yerine serbest metin girişi çizer.
  bool _birimSerbest = false;
  late final TextEditingController _birimMetni = TextEditingController(text: _birim);

  /// Ürünün malzeme listesi (2026-08-18). Kaynak doğruluk BURASI — alt bileşen durum tutmaz.
  late List<UrunSecenegi> _secenekler = secenekleriCoz(widget.urun?.optionsJson);

  late final TextEditingController _barkod =
      TextEditingController(text: widget.urun == null ? '' : (urunBarkodu(widget.urun!) ?? ''));

  late bool _aktif = widget.urun?.isActive ?? true;
  late String? _gorsel = widget.urun == null ? null : urunGorseli(widget.urun!);

  /// Alan adı → hata metni (tasarımdaki `hata` sözlüğü).
  Map<String, String> _hata = const {};

  bool _kaydediyor = false;

  /// Kuruşu forma yazarken: tam liraysa "45", değilse "45,50" — kullanıcı kuruş girebilsin diye
  /// tasarımın yalnız-tamsayı alanından ayrıldık (para kırmızı çizgisi: sessiz yuvarlama YOK).
  static String _fiyatMetni(int kurus) {
    if (kurus % 100 == 0) return (kurus ~/ 100).toString();
    return '${kurus ~/ 100},${(kurus % 100).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ad.dispose();
    _fiyat.dispose();
    _birimMetni.dispose();
    _barkod.dispose();
    super.dispose();
  }

  void _temizle() {
    if (_hata.isNotEmpty) setState(() => _hata = const {});
  }

  Future<void> _kaydet() async {
    if (_kaydediyor) return;
    final hatalar = <String, String>{};

    final ad = _ad.text.trim();
    final barkod = _barkod.text.trim();
    final kurus = _fiyatiCoz(_fiyat.text);

    if (ad.length < 2) {
      hatalar['ad'] = 'Ürün adı girin (en az 2 karakter)';
    }
    if (kurus == null || kurus <= 0) {
      hatalar['fiyat'] = 'Fiyat 0’dan büyük olmalı';
    }
    if (barkod.isNotEmpty && barkod.length < 8) {
      hatalar['barkod'] = 'Barkod en az 8 hane olmalı';
    }

    if (hatalar.isEmpty && ad.isNotEmpty) {
      final digerleri = await _digerUrunler();
      final ayniAd = digerleri.any((u) => u.name.toLowerCase() == ad.toLowerCase());
      if (ayniAd) hatalar['ad'] = 'Bu adla kayıtlı ürün zaten var';
      if (barkod.isNotEmpty &&
          digerleri.any((u) => urunBarkodu(u) == barkod)) {
        hatalar['barkod'] = 'Bu barkod başka üründe kayıtlı';
      }
    }

    if (hatalar.isNotEmpty) {
      if (mounted) setState(() => _hata = hatalar);
      return;
    }

    setState(() => _kaydediyor = true);
    final repo = ProductRepository(widget.db);
    // Boş birim (serbest metin silinip kaydedildi) bugünkü davranışın aynısıyla varsayılana
    // düşer; DOLU olan hiçbir değer dönüştürülmez.
    final birim = _birim.trim().isEmpty ? kVarsayilanBirim : _birim.trim();
    if (widget.urun == null) {
      await repo.create(
        name: ad,
        unitPriceKurus: kurus!,
        unit: birim,
        barcode: barkod.isEmpty ? null : barkod,
        imageLocalPath: _gorsel,
        secenekler: _secenekler,
      );
    } else {
      // `update` TÜM alanları yazar (verilmeyen null olur): sunucudan inen `imageUrl`
      // düzenleme sırasında silinmesin diye mevcut değeri geri veriyoruz.
      await repo.update(
        widget.urun!.id,
        name: ad,
        unitPriceKurus: kurus!,
        unit: birim,
        isActive: _aktif,
        barcode: barkod.isEmpty ? null : barkod,
        imageUrl: widget.urun!.imageUrl,
        imageLocalPath: _gorsel,
        secenekler: _secenekler,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// Aynı adı/barkodu taşıyan BAŞKA ürün var mı? (düzenlenen ürün hariç, silinmişler hariç)
  Future<List<Product>> _digerUrunler() async {
    final hepsi = await (widget.db.select(widget.db.products)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return hepsi.where((u) => u.id != widget.urun?.id).toList();
  }

  /// "45" → 4500 · "45,5" → 4550. Geçersizse null (para: sessiz kabul YOK).
  static int? _fiyatiCoz(String metin) {
    final s = metin.trim().replaceAll('.', '');
    if (s.isEmpty) return null;
    final parcalar = s.split(',');
    if (parcalar.length > 2) return null;
    final lira = int.tryParse(parcalar[0].isEmpty ? '0' : parcalar[0]);
    if (lira == null) return null;
    if (parcalar.length == 1) return lira * 100;
    final kurusMetni = parcalar[1];
    if (kurusMetni.isEmpty) return lira * 100;
    if (kurusMetni.length > 2) return null;
    final kr = int.tryParse(kurusMetni);
    if (kr == null) return null;
    return lira * 100 + int.parse(kurusMetni.padRight(2, '0'));
  }

  Future<void> _gorselSec() async {
    final secici = urunGorselSecici;
    if (secici == null) {
      SipToast.goster(context, 'Görsel seçimi cihaz galerisi eklentisiyle gelecek.');
      return;
    }
    final yol = await secici();
    if (yol == null || yol.isEmpty || !mounted) return;
    setState(() => _gorsel = yol);
  }

  /// Barkod ikonu → KAMERA. Okunan kod doğrudan barkod alanına yazılır; arada elle
  /// doldurulacak ikinci bir alan yoktur (kullanıcı kararı, 2026-07-26).
  Future<void> _barkodOkut() async {
    final kod = await barkodKameraAc(context);
    if (kod == null || !mounted) return;
    setState(() {
      _barkod.text = kod;
      _hata = const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Etiketler ZATEN büyük harfle yazılır: Dart'ın `toUpperCase()`i yerelden bağımsızdır
        // ve 'i' → 'I' üretir ("BIRIM"). Doğru Türkçe için büyük hâli burada verilir.
        const SipFormEtiket('ÜRÜN GÖRSELİ', ustBosluk: 4),
        _GorselAlani(
          gorsel: _gorsel,
          basHarf: _ad.text.trim().isEmpty ? '+' : trBuyuk(_ad.text.trim()[0]),
          onSec: _gorselSec,
          onKaldir: () => setState(() => _gorsel = null),
        ),

        const SipFormEtiket('ÜRÜN ADI'),
        SipInput(
          controller: _ad,
          ipucu: 'Ör. Damacana 19 L',
          hata: _hata.containsKey('ad'),
          otomatikOdak: widget.urun == null,
          onChanged: (_) => setState(() => _hata = const {}),
        ),
        if (_hata['ad'] != null) AlanNotu(_hata['ad']!),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SipFormEtiket('BİRİM FİYAT (₺)'),
                  SipInput(
                    controller: _fiyat,
                    ipucu: '0',
                    klavye: const TextInputType.numberWithOptions(decimal: true),
                    girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                    stil: SipText.tutar(15),
                    hata: _hata.containsKey('fiyat'),
                    onChanged: (_) => _temizle(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SipSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SipFormEtiket('BİRİM'),
                  if (_birimSerbest)
                    SipInput(
                      controller: _birimMetni,
                      ipucu: 'Birimi yazın',
                      otomatikOdak: true,
                      onChanged: (v) => _birim = v,
                    )
                  else
                    BirimAlani(
                      deger: _birim,
                      onSec: (v) => setState(() => _birim = v),
                      onDiger: () => setState(() {
                        _birimSerbest = true;
                        // Mevcut değerle DOLU açılır: "Diğer…"e basan bayi çoğu zaman var olanı
                        // düzeltmek ister, sıfırdan yazmak değil.
                        _birimMetni.text = _birim;
                      }),
                    ),
                  if (_birimSerbest)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SipMetinButon(
                        etiket: 'Listeden seç',
                        onTap: () => setState(() {
                          _birimSerbest = false;
                          _birim = _birimMetni.text;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_hata['fiyat'] != null) AlanNotu(_hata['fiyat']!),

        const SipFormEtiket('BARKOD · OPSİYONEL'),
        Row(
          children: [
            Expanded(
              child: SipInput(
                controller: _barkod,
                ipucu: 'Barkodu yazın ya da okutun',
                klavye: TextInputType.number,
                girdiFiltreleri: [FilteringTextInputFormatter.digitsOnly],
                stil: SipText.tutar(15, w: 500),
                hata: _hata.containsKey('barkod'),
                onChanged: (_) => _temizle(),
              ),
            ),
            const SizedBox(width: SipSpace.md),
            // CSS `.pos-barkod` — 44×44, accent-soft, köşe 13.
            SipDokun(
              onTap: _barkodOkut,
              zemin: t.accentSoft,
              basiliZemin: t.accentSoft,
              radius: const BorderRadius.all(Radius.circular(13)),
              olcekle: true,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: SipIcon(SipIcons.barkod, boyut: 20, kalinlik: 2, renk: t.accent),
                ),
              ),
            ),
          ],
        ),
        if (_hata['barkod'] != null) AlanNotu(_hata['barkod']!),
        const _SilmeNotu(
          'Barkodsuz ürünler katalogda aramayla seçilir; barkodlular POS’ta okutarak eklenir.',
          hizala: TextAlign.start,
        ),

        // İÇİNDEKİLER — kapısı bileşenin İÇİNDE (kullanıcı eleştirisi 2026-08-18: "su bayisinde
        // içindekiler göstermek çok mantıklı değil"). Bölüm iki katmanlıdır: işletmenin
        // "hazırlanan ürün" yeteneği + ürünün kendi malzeme listesi.
        //
        // ⚠️ YETENEK KAPALIYKEN DE MEVCUT LİSTE KORUNUR: `_secenekler` kayıttan okundu ve
        // `_kaydet` onu aynen geri yazıyor. Kapı yalnız DÜZENLEYİCİYİ gizler — aksi hâlde
        // yeteneği geçici kapatan bir dönerci, bir ürünü açıp kaydettiği anda o ürünün bütün
        // malzemelerini sessizce kaybederdi.
        UrunSecenekBolumu(
          db: widget.db,
          secenekler: _secenekler,
          onDegis: (l) => setState(() => _secenekler = l),
        ),

        AktifToggle(
          acik: _aktif,
          etiket: _aktif ? 'Aktif — siparişte görünür' : 'Pasif — siparişte gizli',
          onDegis: (v) => setState(() => _aktif = v),
        ),

        const SizedBox(height: SipSpace.x3),
        SipButon(etiket: 'Kaydet', onTap: _kaydet, yukleniyor: _kaydediyor),
        if (widget.urun != null)
          const _SilmeNotu('Ürünler silinmez; kullanılmayanı Pasif yap.'),
      ],
    );
  }
}

/// CSS `.uf-gorsel` — 58×58 önizleme + açıklama + "Görsel Ekle / Değiştir / Kaldır".
class _GorselAlani extends StatelessWidget {
  const _GorselAlani({
    required this.gorsel,
    required this.basHarf,
    required this.onSec,
    required this.onKaldir,
  });

  final String? gorsel;
  final String basHarf;
  final VoidCallback onSec;
  final VoidCallback onKaldir;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    // CSS `.uf-gorsel-img.ph` — görsel yoksa baş harf yer tutucusu.
    final harf = Text(
      basHarf,
      style: SipText.tutar(20, w: 800).copyWith(color: t.accent),
    );
    // Yerel dosya silinmiş/erişilemez olabilir (galeri temizliği, izin kaybı) → baş harfe dönülür.
    // Sunucudan inen `imageUrl` burada ÇİZİLMEZ: offline-first kurulumda form açılışında ağ
    // isteği yapılmaz; o durumda da yer tutucu kalır.
    final yerel = gorsel != null && !gorsel!.startsWith('http');
    return Container(
      padding: const EdgeInsets.all(SipSpace.lg),
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: t.accentSoft,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: yerel
                ? Image.file(
                    File(gorsel!),
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(child: harf),
                  )
                : harf,
          ),
          const SizedBox(width: SipSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gorsel == null
                      ? 'POS katalogda karo üzerinde görünür'
                      : 'Görsel yüklendi',
                  style: SipText.yardimci.copyWith(color: t.muted),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    SipMetinButon(
                      etiket: gorsel == null ? 'Görsel Ekle' : 'Değiştir',
                      onTap: onSec,
                    ),
                    if (gorsel != null) ...[
                      const SizedBox(width: SipSpace.sm),
                      SipMetinButon(etiket: 'Kaldır', renk: t.danger, onTap: onKaldir),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.silme-notu` — küçük, sönük, ortalanmış açıklama.
class _SilmeNotu extends StatelessWidget {
  const _SilmeNotu(this.metin, {this.hizala = TextAlign.center});

  final String metin;
  final TextAlign hizala;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.xl),
      child: Text(
        metin,
        textAlign: hizala,
        style: SipText.yardimci.copyWith(color: context.sip.muted),
      ),
    );
  }
}

