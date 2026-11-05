// MÜŞTERİ KARTININ "ÖZEL FİYATLAR" BÖLÜMÜ (saha, 2026-11-05: müşteri bazlı fiyatlandırma).
//
// Bayi bir üründe bu müşteriye katalogdan farklı birim fiyat tanımlar; sipariş girilirken o ürün
// kendiliğinden bu fiyatla sepete düşer ve katalogda da öyle görünür.
//
// YALNIZ ÜRÜN YÖNETİMİ YETKİSİNE AÇIK: fiyat tanımı `urunYonetimi` ("Ürün Ekleme / Düzenleme / Fiyat")
// işidir. Kapı çağıranda: bölüm yetkisizde hiç çizilmez.
//
// ÜRÜN TERCİHLERİNDEN FARKI: tercih sipariş anında öğrenilir, burası ise bilinçli bir tanımdır ve
// sipariş ekranında başka bir yerden girilmez. Bu yüzden düzenleme burada yapılır.

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../repo/customer_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../isletme/isletme_atomlari.dart';
import '../money.dart';
import '../orders/order_parts.dart' show YsEkleDugmesi;
import '../orders/order_queries.dart' show katalogSuz, watchKatalogUrunleri;

class MusteriOzelFiyatlari extends StatelessWidget {
  const MusteriOzelFiyatlari({
    super.key,
    required this.db,
    required this.customerId,
    required this.yazabilir,
  });

  final AppDatabase db;
  final String customerId;

  /// Yazma kapısı, çağrı ANINDA sorulur (`MusteriFavorileri` ile aynı sözleşme).
  final bool Function() yazabilir;

  CustomerRepository get _repo => CustomerRepository(db);

  /// İki tabloyu birlikte izler: fiyat `customers`ta, ürün adı ve katalog fiyatı `products`ta.
  Stream<List<_FiyatSatiri>> _akis() => db
      .customSelect('SELECT 1', readsFrom: {db.customers, db.products})
      .watch()
      .asyncMap((_) => _oku());

  Future<List<_FiyatSatiri>> _oku() async {
    final fiyatlar = await _repo.musteriFiyatlariniOku(customerId);
    if (fiyatlar.bosMu) return const [];
    final urunler = await (db.select(db.products)
          ..where((t) => t.id.isIn(fiyatlar.urunIdleri.toList()) & t.deletedAt.isNull()))
        .get();
    // Silinmiş ürün elenir (favori ve tercih listesiyle aynı kural).
    return [
      for (final u in urunler)
        _FiyatSatiri(urun: u, kurus: fiyatlar.birimFiyat(u.id, u.unitPriceKurus)),
    ]..sort((a, b) => a.urun.name.compareTo(b.urun.name));
  }

  Future<void> _duzenle(BuildContext context, {Product? urun, int? mevcutKurus}) async {
    if (!yazabilir()) return;
    final sonuc = await sipSheet<_FiyatSonucu>(
      context,
      baslik: 'Özel Fiyat',
      tam: urun == null,
      govde: (ctx) => _FiyatGovde(db: db, urun: urun, mevcutKurus: mevcutKurus),
    );
    if (sonuc == null || !context.mounted) return;
    await _repo.musteriFiyatiKaydet(customerId, sonuc.urunId, sonuc.kurus);
    if (context.mounted) SipToast.goster(context, 'Özel fiyat kaydedildi');
  }

  Future<void> _sil(BuildContext context, _FiyatSatiri s) async {
    if (!yazabilir()) return;
    final onay = await sipOnay(
      context,
      baslik: 'Özel fiyat silinsin mi?',
      mesaj: '"${s.urun.name}" bu müşteriye yine katalog fiyatından satılacak',
      onayEtiketi: 'Sil',
      tehlike: true,
    );
    if (!onay || !context.mounted) return;
    await _repo.musteriFiyatiKaydet(customerId, s.urun.id, null);
    if (context.mounted) SipToast.goster(context, 'Özel fiyat kaldırıldı');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_FiyatSatiri>>(
      stream: _akis(),
      builder: (context, snap) {
        final liste = snap.data ?? const <_FiyatSatiri>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SipBolumBaslik('Özel Fiyatlar', ustBosluk: 18),
            for (final s in liste)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Satir(
                  satir: s,
                  onDuzenle: () => _duzenle(context, urun: s.urun, mevcutKurus: s.kurus),
                  onSil: () => _sil(context, s),
                ),
              ),
            YsEkleDugmesi(
              etiket: 'Özel fiyat ekle',
              ikon: SipIcons.plus,
              onTap: () => _duzenle(context),
            ),
          ],
        );
      },
    );
  }
}

class _FiyatSatiri {
  const _FiyatSatiri({required this.urun, required this.kurus});
  final Product urun;
  final int kurus;
}

class _FiyatSonucu {
  const _FiyatSonucu(this.urunId, this.kurus);
  final String urunId;
  final int kurus;
}

class _Satir extends StatelessWidget {
  const _Satir({required this.satir, required this.onDuzenle, required this.onSil});

  final _FiyatSatiri satir;
  final VoidCallback onDuzenle;
  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onDuzenle,
      zemin: t.surface,
      basiliZemin: t.surface2,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  satir.urun.name,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Katalog ${sipTutar(satir.urun.unitPriceKurus)}',
                  style: SipText.metin(11.5, w: 600).copyWith(color: t.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Text(sipTutar(satir.kurus), style: SipText.tutar(13.5).copyWith(color: t.accent)),
          const SizedBox(width: SipSpace.md),
          SipIkonButon(
            ikon: SipIcons.trash,
            ikonBoyut: 16,
            renk: t.muted,
            etiket: '${satir.urun.name} özel fiyatını sil',
            onTap: onSil,
          ),
        ],
      ),
    );
  }
}

/// Ürün seçme + fiyat girme. [urun] verilirse (düzenleme) seçim adımı atlanır.
class _FiyatGovde extends StatefulWidget {
  const _FiyatGovde({required this.db, this.urun, this.mevcutKurus});

  final AppDatabase db;
  final Product? urun;
  final int? mevcutKurus;

  @override
  State<_FiyatGovde> createState() => _FiyatGovdeState();
}

class _FiyatGovdeState extends State<_FiyatGovde> {
  late Product? _urun = widget.urun;
  final _arama = TextEditingController();
  late final _fiyat = TextEditingController(
    text: widget.mevcutKurus == null ? '' : sipTutar(widget.mevcutKurus!, simge: false),
  );
  String _sorgu = '';

  @override
  void dispose() {
    _arama.dispose();
    _fiyat.dispose();
    super.dispose();
  }

  /// Sıfır geçerlidir: bayi bir müşteriye ürünü bedelsiz verebilir.
  int? get _kurus {
    final metin = _fiyat.text.trim();
    if (metin.isEmpty) return null;
    return parseKurus(metin);
  }

  @override
  Widget build(BuildContext context) {
    final urun = _urun;
    return urun == null ? _urunSecimi() : _fiyatGirisi(urun);
  }

  Widget _urunSecimi() {
    final t = context.sip;
    return StreamBuilder<List<Product>>(
      stream: watchKatalogUrunleri(widget.db),
      initialData: const [],
      builder: (context, snap) {
        final liste = katalogSuz(snap.data ?? const [], _sorgu);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipArama(
              controller: _arama,
              ipucu: 'Ürün ara',
              onChanged: (v) => setState(() => _sorgu = v),
              onTemizle: () => setState(() {
                _arama.clear();
                _sorgu = '';
              }),
            ),
            const SizedBox(height: SipSpace.md),
            for (final u in liste)
              SipDokun(
                onTap: () => setState(() => _urun = u),
                radius: SipRadius.br1,
                padding: const EdgeInsets.symmetric(
                    horizontal: SipSpace.md, vertical: SipSpace.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        u.name,
                        style: SipText.metin(13.5, w: 600).copyWith(color: t.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(sipTutar(u.unitPriceKurus),
                        style: SipText.tutar(12.5).copyWith(color: t.muted)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _fiyatGirisi(Product urun) {
    final kurus = _kurus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlanNotu(
          '${urun.name} için katalog fiyatı ${sipTutar(urun.unitPriceKurus)}',
          tur: AlanNotuTuru.bilgi,
        ),
        const SipFormEtiket('BU MÜŞTERİYE BİRİM FİYAT (₺)'),
        SipInput(
          controller: _fiyat,
          ipucu: '0,00',
          klavye: const TextInputType.numberWithOptions(decimal: true),
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          stil: SipText.tutar(22),
          yukseklik: 56,
          otomatikOdak: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: SipSpace.x3),
        SipButon(
          etiket: 'Kaydet',
          onTap: kurus == null
              ? null
              : () => Navigator.of(context).pop(_FiyatSonucu(urun.id, kurus)),
        ),
      ],
    );
  }
}
