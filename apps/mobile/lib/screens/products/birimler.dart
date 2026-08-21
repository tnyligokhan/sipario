// ÜRÜN BİRİMLERİ — sabit liste (TEK KAYNAK) + form alanının açılır menüsü.
//
// NEDEN AYRI DOSYA: birim yalnız ürün formunun derdi değil — sipariş satırı (`order_lines.unit`)
// aynı sözcükleri yazar. İki ayrı liste zamanla ayrışır ve bayi ürün kartında "Koli" derken
// sipariş satırında "koli/kutu" görür. Liste burada durur; iki ekran da buradan okur.
//
// SAKLANAN DEĞER KÜÇÜK HARFTİR ('adet', 'kg'…): sahadaki veri bugün böyle — `products.unit`
// varsayılanı `'adet'` (tables.dart:106) ve `LineInput.unit` belgesi "adet"/"koli"/"kg" diyor.
// Ekranda görünen etiket ("Adet") yalnız GÖSTERİMDİR; veriye dokunmaz.
//
// ⚠️ VERİ KAYBI YASAĞI (bu dosyanın asıl varlık nedeni): birim bugüne kadar SERBEST METİNDİ ve
// sahadaki ürünler listede olmayan değerler taşıyor ("damacana", "şişe", "büyük boy"). Menüye
// geçmek, o değerleri sessizce "adet"e düşüren bir dönüşüm DEĞİLDİR: listede olmayan mevcut
// değer menüde kendi metniyle SEÇİLİ görünür ve kullanıcı başka bir şey seçmedikçe kayıtta
// aynen kalır. Bu yüzden hiçbir yerde "listede yoksa varsayılana düş" dalı yoktur.

import 'package:flutter/material.dart';

import '../../theme/components/dokunma.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/order_sheets.dart' show SecimSatiri;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Liste — tek kaynak
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Menüdeki tek seçenek: kayda yazılan [deger] ve ekranda okunan [etiket].
class BirimSecenegi {
  const BirimSecenegi(this.deger, this.etiket);

  /// `products.unit` / `order_lines.unit` kolonuna yazılan değer (küçük harf).
  final String deger;

  /// Menüde ve alanda görünen Türkçe yazım.
  final String etiket;
}

/// Kullanıcının seçtiği liste (2026-08-11 kararı). Sıra ekrandaki sıradır — en sık kullanılan
/// başta. Listeye ekleme/çıkarma YALNIZ burada yapılır.
const List<BirimSecenegi> kBirimler = [
  BirimSecenegi('adet', 'Adet'),
  BirimSecenegi('kg', 'Kg'),
  BirimSecenegi('gram', 'Gram'),
  BirimSecenegi('litre', 'Litre'),
  BirimSecenegi('paket', 'Paket'),
  BirimSecenegi('koli', 'Koli'),
  BirimSecenegi('metre', 'Metre'),
  BirimSecenegi('kutu', 'Kutu'),
];

/// Yeni ürünün birimi — bugünkü davranışın aynısı (`ProductRepository.create` varsayılanı).
const String kVarsayilanBirim = 'adet';

/// "Diğer…" satırının etiketi. Seçilince serbest metin girişi açılır — listenin dışında kalan
/// birimler (damacana, şişe, teneke) bu kapıdan girer; liste onların yerine geçmez.
const String kBirimDigerEtiketi = 'Diğer';

/// Türkçe duyarlı küçültme — 'I' → 'ı', 'İ' → 'i'. Dart'ın `toLowerCase`i yerelden bağımsızdır
/// ve 'İ' için birleşik nokta üretir; sahadan 'LİTRE' gelirse eşleşme sessizce kaçardı.
String _kucult(String s) =>
    s.trim().replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

/// Saklanan değerin liste karşılığı; listede yoksa `null` (uydurma eşleşme YOK).
/// Karşılaştırma büyük/küçük harf duyarsızdır: 'Adet' de 'ADET' de listedeki satırı seçili yapar,
/// ama kayıttaki metin bu yüzden DEĞİŞMEZ — yalnız hangi satırın işaretleneceğini belirler.
BirimSecenegi? birimBul(String? saklanan) {
  if (saklanan == null) return null;
  final k = _kucult(saklanan);
  for (final b in kBirimler) {
    if (_kucult(b.deger) == k) return b;
  }
  return null;
}

/// Alanda/menüde görünecek metin. Listedekiler kanonik etiketiyle, listede olmayanlar KENDİ
/// metniyle yazılır — bayi kartında "damacana" yazıyorsa ekranda da onu görmelidir.
String birimGosterimi(String? saklanan) {
  final s = (saklanan ?? '').trim();
  if (s.isEmpty) return birimBul(kVarsayilanBirim)!.etiket;
  return birimBul(s)?.etiket ?? s;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Form alanı
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Birim alanı — dokununca menü açan, `.s-input` görünümlü seçim kutusu.
///
/// Metin alanı gibi çizilir (46 yükseklik, surface-2 zemin, br2) ama yazılamaz: burada yeni bir
/// görsel dil yok, var olanın seçilebilir hâli var.
class BirimAlani extends StatelessWidget {
  const BirimAlani({
    super.key,
    required this.deger,
    required this.onSec,
    this.onDiger,
  });

  /// KAYITTAKİ değer (listede olmayabilir).
  final String deger;

  /// Menüden bir birim seçildi — saklanacak değer (küçük harf) verilir.
  final ValueChanged<String> onSec;

  /// "Diğer…" seçildi — çağıran serbest metin girişini açar. null ise satır çizilmez.
  final VoidCallback? onDiger;

  Future<void> _ac(BuildContext context) async {
    final mevcut = deger.trim();
    final listede = birimBul(mevcut) != null;
    final secim = await sipSheet<String>(
      context,
      baslik: 'Birim',
      govde: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LİSTEDE OLMAYAN MEVCUT DEĞER EN ÜSTTE VE SEÇİLİ: menü onu göstermeseydi bayi
          // "birimim kayboldu" derdi ve kaydeder kaydetmez gerçekten kaybolurdu.
          if (!listede && mevcut.isNotEmpty)
            SecimSatiri(
              etiket: mevcut,
              ikon: SipIcons.box,
              secili: true,
              onTap: () => Navigator.of(ctx).pop(mevcut),
            ),
          for (final b in kBirimler)
            SecimSatiri(
              etiket: b.etiket,
              secili: listede && birimBul(mevcut)!.deger == b.deger,
              onTap: () => Navigator.of(ctx).pop(b.deger),
            ),
          if (onDiger != null)
            SecimSatiri(
              etiket: kBirimDigerEtiketi,
              ikon: SipIcons.edit,
              secili: false,
              onTap: () => Navigator.of(ctx).pop(_digerAnahtari),
            ),
        ],
      ),
    );
    if (secim == null) return;
    if (secim == _digerAnahtari) {
      onDiger?.call();
      return;
    }
    onSec(secim);
  }

  /// Menüden dönen "serbest metin istiyorum" işareti. Gerçek bir birim değeriyle ÇAKIŞMAZ.
  static const String _digerAnahtari = '__diger__';

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      label: 'Birim',
      child: SipDokun(
        onTap: () => _ac(context),
        zemin: t.surface2,
        basiliZemin: t.line,
        radius: SipRadius.br2,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2),
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  birimGosterimi(deger),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SipText.input.copyWith(color: t.ink),
                ),
              ),
              const SizedBox(width: SipSpace.sm),
              SipIcon(SipIcons.down, boyut: 16, kalinlik: 2.2, renk: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}
