// SİPARİŞLERİN KİŞİYE GÖRE GRUPLANMASI — harita ve oto sıralamanın ORTAK kuralı
// (kullanıcı kararı 2026-09-29).
//
//   "Kuryeler sadece kendi siparişlerini haritada görebilir! Patron hem kendi siparişlerini hem
//    de kuryelerin siparişlerini görebilir fakat ayrıştırılmış şekilde!"
//   "Patron oto sıralama yaptığında hem kendi siparişlerini hem de kuryelerin konumlarına göre
//    onların siparişlerini sıralayabilmeli."
//
// ══ KURAL ═══════════════════════════════════════════════════════════════════════════════════
//  • KURYE: yalnız KENDİSİNE ATANMIŞ siparişler, tek grup. Atanmamış sipariş kuryenin işi
//    değildir; haritasında görünmesi "bunu da ben mi götüreceğim" sorusunu doğurur.
//  • DİĞER ROLLER (patron, tezgâh): "Siz" grubu = kendisine atanmış + ATANMAMIŞ siparişler
//    (atanmamış siparişi kimse götürmüyorsa sorumlusu siparişi dağıtan kişidir), ardından her
//    atanan kişi ayrı grup. Gruplar adına göre sıralanır; "Siz" her zaman ilktir.
//
// NEDEN TEK DOSYA: harita grupları çizer, oto sıralama aynı grupları ayrı rota olarak sıralar.
// İki ayrı kural yazılsaydı haritada "Ali" grubunda görünen bir sipariş Ali'nin rotasına
// girmeyebilirdi.
//
// RENK: grup rengi kişiye BAĞLIDIR, gruptaki sırasına değil. Sıraya bağlansaydı bir kuryenin
// siparişleri bitince diğer herkesin rengi kayar ve patron "Ali mavi" alışkanlığını kaybederdi.

import 'dart:ui' show Color;

import '../../data/ad_anahtari.dart';

/// Tek bir kişinin sipariş grubu.
class SiparisGrubu<T> {
  const SiparisGrubu({
    required this.kullaniciId,
    required this.ad,
    required this.kendi,
    required this.ogeler,
  });

  /// Grubun sahibi; "Siz" grubunda oturumdaki kullanıcıdır (atanmamışlar da buradadır).
  final String? kullaniciId;
  final String ad;

  /// Oturumdaki kullanıcının kendi grubu mu?
  final bool kendi;

  /// Verilen sırayı korur (rota sırası çağıranın işidir).
  final List<T> ogeler;

  /// Seçim ve renk için kararlı anahtar.
  String get anahtar => kendi ? kKendiGrubu : kullaniciId!;
}

/// "Siz" grubunun anahtarı.
const String kKendiGrubu = 'kendi';

/// Grupların sırası ve üyeliği — saf, doğrudan testlenir.
///
/// [atanan] bir öğenin atandığı kullanıcıyı verir. [adlar] kullanıcı kimliği → görünen ad.
/// [kuryeKipi] true ise yalnız [kendiId]'ye atanmış öğelerden TEK grup döner.
List<SiparisGrubu<T>> siparisleriGrupla<T>(
  List<T> ogeler, {
  required String? Function(T) atanan,
  required String? kendiId,
  required Map<String, String> adlar,
  bool kuryeKipi = false,
}) {
  if (kuryeKipi) {
    final benim = [for (final o in ogeler) if (kendiId != null && atanan(o) == kendiId) o];
    return benim.isEmpty
        ? const []
        : [SiparisGrubu(kullaniciId: kendiId, ad: 'Siz', kendi: true, ogeler: benim)];
  }

  final kendi = <T>[];
  final digerleri = <String, List<T>>{};
  for (final o in ogeler) {
    final a = atanan(o);
    if (a == null || a == kendiId) {
      kendi.add(o);
    } else {
      (digerleri[a] ??= []).add(o);
    }
  }

  String ad(String id) {
    final a = (adlar[id] ?? '').trim();
    return a.isEmpty ? 'Kurye' : a;
  }

  final kimlikler = digerleri.keys.toList()
    ..sort((x, y) {
      final k = adAnahtari(ad(x)).compareTo(adAnahtari(ad(y)));
      return k != 0 ? k : x.compareTo(y);
    });

  return [
    if (kendi.isNotEmpty)
      SiparisGrubu(kullaniciId: kendiId, ad: 'Siz', kendi: true, ogeler: kendi),
    for (final id in kimlikler)
      SiparisGrubu(kullaniciId: id, ad: ad(id), kendi: false, ogeler: digerleri[id]!),
  ];
}

/// Kuryelere verilen renkler — açık ve koyu temada okunur, birbirinden ve temanın vurgusundan
/// ayrışır. "Siz" grubu temanın vurgu rengini alır (bkz. [grupRengi]).
const List<Color> kGrupRenkleri = [
  Color(0xFF0EA5E9), // gök mavisi
  Color(0xFFF59E0B), // kehribar
  Color(0xFF10B981), // zümrüt
  Color(0xFFEC4899), // pembe
  Color(0xFF8B5CF6), // mor
  Color(0xFFEF4444), // kırmızı
  Color(0xFF14B8A6), // camgöbeği
  Color(0xFF84CC16), // fıstık yeşili
];

/// Bir grubun rengi. [kisiSirasi] ekipteki bütün kişilerin KARARLI sırasıdır (kimliğe göre);
/// renk oradaki yerden gelir, o an haritada kaç grup olduğundan değil.
Color grupRengi(
  SiparisGrubu<Object?> grup, {
  required Color vurgu,
  required List<String> kisiSirasi,
}) {
  if (grup.kendi) return vurgu;
  return kisiRengi(grup.kullaniciId!, kisiSirasi: kisiSirasi);
}

/// Bir kişinin (kuryenin) rengi — durakları ve canlı konum pini AYNI rengi alır; kuryenin o an
/// hiç siparişi olmasa da pini bu renkle çizilir.
Color kisiRengi(String kullaniciId, {required List<String> kisiSirasi}) {
  final i = kisiSirasi.indexOf(kullaniciId);
  final sira = i < 0 ? kullaniciId.hashCode.abs() : i;
  return kGrupRenkleri[sira % kGrupRenkleri.length];
}
