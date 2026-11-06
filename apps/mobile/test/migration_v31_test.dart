import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/mesaj_sablonlari.dart';
import 'package:sipario/repo/tenant_settings_repository.dart';
import 'package:drift/drift.dart' show Value;

import 'support/migration_yardimcilari.dart';

/// v30→v31 — BİLGİLENDİRME MESAJLARI (`tenant_settings.message_templates_json`, 2026-11-06).
///
/// BEDELİ: kolon eksikken `tenant_settings` okuyan her ekran "no such column" ile düşer. Adım
/// kapıdan ÖNCE ve koşulsuz koştuğu için sahadaki her cihazda çalışmak zorundadır.
void main() {
  test('v30→v31: kolon eklenir, mevcut işletme bilgileri korunur, mesaj yazılabilir', () async {
    final db = await eskiCihaziYukselt(
      etiket: 'v30v31',
      surum: 30,
      veriYaz: (v31) =>
          TenantSettingsRepository(v31).save(businessName: const Value('Merkez Su')),
      geriSar: ['ALTER TABLE tenant_settings DROP COLUMN message_templates_json'],
    );

    final depo = TenantSettingsRepository(db);
    final satir = await depo.get();
    expect(satir!.businessName, 'Merkez Su');
    expect(satir.messageTemplatesJson, isNull, reason: 'dokunulmamış bayi varsayılan metni görür');

    await depo.mesajSablonlariGuncelle(
      (m) => m.ozelIle(const OzelMesaj(id: 'o1', baslik: 'Kampanya', metin: 'İndirim')),
    );
    expect(MesajSablonlari.coz((await depo.get())!.messageTemplatesJson).ozel, hasLength(1));

    await semaTamOlmali(db);
  });
}
