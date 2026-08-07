// NATIVE çağrı kartının eylem köprüsü.
//
// Telefon çalarken kartı Flutter değil Kotlin çizer (`android/.../CallerCard.kt`) — çağrı
// anında Flutter motoru başlatılmaz, 1 saniyelik bütçe buna izin vermez. Bayi kartta bir
// düğmeye dokunduğunda native uygulamayı açar ve eylemi BEKLETİR; motor ayağa kalkınca
// eylem buradan çekilir.
//
// Neden BEKLETME (pull), doğrudan itme (push) değil: dokunma anında Dart tarafı çoğu zaman
// hiç yaşamıyor olur — itilen çağrı boşluğa düşerdi. Native eylemi tutar, ilk soran alır ve
// alındığı anda native onu siler; iki kez tüketilmesi imkânsızdır.
//
// Uygulama ZATEN önplandayken (bayi çağrı sırasında uygulamayı kullanıyorken) yeni bir
// yaşam döngüsü olayı doğmaz; o durumda native `eylem` dürtüsünü gönderir, dinleyen taraf
// yine çekerek alır. Yani tek transfer yolu vardır, dürtü yalnız "şimdi sor" demektir.

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'cagri_karti.dart' show CagriEylemi;

/// Yalnız çağrı kartı eylemleri için AYRI kanal. `sipario/phase0` ile birleştirilmedi:
/// Dart tarafında gelen çağrıya kancalanmak `setMethodCallHandler` ile olur ve bir kanal
/// adında yalnız SON kanca yaşar — izin sihirbazı ileride kendi kancasını kurarsa bu
/// köprüyü sessizce koparırdı.
const MethodChannel kCagriEylemKanali = MethodChannel('sipario/cagri');

/// Köprü YALNIZ Android'de vardır — native kart Android'e özgüdür. Diğer platformlarda ve
/// widget testlerinde kanal HİÇ ÇAĞRILMAZ, çünkü `flutter_test`in mesajcısı sahtelenmemiş
/// bir kanala yanıt DÖNDÜRMEZ (hata da atmaz): gelecek sonsuza dek askıda kalır ve kabuğu
/// kuran her widget testi arkasında ölü bir bekleyiş bırakırdı. Ölçüldü: 10 dk zaman aşımı.
///
/// Köprüyü uçtan uca sınayan testler bunu `true` yapıp kanalı sahteler.
bool cagriKopruAcik = Platform.isAndroid;

/// Native kartın ilettiği eylem: hangi düğme, hangi numara için.
class NativeCagriEylemi {
  const NativeCagriEylemi({required this.eylem, required this.numara});

  final CagriEylemi eylem;

  /// Ham numara — müşteriye çeviriyi `cagriKisiCoz` yapar (kart çizildiğinden beri numara
  /// müşteri olarak kaydedilmiş ya da silinmiş olabilir).
  final String numara;
}

/// Native'in gönderdiği eylem adını enum'a çevirir. Tanınmayan ad `null` döner ve istek
/// SESSİZCE düşer — köprünün iki ucu ayrışırsa yanlış ekrana gitmektense hiç gitmemek yeğdir.
CagriEylemi? cagriEylemiCoz(String? ad) => switch (ad) {
      'siparis' => CagriEylemi.siparis,
      'defter' => CagriEylemi.defter,
      'kaydet' => CagriEylemi.kaydet,
      _ => null,
    };

/// Native'de bekleyen eylemi çeker ve orada siler. Bekleyen yoksa `null`.
///
/// Köprü kapalıyken (bkz. [cagriKopruAcik]) kanala hiç dokunulmaz — kabuk bu köprüyü
/// açılışta koşulsuz yoklar, köprünün yokluğu hata değildir.
Future<NativeCagriEylemi?> bekleyenCagriEylemi({
  MethodChannel kanal = kCagriEylemKanali,
}) async {
  if (!cagriKopruAcik) return null;

  final Map<Object?, Object?>? ham;
  try {
    ham = await kanal.invokeMapMethod<Object?, Object?>('bekleyen');
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
  if (ham == null) return null;

  final eylem = cagriEylemiCoz(ham['eylem'] as String?);
  final numara = (ham['numara'] as String?) ?? '';
  if (eylem == null || numara.isEmpty) return null;
  return NativeCagriEylemi(eylem: eylem, numara: numara);
}

/// Native'in "bekleyen eylem var" dürtüsüne kancalanır. Dürtü VERİ TAŞIMAZ; dinleyen
/// [bekleyenCagriEylemi] ile çeker — böylece açılışta çekmekle burada çekmek aynı yoldur.
void cagriEylemDurtusunuDinle(
  Future<void> Function() onDurtu, {
  MethodChannel kanal = kCagriEylemKanali,
}) {
  kanal.setMethodCallHandler((cagri) async {
    if (cagri.method == 'eylem') await onDurtu();
    return null;
  });
}

/// Kancayı bırakır (kabuk sökülürken). Kanalın tek sahibi kabuktur.
void cagriEylemDurtusunuBirak({MethodChannel kanal = kCagriEylemKanali}) {
  kanal.setMethodCallHandler(null);
}
