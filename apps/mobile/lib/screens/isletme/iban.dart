// IBAN — biçim, okunur gösterim ve GEÇERLİLİK denetimi. Saf; widget kurmadan test edilir.
//
// NEDEN AYRI DOSYA: iki ekran kullanır — İşletme Profili (girer/doğrular) ve Borçlular (mesaja
// yazar). Birinin içine gömmek, diğerine ekran importu ettirirdi.
//
// NEDEN MOD-97 DENETİMİ VAR: yanlış IBAN sessiz bir hatadır. Bayi rakamı eksik yazar, mesaj
// gider, müşteri parayı gönderemez (ya da daha kötüsü BAŞKASINA gönderir) ve kimse nedenini
// bilmez — ürün "çalışıyor" görünür. Tek hane hatasını yakalayan standart denetim ISO 13616'nın
// kendi mod-97 kuralıdır ve tamamen yereldir (ağ yok, banka sorgusu yok).
//
// SUNUCU BU DENETİMİ TEKRARLAMAZ (bilinçli): geçersiz IBAN kullanıcıya FORMDA söylenmeli, senkron
// partisinin içinde değil. Sunucudaki tek kural uzunluktur (34) — orada aşırı uzun bir değer tüm
// partiyi düşürebilecek bir 22001'e dönüşürdü.

/// Saklama biçimi: boşluksuz, BÜYÜK harf. Boş metin `null` — "IBAN tanımlı değil" gerçek bir
/// durumdur ve boş dizeyle null'ın iki ayrı şey olması hatırlatma kapısını belirsizleştirirdi.
String? ibanNormal(String? ham) {
  if (ham == null) return null;
  final s = ham.toUpperCase().replaceAll(RegExp(r'\s+'), '');
  return s.isEmpty ? null : s;
}

/// Ekranda/mesajda okunur biçim: dörderli gruplar ("TR12 3456 7890 …").
/// Bankaların yazdığı biçim budur; müşteri karşılaştırırken göz bu gruplara alışkındır.
String ibanOkunur(String? iban) {
  final s = ibanNormal(iban);
  if (s == null) return '';
  final parcalar = <String>[];
  for (var i = 0; i < s.length; i += 4) {
    parcalar.add(s.substring(i, i + 4 > s.length ? s.length : i + 4));
  }
  return parcalar.join(' ');
}

/// ISO 13616 mod-97 denetimi. Biçim bozuksa ya da sağlama tutmuyorsa `false`.
///
/// TR hesapları 26 karakterdir ama kural GENEL tutuldu (15–34): yurt dışı hesabı olan bir bayiyi
/// kendi doğru IBAN'ıyla reddetmek, koruduğundan çok engel olurdu. TR'ye özel uzunluk kuralı
/// [ibanHatasi] içinde ayrıca söylenir — orada mesaj kullanıcıya yardım eder.
bool ibanGecerliMi(String? ham) {
  final s = ibanNormal(ham);
  if (s == null) return false;
  if (!RegExp(r'^[A-Z]{2}[0-9A-Z]{13,32}$').hasMatch(s)) return false;

  // İlk dört karakter (ülke + kontrol) sona taşınır, harfler A=10…Z=35 ile sayıya çevrilir.
  final tasinmis = s.substring(4) + s.substring(0, 4);
  var kalan = 0;
  for (final kod in tasinmis.codeUnits) {
    // 0-9 → basamak; A-Z → iki basamaklı sayı.
    final deger = kod >= 65 ? kod - 55 : kod - 48;
    kalan = (kalan * (deger > 9 ? 100 : 10) + deger) % 97;
  }
  return kalan == 1;
}

/// Form hatası metni; sorun yoksa `null`. Boş girdi HATA DEĞİLDİR — IBAN zorunlu bir alan değil,
/// yalnız hatırlatma özelliğinin ön koşuludur.
String? ibanHatasi(String? ham) {
  final s = ibanNormal(ham);
  if (s == null) return null;
  if (s.startsWith('TR') && s.length != 26) {
    return 'TR IBAN 26 karakter olmalı (şu an ${s.length})';
  }
  if (!ibanGecerliMi(s)) return 'IBAN geçersiz, rakamları kontrol edin';
  return null;
}
