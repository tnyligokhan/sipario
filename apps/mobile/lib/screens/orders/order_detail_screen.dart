// Sipariş detayı + TESLİM KAPATMA — CSS `.sdx-*`, `.sd-*`, `.gec-*`.
// Kaynak: s-siparisler.jsx `SiparisDetay`.
//
// Tasarımda detay alttan açılan TAM SHEET'tir → [siparisDetaySheetAc]. [OrderDetailScreen] aynı
// gövdeyi tam sayfa olarak sarar (derin bağlantı ve testler için); ikisi de tek gövdeyi paylaşır,
// böylece iki yüzey ayrışamaz.
//
// Teslim, ödeme tipini sorar ve `OrderRepository.deliver` ile parayı deftere TEK
// transaction'da düşürür (FAZ 3/4). İnternetsiz saniyeler içinde biter — hiçbir ağ çağrısı
// beklenmez (BRIEF); kayıt outbox'a düşer, senkron sonra taşır.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../customers/customer_form_screen.dart' show musteriDuzenleSheet;
import '../team.dart';
import 'delivery_sheet.dart';
import 'order_detail_eylemler.dart';
import 'order_detail_parts.dart';
import 'order_edit_sheet.dart';
import 'order_parts.dart';
import 'order_queries.dart';
import 'order_sheets.dart';

export 'order_queries.dart'
    show
        odemeTipiEtiketi,
        odemeTipiSecilebilir,
        odemeTipleri,
        saatBicimi,
        teslimOdemeTipleri;

/// Detayı tasarımdaki gibi alttan TAM SHEET olarak açar.
///
/// Sheet BAŞLIĞI müşteri adıdır (tasarım `<Sheet tam baslik={o.musteriAd}>`, s-siparisler.jsx:466).
/// Başlık geçmediği sürece `sipSheet` üst şeridi hiç çizmiyordu — tutamaç, başlık ve KAPAT (X)
/// düğmesi birlikte kayboluyor, kullanıcının sheet'i kapatacak görünür bir düğmesi kalmıyordu.
/// [baslik] verilmezse tek atış okunur; çağıranın elinde ad varsa (liste satırı) o geçirilir.
Future<void> siparisDetaySheetAc(
  BuildContext context, {
  required AppDatabase db,
  required String orderId,
  required bool writable,
  bool canAssign = false,
  String? baslik,
}) async {
  final ad = baslik ?? await siparisBasligi(db, orderId);
  if (!context.mounted) return;
  await sipSheet<void>(
    context,
    tam: true,
    baslik: ad,
    govde: (ctx) => SiparisDetayGovde(
      db: db,
      orderId: orderId,
      writable: writable,
      canAssign: canAssign,
    ),
  );
}

/// Tam sayfa sarmalayıcı. Sheet ile AYNI gövdeyi çizer.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.db,
    required this.orderId,
    required this.writable,
    this.canAssign = false,
  });

  final AppDatabase db;
  final String orderId;
  final bool writable;

  /// Sipariş kuryeye atanabilir mi (K2: yönetici VE bayide aktif kurye var). Tek kişilikte false.
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(baslik: 'Sipariş', onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    SipSpace.govde, 0, SipSpace.govde, SipSpace.x5),
                child: SiparisDetayGovde(
                  db: db,
                  orderId: orderId,
                  writable: writable,
                  canAssign: canAssign,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SiparisDetayGovde extends StatelessWidget {
  const SiparisDetayGovde({
    super.key,
    required this.db,
    required this.orderId,
    required this.writable,
    this.canAssign = false,
  });

  final AppDatabase db;
  final String orderId;
  final bool writable;
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Order?>(
      stream: (db.select(db.orders)..where((t) => t.id.equals(orderId))).watchSingleOrNull(),
      builder: (context, snap) {
        final order = snap.data;
        if (order == null) return const SipIskelet(adet: 3);
        return StreamBuilder<List<OrderLine>>(
          stream: watchOrderLines(db, orderId),
          initialData: const [],
          builder: (context, lineSnap) => _Govde(
            db: db,
            order: order,
            satirlar: lineSnap.data ?? const [],
            writable: writable,
            canAssign: canAssign,
          ),
        );
      },
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({
    required this.db,
    required this.order,
    required this.satirlar,
    required this.writable,
    required this.canAssign,
  });

  final AppDatabase db;
  final Order order;
  final List<OrderLine> satirlar;
  final bool writable;
  final bool canAssign;

  bool get _acik => order.status == 'open';
  bool get _duzenlenebilir => writable && _acik;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final musteriId = order.customerId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── .sdx-head ─────────────────────────────────────────────────────────────────────
        _Baslik(
          db: db,
          order: order,
          canAssign: canAssign,
          duzenlenebilir: _duzenlenebilir,
        ),

        // ── Kalemler ──────────────────────────────────────────────────────────────────────
        SdxSec(
          'Sipariş Kalemleri',
          sag: _duzenlenebilir
              ? SdxLink(
                  etiket: 'Düzenle',
                  onTap: () async {
                    final kaydedildi = await siparisDuzenleSheetAc(
                      context,
                      db: db,
                      orderId: order.id,
                      satirlar: satirlar,
                    );
                    if (kaydedildi == true && context.mounted) {
                      SipToast.goster(context, 'Sipariş güncellendi');
                    }
                  },
                )
              : null,
        ),
        SdKart(
          toplamKurus: satirlarToplami(satirlar),
          satirlar: [
            for (final l in satirlar)
              SdSatiri(
                ad: l.productName,
                // Tasarım `{r.adet} {r.birim} × {fmtTL(r.fiyat)}` (s-siparisler.jsx:478) —
                // BİRİM düşerse "3 × 120,00 ₺" koli mi kg mı adet mi belli olmaz.
                altMetin: serbestMi(l)
                    ? 'tek seferlik'
                    : '${l.qty} ${l.unit ?? 'adet'} × ${sipTutar(l.unitPriceKurus)}',
                tutarKurus: l.lineTotalKurus,
              ),
          ],
        ),

        // ── Not ───────────────────────────────────────────────────────────────────────────
        NotBolumu(db: db, order: order, duzenlenebilir: _duzenlenebilir),

        // ── Adres + geçmiş (yalnız müşterili siparişte) ────────────────────────────────────
        if (musteriId != null) ...[
          SdxSec(
            'Teslimat Adresi',
            // Tasarım s-siparisler.jsx:506. Adres yanlışsa düzeltmenin yeri müşteri kaydıdır;
            // sipariş detayından çıkıp müşteriyi aramak zorunda kalmasın. Form sheet'i
            // `screens/customers/`de yaşıyor — buradan yalnız ÇAĞRILIR.
            sag: _duzenlenebilir
                ? SdxLink(
                    etiket: 'Müşteriyi Düzenle',
                    onTap: () => _musteriDuzenle(context, musteriId),
                  )
                : null,
          ),
          AdresBolumu(db: db, musteriId: musteriId),
          GecmisBolumu(db: db, musteriId: musteriId, orderId: order.id),
        ],

        // ── .sd-odendi ────────────────────────────────────────────────────────────────────
        if (order.paymentType != null) ...[
          const SizedBox(height: SipSpace.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 11),
            decoration: BoxDecoration(color: t.okSoft, borderRadius: SipRadius.br2),
            child: Row(
              children: [
                SipIcon(SipIcons.check, boyut: 16, kalinlik: 2.4, renk: t.ok),
                const SizedBox(width: SipSpace.md),
                Expanded(
                  child: Text('${odemeTipiEtiketi(order.paymentType!)} ile ödendi',
                      style: SipText.metin(13, w: 700).copyWith(color: t.ok)),
                ),
              ],
            ),
          ),
        ],

        // Kalan borç — `.sd-odendi`nin karşılığı. Veresiye/kısmi teslimde ekranda borçtan tek
        // kelime yoktu (saha hatası 2026-07-29); kutu yalnız borç varken çizilir.
        SiparisBorcKutusu(db: db, order: order),

        // Sipariş DIŞI borç tahsilatı — teslim edilmiş siparişte de görünür (asıl kullanım anı
        // odur: veresiye teslim, sonra tahsilat). Gerekçeler `SiparisTahsilatButonu` başlığında.
        if (musteriId != null)
          SiparisTahsilatButonu(db: db, customerId: musteriId, writable: writable),

        // ── .sdx-duzen-btns ───────────────────────────────────────────────────────────────
        if (_duzenlenebilir) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: YumusakTehlikeButonu(
                  etiket: 'İptal Et',
                  onTap: () => _iptalEt(context),
                ),
              ),
              const SizedBox(width: SipSpace.md),
              Expanded(
                flex: 2,
                child: SipButon(
                  etiket: 'Teslim Et',
                  yukseklik: 44,
                  onTap: () => _teslimEt(context),
                ),
              ),
            ],
          ),
        ] else if (!writable && _acik) ...[
          const SizedBox(height: 18),
          const SipNotKutusu(
            metin: 'Salt-okunur kip: teslim ve iptal yapılamaz.',
            ikon: SipIcons.lock,
            tur: SipNotTuru.hata,
          ),
        ],
      ],
    );
  }

  /// Teslim + KISMİ ÖDEME: sheet ne kadar tahsil edildiğini döner, `deliver` alınan parayı
  /// `payment` olarak yazar; kalan fark ödenmemiş `debit` olarak borçta durur (ayrı kayıt YOK).
  Future<void> _teslimEt(BuildContext context) async {
    final musteriId = order.customerId;
    final toplam = satirlarToplami(satirlar);
    // Teslimden ÖNCEKİ bakiye tek atış okunur: sheet yalnız sipariş tutarını görür, "fazla ödemede
    // müşteri ne kadar alacaklı kalacak" sorusunu bu olmadan yanıtlayamaz (akış beklenemez).
    final oncekiBakiye =
        musteriId == null ? 0 : (await musteriOku(db, musteriId))?.balanceKurus ?? 0;
    if (!context.mounted) return;

    final sonuc = await teslimSheetAc(context,
        toplamKurus: toplam,
        musteriVar: musteriId != null,
        oncekiBakiyeKurus: oncekiBakiye);
    if (sonuc == null || !context.mounted) return;

    await OrderRepository(db)
        .deliver(order.id, paymentType: sonuc.odemeTipi, tahsilKurus: sonuc.tahsilKurus);
    if (!context.mounted) return;

    // Bayi teslim anında en çok "borç kaldı mı" diye merak eder — kısmi teslimde toast onu söyler.
    final kalan = teslimBorcFarki(toplamKurus: toplam, tahsilKurus: sonuc.tahsilKurus);
    final ek = kalan > 0 && sonuc.odemeTipi != 'veresiye' ? ' · ${sipTutar(kalan)} borç' : '';
    SipToast.goster(context, 'Sipariş teslim edildi · ${odemeTipiEtiketi(sonuc.odemeTipi)}$ek');
    Navigator.of(context).maybePop();
  }

  /// "Müşteriyi Düzenle" — form `screens/customers/`de. Sheet kayıt + telefonlar + adresi HAZIR
  /// ister; üçü tek okumada toplanır (o dosya BAŞKA ajanın alanı, imzasına dokunulmaz).
  Future<void> _musteriDuzenle(BuildContext context, String musteriId) async {
    final veri = await musteriDuzenleVerisiOku(db, musteriId);
    if (!context.mounted) return;
    if (veri == null) {
      SipToast.goster(context, 'Müşteri kaydı bulunamadı');
      return;
    }
    final ok = await musteriDuzenleSheet(
      context,
      db: db,
      musteri: veri.musteri,
      telefonlar: veri.telefonlar,
      adres: veri.adres,
    );
    if (ok == true && context.mounted) {
      SipToast.goster(context, 'Müşteri bilgileri güncellendi');
    }
  }

  Future<void> _iptalEt(BuildContext context) async {
    final onay = await sipOnay(
      context,
      baslik: 'Sipariş iptal edilsin mi?',
      mesaj: 'Kayıt silinmez, iptal olarak işaretlenir.',
      onayEtiketi: 'İptal Et',
      tehlike: true,
    );
    if (!onay || !context.mounted) return;
    await OrderRepository(db).cancel(order.id);
    if (!context.mounted) return;
    SipToast.goster(context, 'Sipariş iptal edildi');
    Navigator.of(context).maybePop();
  }
}

/// CSS `.sdx-head` — kod rozeti · durum pili · kurye · saat.
class _Baslik extends StatelessWidget {
  const _Baslik({
    required this.db,
    required this.order,
    required this.canAssign,
    required this.duzenlenebilir,
  });

  final AppDatabase db;
  final Order order;
  final bool canAssign;
  final bool duzenlenebilir;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final kod = musteriKod(order.customerId);

    return StreamBuilder<List<User>>(
      stream: watchTeam(db),
      initialData: const [],
      builder: (context, snap) {
        final ekip = snap.data ?? const <User>[];
        final kuryeAd = kullaniciAdi(ekip, order.assignedUserId);
        return Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 7,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (kod != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.accentSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(kod, style: SipText.siparisKod.copyWith(color: t.accent)),
                    ),
                  SipDurumPili(durum: order.status),
                  if (kuryeAd != null)
                    SipDokun(
                      onTap: duzenlenebilir && canAssign ? () => _kuryeSec(context, ekip) : null,
                      zemin: t.surface2,
                      basiliZemin: t.line,
                      radius: SipRadius.brHap,
                      kenarlik: Border.all(color: t.line2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: SipSpace.lg, vertical: SipSpace.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SipIcon(SipIcons.truck, boyut: 13, kalinlik: 2.2, renk: t.ink2),
                          const SizedBox(width: 5),
                          Text(kuryeAd, style: SipText.kuryeCip.copyWith(color: t.ink2)),
                          if (duzenlenebilir && canAssign) ...[
                            const SizedBox(width: 5),
                            SipIcon(SipIcons.down, boyut: 12, kalinlik: 2.4, renk: t.muted),
                          ],
                        ],
                      ),
                    ),
                  // "Kuryeye ata" bağlantısı YOK: tasarımın `.sdx-head`inde kurye çipi HEP
                  // doludur (s-siparisler.jsx:470). Kurye adı yoksa bu bayi atama kullanmıyor
                  // demektir — o bayiye kurye kavramını burada hatırlatmayız (BRIEF: tek
                  // kişilikte kurye adımları görünmez).
                ],
              ),
            ),
            const SizedBox(width: SipSpace.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SipIcon(SipIcons.clock, boyut: 12, kalinlik: 2, renk: t.muted),
                const SizedBox(width: SipSpace.xs),
                Text(saatBicimi(order.occurredAt),
                    style: SipText.saat.copyWith(color: t.muted)),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _kuryeSec(BuildContext context, List<User> ekip) async {
    final kuryeler = await watchAktifKuryeler(db).first;
    if (!context.mounted) return;
    if (kuryeler.isEmpty) {
      SipToast.goster(context, 'Atanacak aktif kurye yok');
      return;
    }
    final secili = await kuryeSecSheet(
      context,
      kuryeler: kuryeler,
      seciliId: order.assignedUserId,
    );
    if (secili == null || secili == order.assignedUserId || !context.mounted) return;
    await OrderRepository(db).assign(order.id, secili);
    if (!context.mounted) return;
    SipToast.goster(context, 'Kurye değiştirildi: ${kullaniciAdi(kuryeler, secili) ?? ''}');
  }
}
