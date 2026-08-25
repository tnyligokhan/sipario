// POS KARO ve EYLEM ŞERİDİ — kataloğun tek bir ürün karosu.
//
// NEDEN AYRI DOSYA: `pos_catalog.dart` 629 satıra çıkmıştı (depo sınırı 500). Ayrım KONUYA
// göre: katalog ÜRÜN LİSTELER (ızgara · arama · barkod · sepet sayacı), burası TEK BİR ÜRÜNÜ
// çizer ve onun adet/ekleme yüzeyini taşır.
//
// NEDEN `part` (ayrı kütüphane değil): karo ve şerit sınıflarının hepsi PRIVATE kalmalı —
// kataloğun karosu başka bir ekranın kullanacağı bir bileşen değildir; dışarıya sızması, aynı
// karonun sepet sayacı olmadan çizildiği ikinci bir yüzey açardı. `part` aynı kütüphanede
// kalmayı ve `_` gizliliğini korur; çağrı yerleri DEĞİŞMEZ. Aynı desen: `pos_adet_sheet.dart`.

part of 'pos_catalog.dart';

/// CSS `.pos-tile` — görsel/baş harf, ad (2 satır), fiyat + birim, EYLEM ŞERİDİ.
///
/// ══ EYLEM ŞERİDİ (kullanıcı isteği 2026-08-22) ═════════════════════════════════════════════
/// Eskiden karoya dokunmak HER ZAMAN bir adet sheet'i açıyordu: bayi ürünü seçiyor, sheet'i
/// bekliyor, adedi giriyor, "Sepete Ekle"ye basıyordu — su bayisinde, yani ürünlerinin
/// hiçbirinin malzemesi olmayan bir işletmede, tek bir damacana için üç fazladan dokunuş.
///
/// Şerit İKİ HÂLLİDİR ve bu, dar karonun (360 dp telefonda ≈ 103 px) tek çözümüydü:
///   adet = 0 → tek parça "Ekle" düğmesi, şeridin TAMAMI dokunma alanı
///   adet > 0 → `[−] adet [+]` — üç düğme de ~30 px, parmakla ayırt edilebilir
/// Üçünü baştan yan yana koymak her birini ~20 px'e düşürürdü; kurye direksiyonda, esnaf
/// tezgâhtadır ve 20 px'lik hedefe basamaz.
///
/// SEÇENEKLİ ÜRÜNDE ŞERİT YİNE SHEET AÇAR ve bu bilinçli: "soğansız olsun" karoya sığmaz,
/// müşteri tercihi de orada okunup yazılır. Şerit o ürünlerde adet göstermez, yalnız kaç
/// tanesinin sepete gittiğini söyler — adet, seçime bağlıdır ve tek bir sayıyla anlatılamaz.
class _PosKarosu extends StatelessWidget {
  const _PosKarosu({
    required this.urun,
    required this.onTap,
    this.adet = 0,
    this.secenekli = false,
    this.onAzalt,
  });

  final Product urun;
  final VoidCallback onTap;

  /// Bu katalog oturumunda karodan sepete gönderilen adet. 0 = henüz eklenmedi.
  final int adet;

  /// Ürünün malzeme seçeneği var mı (varsa şerit sheet açar, adet düşürülemez).
  final bool secenekli;

  final VoidCallback? onAzalt;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface2,
      basiliZemin: t.line,
      radius: const BorderRadius.all(Radius.circular(16)),
      olcekle: true,
      // Üç sütunda dolgu 8 → 6: kaybedilen her piksel doğrudan görselden ve ad satırından
      // çıkıyordu. Alt dolgu (9) üsttekinden büyük kalır — fiyat satırı kenara yapışmasın.
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // GÖRSEL ORANI 5/4 → 8/5: eylem şeridi karoya 30 px ekledi ve o pikselin bir yerden
          // gelmesi gerekiyordu. Görselden almak ad satırından almaktan iyidir — bayi ürünü
          // adıyla arar, görsel yalnız tanımayı hızlandırır.
          UrunGorseli(urun: urun, en: double.infinity, oran: 8 / 5, radius: 10, puntoBoyut: 18),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                urun.name,
                style: SipText.metin(12, w: 700, h: 1.3).copyWith(color: t.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    sipTutar(urun.unitPriceKurus),
                    style: SipText.tutar(12.5).copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 3),
                // BİRİM DARALTILABİLİR: dar telefonda "1.250,00 ₺" + "/ porsiyon" yan yana
                // sığmaz. Kırpılacaksa BİRİM kırpılır, fiyat değil — bayi fiyatı okuyamazsa
                // karo işini yapmıyor demektir.
                Flexible(
                  child: Text(
                    '/ ${urun.unit}',
                    style: SipText.metin(9.5, w: 500).copyWith(color: t.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          _EylemSeridi(
            adet: adet,
            secenekli: secenekli,
            urunAdi: urun.name,
            onArtir: onTap,
            onAzalt: onAzalt,
          ),
        ],
      ),
    );
  }
}

/// Karonun alt şeridi — "Ekle" ya da `[−] adet [+]`.
///
/// SABİT YÜKSEKLİK (30): karo yüksekliği `childAspectRatio` ile hesaplanıyor ve şeridin hâli
/// değiştikçe (Ekle → stepper) karonun boyu oynarsa ızgara her eklemede zıplar.
class _EylemSeridi extends StatelessWidget {
  const _EylemSeridi({
    required this.adet,
    required this.secenekli,
    required this.urunAdi,
    required this.onArtir,
    this.onAzalt,
  });

  final int adet;
  final bool secenekli;
  final String urunAdi;
  final VoidCallback onArtir;
  final VoidCallback? onAzalt;

  static const double _yukseklik = 30;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;

    // SEÇENEKLİ ÜRÜN: adet karodan değiştirilemez (adet seçime bağlıdır), şerit yalnız kaç
    // tanesinin sepete gittiğini söyler ve dokunuş yine sheet açar.
    if (secenekli) {
      return _Sekme(
        yukseklik: _yukseklik,
        zemin: adet > 0 ? t.okSoft : t.accentSoft,
        onTap: onArtir,
        etiketi: adet > 0 ? '$adet eklendi' : 'Ekle',
        ikon: adet > 0 ? SipIcons.check : SipIcons.plus,
        renk: adet > 0 ? t.ok : t.accent,
        semantik: '$urunAdi seçeneklerini aç',
      );
    }

    if (adet == 0) {
      return _Sekme(
        yukseklik: _yukseklik,
        zemin: t.accentSoft,
        onTap: onArtir,
        etiketi: 'Ekle',
        ikon: SipIcons.plus,
        renk: t.accent,
        semantik: '$urunAdi sepete ekle',
      );
    }

    return SizedBox(
      height: _yukseklik,
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.accentSoft, borderRadius: SipRadius.br1),
        child: Row(
          children: [
            _KaroDugmesi(
              ikon: SipIcons.down,
              renk: t.accent,
              onTap: onAzalt,
              etiket: '$urunAdi adedini azalt',
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$adet',
                  style: SipText.tutar(13.5, w: 800).copyWith(color: t.accent),
                  maxLines: 1,
                ),
              ),
            ),
            _KaroDugmesi(
              ikon: SipIcons.plus,
              renk: t.accent,
              onTap: onArtir,
              etiket: '$urunAdi adedini artır',
            ),
          ],
        ),
      ),
    );
  }
}

/// Şeridin tek parça hâli (ikon + kısa etiket).
class _Sekme extends StatelessWidget {
  const _Sekme({
    required this.yukseklik,
    required this.zemin,
    required this.onTap,
    required this.etiketi,
    required this.ikon,
    required this.renk,
    required this.semantik,
  });

  final double yukseklik;
  final Color zemin;
  final VoidCallback onTap;
  final String etiketi;
  final String ikon;
  final Color renk;
  final String semantik;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantik,
      child: SipDokun(
        onTap: onTap,
        zemin: zemin,
        basiliZemin: zemin,
        radius: SipRadius.br1,
        child: SizedBox(
          height: yukseklik,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SipIcon(ikon, boyut: 14, kalinlik: 2.6, renk: renk),
              const SizedBox(width: 4),
              // DARALTILABİLİR: "12 eklendi" en dar telefonda ikonla birlikte sınırda kalır.
              Flexible(
                child: Text(
                  etiketi,
                  style: SipText.metin(11, w: 800).copyWith(color: renk),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Şeritteki tek dokunma hedefi (− / +). Genişlik 30: en dar telefonda bile parmakla ayrışır.
class _KaroDugmesi extends StatelessWidget {
  const _KaroDugmesi({
    required this.ikon,
    required this.renk,
    required this.onTap,
    required this.etiket,
  });

  final String ikon;
  final Color renk;
  final VoidCallback? onTap;
  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiket,
      child: SipDokun(
        onTap: onTap,
        radius: SipRadius.br1,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(child: SipIcon(ikon, boyut: 15, kalinlik: 2.8, renk: renk)),
        ),
      ),
    );
  }
}
