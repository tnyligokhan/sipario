// GÜN SONU ekranının VERİ katmanı — ekrandan bağımsız, saf async testle sınanır.
//
// Ekran hiçbir para formülü yazmaz: kasa/borç `DayEndRepository`den, kapanış ve arşiv
// `DayClosingRepository`den gelir. Buradaki işlev yalnız read-model'leri tek çağrıda toplamak,
// böylece ekranın gösterdiği rakam ile arşive donan rakam AYNI koddan çıkmak zorunda kalsın
// (paralel hesap yasağı — DECISIONS Dilim 4).

import '../../data/app_database.dart';
import '../../repo/day_closing_repository.dart';
import '../../repo/day_end_repository.dart';

/// Bugünün TR takvim günü (00:00). Cihaz saat diliminden bağımsız — DayEndRepository +03:00
/// offset'iyle tutarlı (occurred_at +3s kaydırılıp gün karşılaştırılır).
DateTime bugunTr({DateTime? now}) {
  final tr = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
  return DateTime(tr.year, tr.month, tr.day);
}

/// Gün geneli özet: kasa + açık borç.
class GunSonuOzet {
  GunSonuOzet({required this.kasa, required this.borc});
  final KasaOzeti kasa;
  final BorcDurumu borc;
}

Future<GunSonuOzet> gunSonuOzeti(AppDatabase db, DateTime localDate) async {
  final repo = DayEndRepository(db);
  final kasa = await repo.kasaOzeti(localDate);
  final borc = await repo.borcDurumu();
  return GunSonuOzet(kasa: kasa, borc: borc);
}

/// Seçili kapsamın (gün ya da tek kurye) kasa özeti + teslimat sayısı + açık sipariş sayısı.
class KapsamOzeti {
  KapsamOzeti({
    required this.kasa,
    required this.teslimat,
    required this.acikSiparis,
    this.iskonto = 0,
  });

  final KasaOzeti kasa;
  final int teslimat;
  final int acikSiparis;

  /// Kapıda kırılan toplam (pozitif kuruş). [kasa]nın İÇİNDE DEĞİLDİR — kasaya hiç girmedi.
  final int iskonto;
}

/// KAPSAM özeti. [kuryeId] null ise gün geneli.
///
/// Kurye kırılımı dahil TÜM para/teslimat rakamları `DayEndRepository`ye delege edilir; bu
/// dosyada ikinci bir toplama yapılmaz. Yalnız "açık sipariş" sayısı burada sorgulanır — o bir
/// kapatma kapısıdır, para değil.
Future<KapsamOzeti> kapsamOzeti(
  AppDatabase db,
  DateTime localDate, {
  String? kuryeId,
}) async {
  final repo = DayEndRepository(db);
  return KapsamOzeti(
    kasa: await repo.kasaOzeti(localDate, userId: kuryeId),
    teslimat: await repo.teslimatSayisi(localDate, userId: kuryeId),
    iskonto: await repo.iskontoOzeti(localDate, userId: kuryeId),
    acikSiparis: await acikSiparisSayisi(db, localDate, kuryeId: kuryeId),
  );
}

/// O günün AÇIK sipariş sayısı (kapsamla sınırlı). Kapatma bu sayı > 0 iken ENGELLENİR:
/// kapanmış bir gün açık bir siparişi gizlerdi.
Future<int> acikSiparisSayisi(
  AppDatabase db,
  DateTime localDate, {
  String? kuryeId,
}) async {
  // İki ayrı `where` çağrısı drift'te AND ile birleşir — ekran dosyasına `package:drift`
  // operatör eklentisini import etmemek için bilinçli tercih.
  final sorgu = db.select(db.orders)
    ..where((t) => t.deletedAt.isNull())
    ..where((t) => t.status.equals('open'));
  if (kuryeId != null) {
    sorgu.where((t) => t.assignedUserId.equals(kuryeId));
  }
  final satirlar = await sorgu.get();
  return satirlar.where((o) => ayniTrGun(o.occurredAt, localDate)).length;
}

/// occurred_at (UTC ISO) verilen TR yerel takvim gününe mi düşüyor?
bool ayniTrGun(String iso, DateTime localDate) {
  final t = DateTime.tryParse(iso);
  if (t == null) return false;
  final tr = t.toUtc().add(const Duration(hours: 3));
  return tr.year == localDate.year && tr.month == localDate.month && tr.day == localDate.day;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Ekranın tek atışta ihtiyaç duyduğu her şey
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Özet + kapsam + kilit durumu + arşiv. Tek future ile yüklenir; kapatma sonrası tazelenir.
class GunSonuGorunumu {
  GunSonuGorunumu({
    required this.ozet,
    required this.kapsam,
    required this.gunKapali,
    required this.kapsamKapali,
    required this.arsiv,
    this.acikKuryeAdlari = const [],
    this.gunEngeli = false,
  });

  final GunSonuOzet ozet;
  final KapsamOzeti kapsam;

  /// Gün hesabı kapatıldıysa artık HİÇBİR kapsam açılmaz (tasarım: "tüm hesaplar kilitli").
  final bool gunKapali;

  final bool kapsamKapali;

  /// Arşiv (yeni üstte) — APPEND-ONLY; kayıt silinmez, düzeltme yeni kapanışla yapılır.
  final List<DayClosing> arsiv;

  /// Bugün hesabı HENÜZ KAPANMAMIŞ aktif kuryelerin adları (ada göre sıralı).
  /// Tasarımdaki `acikKuryeler` — gün engelinin metnini bu liste yazar.
  final List<String> acikKuryeAdlari;

  /// Tasarım `gunEngel` (s-gunsonu.jsx): gün hesabı, kuryelerin BİR KISMI kapanmışken
  /// kapatılamaz. Hiç kimse kapatmamışken engel YOKtur (tek kişilik bayi ya da kurye
  /// hesaplarını hiç kullanmayan bayi gün sonunu doğrudan kapatabilmeli); hepsi
  /// kapanmışsa da engel yoktur. Engel yalnız YARIM KALMIŞ devirde çıkar — kapanan gün
  /// açık bir kurye kasasını mutabakatsız bırakırdı.
  final bool gunEngeli;
}

Future<GunSonuGorunumu> gunSonuGorunumu(
  AppDatabase db,
  DateTime localDate, {
  String? kuryeId,
}) async {
  final kapanislar = DayClosingRepository(db);
  final gunKapali = await kapanislar.kapaliMi(ClosingScope.day, localDate: localDate);
  final kuryeKapali = kuryeId == null
      ? false
      : await kapanislar.kapaliMi(ClosingScope.courier,
          userId: kuryeId, localDate: localDate);

  final acikKuryeler = await acikKuryeAdlari(db, localDate);
  final aktifSayi = await _aktifKuryeSayisi(db);

  return GunSonuGorunumu(
    ozet: await gunSonuOzeti(db, localDate),
    kapsam: await kapsamOzeti(db, localDate, kuryeId: kuryeId),
    gunKapali: gunKapali,
    kapsamKapali: gunKapali || kuryeKapali,
    arsiv: await kapanislar.watchArchive().first,
    acikKuryeAdlari: acikKuryeler,
    gunEngeli: kuryeId == null &&
        !gunKapali &&
        acikKuryeler.isNotEmpty &&
        acikKuryeler.length < aktifSayi,
  );
}

/// Aktif kuryelerden bugün hesabı KAPANMAMIŞ olanların adları.
Future<List<String>> acikKuryeAdlari(AppDatabase db, DateTime localDate) async {
  final kapanislar = DayClosingRepository(db);
  final kuryeler = await _aktifKuryeler(db);
  final acik = <String>[];
  for (final k in kuryeler) {
    final kapali = await kapanislar.kapaliMi(ClosingScope.courier,
        userId: k.id, localDate: localDate);
    if (!kapali) acik.add(k.name);
  }
  return acik;
}

/// Aktif kuryeler, ada göre. Sıralama SQL'de değil Dart'ta yapılır: bu dosya `package:drift`i
/// import etmiyor (ekran katmanı sözleşmesi) ve `OrderingTerm` oradan gelir.
Future<List<User>> _aktifKuryeler(AppDatabase db) async {
  final sorgu = db.select(db.users)
    ..where((t) => t.role.equals('kurye'))
    ..where((t) => t.status.equals('active'));
  final satirlar = await sorgu.get();
  satirlar.sort((a, b) => a.name.compareTo(b.name));
  return satirlar;
}

Future<int> _aktifKuryeSayisi(AppDatabase db) async => (await _aktifKuryeler(db)).length;
