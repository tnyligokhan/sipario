// UYGULAMA İÇİ GÜNCELLEME — sözleşme ve SAF kurallar.
//
// GEÇİCİ ÖZELLİK (kullanıcı kararı 2026-07-28): pilot bayilere sürekli APK yollamamak için.
// Mağaza sürümüne çıkıldığında güncellemeyi Play yapacak ve bu modül tamamen ölecek. O yüzden
// her şey `saha` kanalına kapalı: `magaza` derlemesinde tek satırı bile koşmaz.
//
// Bu dosya AĞA, DOSYAYA ve PLATFORMA DOKUNMAZ — yalnız veri ve karar. Böylece sürüm
// karşılaştırması ve JSON çözümlemesi düz `test()` ile sınanabiliyor.
//
// SUNUCU SÖZLEŞMESİ (lead'in CI işhattı üretir, GitHub Releases `saha` etiketinde durur):
// ```json
// {
//   "yapim": 128,
//   "surum": "0.9.0",
//   "apk_arm64": "https://.../saha-arm64.apk",
//   "apk_evrensel": "https://.../saha-evrensel.apk",
//   "boyut_arm64": 30204268,
//   "boyut_evrensel": 79600000
// }
// ```

import 'dart:convert';

/// Güncelleme bilgisinin çekildiği SABİT adres. Etiket yuvarlanır (`saha`), varlık adları
/// sabittir; yani URL hiç değişmez ve uygulamaya gömülebilir.
const String kSurumJsonAdresi =
    'https://github.com/tnyligokhan/sipario/releases/download/saha/surum.json';

/// Dağıtım kanalı — derleme sabiti (`--dart-define=SIPARIO_KANAL=saha`).
/// Tanımsızsa `magaza` sayılır: güncelleme yolu KAPALI varsayılan güvenlidir.
const String kKanal = String.fromEnvironment('SIPARIO_KANAL', defaultValue: 'magaza');

/// Bu derlemenin yapı numarası — `--dart-define=SIPARIO_YAPIM=<git commit sayısı>`.
///
/// NEDEN `PackageInfo.buildNumber` DEĞİL (2026-07-28, ölçüldü): `--split-per-abi` ile Flutter
/// versionCode'a ABI sapması ekliyor (v7a +1000, arm64 +2000, x86_64 +4000). Git sayacı 128
/// iken arm64 APK kendini 2128 bildiriyor. Karşılaştırma buna dayansaydı arm64 cihaz sunucuyu
/// (128) hep "eski" görüp BİR DAHA ASLA güncellenmezdi. Sapmayı gradle'dan geri alma denemesi
/// işe yaramadı (Flutter eklentisi `afterEvaluate`te eziyor), bu yüzden sayı derleme sabiti
/// olarak geçiliyor — sapmadan tamamen bağımsız.
///
/// 0 = tanımsız: yerel/geliştirme derlemesi. Güncelleme kontrolü HİÇ koşmaz, bayi dürtülmez.
const int kYapim = int.fromEnvironment('SIPARIO_YAPIM');

/// Güncelleme kontrolü bu derlemede çalışmalı mı?
///
/// İKİ KAPI birden: kanal `saha` OLACAK ve yapı numarası bilinecek. Mağaza derlemesinde ağa
/// hiç çıkılmaz; yapı numarası bilinmeyen bir derlemede karşılaştırma anlamsızdır.
bool get guncellemeKapaliMi => kKanal != 'saha' || kYapim <= 0;

/// Sunucudaki sürümün bilgisi.
class SurumBilgisi {
  const SurumBilgisi({
    required this.yapim,
    required this.surum,
    required this.apkArm64,
    required this.apkEvrensel,
    required this.boyutArm64,
    required this.boyutEvrensel,
  });

  /// Git commit sayısı — tek karşılaştırma ölçütü.
  final int yapim;

  /// Gösterim için sürüm adı ("0.9.0").
  final String surum;

  final String apkArm64;
  final String apkEvrensel;

  /// Beklenen dosya boyutları (bayt). İnen dosya bunu tutmuyorsa KURULMAZ.
  final int boyutArm64;
  final int boyutEvrensel;

  /// Cihazın ABI listesine göre indirilecek APK. arm64 varsa küçük olanı, yoksa evrensel.
  ///
  /// [abiler] native taraftan (`Build.SUPPORTED_ABIS`) gelir — Dart'ta güvenilir ABI bilgisi yok.
  /// Liste boşsa (köprü cevap vermedi) EVRENSEL seçilir: büyük ama her cihazda çalışır.
  ({String url, int boyut}) indirilecek(List<String> abiler) =>
      abiler.contains('arm64-v8a')
          ? (url: apkArm64, boyut: boyutArm64)
          : (url: apkEvrensel, boyut: boyutEvrensel);

  /// JSON'dan çözer. Eksik/bozuk alan varsa `null` — güncelleme SESSİZCE atlanır, çökmez.
  static SurumBilgisi? cozumle(String ham) {
    try {
      final j = jsonDecode(ham);
      if (j is! Map) return null;
      final yapim = _tamsayi(j['yapim']);
      final surum = j['surum'];
      final arm = j['apk_arm64'];
      final evrensel = j['apk_evrensel'];
      if (yapim == null || yapim <= 0) return null;
      if (surum is! String || arm is! String || evrensel is! String) return null;
      if (arm.isEmpty || evrensel.isEmpty) return null;
      return SurumBilgisi(
        yapim: yapim,
        surum: surum,
        apkArm64: arm,
        apkEvrensel: evrensel,
        // Boyut ZORUNLU DEĞİL: yoksa 0 kalır ve bütünlük kontrolü atlanır. Eski bir
        // `surum.json` yüzünden güncellemenin tamamen durması, kontrolsüz kurmaktan da
        // beklemekten de kötü olurdu.
        boyutArm64: _tamsayi(j['boyut_arm64']) ?? 0,
        boyutEvrensel: _tamsayi(j['boyut_evrensel']) ?? 0,
      );
    } on Object {
      return null;
    }
  }

  static int? _tamsayi(Object? v) => switch (v) {
        int i => i,
        String s => int.tryParse(s),
        _ => null,
      };
}

/// Güncelleme var mı? SAF kural, tek karar noktası.
///
/// Katı büyüktür: eşitse güncelleme yoktur. Küçükse de yoktur — cihazda sunucudan YENİ bir
/// derleme olabilir (geliştirici telefonu, elle kurulmuş APK); onu "güncelle" diye geri
/// sürüme düşürmek veri kaybı riski taşır.
bool guncellemeVarMi({required int yerelYapim, required int uzakYapim}) =>
    yerelYapim > 0 && uzakYapim > yerelYapim;

/// İnen dosya sağlam mı? Beklenen boyut bilinmiyorsa (0) kontrol ATLANIR.
///
/// Yarım inen APK'yı kurmaya kalkmak, kurucunun anlamsız bir hata vermesi ve bayinin
/// "güncelleme bozuk" demesi demektir. Boyut karşılaştırması ucuz ve kesin.
bool indirmeSaglamMi({required int inenBayt, required int beklenenBayt}) =>
    beklenenBayt <= 0 ? inenBayt > 0 : inenBayt == beklenenBayt;
