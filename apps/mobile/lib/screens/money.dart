// Para biçimlendirme ve ayrıştırma. Para HER YERDE int kuruş (kırmızı çizgi / DECISIONS: kayan
// nokta YOK) — bu dosya kullanıcı yazımıyla kuruş arasındaki TEK sınırdır.

/// Kuruşu "1.234,56 ₺" biçiminde yazar.
String formatKurus(int kurus) {
  final negative = kurus < 0;
  final abs = kurus.abs();
  final lira = abs ~/ 100;
  final kr = abs % 100;
  final liraStr = lira.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  return '${negative ? '−' : ''}$liraStr,${kr.toString().padLeft(2, '0')} ₺';
}

/// Kullanıcı yazımını kuruşa çevirir; geçersizse null (SESSİZ YUVARLAMA YOK — para).
/// Kabul: "12" → 1200 · "12,5" → 1250 · "12,50" → 1250 · "1.234,56" → 123456 · "12.50" → 1250.
/// "1.234" TR yazımında binliktir → 123400 (nokta+3 hane, virgül yok).
/// Reddedilen: negatif, boş, harf, 2'den uzun kuruş kısmı (yuvarlamayı kullanıcıya sormadan yapmayız).
int? parseKurus(String text) {
  var s = text.trim().replaceAll('₺', '').replaceAll(' ', '').replaceAll(' ', '');
  if (s.isEmpty || s.contains('-') || s.contains('−')) return null;

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  String whole;
  String frac = '';

  if (lastComma > lastDot) {
    // Virgül ondalık, nokta binlik (TR yazımı).
    whole = s.substring(0, lastComma).replaceAll('.', '');
    frac = s.substring(lastComma + 1);
  } else if (lastDot >= 0) {
    final tail = s.substring(lastDot + 1);
    if (tail.length == 3 && !s.contains(',')) {
      // "1.234" — TR'de binlik ayırıcı; ondalık saymak 1.234 TL'yi 12,34 TL yapardı.
      whole = s.replaceAll('.', '');
    } else {
      whole = s.substring(0, lastDot).replaceAll('.', '');
      frac = tail;
    }
  } else {
    whole = s;
  }

  if (whole.isEmpty) whole = '0';
  final digits = RegExp(r'^\d+$');
  if (!digits.hasMatch(whole)) return null;
  if (frac.isNotEmpty && (!digits.hasMatch(frac) || frac.length > 2)) return null;

  final lira = int.tryParse(whole);
  if (lira == null) return null;
  final kr = frac.isEmpty ? 0 : int.parse(frac.padRight(2, '0'));
  return lira * 100 + kr;
}
