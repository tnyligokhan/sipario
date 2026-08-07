// BİLDİRİM SÖZLEŞMESİ — Faz 1.
//
// Bu dosya bildirim altyapısının TEK arayüzüdür. Kural yazan taraflar (borç eşiği, gün sonu
// özeti, rutin teslim günü …) yalnız [BildirimTaslagi] ÜRETİR; ne zaman gösterileceğine,
// gösterilip gösterilmeyeceğine ve nasıl çizileceğine altyapı karar verir.
//
// SAF: bu dosya platform kanalına, veritabanına, `flutter_local_notifications`a BAĞLI DEĞİLDİR.
// Kural fonksiyonları buna bakarak yazılır ve [SahteBildirimServisi] ile test edilir; gerçek
// servis (`bildirim_servisi.dart`) yalnız uygulamada devreye girer.
//
// KAPSAM SINIRI (Faz 1): ABONELİK/ödeme ile ilgili bildirim YOKTUR — mağaza kuralı riski
// (BRIEF: mobilde fiyat, satın alma, yönlendirme bulunamaz). `sistem` kategorisi bu iş için
// KULLANILAMAZ.

import 'package:flutter/foundation.dart';

/// Bildirim türleri. Her biri sistemde AYRI bir kanaldır: bayi tek tek kısabilmeli
/// (ör. "gün sonu özeti kalsın, gecikme uyarısı sussun").
enum BildirimKategori {
  /// Akşam kasayı devrederken: bugün kaç teslim, ne kadar tahsilat, ne kadar açık borç.
  gunSonuOzeti,

  /// Bir müşterinin borcu bayinin belirlediği eşiği aştı.
  borcEsigi,

  /// Vadesi geçmiş borç (veresiye ay sonunda toplanır; geçen ayınki hâlâ duruyorsa).
  vadesiGecenBorc,

  /// Düzenli alan müşteri her zamanki aralığını geçirdi — "Ahmet Bey 3 haftadır aramadı".
  musteriGecikti,

  /// Rutin teslim günü geldi (haftalık damacana turu gibi).
  rutinTeslimGunu,

  /// Uygulamanın kendi durumu (senkron uzun süredir yapılamadı gibi).
  /// ABONELİK/ÖDEME İÇİN KULLANILMAZ — mağaza kuralı.
  sistem;

  /// Kalıcı kimlik: bildirim kanalı adı, ayar dosyası anahtarı ve [BildirimTaslagi.kimlik]
  /// öneki bundan türer. **MAĞAZADA DEĞİŞMEZ** — değişirse kullanıcının sistemden kıstığı
  /// kanal yeni bir kanal olarak geri açılır ve bayi kapattığı bildirimi yeniden almaya başlar.
  String get wire => switch (this) {
        BildirimKategori.gunSonuOzeti => 'gun_sonu_ozeti',
        BildirimKategori.borcEsigi => 'borc_esigi',
        BildirimKategori.vadesiGecenBorc => 'vadesi_gecen_borc',
        BildirimKategori.musteriGecikti => 'musteri_gecikti',
        BildirimKategori.rutinTeslimGunu => 'rutin_teslim_gunu',
        BildirimKategori.sistem => 'sistem',
      };

  /// Sistem bildirim ayarlarında ve uygulamanın Ayarlar ekranında görünen ad.
  ///
  /// ETİKET SERBESTTİR, [wire] DEĞİL: Android kanalın ADINI kimlik sabit kaldığı sürece
  /// günceller (`AndroidNotificationChannel(k.wire, k.ad)` — ilk argüman kimlik). Bu yüzden
  /// "Gün sonu özeti" → "Gün özeti" adlandırması (kullanıcı kararı 2026-08-06) bayinin sistemden
  /// kıstığı kanalı öksüz BIRAKMAZ. `wire` değerine aynı gerekçeyle DOKUNULMADI.
  String get ad => switch (this) {
        BildirimKategori.gunSonuOzeti => 'Gün özeti',
        BildirimKategori.borcEsigi => 'Borç eşiği',
        BildirimKategori.vadesiGecenBorc => 'Vadesi geçen borç',
        BildirimKategori.musteriGecikti => 'Müşteri gecikti',
        BildirimKategori.rutinTeslimGunu => 'Rutin teslim günü',
        BildirimKategori.sistem => 'Uygulama durumu',
      };

  /// Ayarlar ekranındaki tek satırlık açıklama — bayi neyi kapattığını bilmeli.
  String get aciklama => switch (this) {
        BildirimKategori.gunSonuOzeti => 'Akşam kasa ve teslim özeti',
        BildirimKategori.borcEsigi => 'Bir müşterinin borcu eşiği aştığında',
        BildirimKategori.vadesiGecenBorc => 'Vadesi geçmiş veresiye hatırlatması',
        BildirimKategori.musteriGecikti => 'Düzenli müşteri her zamanki aralığını geçirdiğinde',
        BildirimKategori.rutinTeslimGunu => 'Rutin teslim günü hatırlatması',
        BildirimKategori.sistem => 'Senkron ve uygulama uyarıları',
      };

  static BildirimKategori? wiredan(String? w) =>
      values.where((k) => k.wire == w).firstOrNull;
}

/// Kural fonksiyonlarının ÜRETTİĞİ şey. Yan etkisi yok, eşitliği tanımlı, test edilebilir.
@immutable
class BildirimTaslagi {
  const BildirimTaslagi({
    required this.kategori,
    required this.baslik,
    required this.govde,
    required this.kimlik,
    this.yol,
  });

  final BildirimKategori kategori;
  final String baslik;

  /// Gövde metni: müşteri adı ve borç tutarı BURAYA yazılır, başlık nötr tutulur.
  ///
  /// DÜZELTME (2026-07-27): önce "başlık kilit ekranında görünür, gövde gizlenir" yazıyordu;
  /// mekanizma öyle DEĞİL. `flutter_local_notifications` `publicVersion` alanını açmıyor, yani
  /// `VISIBILITY_PRIVATE` bildirimin TAMAMINI (başlık dahil) gizler. Kural yine de geçerli:
  /// kilidi açtıktan sonra bildirim rafında bir bakışta okunan şey başlıktır ve telefon
  /// uzatıldığında yanındaki onu görür. Ayrıntı gövdede kalsın.
  final String govde;

  /// Dokununca gidilecek ekran. Sözlük (Faz 1): `musteri/<id>` · `siparis/<id>` · `gunsonu`.
  /// Boş bırakılırsa uygulama ana ekranda açılır.
  final String? yol;

  /// AYNI KİMLİK = AYNI BİLDİRİM: ikinci gösterim yeni satır açmaz, üzerine yazar
  /// (çağrı günlüğündeki `insertOnConflictUpdate` mantığının bildirim karşılığı) ve günlük
  /// bildirim bütçesinden İKİNCİ KEZ düşmez.
  ///
  /// [bildirimKimligi] ile üretin — elle string birleştirmeyin, kategori öneki zorunludur.
  final String kimlik;

  BildirimTaslagi kopyala({String? baslik, String? govde, String? yol}) => BildirimTaslagi(
        kategori: kategori,
        baslik: baslik ?? this.baslik,
        govde: govde ?? this.govde,
        kimlik: kimlik,
        yol: yol ?? this.yol,
      );

  @override
  bool operator ==(Object other) =>
      other is BildirimTaslagi &&
      other.kategori == kategori &&
      other.baslik == baslik &&
      other.govde == govde &&
      other.yol == yol &&
      other.kimlik == kimlik;

  @override
  int get hashCode => Object.hash(kategori, baslik, govde, yol, kimlik);

  @override
  String toString() => 'BildirimTaslagi(${kategori.wire}, $kimlik, "$baslik")';
}

/// Bildirim kimliği üretir: `<kategori>:<ayırt edici>`.
///
/// [ayirtEdici] AYNI ŞEYİ gösteren iki bildirimde AYNI olmalıdır — müşteri kimliği, gün
/// (`2026-07-27`) gibi. Rastgele değer vermeyin: her çağrıda yeni bildirim doğar, bayi
/// bildirim yağmuruna tutulur ve hepsini kapatır.
String bildirimKimligi(BildirimKategori kategori, String ayirtEdici) =>
    '${kategori.wire}:$ayirtEdici';

/// Gün bazlı bildirimler için ayırt edici: `2026-07-27`.
String bildirimGunAnahtari(DateTime an) {
  final y = an.year.toString().padLeft(4, '0');
  final a = an.month.toString().padLeft(2, '0');
  final g = an.day.toString().padLeft(2, '0');
  return '$y-$a-$g';
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// `yol` sözlüğü — bildirime dokunulunca nereye gidilir
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// [BildirimTaslagi.yol] değerinin çözümü. Faz 1 sözlüğü: `gunsonu` · `musteri/<id>`.
///
/// TANINMAYAN YOL `null` DÖNER, İSTİSNA ATMAZ: sözlük büyüyecek (çok-müşterili liste rotası
/// Faz 2'de gelecek) ve zamanlanmış eski bir bildirim, güncellenmiş uygulamada ya da tersi
/// durumda bilinmeyen bir yol taşıyabilir. Bilinmeyen hedef bir hata değildir; çağıran
/// kullanıcıyı bulunduğu yerde bırakır.
///
/// SAF ve burada duruyor çünkü sözlük SÖZLEŞMENİN parçası: taslağı üreten kural ile onu
/// tüketen kabuk aynı tanıma bakmalı, iki yerde iki ayrı `split('/')` olmamalı.
({String tur, String? id})? bildirimYoluCoz(String? yol) {
  final ham = yol?.trim();
  if (ham == null || ham.isEmpty) return null;
  if (ham == 'gunsonu') return (tur: 'gunsonu', id: null);
  final musteri = RegExp(r'^musteri/(.+)$').firstMatch(ham);
  if (musteri != null) return (tur: 'musteri', id: musteri.group(1));
  return null;
}

/// Bildirim altyapısının dış yüzü. Kural yazan taraf YALNIZ bunu görür.
///
/// [goster] ve [zamanla] SESSİZCE ATLAYABİLİR: kategori kapalıysa, izin yoksa, günlük sınır
/// dolduysa bildirim çizilmez. Bu bilinçlidir — kural fonksiyonu "gösterildi mi" diye
/// dallanmamalı, yalnız doğru taslağı üretmelidir.
abstract class BildirimServisi {
  Future<bool> izinDurumu();
  Future<bool> izinIste();
  Future<void> goster(BildirimTaslagi t);
  Future<void> zamanla(BildirimTaslagi t, DateTime neZaman);
  Future<void> iptal(String kimlik);
  Future<bool> kategoriAcikMi(BildirimKategori k);
}

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

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Günlük sınır — bildirim yorgunluğuna karşı
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Günde 30 sipariş giren bir bayi bildirim yağmuru görürse HEPSİNİ kapatır, sonra önemlisini
/// de kaçırır. Sayılar Faz 1 varsayılanıdır, sahadan gelen geri bildirimle ayarlanır.
///
/// AYNI KİMLİĞİN GÜNCELLENMESİ BÜTÇE YEMEZ: bir borç bildirimi gün içinde üç kez tazelense
/// bile tek bildirimdir — sayaç ayrı KİMLİK sayar, gösterim değil.
@immutable
class GunlukSinir {
  const GunlukSinir({this.toplam = 6, this.kategoriBasina = 2});

  /// Bir günde çizilebilecek toplam FARKLI bildirim.
  final int toplam;

  /// Tek bir kategorinin bütçeyi tek başına tüketmesini engeller.
  final int kategoriBasina;

  /// [gunlukKimlikler] o güne ait, kategori bazında gösterilmiş KİMLİK kümeleridir.
  bool yerVarMi(BildirimKategori k, Map<BildirimKategori, Set<String>> gunlukKimlikler, String kimlik) {
    final kategorininki = gunlukKimlikler[k] ?? const <String>{};
    // Zaten gösterilmiş kimliğin tazelenmesi her zaman serbesttir.
    if (kategorininki.contains(kimlik)) return true;
    if (kategorininki.length >= kategoriBasina) return false;
    final toplamSayi = gunlukKimlikler.values.fold<int>(0, (t, s) => t + s.length);
    return toplamSayi < toplam;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Test ikizi — kural yazan taraflar bunu kullanır
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Gerçek servisin yerine geçen, hiçbir platform çağrısı yapmayan kayıt tutucu.
/// Kural testleri "şu taslak üretildi mi" sorusunu buna sorar.
class SahteBildirimServisi implements BildirimServisi {
  SahteBildirimServisi({
    bool izinVar = true,
    Set<BildirimKategori>? kapaliKategoriler,
  })  : _izin = izinVar,
        _kapali = kapaliKategoriler ?? <BildirimKategori>{};

  bool _izin;
  final Set<BildirimKategori> _kapali;

  /// Gösterilen taslaklar, sırayla.
  final List<BildirimTaslagi> gosterilenler = [];

  /// Zamanlananlar: (taslak, an).
  final List<(BildirimTaslagi, DateTime)> zamanlananlar = [];

  /// İptal edilen kimlikler.
  final List<String> iptaller = [];

  @override
  Future<bool> izinDurumu() async => _izin;

  @override
  Future<bool> izinIste() async => _izin = true;

  @override
  Future<void> goster(BildirimTaslagi t) async {
    if (!_izin || _kapali.contains(t.kategori)) return;
    // Aynı kimlik ÜZERİNE YAZAR — gerçek servisin davranışının aynısı.
    gosterilenler.removeWhere((x) => x.kimlik == t.kimlik);
    gosterilenler.add(t);
  }

  @override
  Future<void> zamanla(BildirimTaslagi t, DateTime neZaman) async {
    if (!_izin || _kapali.contains(t.kategori)) return;
    zamanlananlar.removeWhere((x) => x.$1.kimlik == t.kimlik);
    zamanlananlar.add((t, neZaman));
  }

  @override
  Future<void> iptal(String kimlik) async {
    iptaller.add(kimlik);
    gosterilenler.removeWhere((x) => x.kimlik == kimlik);
    zamanlananlar.removeWhere((x) => x.$1.kimlik == kimlik);
  }

  @override
  Future<bool> kategoriAcikMi(BildirimKategori k) async => !_kapali.contains(k);
}
