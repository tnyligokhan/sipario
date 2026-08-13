// AYARLAR → TAHSİLAT ve MESAJLAR — İşletme Kimliği formundan ÇIKARILAN iki konu.
//
// NEDEN AYRI DOSYA: `ui_isletme_ayarlar_test.dart` bu iki grupla birlikte 624 satıra çıkıyordu
// (500 sınırı). Bölme rastgele değil, ekranların bölünmesiyle AYNI çizgide: bir ekran kendi
// sayfasına taşındıysa testi de kendi dosyasında yaşar.
//
// Kullanıcı eleştirisi 2026-08-13: *"İşletme Kimliği düzenleme içerisindeki bir çok şey orada
// olmasa da olur… mesaj şablonları ilerleyen zamanlarda mesaj sayısı artacak orada olmaya devam
// mı edecek! Fiş bölümü özellikle…"*

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/tenant_settings_repository.dart';
import 'package:sipario/screens/isletme/ayarlar/mesaj_sablonlari_ekrani.dart';
import 'package:sipario/screens/isletme/ayarlar/tahsilat_ayarlari_ekrani.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/ekran_yardimcilari.dart';

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  group('Tahsilat ayarları', () {
    testWidgets('IBAN ve alıcı adı kaydedilir; kimlik alanlarına DOKUNULMAZ', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = TenantSettingsRepository(db);
      await tester.runAsync(() => repo.save(businessName: const Value('Merkez Bayi')));

      await ekranaKoy(tester, TahsilatAyarlariEkrani(db: db));

      expect(find.text('IBAN ALICI ADI'), findsOneWidget);

      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(0), 'TR33 0006 1005 1978 6457 8413 26');
      await tester.enterText(alanlar.at(1), 'Mehmet Yılmaz');
      await tester.pump();
      await dokun(tester, find.text('Kaydet'));

      final satir = await tester.runAsync(() => repo.get());
      // Saklama biçimi TEK: boşluksuz, büyük harf.
      expect(satir!.iban, 'TR330006100519786457841326');
      expect(satir.ibanOwnerName, 'Mehmet Yılmaz');
      expect(satir.businessName, 'Merkez Bayi', reason: 'kimlik alanı bu ekrandan silinemez');

      await kapat(tester);
    });

    testWidgets('geçersiz IBAN kaydı ENGELLER — hata formda söylenir', (tester) async {
      // Yanlış IBAN sessiz bir hatadır: mesaj gider, para gelmez, kimse nedenini bilmez.
      final db = AppDatabase(NativeDatabase.memory());
      final repo = TenantSettingsRepository(db);

      await ekranaKoy(tester, TahsilatAyarlariEkrani(db: db));

      await tester.enterText(find.byType(TextField).at(0), 'TR33 0006 1005 1978 6457 8413 27');
      await tester.pump();
      await dokun(tester, find.text('Kaydet'));

      expect(find.textContaining('IBAN geçersiz'), findsOneWidget);
      expect(await tester.runAsync(() => repo.get()), isNull,
          reason: 'geçersiz değer kaydedilmemeli');

      await kapat(tester);
    });

    testWidgets('FİŞ ALANI PASİF ve "Çok yakında" işaretli', (tester) async {
      // Kullanıcı kararı 2026-08-13. `receipt_note` kolonu var, senkron taşıyor — ama onu
      // OKUYAN hiçbir yer yok: uygulamada fiş/teslim belgesi diye bir çıktı üretilmiyor. Alan
      // normal görünümde kaldığı sürece ürün tutmayacağı bir söz veriyordu.
      //
      // BU TEST GERİ AÇILMAYI ENGELLER: fiş özelliği gelince alan bilinçli olarak açılacak ve
      // bu test o gün BİLEREK güncellenecek.
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, TahsilatAyarlariEkrani(db: db));

      expect(find.text('Çok yakında'), findsOneWidget);
      expect(find.text('Fiş Alt Notu'), findsOneWidget,
          reason: 'bölüm görünür kalır — özellik geliyor, kaldırılmıyor');

      final fisAlani = find.widgetWithText(SipInput, 'Teslim fişi özelliğiyle birlikte açılacak');
      expect(tester.widget<SipInput>(fisAlani).aktif, isFalse);

      await kapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  group('Mesaj şablonları', () {
    testWidgets('liste şablonu ve durumunu gösterir; düzenleme kaydeder', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = TenantSettingsRepository(db);

      await ekranaKoy(tester, MesajSablonlariEkrani(db: db));

      expect(find.text('Borç Hatırlatma'), findsOneWidget);
      expect(find.text('Varsayılan metin'), findsOneWidget,
          reason: 'bayi "ben bunu değiştirmiş miydim" sorusunu listeden cevaplayabilmeli');

      await dokun(tester, find.text('Borç Hatırlatma'));

      // Bayi yer tutucuları EZBERLEMEK zorunda kalmamalı — ekranda çip olarak dururlar.
      expect(find.text('Hatırlatma Mesajı'), findsOneWidget);
      expect(find.text('Müşteri adı'), findsOneWidget);
      expect(find.text('IBAN + alıcı'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Sayın ');
      await tester.pump();
      // Çip: imleç (enterText sonrası metnin SONUNDA) konumuna jeton eklenir.
      await dokun(tester, find.text('Müşteri adı'));
      await dokun(tester, find.text('Kaydet'));

      final satir = await tester.runAsync(() => repo.get());
      expect(satir!.reminderTemplate, 'Sayın *musteriadi*');

      await kapat(tester);
    });

    testWidgets('şablonu boş bırakmak varsayılana döner — null yazılır, boş dize değil',
        (tester) async {
      // null ile boş dize AYRI şeyler olsaydı, boşaltılan şablon "özel metin var ama boş" diye
      // okunur ve borçluya BOŞ bir WhatsApp mesajı hazırlanırdı.
      final db = AppDatabase(NativeDatabase.memory());
      final repo = TenantSettingsRepository(db);
      await tester.runAsync(() => repo.save(reminderTemplate: const Value('Eski metin')));

      await ekranaKoy(tester, MesajSablonlariEkrani(db: db));
      expect(find.text('Özel metin'), findsOneWidget);

      await dokun(tester, find.text('Borç Hatırlatma'));
      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      await dokun(tester, find.text('Kaydet'));

      expect((await tester.runAsync(() => repo.get()))!.reminderTemplate, isNull);

      await kapat(tester);
    });
  });
}
