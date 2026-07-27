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
      SipToast.goster(context, 'Salt-okunur kip: yeni kayıt eklenemez.');
      return;
    }
    final ok = await borcTahsilatiAc(context, db: db, customerId: customerId);
    if (ok == true && context.mounted) SipToast.goster(context, 'Tahsilat kaydedildi');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
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
              Text('Tahsilat Al',
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink2)),
            ],
          ),
        ),
      ),
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
