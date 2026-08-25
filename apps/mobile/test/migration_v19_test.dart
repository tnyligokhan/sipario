// `isNull` hem drift'te hem matcher'da tanımlı; burada matcher'ınki isteniyor.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';

import 'support/migration_yardimcilari.dart';

/// v18→v19 — "BENİ HATIRLA" (`sync_meta.saved_tenant_code` + `saved_username`, 2026-08-11).
///
/// `migration_v16_test.dart` ile AYNI aileden ve aynı arızaya karşı: sahadaki cihaz `onUpgrade`
/// yolundan geçer, `NativeDatabase.memory()` kuran yüzlerce test ise `onCreate` yolundan — ve
/// orada şema her zaman tamdır. Bu dosya "önceki sürümü kurulu olan telefon"u kurar.
///
/// BU ADIMDA SESSİZLİĞİN BEDELİ: iki kolon da `sync_meta`dadır ve Drift o tabloyu AÇIK kolon
/// listesiyle sorgular — biri eksikse `no such column` ile TÜM `sync_meta` okuması patlar.
/// O tablo oturum token'ını taşır, yani arıza "giriş ekranı açılmıyor" kılığında görünür;
/// eksik olan yalnızca bir KOLAYLIK alanı olsa bile bedeli uygulamanın tamamıdır.
void main() {
  test(
      'v18→v19: saved_tenant_code/saved_username sahadaki cihaza EKLENİR, oturum ve imleç aynen '
      'durur, iki alan NULL doğar ("hatırlama kapalı") ve sonradan yazılabilir', () async {
    final db = await eskiCihaziYukselt(
      etiket: 'v18v19',
      surum: 18,
      veriYaz: (v19) => (v19.update(v19.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(
        lastPulledSeq: Value(9312),
        authToken: Value('bearer-token-sahada'),
        userName: Value('Ali Usta'),
        tenantCode: Value('ASP-4213'),
        routeCredits: Value(34),
        subscriptionStatus: Value('active'),
      )),
      geriSar: [
        'ALTER TABLE sync_meta DROP COLUMN saved_tenant_code',
        'ALTER TABLE sync_meta DROP COLUMN saved_username',
      ],
    );

    final kolonSeti = await kolonlar(db, 'sync_meta');
    expect(kolonSeti, containsAll(['saved_tenant_code', 'saved_username']));

    // ⭐ ASIL İDDİA: `sync_meta` okuması PATLAMIYOR (düzeltme olmadan bu satır kırmızı yanar).
    final meta = await db.syncState();

    // Additif: oturum ve imleç durur. Kaybolsalardı bayi yeniden giriş yapar ve cihaz TAM
    // snapshot çeker — bekleyen offline yazımların kaderi riske girerdi.
    expect(meta.lastPulledSeq, 9312);
    expect(meta.authToken, 'bearer-token-sahada');
    expect(meta.tenantCode, 'ASP-4213');
    expect(meta.routeCredits, 34);

    // Yeni alanlar BOŞ doğar: "hatırlama kapalı" varsayılandır. Sunucu sahipli `tenantCode`u
    // buraya KOPYALAMAK yanlış olurdu — kullanıcı hatırlamayı hiç açmamışken giriş ekranı
    // kendiliğinden dolar, üstelik kapatması da imkânsız hâle gelirdi.
    expect(meta.savedTenantCode, isNull);
    expect(meta.savedUsername, isNull);

    // Ve kolonlar gerçekten YAZILABİLİR (giriş ekranı bu iki alanı doldurur).
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(const SyncMetaCompanion(
      savedTenantCode: Value('ASP-4213'),
      savedUsername: Value('ali'),
    ));
    final sonra = await db.syncState();
    expect(sonra.savedUsername, 'ali');
    expect(sonra.authToken, 'bearer-token-sahada', reason: 'yazım diğer alanları ezmedi');

    await semaTamOlmali(db, gerekce: 'v18 damgalı cihaz bugüne yükseltildi.');
  });
}
