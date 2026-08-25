// SESSİZ SAATLER ve GÜNLÜK SINIR — bildirim yorgunluğuna karşı iki SAF kural.
//
// NEDEN AYRI DOSYA: `bildirim_sozlesmesi.dart` 504 satıra çıkmıştı (500 satır kuralı). Bu iki
// kuralın ortak yanı, sözleşmenin geri kalanından farklı bir soruyu cevaplamalarıdır:
// sözleşme "bildirim NE DER" der, burası "bildirim GÖNDERİLİR Mİ" der. İkisi de saf
// fonksiyondur — altyapı da testler de aynı fonksiyonu çağırır, ikinci bir kopya yoktur.
//
// ⚠️ SESSİZ SAATE DÜŞEN BİLDİRİM ATILMAZ, ERTELENİR: bilgi kaybolmaz, yalnız sabaha kalır.
// Atmak, esnafın gece gelen bir siparişi hiç görmemesi demek olurdu.
//
// SÖZLEŞME KORUNDU: `bildirim_sozlesmesi.dart` bu dosyayı yeniden dışa aktarır — mevcut
// import yolları ve testler aynen çalışır.

import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sessiz saatler — SAF kural, altyapı da testler de aynı fonksiyonu kullanır
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Gece bildirim yok. Esnaf 22:00'den sonra iş bildirimi istemez; istemediği bildirim
/// hepsini birden kapattırır.
///
/// Sessiz saate düşen bildirim ATILMAZ, ERTELENİR — bilgi kaybolmaz, yalnız sabaha kalır.
@immutable
class SessizSaatler {
  const SessizSaatler({this.baslangicSaat = 22, this.bitisSaat = 8});

  /// Gece yarısını AŞAN aralık (22 → 8) normaldir ve desteklenir.
  final int baslangicSaat;
  final int bitisSaat;

  bool get kapali => baslangicSaat == bitisSaat;

  bool icindeMi(DateTime an) {
    if (kapali) return false;
    final s = an.hour;
    // 22→8 gibi gece yarısını aşan aralık: "22'den büyük VEYA 8'den küçük".
    if (baslangicSaat > bitisSaat) return s >= baslangicSaat || s < bitisSaat;
    return s >= baslangicSaat && s < bitisSaat;
  }

  /// [an] sessiz saatteyse ertelenecek ilk uygun an (aynı gün ya da ertesi sabah [bitisSaat]),
  /// değilse [an]'ın kendisi.
  DateTime ertelenmisAn(DateTime an) {
    if (!icindeMi(an)) return an;
    final bugunBitis = DateTime(an.year, an.month, an.day, bitisSaat);
    // Sabahın erken saatindeysek (ör. 03:00) bugünün 08:00'i; akşamsa yarının 08:00'i.
    return an.isBefore(bugunBitis)
        ? bugunBitis
        : DateTime(an.year, an.month, an.day + 1, bitisSaat);
  }
}

