// Ürünler ekranı — tasarım s-urunler.jsx + Sipario.html `.urow*`, `.ys-ekle`, `.uliste`.
//
// Liste satırı: küçük görsel (yoksa baş harf yer tutucusu) · ad (+ PASİF rozeti) · birim
// (+ barkod) · fiyat · chevron. Pasif ürün satırı sönükleşir ama FİYATI OKUNUR KALIR — bilgi
// kaybolmaz, yalnız geri plana düşer.
//
// Ürün SİLİNMEZ, pasifleşir: geçmiş sipariş satırları ad/fiyatı kendi içinde taşıdığından
// silme veriyi bozmaz ama katalog geçmişini yalanlar. Form `product_form_sheet.dart` içinde.

import '../../sync/yenileme.dart';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/product_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../isletme/isletme_atomlari.dart';
import 'product_form_sheet.dart';

/// Salt-okunur kip uyarısı — DEĞİŞTİRME: sözleşme testleri bu metni birebir arıyor.
const String saltOkunurUyarisi = 'Aboneliğiniz sona erdiği için yeni kayıt eklenemiyor.';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({
    super.key,
    required this.db,
    required this.writable,
    required this.rol,
  });

  final AppDatabase db;

  /// Abonelik salt-okunur kipinde false — mevcut veri okunur, yeni kayıt yazılmaz.
  final bool writable;

  /// Oturumdaki rol (`patron|operator|kurye`). Kurye bu ekranı göremez (K2).
  final String? rol;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return YoneticiKapisi(
      rol: rol,
      baslik: 'Ürünler',
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<List<Product>>(
            stream: watchProducts(db, activeOnly: false),
            builder: (context, snap) {
              final urunler = snap.data;
              final aktif = urunler?.where((u) => u.isActive).length ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SipUst(
                    baslik: 'Ürünler',
                    alt: urunler == null
                        ? null
                        : '${urunler.length} ürün, $aktif aktif',
                    onGeri: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: urunler == null
                        ? const SipGovde(children: [SipIskelet()])
                        : _Liste(db: db, urunler: urunler, writable: writable),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.db, required this.urunler, required this.writable});

  final AppDatabase db;
  final List<Product> urunler;
  final bool writable;

  Future<void> _ac(BuildContext context, Product? urun) async {
    if (!writable) {
      SipToast.goster(context, saltOkunurUyarisi);
      return;
    }
    final kaydedildi = await urunFormuAc(context, db: db, urun: urun);
    if (kaydedildi && context.mounted) {
      SipToast.goster(context, 'Ürün kaydedildi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SipGovde(
      // Aşağı çekerek yenile: liste sunucudan senkronla besleniyor (kullanıcı isteği 2026-07-29).
      onYenile: yenile,
      children: [
        EkleSatiri(etiket: 'Yeni ürün ekle', onTap: () => _ac(context, null)),
        if (urunler.isEmpty)
          const SipBosDurum(
            ikon: SipIcons.box,
            baslik: 'Henüz ürün yok',
            aciklama: 'Yukarıdan ekleyin. Sipariş alırken ürünler buradan seçilir.',
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.lg),
            child: Column(
              children: [
                for (var i = 0; i < urunler.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 7),
                    child: _UrunSatiri(
                      urun: urunler[i],
                      onTap: () => _ac(context, urunler[i]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UrunSatiri extends StatelessWidget {
  const _UrunSatiri({required this.urun, required this.onTap});

  final Product urun;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final barkod = urunBarkodu(urun);
    return UrunSatiri(
      // Listede YALNIZ cihaz-yerel dosya çizilir; `imageUrl` bir ağ işaretçisidir ve
      // offline-first kuralı gereği liste kaydırırken ağ isteği yapılmaz.
      bas: _Kucuk(ad: urun.name, gorsel: urun.imageLocalPath),
      ad: urun.name,
      altSatir: urun.unit,
      altEk: barkod,
      sag: sipTutar(urun.unitPriceKurus),
      pasif: !urun.isActive,
      onTap: onTap,
    );
  }
}

/// CSS `.urow-thumb` (+ `.ph` yer tutucusu) — 42×42, köşe 12.
class _Kucuk extends StatelessWidget {
  const _Kucuk({required this.ad, required this.gorsel});

  final String ad;
  final String? gorsel;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    const kose = BorderRadius.all(Radius.circular(12));
    final harf = Text(
      ad.trim().isEmpty ? '?' : trBuyuk(ad.trim().substring(0, 1)),
      style: SipText.tutar(16, w: 800).copyWith(color: t.accent),
    );
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: t.accentSoft, borderRadius: kose),
      // Yerel dosya silinmiş/erişilemez olabilir (galeri temizliği, izin kaybı) — o durumda
      // satır boş bir kutuya düşmesin diye baş harfe geri dönülür.
      child: gorsel == null
          ? harf
          : Image.file(
              File(gorsel!),
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(child: harf),
            ),
    );
  }
}

/// Ürün sorgusu (ada göre sıralı, arşivsiz). Ekrandan bağımsız — saf async testle sınanır
/// (widget-test sahte zamanı drift akışlarında güvenilmez; bkz. test/ui_dilim1_test.dart notu).
Stream<List<Product>> watchProducts(AppDatabase db, {bool activeOnly = true}) {
  final q = db.select(db.products)..where((t) => t.deletedAt.isNull());
  if (activeOnly) q.where((t) => t.isActive.equals(true));
  q.orderBy([(t) => OrderingTerm.asc(t.name)]);
  return q.watch();
}

/// GEÇİŞ KÖPRÜSÜ — sipariş formu (`order_form_screen.dart`, başka ajanın alanı) hâlâ eski adı
/// çağırıyor. Yeni tasarımın sheet'ine yönlendirir; sipariş ekranı `urunFormuAc`a geçince silinir.
Future<void> showProductDialog(
  BuildContext context,
  ProductRepository repo, {
  Product? product,
}) async {
  await urunFormuAc(context, db: repo.db, urun: product);
}
