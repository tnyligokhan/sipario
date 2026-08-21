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
  int _eklenen = 0;

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

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
    setState(() => _eklenen++);
    final ozet = sonuc.secim.ozet();
    widget.onBildir?.call(
        '${u.name} ×${sonuc.adet} sepete eklendi${ozet.isEmpty ? '' : ' ($ozet)'}');
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
                    ipucu: 'Ürün ara…',
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
              // karo yüksekliği sabit parçalar (2 satır ad + fiyat satırı + dolgu ≈ 76 px)
              // ile genişliğe ORANTILI parçadan (5/4 görsel) oluşur. Sütun sayısı artınca
              // genişlik düşer, sabit parçaların payı büyür — eski 0.86 ile karo 40 px kısa
              // kalır ve `Expanded`in altındaki fiyat satırı taşardı. 0.68, en dar telefonda
              // (360 dp) bile ~10 px pay bırakır.
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: SipSpace.md,
                crossAxisSpacing: SipSpace.md,
                childAspectRatio: 0.68,
                children: [
                  for (final u in liste) _PosKarosu(urun: u, onTap: () => _sec(u)),
                ],
              ),
            const SizedBox(height: SipSpace.lg),
            // .pos-alt
            SipButon(
              etiket: _eklenen > 0 ? '$_eklenen kalem eklendi' : 'Bitti',
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

/// CSS `.pos-tile` — görsel/baş harf, ad (2 satır), fiyat + birim.
class _PosKarosu extends StatelessWidget {
  const _PosKarosu({required this.urun, required this.onTap});

  final Product urun;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface2,
      basiliZemin: t.line,
      radius: const BorderRadius.all(Radius.circular(16)),
      olcekle: true,
      // Üç sütunda dolgu 8 → 6: kaybedilen her piksel doğrudan görselden ve ad satırından
      // çıkıyordu. Alt dolgu (9) üsttekinden büyük kalır — fiyat satırı kenara yapışmasın.
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UrunGorseli(urun: urun, en: double.infinity, oran: 5 / 4, radius: 10, puntoBoyut: 20),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                urun.name,
                style: SipText.metin(12, w: 700, h: 1.3).copyWith(color: t.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    sipTutar(urun.unitPriceKurus),
                    style: SipText.tutar(12.5).copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 3),
                // BİRİM DARALTILABİLİR: dar telefonda "1.250,00 ₺" + "/ porsiyon" yan yana
                // sığmaz. Kırpılacaksa BİRİM kırpılır, fiyat değil — bayi fiyatı okuyamazsa
                // karo işini yapmıyor demektir.
                Flexible(
                  child: Text(
                    '/ ${urun.unit}',
                    style: SipText.metin(9.5, w: 500).copyWith(color: t.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
