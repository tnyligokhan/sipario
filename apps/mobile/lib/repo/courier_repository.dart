import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

/// Kurye/kullanıcı profili (tasarım: "Kuryeler" ekranı — ad, telefon, aktif/pasif).
///
/// SINIR (bilinçli): buradan kullanıcı OLUŞTURULAMAZ ve rol/e-posta/parola DEĞİŞTİRİLEMEZ. Yeni
/// kullanıcı kimlik bilgisi (e-posta+parola) üretmeyi gerektirir; kimlik yüzeyini senkron yolundan
/// açmak yetki yükseltme vektörü olurdu. Kullanıcı açma panel/owner tarafındadır — AÇIK madde.
///
/// Yerel `users` tablosu sunucu `team` bloğunun TOPTAN tazelenen önbelleğidir. Burada iyimser
/// (optimistic) yazarız ki ekran anında güncellensin; bir sonraki senkronda sunucunun listesi
/// zaten üzerine yazar (tek doğru kaynak sunucu).
class CourierRepository {
  CourierRepository(this.db);
  final AppDatabase db;

  /// Tüm ekip (pasifler dahil — tasarım pasif kuryeyi soluk gösterir).
  Stream<List<User>> watchAll() =>
      (db.select(db.users)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  /// Yalnız aktif kuryeler (atama hedefi + gün sonu sekmeleri).
  Stream<List<User>> watchAktifKuryeler() => (db.select(db.users)
        ..where((t) => t.role.equals('kurye') & t.status.equals('active'))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  /// Profili güncelle. [isActive] pasifleştirmeyi kapsar (silme YOK — geçmiş atamalarda adı gerekir).
  Future<void> updateProfile(
    String userId, {
    required String name,
    String? phone,
    bool isActive = true,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final status = isActive ? 'active' : 'disabled';

    await db.transaction(() async {
      await (db.update(db.users)..where((t) => t.id.equals(userId))).write(UsersCompanion(
        name: Value(name),
        phone: Value(phone),
        status: Value(status),
      ));
      await enqueueOutbox(db,
          entityType: 'user_profile',
          op: 'upsert',
          entityId: userId,
          occurredAt: at,
          deviceId: device,
          payload: {'id': userId, 'name': name, 'phone': phone, 'status': status});
    });
  }
}
