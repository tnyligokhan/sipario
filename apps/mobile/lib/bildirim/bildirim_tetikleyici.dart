// TETİKLEME — kuralları KİM ve NE ZAMAN çağırır.
//
// İki kural dosyası (`kurallar/para_kurallari.dart`, `kurallar/musteri_kurallari.dart`) SAF:
// hazır veri alır, taslak döndürür. Zamanlama kararı onlarda değil burada; veri okuma da
// burada değil, enjekte edilen ÜRETİCİLERDE (`TaslakUretici`). Böylece bu dosya ne Drift'i
// ne de kuralların iç yapısını tanır — üçü de birbirinden bağımsız test edilebilir.
//
// PİL YÖNETİMİNE KARŞI DURUŞ (BRIEF korku #1'in bildirim karşılığı): Xiaomi/Redmi zamanlanmış
// bildirimi öldürebilir ve bunu ENGELLEYEMEYİZ. O yüzden tarama işleri AÇILIŞTA DA koşar.
// Bu güvenli, çünkü kural kimlikleri GÜN damgalıdır: gün içinde kaç kez koşarsa koşsun aynı
// bildirim tazelenir, yenisi doğmaz ve günlük bütçeden ikinci kez düşmez.

import 'package:flutter/foundation.dart';

import 'bildirim_sozlesmesi.dart';
import 'kurallar/para_kurallari.dart' show kGunSonuSaati, kVadeTaramaGunu, kVadeTaramaSaati;

/// Bir kuralın taslağını üreten fonksiyon. Veri okuma bunun içindedir; null = bildirim yok.
typedef TaslakUretici = Future<BildirimTaslagi?> Function();

/// Kuralları doğru anda çağıran ince katman.
class BildirimTetikleyici {
  const BildirimTetikleyici({
    required this.servis,
    this.gecikmisMusteri,
    this.rutinTeslim,
    this.borcEsigi,
    this.gunSonu,
    this.vadesiGecen,
  });

  final BildirimServisi servis;

  /// ANLIK taramalar — açılışta koşar, gün damgalı oldukları için tekrar güvenlidir.
  final TaslakUretici? gecikmisMusteri;
  final TaslakUretici? rutinTeslim;
  final TaslakUretici? borcEsigi;

  /// ZAMANLANAN işler — günün belirli saatine kurulur.
  final TaslakUretici? gunSonu;
  final TaslakUretici? vadesiGecen;

  /// Uygulama açılışında çağrılır. Hem anlık taramaları koşar hem günün zamanlamalarını kurar.
  ///
  /// HATA YUTAR: tek bir üretici patlarsa diğerleri koşmaya devam eder — bildirim bir
  /// kolaylıktır, açılışı bloke edemez ve birbirini düşüremez.
  Future<void> acilistaKos({DateTime? simdi}) async {
    final an = simdi ?? DateTime.now();

    await _anlik(gecikmisMusteri, 'gecikmisMusteri');
    await _anlik(rutinTeslim, 'rutinTeslim');
    await _anlik(borcEsigi, 'borcEsigi');

    await _zamanla(gunSonu, gunSonuAni(an), 'gunSonu');
    await _zamanla(vadesiGecen, vadeTaramaAni(an), 'vadesiGecen');
  }

  Future<void> _anlik(TaslakUretici? uretici, String ad) async {
    if (uretici == null) return;
    try {
      final taslak = await uretici();
      if (taslak != null) await servis.goster(taslak);
    } on Object catch (e) {
      debugPrint('Bildirim kuralı koşulamadı ($ad): $e');
    }
  }

  Future<void> _zamanla(TaslakUretici? uretici, DateTime neZaman, String ad) async {
    if (uretici == null) return;
    try {
      final taslak = await uretici();
      if (taslak != null) await servis.zamanla(taslak, neZaman);
    } on Object catch (e) {
      debugPrint('Bildirim kuralı zamanlanamadı ($ad): $e');
    }
  }

  // ── Zamanlama hesapları (SAF, testli) ────────────────────────────────────────────────────

  /// Gün sonu özetinin anı: bugünün [kGunSonuSaati] saati; o saat GEÇTİYSE yarınki.
  ///
  /// Geçmiş bir ana zamanlamak bildirimi anında ateşler; bayi akşam 21:00'de uygulamayı
  /// açtığında "gün sonu özeti" diye bir bildirim patlaması yaşanırdı.
  static DateTime gunSonuAni(DateTime simdi) {
    final bugun = DateTime(simdi.year, simdi.month, simdi.day, kGunSonuSaati);
    return simdi.isBefore(bugun) ? bugun : bugun.add(const Duration(days: 1));
  }

  /// Vade taramasının anı: SIRADAKİ [kVadeTaramaGunu] gününün [kVadeTaramaSaati] saati.
  /// Bugün o günse ve saat geçmemişse bugündür.
  static DateTime vadeTaramaAni(DateTime simdi) {
    final bugunHedef =
        DateTime(simdi.year, simdi.month, simdi.day, kVadeTaramaSaati);
    if (simdi.weekday == kVadeTaramaGunu && simdi.isBefore(bugunHedef)) {
      return bugunHedef;
    }
    // Haftanın sıradaki tarama gününe kaydır (bugünse +7).
    var fark = (kVadeTaramaGunu - simdi.weekday) % 7;
    if (fark == 0) fark = 7;
    return bugunHedef.add(Duration(days: fark));
  }
}
