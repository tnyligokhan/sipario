// Sipariş ekranlarının SAF GÖSTERİM yardımcıları — kod rozetleri, geçen süre, ödeme tipleri,
// saat biçimi. Tasarım kaynağı: s-siparisler.jsx + s-veri.jsx.
//
// NEDEN AYRI DOSYA: `order_queries.dart` 728 satıra çıkmıştı (500 satır kuralı). Bu bölüm oradan
// TEK BİR sembol bile ödünç almıyordu — ne veritabanı, ne drift, ne `AppDatabase`. Girdisi
// `int?`/`String`, çıktısı ekrana yazılacak metin; sınır kendiliğinden buradaydı. Dosyanın hiç
// import'u yok, ve olmaması kuralın kendisidir: buraya bir sorgu sızarsa import listesi bunu
// söyler.
//
// SÖZLEŞME: `saatBicimi` / `odemeTipiEtiketi` / `gecenSure` / `satirKodu` imzaları DEĞİŞMEZ —
// mevcut testler ve başka ekranlar bunları doğrudan çağırıyor. `order_queries.dart` bu dosyayı
// yeniden dışa aktarır, dolayısıyla eski `import 'order_queries.dart'` yolları aynen çalışır.

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Kod rozetleri
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Müşteri kodu rozeti — "102".
///
/// ESKİ HÂLİ (2026-07-29'a kadar): kod UUID'nin son üç RAKAMINDAN türetiliyordu ve "M-007"
/// yazıyordu. Bu bir kimlik değil, bir SÜSTÜ: iki müşteri aynı üçlüyü alabiliyordu, sayı hiçbir
/// sırayı anlatmıyordu ve bayi "102 numaralı abone" diyemiyordu. Artık kod sunucudan gelen
/// gerçek sıra numarasıdır (`customers.code`).
///
/// Kod YOKSA null döner ve çağıran rozeti HİÇ çizmez — sıfır ya da "M-000" gibi uydurma bir
/// numara basmak, senkronlanmamış bir müşteriyi var olmayan bir kodla anmak olurdu.
String? musteriKodu(int? code) => code == null ? null : '$code';

/// Sipariş kodu rozeti — "#248". Kullanıcı isteği: "her siparişin bir kodu olmalı #xxx gibi".
String? siparisKodu(int? code) => code == null ? null : '#$code';

/// Sipariş satırında hangi kod görünecek? Bayi tercihi (`tenant_settings.order_code_display`).
///
/// Tek karar noktası: liste satırı, sipariş detayı ve testler aynı fonksiyonu çağırır. Tanınmayan
/// bir değer (eski/yeni istemci ayrışması) MÜŞTERİ koduna düşer — sunucudaki beyaz listenin aynısı.
/// Seçilen kod yoksa (ör. tezgâh satışında müşteri kodu) DİĞERİNE düşülür: satırda hiç numara
/// olmamasındansa var olan numara gösterilir.
String? satirKodu({
  required String tercih,
  required int? musteriCode,
  required int? siparisCode,
}) {
  final musteri = musteriKodu(musteriCode);
  final siparis = siparisKodu(siparisCode);
  return tercih == 'siparis' ? (siparis ?? musteri) : (musteri ?? siparis);
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Zaman
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Açık siparişin ÜZERİNDEN GEÇEN süre — "12 dk" · "1 sa 5 dk" · "2 gün".
///
/// Kullanıcı isteği (2026-07-29): açık siparişte kartta "Açık" yazmak yerine siparişin kaç
/// dakikadır beklediği görünsün. Gerekçe sahadan: "açık" bilgisi zaten listenin adında var
/// (Açık sekmesi), asıl merak edilen BEKLEME SÜRESİDİR — geciken teslimat böyle fark edilir.
///
/// Kurallar:
///  • 1 dakikadan yeni → "yeni" (0 dk yazmak siparişin daha girilmediğini düşündürür).
///  • 60 dakikaya kadar dakika; sonrasında saat + dakika (ilk gün dakika ÖNEMLİDİR — 1 sa 5 dk
///    ile 1 sa 55 dk arasındaki fark bayinin telefonla özür dileyip dilemeyeceğini belirler).
///  • 24 saatten sonra gün (o noktada dakika gürültüdür).
///  • İLERİ tarihli damga "yeni" sayılır: cihaz saati ileri kaymış olabilir ve "−3 dk" yazmak
///    veriye güveni sarsar (senkron zaten sunucu saatiyle düzeltilmiş damga yazar).
String gecenSure(String iso, {DateTime? simdi}) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final fark = (simdi ?? DateTime.now()).difference(t.toLocal());
  if (fark.inMinutes < 1) return 'yeni';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dk';
  if (fark.inHours < 24) {
    final dk = fark.inMinutes % 60;
    return dk == 0 ? '${fark.inHours} sa' : '${fark.inHours} sa $dk dk';
  }
  return '${fark.inDays} gün';
}

/// ISO8601 occurred_at → "14:35" (bugünse) veya "17.07 14:35". Saat cihaz yerelinde gösterilir;
/// kayıtta UTC/sunucu-düzeltilmiş metin OLDUĞU GİBİ durur (DECISIONS — gösterim veriyi değiştirmez).
String saatBicimi(String iso, {DateTime? simdi}) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final local = t.toLocal();
  final now = simdi ?? DateTime.now();
  final saat = '${_ikiHane(local.hour)}:${_ikiHane(local.minute)}';
  final ayniGun = local.year == now.year && local.month == now.month && local.day == now.day;
  return ayniGun ? saat : '${_ikiHane(local.day)}.${_ikiHane(local.month)} $saat';
}

String _ikiHane(int n) => n.toString().padLeft(2, '0');

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Ödeme tipleri
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Teslim sheet'inde ÇİZİLEN ödeme karoları (tasarım `ODEME_TIPLERI`) — dördü de HER ZAMAN
/// görünür. Müşterisiz siparişte veresiye karosu listeden DÜŞMEZ, PASİF çizilir
/// (s-siparisler.jsx:620 `disabled` + `opacity .45`): seçeneği gizlemek kullanıcıya "veresiye
/// yok" dedirtir, pasif göstermek "burada kullanılamaz" der ve yanındaki açıklama okunur olur.
const List<String> odemeTipleri = ['nakit', 'kart', 'havale', 'veresiye'];

/// Teslimde SEÇİLEBİLİR ödeme tipleri. veresiye MÜŞTERİ ZORUNLU: borç bir müşteriye yazılır —
/// müşterisiz veresiye kimseye ait olmayan bir borç kaydı üretirdi (defter tutarlılığı;
/// tezgâh satışındaki veresiye kilidi budur). Karo GÖSTERİMİ için [odemeTipleri] kullanılır.
List<String> teslimOdemeTipleri({required bool musteriVar}) =>
    [for (final tip in odemeTipleri) if (odemeTipiSecilebilir(tip, musteriVar: musteriVar)) tip];

/// Tek karonun kilidi — pasif çizim ve dokunma engeli aynı kuraldan okur (iki yerde ayrı
/// koşul yazılırsa görünüşte pasif ama seçilebilir bir karo çıkar).
bool odemeTipiSecilebilir(String tip, {required bool musteriVar}) =>
    tip != 'veresiye' || musteriVar;

/// Ödeme tipinin ekran etiketi (veri değeri değişmez — DB'de 'nakit'/'veresiye'/... durur).
String odemeTipiEtiketi(String paymentType) => switch (paymentType) {
      'nakit' => 'Nakit',
      'kart' => 'Kart',
      'havale' => 'Havale',
      'veresiye' => 'Veresiye',
      _ => paymentType,
    };
