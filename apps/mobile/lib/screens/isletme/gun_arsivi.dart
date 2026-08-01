// GEÇMİŞ GÜNLER — gün listesi ve gün detayı (kullanıcı isteği 2026-07-29).
//
// ÖNCEKİ HÂLİ: "Arşiv" bölümü KAPANIŞ KAYITLARINI düz liste olarak gösteriyordu ("Gün hesabı",
// "Emre", "Hakan" alt alta, hepsi aynı görünümde). İki sorun vardı:
//  1. Satırlar tarihi değil KAPSAMI yazıyordu; bayi "28 Temmuz ne oldu" diye bakamıyordu.
//  2. Kapatılmamış bir gün arşivde HİÇ görünmüyordu — bayi kapatmayı unutursa o günün cirosu
//     uygulamada okunamaz hâle geliyordu (kullanıcı kararı: hareket olan her gün listelenmeli).
//
// YENİ EKSEN GÜNDÜR: liste bir gün = bir satır; kurye kırılımı ve ürün dökümü o günün İÇİNDE
// durur. Kapatma eylemi ekranın tepesindeki BUGÜN kartında kalır — esnafın günlük işi odur.
//
// SAF VERİ KATMANI: ekran hiçbir para formülü yazmaz. Kasa ve teslimat rakamları
// `DayEndRepository`den gelir (paralel hesap yasağı — arşive donan tutarla ekrandaki tutar aynı
// koddan çıkmak zorunda). Bu dosya yalnız GRUPLAR ve SIRALAR.

import '../../data/app_database.dart';
import '../../repo/day_closing_repository.dart';
import '../../repo/day_end_repository.dart';
import 'gun_sonu_ozet.dart';

/// Geçmiş listesinin bir satırı.
class GunSatiri {
  GunSatiri({
    required this.gun,
    required this.tahsilat,
    required this.teslimat,
    required this.kapatildi,
  });

  final DateTime gun;

  /// O gün kasaya giren toplam (nakit+kart+havale).
  final int tahsilat;

  final int teslimat;

  /// Gün hesabı kapatılmış mı? Kapatılmamış gün listede KALIR ama işaretlenir — bayi bir günü
  /// kapatmayı unuttuğunda o günün kaybolması, en çok ihtiyaç duyulan anda veriyi gizlerdi.
  final bool kapatildi;
}

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

/// HAREKET OLAN günler (bugün HARİÇ), yeni üstte.
///
/// "Hareket" iki kaynaktan gelir ve BİRLEŞTİRİLİR: teslim edilmiş sipariş (teslimat sayısı) ve
/// kasaya giren ödeme (tahsilat). Yalnız birine bakmak gün düşürürdü — bir gün teslimat yapılıp
/// parası ertesi gün tahsil edilebilir, ya da eski bir borç teslimatsız bir günde kapanabilir.
///
/// TEK GEÇİŞ: defter ve siparişler bir kez okunup Dart'ta gruplanır. Her gün için ayrı sorgu
/// atmak (gün sayısı × tablo taraması) yıllara yayılmış bir defterde ekranı dakikalara çıkarırdı.
Future<List<GunSatiri>> gecmisGunler(AppDatabase db, {DateTime? bugun}) async {
  final bugunTarih = bugun ?? bugunTr();

  final odemeler = await (db.select(db.ledgerEntries)
        ..where((t) => t.paymentType.isNotNull()))
      .get();
  // İki ayrı `where` AND ile birleşir — bu dosya `package:drift`i import etmiyor (ekran
  // katmanı sözleşmesi: `&` operatörü oradan gelir, `gun_sonu_ozet.dart`taki aynı tercih).
  final teslimSorgusu = db.select(db.orders)
    ..where((t) => t.deletedAt.isNull())
    ..where((t) => t.status.equals('delivered'));
  final teslimler = await teslimSorgusu.get();

  final tahsilat = <DateTime, int>{};
  final teslimat = <DateTime, int>{};

  for (final e in odemeler) {
    final g = trGunu(e.occurredAt);
    if (g == null || !g.isBefore(bugunTarih)) continue;
    // payment(−) kasaya girer(+); ters correction(+) kasadan çıkar(−) — `kasaOzeti` ile aynı işaret.
    tahsilat[g] = (tahsilat[g] ?? 0) + -e.amountKurus;
  }
  for (final o in teslimler) {
    final g = trGunu(o.occurredAt);
    if (g == null || !g.isBefore(bugunTarih)) continue;
    teslimat[g] = (teslimat[g] ?? 0) + 1;
  }

  final gunler = {...tahsilat.keys, ...teslimat.keys}.toList()
    ..sort((a, b) => b.compareTo(a)); // yeni üstte

  final kapanislar = DayClosingRepository(db);
  final satirlar = <GunSatiri>[];
  for (final g in gunler) {
    satirlar.add(GunSatiri(
      gun: g,
      tahsilat: tahsilat[g] ?? 0,
      teslimat: teslimat[g] ?? 0,
      kapatildi: await kapanislar.kapaliMi(ClosingScope.day, localDate: g),
    ));
  }
  return satirlar;
}

/// ISO damgasından TR yerel takvim günü (00:00). `ayniTrGun` ile AYNI kaydırmayı kullanır —
/// iki farklı gün tanımı, gün sonu rakamlarını sessizce ayrıştırırdı.
DateTime? trGunu(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return null;
  final tr = t.toUtc().add(const Duration(hours: 3));
  return DateTime(tr.year, tr.month, tr.day);
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

/// "28.07 Pazartesi" — liste satırının başlığı. Yıl YAZILMAZ: arşiv yeni günlerle başlar ve
/// yıl her satırda gürültüdür; gün detayının başlığında tam tarih durur.
String gunBasligi(DateTime g) =>
    '${_ikiHane(g.day)}.${_ikiHane(g.month)} ${_gunAdi(g)}';

/// "28 Temmuz 2026, Pazartesi" — detay başlığı.
String gunTamBasligi(DateTime g) => '${g.day} ${_aylar[g.month - 1]} ${g.year}, ${_gunAdi(g)}';

const _aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

const _gunler = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

String _gunAdi(DateTime g) => _gunler[g.weekday - 1];

String _ikiHane(int n) => n.toString().padLeft(2, '0');
