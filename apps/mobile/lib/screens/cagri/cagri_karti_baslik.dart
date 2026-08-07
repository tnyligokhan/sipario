// Çağrı kartının ÜST YARISI — CSS `.cagri-top` + `.cagri-kim` (Sipario.html).
// İskelet `cagri_karti.dart`'tadır; bu dosya 500 satır sınırı için ayrıldı.
//
// Parçalar `_` ile gizlenmiyor: aynı özelliğin üç dosyası birbirini görebilsin diye
// kütüphane-açık adlandırıldılar. Dışarıdan kullanılmaları beklenmez.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'cagri_model.dart';

/// CSS `.cagri-top` — nabızlı nokta + yön etiketi + süre + kapat düğmesi.
///
/// ETİKET [yon]'DEN GELİR: burada "GELEN ÇAĞRI" sabit yazıyordu ve kart giden çağrıda da
/// gelen çağrı gösteriyordu (2026-07-27 saha bulgusu). Cevapsızda vurgu `danger`a döner ve
/// nokta nabız atmaz — çağrı artık canlı değildir.
class CagriUstSerit extends StatelessWidget {
  const CagriUstSerit({
    super.key,
    this.yon = AramaTipi.gelen,
    this.baslangic,
    this.onKapat,
  });

  final AramaTipi yon;
  final DateTime? baslangic;
  final VoidCallback? onKapat;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final vurgu = yon == AramaTipi.cevapsiz ? t.danger : t.accent;
    return Row(
      children: [
        CagriCanliNokta(renk: vurgu, nabiz: yon != AramaTipi.cevapsiz),
        const SizedBox(width: 7),
        // Yön etiketi ESNEK DEĞİL: dar alanda kısalmaz, kırpılmaz. Kartın en üst satırıdır ve
        // "CEVAPSIZ" yerine "CEVAP…" yazması madde 1'in kazanımını geri alırdı.
        Text(
          cagriYonEtiketi(yon),
          style: SipText.cagriCanli.copyWith(color: vurgu),
        ),
        // CSS `.cagri-since { margin-left: auto }` — süre sağa yaslanır ve kalan alanı alır.
        //
        // ESNEYEN PARÇA BURASIDIR (2026-07-27): üst şerit dar kartta taşıyordu (testte 252px'te
        // 31px). Şeritteki her şey sabit genişlikteydi, yani sıkışacak bir eleman yoktu. Süre
        // ("şimdi") tasarımda SABİT bir dekorasyondur — bilgi taşımaz, ilk o feda edilir.
        // `Clip.hardEdge`: yer kalmadığında sessizce kırpılır, kırmızı taşma şeridi çizilmez.
        Expanded(
          // `ConstraintsTransformBox`: iç satır genişlik kısıtı KALDIRILARAK ölçülür (yani asla
          // "taştım" demez), sonra kalan alana kırpılır. `Flex`in kendi `clipBehavior`ı
          // yetmiyordu — boyamayı kırpıyor ama taşma hatasını yine de atıyor; `OverflowBox` ise
          // sınırsız yükseklikte kendi boyunu sonsuz yapıyor. Bu widget tam bu iş için var.
          //
          // Sağa yaslı hizalama sayesinde önce SAAT İKONU kaybolur, sözcük en son gider:
          // ikon dekorasyon, "şimdi" bilgidir.
          child: ConstraintsTransformBox(
            constraintsTransform: ConstraintsTransformBox.maxWidthUnconstrained,
            alignment: Alignment.centerRight,
            clipBehavior: Clip.hardEdge,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SipIcon(SipIcons.clock, boyut: 12, kalinlik: 2, renk: t.muted),
                const SizedBox(width: SipSpace.xs),
                CagriSure(baslangic: baslangic),
              ],
            ),
          ),
        ),
        const SizedBox(width: SipSpace.lg),
        // CSS `.sheet-x`
        SipDokun(
          onTap: onKapat,
          zemin: t.surface2,
          basiliZemin: t.line2,
          radius: SipRadius.brHap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: SipIcon(SipIcons.x, boyut: 20, kalinlik: 2.2, renk: t.muted),
            ),
          ),
        ),
      ],
    );
  }
}

/// CSS `.cagri-live i` — accent nokta, `puls` animasyonuyla genişleyen halka.
/// Cevapsız çağrıda [nabiz] kapanır: biten bir çağrı "canlı" değildir.
class CagriCanliNokta extends StatefulWidget {
  const CagriCanliNokta({super.key, this.renk, this.nabiz = true});

  /// Verilmezse tema vurgusu (accent). Cevapsızda `danger` geçilir.
  final Color? renk;
  final bool nabiz;

  @override
  State<CagriCanliNokta> createState() => _CagriCanliNoktaState();
}

class _CagriCanliNoktaState extends State<CagriCanliNokta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    // Nabız YOKSA denetleyici hiç başlatılmaz: sonsuz animasyon `pumpAndSettle`'ı kilitler ve
    // cevapsız kartını gösteren testlerin ağacı oturur.
    if (widget.nabiz) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renk = widget.renk ?? context.sip.accent;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // CSS: box-shadow 0 0 0 4px → 0 0 0 7px, opaklık %15 → %4
        final hale = 4 + 3 * _c.value;
        return SizedBox(
          width: 8 + 2 * 7,
          height: 8 + 2 * 7,
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: renk,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: renk.withValues(alpha: 0.15 - 0.11 * _c.value),
                    spreadRadius: hale,
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

/// CSS `.cagri-since` — [baslangic] verilmezse tasarımdaki sabit "şimdi".
class CagriSure extends StatefulWidget {
  const CagriSure({super.key, this.baslangic});

  final DateTime? baslangic;

  @override
  State<CagriSure> createState() => _CagriSureState();
}

class _CagriSureState extends State<CagriSure> {
  late final Stream<void> _tik = widget.baslangic == null
      ? const Stream<void>.empty()
      : Stream<void>.periodic(const Duration(seconds: 1));

  String _metin() {
    final b = widget.baslangic;
    if (b == null) return 'şimdi';
    final gecen = DateTime.now().difference(b);
    if (gecen.inSeconds < 1) return 'şimdi';
    final dk = gecen.inMinutes.toString().padLeft(2, '0');
    final sn = (gecen.inSeconds % 60).toString().padLeft(2, '0');
    return '$dk:$sn';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<void>(
      stream: _tik,
      builder: (context, _) => Text(
        _metin(),
        style: SipText.yardimci.copyWith(
          color: t.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// CSS `.cagri-kim` — ad/numara + bakiye rozeti.
///
/// AVATAR YOK: tasarımın `.cagri-kim`i (s-cagri.jsx:23-31, 53-59) yalnız `.cagri-kim-mid` ile
/// rozeti çiziyor; `.cagri-av` CSS'te kalmış ölü bir sınıf.
class CagriKimSatiri extends StatelessWidget {
  const CagriKimSatiri({super.key, required this.kisi});

  final CagriKisi kisi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.x3),
      child: Row(
        children: [
          Expanded(child: _KimOrta(kisi: kisi)),
          const SizedBox(width: SipSpace.xl), // CSS `.cagri-kim { gap: 12px }`
          _BakiyePili(kisi: kisi),
        ],
      ),
    );
  }
}

/// CSS `.cagri-kim-mid` — ad/numara ikilisi. Kayıtsızda numara baskın, altında açıklama.
class _KimOrta extends StatelessWidget {
  const _KimOrta({required this.kisi});

  final CagriKisi kisi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final kayitli = kisi.kayitli;
    final numara = sipTelefon(kisi.numara);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kayitli ? (kisi.ad ?? '') : numara,
          style: SipText.cagriAd.copyWith(color: t.ink),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        if (kayitli)
          Row(
            children: [
              // CSS `.srow-kod` — müşteri kodu rozeti.
              if (kisi.musteriKodu != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    kisi.musteriKodu!,
                    style: SipText.siparisKod.copyWith(color: t.accent),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  numara,
                  style: SipText.cagriNumara.copyWith(color: t.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        else
          Text(
            'Bu numara defterinizde yok',
            style: SipText.cagriNumara.copyWith(color: t.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// CSS `.cagri-kim .pill` — bakiye durumu rozeti (Borç / Alacak / Temiz / Kayıtsız).
class _BakiyePili extends StatelessWidget {
  const _BakiyePili({required this.kisi});

  final CagriKisi kisi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    if (!kisi.kayitli) {
      return SipPil(etiket: 'Kayıtsız', renk: t.ink2, zemin: t.surface2);
    }
    final kurus = kisi.bakiyeKurus;
    // Temiz müşteride tasarım nötr değil YEŞİL rozet gösterir (s-cagri.jsx).
    if (kurus == 0) {
      return SipPil(etiket: 'Temiz', renk: t.ok, zemin: t.okSoft);
    }
    return SipPil(
      etiket: SipTokens.bakiyeEtiket(kurus),
      renk: t.bakiyeRenk(kurus),
      zemin: t.bakiyeSoft(kurus),
    );
  }
}
