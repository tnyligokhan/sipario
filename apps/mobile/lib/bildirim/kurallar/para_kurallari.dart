// PARA / VERESİYE bildirim kuralları (Faz 1). Üç kural: gün sonu özeti, borç eşiği aşımı,
// vadesi geçen borçlar.
//
// BU DOSYA SAFTIR: veritabanı okumaz, saat okumaz, bildirim göstermez. Girdi olarak değer alır,
// çıktı olarak `ParaBildirimi?` döner. "Şimdi" bile parametredir — kural testi sahte saate,
// sahte veritabanına ya da widget'a ihtiyaç duymaz. Okuma katmanı `DayEndRepository`dedir.
//
// PARA: her yerde int kuruş; gösterime çevirme YALNIZ `formatKurus` üzerinden (DECISIONS: kayan
// nokta yok, kuruş farkı ürüne güveni öldürür). Bildirimdeki rakam bayinin gün sonu EKRANINDA
// gördüğü rakamla aynı kaynaktan gelir (DayEndRepository) — iki yüzey farklı sayı konuşamaz.
//
// KİLİT EKRANI (cagri sözleşmesi): `govde` GİZLENİR, `baslik` GÖRÜNÜR. Müşteri adı ve borç tutarı
// yalnız GÖVDEDE geçer; başlıklar nötrdür ("Borç eşiği aşıldı"), çünkü kilit ekranını başkası
// görebilir. Bu kural üç bildirimde de uygulanmıştır.
//
// KATEGORİ BAŞINA GÜNDE 2 BİLDİRİM SINIRI VAR (GunlukSinir): bu yüzden MÜŞTERİ BAŞINA ayrı
// bildirim ÜRETİLMEZ — üçüncü müşteri sessizce düşerdi. Borç eşiği de vade taraması da TEK ÖZET
// taslak üretir ve ayırt edicisi GÜNdür; gün içinde yeni müşteri eklenirse aynı kimlik ÜZERİNE
// YAZILIR (bütçeden ikinci kez düşmez, bayi tek bir güncel satır görür).

import '../../theme/components/bicim.dart' show sipTutar;
import '../bildirim_sozlesmesi.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Varsayılan zamanlama
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Gün sonu özeti saati. 20:00 önerisi: su/tüp bayiinde akşam teslimatları biter, kasa sayılır;
/// bildirim bayinin elindeki defterle karşılaştırma yapacağı ana denk gelmeli. Daha erken atarsa
/// akşam teslimatları rakamın dışında kalır ve "tutmuyor" hissi doğar — bu üründe en pahalı his.
const int kGunSonuSaati = 20;

/// Vadesi geçen borç taraması: PAZARTESİ 10:00. Hafta başı, çünkü borç kovalamak planlanacak bir
/// iştir (kimi arayacağım, kimden ne isteyeceğim); hafta sonu ya da cuma akşamı atılan bildirim
/// eyleme dönüşmez. 10:00, esnafın dükkânı açıp oturduğu saat.
const int kVadeTaramaGunu = DateTime.monday;
const int kVadeTaramaSaati = 10;

/// Borç eşiğinin KAPALI değeri — ve Faz 1'in VARSAYILANI (lead kararı).
///
/// Bir sayı uydurmak yerine özellik kapalı başlar: cirosu 2.000 ₺ olan bayi ile 200.000 ₺ olan
/// aynı sınırı kullanamaz; kötü bir varsayılan ya bildirimi anlamsızca susturur ya da gürültüye
/// çevirir — ikisi de bayiye TÜM bildirimleri kapattırır. Ayarlarda eşik alanı boşken kategori
/// pasif görünür ("bir eşik belirleyin"); bayi kendi rakamını girince kural çalışmaya başlar.
///
/// Eşik ≤ 0 verildiğinde [esikAsildiMi] daima `false`, [borcEsigiBildirimi] daima `null` döner ve
/// `DayEndRepository.bugunEsigiAsanlar` defteri hiç okumaz.
const int kBorcEsigiKapali = 0;

/// "Vadesi geçmiş" sayılan gün eşiği. 30 gün: aylık dönen bir nakit akışında bir ayı geçen borç
/// artık "unutulmuş"tur; 15 gün çok erken (normal işleyişi alarma çevirir), 60 gün çok geç
/// (para tahsil edilemez hâle gelir). Bayi değiştirebilsin diye parametre olarak da alınır.
const int kVadeGunEsigi = 30;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// 1) GÜN SONU ÖZETİ
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Gün sonu kuralının girdisi — üç rakam, hepsi TR takvim gününe göre (`DayEndRepository`).
class GunSonuVerisi {
  const GunSonuVerisi({
    required this.gun,
    required this.tahsilatKurus,
    required this.teslimatSayisi,
    required this.veresiyeKurus,
  });

  /// TR takvim günü (yerel tarih; saat kısmı kullanılmaz).
  final DateTime gun;

  /// KASAYA GİREN para (nakit+kart+havale). Bayinin fiziksel olarak sayacağı tutar budur —
  /// eski borç tahsilatı da dâhildir, çünkü o para da bugün kasaya girdi.
  final int tahsilatKurus;

  /// Teslim edilen sipariş sayısı (iptaller hariç).
  final int teslimatSayisi;

  /// BUGÜN YAZILAN net yeni borç: günün `debit` toplamı − günün SİPARİŞ BAĞLI tahsilatı.
  /// Sipariş dışı tahsilat (eski borcun ödenmesi) buradan DÜŞÜLMEZ; o bugün yazılmış bir
  /// veresiyeyi kapatmaz ve düşülseydi "bugün ne kadar veresiye verdim" sorusu yanlış cevaplanırdı.
  final int veresiyeKurus;

  /// Hiç hareket yoksa bildirim atılmaz — boş bildirim gürültüdür ve bir sonrakinin okunma
  /// ihtimalini düşürür.
  bool get bosGun => tahsilatKurus == 0 && teslimatSayisi == 0 && veresiyeKurus == 0;
}

/// Gün sonu özeti bildirimi. Boş günde `null`.
///
/// HANGİ ÜÇ RAKAM VE NEDEN: bayinin akşam yaptığı iş üç sorunun cevabıdır — (1) kasada ne kadar
/// para olmalı, (2) kaç iş yaptım, (3) ne kadarını veresiye verdim. Dördüncü bir rakam (toplam
/// açık borç) eklenmedi: o günlük değil BİRİKİMLİ bir büyüklüktür, her akşam tekrarlanınca
/// anlamını yitirir ve zaten "vadesi geçen borçlar" kuralının konusudur.
BildirimTaslagi? gunSonuOzeti(GunSonuVerisi v) {
  if (v.bosGun) return null;
  return BildirimTaslagi(
    kategori: BildirimKategori.gunSonuOzeti,
    // Nötr başlık: rakamlar kilit ekranında görünmesin. Ad EKRANLA AYNI olmak zorunda
    // (kullanıcı kararı 2026-08-06): çekmece "Gün Özeti" derken bildirim başka bir ad söylerse
    // bayi iki ayrı özellik olduğunu sanar. Kanal kimliği (`wire`) DEĞİŞMEDİ.
    baslik: 'Gün özeti',
    govde: 'Bugün ${sipTutar(v.tahsilatKurus)} tahsil edildi · '
        '${v.teslimatSayisi} teslim · ${sipTutar(v.veresiyeKurus)} veresiye yazıldı',
    // Günde TEK özet: ayırt edici TR takvim günü. İki kez tetiklense (yeniden başlatma,
    // zamanlayıcı çakışması) aynı kimlik üzerine yazılır, ikinci bildirim doğmaz.
    kimlik: bildirimKimligi(BildirimKategori.gunSonuOzeti, bildirimGunAnahtari(v.gun)),
    yol: 'gunsonu',
  );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// 2) BORÇ EŞİĞİ AŞIMI
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bakiyeyi değiştiren TEK bir defter yazımının öncesi/sonrası. Kural bir SEVİYE değil bir
/// GEÇİŞ (edge) görür — mükerrer bildirimin kökten çözümü budur (aşağıya bakınız).
class BorcEsigiOlayi {
  const BorcEsigiOlayi({
    required this.customerId,
    required this.ad,
    required this.oncekiBakiyeKurus,
    required this.yeniBakiyeKurus,
    required this.occurredAtIso,
  });

  final String customerId;
  final String ad;

  /// Bu yazımdan ÖNCEKİ bakiye = güncel bakiye − yazılan tutar (bakiye zaten `SUM(amount_kurus)`,
  /// dolayısıyla bu çıkarma kesindir, tahmin değildir).
  final int oncekiBakiyeKurus;
  final int yeniBakiyeKurus;

  /// Geçişi tetikleyen kaydın zamanı — kimliği tekilleştirir.
  final String occurredAtIso;
}

/// Bu TEK yazım bakiyeyi eşiğin altından üstüne taşıdı mı?
///
/// MÜKERRER BİLDİRİMİN KÖKTEN ÇÖZÜMÜ: kural "bakiye > eşik mi" diye BAKMAZ (öyle olsaydı eşiğin
/// üstündeki her yazımda tekrar ateşlerdi), "bu yazım eşiği GEÇTİ mi" diye bakar. Bir kez
/// aşıldıktan sonra ikinci geçiş ancak bakiye eşiğin ALTINA düşüp tekrar çıkarsa oluşur —
/// istenen davranış tam olarak budur. Durum saklamaya, sayaç tutmaya gerek yok.
///
/// [esikKurus] parametredir: sabit eşik bayiden bayiye anlamsızdır (günlük cirosu 2.000 ₺ olanla
/// 200.000 ₺ olan aynı sınırı kullanamaz). Ayar deposuna bağlama lead/cagri tarafındadır.
bool esikAsildiMi(BorcEsigiOlayi o, {required int esikKurus}) {
  if (esikKurus <= kBorcEsigiKapali) return false; // özellik kapalı (Faz 1 varsayılanı)
  return o.oncekiBakiyeKurus < esikKurus && o.yeniBakiyeKurus >= esikKurus;
}

/// Eşiği bugün aşan bir müşteri.
class EsikAsanMusteri {
  const EsikAsanMusteri({
    required this.customerId,
    required this.ad,
    required this.bakiyeKurus,
  });
  final String customerId;
  final String ad;

  /// Geçiş anındaki (güncel) bakiye.
  final int bakiyeKurus;
}

/// Borç eşiği bildirimi — GÜNLÜK TEK ÖZET, müşteri başına değil.
///
/// NEDEN ÖZET: kategori başına günde 2 bildirim sınırı var (`GunlukSinir`); müşteri başına
/// üretseydik üçüncü müşteri sessizce düşerdi ve bayi en kritik olanı kaçırabilirdi. Ayırt edici
/// GÜNdür: gün içinde dördüncü müşteri de aşarsa aynı kimlik ÜZERİNE YAZILIR — bütçeden ikinci
/// kez düşmez, bayi tek ve güncel bir satır görür.
///
/// Hangi müşterilerin bugün geçtiği [esikAsildiMi] ile belirlenir (okuma katmanı:
/// `DayEndRepository.bugunEsigiAsanlar`).
BildirimTaslagi? borcEsigiBildirimi(
  List<EsikAsanMusteri> asanlar, {
  required DateTime gun,
  required int esikKurus,
}) {
  if (asanlar.isEmpty || esikKurus <= kBorcEsigiKapali) return null;

  // Tek müşteride ADIYLA seslen — gövde kilit ekranında gizli, ad yazmak güvenli ve bildirim
  // tek dokunuşluk bir işe dönüşüyor. Çoklu durumda ad listesi gövdeyi okunmaz yapar.
  final govde = asanlar.length == 1
      ? '${asanlar.single.ad} · borç ${sipTutar(asanlar.single.bakiyeKurus)} '
          '(eşik ${sipTutar(esikKurus)})'
      : '${asanlar.length} müşterinin borcu ${sipTutar(esikKurus)} eşiğini aştı · '
          'toplam ${sipTutar(asanlar.fold<int>(0, (s, m) => s + m.bakiyeKurus))}';

  return BildirimTaslagi(
    kategori: BildirimKategori.borcEsigi,
    baslik: 'Borç eşiği aşıldı',
    govde: govde,
    kimlik: bildirimKimligi(BildirimKategori.borcEsigi, bildirimGunAnahtari(gun)),
    // Tek müşteride doğrudan kartına git; çoklu durumda Faz 1 sözlüğünde borçlu listesi yolu
    // YOK, boş bırakılır (uygulama ana ekranda açılır).
    yol: asanlar.length == 1 ? 'musteri/${asanlar.single.customerId}' : null,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// 3) VADESİ GEÇEN BORÇLAR (haftalık)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Tek bir defter satırının kurala yeten kısmı (saf girdi — Drift tipi sızmaz).
class DefterHareketi {
  const DefterHareketi({required this.occurredAt, required this.amountKurus});

  /// Kaydın zamanı (sunucu-düzeltilmiş, UTC).
  final DateTime occurredAt;

  /// İMZALI kuruş: + borç doğuran (debit / pozitif correction), − borcu azaltan
  /// (payment / credit / negatif correction). Tip adına DEĞİL işarete bakılır — defterin
  /// kuralı zaten budur (`bakiye = SUM(amount_kurus)`).
  final int amountKurus;
}

/// Bir müşterinin gecikmiş borcu (kuruş). Borcu yoksa ya da tamamı taze ise 0.
///
/// FIFO YAŞLANDIRMA — "30 gün"ü NEYE göre saydığımızın cevabı: ödemeler EN ESKİ borcu kapatır.
/// Kalan (kapanmamış) borç parçalarından [gunEsigi] günden eski olanların toplamı "gecikmiş"tir.
///
/// İki basit alternatif REDDEDİLDİ:
///  • "Borcun doğduğu tarih" (en eski `debit`): düzenli ödeyen ama bakiyesi hiç sıfırlanmayan
///    müşteriyi sonsuza dek gecikmiş gösterirdi — bayinin en iyi müşterileri alarma girerdi.
///  • "Son tahsilat tarihi": 10.000 ₺ borcu olup her ay 50 ₺ ödeyen müşteriyi temiz gösterirdi;
///    borcun YAŞINI değil sadece temas tarihini ölçer.
/// FIFO ikisini de düzeltir: düzenli ödeyenin eski borcu ödemelerle tüketilir, sembolik ödeme
/// yapanın eski borcu tüketilmeden kalır. Muhasebedeki alacak yaşlandırmasının ta kendisi.
int gecikmisTutar(
  List<DefterHareketi> hareketler, {
  required DateTime simdi,
  int gunEsigi = kVadeGunEsigi,
}) {
  final sirali = [...hareketler]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

  // Açık borç parçaları, eskiden yeniye: (zaman, kalan tutar).
  final acik = <({DateTime zaman, int kalan})>[];
  for (final h in sirali) {
    if (h.amountKurus > 0) {
      acik.add((zaman: h.occurredAt, kalan: h.amountKurus));
      continue;
    }
    // Ödeme/alacak: en eski borçtan başlayarak tüket.
    var kalanOdeme = -h.amountKurus;
    while (kalanOdeme > 0 && acik.isNotEmpty) {
      final ilk = acik.first;
      if (ilk.kalan > kalanOdeme) {
        acik[0] = (zaman: ilk.zaman, kalan: ilk.kalan - kalanOdeme);
        kalanOdeme = 0;
      } else {
        kalanOdeme -= ilk.kalan;
        acik.removeAt(0);
      }
    }
    // Fazla ödeme (bakiye alacağa geçti) bilerek YUTULUR: alacaklı müşterinin gecikmiş borcu
    // yoktur ve negatif bakiyeyi ileride doğacak borca saymak yaşlandırmayı bozar.
  }

  final sinir = simdi.subtract(Duration(days: gunEsigi));
  return acik
      .where((p) => p.zaman.isBefore(sinir))
      .fold<int>(0, (s, p) => s + p.kalan);
}

/// Haftalık taramanın girdisi: müşteri başına gecikmiş tutar (0 olanlar elenmiş olabilir).
class GecikmisMusteri {
  const GecikmisMusteri({
    required this.customerId,
    required this.ad,
    required this.gecikmisKurus,
  });
  final String customerId;
  final String ad;
  final int gecikmisKurus;
}

/// Vadesi geçen borçlar bildirimi. Gecikmiş müşteri yoksa `null` (boş bildirim atılmaz).
///
/// [haftaBasi] kimliği tekilleştirir: aynı hafta içinde ikinci kez tetiklense bastırılır,
/// sonraki hafta yeniden bildirilir (borç durmuyorsa hatırlatma da durmamalı).
BildirimTaslagi? vadesiGecenBorclar(
  List<GecikmisMusteri> musteriler, {
  required DateTime haftaBasi,
  int gunEsigi = kVadeGunEsigi,
}) {
  final gecikmis = musteriler.where((m) => m.gecikmisKurus > 0).toList();
  if (gecikmis.isEmpty) return null;

  final toplam = gecikmis.fold<int>(0, (s, m) => s + m.gecikmisKurus);

  // Tek müşteride ADIYLA seslen: "1 müşterinin borcu" demek, bayinin zaten bildiği bir şeyi
  // gizlemektir; adı yazınca bildirim tek dokunuşluk bir işe dönüşür. (Ad GÖVDEDE, yani kilit
  // ekranında gizli.)
  final govde = gecikmis.length == 1
      ? '${gecikmis.single.ad} · ${sipTutar(toplam)} ($gunEsigi günü geçti)'
      : '${gecikmis.length} müşterinin borcu $gunEsigi günü geçti · '
          'toplam ${sipTutar(toplam)}';

  return BildirimTaslagi(
    kategori: BildirimKategori.vadesiGecenBorc,
    baslik: 'Vadesi geçen borçlar',
    govde: govde,
    // Haftalık ayırt edici: haftanın PAZARTESİ tarihi. Aynı hafta içindeki her tetikleme aynı
    // kimliği üretir (üzerine yazar), sonraki hafta yeni bildirim doğar.
    kimlik: bildirimKimligi(BildirimKategori.vadesiGecenBorc, bildirimGunAnahtari(haftaBasi)),
    yol: gecikmis.length == 1 ? 'musteri/${gecikmis.single.customerId}' : null,
  );
}

/// Verilen tarihi içeren haftanın PAZARTESİsi (yerel tarih, saat sıfırlanmış). Haftalık kimliğin
/// dayanağı — aynı hafta içindeki her tetikleme aynı anahtarı üretir.
DateTime haftaninBasi(DateTime t) {
  final gun = DateTime(t.year, t.month, t.day);
  return gun.subtract(Duration(days: gun.weekday - DateTime.monday));
}
