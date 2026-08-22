// HEADS-UP GERÇEKTEN ÇALIŞIYOR MU — ÖLÇÜM KATMANI (kullanıcı isteği 2026-08-22).
//
// ══ NEDEN VAR ══════════════════════════════════════════════════════════════════════════════
// Kullanıcı sahadan şunu bildirdi: *"heads-up bildirimler yapılacaktı fakat onlar yok"*.
// Kodda heads-up KURULUYDU (`BildirimKategori.headsUp` → kanal `IMPORTANCE_HIGH` ile doğuyor),
// yani "yapılmamış" değildi. Ama bu iki ayrı sorudur ve bu depoda daha önce de karıştırıldı
// (ses dosyaları derlenmişti, APK'ya girmemişti):
//
//     KURULDU MU?            →  koddan okunur, testle kilitlenir
//     CİHAZDA ÇALIŞIYOR MU?  →  yalnız CİHAZDAN ölçülür
//
// Uygulama bir kanalın önemini DOĞUŞTAN SONRA yükseltemez (Android kuralı: kullanıcının kıstığı
// bildirimi uygulama arkadan dolanıp geri açamaz). Üstelik bu ürünün ana pazarında (BRIEF:
// Xiaomi/Redmi/Poco hâkim) "kayan bildirim" uygulama başına KAPALI gelebiliyor. Yani heads-up'ın
// olmaması çoğu zaman bir KOD arızası değil, bir CİHAZ AYARIDIR — ve bugüne kadar ikisini
// ayırt edecek tek bir veri bile yoktu.
//
// Bu dosya o veriyi getirir: her kanalın O ANKİ önem derecesi. Ayarlar ekranı artık tahmin
// etmez; "bu bildirim ekranın üstünde belirmiyor" diyebilir ve düzelteceği ekranı açabilir.
//
// ══ PLATFORM YOKSA SESSİZCE PASİFLEŞİR ═════════════════════════════════════════════════════
// Widget testlerinde ve iOS'ta kanal yoktur. Bu deponun yerleşik kuralı (bkz.
// `YerelBildirimServisi._android` ve `tutamac_deposu`): platform yoksa özellik susar, uygulama
// çalışmaya devam eder. Burada karşılığı [KanalDurumu.bilinmiyor]dur — "kapalı" DEĞİL, çünkü
// ölçülemeyen bir şeyi arızalı ilan etmek yanlış uyarı üretir.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bildirim_sozlesmesi.dart';

/// Sihirbazın da kullandığı native kanal — ikinci bir kanal açmak, aynı köprüyü iki yerde
/// tanımlamak olurdu.
@visibleForTesting
const MethodChannel kBildirimKanali = MethodChannel('sipario/phase0');

/// Android `NotificationManager.IMPORTANCE_HIGH`. Heads-up bunun ALTINDA çalışmaz.
const int kOnemYuksek = 4;

/// Tek bir kategorinin cihazdaki gerçek durumu.
@immutable
class KanalDurumu {
  const KanalDurumu({required this.onem, required this.uygulamaAcik});

  /// Android önem sabiti. `null` = ölçülemedi (platform yok ya da kanal henüz kurulmadı).
  final int? onem;

  /// Uygulamanın bildirimleri sistemden tamamen kapatılmış mı.
  final bool uygulamaAcik;

  static const bilinmiyor = KanalDurumu(onem: null, uygulamaAcik: true);

  /// Bu kanal ekranın üstünde belirir mi?
  ///
  /// ÖLÇÜLEMEDİYSE `null` DÖNER, `false` DEĞİL: "bilmiyorum" ile "çalışmıyor" ayrı şeylerdir
  /// ve ikincisini uydurmak, hiçbir sorunu olmayan bayiye yanlış bir uyarı göstermek olurdu.
  bool? get headsUpCalisir {
    if (!uygulamaAcik) return false;
    final o = onem;
    if (o == null) return null;
    return o >= kOnemYuksek;
  }
}

/// Bütün kanalların cihazdaki gerçek durumu — kategori bazında.
///
/// Platform yoksa ya da çağrı düşerse HER kategori [KanalDurumu.bilinmiyor] döner: ölçüm
/// katmanının kendisi bir arıza kaynağı olamaz.
Future<Map<BildirimKategori, KanalDurumu>> kanalDurumlariniOku({
  MethodChannel kanal = kBildirimKanali,
}) async {
  Map<Object?, Object?>? yanit;
  try {
    yanit = await kanal.invokeMapMethod<Object?, Object?>('notificationChannels');
  } on Object catch (e) {
    debugPrint('Bildirim kanalları okunamadı (platform yok?): $e');
  }

  if (yanit == null) {
    return {for (final k in BildirimKategori.values) k: KanalDurumu.bilinmiyor};
  }

  final acik = yanit['acik'] as bool? ?? true;
  final ham = (yanit['kanallar'] as Map<Object?, Object?>?) ?? const {};
  final onemler = <String, int>{
    for (final e in ham.entries)
      if (e.value is int) '${e.key}': e.value! as int,
  };

  return {
    for (final k in BildirimKategori.values)
      // KANAL KİMLİĞİ `wire` DEĞİL: sesin/önemin sürümlenebilmesi için `${wire}_v2` kullanılıyor
      // (gerekçe `BildirimKategori.kanalKimligi`). Burada `wire` aranırsa hiçbir kanal bulunamaz
      // ve ölçüm sessizce "bilinmiyor" döner — sessiz yanlış, en pahalı arıza sınıfı.
      k: KanalDurumu(onem: onemler[k.kanalKimligi], uygulamaAcik: acik),
  };
}

/// Tek bir kanalın SİSTEM ayarını açar (kullanıcı önemi oradan yükseltir).
///
/// Uygulama önemi kendisi yükseltemez; yapabileceği tek şey kullanıcıyı doğru ekrana
/// götürmektir. Tarif okutmak ("Ayarlar → Uygulamalar → Sipario → Bildirimler → …") bu
/// kullanıcı kitlesinde işe yaramaz (BRIEF: teknoloji toleransı düşük).
Future<void> kanalAyariniAc(
  BildirimKategori kategori, {
  MethodChannel kanal = kBildirimKanali,
}) async {
  try {
    await kanal.invokeMethod<void>(
      'openNotificationChannelSettings',
      {'channel': kategori.kanalKimligi},
    );
  } on Object catch (e) {
    debugPrint('Kanal ayarı açılamadı: $e');
  }
}
