// GÜN VERİSİ — ürün dökümü + tarih biçimleri (Gün Özeti ekranının yardımcı veri katmanı).
//
// ⚠️ DOSYA ADI TARİHSELDİR: bir zamanlar ayrı bir "Geçmiş" ekranı vardı ve bu onun veri
// katmanıydı. O ekran 2026-08-25'te SİLİNDİ — geçmiş artık Gün Özeti'nin kendi gün şeridiyle
// geziliyor ve `satilanUrunler` BUGÜN için de çiziliyor. Ad değişmedi çünkü değiştirmek, iki
// çağıran dosyanın import satırını yalnız kozmetik bir sebeple oynatmak olurdu.
//
// GEÇMİŞE ERİŞİM GÜN GEZİNMESİYLEDİR (kullanıcı kararı 2026-08-06): eskiden burada
// "hareket olan günler" listesi (`gecmisGunler`), bir gün satırına dokununca açılan detay ekranı
// ve onun veri fonksiyonu (`gunDetayi` + `GunDetayi` + `KuryeGunu`) vardı. Liste + detay iki
// katmanı, ‹ › oklarıyla tek katmana indi — bayi listede tarih aramıyor, "dün ne oldu" diye
// soruyor. O yüzden hepsi silindi: günün KAPSAMLI özeti artık `gun_sonu_ozet.dart`taki
// `gunSonuGorunumu(db, gun, kuryeId:)`ndan geliyor ve kurye kırılımını kapsam segmenti veriyor.
//
// GERİYE ÜRÜN DÖKÜMÜ KALDI, çünkü onun kapsamlı bir karşılığı YOK: `satilanUrunler` gün
// genelindedir ve Geçmiş ekranı onu yalnız "Tümü" kapsamında çizer.
//
// SAF VERİ KATMANI: ekran hiçbir para formülü yazmaz. Bu dosya yalnız GRUPLAR ve SIRALAR.

import '../../data/app_database.dart';
import 'gun_sonu_ozet.dart';

/// O gün satılan bir ürün (teslim edilmiş siparişlerden).
class UrunSatisi {
  UrunSatisi({required this.ad, required this.adet, required this.tutar});
  final String ad;
  final int adet;
  final int tutar;
}

/// O gün TESLİM EDİLEN siparişlerin ürün dökümü (çok satandan aza).
///
/// Kullanıcı kararı: yalnız teslim edilenler sayılır. Açık sipariş henüz satılmış değildir ve
/// kasa özetiyle aynı kümeye bakmak zorundayız — iki rakam birbirini tutmazsa bayi hangisine
/// güveneceğini bilemez.
///
/// GRUPLAMA ADA GÖREDİR, ürün kimliğine değil: serbest satırların (katalog dışı tek seferlik iş)
/// productId'si yoktur ve silinmiş bir ürünün satırı da kimliksiz kalır; ada göre gruplamak
/// ikisini de dökümde tutar. Aynı adı taşıyan iki farklı ürün varsa birleşirler — bu, satılan
/// bir kalemi dökümden düşürmekten iyidir.
Future<List<UrunSatisi>> satilanUrunler(AppDatabase db, DateTime gun) async {
  final sorgu = db.select(db.orders)
    ..where((t) => t.deletedAt.isNull())
    ..where((t) => t.status.equals('delivered'));
  final siparisler = await sorgu.get();
  final gunlukIdler = {
    for (final o in siparisler)
      if (ayniTrGun(o.occurredAt, gun)) o.id,
  };
  if (gunlukIdler.isEmpty) return const [];

  final satirlar = await (db.select(db.orderLines)
        ..where((t) => t.deletedAt.isNull()))
      .get();

  final adet = <String, int>{};
  final tutar = <String, int>{};
  for (final l in satirlar) {
    if (!gunlukIdler.contains(l.orderId)) continue;
    adet[l.productName] = (adet[l.productName] ?? 0) + l.qty;
    tutar[l.productName] = (tutar[l.productName] ?? 0) + l.lineTotalKurus;
  }

  final liste = [
    for (final ad in adet.keys)
      UrunSatisi(ad: ad, adet: adet[ad]!, tutar: tutar[ad] ?? 0),
  ]..sort((a, b) {
      final c = b.adet.compareTo(a.adet);
      return c != 0 ? c : a.ad.compareTo(b.ad); // eşitlikte ada göre — sıra titremesin
    });
  return liste;
}


/// "28 Temmuz 2026, Pazartesi" — Geçmiş ekranının başlık altı.
String gunTamBasligi(DateTime g) => '${g.day} ${_aylar[g.month - 1]} ${g.year}, ${_gunAdi(g)}';

const _aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

const _gunler = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

String _gunAdi(DateTime g) => _gunler[g.weekday - 1];
