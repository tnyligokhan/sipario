import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'tables.dart';

part 'app_database.g.dart';
part 'app_database_gocler.dart';

/// Ürünün yerel veritabanı (Drift). Faz 0 sqflite spike'ının yerini alır; sipario.db dosya adı ve
/// customers/customer_phones/phone_last10 sözleşmesi native arayan-tanıma için KORUNUR.
@DriftDatabase(
  tables: [
    Customers,
    CustomerPhones,
    CustomerAddresses,
    Products,
    Orders,
    OrderLines,
    OrderEvents,
    LedgerEntries,
    CashHandovers,
    Users,
    TenantSettings,
    ExemptNumbers,
    CallLogs,
    DayClosings,
    Outbox,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Test/enjeksiyon için: verilen executor (ör. NativeDatabase.memory()).
  AppDatabase(super.e);

  /// Cihazda: sipario.db'yi Faz 0 ile AYNI dizinde açar (native aynı dosyayı okur).
  AppDatabase.file() : super(_openOnDevice());

  /// ⚠️ KOLON EKLEYEN HERKES BU SAYIYI ARTIRMAK ZORUNDA — 2026-08-09'da sahada ödendi.
  ///
  /// Yetki Matrisi (2026-08-08) `tenant_settings`e 13 kolon ekledi, aşağıdaki `onUpgrade`
  /// içine ALTER TABLE'larını da yazdı, **ama bu sayı 14'te bırakıldı.** Drift `onUpgrade`'i
  /// YALNIZ sürüm değiştiğinde çağırır; sahadaki cihazlar zaten v14 damgalı olduğu için o
  /// ALTER TABLE'lar HİÇ KOŞMADI. Sonuç: `no such column: tenant_settings.courier_can_see_all_orders`
  /// ve `tenant_settings`e dokunan her sorgunun patlaması (harita ekranı bu yüzden açılmıyordu).
  ///
  /// **Testler bunu göremez** — her test `NativeDatabase.memory()` ile TAZE veritabanı kurar,
  /// yani `onCreate` yolundan geçer ve şema her zaman tamdır. 1109 yeşil testin hiçbiri
  /// YÜKSELTME yolundan geçmiyordu. Kusur yalnız "önceki sürümü kurulu olan cihazda" görünür.
  @override
  int get schemaVersion => 23; // v1 Faz0 · v2 Faz2 · v3 Faz3 · v4 Faz4 kurye · v5 Faz5a abonelik · v6 Dilim1 oturum · v7 Dilim4 ekip(users) · v8 tasarım boşluğu · v9 oto-sıralama kotası · v10 kupon kaldırıldı · v11 sıra kodları (müşteri/sipariş) · v12 müşteri kara listesi · v13 IBAN · v14 IBAN alıcı adı + hatırlatma şablonu · v15 kurye yetki matrisi 13 kolonu (SÜRÜM ARTIŞI UNUTULMUŞTU) · v16 sync_meta.api_version (sunucu sözleşme sürümü önbelleği) · v17 users'a kişiye özel kurye yetkileri (13 NULLABLE kolon — null = bayi varsayılanını devral) · v18 order_lines.note (satır notu) + customers.favorite_product_ids (JSON dizi) · v19 sync_meta "beni hatırla" (saved_tenant_code + saved_username) · v20 cash_handovers.reverses_handover_id (ara tahsilat iptal kaydı) · v21 call_logs.user_id (çağrıyı kim karşıladı) · v22 day_closings.reverses_closing_id (kapanışı geri alma kaydı) · v23 ürün seçenekleri (products.options_json + order_lines.options_json + customers.product_options_json)

  @override
  /// Göç merdiveni AYRI DOSYADA (`app_database_gocler.dart`, 500 satır kuralı): bu getter
  /// yalnız oraya bağlar. Gerekçe ve "kapıdan önce/sonra" kuralı o dosyanın başlığında.
  @override
  MigrationStrategy get migration => gocStratejisi;

  /// Senkron meta tek satırını döner (garanti var — beforeOpen kurar).
  Future<SyncMetaData> syncState() =>
      (select(syncMeta)..where((t) => t.id.equals(1))).getSingle();

  /// Senkron meta tek satırının AKIŞI. Sunucu sahipli alanlar (abonelik, firma kodu, rota
  /// kontörü) senkron tamamlanınca yazılır — ekran açılışında tek atış okuma YAPMAK YETMEZ,
  /// değer o an henüz gelmemiş olabilir (cihazda yaşandı: "Oto Sırala · 0 hak" yazıyordu,
  /// sunucuda 34 vardı; giriş yanıtı kontörü taşımıyor, ilk senkron taşıyor).
  Stream<SyncMetaData> watchSyncState() =>
      (select(syncMeta)..where((t) => t.id.equals(1))).watchSingle();

  /// KARANTİNADAKİ giden-kutusu kayıtlarının sayısı (akış).
  ///
  /// Sunucunun kalıcı olarak kabul etmediği olaylar SİLİNMEZ (BRIEF kırmızı çizgi #3) — ama
  /// sessizce durmaları da kabul edilemez: o sipariş/tahsilat bu telefonda VAR, sunucuda YOK.
  /// Bandın karantina satırı bu akıştan beslenir; sayı sıfırlanana kadar (destek kaydı elden
  /// geçirene kadar) bant durur. TUR BAŞINA bir sayaç yetmezdi: karantinaya alınan olay bir
  /// daha gönderilmediği için sonraki turlar temiz geçer ve uyarı ilk turda kaybolurdu.
  Stream<int> watchKarantinaSayisi() {
    final sayac = outbox.id.count();
    return (selectOnly(outbox)
          ..addColumns([sayac])
          ..where(outbox.status.equals('rejected')))
        .watchSingle()
        .map((r) => r.read(sayac) ?? 0);
  }

  /// GÖNDERİLMEYİ BEKLEYEN giden-kutusu kayıtlarının sayısı (akış) — senkronun YAZIM TETİĞİ.
  ///
  /// NEDEN VAR (2026-08-09 saha arızası): patron siparişi kuryeye atıyor, kurye yenilese bile
  /// göremiyordu; patron uygulamayı alta alıp öne getirince görünüyordu. Atama outbox'a düzgün
  /// düşüyordu — eksik olan, kaydın sunucuya GİDECEĞİ ANIN tetiklenmesiydi: tur yalnız dört DIŞ
  /// olayla açılıyordu (2 dk zamanlayıcı · ağ değişimi · öne gelme · aşağı çekerek yenileme) ve
  /// "alta alıp açınca gidiyor" gözlemi tam olarak `AppLifecycleState.resumed` turudur. Bu bir
  /// tutarlılık değil GECİKME arızasıydı; durağan durumu ölçen teşhislerin kaçırdığı da buydu.
  ///
  /// NEDEN AKIŞ, NEDEN `enqueueOutbox` İÇİNDEN ÇAĞRI DEĞİL: her yazım bir `db.transaction`
  /// İÇİNDEDİR (yerel satır + outbox aynı transaction'da — DECISIONS). Oradan tetiklenen bir tur
  /// commit'ten ÖNCE koşar ve ya kaydı göremez ya da yazma kilidine girer. Drift'in tablo
  /// bildirimi COMMIT sonrası düşer; [watchKarantinaSayisi] karantina bandını yıllardır bu
  /// desenle besliyor. Ayrıca outbox'a yazan 30 nokta (sipariş · defter · kasa devri · gün
  /// kapanışı · müşteri · ürün · kurye · çağrı günlüğü · muaf numara · işletme ayarları) tek
  /// tetiği paylaşır: repo katmanı senkrondan habersiz kalır, yarın eklenecek yazım unutulmaz.
  ///
  /// ⚠️ DİNLEYEN TARAF YALNIZ ARTIŞA TETİKLENMELİ: push kayıtları `acked` yapınca bu sayı düşer
  /// ve akış YİNE yayın yapar — düşüşe de tur açan bir dinleyici kendi kendini besleyen sonsuz
  /// tur döngüsü kurardı (bkz. `sync_service.dart::yazimTetigiBagla`).
  Stream<int> watchBekleyenSayisi() {
    final sayac = outbox.id.count();
    return (selectOnly(outbox)
          ..addColumns([sayac])
          ..where(outbox.status.equals('pending')))
        .watchSingle()
        .map((r) => r.read(sayac) ?? 0);
  }

  /// ALTER'ı "duplicate column"a TOLERANSLI koşar (savunma derinliği — sürüm damgası harici
  /// bir açıcı tarafından ezilirse migration yeniden koşabilir; var olan kolon hata değildir).
  /// Tablo bu veritabanında var mı? Migration adımları eski şemalarda da koştuğu için, henüz
  /// doğmamış bir tabloya ALTER atmadan önce sorulur.
  static Future<bool> _tabloVar(Migrator m, String ad) async {
    final r = await m.database
        .customSelect("SELECT 1 FROM sqlite_master WHERE type='table' AND name='$ad'")
        .get();
    return r.isNotEmpty;
  }

  static Future<void> _addColumnIfMissing(Migrator m, String sql) async {
    try {
      await m.database.customStatement(sql);
    } on Exception catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
  }
}

/// Native taraf sipario.db'yi salt-okunur açtığından WAL yerine rollback-journal kullanılır
/// (WAL'de -wal/-shm dosyaları salt-okunur açıcıyı bozabilir — DECISIONS Faz 2 riski, gerçek
/// cihazda doğrulanacak). Dosya Faz 0 ile AYNI dizinde (sqflite getDatabasesPath).
LazyDatabase _openOnDevice() {
  return LazyDatabase(() async {
    final dir = await getDatabasesPath();
    final file = File(p.join(dir, 'sipario.db'));

    return NativeDatabase.createInBackground(
      file,
      setup: (raw) => raw.execute('PRAGMA journal_mode = TRUNCATE'),
    );
  });
}
