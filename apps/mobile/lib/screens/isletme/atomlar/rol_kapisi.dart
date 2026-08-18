// Rol kapısı — CSS karşılığı yok; K2 kuralının ekran içi savunması.
// Barrel: `../isletme_atomlari.dart` (ekranlar oradan import eder).

import 'package:flutter/material.dart';

import '../../../theme/components/atoms.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

/// Kurye rolü Ürünler / Kuryeler / Muaf telefonlar ekranlarını GÖREMEZ. Çekmece bu girişleri
/// zaten gizler; bu ekranın doğrudan (derin bağlantı, geri yığını) açılmasına karşı ikinci kapı.
///
/// ⚠️ KAPIYI SARAN DÖRT EKRANDA `rol` ZORUNLU ALANDIR (2026-08-18) ve bu bilinçlidir: kapı bir
/// İZİN LİSTESİ olduğu için bilinmeyen rolde KAPANIR, `rol` geçilmeyen bir çağrı da null
/// gönderir — yani "unutmak", ekranı HERKESE kapatmak demektir. Tam olarak bu yaşandı: çekmece
/// `KuryelerEkrani`ye `rol` geçmiyordu ve PATRON kendi kuryelerini yönetemiyordu. Kapının kendi
/// testleri yeşildi, çünkü kırık olan kapı değil BAĞLANTIYDI. Alanı zorunlu yapmak o bağlantıyı
/// derleyicinin sorumluluğuna verir — yeni bir giriş noktası eklendiğinde derlenmez.
class YoneticiKapisi extends StatelessWidget {
  const YoneticiKapisi({super.key, required this.rol, required this.child, this.baslik});

  final String? rol;
  final Widget child;

  /// Kapı kapalıyken üstte gösterilecek başlık.
  final String? baslik;

  /// Kapı YALNIZ tanınan yönetici rollerine açılır — İZİN LİSTESİ, yasak listesi değil.
  ///
  /// ⚠️ ESKİDEN `rol != 'kurye'` YAZIYORDU ve bu, kapının kendi varlık sebebini deliyordu:
  /// `rol` null iken (oturum açıldı ama ilk senkron henüz inmedi) ya da sunucu ileride yeni bir
  /// rol adı gönderdiğinde kapı AÇILIYORDU. Oysa aynı soruya cevap veren `yetkiler(rol: null)`
  /// EN DAR kümeyi (kurye) veriyor — iki kural aynı soruya ters cevap veriyordu.
  ///
  /// Açık üretmesi çekmecenin de aynı `rol == 'kurye'` ölçütünü kullanmasıyla engelleniyordu,
  /// ama kapı tam olarak "ÇEKMECE ATLANDIĞINDA" (derin bağlantı, geri yığını) korumak için var;
  /// yani korumasının gerektiği tek senaryoda korumuyordu.
  ///
  /// Deponun yazılı ilkesi uygulandı (bkz. `day_end_screen.dart` — `_kapsamsizKurye`):
  /// **belirsizlikte AÇILAN değil KAPANAN taraf seçilir.** Tanınmayan/eksik rol artık kapalıdır;
  /// rol indiğinde ekran zaten yeniden çizilir.
  bool get acik => rol == 'patron' || rol == 'operator';

  @override
  Widget build(BuildContext context) {
    if (acik) return child;
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            SipUstYerine(baslik: baslik ?? 'Yetki yok'),
            const Expanded(
              child: Center(
                child: KapaliKapiMetni(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kapı kapalıyken çizilen sade başlık (ekranların `SipUst`u yerine — geri düğmesi taşır).
class SipUstYerine extends StatelessWidget {
  const SipUstYerine({super.key, required this.baslik});

  final String baslik;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SipSpace.govde, SipSpace.xl, SipSpace.govde, SipSpace.md),
      child: Row(
        children: [
          SipIkonButon(
            ikon: SipIcons.left,
            ikonBoyut: 24,
            renk: t.ink,
            etiket: 'Geri',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: SipSpace.lg),
          Expanded(
            child: Text(baslik, style: SipText.ustBaslik.copyWith(color: t.ink)),
          ),
        ],
      ),
    );
  }
}

class KapaliKapiMetni extends StatelessWidget {
  const KapaliKapiMetni({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SipIkonKutu(
            ikon: SipIcons.lock,
            cap: 66,
            ikonBoyut: 30,
            kalinlik: 1.6,
            zemin: t.surface2,
            renk: t.muted,
          ),
          const SizedBox(height: SipSpace.x3),
          Text(
            'Bu ekran yöneticilere açık',
            style: SipText.bosBaslik.copyWith(color: t.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SipSpace.sm),
          Text(
            'Kurye hesabıyla ürün, kurye ve muaf numara yönetimi görülemez.',
            style: SipText.bosAciklama.copyWith(color: t.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
