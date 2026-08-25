import 'dart:io';

// `isNull` hem drift'te hem matcher'da tanımlı; burada matcher'ınki isteniyor.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sipario/data/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// v15→v16 — `sync_meta.api_version` (sunucunun sözleşme sürümü önbelleği, 2026-08-10).
///
/// NEDEN AYRI BİR DOSYA VAR (v14 ve v15'in yanına): bu depoda şema değiştiren her vardiyanın
/// yükseltme yolunu YAZILI olarak sınaması kuralı, 2026-08-09'da bir saha arızasıyla ödendi —
/// `schemaVersion` artırılmadığı için `onUpgrade` HİÇ çağrılmamış, ALTER TABLE'ların yazılmış
/// olması hiçbir işe yaramamıştı. Testlerin tamamı `NativeDatabase.memory()` ile TAZE veritabanı
/// kurar, yani `onCreate` yolundan geçer ve şemayı her zaman tam görür; kusur yalnız "önceki
/// sürümü kurulu olan cihazda" görünür. Bu dosya tam olarak o yoldan geçer.
///
/// BU ADIMDA SESSİZLİĞİN BEDELİ NEYDİ: kolon eklenmezse `sync_meta`ya dokunan HER sorgu
/// `no such column: sync_meta.api_version` ile patlar — ve `sync_meta` oturum token'ını,
/// abonelik önbelleğini ve senkron imlecini taşıyan tek satırlık tablodur. Yani eksik bir
/// GÖSTERİM alanı, uygulamayı açılamaz hâle getirirdi.
void main() {
  test(
      'v15→v16: sync_meta.api_version sahadaki cihaza EKLENİR, oturum/imleç verisi aynen durur '
      've sync_meta okuması patlamaz', () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_v15v16_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // 1) Güncel şemayla kur + korunması gereken veriyi yaz. `sync_meta` tek satırdır (id=1) ve
    //    `beforeOpen` onu zaten yaratır; burada gerçek bir cihazdaki gibi DOLDURUYORUZ.
    final v16 = AppDatabase(NativeDatabase(file));
    await (v16.update(v16.syncMeta)..where((t) => t.id.equals(1))).write(const SyncMetaCompanion(
      lastPulledSeq: Value(4821),
      authToken: Value('bearer-token-sahada'),
      userName: Value('Ali Usta'),
      tenantCode: Value('ASP-4213'),
      subscriptionStatus: Value('active'),
      apiVersion: Value('1.0.0'),
    ));
    await v16.close();

    // 2) Dosyayı v15'e GERİ SAR: kolonu düşür, damgayı 15 yap. Sahadaki bir telefonun bu
    //    vardiyadan ÖNCEKİ diskteki hâli birebir budur.
    final raw = sqlite3.open(file.path);
    raw.execute('ALTER TABLE sync_meta DROP COLUMN api_version');
    raw.execute('PRAGMA user_version = 15');
    raw.close();

    // 3) Yeniden aç → onUpgrade(from: 15, to: 16) koşmalı.
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) file.deleteSync();
    });

    final kolonlar = await db
        .customSelect('PRAGMA table_info(sync_meta)')
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toSet());
    expect(kolonlar, contains('api_version'), reason: 'api_version migration ile eklenmeliydi');

    // ⭐ ASIL İDDİA: `sync_meta` okuması PATLAMIYOR. Düzeltme olmadan bu satır
    // `SqliteException(1): no such column: sync_meta.api_version` ile kırmızı yanardı — ve
    // uygulama bu tabloyu açılışta okuduğu için arıza "hiç açılmıyor" kılığında görünürdü.
    final meta = await db.syncState();

    // Additif migration: oturum ve imleç AYNEN durmalı. (Bunlar kaybolursa bayi yeniden giriş
    // yapmak zorunda kalır ve cihaz TAM SNAPSHOT çeker — offline yazımların kaderi riske girer.)
    expect(meta.lastPulledSeq, 4821);
    expect(meta.authToken, 'bearer-token-sahada');
    expect(meta.tenantCode, 'ASP-4213');
    expect(meta.subscriptionStatus, 'active');

    // Kolonun kendisi BOŞ doğar — yükseltme uydurmaz. Değer ilk senkron turunda sunucudan iner.
    expect(meta.apiVersion, isNull,
        reason: 'yükseltme bir sürüm numarası UYDURAMAZ; sunucu söyleyene kadar bilinmiyordur');
  });
}
