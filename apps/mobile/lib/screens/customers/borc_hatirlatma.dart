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
// TON: kısa, resmî ama sert değil. Esnaf-müşteri ilişkisi süreklidir; "borcunuzu ödeyin" değil
// "bakiyeniz görünüyor" denir. Tehdit, gecikme faizi, son tarih YOK — bunlar bayinin kendi
// kararıdır ve mesaj gönderilmeden önce elle eklenebilir (WhatsApp metni düzenlenebilir gelir).
//
// MESAJ GÖNDERİLMEZ, HAZIRLANIR: `whatsappUriler(..., mesaj:)` sohbeti hazır metinle açar;
// gönder tuşuna bayi basar. Bayi mesajı görmeden müşterisine para isteyen bir metin gitmemeli.

import '../../theme/components/bicim.dart' show sipTutar;
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
];

/// Şablon uzunluk sınırı — sunucudaki `reminder_template` kolonuyla AYNI (1000).
///
/// İstemcide de sınır var çünkü sunucudaki sınırın devreye girdiği yer SENKRON PARTİSİDİR:
/// orada aşan değer olayı 'rejected' yapar ve bayi neyin kaydolmadığını FORMDA değil, günler
/// sonra "mesajım eski" diye fark eder.
const int hatirlatmaSablonuAzamiUzunluk = 1000;

/// Bayiye DÜZENLEMESİ İÇİN sunulan başlangıç metni. Değerlendirildiğinde (tüm alanlar dolu)
/// [borcHatirlatmaMesaji]'nin varsayılan çıktısıyla BİREBİR aynı metni verir — testle kilitli.
///
/// Bu sabit, "şablon boş" hâlinin karşılığı DEĞİLDİR: boş şablonda aşağıdaki [_varsayilanMesaj]
/// koşar ve o, eksik ad/işletme adı hâllerini de düzgün karşılar ("Sayın , merhaba." yazmaz).
/// Bayi şablonu düzenlemeye başladığı andan itibaren metnin sorumluluğu onundur.
const String varsayilanHatirlatmaSablonu = 'Sayın *musteriadi*, merhaba.\n'
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
}) {
  final ad = musteriAd.trim();
  final isletme = (isletmeAdi ?? '').trim();
  final blok = ibanOdemeBlogu(iban: iban, aliciAdi: ibanAliciAdi, isletmeAdi: isletmeAdi);

  final ozel = (sablon ?? '').trim();
  if (ozel.isEmpty) {
    return _varsayilanMesaj(ad: ad, isletme: isletme, borcKurus: borcKurus, blok: blok);
  }

  return hatirlatmaSablonuUygula(ozel, degerler: {
    '*musteriadi*': ad,
    '*isletmeadi*': isletme,
    '*siparistutar*': sipTutar(borcKurus),
    '*ibanodemebilgileri*': blok,
  });
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
/// İKİ KURAL, ikisi de testle kilitli:
///
///  1. **Bilinmeyen `*...*` dizileri OLDUĞU GİBİ kalır.** WhatsApp'ta yıldız KALIN YAZI demektir;
///     tanımadığımız her yıldızlı diziyi silmek ya da boşaltmak, bayinin kendi vurgusunu
///     ("*Önemli*") yiyip mesajı bozardı. Yalnız [degerler] anahtarları değiştirilir.
///  2. **Boşa çözülen yer tutucu, satırını ve BİR komşu boş satırını götürür.** IBAN tanımlı
///     değilken şablonun ortasında iki boş satır kalırdı; metin "unutulmuş" görünürdü.
///     Yutma tek satırlıktır ve yalnız çözülemeyen yer tutucunun etrafında olur — bayinin
///     kendi koyduğu boşluklara dokunulmaz.
String hatirlatmaSablonuUygula(String sablon, {required Map<String, String> degerler}) {
  final satirlar = <String>[];
  var bosluguYut = false;

  for (final ham in sablon.split('\n')) {
    var satir = ham;
    var yerTutucuVardi = false;
    for (final girdi in degerler.entries) {
      if (!satir.contains(girdi.key)) continue;
      yerTutucuVardi = true;
      satir = satir.replaceAll(girdi.key, girdi.value);
    }

    // Yer tutucusu boşa çözülüp geriye HİÇBİR ŞEY kalmayan satır düşer (baştan boş olan satır
    // bayinin bilinçli boşluğudur — o durmalı).
    if (yerTutucuVardi && satir.trim().isEmpty && ham.trim().isNotEmpty) {
      if (satirlar.isNotEmpty && satirlar.last.trim().isEmpty) {
        satirlar.removeLast();
      } else {
        bosluguYut = true;
      }
      continue;
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

/// Bayi şablona HİÇ dokunmadıysa koşan kurulum. 2026-08-06 öncesi metnin BİREBİR aynısıdır;
/// tek fark alıcı adının artık ayrı bir alandan gelebilmesidir (boşsa yine işletme adı yazar).
String _varsayilanMesaj({
  required String ad,
  required String isletme,
  required int borcKurus,
  required String blok,
}) {
  final satirlar = <String>[
    ad.isEmpty ? 'Merhaba,' : 'Sayın $ad, merhaba.',
    isletme.isEmpty
        ? 'Hesabınızda ${sipTutar(borcKurus)} tutarında ödenmemiş bakiye görünüyor.'
        : '$isletme olarak hesabınızda ${sipTutar(borcKurus)} tutarında ödenmemiş bakiye görünüyor.',
  ];

  if (blok.isNotEmpty) {
    satirlar
      ..add('')
      ..add(blok);
  }

  satirlar
    ..add('')
    ..add('Teşekkür ederiz.');

  return satirlar.join('\n');
}
