/// YÜKSELTME (onUpgrade) TESTLERİNİN ORTAK İSKELESİ.
///
/// NEDEN VAR: bu depodaki testlerin neredeyse tamamı `NativeDatabase.memory()` ile TAZE
/// veritabanı kurar — yani `onCreate` yolundan geçer ve orada şema HER ZAMAN tamdır. Sahadaki
/// telefon ise `onUpgrade` yolundan geçer; uygulama offline-first çalıştığı için cihazlar
/// günlerce eski damgada kalır. 2026-08-09'da bedeli ödendi: 13 kolon eklendi, `schemaVersion`
/// artırılmadı, sahadaki cihazlarda ALTER'lar hiç koşmadı ve `tenant_settings`e dokunan her
/// sorgu patladı — o günün 1109 yeşil testinin hiçbiri görmedi.
///
/// DESEN (üç adım): (1) güncel şemayla kur + KORUNMASI GEREKEN veriyi yaz, (2) dosyayı hedef
/// sürüme GERİ SAR (o sürümden sonra eklenen kolon/tabloları düşür + `PRAGMA user_version`),
/// (3) yeniden aç → `onUpgrade` koşar. Yeni bir vardiyanın tek yapması gereken, kendi sürümünün
/// geri-sarma listesini yazıp [eskiCihaziYukselt] çağırmaktır.
///
/// ⚠️ İDDİA "AÇILDI MI" DEĞİLDİR: aranan şey VERİ KAYBI ve SESSİZ EKSİK KOLONdur. Her testin
/// sonunda [semaTamOlmali] çağrılır — o, yükseltilmiş şemayı TAZE şemayla karşılaştırır ve
/// "ALTER yazmayı unutulmuş kolon" sınıfını tek başına yakalar (bu yardımcı yazıldığında
/// `users.username` tam olarak böyle bulundu: eklendiği günden beri hiç ALTER'ı yoktu).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sipario/data/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Geçici (ve teste özel) bir veritabanı dosyası yolu. Eşzamanlı koşan testler çakışmasın diye
/// mikrosaniye damgalıdır.
File geciciDbDosyasi(String etiket) {
  final f = File(p.join(
    Directory.systemTemp.path,
    'sipario_${etiket}_${DateTime.now().microsecondsSinceEpoch}.db',
  ));
  if (f.existsSync()) f.deleteSync();
  return f;
}

/// "Sahadaki eski cihaz"ı kurar ve yükseltir — üç adımın tamamı.
///
/// [veriYaz] GÜNCEL şemayla açılmış veritabanına çağrılır (yükseltmenin korumak zorunda olduğu
/// veri buraya yazılır). [geriSar] ham SQL listesidir ve indeks düşürmeleri ÖNCE gelmelidir:
/// SQLite indeksli bir kolonu düşürmeyi reddeder. [surum] geri sarılan `user_version`dır.
///
/// Dönen veritabanı AÇIKTIR; kapanışı ve dosya temizliği `addTearDown` ile bağlanır.
Future<AppDatabase> eskiCihaziYukselt({
  required String etiket,
  required int surum,
  required List<String> geriSar,
  Future<void> Function(AppDatabase db)? veriYaz,
}) async {
  final file = geciciDbDosyasi(etiket);

  final guncel = AppDatabase(NativeDatabase(file));
  if (veriYaz != null) await veriYaz(guncel);
  await guncel.close();

  final raw = sqlite3.open(file.path);
  for (final sql in geriSar) {
    raw.execute(sql);
  }
  raw.execute('PRAGMA user_version = $surum');
  raw.close();

  return dosyayiAc(file);
}

/// Faz 0'ın (sqflite v1) diskteki şemasını BİREBİR kurar ve `user_version = 1` damgalar.
///
/// v1 "geri sarılamaz": o şema Drift'ten değil, kaldırılmış bir ölçüm ekranından gelir. Native
/// arayan-tanıma tarafının sözleşmesi (tablo/kolon adları + `phone_last10` indeksi) budur.
File faz0V1DosyasiKur(String etiket, {void Function(Database raw)? veriYaz}) {
  final file = geciciDbDosyasi(etiket);
  final raw = sqlite3.open(file.path);
  raw.execute('''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, address TEXT, note TEXT,
      balance_kurus INTEGER NOT NULL DEFAULT 0
    )''');
  raw.execute('''
    CREATE TABLE customer_phones (
      id TEXT PRIMARY KEY, customer_id TEXT NOT NULL REFERENCES customers(id),
      phone_e164 TEXT NOT NULL, phone_last10 TEXT NOT NULL, label TEXT,
      is_primary INTEGER NOT NULL DEFAULT 0
    )''');
  raw.execute('CREATE INDEX idx_phones_last10 ON customer_phones(phone_last10)');
  veriYaz?.call(raw);
  raw.execute('PRAGMA user_version = 1');
  raw.close();
  return file;
}

/// Dosyayı açar (yükseltmeyi tetikler) ve temizliğini bağlar.
AppDatabase dosyayiAc(File file) {
  final db = AppDatabase(NativeDatabase(file));
  addTearDown(() async {
    await db.close();
    if (file.existsSync()) file.deleteSync();
  });
  return db;
}

/// Bir tablonun gerçek kolon adları (PRAGMA table_info).
Future<Set<String>> kolonlar(AppDatabase db, String tablo) => db
    .customSelect('PRAGMA table_info($tablo)')
    .get()
    .then((rows) => rows.map((r) => r.read<String>('name')).toSet());

/// Veritabanındaki TÜM tabloların kolon haritası (sqlite iç tabloları hariç).
Future<Map<String, Set<String>>> semaHaritasi(AppDatabase db) async {
  final tablolar = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'")
      .get()
      .then((rows) => rows.map((r) => r.read<String>('name')).toList());
  return {
    for (final t in tablolar) t: await kolonlar(db, t),
  };
}

/// ⭐ SINIF DÜZEYİNDE KORUMA: yükseltilmiş şema, TAZE kurulmuş şemanın TAMAMINI içermeli.
///
/// Tek tek kolon iddiası yazmak, yazılmayı UNUTULAN kolonu göremez — bu karşılaştırma görür.
/// Yön tek taraflıdır (taze ⊆ yükseltilmiş): eski cihazda artakalan yetim kolonlar (ör. Faz 0'ın
/// `customers.address`i) zararsızdır ve bilerek korunur.
Future<void> semaTamOlmali(AppDatabase yukseltilmis, {String? gerekce}) async {
  final taze = AppDatabase(NativeDatabase.memory());
  addTearDown(taze.close);

  final beklenen = await semaHaritasi(taze);
  final gercek = await semaHaritasi(yukseltilmis);

  final eksikler = <String>[];
  beklenen.forEach((tablo, kolonSeti) {
    final varOlan = gercek[tablo];
    if (varOlan == null) {
      eksikler.add('$tablo → TABLO HİÇ OLUŞMADI');
      return;
    }
    for (final k in kolonSeti) {
      if (!varOlan.contains(k)) eksikler.add('$tablo.$k');
    }
  });

  // İNDEKSLER DE ŞEMANIN PARÇASIDIR ve eksikliği KOLONDAN SİNSİDİR: sorgu patlamaz, yalnız
  // yavaşlar. `idx_phones_last10` arayan-tanımanın 1 sn bütçesinin tek dayanağıdır — o indeks
  // olmadan telefon çalarken kart geç çizilir ve kimse bunu "arıza" diye bildirmez.
  for (final ix in await indeksler(taze)) {
    if (!(await indeksler(yukseltilmis)).contains(ix)) eksikler.add('INDEKS $ix');
  }

  expect(
    eksikler,
    isEmpty,
    reason: 'YÜKSELTİLMİŞ ŞEMA EKSİK — sahadaki cihazda bu kolon/tablolara dokunan HER sorgu '
        '"no such column" ile patlar (2026-08-09 arıza sınıfı).'
        '${gerekce == null ? '' : ' $gerekce'}',
  );
}

/// Kullanıcı tanımlı indeksler (sqlite'ın kendi ürettikleri hariç).
Future<Set<String>> indeksler(AppDatabase db) => db
    .customSelect("SELECT name FROM sqlite_master WHERE type='index' "
        "AND name NOT LIKE 'sqlite_%'")
    .get()
    .then((rows) => rows.map((r) => r.read<String>('name')).toSet());

// ---------------------------------------------------------------------------
// ÇOK ESKİ CİHAZ SENARYOLARI — TARİHSEL ŞEMADAN geri sarma
//
// ⚠️ NEDEN "DÜŞÜRÜLECEK KOLON LİSTESİ" DEĞİL, "O SÜRÜMDE VAR OLAN KOLON LİSTESİ":
// düşürme listesi YARIN EKLENECEK KOLONU BİLEMEZ. Yarınki vardiya `users`a bir kolon ekleyip
// ALTER'ını yazmayı unutursa, düşürme listesi o kolona dokunmaz → sahte cihazda kolon DURUR →
// karşılaştırma yeşil yanar ve tam da yakalamak için yazıldığı kusuru kaçırır. Tarihsel şema
// ise DONDURULMUŞtur: sonradan eklenen her kolon otomatik olarak "bu sürümde yoktu" sayılır ve
// düşürülür. Yani bu iskele yeni sürümlerde BAKIM İSTEMEDEN çalışmaya devam eder.
//
// Haritalar tahmin değil ÖLÇÜMdür: `tables.dart`ın o sürümdeki git hâlinden çıkarıldı
// (2026-08-17). DEĞİŞTİRİLMEZLER — geçmiş değişmez.
// ---------------------------------------------------------------------------

/// Tarihsel bir şemaya göre geri sarar ve yükseltir.
///
/// Güncel dosyada var olup [tarihselSema]da OLMAYAN her tablo düşürülür, her kolon
/// `DROP COLUMN` edilir. [onceDusurulecekIndeksler] ilk sırada koşar: SQLite indeksli bir
/// kolonu düşürmeyi reddeder.
///
/// Gelecekte indeksli YENİ bir kolon eklenirse bu çağrı SQLite hatasıyla düşer — bu bilinçli:
/// sessizce atlamak yerine, geri sarmanın eksik kaldığını yüzümüze söylemesi istenir.
Future<AppDatabase> tarihselCihaziYukselt({
  required String etiket,
  required int surum,
  required Map<String, Set<String>> tarihselSema,
  List<String> onceDusurulecekIndeksler = const [],
  Future<void> Function(AppDatabase db)? veriYaz,
}) async {
  final file = geciciDbDosyasi(etiket);

  final guncel = AppDatabase(NativeDatabase(file));
  if (veriYaz != null) await veriYaz(guncel);
  await guncel.close();

  final raw = sqlite3.open(file.path);
  for (final ix in onceDusurulecekIndeksler) {
    raw.execute('DROP INDEX IF EXISTS $ix');
  }
  final tablolar = raw
      .select("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
      .map((r) => r['name'] as String)
      .toList();
  for (final tablo in tablolar) {
    final kalanlar = tarihselSema[tablo];
    if (kalanlar == null) {
      raw.execute('DROP TABLE IF EXISTS $tablo');
      continue;
    }
    final mevcut = raw.select('PRAGMA table_info($tablo)').map((r) => r['name'] as String);
    for (final k in mevcut) {
      if (!kalanlar.contains(k)) raw.execute('ALTER TABLE $tablo DROP COLUMN $k');
    }
  }
  raw.execute('PRAGMA user_version = $surum');
  raw.close();

  return dosyayiAc(file);
}

/// v7 damgalı cihaz (Dilim 4 "ekip" sürümü: `users` VAR, `tenant_settings` YOK).
///
/// KRİTİK SENARYO: `users` bu sürümde DOĞMUŞTUR, yani sonraki sürümlerin `createTable(users)`
/// yolu bu cihazda BİR DAHA KOŞMAZ — `users`a eklenen her kolonun ALTER'ı olmak zorundadır.
const v7Semasi = <String, Set<String>>{
  'customers': {
    'id', 'name', 'note', 'balance_kurus', 'updated_occurred_at', 'updated_device_id', 'deleted_at',
  },
  'customer_phones': {
    'id', 'customer_id', 'phone_e164', 'phone_last10', 'label', 'is_primary',
    'updated_occurred_at', 'updated_device_id', 'deleted_at',
  },
  'customer_addresses': {
    'id', 'customer_id', 'label', 'address_text', 'lat', 'lng', 'is_primary',
    'updated_occurred_at', 'updated_device_id', 'deleted_at',
  },
  'products': {
    'id', 'name', 'unit_price_kurus', 'unit', 'is_active',
    'updated_occurred_at', 'updated_device_id', 'deleted_at',
  },
  'orders': {
    'id', 'customer_id', 'assigned_user_id', 'status', 'total_kurus', 'payment_type', 'note',
    'occurred_at', 'created_device_id', 'deleted_at',
  },
  'order_lines': {
    'id', 'order_id', 'product_id', 'product_name', 'unit_price_kurus', 'qty',
    'line_total_kurus', 'deleted_at',
  },
  'order_events': {
    'id', 'order_id', 'event_type', 'payload', 'client_event_id', 'occurred_at', 'device_id',
  },
  'ledger_entries': {
    'id', 'customer_id', 'entry_type', 'amount_kurus', 'payment_type', 'collected_by_user_id',
    'related_order_id', 'reverses_entry_id', 'note', 'occurred_at', 'device_id', 'client_event_id',
  },
  'cash_handovers': {
    'id', 'from_user_id', 'to_user_id', 'counted_cash_kurus', 'expected_cash_kurus', 'diff_kurus',
    'period_start', 'occurred_at', 'device_id', 'note',
  },
  'users': {'id', 'name', 'role', 'status'},
  'outbox': {
    'id', 'client_event_id', 'entity_type', 'op', 'entity_id', 'payload', 'occurred_at',
    'device_id', 'created_at', 'status', 'attempts', 'last_error',
  },
  'sync_meta': {
    'id', 'last_pulled_seq', 'last_server_time_iso', 'server_time_offset_ms', 'elapsed_anchor_ms',
    'snapshot_done', 'device_id', 'user_id', 'valid_until_iso', 'locked_at_iso',
    'subscription_status', 'auth_token', 'user_name', 'user_role', 'tenant_name', 'api_base_url',
  },
};

/// v8 damgalı cihaz (tasarım boşluğu sürümü — `tenant_settings` VAR).
///
/// KRİTİK SENARYO: kendini-onarma kapısı `tenant_settings`i görünce ERKEN DÖNER. Yani bu
/// cihazda `from < N` dallarının HİÇBİRİ koşmaz; kapıdan ÖNCE yazılmayan her adım ÖLÜDÜR.
final v8Semasi = <String, Set<String>>{
  ...v7Semasi,
  'customer_addresses': {...v7Semasi['customer_addresses']!, 'region'},
  'products': {...v7Semasi['products']!, 'barcode', 'image_url', 'image_local_path'},
  'orders': {...v7Semasi['orders']!, 'sort_index'},
  'order_lines': {...v7Semasi['order_lines']!, 'unit', 'is_custom'},
  'users': {...v7Semasi['users']!, 'phone'},
  'sync_meta': {
    ...v7Semasi['sync_meta']!,
    'tenant_code', 'route_credits', 'setup_completed_at', 'theme_mode',
    // NOT: `route_credits_monthly` BİLEREK YOK — o v9 kolonudur ve bu senaryonun bütün
    // meselesi, v9 adımının v8 damgalı cihazda koşup koşmadığıdır.
  },
  'tenant_settings': {
    'id', 'business_name', 'owner_name', 'phone', 'whatsapp', 'address_text', 'tax_office',
    'tax_number', 'opens_at', 'closes_at', 'receipt_note', 'updated_occurred_at',
    'updated_device_id',
  },
  'exempt_numbers': {
    'id', 'phone_e164', 'phone_last10', 'label', 'updated_occurred_at', 'updated_device_id',
    'deleted_at',
  },
  'call_logs': {
    'id', 'customer_id', 'phone_e164', 'phone_last10', 'direction', 'outcome', 'related_order_id',
    'occurred_at', 'device_id', 'updated_occurred_at', 'updated_device_id', 'deleted_at',
  },
  'day_closings': {
    'id', 'scope', 'user_id', 'period_start', 'delivery_count', 'total_collected_kurus',
    'cash_nakit_kurus', 'cash_kart_kurus', 'cash_havale_kurus', 'open_credit_kurus',
    'expected_cash_kurus', 'counted_cash_kurus', 'diff_kurus', 'cash_handover_id', 'note',
    'occurred_at', 'device_id',
  },
};

/// `products.barcode` v8'de gelir ve İNDEKSLİDİR; v7'ye geri sarmak için indeks önce düşer.
/// `exempt_numbers`/`call_logs` indeksleri tablolarıyla birlikte gider ama açıkça yazmak
/// SQLite'ın "indeksli kolon düşürülemez" hatasını kesin olarak eler.
const v7Indeksleri = <String>[
  'idx_products_barcode',
  'idx_exempt_last10',
  'idx_call_logs_occurred',
];
