// ARA TAHSİLAT TESTLERİNİN ORTAK DÜZENEĞİ.
//
// NEDEN AYRI DOSYA: `ara_tahsilat_test.dart` 1126 satıra çıkmıştı (500 satır kuralı) ve üçe
// bölündü — kapsam kuralları · devir penceresi · yazma kuralları. Üç dosya da aynı fikstürü
// kullanıyor; kopyalansaydı üç ayrı "kurye ekle" tanımı doğar ve bir gün ayrışırlardı.
//
// ⚠️ ZAMAN DAMGALARI 5 DAKİKALIK ARALIKLA KURULUR ve bu kasıtlıdır: `araTahsilat()` kaydı gerçek
// ŞİMDİ ile yazar, ledger kayıtları ona göre konumlanmalıdır. Aynı milisaniyeye düşen iki kayıtta
// `period_start` süzgeci (`isBefore`) yazı-tura döner ve SAHTE KIRIK üretir. Gün sınırını aşacak
// damgalar gün içine kırpılır — TR takvim günü dışına taşan bir kayıt kapsamdan düşerdi.

import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/ledger_ops.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart';

/// `Value` yeniden dışa aktarılır: bölünen dosyalar fikstürü kurarken kullanıyor.
export 'package:drift/drift.dart' show Value;

/// TR takvim gününün UTC gün başı.
DateTime gunBasiUtc(DateTime trGun) =>
    DateTime.utc(trGun.year, trGun.month, trGun.day).subtract(const Duration(hours: 3));

/// Bugünün TR gününde KALMASI garanti "önce" damgası (bkz. dosya başlığı).
String oncekiIso() {
  final simdi = DateTime.now().toUtc();
  final erken = simdi.subtract(const Duration(minutes: 5));
  final sinir = gunBasiUtc(bugunTr());
  return (erken.isBefore(sinir) ? sinir : erken).toIso8601String();
}

/// Bugünün TR gününde KALMASI garanti "sonra" damgası.
String sonrakiIso() {
  final simdi = DateTime.now().toUtc();
  final gec = simdi.add(const Duration(minutes: 5));
  final sinir = gunBasiUtc(bugunTr()).add(const Duration(hours: 24, seconds: -1));
  return (gec.isAfter(sinir) ? sinir : gec).toIso8601String();
}

/// Test kuryesi ekler.
Future<void> kurye(AppDatabase db, String id, String ad, {String durum = 'active'}) =>
    db.into(db.users).insert(
        UsersCompanion.insert(id: id, name: ad, role: 'kurye', status: durum));

/// Nakit tahsilat yazar.
///
/// Tutar NEGATİF yazılır (defter sözleşmesi): kasaya giren = −amount.
Future<void> nakit(AppDatabase db, int kurus,
        {required String kuryeId, required String at}) =>
    writeLedgerEntry(db,
        entryType: 'payment',
        amountKurus: -kurus,
        paymentType: 'nakit',
        collectedByUserId: kuryeId,
        occurredAt: at);

