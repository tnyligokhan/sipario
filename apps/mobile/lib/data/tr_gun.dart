library;

import 'app_database.dart';

/// GÜN SINIRININ TEK TANIMI (inceleme bulgusu #9, 2026-08-06).
///
/// Kural SABİT +03:00'tür (Türkiye, 2016'dan beri DST yok): `occurred_at` (UTC ISO) +3 saat
/// kaydırılıp yerel takvim günü çıkarılır. Sabit offset DST karmaşasını kökten kapatır.
///
/// NEDEN TEK DOSYA: bu kural bir zamanlar DÖRT yerde kopyalanmıştı (`DayEndRepository`,
/// `CashHandoverRepository`, `DayClosingRepository`, `gun_sonu_ozet`). Kopyalardan birini
/// güncellemeyi unutmak, iki ekranın farklı gün konuşması demekti — ve hiçbir test bunu
/// yakalamazdı, çünkü her kopya kendi içinde tutarlı kalırdı.

const Duration kTrOffset = Duration(hours: 3);

/// Bir ANIN düştüğü TR takvim günü (saat sıfırlanmış, yerel DateTime olarak).
DateTime trGunu(DateTime an) {
  final tr = an.toUtc().add(kTrOffset);
  return DateTime(tr.year, tr.month, tr.day);
}

/// Bu AN verilen TR takvim gününe mi düşüyor?
bool ayniTrGunAn(DateTime an, DateTime gun) {
  final tr = an.toUtc().add(kTrOffset);
  return tr.year == gun.year && tr.month == gun.month && tr.day == gun.day;
}

/// Bu UTC ISO damgası verilen TR takvim gününe mi düşüyor? Okunamayan damga HİÇBİR güne düşmez.
bool ayniTrGunIso(String iso, DateTime gun) {
  final t = DateTime.tryParse(iso);
  return t != null && ayniTrGunAn(t, gun);
}

/// TR gününün başlangıcının GERÇEK UTC karşılığı (occurred_at ile karşılaştırılabilir).
DateTime trGunBasiUtc(DateTime gun) =>
    DateTime.utc(gun.year, gun.month, gun.day).subtract(kTrOffset);

/// Bugünün TR günü — DÜZELTİLMİŞ SUNUCU SAATİNDEN (inceleme bulgusu #4, 2026-08-06).
///
/// Kayıtlar `correctedNowIso(serverTimeOffsetMs)` ile yazılıyor; gün sınırı da aynı saatten
/// türemek ZORUNDA. Cihaz saati 40 dk ileriyken 23:40'ta ham `DateTime.now()` YARINI hesaplar
/// ama kayıt BUGÜNE düşerdi — ekran ile defter farklı gün konuşurdu. Bu ürün zaten cihaz saatine
/// güvenmiyor (`correctedNowIso` tam olarak bunun için var); gün sınırı o disiplinin dışında
/// kalmıştı.
Future<DateTime> bugunTrDuzeltilmis(AppDatabase db) async {
  final meta = await db.syncState();
  return trGunu(DateTime.now().toUtc().add(Duration(milliseconds: meta.serverTimeOffsetMs)));
}
