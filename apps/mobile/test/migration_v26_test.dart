import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/bildirim_kutusu.dart';

import 'support/migration_yardimcilari.dart';

/// v25→v26 — BİLDİRİM KUTUSU (`bildirimler` tablosu, 2026-08-21).
///
/// KOLON DEĞİL TABLO EKLENDİ ve bu, migration ailesinin farklı bir dalıdır: `_addColumnIfMissing`
/// yerine `_tabloVar` + `createTable`. Adım KAPIDAN ÖNCE ve KOŞULSUZ koştuğu için her açılışta
/// çalışır; varlık kontrolü olmasaydı ikinci açılış "table already exists" ile DÜŞERDİ — yani
/// uygulama bir kez açılıp bir daha hiç açılmazdı.
///
/// BEDELİ: tablo eksikken ana ekranın rozeti (`watchOkunmamisSayisi`) "no such table" ile patlar
/// ve ANA EKRAN hiç çizilmez. Yani eksik bir tablo, ürünün ilk ekranını öldürür.
void main() {
  test(
      'v25→v26: bildirimler tablosu sahadaki cihaza EKLENİR, mevcut veri aynen durur ve kutu '
      'BOŞ doğar (geriye dönük bildirim UYDURULMAZ)', () async {
    final db = await eskiCihaziYukselt(
      etiket: 'v25v26',
      surum: 25,
      veriYaz: (v26) async {
        await v26.into(v26.customers).insert(CustomersCompanion.insert(
              id: 'm-1',
              name: 'Ayşe Yılmaz',
              updatedOccurredAt: '2026-08-20T00:00:00.000Z',
            ));
      },
      geriSar: ['DROP TABLE IF EXISTS bildirimler'],
    );

    // Yükseltmenin korumak zorunda olduğu veri yerinde.
    final musteri =
        await (db.select(db.customers)..where((t) => t.id.equals('m-1'))).getSingle();
    expect(musteri.name, 'Ayşe Yılmaz');

    // ⭐ KUTU BOŞ DOĞAR: yükseltmeden önce gösterilmiş bildirimlerin kaydı hiçbir yerde YOK.
    // Geriye dönük satır üretmek, bayiyi hiç okunmamış onlarca satırla karşılamak olurdu.
    final kutu = BildirimKutusu(db);
    expect(await kutu.watchHepsi().first, isEmpty);
    expect(await kutu.watchOkunmamisSayisi().first, 0,
        reason: 'rozet sıfır olmalı — boş bir kutu "3 okunmamış" diyemez');

    // Tablo DEKORATİF DEĞİL: gerçekten yazılabiliyor olmalı (kolonların hepsi yerinde).
    await kutu.yaz(
      const BildirimTaslagi(
        kategori: BildirimKategori.gunKapanisHatirlatma,
        baslik: '2 gün kapatılmadı',
        govde: '2 günün kasası kapatılmamış görünüyor',
        kimlik: 'gunKapanisHatirlatma:gun-2026-08-20',
        yol: 'gunsonu',
      ),
      occurredAtIso: '2026-08-21T09:00:00.000Z',
    );
    expect(await kutu.watchOkunmamisSayisi().first, 1);

    await semaTamOlmali(db);
  });
}
