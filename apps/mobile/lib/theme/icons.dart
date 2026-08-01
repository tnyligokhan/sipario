// Sipario ikon seti — tasarım s-arayuz.jsx `S_ICONS` sözlüğünün birebir kopyası.
//
// İkonlar Lucide'dan (lucide.dev, ISC) gelir: yuvarlak uçlu, 24×24 kutu, 1.8 çizgi kalınlığı.
// Path verisi tasarımdan HARFİ HARFİNE alınmıştır — değiştirme; tasarım güncellenirse buradan
// yeniden kopyala. Birden çok alt-yol `|` ile ayrılır (tasarımdaki gösterimin aynısı).
//
// Material ikonlarına DÖNÜLMEDİ: tasarımın çizgi karakteri (uniform stroke, yuvarlak uç) Material
// ikonlarının dolu/karışık diliyle uyuşmuyor; ekranların yanında hemen sırıtıyor.

import 'package:flutter/material.dart';

import 'svg_path.dart';
import 'tokens.dart';

abstract final class SipIcons {
  static const String phone =
      'M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z';
  static const String phoneCall =
      'M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z|M14.05 2a9 9 0 0 1 8 7.94|M14.05 6A5 5 0 0 1 18 10';
  static const String user = 'M12 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10z|M20 21a8 8 0 0 0-16 0';
  static const String users =
      'M10 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10z|M2 21a8 8 0 0 1 16 0|M16.5 3.5a5 5 0 0 1 0 9|M19.5 15.5c1.9 1.2 2.5 3.3 2.5 5.5';
  static const String list = 'M8 6h13|M8 12h13|M8 18h13|M3 6h.01|M3 12h.01|M3 18h.01';
  static const String plus = 'M5 12h14|M12 5v14';
  static const String book = 'M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20';
  static const String wallet =
      'M21 12V7H5a2 2 0 0 1 0-4h14v4|M3 5v14a2 2 0 0 0 2 2h16v-5|M18 12a2 2 0 0 0 0 4h4v-4z';
  static const String box =
      'M16.5 9.4 7.55 4.24|M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z|M3.29 7 12 12l8.71-5|M12 22V12';
  static const String home = 'M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z|M9 22V12h6v10';
  static const String menu = 'M4 6h16|M4 12h16|M4 18h16';
  static const String check = 'M20 6 9 17l-5-5';
  static const String x = 'M18 6 6 18|M6 6l12 12';
  static const String right = 'm9 18 6-6-6-6';
  static const String left = 'm15 18-6-6 6-6';
  static const String search = 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16z|m21 21-4.3-4.3';
  static const String alert = 'm21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3|M12 9v4|M12 17h.01';
  static const String pin = 'M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z|M12 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6z';
  static const String receipt =
      'M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1z|M14 8H8|M16 12H8|M13 16H8';
  static const String settings =
      'M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z|M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z';
  static const String sync =
      'M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8|M21 3v5h-5|M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16|M3 21v-5h5';
  static const String ticket =
      'M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2z|M13 5v2|M13 17v2|M13 11v2';
  static const String truck =
      'M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2|M15 18H9|M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62l-3.48-4.35A1 1 0 0 0 17.52 8H14|M7 20a2 2 0 1 0 0-4 2 2 0 0 0 0 4z|M17 20a2 2 0 1 0 0-4 2 2 0 0 0 0 4z';
  static const String power = 'M12 2v10|M18.4 6.6a9 9 0 1 1-12.77.04';
  static const String edit = 'M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5z|m15 5 4 4';
  static const String clock = 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z|M12 6v6l4 2';
  static const String chevR = 'm9 18 6-6-6-6';
  static const String lock = 'M3 13a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z|M7 11V7a5 5 0 0 1 10 0v4';
  static const String info = 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z|M12 16v-4|M12 8h.01';
  static const String bolt =
      'M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z';
  static const String hand =
      'M8 12V6a1.5 1.5 0 0 1 3 0v5|M11 11V4.5a1.5 1.5 0 0 1 3 0V11|M14 11V6a1.5 1.5 0 0 1 3 0v8a6 6 0 0 1-6 6h-1a6 6 0 0 1-5-2.7L3.5 15a1.6 1.6 0 0 1 2.6-1.8L8 15';
  static const String wa = 'M12 21a9 9 0 1 0-8.3-5.4L3 21l5.6-.8A9 9 0 0 0 12 21z|M9 9.5c.5 2.5 3 5 5.5 5.5';
  static const String chat = 'M7.9 20A9 9 0 1 0 4 16.1L2 22z|M8 12h.01|M12 12h.01|M16 12h.01';
  static const String phoneOff =
      'M10.68 13.31a16 16 0 0 0 3.41 2.6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7 2 2 0 0 1 1.72 2v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.42 19.42 0 0 1-3.33-2.67m-2.67-3.34a19.79 19.79 0 0 1-3.07-8.63A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91|M22 2 2 22';
  static const String grip = 'M9 5.5h.01|M9 12h.01|M9 18.5h.01|M15 5.5h.01|M15 12h.01|M15 18.5h.01';
  static const String barkod =
      'M3 7V5a2 2 0 0 1 2-2h2|M17 3h2a2 2 0 0 1 2 2v2|M21 17v2a2 2 0 0 1-2 2h-2|M7 21H5a2 2 0 0 1-2-2v-2|M8 7v10|M12 7v10|M17 7v10';
  static const String sirala = 'm3 16 4 4 4-4|M7 20V4|M11 4h10|M11 8h7|M11 12h4';
  static const String up = 'm18 15-6-6-6 6';
  static const String down = 'm6 9 6 6 6-6';
  static const String userPlus = 'M10 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10z|M2 21a8 8 0 0 1 13.3-6|M19 16v6|M22 19h-6';
  static const String moon = 'M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9z';
  static const String ay = moon;
  static const String sinyal = 'M2 20h.01|M7 20v-4|M12 20v-8|M17 20V8|M22 4v16';
  static const String wifi = 'M12 20h.01|M8.5 16.43a5 5 0 0 1 7 0|M5 12.86a10 10 0 0 1 14 0|M2 8.82a15 15 0 0 1 20 0';
  static const String batarya =
      'M3 7h13a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z|M22 11v2|M5 10v4|M8 10v4|M11 10v4|M14 10v4';

  /// Müşteri silme (tehlikeli eylem).
  static const String trash =
      'M3 6h18|M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6|M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2';

  /// Kara liste (yasak işareti).
  static const String ban = 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z|m4.9 4.9 14.2 14.2';

  /// Ad → path eşlemesi. Tasarımın `Icon name="..."` çağrılarıyla aynı anahtarlar.
  static const Map<String, String> hepsi = {
    'trash': trash,
    'ban': ban,
    'phone': phone,
    'phoneCall': phoneCall,
    'user': user,
    'users': users,
    'list': list,
    'plus': plus,
    'book': book,
    'wallet': wallet,
    'box': box,
    'home': home,
    'menu': menu,
    'check': check,
    'x': x,
    'right': right,
    'left': left,
    'search': search,
    'alert': alert,
    'pin': pin,
    'receipt': receipt,
    'settings': settings,
    'sync': sync,
    'ticket': ticket,
    'truck': truck,
    'power': power,
    'edit': edit,
    'clock': clock,
    'chevR': chevR,
    'lock': lock,
    'info': info,
    'bolt': bolt,
    'hand': hand,
    'wa': wa,
    'chat': chat,
    'phoneOff': phoneOff,
    'grip': grip,
    'barkod': barkod,
    'sirala': sirala,
    'up': up,
    'down': down,
    'userPlus': userPlus,
    'moon': moon,
    'ay': ay,
    'sinyal': sinyal,
    'wifi': wifi,
    'batarya': batarya,
  };
}

/// Metin bir SVG path verisi mi, yoksa sözlük anahtarı mı? Path daima bir başlangıç komutuyla
/// (`M`/`m`) başlar ve rakam içerir; anahtarlarımız ('menu', 'phoneCall') hiçbiri öyle değil.
bool _pathMi(String s) =>
    s.length > 3 && (s.startsWith('M') || s.startsWith('m')) && s.contains(RegExp(r'\d'));

/// Çözülmüş [Path] önbelleği — aynı ikon ikinci kez ayrıştırılmaz. İkon sayısı sabit (44) ve
/// küçük olduğu için sınırsız büyümez.
final Map<String, List<Path>> _yolOnbellek = {};

List<Path> _yollar(String d) => _yolOnbellek.putIfAbsent(
      d,
      () => d.split('|').map(svgYoluCoz).toList(growable: false),
    );

/// Tasarımdaki `<Icon name size sw color />` bileşeninin karşılığı.
///
/// [ad] [SipIcons.hepsi] anahtarlarından biri (veya doğrudan bir path metni geçmek istersen
/// [yol] kullan). [kalinlik] CSS'teki `sw` — varsayılan 1.8.
///
/// Renk verilmezse çevredeki [DefaultTextStyle]/[IconTheme] renginden miras alınır; böylece hero
/// blokları içindeki ikonlar otomatik beyaza döner.
class SipIcon extends StatelessWidget {
  const SipIcon(
    this.ad, {
    super.key,
    this.boyut = 22,
    this.kalinlik = 1.8,
    this.renk,
  }) : yol = null;

  /// Ham path verisiyle çizmek için (ikon setinde olmayan tek seferlik şekiller).
  const SipIcon.yolIle(
    this.yol, {
    super.key,
    this.boyut = 22,
    this.kalinlik = 1.8,
    this.renk,
  }) : ad = '';

  final String ad;
  final String? yol;
  final double boyut;
  final double kalinlik;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    // [ad] iki biçimi de kabul eder: sözlük ANAHTARI ('menu') ya da doğrudan PATH verisi
    // (`SipIcons.menu`, yani 'M4 6h16|…'). İkisi de gerekli çünkü sabitler path taşıyor
    // (`SipIcon(SipIcons.menu)` en doğal çağrı) ama ad ile çağırmak da okunur.
    // Karışma riski yok: anahtarlar sade sözcükler, path'ler daima bir komut harfi + sayı içerir.
    //
    // NOT — bu ayrım bir kez ATLANDI ve TÜM uygulamada hiçbir ikon çizilmedi: yalnız
    // `hepsi[ad]` bakılıyordu, `SipIcons.menu` anahtar olarak bulunamıyordu ve fonksiyon
    // sessizce boş kutu döndürüyordu. Hata testlerden geçti (çökme yok, yol ayrıştırılıyor),
    // yalnız cihazda görüldü. `test/icon_paint_test.dart` artık gerçek piksel sayıyor.
    final d = yol ?? SipIcons.hepsi[ad] ?? (_pathMi(ad) ? ad : null);
    if (d == null || d.isEmpty) return SizedBox.square(dimension: boyut);
    final c = renk ??
        DefaultTextStyle.of(context).style.color ??
        IconTheme.of(context).color ??
        SipTokens.acik.ink;
    return SizedBox.square(
      dimension: boyut,
      child: CustomPaint(
        painter: _IkonCizer(
          yollar: _yollar(d),
          renk: c,
          kalinlik: kalinlik,
          boyut: boyut,
        ),
      ),
    );
  }
}

class _IkonCizer extends CustomPainter {
  const _IkonCizer({
    required this.yollar,
    required this.renk,
    required this.kalinlik,
    required this.boyut,
  });

  final List<Path> yollar;
  final Color renk;
  final double kalinlik;
  final double boyut;

  @override
  void paint(Canvas canvas, Size size) {
    // Lucide kutusu 24×24; istenen boyuta ölçekle. Çizgi kalınlığı da ölçeklenir ki ikon
    // küçüldükçe çizgi orantılı incelsin (CSS'te viewBox davranışının aynısı).
    final olcek = size.width / 24.0;
    canvas.save();
    canvas.scale(olcek);
    final firca = Paint()
      ..style = PaintingStyle.stroke
      ..color = renk
      ..strokeWidth = kalinlik
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    for (final y in yollar) {
      canvas.drawPath(y, firca);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IkonCizer eski) =>
      eski.renk != renk ||
      eski.kalinlik != kalinlik ||
      eski.boyut != boyut ||
      !identical(eski.yollar, yollar);
}
