// SEKMEYE YÖNLENDİRME — bir iş bittiğinde kabuğu sonucun göründüğü sekmeye alır.
// Kullanıcı isteği (2026-08-04): "sipariş ekledikten sonra müşteri kartına değil siparişler
// ekranına gidecek."
//
// NEDEN GEÇİLEN GERİ ÇAĞRIM DEĞİL DE MODÜL DÜZEYİNDE BAĞLAMA (`yenileme.dart` deseni):
// sipariş formu ÜÇ ayrı yoldan açılıyor — FAB, çağrı kartı ve müşteri kartı. İlk ikisi kabuğun
// kendi metotları (sekmeyi zaten kendileri ayarlıyordu), üçüncüsü İKİ seviye derinde:
// kabuk → müşteri kartı → sipariş formu; üstelik müşteri kartı bir de müşteri LİSTESİNDEN
// açılıyor. Sonucu zincirin her halkasından geri taşımak dört ekranın imzasını yalnız taşıma
// amacıyla değiştirmek demekti.
//
// YIĞIN DA TEMİZLENİR: "siparişler ekranına git" demek, üstünde müşteri kartı duran bir
// siparişler sekmesi değildir. Geri tuşu kullanıcıyı yeni bitirdiği işin formuna döndürmemeli.
//
// BAĞLANMAMIŞSA SESSİZ: testler ve önizleme ağaçlarında kabuk yoktur; orada çökmek değil,
// çağıranın kendi yedeğine düşmesi doğru davranıştır (dönen `bool` bunun içindir).

import 'alt_nav.dart';

typedef SekmeYonlendirici = void Function(SipSekme sekme);

SekmeYonlendirici? _yonlendirici;

/// Kabuk açılışta bağlar.
void sekmeYonlendirmeyiBagla(SekmeYonlendirici f) => _yonlendirici = f;

/// Kabuk kapanışta çözer (bir sonraki test/oturum ölü kabuğa yönlendirmesin).
void sekmeYonlendirmeyiCoz() => _yonlendirici = null;

/// Kabuğu [sekme]ye alır ve üstündeki push'ları kapatır. Bağlama yoksa `false` döner ve
/// HİÇBİR ŞEY yapmaz — çağıran kendi yedeğini uygular.
bool sekmeyeGit(SipSekme sekme) {
  final f = _yonlendirici;
  if (f == null) return false;
  f(sekme);
  return true;
}
