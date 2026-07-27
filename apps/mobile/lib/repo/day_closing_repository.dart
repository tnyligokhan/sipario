import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import 'cash_handover_repository.dart';
import 'day_end_repository.dart';

/// Kapanış kapsamı: günün tamamı ya da tek kurye (tasarım: "Tümü" sekmesi vs kurye sekmesi).
enum ClosingScope { day, courier }

/// Gün sonu KAPANIŞI (tasarım: "Hesabı Kapat · Kasa Devri" + "Arşiv") — APPEND-ONLY.
///
/// Faz 3'te gün sonu salt-okunur bir read-model'di; tasarım kalıcı bir kapanış istiyor: kapatılan
/// hesap kilitlenir ve arşivde kuruşu kuruşuna geri okunur. Kapanış özeti KAPATILDIĞI ANDAKİ
/// gerçeği dondurur — sonradan gelen geç senkron kaydı arşivi değiştirmez.
///
/// PARALEL HESAP YASAĞI (DECISIONS Dilim 4): kasa/teslimat rakamları ekranın gösterdiği ile AYNI
/// koddan gelir (`DayEndRepository`); beklenen nakit ve devir kaydı `CashHandoverRepository`'den.
/// Bu sınıf kendi başına hiçbir para formülü yazmaz, yalnız birleştirir ve dondurur.
class DayClosingRepository {
  DayClosingRepository(this.db)
      : _dayEnd = DayEndRepository(db),
        _handovers = CashHandoverRepository(db);

  final AppDatabase db;
  final DayEndRepository _dayEnd;
  final CashHandoverRepository _handovers;

  static const _trOffset = Duration(hours: 3);

  /// Arşiv listesi (yeni üstte).
  Stream<List<DayClosing>> watchArchive({int limit = 50}) => (db.select(db.dayClosings)
        ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
        ..limit(limit))
      .watch();

  /// Bu kapsam bugün kapatıldı mı? (Kapatılmışsa ekran kilitlenir — tasarım.)
  Future<bool> kapaliMi(ClosingScope scope, {String? userId, DateTime? localDate}) async {
    final date = localDate ?? _trToday();
    final rows = await (db.select(db.dayClosings)..where((t) => t.scope.equals(scope.name))).get();
    return rows.any((r) =>
        r.userId == (scope == ClosingScope.courier ? userId : null) && _sameTrDay(r.occurredAt, date));
  }

  /// Kapanış ÖNİZLEMESİ — ekranın gösterdiği rakamlar. `kapat()` submit anında bunu YENİDEN çağırır,
  /// böylece gösterilen ile yazılan aynı koddan çıkar (devir önizlemesiyle aynı desen).
  Future<ClosingOnizleme> onizle(ClosingScope scope, {String? userId, DateTime? localDate}) async {
    final date = localDate ?? _trToday();
    final courierId = scope == ClosingScope.courier ? userId : null;

    final kasa = await _dayEnd.kasaOzeti(date, userId: courierId);
    final teslimat = await _dayEnd.teslimatSayisi(date, userId: courierId);
    final borc = await _dayEnd.borcDurumu();

    // Beklenen nakit: kurye kapanışında devir mutabakatının AYNI hesabı (period_start'tan beri
    // o kuryenin topladığı nakit); gün kapanışında günün nakit kasası.
    final expected = courierId != null
        ? (await _handovers.onizle(courierId)).expectedKurus
        : kasa.nakit;

    return ClosingOnizleme(
      kasa: kasa,
      deliveryCount: teslimat,
      openCreditKurus: borc.toplamAcikBorc,
      expectedCashKurus: expected,
      periodStartIso: courierId != null ? (await _handovers.onizle(courierId)).periodStartIso : null,
    );
  }

  /// Hesabı kapat ve arşivle. [countedCashKurus] null ise nakit sayılmamıştır (fark 0 yazılır).
  ///
  /// [alsoHandover] true ve kurye kapsamı ise AYNI transaction'da bir kasa devri de yazılır ve
  /// kapanışa bağlanır: tasarımda "Hesabı Kapat" ile "Kasa Devri" tek ekrandır. Para mutabakatının
  /// defteri cash_handovers olarak KALIR; day_closings o anın ekran özetidir.
  Future<String> kapat({
    required ClosingScope scope,
    String? userId,
    int? countedCashKurus,
    String? note,
    String? toUserId,
    bool alsoHandover = false,
    DateTime? localDate,
  }) async {
    if (scope == ClosingScope.courier && userId == null) {
      throw ArgumentError('Kurye kapanışında userId zorunlu');
    }
    if (scope == ClosingScope.day && userId != null) {
      throw ArgumentError('Gün kapanışında userId olamaz');
    }

    final on = await onizle(scope, userId: userId, localDate: localDate);
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final id = newId();
    final diff = countedCashKurus == null ? 0 : countedCashKurus - on.expectedCashKurus;

    String? handoverId;
    if (alsoHandover && scope == ClosingScope.courier && countedCashKurus != null) {
      handoverId = await _handovers.devret(
        fromUserId: userId!,
        toUserId: toUserId,
        countedCashKurus: countedCashKurus,
        note: note,
      );
    }

    final payload = <String, Object?>{
      'id': id,
      'scope': scope.name,
      'user_id': userId,
      'period_start': on.periodStartIso,
      'delivery_count': on.deliveryCount,
      'total_collected_kurus': on.kasa.toplam,
      'cash_nakit_kurus': on.kasa.nakit,
      'cash_kart_kurus': on.kasa.kart,
      'cash_havale_kurus': on.kasa.havale,
      'open_credit_kurus': on.openCreditKurus,
      'expected_cash_kurus': on.expectedCashKurus,
      'counted_cash_kurus': countedCashKurus,
      'diff_kurus': diff,
      'cash_handover_id': handoverId,
      'note': note,
    };

    await db.transaction(() async {
      await db.into(db.dayClosings).insert(DayClosingsCompanion.insert(
            id: id,
            scope: scope.name,
            userId: Value(userId),
            periodStart: Value(on.periodStartIso),
            deliveryCount: Value(on.deliveryCount),
            totalCollectedKurus: Value(on.kasa.toplam),
            cashNakitKurus: Value(on.kasa.nakit),
            cashKartKurus: Value(on.kasa.kart),
            cashHavaleKurus: Value(on.kasa.havale),
            openCreditKurus: Value(on.openCreditKurus),
            expectedCashKurus: Value(on.expectedCashKurus),
            countedCashKurus: Value(countedCashKurus),
            diffKurus: Value(diff),
            cashHandoverId: Value(handoverId),
            note: Value(note),
            occurredAt: at,
            deviceId: Value(device),
          ));
      await enqueueOutbox(db,
          entityType: 'day_closing',
          op: 'closing',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: payload);
    });

    return id;
  }

  static DateTime _trToday() {
    final tr = DateTime.now().toUtc().add(_trOffset);
    return DateTime(tr.year, tr.month, tr.day);
  }

  static bool _sameTrDay(String iso, DateTime localDate) {
    final t = DateTime.tryParse(iso);
    if (t == null) return false;
    final tr = t.toUtc().add(_trOffset);
    return tr.year == localDate.year && tr.month == localDate.month && tr.day == localDate.day;
  }
}

/// Kapanış önizlemesi (salt-okunur): ekranın gösterdiği ve kayda donacak rakamlar.
class ClosingOnizleme {
  ClosingOnizleme({
    required this.kasa,
    required this.deliveryCount,
    required this.openCreditKurus,
    required this.expectedCashKurus,
    this.periodStartIso,
  });
  final KasaOzeti kasa;
  final int deliveryCount;
  final int openCreditKurus;
  final int expectedCashKurus;
  final String? periodStartIso;
}
