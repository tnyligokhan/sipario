import 'package:drift/drift.dart';

import '../data/app_database.dart';

/// Gün sonu SALT-OKUNUR read-model (FAZ 3). Hiçbir tabloya YAZMAZ (kalıcı durum üretmez); tüm veriyi
/// yerel Drift'ten türetir. Kasa özeti + borç durumu + kupon durumu. Kurye kasa DEVRİ (kalıcı
/// mutabakat) ve atama FAZ 4 sınırıdır — buraya girmez.
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
  Future<KasaOzeti> kasaOzeti(DateTime localDate) async {
    final tillEntries = await (db.select(db.ledgerEntries)
          ..where((t) => t.paymentType.isNotNull()))
        .get();

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

  /// Kupon durumu: eksi bakiyeli müşteriler (UI kırmızı) + toplam açık kupon adedi + gün içinde
  /// verilen/kullanılan kupon (grant/use toplamı; correction ayrı tutulur).
  Future<KuponDurumu> kuponDurumu(DateTime localDate) async {
    final balances = await db.select(db.couponBalances).get();
    final eksiler = balances
        .where((b) => b.balanceQty < 0)
        .map((b) => EksiKupon(customerId: b.customerId, productId: b.productId, balanceQty: b.balanceQty))
        .toList();
    final acikToplam = balances.where((b) => b.balanceQty > 0).fold<int>(0, (s, b) => s + b.balanceQty);

    final moves = await db.select(db.couponMovements).get();
    var verilen = 0, kullanilan = 0;
    for (final mv in moves) {
      if (!_sameTrDay(mv.occurredAt, localDate)) continue;
      if (mv.movementType == 'grant') verilen += mv.qtyDelta;
      if (mv.movementType == 'use') kullanilan += -mv.qtyDelta; // use negatif → kullanılan pozitif
    }

    return KuponDurumu(
      toplamAcikKupon: acikToplam,
      eksiBakiyeliler: eksiler,
      gunlukVerilen: verilen,
      gunlukKullanilan: kullanilan,
    );
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

class KuponDurumu {
  KuponDurumu({
    required this.toplamAcikKupon,
    required this.eksiBakiyeliler,
    required this.gunlukVerilen,
    required this.gunlukKullanilan,
  });
  final int toplamAcikKupon;
  final List<EksiKupon> eksiBakiyeliler;
  final int gunlukVerilen;
  final int gunlukKullanilan;
}

class EksiKupon {
  EksiKupon({required this.customerId, required this.productId, required this.balanceQty});
  final String customerId;
  final String productId; // '' = genel kupon (sentinel)
  final int balanceQty;
}
