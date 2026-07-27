// Küçük SVG "path data" ayrıştırıcısı — yalnız ikon setimizin ihtiyaç duyduğu kadarı.
//
// NEDEN KENDİ AYRIŞTIRICIMIZ: tasarım (tasarım s-arayuz.jsx) ikonları Lucide'ın ham
// `d` verisi olarak taşıyor. Bunu çizmek için ya bir SVG paketi eklenecekti ya da yollar elle
// Flutter [Path] çağrılarına dönüştürülecekti. İlki uygulamaya çalışma-anı ayrıştırma maliyeti
// ve bir bağımlılık ekler (offline-first ilkesiyle gereksiz bir risk), ikincisi 40+ ikonda
// hataya açık. Bu dosya ikisinin ortası: ~150 satır, sıfır bağımlılık, sonuç [Path] önbelleğe
// alındığı için çizim maliyeti tek seferlik.
//
// Yay (arc) komutları Flutter'ın [Path.arcToPoint] API'sine BİREBİR eşlenir — SVG ile aynı
// semantiği taşıdığı için elle bezier dönüşümü gerekmez.

import 'dart:math' as math;
import 'dart:ui';

/// SVG `d` metnini [Path]'e çevirir. Desteklenen komutlar: M m L l H h V v C c S s Q q T t A a Z z.
/// Tanınmayan komut sessizce atlanır (ikon setimizde geçmez; yine de çizim çökmemeli).
Path svgYoluCoz(String d) {
  final path = Path();
  final t = _Tarayici(d);

  var akimX = 0.0, akimY = 0.0; // geçerli nokta
  var baslangicX = 0.0, baslangicY = 0.0; // alt-yolun başı (Z buraya döner)
  var kontrolX = 0.0, kontrolY = 0.0; // S/T için yansıtılacak son kontrol noktası
  var oncekiKomut = '';

  while (true) {
    final komut = t.komutOku();
    if (komut == null) break;

    switch (komut) {
      case 'M':
      case 'm':
        final bagil = komut == 'm';
        var ilk = true;
        while (t.sayiVar()) {
          final x = t.sayi(), y = t.sayi();
          akimX = bagil ? akimX + x : x;
          akimY = bagil ? akimY + y : y;
          if (ilk) {
            path.moveTo(akimX, akimY);
            baslangicX = akimX;
            baslangicY = akimY;
            ilk = false;
          } else {
            // M'den sonraki fazladan çiftler örtük LineTo'dur (SVG kuralı).
            path.lineTo(akimX, akimY);
          }
        }
        kontrolX = akimX;
        kontrolY = akimY;

      case 'L':
      case 'l':
        final bagil = komut == 'l';
        while (t.sayiVar()) {
          final x = t.sayi(), y = t.sayi();
          akimX = bagil ? akimX + x : x;
          akimY = bagil ? akimY + y : y;
          path.lineTo(akimX, akimY);
        }
        kontrolX = akimX;
        kontrolY = akimY;

      case 'H':
      case 'h':
        final bagil = komut == 'h';
        while (t.sayiVar()) {
          final x = t.sayi();
          akimX = bagil ? akimX + x : x;
          path.lineTo(akimX, akimY);
        }
        kontrolX = akimX;
        kontrolY = akimY;

      case 'V':
      case 'v':
        final bagil = komut == 'v';
        while (t.sayiVar()) {
          final y = t.sayi();
          akimY = bagil ? akimY + y : y;
          path.lineTo(akimX, akimY);
        }
        kontrolX = akimX;
        kontrolY = akimY;

      case 'C':
      case 'c':
        final bagil = komut == 'c';
        while (t.sayiVar()) {
          final x1 = t.sayi(), y1 = t.sayi();
          final x2 = t.sayi(), y2 = t.sayi();
          final x = t.sayi(), y = t.sayi();
          final c1x = bagil ? akimX + x1 : x1, c1y = bagil ? akimY + y1 : y1;
          final c2x = bagil ? akimX + x2 : x2, c2y = bagil ? akimY + y2 : y2;
          akimX = bagil ? akimX + x : x;
          akimY = bagil ? akimY + y : y;
          path.cubicTo(c1x, c1y, c2x, c2y, akimX, akimY);
          kontrolX = c2x;
          kontrolY = c2y;
        }

      case 'S':
      case 's':
        final bagil = komut == 's';
        while (t.sayiVar()) {
          final x2 = t.sayi(), y2 = t.sayi();
          final x = t.sayi(), y = t.sayi();
          // Önceki komut da kübikse ilk kontrol noktası son kontrolün yansımasıdır.
          final yansi = oncekiKomut == 'C' ||
              oncekiKomut == 'c' ||
              oncekiKomut == 'S' ||
              oncekiKomut == 's';
          final c1x = yansi ? 2 * akimX - kontrolX : akimX;
          final c1y = yansi ? 2 * akimY - kontrolY : akimY;
          final c2x = bagil ? akimX + x2 : x2, c2y = bagil ? akimY + y2 : y2;
          akimX = bagil ? akimX + x : x;
          akimY = bagil ? akimY + y : y;
          path.cubicTo(c1x, c1y, c2x, c2y, akimX, akimY);
          kontrolX = c2x;
          kontrolY = c2y;
        }

      case 'Q':
      case 'q':
        final bagil = komut == 'q';
        while (t.sayiVar()) {
          final x1 = t.sayi(), y1 = t.sayi();
          final x = t.sayi(), y = t.sayi();
          final cx = bagil ? akimX + x1 : x1, cy = bagil ? akimY + y1 : y1;
          akimX = bagil ? akimX + x : x;
          akimY = bagil ? akimY + y : y;
          path.quadraticBezierTo(cx, cy, akimX, akimY);
          kontrolX = cx;
          kontrolY = cy;
        }

      case 'T':
      case 't':
        final bagil = komut == 't';
        while (t.sayiVar()) {
          final x = t.sayi(), y = t.sayi();
          final yansi = oncekiKomut == 'Q' ||
              oncekiKomut == 'q' ||
              oncekiKomut == 'T' ||
              oncekiKomut == 't';
          final cx = yansi ? 2 * akimX - kontrolX : akimX;
          final cy = yansi ? 2 * akimY - kontrolY : akimY;
          akimX = bagil ? akimX + x : x;
          akimY = bagil ? akimY + y : y;
          path.quadraticBezierTo(cx, cy, akimX, akimY);
          kontrolX = cx;
          kontrolY = cy;
        }

      case 'A':
      case 'a':
        final bagil = komut == 'a';
        while (t.sayiVar()) {
          final rx = t.sayi(), ry = t.sayi();
          final donus = t.sayi();
          final buyukYay = t.sayi() != 0;
          final saatYonu = t.sayi() != 0;
          final x = t.sayi(), y = t.sayi();
          akimX = bagil ? akimX + x : x;
          akimY = bagil ? akimY + y : y;
          // Flutter'ın arcToPoint'i SVG yay semantiğinin aynısıdır; rotation radyan ister.
          path.arcToPoint(
            Offset(akimX, akimY),
            radius: Radius.elliptical(rx.abs(), ry.abs()),
            rotation: donus * math.pi / 180.0,
            largeArc: buyukYay,
            clockwise: saatYonu,
          );
        }
        kontrolX = akimX;
        kontrolY = akimY;

      case 'Z':
      case 'z':
        path.close();
        akimX = baslangicX;
        akimY = baslangicY;
        kontrolX = akimX;
        kontrolY = akimY;

      default:
        // Bilinmeyen komut: bu komuta ait sayıları yutup devam et.
        while (t.sayiVar()) {
          t.sayi();
        }
    }
    oncekiKomut = komut;
  }
  return path;
}

/// `d` metnini komut harflerine ve sayılara bölen imleç. SVG'de sayılar boşluksuz da bitişebilir
/// ("6-6-6" → 6, −6, −6; "1.5.5" → 1.5, .5), tarayıcı bunu karakter karakter çözer.
class _Tarayici {
  _Tarayici(this._s);

  final String _s;
  int _i = 0;

  static const int _bosluk = 32, _tab = 9, _lf = 10, _cr = 13, _virgul = 44;
  static const int _eksi = 45, _arti = 43, _nokta = 46, _sifir = 48, _dokuz = 57;
  static const int _e = 101, _buyukE = 69;

  void _bosluklariAtla() {
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c == _bosluk || c == _tab || c == _lf || c == _cr || c == _virgul) {
        _i++;
      } else {
        break;
      }
    }
  }

  /// Sıradaki komut harfini döndürür. Harf yoksa (örtük tekrar) önceki komut çağıran tarafta
  /// `sayiVar()` döngüsüyle sürdürüldüğü için burada null döner ve ayrıştırma biter.
  String? komutOku() {
    _bosluklariAtla();
    if (_i >= _s.length) return null;
    final c = _s[_i];
    if (RegExp(r'[A-Za-z]').hasMatch(c)) {
      _i++;
      return c;
    }
    return null;
  }

  bool sayiVar() {
    _bosluklariAtla();
    if (_i >= _s.length) return false;
    final c = _s.codeUnitAt(_i);
    return c == _eksi ||
        c == _arti ||
        c == _nokta ||
        (c >= _sifir && c <= _dokuz);
  }

  double sayi() {
    _bosluklariAtla();
    final bas = _i;
    if (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c == _eksi || c == _arti) _i++;
    }
    var noktaGoruldu = false;
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c >= _sifir && c <= _dokuz) {
        _i++;
      } else if (c == _nokta && !noktaGoruldu) {
        noktaGoruldu = true;
        _i++;
      } else if (c == _e || c == _buyukE) {
        // Bilimsel gösterim: üsteli ve varsa işaretini yut.
        _i++;
        if (_i < _s.length) {
          final u = _s.codeUnitAt(_i);
          if (u == _eksi || u == _arti) _i++;
        }
      } else {
        break;
      }
    }
    return double.tryParse(_s.substring(bas, _i)) ?? 0.0;
  }
}
