// ÜRÜN SEÇENEKLERİ — "içinde şu olsun / olmasın" (kullanıcı isteği 2026-08-18).
//
// ══ SORUN ══════════════════════════════════════════════════════════════════════════════════
// Kullanıcının tarifi: "bir hızlı gıda işletmesi — gözlemeci, dönerci, dürümcü — müşteri içinde
// şu olsun olmasın diyebilir. İşletmede her seferinde bunu sormak istemeyebilir."
//
// İki ayrı ihtiyaç var ve ikisi de bugün karşılanmıyordu:
//   1. Ürünün İÇİNDEKİLERİ bir liste olarak bilinmeli ki sipariş alan kişi tek dokunuşla
//      "soğansız" diyebilsin. Bugünkü tek yol serbest metin satır notuydu; her sipariş elle
//      yazılıyor, yazım birliği yok ve mutfak "sogansız / soğan yok / SOĞANSIZ" okuyor.
//   2. Tercih MÜŞTERİYE AİT olmalı. Aynı müşteri her hafta aynı şeyi söylüyor; onu her seferinde
//      sormak, favorileri her seferinde sormakla aynı hatadır.
//
// ══ NEDEN YENİ BİR SENKRON VARLIĞI AÇILMADI ════════════════════════════════════════════════
// Üç JSON alanı, mevcut üç varlığın üstüne bindi: ürünün seçenek listesi `products`e, satırın
// seçimi `order_lines`a, müşterinin tercihi `customers`a. Gerekçe `customers.favoriteProductIds`
// (2026-08-11) ile BİREBİR aynı ve orada yazılı: yeni bir entity_type + tombstone + çakışma
// kuralı + pull dalı, bu bayi ölçeğinde taşınmayacak bir maliyettir. Seçenek listesi tam olarak
// "bu ürünün bir alanı"dır; iki cihaz farklı liste yazarsa çözüm LWW'nin kendisidir.
//
// ⚠️ SATIRIN SEÇİMİ **KENDİ KENDİNE YETER** — ürüne bakılarak çözülmez. `order_lines` zaten
// `product_name`, `unit_price_kurus` ve `unit` alanlarını satırda saklıyor ("siparişin çekildiği
// andaki gerçek", DECISIONS). Seçenek de aynı kurala tabidir: çıkarılan malzemenin ADI ve eklenen
// malzemenin FİYATI satıra yazılır. Ürünün listesi yarın değişse, silinse, adı değişse bile dün
// yazılmış bir sipariş hâlâ "soğansız" der. Diff'i ürünle karşılaştırarak çözen bir tasarım,
// menü değiştiği gün bütün geçmiş siparişlerin anlamını sessizce kaydırırdı.
//
// ══ FİYAT ═══════════════════════════════════════════════════════════════════════════════════
// Çıkarma BEDAVA, ekleme ÜCRETLİ olabilir (`ekKurus`). Ek tutar satırın BİRİM fiyatına eklenir;
// `lineTotalKurus = birim * adet` kimliği korunur ve hiçbir toplam formülü değişmez. Ayrı bir
// "ekstralar" kalemi açmak, gün sonu ve defter hesaplarının tamamına yeni bir dal eklerdi.

import 'dart:convert';

/// Bir ürünün TEK bir seçeneği (malzeme).
class UrunSecenegi {
  const UrunSecenegi({required this.ad, this.varsayilan = true, this.ekKurus = 0});

  /// Malzemenin adı — "Soğan", "Ekstra peynir". Mutfağın okuduğu metin budur.
  final String ad;

  /// Üründe VARSAYILAN olarak var mı?
  ///
  /// `true`  → içinde vardır; müşteri "olmasın" derse ÇIKARILIR (bedava).
  /// `false` → içinde yoktur; müşteri "olsun" derse EKLENİR ([ekKurus] kadar ücretlenir).
  ///
  /// Tek bir bayrağın iki ayrı listeyi (içindekiler / ekstralar) taşıması bilinçli: bayi ürünü
  /// düzenlerken tek bir liste görür ve her satırın yanındaki anahtarı çevirir. İki ayrı liste,
  /// aynı malzemenin iki yere yazılabildiği bir arayüz demekti.
  final bool varsayilan;

  /// EKLENDİĞİNDE birim fiyata binen tutar (kuruş). Çıkarmada HİÇ kullanılmaz — malzeme
  /// çıkarınca fiyat düşmez (esnafın işleyişi böyle; "soğansız" indirim değildir).
  final int ekKurus;

  Map<String, Object?> toJson() => {
        'ad': ad,
        'varsayilan': varsayilan,
        if (ekKurus != 0) 'ekKurus': ekKurus,
      };

  /// Bozuk/eksik alanlarda ÇÖKMEZ, `null` döner — çağıran onu atlar.
  ///
  /// Neden savunmacı: bu metin bir `text` kolonda bütün olarak duruyor ve sunucudan iniyor.
  /// Tek bir bozuk kayıt, ürün ekranının tamamını açılmaz yapamaz (`favoriIdleriCoz`un aynı
  /// gerekçesi).
  static UrunSecenegi? fromJson(Object? ham) {
    if (ham is! Map) return null;
    final ad = ham['ad'];
    if (ad is! String || ad.trim().isEmpty) return null;
    final ek = ham['ekKurus'];
    return UrunSecenegi(
      ad: ad.trim(),
      varsayilan: ham['varsayilan'] is bool ? ham['varsayilan'] as bool : true,
      // Negatif ek tutar SIFIRA çekilir: "eksi ekstra" diye bir şey yok ve negatif bir değer
      // satır toplamını sessizce düşürürdü.
      ekKurus: ek is int && ek > 0 ? ek : 0,
    );
  }

  UrunSecenegi kopya({String? ad, bool? varsayilan, int? ekKurus}) => UrunSecenegi(
        ad: ad ?? this.ad,
        varsayilan: varsayilan ?? this.varsayilan,
        ekKurus: ekKurus ?? this.ekKurus,
      );

  @override
  bool operator ==(Object other) =>
      other is UrunSecenegi &&
      other.ad == ad &&
      other.varsayilan == varsayilan &&
      other.ekKurus == ekKurus;

  @override
  int get hashCode => Object.hash(ad, varsayilan, ekKurus);
}

/// Ürünün seçenek listesini metinden çözer. Bozuk metin BOŞ LİSTEDİR (ekran açılmaya devam eder).
List<UrunSecenegi> secenekleriCoz(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  Object? cozulen;
  try {
    cozulen = jsonDecode(json);
  } catch (_) {
    return const [];
  }
  if (cozulen is! List) return const [];

  final sonuc = <UrunSecenegi>[];
  final gorulen = <String>{};
  for (final e in cozulen) {
    final s = UrunSecenegi.fromJson(e);
    if (s == null) continue;
    // AYNI AD İKİ KEZ DURAMAZ: seçim `ad` üzerinden eşleşiyor, tekrar eden ad hangi satırın
    // seçildiğini belirsiz kılardı. İlk görülen kazanır (bayinin sırası korunur).
    if (!gorulen.add(s.ad.toLowerCase())) continue;
    sonuc.add(s);
    if (sonuc.length >= kSecenekUstSinir) break;
  }
  return sonuc;
}

/// Listeyi saklanacak metne çevirir. Boş liste `null` döner — "seçeneği yok" TEK bir hâldir
/// (`[]` ile `null` iki ayrı değer olsaydı her okuma iki dala ayrılırdı).
String? secenekleriYaz(List<UrunSecenegi> secenekler) {
  final temiz = <UrunSecenegi>[];
  final gorulen = <String>{};
  for (final s in secenekler) {
    final ad = s.ad.trim();
    if (ad.isEmpty) continue;
    if (!gorulen.add(ad.toLowerCase())) continue;
    temiz.add(s.kopya(ad: ad));
    if (temiz.length >= kSecenekUstSinir) break;
  }
  if (temiz.isEmpty) return null;
  return jsonEncode([for (final s in temiz) s.toJson()]);
}

/// Bir ürünün taşıyabileceği azami seçenek sayısı.
///
/// KIRPMA DEĞİL SINIR: arayüz bu sayıya ulaşınca "ekle" düğmesini kapatır. Sınırın sebebi
/// ekranın kendisi — 30 çipli bir adet sheet'i, sipariş almayı hızlandırmak yerine yavaşlatır.
const int kSecenekUstSinir = 24;

/// Bir müşterinin hatırlanan tercih sayısı üst sınırı (ürün bazında).
const int kMusteriTercihUstSinir = 60;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Satırın/müşterinin SEÇİMİ
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bir sipariş satırında (ya da bir müşteri tercihinde) yapılmış seçim.
///
/// FARK OLARAK saklanır (varsayılandan sapma), TAM LİSTE olarak değil — çünkü mutfağın okuduğu
/// da budur: "soğansız". Tam listeyi yazmak her satıra sekiz malzeme adı gömerdi ve "neyin
/// değiştiği" sorusunu okuyanın çıkarmasına bırakırdı.
class SecenekSecimi {
  const SecenekSecimi({this.cikarilan = const [], this.eklenen = const []});

  /// Üründe varsayılan olarak VAR olan ama bu siparişte İSTENMEYEN malzemelerin adı.
  final List<String> cikarilan;

  /// Ürüne bu siparişte EKLENEN malzemeler (adı + o günkü ek fiyatıyla birlikte).
  ///
  /// Fiyat burada saklanır, üründen okunmaz: satır kendi kendine yetmeli (dosya başlığı).
  final List<UrunSecenegi> eklenen;

  bool get bos => cikarilan.isEmpty && eklenen.isEmpty;

  /// Eklenen malzemelerin BİRİM fiyata bineceği toplam tutar (kuruş).
  int get ekTutarKurus => eklenen.fold(0, (t, s) => t + s.ekKurus);

  /// Mutfağın/kuryenin okuduğu tek satırlık özet: "Soğansız, turşusuz · + Ekstra peynir".
  ///
  /// ⚠️ BU METİN SATIR NOTUNA YAZILIR ve bu, özelliğin en ucuz kazancıdır: sipariş detayı,
  /// kurye ekranı, fiş ve geçmiş — hepsi `order_lines.note` alanını ZATEN çiziyor. Yapılandırılmış
  /// veriyi ayrıca metne dökmek, o ekranların HİÇBİRİNE dokunmadan seçimi görünür kılar.
  String ozet() {
    final parcalar = <String>[];
    if (cikarilan.isNotEmpty) parcalar.add('${cikarilan.join(', ')} olmasın');
    if (eklenen.isNotEmpty) parcalar.add('+ ${eklenen.map((s) => s.ad).join(', ')}');
    return parcalar.join(', ');
  }

  Map<String, Object?> toJson() => {
        if (cikarilan.isNotEmpty) 'cikarilan': cikarilan,
        if (eklenen.isNotEmpty) 'eklenen': [for (final s in eklenen) s.toJson()],
      };

  static SecenekSecimi fromJson(Object? ham) {
    if (ham is! Map) return const SecenekSecimi();
    final c = ham['cikarilan'];
    final e = ham['eklenen'];
    return SecenekSecimi(
      cikarilan: c is! List
          ? const []
          : [
              for (final x in c)
                if (x is String && x.trim().isNotEmpty) x.trim(),
            ],
      eklenen: e is! List
          ? const []
          : [
              for (final x in e) ?UrunSecenegi.fromJson(x),
            ],
    );
  }

  /// Metinden çözer; bozuk/boş metinde BOŞ seçim döner.
  static SecenekSecimi coz(String? json) {
    if (json == null || json.trim().isEmpty) return const SecenekSecimi();
    try {
      return SecenekSecimi.fromJson(jsonDecode(json));
    } catch (_) {
      return const SecenekSecimi();
    }
  }

  /// Saklanacak metne çevirir; seçim boşsa `null` (alan hiç yazılmaz).
  String? yaz() => bos ? null : jsonEncode(toJson());

  /// Ürünün GÜNCEL seçenek listesine göre seçimi yeniden kurar.
  ///
  /// Neden gerekli: müşteri tercihi aylar önce kaydedilmiş olabilir ve o günden beri bayi
  /// menüyü değiştirmiş olabilir. Artık var olmayan bir malzemeyi "çıkarılan" diye taşımak,
  /// mutfağa anlamsız bir talimat göndermektir; artık ÜCRETLİ olan bir ekstrayı eski fiyatıyla
  /// uygulamak ise bayiye para kaybettirir.
  ///
  /// Kural: seçim ürünün BUGÜNKÜ listesiyle kesiştirilir ve ek fiyatlar BUGÜNKÜ değerden alınır.
  SecenekSecimi urunleUyumlu(List<UrunSecenegi> secenekler) {
    final adAramasi = {for (final s in secenekler) s.ad.toLowerCase(): s};
    return SecenekSecimi(
      cikarilan: [
        for (final ad in cikarilan)
          if (adAramasi[ad.toLowerCase()]?.varsayilan ?? false) adAramasi[ad.toLowerCase()]!.ad,
      ],
      eklenen: [
        for (final s in eklenen)
          if (adAramasi[s.ad.toLowerCase()] case final guncel?)
            if (!guncel.varsayilan) guncel,
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Müşteri tercihleri — "her seferinde sormak istemeyebilir"
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// `customers.product_options_json` çözümü: ürün kimliği → o müşterinin sabit tercihi.
Map<String, SecenekSecimi> musteriTercihleriniCoz(String? json) {
  if (json == null || json.trim().isEmpty) return const {};
  Object? cozulen;
  try {
    cozulen = jsonDecode(json);
  } catch (_) {
    return const {};
  }
  if (cozulen is! Map) return const {};

  final sonuc = <String, SecenekSecimi>{};
  for (final girdi in cozulen.entries) {
    final id = girdi.key;
    if (id is! String || id.trim().isEmpty) continue;
    final secim = SecenekSecimi.fromJson(girdi.value);
    // BOŞ TERCİH SAKLANMAZ: "hiçbir şey değiştirme" zaten varsayılandır ve onu kayıt olarak
    // tutmak, müşteri kartında anlamsız bir satır gösterirdi.
    if (secim.bos) continue;
    sonuc[id.trim()] = secim;
    if (sonuc.length >= kMusteriTercihUstSinir) break;
  }
  return sonuc;
}

/// Tercihleri saklanacak metne çevirir; boşsa `null`.
String? musteriTercihleriniYaz(Map<String, SecenekSecimi> tercihler) {
  final temiz = <String, Object?>{};
  for (final e in tercihler.entries) {
    if (e.key.trim().isEmpty || e.value.bos) continue;
    temiz[e.key.trim()] = e.value.toJson();
    if (temiz.length >= kMusteriTercihUstSinir) break;
  }
  return temiz.isEmpty ? null : jsonEncode(temiz);
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// HAZIR LİSTELER — "işletme türüne göre değişkenlik gösteren ürün listesi"
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bir işletme türü için tipik malzeme listesi.
///
/// ⚠️ ÜRÜNE GÖMÜLÜ DEĞİL, YALNIZ BAŞLANGIÇ NOKTASI. Bayi şablonu uygular ve İSTEDİĞİ GİBİ
/// düzenler; kaydedilen şey ürünün kendi listesidir. Kullanıcının isteği "işletme türüne göre
/// değişkenlik gösteren ürün listesi yapabilmeliyiz" idi — yani ürünün türünü UYGULAMA bilmez,
/// bayi seçer. Sabit bir "işletme türü" alanı eklemek ters yönde bir karardı: aynı dükkânda hem
/// dürüm hem tatlı satılır ve tek bir tür etiketi ikisini birden yanlış tarif ederdi.
class SecenekSablonu {
  const SecenekSablonu({required this.ad, required this.secenekler});

  final String ad;
  final List<UrunSecenegi> secenekler;
}

/// Sık görülen işletme türleri için hazır malzeme listeleri.
///
/// Fiyatlar SIFIR verilir ve bu bilinçli: ekstra ücreti bayiden bayiye değişir ve uydurma bir
/// rakam, bayinin düzeltmeyi unuttuğu gün müşteriden yanlış para almasına yol açar. Sıfır ek
/// ücret görünür ve zararsız bir varsayılandır.
const List<SecenekSablonu> kSecenekSablonlari = [
  SecenekSablonu(ad: 'Dürüm / Döner', secenekler: [
    UrunSecenegi(ad: 'Domates'),
    UrunSecenegi(ad: 'Marul'),
    UrunSecenegi(ad: 'Soğan'),
    UrunSecenegi(ad: 'Turşu'),
    UrunSecenegi(ad: 'Ketçap'),
    UrunSecenegi(ad: 'Mayonez'),
    UrunSecenegi(ad: 'Acı sos'),
    UrunSecenegi(ad: 'Ekstra et', varsayilan: false),
    UrunSecenegi(ad: 'Ekstra peynir', varsayilan: false),
  ]),
  SecenekSablonu(ad: 'Gözleme', secenekler: [
    UrunSecenegi(ad: 'Peynir'),
    UrunSecenegi(ad: 'Maydanoz'),
    UrunSecenegi(ad: 'Patates'),
    UrunSecenegi(ad: 'Ispanak'),
    UrunSecenegi(ad: 'Kıyma', varsayilan: false),
    UrunSecenegi(ad: 'Kaşar', varsayilan: false),
    UrunSecenegi(ad: 'Tereyağı'),
  ]),
  SecenekSablonu(ad: 'Tost / Sandviç', secenekler: [
    UrunSecenegi(ad: 'Kaşar'),
    UrunSecenegi(ad: 'Sucuk'),
    UrunSecenegi(ad: 'Domates'),
    UrunSecenegi(ad: 'Turşu'),
    UrunSecenegi(ad: 'Ketçap'),
    UrunSecenegi(ad: 'Mayonez'),
    UrunSecenegi(ad: 'Zeytin', varsayilan: false),
  ]),
  SecenekSablonu(ad: 'Burger', secenekler: [
    UrunSecenegi(ad: 'Marul'),
    UrunSecenegi(ad: 'Domates'),
    UrunSecenegi(ad: 'Soğan'),
    UrunSecenegi(ad: 'Turşu'),
    UrunSecenegi(ad: 'Cheddar'),
    UrunSecenegi(ad: 'Özel sos'),
    UrunSecenegi(ad: 'Ekstra köfte', varsayilan: false),
  ]),
  SecenekSablonu(ad: 'Pide / Lahmacun', secenekler: [
    UrunSecenegi(ad: 'Maydanoz'),
    UrunSecenegi(ad: 'Soğan'),
    UrunSecenegi(ad: 'Limon'),
    UrunSecenegi(ad: 'Acı biber'),
    UrunSecenegi(ad: 'Ekstra kaşar', varsayilan: false),
  ]),
  SecenekSablonu(ad: 'Salata', secenekler: [
    UrunSecenegi(ad: 'Domates'),
    UrunSecenegi(ad: 'Salatalık'),
    UrunSecenegi(ad: 'Soğan'),
    UrunSecenegi(ad: 'Zeytin'),
    UrunSecenegi(ad: 'Limon sosu'),
    UrunSecenegi(ad: 'Tavuk', varsayilan: false),
  ]),
  SecenekSablonu(ad: 'Çay / Kahve', secenekler: [
    UrunSecenegi(ad: 'Şekerli'),
    UrunSecenegi(ad: 'Süt', varsayilan: false),
    UrunSecenegi(ad: 'Az şekerli', varsayilan: false),
  ]),
  SecenekSablonu(ad: 'Su / İçecek', secenekler: [
    UrunSecenegi(ad: 'Soğuk'),
    UrunSecenegi(ad: 'Buzlu', varsayilan: false),
    UrunSecenegi(ad: 'Pipet', varsayilan: false),
  ]),
];
