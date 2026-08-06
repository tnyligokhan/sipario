// GEÇMİŞ GÜN VERİSİ — ürün dökümü + tarih biçimleri (`gecmis_gun_ekrani.dart`ın veri katmanı).
//
// GEÇMİŞE ERİŞİM ARTIK GÜN GEZİNMESİYLEDİR (kullanıcı kararı 2026-08-06): eskiden burada
// "hareket olan günler" listesi (`gecmisGunler`) ve bir gün satırına dokununca açılan detay
// ekranı vardı. Liste + detay iki katmanı, ‹ › oklarıyla tek katmana indi — bayi listede tarih
// aramıyor, "dün ne oldu" diye soruyor. Liste üreten fonksiyon o yüzden silindi; günün özeti
// artık `gun_sonu_ozet.dart`taki `gunSonuGorunumu`ndan gelir ve KAPSAM da alır.
//
// SAF VERİ KATMANI: ekran hiçbir para formülü yazmaz. Kasa ve teslimat rakamları
// `DayEndRepository`den gelir (paralel hesap yasağı — arşive donan tutarla ekrandaki tutar aynı
// koddan çıkmak zorunda). Bu dosya yalnız GRUPLAR ve SIRALAR.

import '../../data/app_database.dart';
import '../../repo/day_closing_repository.dart';
import '../../repo/day_end_repository.dart';
import 'gun_sonu_ozet.dart';

/// O gün satılan bir ürün (teslim edilmiş siparişlerden).
class UrunSatisi {
  UrunSatisi({required this.ad, required this.adet, required this.tutar});
  final String ad;
  final int adet;
  final int tutar;
}

/// Gün detayındaki bir kurye kartı.
class KuryeGunu {
  KuryeGunu({
    required this.ad,
    required this.kasa,
    required this.teslimat,
    this.farkKurus,
  });

  final String ad;
  final KasaOzeti kasa;
  final int teslimat;

  /// Kasa devri farkı (sayılan − beklenen). Kapanış kaydı yoksa null — "fark 0" yazmak,
  /// hiç sayım yapılmamış bir kasayı mutabık göstermek olurdu.
  final int? farkKurus;
}

/// Bir günün tam dökümü.
class GunDetayi {
  GunDetayi({
    required this.gun,
    required this.kasa,
    required this.teslimat,
    required this.kuryeler,
    required this.urunler,
    required this.kapanislar,
    this.iskonto = 0,
  });

  final DateTime gun;
  final KasaOzeti kasa;
  final int teslimat;

  /// O gün kapıda kırılan toplam (pozitif kuruş). [kasa]nın dışındadır — geçmiş bir günün
  /// kasası ile o günün cirosu arasındaki farkı yalnız bu rakam açıklar.
  final int iskonto;
  final List<KuryeGunu> kuryeler;
  final List<UrunSatisi> urunler;
  final List<DayClosing> kapanislar;

  int get satilanAdet => urunler.fold<int>(0, (s, u) => s + u.adet);
  int get urunTutari => urunler.fold<int>(0, (s, u) => s + u.tutar);
}

/// Bir günün tam dökümü: kasa · kurye kırılımı · satılan ürünler · kapanış kayıtları.
Future<GunDetayi> gunDetayi(AppDatabase db, DateTime gun) async {
  final repo = DayEndRepository(db);
  final kuryeler = await _aktifKuryeler(db);
  final tumKapanislar = await DayClosingRepository(db).watchArchive().first;
  final gunKapanislari =
      tumKapanislar.where((k) => ayniTrGun(k.occurredAt, gun)).toList();

  final kuryeGunleri = <KuryeGunu>[];
  for (final k in kuryeler) {
    final kasa = await repo.kasaOzeti(gun, userId: k.id);
    final teslimat = await repo.teslimatSayisi(gun, userId: k.id);
    // O gün hiç işi olmayan kurye kartı ÇİZİLMEZ: izinli bir kuryenin sıfırlarla dolu kartı
    // ekranı uzatır ve "bu kurye çalıştı mı" sorusunu bulanıklaştırır.
    if (kasa.toplam == 0 && teslimat == 0) continue;
    final kapanis = gunKapanislari.where((c) => c.userId == k.id).firstOrNull;
    kuryeGunleri.add(KuryeGunu(
      ad: k.name,
      kasa: kasa,
      teslimat: teslimat,
      farkKurus: kapanis?.countedCashKurus == null ? null : kapanis?.diffKurus,
    ));
  }

  return GunDetayi(
    gun: gun,
    kasa: await repo.kasaOzeti(gun),
    teslimat: await repo.teslimatSayisi(gun),
    iskonto: await repo.iskontoOzeti(gun),
    kuryeler: kuryeGunleri,
    urunler: await satilanUrunler(db, gun),
    kapanislar: gunKapanislari,
  );
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

/// Aktif kuryeler, ada göre. (`gun_sonu_ozet.dart`taki özelin ikizi; o dosya bunu dışa açmıyor
/// ve açmak için imzasını değiştirmek başka ekranları etkilerdi.)
Future<List<User>> _aktifKuryeler(AppDatabase db) async {
  final sorgu = db.select(db.users)
    ..where((t) => t.role.equals('kurye'))
    ..where((t) => t.status.equals('active'));
  final satirlar = await sorgu.get();
  satirlar.sort((a, b) => a.name.compareTo(b.name));
  return satirlar;
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
