// BORÇ HATIRLATMA MESAJI — borçluya WhatsApp'tan gönderilecek metni kurar.
// Kullanıcı isteği (2026-08-04): "borçlular ekranında tek tuşla iban gönderebilmeliyiz ilgili
// müşterinin whatsappına … iban ile birlikte sipariş tutarını müşteri ismini parametre olarak
// alsın ve basit bir hatırlatma mesajı göndersin."
// Kullanıcı isteği (2026-08-06): mesaj DÜZENLENEBİLİR olsun — bayi kendi cümlelerini yazsın,
// yalnız yer tutucuları konumlandırsın.
//
// SAF FONKSİYON: metnin kendisi ürünün MÜŞTERİYE GÖRÜNEN yüzüdür — bayinin adıyla, bayinin
// müşterisine gider. Widget kurmadan test edilebilmesi bu yüzden önemli; tek bir bozuk satır
// bayiyi kendi müşterisinin gözünde küçük düşürür.
//
// TON: kurumsal, kapsamlı ama sert değil (saha, 2026-11-05: "kapsamlı olmalı, kurumsal bir dilde
// olmalı"). Müşteri mesajı okuyunca hesabının durumunu, son hareketlerini ve nasıl ödeyeceğini
// görür. Esnaf-müşteri ilişkisi süreklidir; tehdit, gecikme faizi, son tarih YOK: bunlar bayinin
// kendi kararıdır ve mesaj gönderilmeden önce elle eklenebilir (WhatsApp metni düzenlenebilir gelir).
//
// MESAJ GÖNDERİLMEZ, HAZIRLANIR: `whatsappUriler(..., mesaj:)` sohbeti hazır metinle açar;
// gönder tuşuna bayi basar. Bayi mesajı görmeden müşterisine para isteyen bir metin gitmemeli.

import '../../theme/components/bicim.dart' show sipTelefon, sipTutar;
import '../isletme/iban.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Şablon sözleşmesi
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Şablonda kullanılabilen tek bir yer tutucu (ekrandaki çip bundan çizilir).
class HatirlatmaYerTutucu {
  const HatirlatmaYerTutucu(this.jeton, this.aciklama);

  /// Metnin içine yazılan dizi — ör. `*musteriadi*`.
  final String jeton;

  /// Çipin üstündeki insan adı — ör. "Müşteri adı".
  final String aciklama;
}

/// Tanınan yer tutucular. Bayi bunları EZBERLEMEZ: ekranda çip olarak durur, dokununca imleç
/// konumuna eklenir. Liste burada tektir — ekran da, çözümleyici de aynı kaynaktan okur.
const List<HatirlatmaYerTutucu> hatirlatmaYerTutuculari = [
  HatirlatmaYerTutucu('*musteriadi*', 'Müşteri adı'),
  HatirlatmaYerTutucu('*isletmeadi*', 'İşletme adı'),
  HatirlatmaYerTutucu('*siparistutar*', 'Borç tutarı'),
  HatirlatmaYerTutucu('*ibanodemebilgileri*', 'IBAN + alıcı'),
  HatirlatmaYerTutucu('*tarih*', 'Bugünün tarihi'),
  HatirlatmaYerTutucu('*odenmemissiparis*', 'Ödenmemiş sipariş sayısı'),
  HatirlatmaYerTutucu('*sonsiparistarihi*', 'Son sipariş tarihi'),
  HatirlatmaYerTutucu('*sonodeme*', 'Son ödeme'),
  HatirlatmaYerTutucu('*isletmetelefonu*', 'İşletme telefonu'),
];

/// Müşterinin hesabından mesaja giren özet. Alanlar boşsa ilgili satır mesajdan düşer.
class HatirlatmaHesapOzeti {
  const HatirlatmaHesapOzeti({
    this.odenmemisSiparis = 0,
    this.sonSiparisAt,
    this.sonOdemeAt,
    this.sonOdemeKurus = 0,
  });

  final int odenmemisSiparis;

  /// UTC ISO damgaları; mesajda müşterinin göreceği yerel tarihe çevrilir.
  final String? sonSiparisAt;
  final String? sonOdemeAt;

  /// Son ödemenin tutarı (pozitif kuruş).
  final int sonOdemeKurus;

  String get _sonSiparisMetni => _isoTarih(sonSiparisAt);

  String get _sonOdemeMetni {
    final tarih = _isoTarih(sonOdemeAt);
    return tarih.isEmpty || sonOdemeKurus <= 0 ? '' : '$tarih, ${sipTutar(sonOdemeKurus)}';
  }

  String get _odenmemisMetni => odenmemisSiparis > 0 ? '$odenmemisSiparis adet' : '';

  static String _isoTarih(String? iso) {
    final an = iso == null ? null : DateTime.tryParse(iso);
    return an == null ? '' : hatirlatmaTarihi(an.toLocal());
  }
}

/// "05.11.2026" — mesajda yazan tarih biçimi.
String hatirlatmaTarihi(DateTime t) {
  String iki(int n) => n.toString().padLeft(2, '0');
  return '${iki(t.day)}.${iki(t.month)}.${t.year}';
}

/// Şablon uzunluk sınırı — sunucudaki `reminder_template` kolonuyla AYNI (1000).
///
/// İstemcide de sınır var çünkü sunucudaki sınırın devreye girdiği yer SENKRON PARTİSİDİR:
/// orada aşan değer olayı 'rejected' yapar ve bayi neyin kaydolmadığını FORMDA değil, günler
/// sonra "mesajım eski" diye fark eder.
const int hatirlatmaSablonuAzamiUzunluk = 1000;

/// Şablon form hatası; sorun yoksa `null`. Boş metin HATA DEĞİLDİR — "varsayılana dön" demektir.
///
/// KURAL BURADA, EKRANDA DEĞİL (2026-08-13): şablon düzenleme İşletme Profili formundan çıkıp
/// kendi ekranına taşındı. Kural o formun doğrulayıcısında kalsaydı, taşınmayla birlikte
/// SESSİZCE kaybolurdu — sınırı yalnız sunucu uygulardı ve bayi kaydettiğini sanardı.
String? hatirlatmaSablonuHatasi(String? ham) {
  final s = (ham ?? '').trim();
  if (s.length <= hatirlatmaSablonuAzamiUzunluk) return null;
  return 'Mesaj çok uzun ($hatirlatmaSablonuAzamiUzunluk karakter sınırı, şu an ${s.length})';
}

/// Bayiye DÜZENLEMESİ İÇİN sunulan başlangıç metni. Değerlendirildiğinde (tüm alanlar dolu)
/// [borcHatirlatmaMesaji]'nin varsayılan çıktısıyla BİREBİR aynı metni verir — testle kilitli.
///
/// Bu sabit, "şablon boş" hâlinin karşılığı DEĞİLDİR: boş şablonda aşağıdaki [_varsayilanMesaj]
/// koşar ve o, eksik ad/işletme adı hâllerini de düzgün karşılar ("Sayın , merhaba." yazmaz).
/// Bayi şablonu düzenlemeye başladığı andan itibaren metnin sorumluluğu onundur.
const String varsayilanHatirlatmaSablonu = 'Sayın *musteriadi*,\n'
    '\n'
    '*tarih* tarihi itibarıyla cari hesabınıza ilişkin bilgilendirmemiz aşağıdadır.\n'
    '\n'
    'Güncel bakiyeniz: *siparistutar*\n'
    'Ödenmemiş sipariş: *odenmemissiparis*\n'
    'Son sipariş tarihi: *sonsiparistarihi*\n'
    'Son ödemeniz: *sonodeme*\n'
    '\n'
    '$_odemeGirisSatiri\n'
    '\n'
    '*ibanodemebilgileri*\n'
    '\n'
    'Ödemenizi gerçekleştirdiyseniz bu mesajı dikkate almayınız.\n'
    'Hesabınızla ilgili sorularınız için *isletmetelefonu* numarasından bize ulaşabilirsiniz.\n'
    '\n'
    'İş birliğiniz için teşekkür eder, iyi günler dileriz.\n'
    'Saygılarımızla,\n'
    '*isletmeadi*';

/// IBAN yokken düşer: hesabı göstermeyen bir "aşağıdaki hesaba" cümlesi müşteriyi boşa yollar.
const String _odemeGirisSatiri = 'Ödemenizi aşağıdaki hesaba havale veya EFT yoluyla yapabilirsiniz.';

/// 2026-11-05 öncesinin varsayılan metni. Bayi "Varsayılanı yükle" deyip değiştirmeden kaydettiyse
/// kendi metni değil bu eski varsayılandır ve yenisi uygulanır; bayinin yazdığı metne dokunulmaz.
const String _eskiVarsayilanSablon = 'Sayın *musteriadi*, merhaba.\n'
    '*isletmeadi* olarak hesabınızda *siparistutar* tutarında ödenmemiş bakiye görünüyor.\n'
    '\n'
    '*ibanodemebilgileri*\n'
    '\n'
    'Teşekkür ederiz.';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Mesaj kurulumu
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Hatırlatma metni. [borcKurus] müşterinin DEFTER bakiyesidir (ekrandaki kartın yazdığı sayı) —
/// tek bir siparişin tutarı değil: müşteri "hangi sipariş" diye değil "ne kadar" diye sorar ve
/// bayi de toplamı tahsil eder.
///
/// [iban] null/boşsa metin IBAN bloğu OLMADAN kurulur. Çağıran bu duruma normalde hiç
/// düşmemeli (düğme kapalıdır) ama fonksiyon yine de kullanılabilir bir metin döndürür:
/// yarım bir mesaj, hata fırlatıp bayiyi elleri boş bırakmaktan iyidir.
///
/// [ibanAliciAdi] hesap sahibinin ad soyadıdır; boşsa [isletmeAdi]'na düşülür (2026-08-06
/// öncesi davranış). Bkz. [ibanOdemeBlogu].
///
/// [sablon] bayinin kendi metnidir; null/boş ise varsayılan kurulum koşar.
String borcHatirlatmaMesaji({
  required String musteriAd,
  required int borcKurus,
  String? iban,
  String? isletmeAdi,
  String? ibanAliciAdi,
  String? sablon,
  String? isletmeTelefonu,
  HatirlatmaHesapOzeti hesap = const HatirlatmaHesapOzeti(),
  DateTime? tarih,
}) {
  final ad = musteriAd.trim();
  final blok = ibanOdemeBlogu(iban: iban, aliciAdi: ibanAliciAdi, isletmeAdi: isletmeAdi);
  final degerler = <String, String>{
    '*musteriadi*': ad,
    '*isletmeadi*': (isletmeAdi ?? '').trim(),
    '*siparistutar*': sipTutar(borcKurus),
    '*ibanodemebilgileri*': blok,
    '*tarih*': hatirlatmaTarihi(tarih ?? DateTime.now()),
    '*odenmemissiparis*': hesap._odenmemisMetni,
    '*sonsiparistarihi*': hesap._sonSiparisMetni,
    '*sonodeme*': hesap._sonOdemeMetni,
    '*isletmetelefonu*': isletmeTelefonu == null || isletmeTelefonu.trim().isEmpty
        ? ''
        : sipTelefon(isletmeTelefonu.trim()),
  };

  final ozel = (sablon ?? '').trim();
  if (ozel.isEmpty || ozel == _eskiVarsayilanSablon) {
    return _varsayilanMesaj(ad: ad, blok: blok, degerler: degerler);
  }

  final cozulmus = hatirlatmaSablonuUygula(ozel, degerler: degerler);

  // BOŞ MESAJ ÜRETİLMEZ (inceleme bulgusu 2026-08-06). Şablonun tamamı boşa çözülebilir —
  // ör. metin yalnız `*ibanodemebilgileri*` iken IBAN tanımlı değilse. O hâlde WhatsApp BOŞ
  // bir metin kutusuyla açılır ve bayi ekranda ne olduğunu anlamaz. Varsayılana düşmek yarım
  // bir mesaj değil, TAM bir mesaj verir; dosyanın açılış ilkesi bunu zaten söylüyor:
  // "yarım bir mesaj, hata fırlatıp bayiyi elleri boş bırakmaktan iyidir".
  if (cozulmus.trim().isEmpty) {
    return _varsayilanMesaj(ad: ad, blok: blok, degerler: degerler);
  }
  return cozulmus;
}

/// Şablondan BAĞIMSIZ, SABİT ödeme bloğu: "Ödeme için IBAN:" + okunur IBAN + "Alıcı: …".
///
/// Bayi bu iki bilgiyi metnin İÇİNDE düzenleyemez, yalnız [varsayilanHatirlatmaSablonu]'ndaki
/// yer tutucuyu istediği yere koyar. Gerekçe: IBAN ve alıcı adı, elle yazıldığında tek hane
/// hatasıyla parayı BAŞKASINA gönderten alanlardır — mod-97 denetiminden geçmiş değerin metne
/// olduğu gibi taşınması gerekir.
///
/// IBAN tanımlı değilse blok BOŞ dizedir; çağıran satırı hiç yazmaz.
///
/// BLOK ÇOK SATIRLIDIR ve bu, satır İÇİNDE kullanıldığında görünür (inceleme notu 2026-08-06):
/// `Ödeme: *ibanodemebilgileri* — teşekkürler` yazan bir bayide "— teşekkürler" bloğun ALTINA,
/// "Alıcı: …" satırının devamına düşer. Kırpmıyoruz ve tek satıra da sıkıştırmıyoruz: IBAN'ın
/// dörderli gruplar hâlinde KENDİ SATIRINDA durması, müşterinin bankada gördüğü biçimle
/// karşılaştırıp doğru okumasının tek güvencesidir. Yer tutucunun kendi satırında durması
/// gerektiğini ekran, alanın altındaki açıklama satırıyla söyler.
///
/// ALICI ADI ŞART (kullanıcı isteği 2026-08-06): banka uygulamaları IBAN'ın yanında ad soyad
/// ister ve hesap sahibi çoğu zaman ŞAHIS adıdır — "Merkez Su Bayii" ile "Mehmet Yılmaz" aynı
/// şey değildir, müşteri işletme adını yazınca havale ekranı onu geçirmez. [aliciAdi] boşsa
/// [isletmeAdi]'na düşülür: güncellemeden önceki davranış budur ve hiçbir bayi "Alıcı" satırını
/// bu güncellemeyle kaybetmemeli.
String ibanOdemeBlogu({String? iban, String? aliciAdi, String? isletmeAdi}) {
  final hesap = ibanOkunur(iban);
  if (hesap.isEmpty) return '';

  final ozelAlici = (aliciAdi ?? '').trim();
  final alici = ozelAlici.isNotEmpty ? ozelAlici : (isletmeAdi ?? '').trim();

  return [
    'Ödeme için IBAN:',
    hesap,
    // Ad hiç yoksa satır yazılmaz — uydurma ad, eksik addan kötüdür.
    if (alici.isNotEmpty) 'Alıcı: $alici',
  ].join('\n');
}

/// Şablonu değerlerle çözer. SAF: takvim, ağ, widget yok.
///
/// ÜÇ KURAL, üçü de testle kilitli:
///
///  1. **Bilinmeyen `*...*` dizileri OLDUĞU GİBİ kalır.** WhatsApp'ta yıldız KALIN YAZI demektir;
///     tanımadığımız her yıldızlı diziyi silmek ya da boşaltmak, bayinin kendi vurgusunu
///     ("*Önemli*") yiyip mesajı bozardı. Yalnız [degerler] anahtarları değiştirilir.
///  2. **TEK GEÇİŞ: çözülen bir değer BİR DAHA taranmaz** (inceleme bulgusu 2026-08-06). Sırayla
///     `replaceAll` yapmak asimetrik bir davranış üretiyordu: müşteri adı `*isletmeadi*` ise o ad
///     ikinci turda işletme adına dönüşüyor, ters yön dönüşmüyordu — sonuç Map'in anahtar
///     SIRASINA bağlıydı. Değer bayinin kendi girdisidir (güvenlik sorunu değil), ama sıraya
///     bağlı bir metin dönüşümü açıklanamaz ve testle kilitlenemez.
///  3. **Değerlerinin TAMAMI boşa çözülen satır, satırını ve BİR komşu boş satırını götürür.**
///     Ölçüt "satır tamamen boşaldı" DEĞİL, "bu satırdaki yer tutucuların hiçbiri değer
///     getirmedi"dir: `Ödeme: *ibanodemebilgileri*` IBAN yokken geriye asılı bir `Ödeme:`
///     etiketi bırakıyordu (inceleme bulgusu 2026-08-06) — etiket yalnız o değeri tanıtmak için
///     yazılmıştır, değer yoksa etiketin de işi yoktur. Buna karşılık `*isletmeadi* olarak
///     hesabınızda *siparistutar* … görünüyor.` satırı, işletme adı boş olsa bile TUTAR
///     getirdiği için DURUR; kalan boşluklar sadeleşir. Aksi hâlde tutar sessizce kaybolurdu.
///     Yutma tek satırlıktır — bayinin kendi koyduğu boşluklara dokunulmaz.
String hatirlatmaSablonuUygula(String sablon, {required Map<String, String> degerler}) {
  if (degerler.isEmpty) return sablon.trim();

  // Alternasyon UZUNDAN KISAYA: bir anahtar başka bir anahtarın ön eki olursa (ileride
  // `*siparistutar*` yanına `*siparistutari*` eklenirse) kısa olan uzunu ısırırdı.
  final anahtarlar = degerler.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final desen = RegExp(anahtarlar.map(RegExp.escape).join('|'));

  final satirlar = <String>[];
  var bosluguYut = false;

  for (final ham in sablon.split('\n')) {
    var bos = 0;
    var dolu = 0;
    // TEK GEÇİŞ (kural 2): eşleşen her jeton bir kez değiştirilir, çıktı yeniden taranmaz.
    var satir = ham.replaceAllMapped(desen, (e) {
      final deger = degerler[e.group(0)]!;
      if (deger.isEmpty) {
        bos++;
      } else {
        dolu++;
      }
      return deger;
    });

    // Kural 3: yer tutucu vardı, hiçbiri değer getirmedi → satır düşer. (Baştan boş olan satır
    // bayinin bilinçli boşluğudur; `ham.trim()` denetimi onu korur.)
    if (bos > 0 && dolu == 0 && ham.trim().isNotEmpty) {
      // Üstte boş satır varsa o gider. Satır paragrafın içindeyse paragraf ayracına DOKUNULMAZ:
      // yutulsaydı son satırı düşen paragraf bir sonrakine yapışırdı (2026-11-05). Mesajın en
      // başında boşluk bırakmamak için yalnız ilk satırda aşağıdaki boşluk yutulur.
      if (satirlar.isNotEmpty && satirlar.last.trim().isEmpty) {
        satirlar.removeLast();
      } else if (satirlar.isEmpty) {
        bosluguYut = true;
      }
      continue;
    }

    // Satır DURUYOR ama içindeki bir yer tutucu boşaldı: geriye çift boşluk ya da baştan/sondan
    // sarkan boşluk kalır ("  olarak hesabınızda …"). Sadeleştirme yalnız BU durumda yapılır —
    // bayinin bilerek hizaladığı bir satıra dokunmak, düzeltmediğimiz bir sorunu yaratmak olurdu.
    if (bos > 0) {
      satir = satir.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
    }

    if (bosluguYut) {
      bosluguYut = false;
      if (satir.trim().isEmpty) continue;
    }
    satirlar.add(satir);
  }

  // Baştaki/sondaki boş satırlar kırpılır: WhatsApp'ta baştaki boşluk balonu kaydırır.
  return satirlar.join('\n').trim();
}

/// Bayi şablona HİÇ dokunmadıysa koşan kurulum: [varsayilanHatirlatmaSablonu] çözülür. Tek kaynak
/// budur, boş kalan değerlerin satırları [hatirlatmaSablonuUygula]nın kuralıyla düşer. Yalnız iki
/// hâl metni değiştirir: adı olmayan müşteride "Sayın ," yazmamak ve IBAN yokken ödeme cümlesi.
String _varsayilanMesaj({
  required String ad,
  required String blok,
  required Map<String, String> degerler,
}) {
  var sablon = varsayilanHatirlatmaSablonu;
  if (ad.isEmpty) sablon = sablon.replaceFirst('Sayın *musteriadi*,', 'Merhaba,');
  if (blok.isEmpty) sablon = sablon.replaceFirst('$_odemeGirisSatiri\n\n', '');
  return hatirlatmaSablonuUygula(sablon, degerler: degerler);
}
