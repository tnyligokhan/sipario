// GENEL YETKİ MATRİSİNİN VERİSİ — `yetki_matrisi_test.dart` bunu gezerek sınar.
//
// NEDEN AYRI DOSYA: tablo 26 satır × 5 sütun + 26 okuyucu + 13 anahtar eşlemesi taşıyor ve
// testlerle aynı dosyada 500 satır sınırını aşıyordu. Ayrılınca testin kendisi "hangi soruları
// soruyorum" olarak, bu dosya da "matris nedir" olarak okunur hâle gelir.

import 'package:sipario/screens/team.dart';

/// Matrisin bir satırı: bir yetkinin beş senaryodaki beklenen değeri.
class YetkiSatiri {
  const YetkiSatiri(
    this.ad, {
    required this.patron,
    required this.operatorRol,
    required this.kuryeVarsayilan,
    required this.kuryeKapali,
    required this.kuryeAcik,
  });

  final String ad;
  final bool patron;
  final bool operatorRol;

  /// Kurye · `izin` verilmemiş (senkron öncesi veya ayar satırı yok).
  final bool kuryeVarsayilan;

  /// Kurye · 13 anahtarın hepsi kapalı.
  final bool kuryeKapali;

  /// Kurye · 13 anahtarın hepsi açık (bayinin verebileceği EN GENİŞ küme).
  final bool kuryeAcik;
}

/// Yalnız-yönetici yetkiler: hiçbir anahtar ve hiçbir kişisel ezme bunları kuryeye açamaz.
const yalnizYonetici = <String>[
  'siparisIptal',
  'rotaCalistir',
  'atama',
  'musteriBorcSilme',
  'toplamBorclulariGorme',
  'gunuKapatma',
  'gecmisHesapArsivi',
  'defterDuzeltme',
  'musteriYonetimi',
  'urunYonetimi',
  'muafTelefonYonetimi',
];

/// `t`/`f` kısaltmaları bilinçli: sütunlar hizalı kalınca yanlış bir hücre gözle de görülür.
const _t = true;
const _f = false;

/// 26 satırlık TAM tablo.
const yetkiMatrisi = <YetkiSatiri>[
  // 1. Sipariş & Teslimat
  YetkiSatiri('tumSiparisleriGorme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('siparisAcma',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('siparisIptal',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  YetkiSatiri('gecmisTeslimatlariGorme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('rotaCalistir',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  YetkiSatiri('atama',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),

  // 2. Kasa & Tahsilat
  YetkiSatiri('tahsilat',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('iskonto',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('musteriBorcSilme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  YetkiSatiri('sahaGideri',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('toplamBorclulariGorme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),

  // 3. Gün Sonu & Kasa Devri
  YetkiSatiri('gunSonu',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('gunuKapatma',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  YetkiSatiri('gecmisHesapArsivi',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  YetkiSatiri('defterDuzeltme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),

  // 4. Müşteri & KVKK
  YetkiSatiri('musteriDuzenleme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('musteriYonetimi',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  // TERS KUTUP: yetki değil KISIT — yöneticide hep kapalı, kuryede varsayılan AÇIK.
  YetkiSatiri('telefonMaskeleme',
      patron: _f, operatorRol: _f, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('musteriGecmisDefteri',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('borcHatirlatma',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),

  // 5. Ürün & Stok
  YetkiSatiri('urunYonetimi',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  YetkiSatiri('stokPasifleme',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _f, kuryeAcik: _t),

  // 6. Çağrı & Ayarlar
  YetkiSatiri('cagriGunlugu',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _t),
  YetkiSatiri('muafTelefonYonetimi',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  // Matristeki TEK patron/operatör ayrımı.
  YetkiSatiri('isletmeAbonelikAyarlari',
      patron: _t, operatorRol: _f, kuryeVarsayilan: _f, kuryeKapali: _f, kuryeAcik: _f),
  // Herkese açık — cihazın kendi ayarı, bayiyi ilgilendirmez.
  YetkiSatiri('cihazAyarlari',
      patron: _t, operatorRol: _t, kuryeVarsayilan: _t, kuryeKapali: _t, kuryeAcik: _t),
];

/// Ada göre alan okuyucuları — tabloyu veriyle gezebilmenin tek yolu (Dart'ta yansıma yok).
final Map<String, bool Function(RolYetkileri)> yetkiOkuyuculari = {
  'tumSiparisleriGorme': (y) => y.tumSiparisleriGorme,
  'siparisAcma': (y) => y.siparisAcma,
  'siparisIptal': (y) => y.siparisIptal,
  'gecmisTeslimatlariGorme': (y) => y.gecmisTeslimatlariGorme,
  'rotaCalistir': (y) => y.rotaCalistir,
  'atama': (y) => y.atama,
  'tahsilat': (y) => y.tahsilat,
  'iskonto': (y) => y.iskonto,
  'musteriBorcSilme': (y) => y.musteriBorcSilme,
  'sahaGideri': (y) => y.sahaGideri,
  'toplamBorclulariGorme': (y) => y.toplamBorclulariGorme,
  'gunSonu': (y) => y.gunSonu,
  'gunuKapatma': (y) => y.gunuKapatma,
  'gecmisHesapArsivi': (y) => y.gecmisHesapArsivi,
  'defterDuzeltme': (y) => y.defterDuzeltme,
  'musteriDuzenleme': (y) => y.musteriDuzenleme,
  'musteriYonetimi': (y) => y.musteriYonetimi,
  'telefonMaskeleme': (y) => y.telefonMaskeleme,
  'musteriGecmisDefteri': (y) => y.musteriGecmisDefteri,
  'borcHatirlatma': (y) => y.borcHatirlatma,
  'urunYonetimi': (y) => y.urunYonetimi,
  'stokPasifleme': (y) => y.stokPasifleme,
  'cagriGunlugu': (y) => y.cagriGunlugu,
  'muafTelefonYonetimi': (y) => y.muafTelefonYonetimi,
  'isletmeAbonelikAyarlari': (y) => y.isletmeAbonelikAyarlari,
  'cihazAyarlari': (y) => y.cihazAyarlari,
};

/// Bayi anahtarı → açtığı yetki. Ekrandaki 13 kutucuğun ürün karşılığı.
const anahtarEslemesi = <String, String>{
  'musteri': 'musteriDuzenleme',
  'siparis': 'siparisAcma',
  'tahsilat': 'tahsilat',
  'iskonto': 'iskonto',
  'gunSonu': 'gunSonu',
  'tumSiparisler': 'tumSiparisleriGorme',
  'gecmisTeslimatlar': 'gecmisTeslimatlariGorme',
  'sahaGideri': 'sahaGideri',
  'telefonMaskeleme': 'telefonMaskeleme',
  'musteriGecmisDefteri': 'musteriGecmisDefteri',
  'borcHatirlatma': 'borcHatirlatma',
  'stokPasifleme': 'stokPasifleme',
  'cagriGunlugu': 'cagriGunlugu',
};

/// Bir yetki kümesini ada göre `Map`e çevirir — iki kümeyi TAMAMIYLA karşılaştırabilmek için.
Map<String, bool> yetkiKumesi(RolYetkileri y) =>
    {for (final e in yetkiOkuyuculari.entries) e.key: e.value(y)};

const hepsiKapali = KuryeIzinleri(
  musteri: false,
  siparis: false,
  tahsilat: false,
  iskonto: false,
  gunSonu: false,
  tumSiparisler: false,
  gecmisTeslimatlar: false,
  sahaGideri: false,
  telefonMaskeleme: false,
  musteriGecmisDefteri: false,
  borcHatirlatma: false,
  stokPasifleme: false,
  cagriGunlugu: false,
);

const hepsiAcik = KuryeIzinleri(
  musteri: true,
  siparis: true,
  tahsilat: true,
  iskonto: true,
  gunSonu: true,
  tumSiparisler: true,
  gecmisTeslimatlar: true,
  sahaGideri: true,
  telefonMaskeleme: true,
  musteriGecmisDefteri: true,
  borcHatirlatma: true,
  stokPasifleme: true,
  cagriGunlugu: true,
);

/// Hepsi kapalı + [anahtar] açık.
KuryeIzinleri tekAnahtar(String anahtar) => _kur((a) => a == anahtar);

/// Hepsi açık + [anahtar] kapalı.
KuryeIzinleri tekAnahtarHaric(String anahtar) => _kur((a) => a != anahtar);

/// 13 anahtarı adına bakan bir yüklemle kurar — 13 ayrı `copyWith` yazmadan tek yerde.
KuryeIzinleri _kur(bool Function(String anahtar) deger) => KuryeIzinleri(
      musteri: deger('musteri'),
      siparis: deger('siparis'),
      tahsilat: deger('tahsilat'),
      iskonto: deger('iskonto'),
      gunSonu: deger('gunSonu'),
      tumSiparisler: deger('tumSiparisler'),
      gecmisTeslimatlar: deger('gecmisTeslimatlar'),
      sahaGideri: deger('sahaGideri'),
      telefonMaskeleme: deger('telefonMaskeleme'),
      musteriGecmisDefteri: deger('musteriGecmisDefteri'),
      borcHatirlatma: deger('borcHatirlatma'),
      stokPasifleme: deger('stokPasifleme'),
      cagriGunlugu: deger('cagriGunlugu'),
    );
