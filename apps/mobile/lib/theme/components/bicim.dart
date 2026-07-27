// Sipario paylaşılan atomlar — PARA VE METİN BİÇİMLENDİRME.
// Kaynak: tasarım s-arayuz.jsx (`fmtTL`, `fmtSayi`).
//
// Saf Dart: hiçbir Flutter bağımlılığı yok, bu yüzden testte ve arka plan kodunda da kullanılır.

/// Kuruş tamsayısını "1.234,50 ₺" biçiminde yazar. Negatifte tasarımdaki gibi TİPOGRAFİK eksi
/// (U+2212) kullanılır — tabular hizada normal tireden daha temiz oturur.
String sipTutar(int kurus, {bool simge = true}) {
  final eksi = kurus < 0;
  final mutlak = kurus.abs();
  final lira = mutlak ~/ 100;
  final kurusKismi = mutlak % 100;
  final buf = StringBuffer();
  if (eksi) buf.write('−');
  buf.write(_binlik(lira));
  buf.write(',');
  buf.write(kurusKismi.toString().padLeft(2, '0'));
  if (simge) buf.write(' ₺');
  return buf.toString();
}

/// Tamsayıyı binlik ayraçlı yazar (tr-TR: nokta).
String sipSayi(int n) => (n < 0 ? '−' : '') + _binlik(n.abs());

String _binlik(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// TÜRKÇE büyük harf. Dart'ın [String.toUpperCase] metodu yerelden bağımsızdır ve `i` harfini
/// `I` yapar — Türkçede doğrusu `İ`, `ı`nın büyüğü ise `I`. Tasarımda form etiketleri, bölüm
/// başlıkları ve rozetler BÜYÜK HARF olduğu için bu ayrım her ekranda görünür
/// ("MÜŞTERI ADI" yanlış, "MÜŞTERİ ADI" doğru).
String trBuyuk(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Türkçe küçük harf — [trBuyuk]'ün tersi (arama karşılaştırmalarında kullanılır).
String trKucuk(String s) => s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

/// "0532 415 22 90" — yalnız GÖSTERİM içindir; saklama daima E.164.
String sipTelefon(String ham) {
  final d = ham.replaceAll(RegExp(r'\D'), '');
  final s = d.length > 10 ? d.substring(d.length - 10) : d;
  if (s.length != 10) return ham;
  return '0${s.substring(0, 3)} ${s.substring(3, 6)} ${s.substring(6, 8)} ${s.substring(8)}';
}
