// ÜRETİLEN ŞEY ve NEREYE GÖTÜRDÜĞÜ — bildirim taslağı, kimliği ve `yol` sözlüğü.
//
// NEDEN AYRI DOSYA: `bildirim_sozlesmesi.dart` 593 satıra çıkmıştı (depo sınırı 500). Ayrım
// KONUYA göre: orası KATEGORİLERİ tanımlar (hangi kanal, hangi ses, heads-up mu, kim görür),
// burası bir kuralın ÜRETTİĞİ nesneyi ve o nesnenin dokunulduğunda nereye götürdüğünü.
//
// NEDEN `part` (ayrı kütüphane değil): `BildirimTaslagi`, `bildirimKimligi`, `bildirimYoluCoz`
// bu depoda kural motoru, push katmanı, kabuk ve testlerin
// `bildirim_sozlesmesi.dart`tan import ettiği ADLARDIR. Ayrı kütüphane yapmak ya her çağrı
// yerini değiştirmeyi ya da bir `export` köprüsü kurmayı gerektirirdi; `part` ile hiçbiri
// değişmez. Dosya SAF kalır: platform kanalı, veritabanı, paket bağımlılığı YOK.

part of 'bildirim_sozlesmesi.dart';

/// Kural fonksiyonlarının ÜRETTİĞİ şey. Yan etkisi yok, eşitliği tanımlı, test edilebilir.
@immutable
class BildirimTaslagi {
  const BildirimTaslagi({
    required this.kategori,
    required this.baslik,
    required this.govde,
    required this.kimlik,
    this.yol,
    this.detay,
    this.kararIster = false,
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

  /// Dokununca gidilecek ekran. Sözlük: `gunsonu` · `siparisler` · `cihazlar` · `musteri/<id>`.
  /// Boş bırakılırsa uygulama ana ekranda açılır.
  final String? yol;

  /// GENİŞLETİLMİŞ bildirimin metni — bayi bildirimi aşağı çekince görünen tam hâli.
  /// `null` = bu bildirim genişlemez (tek satır yeter).
  ///
  /// [govde] İLE İLİŞKİSİ: `govde` daraltılmış hâlde TEK SATIRDIR ve Android onu keser;
  /// `detay` ise çok satırlı olabilir. Bu yüzden detay, gövdenin uzun karşılığıdır — gövdede
  /// olmayan bir bilgiyi detaya koymak, bildirimi açmayan bayiden o bilgiyi saklamak olur.
  ///
  /// NEREDE DEĞERLİ: karar verilecek bildirimlerde (gün özeti: üç rakam; sipariş atandı:
  /// müşteri + adres). NEREDE GEREKSİZ: olan biteni haber verenlerde ("teslim edildi") —
  /// oraya detay koymak, açılacak bir şey varmış gibi göstermektir.
  ///
  /// ⚠️ KİLİT EKRANI KURALI DETAYA DA GEÇERLİ: müşteri adı/adresi burada da GÖVDE tarafındadır,
  /// başlıkta değil.
  final String? detay;

  /// AYNI KİMLİK = AYNI BİLDİRİM: ikinci gösterim yeni satır açmaz, üzerine yazar
  /// (çağrı günlüğündeki `insertOnConflictUpdate` mantığının bildirim karşılığı) ve günlük
  /// bildirim bütçesinden İKİNCİ KEZ düşmez.
  ///
  /// [bildirimKimligi] ile üretin — elle string birleştirmeyin, kategori öneki zorunludur.
  final String kimlik;

  /// BİLDİRİMİN İÇİNE "Onayla" / "Reddet" DÜĞMELERİ KONSUN MU (kullanıcı isteği 2026-08-22)?
  ///
  /// ⚠️ DÜĞMELER KARARI ARKA PLANDA UYGULAMAZ, uygulamayı AÇAR ve kararı taşır
  /// (`showsUserInterface: true`). Gerekçe bu deponun en sert kurallarından biri: arka plan
  /// isolate'i SQLite'a YAZMAZ (`push_servisi.dart` başlığı) — para ve defter kayıtlarının
  /// bütünlüğü, bir dokunuşun kazandıracağı saniyeden değerlidir. Kullanıcı açısından fark
  /// yok denecek kadar azdır: dokunur, uygulama açılır, karar uygulanır ve sonucu ekranda
  /// görür. Sessizce uygulanan bir iptalin geri dönüşü ise yoktur.
  ///
  /// [yol] ZORUNLU HÂLE GELİR: karar uygulanacak kaydın kimliği oradan okunur.
  final bool kararIster;

  BildirimTaslagi kopyala({String? baslik, String? govde, String? yol, String? detay}) =>
      BildirimTaslagi(
        kategori: kategori,
        baslik: baslik ?? this.baslik,
        govde: govde ?? this.govde,
        kimlik: kimlik,
        yol: yol ?? this.yol,
        detay: detay ?? this.detay,
        kararIster: kararIster,
      );

  @override
  bool operator ==(Object other) =>
      other is BildirimTaslagi &&
      other.kategori == kategori &&
      other.baslik == baslik &&
      other.govde == govde &&
      other.yol == yol &&
      other.detay == detay &&
      other.kararIster == kararIster &&
      other.kimlik == kimlik;

  @override
  int get hashCode =>
      Object.hash(kategori, baslik, govde, yol, detay, kimlik, kararIster);

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
///
/// [eylem] — yolun sonundaki `#eylem` eki (2026-08-22). Bildirimin İÇİNDEKİ düğmeye
/// dokunulduğunda hangi kararın verildiğini taşır (`iptal_onay` · `iptal_ret`); gövdeye
/// dokunulduğunda `null`dır. Ek, YOLUN KENDİSİNDEN AYRI taşınmaz çünkü Android bize tek bir
/// `payload` dizesi geri verir ve ikinci bir kanal açmak (statik alan, kuyruk) aynı bilgiyi
/// iki yerde tutmak olurdu.
({String tur, String? id, String? eylem})? bildirimYoluCoz(String? yol) {
  var ham = yol?.trim();
  if (ham == null || ham.isEmpty) return null;

  String? eylem;
  final kanca = ham.indexOf('#');
  if (kanca >= 0) {
    eylem = ham.substring(kanca + 1).trim();
    if (eylem.isEmpty) eylem = null;
    ham = ham.substring(0, kanca).trim();
  }
  if (ham.isEmpty) return null;

  if (ham == 'gunsonu') return (tur: 'gunsonu', id: null, eylem: eylem);
  /*
   * `siparisler` — sipariş LİSTESİ, kimliksiz. Push bildirimleri (atandı · teslim edildi)
   * buraya götürür.
   *
   * ⚠️ `siparis/<id>` DE VAR ARTIK (2026-08-22) ve eski yorumun gerekçesi düştü: "tüketecek
   * bir sipariş detay ekranı yok" doğru DEĞİLDİ — `siparisDetaySheetAc` var ve liste, harita,
   * müşteri defteri onu zaten açıyordu. İptal onayı bildirimi kimliği taşımak ZORUNDA: karar
   * düğmesinin uygulayacağı kayıt odur. Kimliksiz yol (`siparisler`) KALDI ve kaldırılmaz —
   * sahadaki eski bildirimler onu taşıyor.
   */
  if (ham == 'siparisler') return (tur: 'siparisler', id: null, eylem: eylem);
  // `cihazlar` — Hesap → Cihazlar ekranı. "Yeni cihaz girişi" bildiriminin hedefi: bayi
  // uyarıyı görür görmez hangi telefonların bağlı olduğunu görebilmeli, aramak zorunda kalmamalı.
  if (ham == 'cihazlar') return (tur: 'cihazlar', id: null, eylem: eylem);
  final siparis = RegExp(r'^siparis/(.+)$').firstMatch(ham);
  if (siparis != null) return (tur: 'siparis', id: siparis.group(1), eylem: eylem);
  final musteri = RegExp(r'^musteri/(.+)$').firstMatch(ham);
  if (musteri != null) return (tur: 'musteri', id: musteri.group(1), eylem: eylem);
  return null;
}
