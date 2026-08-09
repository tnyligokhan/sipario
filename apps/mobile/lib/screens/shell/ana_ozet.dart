// Ana ekranın (s-ana.jsx) bento rakamları — SALT-OKUNUR read-model.
//
// `lib/repo/` `backend` ajanının alanı olduğundan bu sorgular kabuğun kendi dosyasında yaşar.
// Hiçbir tabloya YAZMAZ; yalnız Drift'ten türetir ve `watch()` ile canlı kalır (sipariş teslim
// edilince bento kendiliğinden güncellenir).
//
// GÜN SINIRI KURALI BU DOSYADA YAŞAMAZ: `data/tr_gun.dart`taki TEK tanıma delege edilir.
// Burada bir zamanlar kendi `+3` sabiti ve kendi `bugunTrGunu()`sü vardı; kural toplandığında bu
// dosya atlanmıştı ve sonuç şuydu (inceleme bulgusu, 2026-08-06): telefon 40 dk ileriyken 23:40'ta
// bento "Bugün Kasa 0,00 ₺" derken, kutuya dokununca açılan Gün Özeti "Toplam Tahsilat 12.000 ₺"
// diyordu. Aynı büyüklük, farklı gün kaynağı, bir dokunuş arayla iki farklı gerçek.
// TR gece yarısının UTC karşılığı sınır olarak SQL'e verilir; `datetime()` ile karşılaştırılır ki
// sunucudan gelen farklı ISO yazımları (Z'li / Z'siz / kesirli saniye) da doğru düşsün.

import 'dart:async';

import 'package:drift/drift.dart';

import '../../data/app_database.dart';
import '../../data/tr_gun.dart';

/// Verilen TR takvim gününün [başlangıç, bitiş) UTC ISO sınırları.
({String bas, String son}) trGunSiniri(DateTime trGun) {
  final bas = trGunBasiUtc(trGun);
  return (
    bas: bas.toIso8601String(),
    son: bas.add(const Duration(days: 1)).toIso8601String(),
  );
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
///
/// [gun] verilmezse gün DÜZELTİLMİŞ SUNUCU SAATİNDEN türer — cihaz saatinden DEĞİL. Kayıtlar
/// `correctedNowIso(serverTimeOffsetMs)` ile damgalanıyor; bento'nun günü de aynı saatten gelmek
/// ZORUNDA, yoksa aynı parayı iki yüzey iki farklı güne yazar.
/// [assignedTo] verilirse "Açık Sipariş" kutusu YALNIZ o kullanıcıya atananları sayar
/// (kurye kısıtlaması). Diğer rakamlar dükkân geneli kalır — kasa/teslim/borç kutuları
/// kendi yetki kapılarından geçer.
Stream<AnaOzet> watchAnaOzet(AppDatabase db, {DateTime? gun, String? assignedTo}) =>
    gun != null
        ? _watchGun(db, gun, assignedTo: assignedTo)
        : _duzeltilmisGunAkisi(db, assignedTo: assignedTo);

/// Düzeltilmiş günü İZLER ve gün değiştikçe sorguyu yeniden kurar.
///
/// NEDEN AKIŞ, TEK ATIŞ DEĞİL: `serverTimeOffsetMs` SUNUCU SAHİPLİ bir alandır ve ilk senkronla
/// iner. Açılışta bir kez okunsaydı, saati yanlış kurulmuş bir telefonda bento gün boyu yanlış
/// günün kasasını gösterir, offset indiğinde de kimse ona haber vermezdi (bu depoda yaşanmış bir
/// arıza sınıfı: kontör "0 hak" görünüyordu, sunucuda 34 vardı). Yan fayda: gece yarısını geçen
/// bir ekran, sonraki senkron turunda kendiliğinden yeni güne döner.
Stream<AnaOzet> _duzeltilmisGunAkisi(AppDatabase db, {String? assignedTo}) {
  final gunler = db
      .watchSyncState()
      .map((m) =>
          trGunu(DateTime.now().toUtc().add(Duration(milliseconds: m.serverTimeOffsetMs))))
      .distinct();

  // "switchMap" elle yazılır (depoda rxdart yok): gün değişince ESKİ sorgu akışı kapatılır.
  // `asyncExpand` burada ÇALIŞMAZ — iç akış sonsuzdur, dış olayı hiç sıraya alamaz ve ikinci gün
  // asla gelmez. `distinct()` sayesinde sync_meta'nın her yazımında (lastPulledSeq…) yeniden
  // abone olunmaz; yalnız GÜN değiştiğinde olunur.
  StreamSubscription<DateTime>? disAbone;
  StreamSubscription<AnaOzet>? icAbone;
  late final StreamController<AnaOzet> kanal;
  kanal = StreamController<AnaOzet>(
    onListen: () {
      disAbone = gunler.listen(
        (g) {
          icAbone?.cancel();
          icAbone = _watchGun(db, g, assignedTo: assignedTo)
              .listen(kanal.add, onError: kanal.addError);
        },
        onError: kanal.addError,
      );
    },
    // İKİ ABONELİK DE AYNI TURDA DÜŞÜRÜLÜR — arka arkaya `await` YOK.
    //
    // Eskiden `await icAbone?.cancel(); await disAbone?.cancel();` yazıyordu ve aradaki TEK bir
    // async boşluk, dış aboneliğin iptalini widget testinin son `pump`ından SONRAYA atıyordu.
    // Drift, bir sorgu akışının son dinleyicisi gidince önbelleği bir olay turu daha canlı
    // tutmak için sıfır süreli bir `Timer` kurar (`StreamQueryStore.markAsClosed`); o timer
    // sahte zamanı ilerleten kimse kalmadığı için "A Timer is still pending" ile dört testi
    // düşürüyordu (`ui_dilim4`, HomeShell menü grubu). Susturulacak bir gürültü değildi:
    // test, aboneliğin ağaç yıkıldıktan sonra kapandığını doğru biçimde bildiriyordu.
    //
    // Liste literali iki `cancel()`i de kurulurken SENKRON çağırır; `Future.wait` yalnız
    // bitişlerini bekler.
    onCancel: () async {
      final bekleyen = <Future<void>>[
        if (icAbone != null) icAbone!.cancel(),
        if (disAbone != null) disAbone!.cancel(),
      ];
      icAbone = null;
      disAbone = null;
      await Future.wait(bekleyen);
    },
  );
  return kanal.stream;
}

Stream<AnaOzet> _watchGun(AppDatabase db, DateTime gun, {String? assignedTo}) {
  final s = trGunSiniri(gun);
  final v = [
    Variable<String>(s.bas),
    Variable<String>(s.son),
  ];

  // Kurye kısıtlıysa "Açık Sipariş" kutusu YALNIZ ona atananları sayar (2026-08-09).
  // Süzülmezse ana ekran 12 der, sipariş listesi 2 gösterir — aynı ekranın iki yeri
  // farklı sayı konuşur ve kurye "siparişlerim kayboldu" diye arar.
  //
  // ⚠️ PARAMETRE SIRASI: `?` işaretleri SQL'de göründükleri sıraya bağlanır. Bu süzgeç
  // İLK alt sorguda olduğu için değişkeni de listenin BAŞINA koymak zorundayız.
  final kuryeSuzgeci = assignedTo == null ? '' : 'AND assigned_user_id = ?';

  return db
      .customSelect(
        '''
        SELECT
          (SELECT COUNT(*) FROM orders
             WHERE deleted_at IS NULL AND status = 'open' $kuryeSuzgeci) AS acik_siparis,
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
        variables: [
          if (assignedTo != null) Variable<String>(assignedTo),
          ...v,
          ...v,
          ...v,
        ],
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
  final tr = t.toUtc().add(kTrOffset);
  return '${tr.hour.toString().padLeft(2, '0')}:${tr.minute.toString().padLeft(2, '0')}';
}
