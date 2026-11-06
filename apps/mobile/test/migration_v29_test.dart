import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/repo/bildirim_kutusu.dart';

import 'support/migration_yardimcilari.dart';

/// v28→v29 — BİLDİRİM TEMİZLEME (`bildirimler.temizlendi_at`, 2026-09-29).
///
/// BEDELİ: kolon eksikken bildirim kutusunun iki sorgusu da (`watchHepsi`, rozet sayacı)
/// "no such column" ile düşer — ana ekranın rozeti ve bildirimler ekranı birlikte ölür.
/// Adım kapıdan ÖNCE ve koşulsuz koştuğu için sahadaki her cihazda çalışmak zorundadır.
void main() {
  test(
      'v28→v29: temizlendi_at kolonu eklenir, eski bildirimler GÖRÜNÜR kalır ve temizlenebilir',
      () async {
    final db = await eskiCihaziYukselt(
      etiket: 'v28v29',
      surum: 28,
      veriYaz: (v29) => BildirimKutusu(v29).yaz(
        const BildirimTaslagi(
          kategori: BildirimKategori.gunKapanisHatirlatma,
          baslik: 'Dün gün kapatılmadı',
          govde: 'Dünün hesabı hâlâ açık',
          kimlik: 'gunKapanisHatirlatma:gun-2026-09-28',
        ),
        occurredAtIso: '2026-09-29T09:00:00.000Z',
      ),
      geriSar: ['ALTER TABLE bildirimler DROP COLUMN temizlendi_at'],
    );

    final kutu = BildirimKutusu(db);
    expect(await kutu.watchHepsi().first, hasLength(1),
        reason: 'yükseltme öncesi bildirim temizlenmemiştir; NULL tam olarak bunu söyler');
    expect(await kutu.watchOkunmamisSayisi().first, 1);

    await kutu.hepsiniTemizle(anIso: '2026-09-29T10:00:00.000Z');
    expect(await kutu.watchHepsi().first, isEmpty);

    await semaTamOlmali(db);
  });
}
