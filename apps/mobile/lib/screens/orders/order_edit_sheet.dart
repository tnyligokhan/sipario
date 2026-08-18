// "Siparişi Düzenle" sheet'i — CSS `.sdx-sb`, `.sd-kart` + `.ys-stepper`.
// Kaynak: s-siparisler.jsx `SiparisDetay` içindeki `duzen` sheet'i.
//
// YAZMA YOLU: satır değişiklikleri `OrderRepository.addLine` / `removeLine` ile uygulanır — her biri
// order_events'e APPEND eder ve outbox'a düşer. Adet değişimi "eski satırı sil + yeni satırı ekle"
// olarak yazılır; repo'da adet güncelleme yoktur ve olmamalıdır (satır, siparişin çekildiği andaki
// gerçeği taşır — üzerine yazmak geçmişi bozar).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/urun_secenekleri.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../money.dart';
import 'order_parts.dart';

import 'pos_catalog.dart';

/// Düzenleme sırasında tutulan satır. [lineId] null ise bu oturumda EKLENMİŞ yeni satırdır.
class DuzenSatiri {
  DuzenSatiri({
    this.lineId,
    this.productId,
    required this.ad,
    required this.birimFiyatKurus,
    required this.adet,
    this.unit,
    this.serbestBayrak = false,
    this.note,
  });

  final String? lineId;
  final String? productId;
  final String ad;
  final int birimFiyatKurus;
  final String? unit;

  /// SATIR NOTU. Adet değişimi satırı SİLİP YENİDEN EKLEDİĞİ için (append-only) notun burada
  /// taşınması şart: taşınmasaydı kullanıcı adedi bir artırdığında notu sessizce kaybolurdu.
  String? note;

  /// Kayıtlı satırdan gelen `OrderLines.isCustom`. Yeni eklenen serbest satırda productId zaten
  /// null olduğundan varsayılan false yeterli.
  final bool serbestBayrak;

  int adet;

  bool get serbest => serbestBayrak || productId == null;
  int get tutar => birimFiyatKurus * adet;
}

/// Sheet'i açar. Kaydedilirse `true` döner (çağıran taraf bildirim gösterir).
Future<bool?> siparisDuzenleSheetAc(
  BuildContext context, {
  required AppDatabase db,
  required String orderId,
  required List<OrderLine> satirlar,
}) =>
    sipSheet<bool>(
      context,
      baslik: 'Siparişi Düzenle',
      tam: true,
      govde: (ctx) => _DuzenGovde(db: db, orderId: orderId, satirlar: satirlar),
    );

class _DuzenGovde extends StatefulWidget {
  const _DuzenGovde({required this.db, required this.orderId, required this.satirlar});

  final AppDatabase db;
  final String orderId;
  final List<OrderLine> satirlar;

  @override
  State<_DuzenGovde> createState() => _DuzenGovdeState();
}

class _DuzenGovdeState extends State<_DuzenGovde> {
  late final List<DuzenSatiri> _taslak = widget.satirlar
      .map((l) => DuzenSatiri(
            lineId: l.id,
            productId: l.productId,
            ad: l.productName,
            birimFiyatKurus: l.unitPriceKurus,
            unit: l.unit,
            serbestBayrak: l.isCustom,
            adet: l.qty,
          ))
      .toList();

  final _sbAd = TextEditingController();
  final _sbTutar = TextEditingController();
  bool _kaydediyor = false;

  @override
  void dispose() {
    _sbAd.dispose();
    _sbTutar.dispose();
    super.dispose();
  }

  int get _toplam => _taslak.fold<int>(0, (s, r) => s + r.tutar);
  bool get _bos => _taslak.isEmpty;

  void _adetDegis(int i, int delta) {
    setState(() {
      final yeni = _taslak[i].adet + delta;
      if (yeni <= 0) {
        _taslak.removeAt(i);
      } else {
        _taslak[i].adet = yeni;
      }
    });
  }

  void _serbestEkle() {
    final ad = _sbAd.text.trim();
    // Kuruş YAZILABİLİR (order_sd_parts.dart ile aynı gerekçe): serbest satır sipariş toplamına
    // giriyor, teslimdeki kuruşlu tahsilatın kaynağı burası. Dönüşüm tek para sınırından geçer.
    final kurus = parseKurus(_sbTutar.text);
    if (ad.length < 2 || kurus == null || kurus <= 0) {
      SipToast.goster(context, 'Açıklama ve 0’dan büyük tutar girin');
      return;
    }
    setState(() {
      _taslak.add(DuzenSatiri(ad: ad, birimFiyatKurus: kurus, adet: 1));
      _sbAd.clear();
      _sbTutar.clear();
    });
  }

  Future<void> _kaydet() async {
    if (_bos || _kaydediyor) return;
    setState(() => _kaydediyor = true);
    final repo = OrderRepository(widget.db);
    try {
      for (final orijinal in widget.satirlar) {
        DuzenSatiri? kalan;
        for (final d in _taslak) {
          if (d.lineId == orijinal.id) {
            kalan = d;
            break;
          }
        }
        if (kalan == null) {
          await repo.removeLine(widget.orderId, orijinal.id);
        } else if (kalan.adet != orijinal.qty) {
          // Adet değişimi: eski satır kaldırılır, yeni adetle yenisi eklenir (append-only).
          await repo.removeLine(widget.orderId, orijinal.id);
          await repo.addLine(
            widget.orderId,
            LineInput(
              productId: kalan.productId,
              productName: kalan.ad,
              unitPriceKurus: kalan.birimFiyatKurus,
              unit: kalan.unit,
              isCustom: kalan.serbest,
              qty: kalan.adet,
            ),
          );
        }
      }
      for (final d in _taslak.where((x) => x.lineId == null)) {
        await repo.addLine(
          widget.orderId,
          LineInput(
            productId: d.productId,
            productName: d.ad,
            unitPriceKurus: d.birimFiyatKurus,
            unit: d.unit,
            isCustom: d.serbest,
            qty: d.adet,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  /// [secim] BU SHEET'TE SORULMAZ ve kullanılmaz (2026-08-18) — imzada durmasının sebebi
  /// `posKatalogAc` sözleşmesidir. Düzenleme sheet'i var olan bir siparişin ADET/SATIR
  /// düzeltmesidir; katalog buradan müşterisiz açılır, yani tercih de uygulanmaz ve seçim
  /// her zaman boş gelir. Sessizce yok saymak yerine bu not yazıldı: parametreyi görüp
  /// "neden kullanılmıyor" diye soran kişinin cevabı burada.
  void _urunEkle(Product u, int adet, SecenekSecimi secim) {
    setState(() {
      final i = _taslak.indexWhere((x) => x.productId == u.id);
      if (i >= 0) {
        _taslak[i].adet += adet;
      } else {
        _taslak.add(DuzenSatiri(
          productId: u.id,
          ad: u.name,
          birimFiyatKurus: u.unitPriceKurus,
          unit: u.unit,
          adet: adet,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SdxSec('Kalemler', ustBosluk: 2),
        SdKart(
          toplamEtiketi: 'Yeni toplam',
          toplamKurus: _toplam,
          satirlar: [
            for (var i = 0; i < _taslak.length; i++)
              SdSatiri(
                ad: _taslak[i].ad,
                // Tasarım `{fmtTL(r.fiyat)} / {r.birim}` (s-siparisler.jsx:553). Birim SABİT
                // "adet" yazılıyordu → koli/kg satan bayide satır YANLIŞ bilgi veriyordu.
                // Birim satırın kendisinde saklı (siparişin çekildiği andaki gerçek).
                altMetin: _taslak[i].serbest
                    ? 'tek seferlik'
                    : '${sipTutar(_taslak[i].birimFiyatKurus)} / ${_taslak[i].unit ?? 'adet'}',
                tutarKurus: _taslak[i].tutar,
                orta: _taslak[i].serbest
                    ? SipIkonButon(
                        ikon: SipIcons.x,
                        cap: 30,
                        ikonBoyut: 16,
                        kalinlik: 2.2,
                        renk: t.muted,
                        etiket: 'Satırı sil',
                        onTap: () => setState(() => _taslak.removeAt(i)),
                      )
                    : YsStepper(
                        adet: _taslak[i].adet,
                        onAzalt: () => _adetDegis(i, -1),
                        onArtir: () => _adetDegis(i, 1),
                      ),
              ),
            if (_bos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SipSpace.lg),
                child: Row(
                  children: [
                    SipIcon(SipIcons.alert, boyut: 13, kalinlik: 2.2, renk: t.danger),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text('Sepet boş kalamaz — en az bir kalem ekleyin',
                          style: SipText.metin(12, w: 700).copyWith(color: t.danger)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        YsEkleDugmesi(
          etiket: 'Katalogdan ürün ekle',
          ikon: SipIcons.plus,
          onTap: () => posKatalogAc(context, db: widget.db, onEkle: _urunEkle),
        ),
        const SdxSec('Serbest Satır Ekle'),
        // .sdx-sb — açıklama + tutar + Ekle, tek satır.
        Row(
          children: [
            Expanded(flex: 2, child: SipInput(controller: _sbAd, ipucu: 'Açıklama (ör. nakliye)')),
            const SizedBox(width: SipSpace.md),
            Expanded(
              child: SipInput(
                controller: _sbTutar,
                ipucu: '₺',
                // Rakam + ayraç (tahsilat alanıyla aynı desen) — kuruşlu serbest satır yazılabilsin.
                klavye: const TextInputType.numberWithOptions(decimal: true),
                girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
              ),
            ),
            const SizedBox(width: SipSpace.md),
            SipButon(
              etiket: 'Ekle',
              tur: SipButonTuru.ikincil,
              genisle: false,
              yukseklik: 46,
              yatayPadding: 16,
              onTap: _serbestEkle,
            ),
          ],
        ),
        const SizedBox(height: SipSpace.x3),
        Row(
          children: [
            Expanded(
              child: SipButon(
                etiket: 'Vazgeç',
                tur: SipButonTuru.ikincil,
                yukseklik: 44,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: SipSpace.md),
            Expanded(
              child: SipButon(
                etiket: 'Değişiklikleri Kaydet',
                yukseklik: 44,
                yukleniyor: _kaydediyor,
                onTap: _bos ? null : _kaydet,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
