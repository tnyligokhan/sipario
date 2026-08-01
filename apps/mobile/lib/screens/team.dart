import 'package:drift/drift.dart';

import '../data/app_database.dart';

/// FAZ 4b Dilim 4 — ekip (yerel `users` aynası) sorguları + rol bazlı yetki. Ekrandan bağımsız,
/// saf test edilebilir (money.dart deseni). `users` team bloğuyla toptan tazelenen önbellektir;
/// istemciden ASLA push edilmez. Yetki mantığı TEK saf fonksiyonda (K2) → regresyon testi kolay.

/// Tüm ekip (ada göre). status disabled DAHİL — atanan kuryenin adı eski atamalarda gösterilsin.
Stream<List<User>> watchTeam(AppDatabase db) =>
    (db.select(db.users)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

/// Atama hedefi olarak sunulacaklar: yalnız AKTİF kuryeler (ada göre).
Stream<List<User>> watchAktifKuryeler(AppDatabase db) => (db.select(db.users)
      ..where((t) => t.role.equals('kurye'))
      ..where((t) => t.status.equals('active'))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
    .watch();

/// Devralan seçici için: bayinin patron/operator kullanıcıları (aktif, ada göre).
Stream<List<User>> watchYoneticiler(AppDatabase db) => (db.select(db.users)
      ..where((t) => t.status.equals('active'))
      ..where((t) => t.role.equals('patron') | t.role.equals('operator'))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
    .watch();

/// Kullanıcı adını id'den çöz (bulunamazsa null → UI 'Kurye' gibi bir yedeğe düşer). Pasif
/// kullanıcı da çözülür (adı team'de kalır).
String? kullaniciAdi(List<User> team, String? id) {
  if (id == null) return null;
  for (final u in team) {
    if (u.id == id) return u.name;
  }
  return null;
}

/// Rol bazlı görünüm yetkileri (K2 — BRIEF'ten türetilmiş v1 asgarisi).
class RolYetkileri {
  const RolYetkileri({
    required this.urunYonetimi,
    required this.gunSonu,
    required this.defterDuzeltme,
    required this.tahsilat,
    required this.atama,
    required this.musteriYonetimi,
  });

  final bool urunYonetimi; // ürün ekle/düzenle/pasifle
  final bool gunSonu; // gün sonu özeti
  final bool defterDuzeltme; // ters kayıtla düzelt
  final bool tahsilat; // tahsilat al
  final bool atama; // siparişi kuryeye ata

  /// müşteriyi sil / kara listeye al-çıkar (geri dönüşü zor, bayi kararı)
  final bool musteriYonetimi;

  /// Tam yetkili (test/varsayılan yardımcısı; rol bilinmeden ekran açıldığında permissive değil,
  /// gerçek karar yetkiler() ile verilir).
  static const tumu = RolYetkileri(
    urunYonetimi: true,
    gunSonu: true,
    defterDuzeltme: true,
    tahsilat: true,
    atama: true,
    musteriYonetimi: true,
  );
}

/// K2 matrisi (tek doğruluk kaynağı). yonetici = patron|operator. kuryeVar = yerelde aktif kurye var.
/// - ürün/gün-sonu/defter-düzeltme: yalnız yönetici (patron işi).
/// - tahsilat: HERKES (kurye sahada/ay sonu tahsilat yapar; collected_by atfı zaten ondan).
/// - atama: yönetici VE kuryeVar (tek kişilikte atama yok).
/// - müşteri yönetimi (sil / kara liste): yalnız yönetici. Kurye sahada müşterinin kaydını
///   kaldıramaz ya da ona sipariş açılmasını engelleyemez — bu bayinin ticari kararıdır ve
///   telefonu elinde tutan kişi verir. Kurye kapıya gider, müşteriyi kayıttan düşürmez.
///
/// `kasaDevri` bayrağı KALDIRILDI (2026-07-26): tasarımda ayrı bir kasa devri ekranı yok, devir
/// Gün Sonu'nun "Hesabı Kapat · Kasa Devri" sheet'inin içindedir (`s-gunsonu.jsx:110`) ve kurye
/// kapanışı zaten devri yazar (`DayClosingRepository.kapat(alsoHandover:)`).
RolYetkileri yetkiler({required String? rol, required bool kuryeVar}) {
  final yonetici = rol == 'patron' || rol == 'operator';
  return RolYetkileri(
    urunYonetimi: yonetici,
    gunSonu: yonetici,
    defterDuzeltme: yonetici,
    tahsilat: true,
    atama: yonetici && kuryeVar,
    musteriYonetimi: yonetici,
  );
}
