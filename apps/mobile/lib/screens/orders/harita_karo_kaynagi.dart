// HARİTA KAROSUNUN KAYNAĞI — kendi sunucumuz (2026-09-26 saha arızası).
//
// YAŞANAN: haritada her karonun yerinde "API KEY REQUIRED" yazıyordu. CARTO anahtarsız karo
// vermeyi kesmiş; anahtarsız istek 200 ile filigran görsel döndürüyor (ölçüldü). Env'deki hiçbir
// anahtar bu isteğe uğramıyordu çünkü telefon karoyu DOĞRUDAN CARTO'dan çekiyordu.
//
// ÇÖZÜM: karo artık `GET <api>/harita/karo/...` üzerinden gelir. Sunucu CARTO anahtarını ekler ve
// karoyu önbelleğe alır — anahtar APK'ya gömülmez (coğrafi kodlamadaki kuralın aynısı). Oturum
// jetonu istenir: açık bir aracı, kotamızı herkesin bedava karo sunucusu yapardı.

import '../../auth/session.dart';
import '../../data/app_database.dart';

/// Karo adresi + istek başlıkları. Değer nesnesidir: aynı oturumda eşit iki kaynak aynı katmanı
/// üretir, jeton ya da adres değişince katman yenilenir.
class HaritaKaroKaynagi {
  const HaritaKaroKaynagi({required this.apiTaban, this.jeton});

  /// Senkron durumundan — API adresi ve oturum jetonu oradadır.
  factory HaritaKaroKaynagi.meta(SyncMetaData meta) => HaritaKaroKaynagi(
    apiTaban: Session.baseUrlOf(meta),
    jeton: meta.authToken,
  );

  /// Sonunda `/` olmayan API kökü (ör. `https://sipario.com.tr/api/v1`).
  final String apiTaban;

  /// Oturum jetonu; null ise karo isteği 401 alır ve harita gri kalır (pinler durur).
  final String? jeton;

  /// flutter_map şablonu. `{r}` yüksek yoğunluklu ekranda "@2x" olur, aksi hâlde boş kalır.
  /// Açık tema Positron (`light_all`), koyu tema Dark Matter (`dark_all`).
  String sablon({required bool koyu}) =>
      '$apiTaban/harita/karo/${koyu ? 'dark_all' : 'light_all'}/{z}/{x}/{y}{r}.png';

  /// Her karo isteğine eklenecek başlıklar.
  Map<String, String> get basliklar => {
    if (jeton != null) 'Authorization': 'Bearer $jeton',
  };

  @override
  bool operator ==(Object other) =>
      other is HaritaKaroKaynagi &&
      other.apiTaban == apiTaban &&
      other.jeton == jeton;

  @override
  int get hashCode => Object.hash(apiTaban, jeton);
}
