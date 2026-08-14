// TETİKLEME — yerel kuralları KİM ve NE ZAMAN çağırır.
//
// Kural dosyaları (`kurallar/*_kurallari.dart`) SAF: hazır veri alır, taslak döndürür.
// Zamanlama kararı onlarda değil burada; veri okuma da burada değil, enjekte edilen
// ÜRETİCİLERDE (`TaslakUretici`). Böylece bu dosya ne Drift'i ne de kuralların iç yapısını
// tanır — üçü de birbirinden bağımsız test edilebilir.
//
// PİL YÖNETİMİNE KARŞI DURUŞ (BRIEF korku #1'in bildirim karşılığı): Xiaomi/Redmi zamanlanmış
// bildirimi öldürebilir ve bunu ENGELLEYEMEYİZ. O yüzden ANLIK işler AÇILIŞTA DA koşar.
// Bu güvenli, çünkü kural kimlikleri GÜN damgalıdır: gün içinde kaç kez koşarsa koşsun aynı
// bildirim tazelenir, yenisi doğmaz ve günlük bütçeden ikinci kez düşmez.
//
// ⚠️ SUNUCUDAN GELEN BİLDİRİMLER BURADAN GEÇMEZ. Push'un yolu ayrıdır (`bildirim/push/`):
// dürtü geldiğinde senkron koşar ve taslak orada üretilir. Buradaki liste YALNIZ telefonun
// kendi verisinden türeyen kurallardır.

import 'package:flutter/foundation.dart';

import 'bildirim_sozlesmesi.dart';

/// Bir kuralın taslağını üreten fonksiyon. Veri okuma bunun içindedir; null = bildirim yok.
typedef TaslakUretici = Future<BildirimTaslagi?> Function();

/// Zamanlanmış bir iş: üretici + o işin günün hangi anına kurulacağı.
///
/// NEDEN LİSTE, NEDEN ADLANDIRILMIŞ PARAMETRE DEĞİL: bu tetikleyici bir kez sabit alanlarla
/// (`gecikmisMusteri`, `rutinTeslim`, …) yazıldı ve kural sayısı her değiştiğinde imza da
/// değişti — kural silinince alan öksüz kaldı, eklenince imza büyüdü. Liste, kural sayısını
/// tetikleyicinin meselesi olmaktan çıkarır.
@immutable
class ZamanlanmisIs {
  const ZamanlanmisIs({
    required this.ad,
    required this.uretici,
    required this.an,
  });

  /// Yalnız günlük/tanı için — hangi kuralın patladığı log'da görünsün.
  final String ad;

  final TaslakUretici uretici;

  /// Verilen ANA göre bu işin kurulacağı zaman. Geçmiş bir an DÖNDÜRÜLMEMELİDİR: sistem onu
  /// anında ateşler ve bayi uygulamayı açar açmaz bildirim patlaması yaşar.
  final DateTime Function(DateTime simdi) an;
}

/// Kuralları doğru anda çağıran ince katman.
class BildirimTetikleyici {
  const BildirimTetikleyici({
    required this.servis,
    this.anlik = const [],
    this.zamanlanan = const [],
  });

  final BildirimServisi servis;

  /// AÇILIŞTA koşan taramalar. Kimlikleri gün damgalı olduğu için tekrar güvenlidir.
  final List<TaslakUretici> anlik;

  /// Günün belirli anlarına kurulan işler.
  final List<ZamanlanmisIs> zamanlanan;

  /// Uygulama açılışında çağrılır. Hem anlık taramaları koşar hem günün zamanlamalarını kurar.
  ///
  /// HATA YUTAR: tek bir üretici patlarsa diğerleri koşmaya devam eder — bildirim bir
  /// kolaylıktır, açılışı bloke edemez ve birbirini düşüremez.
  Future<void> acilistaKos({DateTime? simdi}) async {
    final an = simdi ?? DateTime.now();

    for (var i = 0; i < anlik.length; i++) {
      await _anlik(anlik[i], 'anlik#$i');
    }

    for (final is_ in zamanlanan) {
      await _zamanla(is_.uretici, is_.an(an), is_.ad);
    }
  }

  Future<void> _anlik(TaslakUretici uretici, String ad) async {
    try {
      final taslak = await uretici();
      if (taslak != null) await servis.goster(taslak);
    } on Object catch (e) {
      debugPrint('Bildirim kuralı koşulamadı ($ad): $e');
    }
  }

  Future<void> _zamanla(TaslakUretici uretici, DateTime neZaman, String ad) async {
    try {
      final taslak = await uretici();
      if (taslak != null) await servis.zamanla(taslak, neZaman);
    } on Object catch (e) {
      debugPrint('Bildirim kuralı zamanlanamadı ($ad): $e');
    }
  }

  // ── Zamanlama hesapları (SAF, testli) ────────────────────────────────────────────────────

  /// Bugünün [saat]'i; o saat GEÇTİYSE yarınki.
  ///
  /// Geçmiş bir ana zamanlamak bildirimi anında ateşler; bayi akşam 21:00'de uygulamayı
  /// açtığında "gün sonu özeti" diye bir bildirim patlaması yaşanırdı.
  static DateTime gunlukAn(DateTime simdi, int saat) {
    final bugun = DateTime(simdi.year, simdi.month, simdi.day, saat);
    return simdi.isBefore(bugun) ? bugun : bugun.add(const Duration(days: 1));
  }
}
