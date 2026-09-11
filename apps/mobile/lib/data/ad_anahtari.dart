/// Müşteri adının ARAMA VE SIRALAMA ANAHTARI — Türkçe harfler katlanmış, ASCII'ye indirgenmiş.
///
/// NEDEN VAR (saha bulgusu 2026-09-12, ÖLÇÜLDÜ): SQLite'ın `LIKE`'ı büyük/küçük harfi YALNIZ
/// ASCII'de eşler. `ş`↔`Ş`, `ç`↔`Ç`, `ğ`↔`Ğ`, `ö`↔`Ö`, `ü`↔`Ü`, `i`↔`İ` eşleşmez. Bir bayinin
/// 9.047 müşterisi ürüne aktarıldığında adların hepsi BÜYÜK HARFTİ; kullanıcı telefonda küçük
/// harfle yazdığı için müşterilerin çoğu ARANDIĞINDA HİÇ ÇIKMADI — panelde duruyor, telefonda
/// yok görünüyordu. Ölçüm: `ara("şerife")` → boş, `ara("ŞERİFE")` → bulur.
///
/// AYNI KÖK SIRALAMAYI DA BOZMUŞTU: SQLite'ın BINARY collation'ında Türkçe harfler çok baytlı
/// UTF-8 olduğu için TÜM ASCII harflerden sonra dizilir — "Zeynep" ile "Çağlayan" arasında
/// Çağlayan sonda kalırdı. Alfabetik sıra bu yüzden 2026-08-06'da kaldırılmıştı
/// (`musteri_siralama_test.dart`). Bu anahtar onu geri getirilebilir kılar.
///
/// ŞAPKA DA ATILIR (kullanıcı kararı 2026-09-12): `serife` yazan da ŞERİFE'yi bulur. Telefon
/// klavyesinde kimse şapkalı harf yazmıyor; eşleşmeyi harfin tam yazımına bağlamak, çözmeye
/// çalıştığımız arızanın daha kibar bir hâlini üretirdi.
///
/// BÜYÜK HARF EŞLEMESİ `toLowerCase()`TEN ÖNCE YAPILIR VE BU SIRA ŞARTTIR: Dart'ın
/// `'İ'.toLowerCase()` çıktısı `i` DEĞİL, `i` + BİRLEŞTİREN NOKTA'dır (U+0307). Önce küçültüp
/// sonra eşleseydik anahtar görünmez bir karakter taşır ve hiçbir sorguyla eşleşmezdi.
const _katlama = {
  'Ç': 'c', 'ç': 'c',
  'Ğ': 'g', 'ğ': 'g',
  'İ': 'i', 'ı': 'i', 'I': 'i',
  'Ö': 'o', 'ö': 'o',
  'Ş': 's', 'ş': 's',
  'Ü': 'u', 'ü': 'u',
  'Â': 'a', 'â': 'a',
  'Î': 'i', 'î': 'i',
  'Û': 'u', 'û': 'u',
};

/// Ham adı arama/sıralama anahtarına çevirir.
///
/// Boşluklar sadeleşir (baştaki/sondaki atılır, aradaki tek boşluğa iner): aktarılan veride
/// "AHMET  YILMAZ" gibi çift boşluklu adlar vardı ve bunlar hem aramayı hem sırayı kaydırırdı.
String adAnahtari(String ad) {
  final tampon = StringBuffer();
  for (final harf in ad.characters8()) {
    tampon.write(_katlama[harf] ?? harf.toLowerCase());
  }

  return tampon.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

extension _Harfler on String {
  /// Tek tek KOD BİRİMİ değil KARAKTER gezmek için: Türkçe harfler çok baytlı UTF-16 değildir
  /// (hepsi BMP'de tek birim), ama `split('')` yine de emoji/birleşik işaret taşıyan bir adı
  /// böler ve anahtarı bozardı. `runes` bunu güvenli yapar.
  Iterable<String> characters8() => runes.map(String.fromCharCode);
}
