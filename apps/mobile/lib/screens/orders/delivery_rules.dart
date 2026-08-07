// Teslim & Ödeme sheet'inin SAF KURALLARI — widget kurmadan test edilir (sipariş ekranlarının
// deseni: karar mantığı ekrandan ayrı durur, drift/animasyon gerektirmeden milisaniyelerde koşar).
//
// NEDEN AYRI DOSYA: kapıda iskonto eklenince `delivery_sheet.dart` 500 satır sınırını aştı
// (`order_detail_eylemler.dart` ile aynı gerekçe). Buradaki semboller `delivery_sheet.dart`tan
// RE-EXPORT edilir — mevcut testler ve çağıranlar tek import'la çalışmayı sürdürsün diye.
//
// Bu dosya hiçbir şey YAZMAZ ve hiçbir widget kurmaz: girdi sayı, çıktı sayı ya da metin.

import '../../theme/components/atoms.dart' show sipTutar;

/// Kaydedilecek ödeme tipi. Hiç para alınmadıysa seçili karo ne olursa olsun kayıt VERESİYEDİR:
/// `orders.payment_type` "nakit" derken defterde tek kuruş `payment` bulunmaması, gün sonu kasa
/// özetiyle sipariş listesini birbirine düşürürdü.
String teslimOdemeTipi(String secilen, int tahsilKurus) =>
    tahsilKurus <= 0 ? 'veresiye' : secilen;

/// Teslimden sonra müşterinin borcuna yazılacak İMZALI fark: + kalan borç, − fazla ödeme.
/// Bu fark deftere ayrı satır olarak YAZILMAZ (debit − payment farkı zaten budur); yalnız
/// ekranda ne olacağını söylemek için hesaplanır.
int teslimBorcFarki({required int toplamKurus, required int tahsilKurus}) =>
    toplamKurus - tahsilKurus;

/// Girilen tahsilat tutarının hata metni; geçerliyse `null`.
///
/// Müşterili siparişte HER tutar geçerlidir — 0 (tamamı veresiye) de, sipariş tutarından fazlası
/// da. Fazlası kasaya gerçekten giren paradır ve müşterinin ÖNCEKİ borcunu kapatır; reddetmek
/// bayiyi "önce teslim et, sonra ayrı tahsilat gir" iki adımına zorlar ve saha o ikinci adımı
/// atlar (para cebe girer, kayıt kaçar). Bakiyenin eksiye düşmesi modelde zaten mümkün.
///
/// Müşterisiz (tezgâh) siparişte tutar TAM olmalıdır: eksiğini yazacak da fazlasını alacak
/// yazacak bir cari yok — veresiye karosunun müşterisizken kilitli olmasıyla aynı gerekçe.
String? teslimTahsilatHatasi({
  required int? tahsilKurus,
  required int toplamKurus,
  required bool musteriVar,
}) {
  if (tahsilKurus == null) return 'Tutarı okuyamadım — ör. 120 ya da 120,50 yazın';
  if (!musteriVar && tahsilKurus != toplamKurus) {
    return 'Tezgâh satışında sipariş tutarının tamamı tahsil edilir '
        '(${sipTutar(toplamKurus)}) — eksiği yazılacak müşteri yok';
  }
  return null;
}

/// "Kalanı borç yazma (iskonto)" anahtarı SORULUR mu?
///
/// Yalnız tutar okunabilir VE sipariş tutarının ALTINDAYKEN — üstünde iskonto diye bir şey yoktur
/// (fazlası müşterinin önceki borcunu kapatır, DECISIONS 2026-07-27), eşitken de kırılan bir şey
/// yoktur. Anahtarı her teslimde göstermek, ezici çoğunluğu tam tahsilat olan bir akışa hiç
/// kullanılmayan bir soru eklerdi; kırma yapıldığı an KENDİLİĞİNDEN belirmesi ise bayiye "bunu
/// borç mu yazayım" sorusunu tam karar anında sorar.
bool teslimIskontoSorulur({required int? tahsilKurus, required int toplamKurus}) =>
    tahsilKurus != null && tahsilKurus >= 0 && tahsilKurus < toplamKurus;

/// Deftere düşecek İSKONTO (pozitif kuruş, 0 = yok).
///
/// Anahtar kapalıyken DAİMA 0'dır: kapalı anahtar mevcut davranıştır (kalan borç olarak yazılır)
/// ve bu fonksiyon o yolu hiç değiştirmez. Açıkken iskonto tam olarak kırılan farktır — fark
/// pozitif değilse (tam ya da fazla tahsilat) yine 0: anahtar o durumda zaten görünmez, ama
/// kullanıcı önce kutuyu işaretleyip SONRA tutarı yükseltmiş olabilir ve görünmeyen bir işaretin
/// deftere kayıt düşürmesi, bu depoda en pahalıya mal olan sessiz-yazma ailesinden olurdu.
int teslimIskontoKurus({
  required int toplamKurus,
  required int tahsilKurus,
  required bool borcYazma,
}) {
  if (!borcYazma) return 0;
  final fark = toplamKurus - tahsilKurus;
  return fark > 0 ? fark : 0;
}

/// Kuruşu girdi kutusuna yazılabilir metne çevirir ("12050" → "120,50"). Binlik ayracı YOK:
/// `parseKurus` "1.234"ü binlik sayar, geri okumada belirsizlik kalmasın.
///
/// `screens/customers/customer_widgets.dart`teki `tutarGirdisi` ile aynı kuraldır; oradan ödünç
/// ALINMADI çünkü sipariş ekranları başka ajanların ekran dosyalarından sembol almıyor
/// (order_queries.dart başlığındaki sözleşme). Asıl yeri `money.dart` — taşınması lead'e bildirildi.
String teslimTutarGirdisi(int kurus) =>
    '${kurus ~/ 100},${(kurus % 100).toString().padLeft(2, '0')}';
