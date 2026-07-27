// Ana ekranın (s-ana.jsx) bento rakamları — SALT-OKUNUR read-model.
//
// `lib/repo/` `backend` ajanının alanı olduğundan bu sorgular kabuğun kendi dosyasında yaşar.
// Hiçbir tabloya YAZMAZ; yalnız Drift'ten türetir ve `watch()` ile canlı kalır (sipariş teslim
// edilince bento kendiliğinden güncellenir).
//
// GÜN SINIRI: DayEndRepository ile AYNI kural — sabit +03:00 (Türkiye, 2016'dan beri DST yok).
// TR gece yarısının UTC karşılığı hesaplanıp sınır olarak SQL'e verilir; `datetime()` ile
// karşılaştırılır ki sunucudan gelen farklı ISO yazımları (Z'li / Z'siz / kesirli saniye) da
// doğru düşsün.

import 'package:drift/drift.dart';

import '../../data/app_database.dart';

const Duration _trOffset = Duration(hours: 3);

/// Verilen TR takvim gününün [başlangıç, bitiş) UTC ISO sınırları.
({String bas, String son}) trGunSiniri(DateTime trGun) {
  final geceYarisi = DateTime.utc(trGun.year, trGun.month, trGun.day);
  final bas = geceYarisi.subtract(_trOffset);
  return (
    bas: bas.toIso8601String(),
    son: bas.add(const Duration(days: 1)).toIso8601String(),
  );
}

/// Bugünün TR takvim günü (yerel saatten bağımsız — cihaz saati yanlış olsa da gün TR'ye göre).
DateTime bugunTrGunu([DateTime? simdi]) {
  final tr = (simdi ?? DateTime.now()).toUtc().add(_trOffset);
  return DateTime.utc(tr.year, tr.month, tr.day);
}

/// Ana ekran bento kutularının dört rakamı + yanlarındaki alt bilgiler.
class AnaOzet {
  const AnaOzet({
    this.acikSiparis = 0,
    this.bugunSiparis = 0,
    this.bugunTeslim = 0,
    this.bugunTahsilatKurus = 0,
    this.borcluMusteri = 0,
    this.acikVeresiyeKurus = 0,
  });

  /// Teslim bekleyen sipariş sayısı (durum `open`).
  final int acikSiparis;

  /// Bugün açılan sipariş sayısı.
  final int bugunSiparis;

  /// Bugün teslim edilen sipariş sayısı.
  final int bugunTeslim;

  /// Bugün kasaya giren tahsilat (nakit+kart+havale, kuruş).
  final int bugunTahsilatKurus;

  /// Bakiyesi borçta olan müşteri sayısı.
  final int borcluMusteri;

  /// Toplam açık veresiye (kuruş, pozitif).
  final int acikVeresiyeKurus;
}

/// Bento rakamlarının canlı akışı. Sipariş/defter/müşteri tablolarından herhangi biri değişince
/// yeniden yayar.
Stream<AnaOzet> watchAnaOzet(AppDatabase db, {DateTime? gun}) {
  final s = trGunSiniri(gun ?? bugunTrGunu());
  final v = [
    Variable<String>(s.bas),
    Variable<String>(s.son),
  ];

  return db
      .customSelect(
        '''
        SELECT
          (SELECT COUNT(*) FROM orders
             WHERE deleted_at IS NULL AND status = 'open')            AS acik_siparis,
          (SELECT COUNT(*) FROM orders
             WHERE deleted_at IS NULL
               AND datetime(occurred_at) >= datetime(?)
               AND datetime(occurred_at) <  datetime(?))              AS bugun_siparis,
          (SELECT COUNT(*) FROM orders
             WHERE deleted_at IS NULL AND status = 'delivered'
               AND datetime(occurred_at) >= datetime(?)
               AND datetime(occurred_at) <  datetime(?))              AS bugun_teslim,
          (SELECT COALESCE(SUM(-amount_kurus), 0) FROM ledger_entries
             WHERE payment_type IS NOT NULL
               AND datetime(occurred_at) >= datetime(?)
               AND datetime(occurred_at) <  datetime(?))              AS bugun_tahsilat,
          (SELECT COUNT(*) FROM customers
             WHERE deleted_at IS NULL AND balance_kurus > 0)          AS borclu,
          (SELECT COALESCE(SUM(balance_kurus), 0) FROM customers
             WHERE deleted_at IS NULL AND balance_kurus > 0)          AS veresiye
        ''',
        variables: [...v, ...v, ...v],
        readsFrom: {db.orders, db.ledgerEntries, db.customers},
      )
      .watchSingle()
      .map((r) => AnaOzet(
            acikSiparis: r.read<int>('acik_siparis'),
            bugunSiparis: r.read<int>('bugun_siparis'),
            bugunTeslim: r.read<int>('bugun_teslim'),
            bugunTahsilatKurus: r.read<int>('bugun_tahsilat'),
            borcluMusteri: r.read<int>('borclu'),
            acikVeresiyeKurus: r.read<int>('veresiye'),
          ));
}

/// "Son aktivite" listesinin bir satırı (CSS `.akt-row`).
class SonHareket {
  const SonHareket({
    required this.siparisId,
    required this.musteriAd,
    required this.tutarKurus,
    this.odemeTipi,
    required this.occurredAt,
    this.satirOzeti = '',
  });

  final String siparisId;
  final String musteriAd;
  final int tutarKurus;
  final String? odemeTipi;
  final String occurredAt;

  /// Ürün dökümü: "Tüp ×2 · Su ×1" (tasarım `siparisOzet`, `s-veri.jsx:103`). Serbest satır
  /// adet taşımaz, yalnız açıklamasıyla yazılır. Satırı olmayan siparişte boştur.
  final String satirOzeti;
}

/// Son teslim edilen siparişler (varsayılan 3 — tasarımdaki `teslim.slice(0, 3)`).
Stream<List<SonHareket>> watchSonHareketler(AppDatabase db, {int limit = 3}) {
  return db
      .customSelect(
        // Ürün dökümü SQL'de birleştirilir: `order_queries.dart`taki `satirOzeti` ile aynı
        // biçim ("ad ×adet", serbest satırda yalnız ad) ama o katman `siparis` ajanının alanı
        // ve satır satır Dart nesnesi ister; üç satırlık liste için ikinci bir sorgu açmak
        // yerine burada tek atışta toplanır.
        //
        // İLİŞKİLİ (correlated) SKALER alt sorgu — `FROM (SELECT … WHERE l.order_id = o.id)`
        // biçimi SQLite'ta ÇALIŞMAZ (FROM alt sorgusu dış sorgunun kolonunu göremez, LATERAL
        // yok). group_concat'e ORDER BY verilemediğinden sıra tarama sırasıdır: order_id
        // eşitliğinde satırlar rowid artışıyla gelir, yani sepete eklenme sırası korunur.
        '''
        SELECT o.id AS id, o.total_kurus AS tutar, o.payment_type AS odeme,
               o.occurred_at AS zaman, c.name AS musteri,
               (SELECT group_concat(
                          CASE WHEN l.is_custom = 1
                               THEN l.product_name
                               ELSE l.product_name || ' ×' || l.qty END, ' · ')
                  FROM order_lines l
                 WHERE l.order_id = o.id AND l.deleted_at IS NULL) AS ozet
        FROM orders o
        LEFT JOIN customers c ON c.id = o.customer_id
        WHERE o.deleted_at IS NULL AND o.status = 'delivered'
        ORDER BY o.occurred_at DESC
        LIMIT ?
        ''',
        variables: [Variable<int>(limit)],
        readsFrom: {db.orders, db.customers, db.orderLines},
      )
      .watch()
      .map((rows) => rows
          .map((r) => SonHareket(
                siparisId: r.read<String>('id'),
                musteriAd: r.read<String?>('musteri') ?? 'Kayıtsız müşteri',
                tutarKurus: r.read<int>('tutar'),
                odemeTipi: r.read<String?>('odeme'),
                occurredAt: r.read<String>('zaman'),
                satirOzeti: r.read<String?>('ozet') ?? '',
              ))
          .toList());
}

/// Tasarımdaki ödeme etiketleri (s-veri.jsx `ODEME_TIPLERI`).
String odemeEtiketi(String? tip) => switch (tip) {
      'nakit' => 'Nakit',
      'kart' => 'Kart',
      'havale' => 'Havale',
      'veresiye' => 'Veresiye',
      _ => '',
    };

/// ISO zaman damgasından TR saati ("14:05"). Yalnız gösterim.
String sipSaat(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final tr = t.toUtc().add(_trOffset);
  return '${tr.hour.toString().padLeft(2, '0')}:${tr.minute.toString().padLeft(2, '0')}';
}
