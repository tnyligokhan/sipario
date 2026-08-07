// MÜŞTERİ İLİŞKİSİ bildirim kuralları — Faz 1.
//
// İki kural: "gecikmiş müşteri" (kaybedilmekte olan müşteriyi yakalar) ve "rutin teslim günü"
// (bugün sırası gelenler). İkisi de MEVCUT sipariş geçmişinden türer; ek veri, sunucu çağrısı ya
// da tahmin modeli YOKTUR — hesap tamamen cihazda, saf fonksiyonlarda yapılır.
//
// TASARIMIN TEK KURALI: YANLIŞ TAHMİN GÜVEN KAYBETTİRİR.
// "Ahmet Bey'i arayın" deyip Ahmet Bey dün almışsa bayi bu bildirime bir daha bakmaz. Bu yüzden
// her eşik MUHAFAZAKÂR seçildi ve emin olunamayan her durumda kural SUSAR (null döner). Bir
// gecikmeyi kaçırmanın maliyeti, yanlış bildirmenin maliyetinden düşüktür: kaçan bildirim
// yarın yeniden denenir, yanlış bildirim ise özelliğin tamamını çöpe atar.
//
// KATMAN: bu dosya SAFTIR — girdi veri, çıktı `BildirimTaslagi`. Veritabanı okuması
// `repo/order_repository.dart` içindeki `musteriTeslimGecmisleri`ndedir; bildirimi GÖSTERMEK
// (izin, sessiz saat, günlük sınır) altyapının işidir — kural yalnız doğru taslağı üretir.
//
// MÜŞTERİ ADI DAİMA GÖVDEDE, BAŞLIK YALNIZ SAYI TAŞIR.
//
// Mekanizma (cagri'nin 2026-07-27 düzeltmesi): `flutter_local_notifications` `publicVersion`
// alanını AÇMIYOR, yalnız `visibility` var; `VISIBILITY_PRIVATE` seçilince Android bildirimin
// TAMAMINI gizler (başlık dahil). Yani "nötr başlık göster, ayrıntıyı gizle" ikilisi bu paketle
// kurulamıyor — ilk anlattığımız "başlık görünür, gövde gizlenir" ayrımı YANLIŞTI.
//
// Kural yine de geçerli, çünkü asıl risk kilit ekranı DEĞİL:
//  1. Kilidi açtıktan sonra bildirim rafında bir bakışta okunan şey BAŞLIKTIR; orada ad olması,
//     telefonu birine uzatınca müşteri adının görülmesi demektir.
//  2. Görünürlük kararı ileride değişirse ya da native köprüyle `publicVersion` eklenirse
//     sızacak alan başlıktır — bugünden temiz olması bedava sigorta.
//  3. SAYI kişisel veri değildir; "7 müşteri gecikti" hiçbir müşteriyi ele vermez.
// Başlıkta ad OLMADIĞI testle kilitlidir — "başlık daha bilgilendirici olsun" düzeltmesi
// sessizce bir KVKK sorunu geri getirirdi.
//
// XIAOMI NOTU (cagri): agresif pil yönetimi zamanlanmış bildirimi öldürebilir. Bu yüzden
// [gecikmisMusteriler] ve [rutinGunuGelenler] AYRICA açıktır — aynı bilgi ana ekranda da
// gösterilebilsin, kritik bilgi yalnız bildirime bağlı kalmasın.

import 'dart:math' as math;

import '../bildirim_sozlesmesi.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Eşikler — hepsi tek yerde, hepsi gerekçeli
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Ritim hesabı için gereken EN AZ teslimat sayısı.
///
/// Neden 4 (yani 3 aralık): iki teslimat tek aralık verir ve "aralık" değil "tesadüf"tür. Üç
/// teslimat iki aralık verir, ortancası ikisinin ORTALAMASIDIR — yani tek bir olağandışı sipariş
/// yine sonucu kaydırır. Üç aralıkta ortanca gerçekten ORTADAKİ değerdir ve tek aykırı değer onu
/// oynatamaz. Alt sınırı burada tutmak, "tek seferlik müşteri gecikmiş sayılmaz" kuralını da
/// kendiliğinden sağlar.
const int kEnAzTeslimat = 4;

/// Ritmi anlamlı sayılan aralık bandı (gün).
///
/// Alt sınır: günde birkaç kez alan bir müşterinin "döngüsü" yoktur, gürültü üretir.
/// Üst sınır: dört ayda bir alan biri için "gecikti" demek kehanettir; o müşteri zaten uykuda.
const int kEnAzOrtanca = 2;
const int kEnCokOrtanca = 120;

/// Düzensizlik tavanı: MAD (ortanca mutlak sapma) ortancanın bu oranını aşarsa müşteri DÜZENLİ
/// SAYILMAZ ve hakkında hiçbir şey söylenmez.
///
/// Aralıkları 2 · 40 · 5 gün olan birinin ortancası 5'tir ama bu sayı hiçbir şey anlatmaz —
/// böyle bir müşteriye "geciktin" demek kesin bir yanlış bildirimdir.
const double kDuzensizlikTavani = 0.5;

/// Gecikme payının ortancaya oranındaki TABAN. Çok düzenli müşteride (MAD≈0) eşik budur.
///
/// 0,4 seçildi: 15 günde bir alan müşteri 15 + 6 = 21 günü geçince, yani 22. günde bildirilir —
/// sahadan gelen örnek cümlenin ("normalde 15 günde bir alır, 22 gün oldu") tam karşılığı.
const double kTabanPayOrani = 0.4;

/// Gecikme payının üst sınırı (gün). 90 günde bir alan müşteride oransal pay 36 gün olurdu;
/// bildirim ancak 4 ay sonra çıkardı ve müşteri çoktan kaybedilmiş olurdu.
const int kEnCokPay = 30;

/// Bildirim gövdesinde en fazla kaç müşteri adı sayılır.
const int kEnCokAd = 3;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Girdi
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Tek müşterinin bildirim kararı için gereken her şeyi taşır.
///
/// SÖZLEŞME (veri katmanı bunu garanti eder):
///  • [teslimGunleri] YALNIZ TESLİM EDİLMİŞ siparişlerin günleridir. İptal edilen sipariş
///    girmez; teslim edilmemiş AÇIK sipariş de "aldı" sayılmaz — mal gitmediyse döngü dönmemiştir.
///  • Artan sırada ve GÜN çözünürlüğünde (saat sıfırlanmış) gelir.
///  • [acikSiparisVar] o an bekleyen (açık) siparişi olan müşteriyi işaretler.
class MusteriGecmisi {
  const MusteriGecmisi({
    required this.customerId,
    required this.ad,
    required this.teslimGunleri,
    this.acikSiparisVar = false,
  });

  final String customerId;
  final String ad;
  final List<DateTime> teslimGunleri;

  /// Bekleyen siparişi olan müşteri NE gecikmiştir NE de "bugün sırası" gelmiştir: zaten
  /// sipariş vermiştir, kurye yoldadır. Bunu atlamak bildirimin en utandırıcı yanlışı olurdu.
  final bool acikSiparisVar;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Ritim ölçümü
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bir müşterinin sipariş ritmi. Yalnız ÖLÇÜMDÜR — karar [gecikmisMusteriler] /
/// [rutinGunuGelenler] fonksiyonlarındadır.
class MusteriRitmi {
  const MusteriRitmi({
    required this.gecmis,
    required this.ortancaGun,
    required this.sapmaGun,
    required this.gecikmeEsigiGun,
    required this.sonTeslimdenBeriGun,
  });

  final MusteriGecmisi gecmis;

  /// Teslimatlar arası ORTANCA gün.
  ///
  /// ORTALAMA DEĞİL: 15 günde bir alan bir müşteri tatilde 90 gün ara verdiyse ortalama 30'a
  /// fırlar ve müşteri bir daha asla "gecikmiş" görünmez — kural tam da yakalaması gereken
  /// durumda kör kalır. Ortanca o tek sıçramayı yok sayar. Ölçüldü: [4, 15, 15, 90] gün
  /// aralıklarında ortalama 31, ortanca 15'tir; doğru cevap 15.
  final int ortancaGun;

  /// Ortanca mutlak sapma (MAD) — düzenlilik ölçüsü. Standart sapma DEĞİL: o da ortalamayla
  /// aynı hastalıktan (tek aykırı değere teslim olmak) muzdariptir.
  final double sapmaGun;

  /// Bu gün sayısı AŞILIRSA müşteri gecikmiş sayılır.
  final int gecikmeEsigiGun;

  final int sonTeslimdenBeriGun;

  /// Ritim güvenilir mi — değilse müşteri hakkında hiçbir bildirim üretilmez.
  bool get duzenli => sapmaGun <= kDuzensizlikTavani * ortancaGun;
}

/// Müşterinin ritmini ölçer; ölçülemiyorsa `null` (= bu müşteri hakkında SUSULUR).
///
/// `null` dönen durumlar: yeterli geçmiş yok · ritim bandın dışında · düzensiz · bekleyen
/// siparişi var. Hepsi bilinçli sessizliktir.
MusteriRitmi? musteriRitmi(MusteriGecmisi g, {required DateTime bugun}) {
  if (g.acikSiparisVar) return null;
  if (g.teslimGunleri.length < kEnAzTeslimat) return null;

  final araliklar = <int>[];
  for (var i = 1; i < g.teslimGunleri.length; i++) {
    final fark = g.teslimGunleri[i].difference(g.teslimGunleri[i - 1]).inDays;
    // Aynı gün içindeki ikinci teslimat döngü değildir (bayi siparişi ikiye bölmüştür).
    if (fark > 0) araliklar.add(fark);
  }
  if (araliklar.length < kEnAzTeslimat - 1) return null;

  final ortanca = _ortanca(araliklar.map((e) => e.toDouble()).toList());
  final ortancaGun = ortanca.round();
  if (ortancaGun < kEnAzOrtanca || ortancaGun > kEnCokOrtanca) return null;

  final sapma = _ortanca(araliklar.map((e) => (e - ortanca).abs()).toList());

  // Pay: müşterinin KENDİ değişkenliği kadar, ama en az taban oranı, en çok tavan.
  // Böylece saat gibi düzenli müşteri erken, biraz oynak müşteri geç bildirilir — ikisi de
  // kendi normaline göre ölçülür.
  final pay = math.min(
    math.max(2 * sapma, kTabanPayOrani * ortanca).round(),
    kEnCokPay,
  );

  final ritim = MusteriRitmi(
    gecmis: g,
    ortancaGun: ortancaGun,
    sapmaGun: sapma,
    gecikmeEsigiGun: ortancaGun + pay,
    sonTeslimdenBeriGun: _gunFarki(g.teslimGunleri.last, bugun),
  );
  return ritim.duzenli ? ritim : null;
}

/// Gün farkı — saat bileşeni ELENİR. Saat kalırsa "14 gün 23 saat" 14 gün görünür ve bildirim
/// bir gün kayar; esnaf sabah bakar, biz akşam hesaplarız.
int _gunFarki(DateTime once, DateTime sonra) =>
    DateTime(sonra.year, sonra.month, sonra.day)
        .difference(DateTime(once.year, once.month, once.day))
        .inDays;

double _ortanca(List<double> x) {
  final s = [...x]..sort();
  final orta = s.length ~/ 2;
  return s.length.isOdd ? s[orta] : (s[orta - 1] + s[orta]) / 2;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Seçim — iki kural, ÇAKIŞMAYAN iki pencere
// ═══════════════════════════════════════════════════════════════════════════════════════════
//
// Zaman çizgisi (son teslimden beri geçen gün):
//
//   0 ────────── ortanca ────────── eşik ──────────▶
//        (erken)     ▲      (bekleme payı)   ▲
//                    │                       │
//              RUTİN GÜNÜ              GECİKMİŞ (eşiği AŞANLAR)
//              (tam eşitlik)
//
// Rutin kuralı "gün farkı ORTANCAYA EŞİT" der — bir gün, bir kez. Gecikme kuralı "eşiği AŞTI"
// der. Ortanca < eşik her zaman doğru olduğundan (pay daima pozitif) iki küme KESİŞMEZ; aynı
// müşteri aynı gün iki bildirime giremez. Aradaki bant bilinçli sessizliktir: müşteri
// gecikmiş sayılacak kadar geç değildir, "bugün sırası" da geçmiştir.

/// Eşiği aşmış müşteriler — en çok gecikeni başta (gecikme/eşik oranına göre).
///
/// Oran kullanılır, ham gün DEĞİL: 7 günde bir alan müşterinin 10 günlük sessizliği, 60 günde
/// bir alanın 70 günlük sessizliğinden daha alarm vericidir.
List<MusteriRitmi> gecikmisMusteriler(
  List<MusteriGecmisi> musteriler, {
  required DateTime bugun,
}) {
  final sonuc = <MusteriRitmi>[];
  for (final m in musteriler) {
    final r = musteriRitmi(m, bugun: bugun);
    if (r != null && r.sonTeslimdenBeriGun > r.gecikmeEsigiGun) sonuc.add(r);
  }
  sonuc.sort((a, b) => (b.sonTeslimdenBeriGun / b.gecikmeEsigiGun)
      .compareTo(a.sonTeslimdenBeriGun / a.gecikmeEsigiGun));
  return sonuc;
}

/// Bugün rutin teslim sırası gelenler — ada göre (liste her gün aynı düzende okunsun).
List<MusteriRitmi> rutinGunuGelenler(
  List<MusteriGecmisi> musteriler, {
  required DateTime bugun,
}) {
  final sonuc = <MusteriRitmi>[];
  for (final m in musteriler) {
    final r = musteriRitmi(m, bugun: bugun);
    if (r != null && r.sonTeslimdenBeriGun == r.ortancaGun) sonuc.add(r);
  }
  sonuc.sort((a, b) => a.gecmis.ad.compareTo(b.gecmis.ad));
  return sonuc;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Bildirim metni
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// TEK taslak döner, müşteri BAŞINA bir tane DEĞİL.
///
/// 20 müşteri gecikmişse 20 bildirim atmak bildirim rafını çöpe çevirir ve bayi tümünü birden
/// kapatır — özellik bir daha geri gelmez. Üstelik sözleşmede kategori başına GÜNLÜK 2 sınırı
/// var: üçüncü müşteri zaten sessizce düşerdi. Onun yerine tek özet + en kritik üç ad.
///
/// Gecikme yoksa `null`: "bugün gecikme yok" diye bildirim atmak da gürültüdür.
///
/// Kimlik GÜN bazlıdır ([bildirimGunAnahtari]): gün içinde kaç kez hesaplanırsa hesaplansın
/// aynı bildirim tazelenir, yenisi doğmaz ve bütçeden ikinci kez düşmez.
BildirimTaslagi? gecikmisMusteriBildirimi(
  List<MusteriGecmisi> musteriler, {
  required DateTime bugun,
}) {
  final gecikenler = gecikmisMusteriler(musteriler, bugun: bugun);
  if (gecikenler.isEmpty) return null;

  final kimlik = bildirimKimligi(
      BildirimKategori.musteriGecikti, bildirimGunAnahtari(bugun));

  if (gecikenler.length == 1) {
    final r = gecikenler.first;
    return BildirimTaslagi(
      kategori: BildirimKategori.musteriGecikti,
      // Başlık bildirim rafında bir bakışta okunur → ad taşımaz (bkz. dosya başlığı).
      baslik: 'Bir müşteri gecikti',
      govde: '${r.gecmis.ad} ${r.sonTeslimdenBeriGun} gündür sipariş vermedi · '
          'normalde ${r.ortancaGun} günde bir alıyordu.',
      kimlik: kimlik,
      yol: 'musteri/${r.gecmis.customerId}',
    );
  }

  final adlar = gecikenler
      .take(kEnCokAd)
      .map((r) => '${r.gecmis.ad} (${r.sonTeslimdenBeriGun} gün)')
      .join(', ');
  final kalan = gecikenler.length - kEnCokAd;
  return BildirimTaslagi(
    kategori: BildirimKategori.musteriGecikti,
    // Sayı kişisel veri değildir; hiçbir müşteriyi ele vermez.
    baslik: '${gecikenler.length} müşteri gecikti',
    govde: kalan > 0 ? '$adlar · ve $kalan kişi daha' : adlar,
    kimlik: kimlik,
    // Faz 1 yol sözlüğünde çok-müşterili bir liste rotası YOK; uydurmak yerine boş bırakılır
    // (uygulama ana ekranda açılır).
    yol: null,
  );
}

/// Sabah özeti — bugün rutin sırası gelenler. Kimse yoksa `null` (sessizlik).
BildirimTaslagi? rutinTeslimBildirimi(
  List<MusteriGecmisi> musteriler, {
  required DateTime bugun,
}) {
  final gelenler = rutinGunuGelenler(musteriler, bugun: bugun);
  if (gelenler.isEmpty) return null;

  final kimlik = bildirimKimligi(
      BildirimKategori.rutinTeslimGunu, bildirimGunAnahtari(bugun));
  final baslik = 'Bugün ${gelenler.length} rutin teslim var';

  if (gelenler.length == 1) {
    final r = gelenler.first;
    return BildirimTaslagi(
      kategori: BildirimKategori.rutinTeslimGunu,
      baslik: baslik,
      govde: '${r.gecmis.ad} · normalde ${r.ortancaGun} günde bir alıyor.',
      kimlik: kimlik,
      yol: 'musteri/${r.gecmis.customerId}',
    );
  }

  final adlar = gelenler.take(kEnCokAd).map((r) => r.gecmis.ad).join(', ');
  final kalan = gelenler.length - kEnCokAd;
  return BildirimTaslagi(
    kategori: BildirimKategori.rutinTeslimGunu,
    baslik: baslik,
    govde: kalan > 0 ? '$adlar · ve $kalan kişi daha' : adlar,
    kimlik: kimlik,
    yol: null,
  );
}
