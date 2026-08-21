// Sipariş detayının EYLEM DÜĞMELERİ — CSS `.sdx-duzen-btns` ve altındaki tahsilat eylemi.
//
// NEDEN AYRI DOSYA: `order_detail_screen.dart` 497 satırdaydı ve "Tahsilat Al" eylemi onu 500
// sınırının üstüne çıkarıyordu. Ekranın kendisi düzen/veri işi yapar; düğmelerin görünüşü ve
// para akışına bağlanması ayrı bir konudur.
//
// Bu dosya HİÇBİR YAZMA YAPMAZ: tahsilat kaydını `borcTahsilatiAc` (customer_sheets.dart) yazar,
// o da `LedgerRepository.tahsilat` üzerinden deftere `payment(−)` düşer. Defter append-only.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../customers/customer_sheets.dart' show borcTahsilatiAc;
import 'order_queries.dart';

/// Teslim edilmiş siparişin ÖDENMEMİŞ kalanını söyleyen kutu — `.sd-odendi`nin borç eşi.
///
/// SAHA HATASI (2026-07-29): teslim edilmiş bir siparişte ekranda borçtan tek kelime yoktu.
/// "Nakit ile ödendi" şeridi ödenmiş siparişte çıkıyor, veresiye/kısmi teslimde ise yerine
/// HİÇBİR ŞEY gelmiyordu; bayi kalan borcu ancak "Tahsilat Al"a dokunup sheet'i açınca
/// görebiliyordu — yani borcu ÖĞRENMEK için bir para yazma akışına girmek gerekiyordu.
///
/// İKİ SAYI AYRI YAZILIR ve karıştırılmaz: BU SİPARİŞTEN kalan borç ile MÜŞTERİNİN toplam borcu
/// farklı büyüklüklerdir (müşterinin eski siparişlerinden borcu olabilir). Tahsilat toplam
/// bakiyeden yapılır; ikisi eşit değilken tek sayı göstermek, hangisinin tahsil edileceği
/// konusunda bayiyi yanıltırdı.
class SiparisBorcKutusu extends StatelessWidget {
  const SiparisBorcKutusu({
    super.key,
    required this.db,
    required this.order,
  });

  final AppDatabase db;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final musteriId = order.customerId;
    return StreamBuilder<int>(
      stream: watchSiparisTahsilati(db, order.id),
      initialData: 0,
      builder: (context, tahsilSnap) {
        final kalan = siparisKalanBorcu(
          durum: order.status,
          toplamKurus: order.totalKurus,
          tahsilKurus: tahsilSnap.data ?? 0,
        );
        if (kalan <= 0) return const SizedBox.shrink();
        return StreamBuilder<Customer?>(
          stream: musteriId == null ? const Stream.empty() : watchMusteri(db, musteriId),
          builder: (context, musteriSnap) {
            final bakiye = musteriSnap.data?.balanceKurus ?? 0;
            return Padding(
              padding: const EdgeInsets.only(top: SipSpace.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: SipSpace.x2, vertical: 11),
                decoration:
                    BoxDecoration(color: t.dangerSoft, borderRadius: SipRadius.br2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: SipIcon(SipIcons.wallet,
                          boyut: 16, kalinlik: 2.4, renk: t.danger),
                    ),
                    const SizedBox(width: SipSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bu siparişten kalan borç ${sipTutar(kalan)}',
                              style:
                                  SipText.metin(13, w: 700).copyWith(color: t.danger)),
                          // Toplam borç YALNIZ farklıysa yazılır: eşitken aynı sayıyı iki kez
                          // göstermek kutuyu gürültüye çevirir.
                          if (bakiye > 0 && bakiye != kalan)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Müşterinin toplam borcu ${sipTutar(bakiye)}',
                                style: SipText.metin(12, w: 600)
                                    .copyWith(color: t.danger),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Sipariş dışı borç tahsilatının sipariş detayındaki giriş noktası.
///
/// NEDEN BURADA: "Borçlu" sekmesindeki satıra dokunulunca sipariş detayı açılıyor; bayinin
/// borcu gördüğü yer ile tahsil ettiği yer aynı ekran olmalı. Sipariş listesi tarafında hiçbir
/// değişiklik gerekmiyor.
///
/// TESLİM EDİLMİŞ SİPARİŞTE DE GÖRÜNÜR — asıl kullanım anı odur: veresiye teslim edilmiş bir
/// siparişin müşterisi sonradan öder. Bu yüzden `_duzenlenebilir` (yalnız açık sipariş) kapısına
/// BAĞLANMAZ; kapı yalnız `writable`dır (salt-okunur kip).
///
/// BORCU OLMAYAN MÜŞTERİDE DE ÇİZİLİR ve dokunulabilir. Üç sebep: (1) bakiye canlı bir değerdir,
/// düğmeyi ekranın elindeki anlık kopyaya göre gizlemek bayat karar verir; (2) `borcTahsilatiAc`
/// bakiyeyi dokunma anında defterden okur ve borç yoksa "Bu müşterinin açık borcu yok." diyip
/// hiçbir kayıt yazmaz — sebebini söyleyen bir ekran, kaybolan bir düğmeden anlaşılırdır (Dilim 3
/// kararının aynısı: ana eylemler görünür kalır, kilit sebebini söyler); (3) bayi bakiyeyi ezbere
/// bilmez, düğmenin yokluğu "tahsilat nerede kayboldu" sorusu üretir.
///
/// MÜŞTERİSİZ (tezgâh) SİPARİŞTE HİÇ ÇİZİLMEZ — pasif de çizilmez. Veresiye karosundan farkı:
/// orada kavram vardır ama o bağlamda kullanılamaz; burada tahsilatın muhatabı olan cari HİÇ
/// YOKTUR, pasif bir düğme kullanıcıya var olmayan bir şeyi arattırırdı.
class SiparisTahsilatButonu extends StatelessWidget {
  const SiparisTahsilatButonu({
    super.key,
    required this.db,
    required this.customerId,
    this.writable = true,
  });

  final AppDatabase db;
  final String customerId;
  final bool writable;

  Future<void> _ac(BuildContext context) async {
    if (!writable) {
      SipToast.goster(context, 'Aboneliğiniz sona erdiği için yeni kayıt eklenemiyor.');
      return;
    }
    final ok = await borcTahsilatiAc(context, db: db, customerId: customerId);
    if (ok == true && context.mounted) SipToast.goster(context, 'Tahsilat kaydedildi');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    // Düğmenin ÜSTÜNDE tahsil edilecek tutar yazar: eskiden rakamı görmenin tek yolu düğmeye
    // basıp sheet'i açmaktı. Bakiye canlı akıştan okunur — düğme yine HER DURUMDA çizilir
    // (borç yokken de), yalnız etiketi sayısızdır.
    return StreamBuilder<Customer?>(
      stream: watchMusteri(db, customerId),
      builder: (context, snap) {
        final bakiye = snap.data?.balanceKurus ?? 0;
        return Padding(
          padding: const EdgeInsets.only(top: SipSpace.lg),
          child: SipDokun(
            onTap: () => _ac(context),
            zemin: t.surface2,
            basiliZemin: t.line,
            radius: SipRadius.br2,
            olcekle: true,
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SipIcon(SipIcons.wallet, boyut: 16, kalinlik: 2.2, renk: t.ink2),
                  const SizedBox(width: 7),
                  Text(
                    bakiye > 0 ? 'Tahsilat Al (${sipTutar(bakiye)})' : 'Tahsilat Al',
                    style: SipText.metin(13.5, w: 700).copyWith(color: t.ink2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "İptal Et" — tasarım `.btn-d` sınıfını alır ama satır içi stille YUMUŞATILIR:
/// `background: var(--danger-soft); color: var(--danger)` (s-siparisler.jsx:542).
/// `SipButonTuru.tehlike` dolu kırmızı, `ikincil` ise nötr gri; ikisi de bu görünümü vermiyor —
/// yıkıcı eylem nötr görünmemeli, ama dolu kırmızı da "Teslim Et"in yanında onu bastırıyor.
class YumusakTehlikeButonu extends StatelessWidget {
  const YumusakTehlikeButonu({super.key, required this.etiket, required this.onTap});

  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.dangerSoft,
      basiliZemin: t.dangerSoft,
      radius: SipRadius.br2,
      olcekle: true,
      child: SizedBox(
        height: 44,
        child: Center(
          // CSS `.sdx-duzen-btns .btn { height: 44px; font-size: 13.5px }`.
          child: Text(etiket,
              style: SipText.metin(13.5, w: 700).copyWith(color: t.danger)),
        ),
      ),
    );
  }
}
