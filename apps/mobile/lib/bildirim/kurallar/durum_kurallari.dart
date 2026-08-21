// DURUM bildirim kuralları (kullanıcı kararı 2026-08-14): senkron uyarısı · kullanım hakkı ·
// gün kapanışı hatırlatmaları.
//
// ÜÇÜNÜN ORTAK YANI: hiçbiri "olan biteni" haber vermez, hepsi EKSİK KALAN BİR ŞEYİ söyler.
// Bu yüzden metinleri bir eylem önerir; yalnız durum bildiren bir cümle ("senkron yapılamadı")
// bayiye ne yapacağını söylemez ve bildirim gürültüye dönüşür.
//
// BU DOSYA SAFTIR: veritabanı okumaz, saat okumaz. Girdi olarak değer alır, taslak döner.
// Okuma katmanı `durum_ureticileri.dart`tadır.

import '../../theme/components/bicim.dart' show sipTutar;
import '../bildirim_sozlesmesi.dart';

/// Kaç gün senkron yapılamayınca uyarılır.
///
/// 2 GÜN, çünkü kısa kopukluklar bu üründe NORMALDİR ve uyarı üretmemelidir: bodrum, asansör,
/// sinyal çukuru (BRIEF: tipik kopukluk 10 dakika, azami birkaç saat). Bir günü aşan sessizlik
/// ise artık "ağ yoktu" değil "bir şey bozuk" demektir — ve o noktada bayinin bilmesi gerekir,
/// çünkü abonelik önbelleği bayatlarsa uygulama salt-okunura düşer ve sebebi anlaşılmaz.
const int kSenkronUyariGunu = 2;

/// Kaç hak kalınca uyarılır. 3: bir günlük tipik kullanımı karşılar, yani bayinin tedbir
/// alacak vakti kalır. Daha erken uyarmak (ör. 10) henüz sorun olmayan bir şeyi sorun gibi
/// gösterirdi.
const int kKullanimHakkiEsigi = 3;

/// Kasa devri hatırlatmasının saati. 21:00: akşam teslimatları bitmiş, kurye dönmüş olur;
/// gün sonu özetinden (20:00) sonra gelir ki bayi önce rakamı görsün, sonra eksiği duysun.
const int kKasaHatirlatmaSaati = 21;

/// "Dün gün kapatılmadı" hatırlatmasının saati. 09:00: dükkânın açıldığı saat. Gece atmak
/// anlamsız — kapatma işi ancak ertesi gün yapılabilir.
const int kSabahHatirlatmaSaati = 9;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// 1) SENKRON UYARISI
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Uzun süredir sunucuya ulaşılamadı uyarısı. Eşiğin altındaysa `null`.
///
/// [sonBasariliSenkron] `null` ise (hiç senkron olmamış) uyarı ÜRETİLMEZ: yeni kurulmuş, henüz
/// bir kez bile bağlanmamış bir cihazı "2 gündür bağlanamıyor" diye korkutmak yanlış olurdu.
BildirimTaslagi? senkronUyarisi({
  required DateTime? sonBasariliSenkron,
  required DateTime simdi,
  int esikGun = kSenkronUyariGunu,
}) {
  if (sonBasariliSenkron == null) return null;

  final gun = simdi.difference(sonBasariliSenkron).inDays;
  if (gun < esikGun) return null;

  return BildirimTaslagi(
    kategori: BildirimKategori.sistem,
    baslik: 'Sunucuya bağlanılamıyor',
    govde: '$gun gündür sunucuya bağlanılamadı',
    // DETAY YALNIZ İÇİ RAHATLATIR: bu uyarıyı gören esnafın ilk düşüncesi "verilerim gitti mi?"
    // olur. Gövdeyi tekrar etmez — bildirim açıldığında zaten görünüyor.
    detay: 'Kayıtlarınız telefonda duruyor, kaybolmaz. Bağlantı gelince kendiliğinden gider.',
    kimlik: bildirimKimligi(BildirimKategori.sistem, bildirimGunAnahtari(simdi)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// 2) KULLANIM HAKKI (oto-sıralama kontörü)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Oto-sıralama hakkı azaldı/bitti uyarısı.
///
/// ⚠️ NÖTR KALMAK ZORUNDA (BRIEF mağaza kuralı): fiyat, paket adı, "satın al" çağrısı ya da
/// siteye yönlendirme İÇEREMEZ. Söylediği tek şey, özelliğin neden çalışmadığıdır.
///
/// [aylik] 0 ise özellik o bayide HİÇ TANIMLI DEĞİLDİR ve uyarı üretilmez — olmayan bir
/// özelliğin bittiğini haber vermek, var olduğunu sanmasına yol açardı.
BildirimTaslagi? kullanimHakkiUyarisi({
  required int kalan,
  required int aylik,
  required DateTime gun,
  int esik = kKullanimHakkiEsigi,
}) {
  if (aylik <= 0) return null;
  if (kalan > esik) return null;

  final bitti = kalan <= 0;

  return BildirimTaslagi(
    kategori: BildirimKategori.kullanimHakki,
    baslik: bitti ? 'Oto-sıralama hakkınız bitti' : 'Oto-sıralama hakkınız azaldı',
    govde: bitti
        ? 'Bu ayki $aylik hakkın tamamı kullanıldı'
        : 'Bu ay $kalan hakkınız kaldı',
    detay: bitti
        ? 'Siparişleri elle sıralayabilirsiniz. Hak ay başında yenilenir.'
        : null,
    // GÜN DAMGALI: gün içinde birkaç rota çalıştırılırsa aynı bildirim tazelenir, yenisi
    // doğmaz. Ay damgası YETMEZDİ — hak azalırken tek bir uyarı verip susardı.
    kimlik: bildirimKimligi(BildirimKategori.kullanimHakki, bildirimGunAnahtari(gun)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// 3) GÜN KAPANIŞI HATIRLATMALARI
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Kuryelerde duran nakit akşam hâlâ devredilmediyse uyarır.
///
/// [kuryedeKalanKurus] 0 ya da altındaysa `null`: devredilecek para yoksa hatırlatılacak bir
/// eksik de yoktur. Negatif değer de sessizdir — kurye kendi cebinden ara tahsilat vermiş
/// olabilir ve o bir eksiklik değildir.
BildirimTaslagi? kasaDevriHatirlatmasi({
  required int kuryedeKalanKurus,
  required int kuryeSayisi,
  required DateTime gun,
}) {
  if (kuryedeKalanKurus <= 0 || kuryeSayisi <= 0) return null;

  return BildirimTaslagi(
    kategori: BildirimKategori.gunKapanisHatirlatma,
    baslik: 'Kasa devredilmedi',
    // TUTAR GÖVDEDE, BAŞLIK NÖTR: kilit ekranı kuralı (para başkasının gözüne çarpmamalı).
    govde: kuryeSayisi == 1
        ? 'Kuryede ${sipTutar(kuryedeKalanKurus)} görünüyor'
        : '$kuryeSayisi kuryede toplam ${sipTutar(kuryedeKalanKurus)} görünüyor',
    kimlik: bildirimKimligi(
      BildirimKategori.gunKapanisHatirlatma,
      'kasa-${bildirimGunAnahtari(gun)}',
    ),
    yol: 'gunsonu',
  );
}

/// Dün gün kapatılmadıysa sabah uyarır.
///
/// [dunKapatildi] true ise `null`. Kapatılmayan gün ertesi günün rakamlarını kirletir: kasa
/// devri ve tahsilat pencereleri son kapanıştan itibaren sayılır.
/// [oncekiKapanmamis] DÜNDEN ÖNCEKİ kapanmamış gün sayısı (kullanıcı isteği 2026-08-21:
/// "kapanmayan gün/günleriniz var şeklinde göstermeliyiz").
///
/// ⚠️ ESKİDEN YALNIZ DÜNE BAKIYORDU ve bu, şikâyetin sessiz yarısıydı: üst üste üç gün
/// kapatmayan bayi her sabah aynı tekil cümleyi ("Dün gün kapatılmadı") okuyordu. Cümle
/// doğruydu ama BİRİKMENİN kendisini gizliyordu — oysa devreden tutarı büyüten şey tam olarak
/// o birikmedir. Sayı yazınca uyarı bir hatırlatmadan bir DURUM RAPORUNA dönüşür.
///
/// DÜN KAPATILMIŞ AMA ÖNCESİ AÇIKSA YİNE UYARIR: eski günler kendiliğinden kapanmaz ve
/// "dünü kapattım" hissi, üç gün önceki açık günü görünmez kılıyordu.
BildirimTaslagi? gunKapatilmadiHatirlatmasi({
  required bool dunKapatildi,
  required bool dunHareketVardi,
  required DateTime dun,
  int oncekiKapanmamis = 0,
}) {
  // HAREKETSİZ GÜN KAPATILMAZ ve bu bir eksiklik değildir: bayi pazar günü çalışmamıştır.
  // Uyarmak, tatil gününde iş buyurmak olurdu.
  final dunSayilir = !dunKapatildi && dunHareketVardi;
  final toplam = (dunSayilir ? 1 : 0) + (oncekiKapanmamis < 0 ? 0 : oncekiKapanmamis);
  if (toplam == 0) return null;

  // TEK GÜN İÇİN ESKİ CÜMLE KORUNUR ve bu bilinçli: "1 gün kapatılmadı" doğru ama soğuktur;
  // bayinin diliyle konuşan hâli "dün"dür. Çoğulda ise gün adı zaten yetmez.
  final tekDun = toplam == 1 && dunSayilir;

  return BildirimTaslagi(
    kategori: BildirimKategori.gunKapanisHatirlatma,
    baslik: tekDun ? 'Dün gün kapatılmadı' : '$toplam gün kapatılmadı',
    govde: tekDun ? 'Dünün hesabı hâlâ açık' : 'Son $toplam günün hesabı hâlâ açık',
    detay: 'Gün Özeti\'nden kapatabilirsiniz. Kuryedeki nakit sayılmaya devam eder.',
    kimlik: bildirimKimligi(
      BildirimKategori.gunKapanisHatirlatma,
      'gun-${bildirimGunAnahtari(dun)}',
    ),
    yol: 'gunsonu',
  );
}
