// TURUN ANLATI KARTI — ilerleme noktaları · başlık · metin · "şimdi dene" şeridi · Geri/Sonraki.
//
// `rehber_spot.dart`tan AYRILDI (500 satır kuralı). Bölme sınırı keyfi değil: orası KARARTMAYI
// ve deliği çizer (dokunuşun nereden geçeceği dahil), burası kullanıcıya NE SÖYLENDİĞİNİ
// biçimlendirir. İkisi birbirini yalnız [RehberBalon] arayüzünden tanır.

import 'package:flutter/material.dart';

import '../theme/components/atoms.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'rehber_modeli.dart';

/// Balonun ucunun hangi yöne baktığı — yukarı bakan uç, balonun ÜSTÜNDEKİ deliği gösterir.
enum RehberOk { yukari, asagi }


/// Anlatı kartı: ilerleme noktaları · başlık · metin · (dene şeridi) · Geri/Sonraki.
class RehberBalon extends StatelessWidget {
  const RehberBalon({
    super.key,
    required this.adim,
    required this.sira,
    required this.toplam,
    required this.etkilesim,
    required this.onIleri,
    required this.onGeri,
    required this.onAtla,
    required this.okYonu,
    required this.okYeri,
  });

  final RehberAdim adim;
  final int sira;
  final int toplam;
  final bool etkilesim;
  final VoidCallback onIleri;
  final VoidCallback? onGeri;
  final VoidCallback onAtla;
  final RehberOk? okYonu;

  /// Ok ucunun balonun SOL KENARINA göre yatay konumu.
  final double okYeri;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final son = sira == toplam;
    // Karta dokunmak adımı İLERLETMEZ: perdenin `onTap`i kartın altında kalıyor ve düğmeye
    // nişan alırken ıskalayan parmak turu bir adım atlatırdı.
    return GestureDetector(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (okYonu == RehberOk.yukari) _OkUcu(yon: RehberOk.yukari, yeri: okYeri),
          SipKart(
            padding: const EdgeInsets.fromLTRB(
                SipSpace.x3, SipSpace.xl, SipSpace.x3, SipSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Ilerleme(sira: sira, toplam: toplam, onAtla: onAtla),
                const SizedBox(height: SipSpace.lg),
                Text(adim.baslik, style: SipText.metin(15.5, w: 700).copyWith(color: t.ink)),
                const SizedBox(height: SipSpace.sm),
                Text(adim.metin, style: SipText.metin(13, h: 1.45).copyWith(color: t.ink2)),
                if (etkilesim) ...[
                  const SizedBox(height: SipSpace.xl),
                  _DeneSeridi(metin: adim.dene),
                ],
                const SizedBox(height: SipSpace.x3),
                Row(
                  children: [
                    if (onGeri != null)
                      SipMetinButon(etiket: 'Geri', ikon: SipIcons.left, onTap: onGeri),
                    const Spacer(),
                    // ETKİLEŞİMLİ ADIMDA "Sonraki" YERİNE "Geç" YAZAR: asıl yol hedefe
                    // dokunmaktır, düğme yalnız kaçış kapısıdır. İkisini aynı kelimeyle
                    // sunmak, kullanıcıyı denemeden geçmeye davet ederdi.
                    if (etkilesim)
                      SipMetinButon(etiket: 'Geç', onTap: onIleri)
                    else
                      SipButon(
                        etiket: son ? 'Bitti' : 'Sonraki',
                        genisle: false,
                        yukseklik: 40,
                        yatayPadding: 20,
                        onTap: onIleri,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (okYonu == RehberOk.asagi) _OkUcu(yon: RehberOk.asagi, yeri: okYeri),
        ],
      ),
    );
  }
}

/// Noktalar + sayaç + kapat. Noktalar sayacın süsü değil: kaç adım kaldığını RAKAM okumadan
/// gösterir, esnafın "daha ne kadar sürecek" sorusunun cevabı budur.
class _Ilerleme extends StatelessWidget {
  const _Ilerleme({required this.sira, required this.toplam, required this.onAtla});

  final int sira;
  final int toplam;
  final VoidCallback onAtla;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Row(
      children: [
        // Nokta sayısı SINIRLI: 12 adımlık bir turda 12 nokta satırı doldurup okunmaz hâle
        // geliyor; o durumda yalnız rakam kalır.
        if (toplam <= 8)
          Row(
            children: [
              for (var i = 0; i < toplam; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: i == sira - 1 ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < sira ? t.accent : t.line2,
                      borderRadius: SipRadius.brHap,
                    ),
                  ),
                ),
              const SizedBox(width: SipSpace.sm),
            ],
          ),
        Text(
          '$sira/$toplam',
          style: SipText.metin(11, w: 700).copyWith(color: t.muted),
        ),
        const Spacer(),
        SipMetinButon(etiket: 'Rehberi kapat', onTap: onAtla),
      ],
    );
  }
}

/// "Şimdi sen dene" çağrısı — etkileşimli adımda deliğin gerçekten dokunulabilir olduğunu
/// söyleyen tek işaret. Olmadığında kullanıcı karartmayı görüp dokunmayı denemiyor.
class _DeneSeridi extends StatelessWidget {
  const _DeneSeridi({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SipSpace.xl, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: t.accentSoft, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          SipIcon(SipIcons.hand, boyut: 17, kalinlik: 2.2, renk: t.accent),
          const SizedBox(width: SipSpace.lg),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(12.5, w: 700, h: 1.35).copyWith(color: t.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Balonu deliğe bağlayan üçgen. Balon yatayda kaydırıldığında (ekran kenarı) uç yine hedefin
/// ortasına bakar — yoksa ok kartın ortasında kalır ve yanlış yeri gösterir.
class _OkUcu extends StatelessWidget {
  const _OkUcu({required this.yon, required this.yeri});

  final RehberOk yon;

  /// Ok ucunun balonun sol kenarına göre yatay konumu (yerel piksel).
  final double yeri;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SizedBox(
      height: 8,
      child: CustomPaint(painter: _OkBoyaci(yon: yon, merkez: yeri, renk: t.surface)),
    );
  }
}

class _OkBoyaci extends CustomPainter {
  const _OkBoyaci({required this.yon, required this.merkez, required this.renk});

  final RehberOk yon;
  final double merkez;
  final Color renk;

  @override
  void paint(Canvas canvas, Size size) {
    // Uç kartın dışına taşmasın: dar ekranda hedef kartın kenarından da dışarıda kalabilir.
    final x = merkez.clamp(14.0, size.width - 14).toDouble();
    final yol = Path();
    if (yon == RehberOk.yukari) {
      yol
        ..moveTo(x - 9, size.height)
        ..lineTo(x, 0)
        ..lineTo(x + 9, size.height);
    } else {
      yol
        ..moveTo(x - 9, 0)
        ..lineTo(x, size.height)
        ..lineTo(x + 9, 0);
    }
    canvas.drawPath(yol..close(), Paint()..color = renk);
  }

  @override
  bool shouldRepaint(_OkBoyaci eski) =>
      eski.yon != yon || eski.merkez != merkez || eski.renk != renk;
}
