// SİPARİŞ SATIRI GİRDİSİ — sipariş deposunun yazma sözleşmesi.
//
// NEDEN AYRI DOSYA: `order_repository.dart` satır iskontosuyla 500 satırı aştı. Bu sınıf satırın
// tutar formülünün tek yeridir; `order_repository.dart` onu yeniden dışa aktarır, çağıranlar değişmez.

import '../data/urun_secenekleri.dart';

class LineInput {
  LineInput({
    required this.productName,
    required this.unitPriceKurus,
    required this.qty,
    this.productId,
    this.unit,
    this.note,
    this.isCustom = false,
    this.secim = const SecenekSecimi(),
    this.iskontoKurus = 0,
  });
  final String? productId;
  final String productName;
  final int unitPriceKurus;
  final int qty;

  /// Birim ("adet"/"koli"/"kg") satırda saklanır — fiyat/ad ile aynı gerekçe: o anki gerçek.
  /// Opsiyonel; mevcut çağrılar aynen çalışır.
  final String? unit;

  /// SATIR NOTU ("buzlu olsun", "kapıya bırak") — siparişin NOTUYLA karıştırılmamalı: o
  /// siparişin tamamına, bu TEK KALEME aittir. Opsiyonel; mevcut çağrılar aynen çalışır.
  final String? note;

  /// "Serbest satır" (katalogda olmayan tek seferlik iş — tasarım bunları ayrı gösterir).
  /// productId'nin null olması yeterli ayırt edici değildir: silinmiş ürünün satırı da null olur.
  final bool isCustom;

  /// SEÇENEK SEÇİMİ — "soğansız, ekstra peynirli" (kullanıcı isteği 2026-08-18).
  ///
  /// ⚠️ [unitPriceKurus] EK TUTARI **İÇERMEZ**; onu depo ekler ([birimFiyat]). Çağıranın ürünün
  /// katalog fiyatını göndermesi ve ekstraları depo hesabına bırakması bilinçli: fiyat formülü
  /// tek yerde durur, yoksa her çağrı yerinde bir kez daha yazılır ve biri er geç unutulur.
  final SecenekSecimi secim;

  /// Satıra yazılacak BİRİM fiyat: katalog fiyatı + eklenen malzemelerin ek tutarı.
  ///
  /// Ekstra, ADET BAŞINA binmelidir: iki dürümün ikisine de ekstra peynir eklendiyse ücret de
  /// iki kere alınır. Satır toplamı `birim * adet` kimliğini koruduğu için gün sonu, defter ve
  /// teslim hesaplarının hiçbiri değişmez.
  int get birimFiyat => unitPriceKurus + secim.ekTutarKurus;

  /// SATIR İSKONTOSU (saha, 2026-11-05): satırın tamamından düşülen kuruş.
  final int iskontoKurus;

  /// Satıra yazılacak iskonto; satır tutarını aşamaz, sunucu aşanı reddeder.
  int get uygulananIskonto {
    final brut = birimFiyat * qty;
    if (iskontoKurus <= 0) return 0;
    return iskontoKurus > brut ? brut : iskontoKurus;
  }

  /// Satır toplamı. Sipariş toplamı buradan türediği için teslim, defter ve gün sonu iskontoyu
  /// ayrıca bilmez. Formül sunucuyla AYNI (`OrderChangeApplier::insertLine`).
  int get satirToplami => birimFiyat * qty - uygulananIskonto;

  /// Satırın notu: kullanıcının yazdığı not + seçim özeti ("Soğansız · + Ekstra peynir").
  ///
  /// İKİSİ BİRLEŞTİRİLİR çünkü ekranların TAMAMI bu tek alanı çiziyor (sipariş detayı, kurye
  /// görünümü, geçmiş). Seçimi ayrı bir alanda bırakıp ekranları tek tek güncellemek, bir
  /// ekranın unutulduğu gün kuryenin "soğansız"ı hiç görmemesi demekti.
  String? get satirNotu {
    final elle = (note ?? '').trim();
    final ozet = secim.ozet();
    if (elle.isEmpty) return ozet.isEmpty ? null : ozet;
    if (ozet.isEmpty) return elle;
    return '$ozet, $elle';
  }
}
