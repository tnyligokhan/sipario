// SATIR İSKONTOSU değer nesnesi — sipariş kaleminde girilen indirim (kullanıcı isteği 2026-11-05).
//
// KAPIDA İSKONTODAN AYRIDIR. Teslimde kırılan tutar defterde `discount` satırıdır: mal tam fiyatla
// satılmış, borcun bir kısmı silinmiştir. Bu ise satışın baştan indirimli yapılmasıdır: satır toplamı
// düşer, sipariş toplamı düşer, deftere o tutar hiç borç yazılmaz. Gün özetindeki kapıda iskonto
// satırı bu tutarı içermez.
//
// YÜZDE NEDEN SAKLANIR: sepette bayi "%10" yazar, sonra adedi artırır. Kuruşa çevrilip donsaydı
// iskonto yeni adede göre eksik kalırdı. Sunucuya yalnız sonuç kuruş gider (`order_lines.discount_kurus`);
// yüzde sepetin çalışma durumudur.
//
// Saf Dart.

enum IskontoTuru { tutar, yuzde }

/// Sepet satırının iskontosu. [yok] dışındaki örnekler pozitif değer taşır.
class SatirIskontosu {
  const SatirIskontosu.tutar(int kurus)
      : tur = IskontoTuru.tutar,
        deger = kurus;

  /// [yuzde] 1..100.
  const SatirIskontosu.yuzde(int yuzde)
      : tur = IskontoTuru.yuzde,
        deger = yuzde;

  static const SatirIskontosu yok = SatirIskontosu.tutar(0);

  final IskontoTuru tur;

  /// Kuruş ya da yüzde; anlamını [tur] verir.
  final int deger;

  bool get bos => deger <= 0;

  /// [brutKurus] (birim × adet) üzerinden düşülecek kuruş. Daima 0..brüt arasındadır: adet
  /// azaltılınca tutar iskontosu satırı eksiye düşürmesin diye kırpılır.
  int kurus(int brutKurus) {
    if (bos || brutKurus <= 0) return 0;
    final ham = tur == IskontoTuru.tutar ? deger : (brutKurus * deger / 100).round();
    return ham > brutKurus ? brutKurus : ham;
  }

  /// Sepette ve özette yazılan kısa ad: "%10" ya da boş. Tutar türünde ek metin gerekmez.
  String get yuzdeEtiketi => tur == IskontoTuru.yuzde && !bos ? '%$deger' : '';
}
