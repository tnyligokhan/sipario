// BORÇ HATIRLATMA MESAJI — borçluya WhatsApp'tan gönderilecek metni kurar.
// Kullanıcı isteği (2026-08-04): "borçlular ekranında tek tuşla iban gönderebilmeliyiz ilgili
// müşterinin whatsappına … iban ile birlikte sipariş tutarını müşteri ismini parametre olarak
// alsın ve basit bir hatırlatma mesajı göndersin."
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

/// Hatırlatma metni. [borcKurus] müşterinin DEFTER bakiyesidir (ekrandaki kartın yazdığı sayı) —
/// tek bir siparişin tutarı değil: müşteri "hangi sipariş" diye değil "ne kadar" diye sorar ve
/// bayi de toplamı tahsil eder.
///
/// [iban] null/boşsa metin IBAN bloğu OLMADAN kurulur. Çağıran bu duruma normalde hiç
/// düşmemeli (düğme kapalıdır) ama fonksiyon yine de kullanılabilir bir metin döndürür:
/// yarım bir mesaj, hata fırlatıp bayiyi elleri boş bırakmaktan iyidir.
String borcHatirlatmaMesaji({
  required String musteriAd,
  required int borcKurus,
  String? iban,
  String? isletmeAdi,
}) {
  final ad = musteriAd.trim();
  final isletme = (isletmeAdi ?? '').trim();
  final hesap = ibanOkunur(iban);

  final satirlar = <String>[
    ad.isEmpty ? 'Merhaba,' : 'Sayın $ad, merhaba.',
    isletme.isEmpty
        ? 'Hesabınızda ${sipTutar(borcKurus)} tutarında ödenmemiş bakiye görünüyor.'
        : '$isletme olarak hesabınızda ${sipTutar(borcKurus)} tutarında ödenmemiş bakiye görünüyor.',
  ];

  if (hesap.isNotEmpty) {
    satirlar
      ..add('')
      ..add('Ödeme için IBAN:')
      ..add(hesap);
    // Alıcı adı ŞART: banka uygulamaları IBAN'ın yanında ad soyad ister ve müşteri onu bilmezse
    // havaleyi tamamlayamaz. İşletme adı yoksa satır hiç yazılmaz (uydurma ad yazılmaz).
    if (isletme.isNotEmpty) satirlar.add('Alıcı: $isletme');
  }

  satirlar
    ..add('')
    ..add('Teşekkür ederiz.');

  return satirlar.join('\n');
}
