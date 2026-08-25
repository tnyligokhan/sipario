// BARKOD OKUYUCU — kamera. Tasarım `.bk-cam` kutusunun içi artık canlı görüntüdür.
//
// TEK YÜZEY, İKİ ÇAĞIRAN: ürün formu (okunan kod barkod alanına yazılır) ve POS kataloğu
// (okunan kod arama alanına yazılır, ızgara o ürüne iner). İkisi de aynı sözleşmeyi kullanır:
// düğmeye dokunuldu → kamera açıldı → kod okundu → sayfa kapandı ve kod DÖNDÜ. Arada elle
// doldurulacak ikinci bir alan YOKTUR (kullanıcı kararı, 2026-07-26).
//
// KAMERA YOKSA/İZİN VERİLMEZSE alanın yerine elle giriş çıkar. Bu mutlu yola bir adım
// EKLEMEZ — yalnız kameranın çalışmadığı durumda bir yetenek kaybını önler; eski davranış
// (elle yazma) o zaman da erişilebilir kalır.
//
// Çevrimdışı: `mobile_scanner` ML Kit'in PAKETE GÖMÜLÜ barkod modelini kullanır, çalışma
// anında indirme yapmaz — depoda internet olmayabilir.
//
// FENER: görüntünün sağ üstünde AÇ/KAPA düğmesi (2026-07-31 saha isteği). Işık `mobile_scanner`
// kontrolcüsünün KENDİ torch API'sinden gelir — yeni paket eklenmedi.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Ürün barkodu olarak KABUL EDİLEBİLİR mi? Kayıt yalnız RAKAM tutar (bkz. `urunBarkodu`)
/// ve form en az 8 hane ister; okuyucu da aynı kuralı uygular.
///
/// Harf içeren kodlar (Code 128 ile basılmış parti/raf etiketleri) rakamları AYIKLANARAK
/// kabul EDİLMEZ — "AB12345678"den "12345678" üretmek, hiç okumamaktan daha kötüdür:
/// yanlış ürüne bağlanmış bir barkod sessizce yanlış fiyat keser.
String? barkodKabulEt(String? ham) {
  final kod = ham?.trim();
  if (kod == null || kod.isEmpty) return null;
  return RegExp(r'^\d{8,}$').hasMatch(kod) ? kod : null;
}

/// Kamerayı açar; okunan barkodu döndürür, vazgeçilirse null.
Future<String?> barkodKameraAc(BuildContext context) => sipSheet<String>(
      context,
      baslik: 'Barkod Okut',
      tam: true,
      govde: (ctx) => const _KameraGovde(),
    );

class _KameraGovde extends StatefulWidget {
  const _KameraGovde();

  @override
  State<_KameraGovde> createState() => _KameraGovdeState();
}

class _KameraGovdeState extends State<_KameraGovde> {
  /// Ürün barkodlarının biçimleri. Daraltmak hem hızlandırır hem de kargo etiketi /
  /// QR gibi ürünle ilgisi olmayan kodların yanlışlıkla alana yazılmasını engeller.
  final _kontrol = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
  );

  /// Kod bir kez döndürülür; kamera aynı kareden birkaç kez tetikleyebilir.
  bool _dondu = false;
  String? _uyari;

  /// Fener çalıştırılamadığında söylenen tek cümle. SESSİZ KALINMAZ: dokunulan ama hiçbir şey
  /// yapmayan bir düğme kullanıcıya "uygulama bozuk" dedirtir (okunamayan kod uyarısıyla aynı
  /// gerekçe).
  static const String _fenerYokMesaji = 'Bu telefonda fener kullanılamıyor';

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  void _okundu(BarcodeCapture yakalama) {
    if (_dondu) return;
    for (final b in yakalama.barcodes) {
      final kod = barkodKabulEt(b.rawValue);
      if (kod == null) continue;
      _dondu = true;
      Navigator.of(context).pop(kod);
      return;
    }
    // Okundu ama ürün barkodu değil: sessiz kalmak "kamera bozuk" hissi verir.
    if (mounted) {
      setState(() => _uyari = 'Okunan kod ürün barkodu değil (en az 8 hane rakam)');
    }
  }

  /// Feneri açar/kapatır (2026-07-31 saha isteği: "barkod okuma ekranına ışık düğmesi").
  /// Depo rafı, kasa altı ve akşam servisi — barkodun okunduğu yerlerin çoğu loştur.
  ///
  /// ÇAĞRI TRY İÇİNDE: `toggleTorch` platform kanalına uzanır ve kamera henüz hazır değilken
  /// (ya da eklentinin bulunmadığı widget testi/masaüstünde) fırlatır. Bu depoda try'ın DIŞINDA
  /// kalan tek bir kanal çağrısı dosyanın TÜM testlerini düşürüyor — kanıtlı tuzak. Fener bir
  /// KOLAYLIKTIR: çalışmasa da barkod okunmaya devam eder.
  Future<void> _feneriDegistir() async {
    try {
      await _kontrol.toggleTorch();
    } on Object {
      if (mounted) setState(() => _uyari = _fenerYokMesaji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CSS `.bk-cam` kutusunun yerinde canlı görüntü. Sabit yükseklik: sheet gövdesi
        // kaydırılabilir, sınırsız yükseklik veren bir kamera orada çizilemez.
        ClipRRect(
          borderRadius: SipRadius.br2,
          child: SizedBox(
            height: 300,
            child: MobileScanner(
              controller: _kontrol,
              onDetect: _okundu,
              // Kamera yoksa/izin verilmediyse yetenek kaybolmasın: elle giriş.
              errorBuilder: (ctx, hata) => _ElleGiris(hata: hata),
              placeholderBuilder: (ctx) => ColoredBox(
                color: t.surface2,
                child: Center(
                  child: SipIcon(SipIcons.barkod, boyut: 34, kalinlik: 1.5, renk: t.muted),
                ),
              ),
              // Kaplama YALNIZ canlı görüntü varken çizilir (bu builder kamera açılamadığında
              // hiç çağrılmaz) — elle girişin üstüne fener düğmesi düşmez.
              overlayBuilder: (ctx, kisit) => _KameraKaplama(
                kontrol: _kontrol,
                onFener: _feneriDegistir,
              ),
            ),
          ),
        ),
        const SizedBox(height: SipSpace.x3),
        Text(
          _uyari ?? 'Barkodu çerçeveye getirin. Okunduğunda alana kendiliğinden yazılır.',
          textAlign: TextAlign.center,
          style: SipText.metin(12.5, w: 500)
              .copyWith(color: _uyari == null ? t.muted : t.warn),
        ),
      ],
    );
  }
}

/// Canlı görüntünün üstündeki kaplama: nişan çizgisi + sağ üstte fener düğmesi.
class _KameraKaplama extends StatelessWidget {
  const _KameraKaplama({required this.kontrol, required this.onFener});

  final MobileScannerController kontrol;
  final VoidCallback onFener;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _NisanCizgisi(),
        Positioned(
          top: SipSpace.md,
          right: SipSpace.md,
          // Fener durumu KONTROLCÜDEN okunur, ekranda ayrı bir bayrak tutulmaz: ışığı sistem de
          // (pil koruması, kamera duraklatma) kapatabilir ve iki kaynak ayrışırsa düğme yalan
          // söylerdi.
          child: ValueListenableBuilder(
            valueListenable: kontrol,
            builder: (ctx, durum, _) => BarkodFenerDugmesi(
              acik: durum.torchState == TorchState.on,
              kullanilabilir: durum.torchState != TorchState.unavailable,
              onTap: onFener,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lucide `flashlight` (24×24). `SipIcons`a EKLENEMEDİ: `theme/icons.dart` bu ajanın dosyası
/// değil (`kMikrofonIkonu` ile aynı gerekçe). Tema sahibi ekleyebildiğinde buradan silinip
/// `SipIcons.fener` kullanılmalı — path birebir aynı.
const String kFenerIkonu =
    'M18 6c0 2-2 2-2 4v10a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2V10c0-2-2-2-2-4V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2z'
    '|M6 6h12|M12 12h2';

/// Canlı görüntünün üstündeki fener düğmesi.
///
/// DURUM GÖRÜNÜR OLMAK ZORUNDA: fener açıkken düğme accent zeminle DOLAR ve ikon beyaza döner
/// (sesli giriş mikrofonuyla aynı dil). Kapalıyken görüntünün üstünde okunabilsin diye koyu
/// perde zemin + beyaz ikon kullanılır — kameranın önündeki sahne beyaz da olabilir siyah da.
///
/// PASİF ≠ GİZLİ: fenersiz cihazda düğme soluk çizilir ama dokunulabilir kalır ve dokunuş
/// sebebini söyler (mikrofon düğmesiyle aynı desen).
class BarkodFenerDugmesi extends StatelessWidget {
  const BarkodFenerDugmesi({
    super.key,
    required this.acik,
    required this.onTap,
    this.kullanilabilir = true,
  });

  final bool acik;

  /// Cihazda fener var mı — yoksa soluk çizilir.
  final bool kullanilabilir;

  final VoidCallback onTap;

  /// DESIGN_SYSTEM dokunma hedefi alt sınırı.
  static const double cap = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      label: acik ? 'Feneri kapat' : 'Feneri aç',
      child: Opacity(
        opacity: kullanilabilir ? 1 : 0.62,
        child: SipDokun(
          onTap: onTap,
          zemin: acik ? t.accent : SipTokens.scrim,
          basiliZemin: acik ? t.accent : SipTokens.onHeroFill2,
          radius: SipRadius.brHap,
          child: SizedBox.square(
            dimension: cap,
            child: Center(
              child: SipIcon(
                kFenerIkonu,
                boyut: 20,
                // Açıkken çizgi kalınlaşır: renk körü kullanıcı da "dolu" hâli ayırt etmeli.
                kalinlik: acik ? 2.6 : 2.1,
                renk: SipTokens.onHero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ortadan geçen nişan çizgisi — kullanıcıya barkodu nereye getireceğini söyler.
class _NisanCizgisi extends StatelessWidget {
  const _NisanCizgisi();

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.72,
        child: Container(height: 2, color: t.accent),
      ),
    );
  }
}

/// Kamera açılamadığında kutunun İÇİNDE çıkan elle giriş. Mutlu yolda hiç çizilmez.
class _ElleGiris extends StatefulWidget {
  const _ElleGiris({required this.hata});

  final MobileScannerException hata;

  @override
  State<_ElleGiris> createState() => _ElleGirisState();
}

class _ElleGirisState extends State<_ElleGiris> {
  final _kod = TextEditingController();

  @override
  void dispose() {
    _kod.dispose();
    super.dispose();
  }

  void _kullan() {
    final kod = barkodKabulEt(_kod.text);
    if (kod == null) return;
    Navigator.of(context).pop(kod);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final izin =
        widget.hata.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: t.surface2,
      child: Padding(
        padding: const EdgeInsets.all(SipSpace.x3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              izin
                  ? 'Kamera izni verilmedi. Barkodu yazarak girebilirsiniz.'
                  : 'Kamera açılamadı. Barkodu yazarak girebilirsiniz.',
              textAlign: TextAlign.center,
              style: SipText.metin(12.5, w: 500).copyWith(color: t.ink2),
            ),
            const SizedBox(height: SipSpace.x3),
            SipInput(
              controller: _kod,
              ipucu: 'Barkod',
              klavye: TextInputType.number,
              girdiFiltreleri: [FilteringTextInputFormatter.digitsOnly],
              stil: SipText.tutar(15, w: 500),
              onSubmitted: (_) => _kullan(),
            ),
            const SizedBox(height: SipSpace.md),
            SipButon(etiket: 'Kullan', onTap: _kullan),
          ],
        ),
      ),
    );
  }
}
