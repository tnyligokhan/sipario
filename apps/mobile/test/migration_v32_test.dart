import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';

import 'support/migration_yardimcilari.dart';

/// v31→v32 — KARANTİNA ANAHTARI (`sync_meta.karantina_anahtari`, 2026-11-06).
///
/// BEDELİ: `sync_meta` her senkron turunda okunur; kolon eksik kalırsa senkronun tamamı düşer. Adım
/// kapıdan ÖNCE ve koşulsuz koştuğu için sahadaki her cihazda çalışmak zorundadır.
void main() {
  test('v31→v32: kolon boş eklenir, mevcut oturum bilgisi korunur', () async {
    final db = await eskiCihaziYukselt(
      etiket: 'v31v32',
      surum: 31,
      veriYaz: (v32) => (v32.update(v32.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(deviceId: Value('cihaz-1'))),
      geriSar: ['ALTER TABLE sync_meta DROP COLUMN karantina_anahtari'],
    );

    final meta = await db.syncState();
    expect(meta.deviceId, 'cihaz-1');
    expect(meta.karantinaAnahtari, isNull, reason: 'ilk senkron karantinayı yeniden denemeli');

    await semaTamOlmali(db);
  });
}
