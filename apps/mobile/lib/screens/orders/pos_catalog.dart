// POS ürün kataloğu — CSS `.pos-*`, `.bk-*`. Kaynak: s-siparisler.jsx `PosKatalog` / `UrunGorsel`.
//
// İki sheet: (1) tam ekran katalog ızgarası + arama + barkod düğmesi, (2) "Sepete Ekle" adet
// seçimi. Barkod düğmesi KAMERAYI açar (`screens/barkod/barkod_kamera.dart`) ve okunan kodu
// arama alanına yazar; arada elle doldurulan bir ara sheet YOKTUR (kullanıcı kararı,
// 2026-07-26). Kamera modeli pakete gömülüdür — çalışma anı indirmesi yok, offline-first
// korunur; kamera yoksa/izin verilmezse okuyucu kendi içinde elle girişe düşer.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/urun_secenekleri.dart';
import '../../repo/customer_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../barkod/barkod_kamera.dart';
import 'order_queries.dart';
import 'urun_secenek_secici.dart';

// "Sepete Ekle" sheet'i (adet · malzeme seçimi · müşteri tercihi) buradan ayrıldı — 500 satır
// sınırı. AYNI KÜTÜPHANEDİR (`part`): gerekçe o dosyanın başlığında.
part 'pos_adet_sheet.dart';

// Ürün karosu ve eylem şeridi (adet · sepete ekle) buradan ayrıldı — 500 satır sınırı.
// AYNI KÜTÜPHANEDİR (`part`): gerekçe o dosyanın başlığında.
part 'pos_karosu.dart';

/// Katalogdan sepete eklenen kalem.
class KatalogSecimi {
  const KatalogSecimi(this.urun, this.adet);
  final Product urun;
  final int adet;
}

/// Tam ekran katalog sheet'i. Kullanıcı "Bitti"ye basana kadar açık kalır; her ekleme
/// [onEkle] ile anında dışarı bildirilir (tasarımdaki davranış — sepet arkada dolar).
Future<void> posKatalogAc(
  BuildContext context, {
  required AppDatabase db,
  required void Function(Product urun, int adet, SecenekSecimi secim) onEkle,
  ValueChanged<String>? onBildir,
  String? musteriId,
  String? musteriAdi,
}) =>
    sipSheet<void>(
      context,
      baslik: 'Ürün Kataloğu',
      tam: true,
      govde: (ctx) => _KatalogGovde(
        db: db,
        onEkle: onEkle,
        onBildir: onBildir,
        musteriId: musteriId,
        musteriAdi: musteriAdi,
      ),
    );

class _KatalogGovde extends StatefulWidget {
  const _KatalogGovde({
    required this.db,
    required this.onEkle,
    this.onBildir,
    this.musteriId,
    this.musteriAdi,
  });

  final AppDatabase db;
  final void Function(Product urun, int adet, SecenekSecimi secim) onEkle;
  final ValueChanged<String>? onBildir;

  /// Siparişin müşterisi (2026-08-18). Verilirse kayıtlı ürün tercihi ÖNCEDEN uygulanır ve
  /// "bu müşteri için hatırla" anahtarı çizilir. null = tezgâh satışı: hatırlanacak kimse yok.
  final String? musteriId;
  final String? musteriAdi;

  @override
  State<_KatalogGovde> createState() => _KatalogGovdeState();
}

class _KatalogGovdeState extends State<_KatalogGovde> {
  final _arama = TextEditingController();
  String _sorgu = '';

  /// KARODAN sepete gönderilen adet (ürün kimliği → adet). Sepetin kendisi DEĞİLDİR:
  /// sepet çağıranda yaşar ve katalog onu görmez.
  ///
  /// NEDEN YETERLİ: bu sayaç yalnız sheet AÇIK OLDUĞU sürece yaşar ve o süre boyunca sepete
  /// tek dokunan yüzey burasıdır. Sheet kapanınca unutulur; ikinci kez açıldığında karolar
  /// yine "Ekle" der. Gerçek sepeti buraya taşımak, kataloğun sipariş formunun iç durumunu
  /// tanıması demekti — iki yüzey birbirine bağlanır, ikisi de ayrı ayrı test edilemezdi.
  final Map<String, int> _adetler = {};

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  /// Seçeneği olan ürün — adet/malzeme sheet'i açılır (tek yol; malzeme karoya sığmaz).
  Future<void> _sec(Product u) async {
    final secenekler = secenekleriCoz(u.optionsJson);
    // MÜŞTERİ TERCİHİ SHEET AÇILMADAN ÖNCE OKUNUR (kullanıcı isteği 2026-08-18: "her seferinde
    // sormak istemeyebilir"). Ürünün BUGÜNKÜ listesiyle uyumlulaştırılır — aylar önce kaydedilen
    // tercih menüden kalkmış bir malzemeyi taşıyor olabilir.
    final musteriId = widget.musteriId;
    final tercih = musteriId == null || secenekler.isEmpty
        ? const SecenekSecimi()
        : await CustomerRepository(widget.db)
            .urunTercihi(musteriId, u.id, secenekler: secenekler);
    if (!mounted) return;

    final sonuc = await _adetSheetAc(
      context,
      u,
      secenekler: secenekler,
      baslangic: tercih,
      musteriAdi: musteriId == null ? null : widget.musteriAdi,
      tercihUygulandi: !tercih.bos,
    );
    if (sonuc == null || !mounted) return;

    // HATIRLAMA YAZIMI EKLEMEDEN ÖNCE: sipariş satırı zaten seçimi taşıyor, ama tercih yazımı
    // başarısız olursa (müşteri silinmiş) kullanıcı bunu ürün sepete girmeden önce öğrenmeli.
    if (sonuc.hatirla && musteriId != null) {
      await CustomerRepository(widget.db)
          .urunTercihiKaydet(musteriId, u.id, sonuc.secim);
      if (!mounted) return;
    }

    widget.onEkle(u, sonuc.adet, sonuc.secim);
    setState(() => _adetler[u.id] = (_adetler[u.id] ?? 0) + sonuc.adet);
    final ozet = sonuc.secim.ozet();
    widget.onBildir?.call(
        '${u.name} ×${sonuc.adet} sepete eklendi${ozet.isEmpty ? '' : ' ($ozet)'}');
  }

  /// KARODAN doğrudan ekleme/çıkarma (seçeneksiz ürün) — sheet AÇILMAZ.
  ///
  /// Kullanıcı isteği 2026-08-22: "adet seçme işlemi için ekstra bir alan açılıyor, bunun
  /// yerine kompakt kartta adet ve sepete ekleme olsun". Su bayisinde ürünlerin hiçbirinin
  /// seçeneği yoktur, yani her damacana için açılan sheet iki fazladan dokunuştu.
  ///
  /// [delta] NEGATİF OLABİLİR ve çağıran taraf bunu bilmek zorundadır: sipariş formu ile
  /// düzenleme sheet'i, adet sıfıra inince satırı SİLER (`_urunEkle`). Katalog o kararı
  /// vermez — sepetin sahibi o değildir.
  void _karodanDegis(Product u, int delta) {
    final onceki = _adetler[u.id] ?? 0;
    final yeni = onceki + delta;
    if (yeni < 0) return;
    widget.onEkle(u, delta, const SecenekSecimi());
    setState(() {
      if (yeni == 0) {
        _adetler.remove(u.id);
      } else {
        _adetler[u.id] = yeni;
      }
    });
    if (delta > 0) widget.onBildir?.call('${u.name} sepete eklendi');
  }

  /// Karonun ana dokunuşu: seçenekli ürün sheet açar, seçeneksiz ürün doğrudan bir adet ekler.
  Future<void> _karoyaDokun(Product u) async {
    if (secenekleriCoz(u.optionsJson).isNotEmpty) return _sec(u);
    _karodanDegis(u, 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<List<Product>>(
      stream: watchKatalogUrunleri(widget.db),
      initialData: const [],
      builder: (context, snap) {
        final tumu = snap.data ?? const <Product>[];
        // Süzgeç ekrandan BAĞIMSIZ (`katalogSuz`): ad + barkod kuralı orada kilitli.
        final liste = katalogSuz(tumu, _sorgu);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .pos-ust — arama + barkod düğmesi
            Row(
              children: [
                Expanded(
                  child: SipArama(
                    controller: _arama,
                    ipucu: 'Ürün ara',
                    onChanged: (v) => setState(() => _sorgu = v),
                    onTemizle: () => setState(() {
                      _arama.clear();
                      _sorgu = '';
                    }),
                  ),
                ),
                const SizedBox(width: SipSpace.md),
                SipDokun(
                  onTap: _barkodAc,
                  zemin: t.accentSoft,
                  basiliZemin: t.accentSoft,
                  radius: const BorderRadius.all(Radius.circular(13)),
                  olcekle: true,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: SipIcon(SipIcons.barkod, boyut: 21, kalinlik: 2, renk: t.accent),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SipSpace.xl),
            if (liste.isEmpty)
              // Tasarımda tek boş-durum var: `"{q}" için sonuç yok` (s-siparisler.jsx:190).
              // "ürünleri Menü › Ürünler'den ekleyin" yönlendirmesi kaldırıldı — kullanıcıyı
              // katalog sheet'inin içinden gidemeyeceği bir yere yolluyordu.
              _PosBos(
                ikon: tumu.isEmpty ? SipIcons.box : SipIcons.search,
                metin: tumu.isEmpty ? 'Katalog boş' : '"$_sorgu" için sonuç yok',
              )
            else
              // ÜÇ SÜTUN (kullanıcı kararı 2026-08-18): iki sütunda karolar tezgâhta gereksiz
              // büyüktü ve ekrana ancak dört ürün sığıyordu; sipariş girişi sürekli kaydırma
              // istiyordu. Üç sütun aynı yükseklikte %50 daha fazla ürün gösterir.
              //
              // ⚠️ ORAN SÜTUN SAYISINA BAĞLIDIR: `childAspectRatio` GENİŞLİK/YÜKSEKLİK'tir ve
              // karo yüksekliği sabit parçalar (2 satır ad + fiyat satırı + EYLEM ŞERİDİ +
              // dolgu) ile genişliğe ORANTILI parçadan (görsel) oluşur. Sütun sayısı artınca
              // genişlik düşer, sabit parçaların payı büyür — oran güncellenmezse karo kısa
              // kalır ve `Expanded`in altındaki satırlar taşar.
              //
              // 0.68 → 0.60 (2026-08-22): karoya 30 px'lik EYLEM ŞERİDİ eklendi (adet + sepete
              // ekle). Görselin oranı da 5/4'ten 8/5'e çekildi — yoksa karo, kazandığı işlevin
              // iki katı kadar uzardı ve "kompakt kart" isteğinin tersine düşerdi. En dar
              // telefonda (360 dp) karo ≈ 171 px; sabit parçalar ≈ 159 px, yani ~12 px pay var.
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: SipSpace.md,
                crossAxisSpacing: SipSpace.md,
                childAspectRatio: 0.60,
                children: [
                  for (final u in liste)
                    _PosKarosu(
                      urun: u,
                      adet: _adetler[u.id] ?? 0,
                      secenekli: secenekleriCoz(u.optionsJson).isNotEmpty,
                      onTap: () => _karoyaDokun(u),
                      onAzalt: () => _karodanDegis(u, -1),
                    ),
                ],
              ),
            const SizedBox(height: SipSpace.lg),
            // .pos-alt
            SipButon(
              etiket: _adetler.isEmpty ? 'Bitti' : '${_adetler.length} kalem eklendi',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        );
      },
    );
  }

  /// Barkod ikonu → KAMERA. Okunan kod ARAMA ALANINA yazılır (kullanıcı kararı,
  /// 2026-07-26: "okuduğu barkodu direkt inputa yazsın"); ızgara filtresi barkodu da
  /// eşleştirdiği için ürün anında karo olarak kalır, dokunuş adet sheet'ini açar.
  /// Kod hiçbir ürüne bağlı değilse kataloğun kendi boş durumu `"…" için sonuç yok` der —
  /// ayrı bir hata yolu yok.
  Future<void> _barkodAc() async {
    final kod = await barkodKameraAc(context);
    if (kod == null || !mounted) return;
    setState(() {
      _arama.text = kod;
      _sorgu = kod;
    });
  }
}

/// CSS `.pos-img` / `.pos-img.ph` — görsel yoksa ürün adının baş harfi accent-soft daire içinde.
/// Görsel İŞARETÇİSİ (imageUrl) uzak adres olabileceğinden şimdilik yalnız YEREL dosya yolu
/// (imageLocalPath) çizilir; ağdan indirme offline-first sözünü bozar, o boru hattı ayrı iş.
class UrunGorseli extends StatelessWidget {
  const UrunGorseli({
    super.key,
    required this.urun,
    this.en = 52,
    this.oran,
    this.radius = 14,
    this.puntoBoyut = 19,
  });

  final Product urun;
  final double en;

  /// Verilirse kutu bu en/boy oranında çizilir (ızgara karosu), yoksa kare.
  final double? oran;
  final double radius;
  final double puntoBoyut;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final yol = urun.imageLocalPath;
    final harf = urun.name.trim().isEmpty ? '?' : trBuyuk(urun.name.trim()[0]);

    Widget kutu = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(radius),
        image: yol == null
            ? null
            : DecorationImage(image: FileImage(File(yol)), fit: BoxFit.cover),
      ),
      child: yol != null
          ? null
          : Text(harf, style: SipText.tutar(puntoBoyut, w: 800).copyWith(color: t.accent)),
    );

    if (oran != null) kutu = AspectRatio(aspectRatio: oran!, child: kutu);
    return SizedBox(width: en == double.infinity ? null : en, child: kutu);
  }
}

class _PosBos extends StatelessWidget {
  const _PosBos({required this.ikon, required this.metin});
  final String ikon;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 30),
      child: Column(
        children: [
          SipIcon(ikon, boyut: 28, kalinlik: 1.6, renk: t.line2),
          const SizedBox(height: 9),
          Text(metin,
              textAlign: TextAlign.center,
              style: SipText.metin(13, w: 500).copyWith(color: t.muted)),
        ],
      ),
    );
  }
}
