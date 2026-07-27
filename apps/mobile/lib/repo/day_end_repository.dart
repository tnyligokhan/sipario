import 'package:drift/drift.dart';

import '../data/app_database.dart';

/// Gün sonu SALT-OKUNUR read-model (FAZ 3). Hiçbir tabloya YAZMAZ (kalıcı durum üretmez); tüm veriyi
/// yerel Drift'ten türetir. Kasa özeti + borç durumu. Kurye kasa DEVRİ (kalıcı mutabakat) ve atama
/// FAZ 4 sınırıdır — buraya girmez.
///
/// Gün sınırı SABİT +03:00 (Türkiye, 2016'dan beri DST yok): occurred_at (düzeltilmiş sunucu saati,
/// UTC ISO) +3s kaydırılıp yerel takvim günü çıkarılır. Sabit offset DST karmaşasını kökten kapatır.
class DayEndRepository {
  DayEndRepository(this.db);
  final AppDatabase db;

  static const _trOffset = Duration(hours: 3);

  /// occurred_at (UTC ISO) verilen TR yerel takvim gününe mi düşüyor?
  static bool _sameTrDay(String iso, DateTime localDate) {
    final t = DateTime.tryParse(iso);
    if (t == null) return false;
    final tr = t.toUtc().add(_trOffset);
    return tr.year == localDate.year && tr.month == localDate.month && tr.day == localDate.day;
  }

  /// Kasa özeti: gün içinde KASAYA DOKUNAN kayıtlar ödeme tipine göre. İnvariant (DECISIONS Faz 3):
  /// "payment_type taşıyan kayıt = kasaya dokundu" — payment (tahsilat, −) VE payment_type'lı
  /// correction (yanlış tahsilatı ters çeviren, +) birlikte toplanır; kasa katkısı = −amount_kurus.
  /// Böylece yanlış nakit tahsilat correction ile ters çevrilince kasa da düzelir (bakiye + kasa birlikte).
  ///
  /// [userId] verilirse yalnız O KULLANICININ topladıkları sayılır (tasarım: gün sonu ekranındaki
  /// kurye sekmesi). Opsiyonel — mevcut çağrılar (Tümü) aynen çalışır.
  Future<KasaOzeti> kasaOzeti(DateTime localDate, {String? userId}) async {
    final query = db.select(db.ledgerEntries)..where((t) => t.paymentType.isNotNull());
    if (userId != null) {
      query.where((t) => t.collectedByUserId.equals(userId));
    }
    final tillEntries = await query.get();

    var nakit = 0, kart = 0, havale = 0;
    for (final e in tillEntries) {
      if (!_sameTrDay(e.occurredAt, localDate)) continue;
      final giren = -e.amountKurus; // payment(−)→kasaya girer(+); ters correction(+)→kasadan çıkar(−)
      switch (e.paymentType) {
        case 'nakit':
          nakit += giren;
        case 'kart':
          kart += giren;
        case 'havale':
          havale += giren;
      }
    }
    return KasaOzeti(nakit: nakit, kart: kart, havale: havale);
  }

  /// Gün içinde teslim edilen sipariş SAYISI (tasarım: "N teslimat"). [userId] verilirse yalnız
  /// o kuryeye atanmış siparişler. İptaller sayılmaz (status='delivered').
  Future<int> teslimatSayisi(DateTime localDate, {String? userId}) async {
    final query = db.select(db.orders)
      ..where((t) => t.deletedAt.isNull() & t.status.equals('delivered'));
    if (userId != null) {
      query.where((t) => t.assignedUserId.equals(userId));
    }
    final rows = await query.get();
    return rows.where((o) => _sameTrDay(o.occurredAt, localDate)).length;
  }

  /// Borç durumu: toplam açık veresiye (balance_kurus>0) + borçlu müşteri listesi (çoktan aza).
  Future<BorcDurumu> borcDurumu() async {
    final rows = await (db.select(db.customers)
          ..where((t) => t.deletedAt.isNull() & t.balanceKurus.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.balanceKurus)]))
        .get();

    final borclular = rows
        .map((c) => BorcluMusteri(customerId: c.id, name: c.name, balanceKurus: c.balanceKurus))
        .toList();
    final toplam = borclular.fold<int>(0, (s, b) => s + b.balanceKurus);
    return BorcDurumu(toplamAcikBorc: toplam, borclular: borclular);
  }

}

/// Gün sonu kasa özeti (kuruş). Salt-okunur değer nesnesi.
class KasaOzeti {
  KasaOzeti({required this.nakit, required this.kart, required this.havale});
  final int nakit;
  final int kart;
  final int havale;
  int get toplam => nakit + kart + havale;
}

class BorcDurumu {
  BorcDurumu({required this.toplamAcikBorc, required this.borclular});
  final int toplamAcikBorc;
  final List<BorcluMusteri> borclular;
}

class BorcluMusteri {
  BorcluMusteri({required this.customerId, required this.name, required this.balanceKurus});
  final String customerId;
  final String name;
  final int balanceKurus;
}
