// ÇEKMECENİN SATIR ATOMLARI — bölüm etiketi · ayraç · hedef satırı · alt çubuk · metin eylemi.
//
// NEDEN AYRI DOSYA: `cekmece.dart` 541 satıra çıkmıştı (500 satır kuralı). Çekmece 2026-08-13'te
// zaten bir kez bölünmüştü (`cekmece_parcalari.dart` — DURUM ve KONTROL parçaları); bu dosya
// üçüncü bölgeyi alır: satırın KENDİSİNİ çizen atomlar. Ayrım şu soruyla yapıldı: "bu widget
// çekmecenin İÇERİĞİNİ bilir mi?" — buradakiler bilmez, etiketi ve ikonu verilir, dokunuşu
// yukarı bildirir. Hangi satırın hangi yetkiyle çizileceği kararı `cekmece.dart`ta kaldı.

part of 'cekmece.dart';

/// CSS `.cek-sec` — bölüm etiketi (BÜYÜK HARF). Yalnız YÖNETİM için kullanılır.
class _Bolum extends StatelessWidget {
  const _Bolum(this.etiket);

  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SipSpace.lg, SipSpace.x3, SipSpace.lg, 7),
      child: Text(
        trBuyuk(etiket),
        style: SipText.cekmeceBolum.copyWith(color: SipTokens.onHeroSoft),
      ),
    );
  }
}

/// Hedef öbekleri arasındaki sessiz ayraç — etiket yerine çizgi.
class _Ayrac extends StatelessWidget {
  const _Ayrac();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: SipSpace.lg, vertical: SipSpace.lg),
        child: Divider(height: 1, thickness: 1, color: SipTokens.onHeroLine),
      );
}

/// CSS `.cekr` — hedef satırı. Sağda chevron; [sayac] verilirse chevron'un solunda rozet.
///
/// HER SATIR BİR ROTA AÇAR. `secili` (accent dolgulu aktif hâl) parametresi kaldırıldı: o,
/// alt barı tekrarlayan sekme satırları içindi ve onlar 2026-08-13'te kaldırıldı. Rotalar
/// "seçili" olmaz; kullanılmayan bir görsel hâli bırakmak sonraki okuyucuya var olmayan bir
/// davranış vaat ederdi.
class _Satir extends StatelessWidget {
  const _Satir({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.sayac,
  });

  final String ikon;
  final String etiket;
  final VoidCallback onTap;

  /// Rozet sayısı; null ya da 0 ise rozet çizilmez (sıfır bir haber değildir).
  final int? sayac;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final n = sayac ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SipDokun(
        onTap: onTap,
        zemin: Colors.transparent,
        basiliZemin: SipTokens.onHeroFill,
        radius: BorderRadius.circular(13),
        padding: const EdgeInsets.all(SipSpace.xl),
        child: Row(
          children: [
            SipIcon(ikon, boyut: 19, kalinlik: 1.9, renk: SipTokens.onHeroMid),
            const SizedBox(width: SipSpace.xl),
            Expanded(
              child: Text(
                etiket,
                style: SipText.cekmeceSatir.copyWith(color: SipTokens.onHeroStrong),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (n > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: SipRadius.brHap,
                ),
                child: Text(
                  '$n',
                  style: SipText.tutar(11.5, w: 800).copyWith(color: t.accentInk),
                ),
              ),
              const SizedBox(width: SipSpace.md),
            ],
            const SipIcon(SipIcons.chevR,
                boyut: 16, kalinlik: 2, renk: SipTokens.onHeroFaint),
          ],
        ),
      ),
    );
  }
}

/// CSS `.cek-alt` — başparmak bölgesi: sık çevrilen anahtarlar + destek.
///
/// ÜÇ ŞEY BURADAN ÇIKTI ve hepsi kullanıcı geri bildirimiyle (2026-08-13):
///  • Çıkış BAŞLIĞA taşındı (eski "×" düğmesinin yerine). Ayakta, tam boy accent "Destek
///    Hattı" düğmesinin yanında kırmızı zeminli ETİKETSİZ bir güç simgesiydi; çekmecenin en
///    erişilebilir köşesini en nadir ve geri alınamaz eylem işgal ediyordu.
///  • Destek artık tam boy accent bir düğme DEĞİL: menünün en yüksek sesli öğesi, en seyrek
///    kullanılan eylemdi. Sessiz bir satır olarak duruyor.
///  • Anahtarlar tek satıra indi (bkz. `CekmeceAnahtarKutusu`).
class _AltCubuk extends StatelessWidget {
  const _AltCubuk({required this.cekmece});

  final SipCekmece cekmece;

  @override
  Widget build(BuildContext context) {
    final c = cekmece;
    return Container(
      padding: EdgeInsets.fromLTRB(
        SipSpace.x2,
        SipSpace.lg,
        SipSpace.x2,
        SipSpace.lg + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SipTokens.onHeroLine)),
      ),
      child: Column(
        children: [
          CekmeceAnahtarlari(koyuTema: c.koyuTema, onTema: c.onTema),
          const SizedBox(height: 6),
          _MetinEylem(
            ikon: SipIcons.chat,
            etiket: 'Sipario Destek Hattı',
            onTap: c.onDestek,
          ),
        ],
      ),
    );
  }
}

class _MetinEylem extends StatelessWidget {
  const _MetinEylem({required this.ikon, required this.etiket, required this.onTap});

  final String ikon;
  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SipDokun(
      onTap: onTap,
      zemin: Colors.transparent,
      basiliZemin: SipTokens.onHeroFill,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SipIcon(ikon, boyut: 15, kalinlik: 2, renk: SipTokens.onHeroMid),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              etiket,
              style: SipText.metin(12, w: 600).copyWith(color: SipTokens.onHeroStrong),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
