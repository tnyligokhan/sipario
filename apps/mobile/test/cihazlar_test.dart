// HESAP → CİHAZLAR — "hesabım hangi telefonlarda açık?"
//
// Ekran kullanıcı eleştirisiyle doğdu (2026-08-13): *"Hesabım sayfasının varlık amacı ne,
// hiçbir şeye yaramıyor?"* Sayfa ad/rol yazıp duruyordu — çekmecede zaten olan bilgiyi. Bu
// dosya, sayfaya varlık nedenini veren şeyi kilitler ve İKİ yanlış vaadi engeller:
//
//  1. AĞ YOKKEN BOŞ LİSTE — "hiç cihaz yok" demek, güvenlik ekranında düpedüz yalandır.
//  2. UZAKTAN OTURUM KAPATMA DÜĞMESİ — sunucuda jeton↔cihaz bağı yok; düğme bayiye kapattığını
//     sandırır, telefon çalışmaya devam eder.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/isletme/ayarlar/cihazlar_ekrani.dart';
import 'package:sipario/sync/cihaz_api.dart';

import 'support/ekran_yardimcilari.dart';

/// Oturum açmış bir cihaz kurar — ekran token ve device_id'yi `sync_meta`dan okur.
Future<AppDatabase> _oturumluDb({String cihazId = 'bu-cihaz'}) async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.into(db.syncMeta).insertOnConflictUpdate(SyncMetaCompanion(
        id: const Value(1),
        authToken: const Value('jeton'),
        deviceId: Value(cihazId),
      ));
  return db;
}

CihazApi Function(String, String) _sahte(String govde, {int kod = 200}) =>
    (baseUrl, token) => CihazApi(
          baseUrl: baseUrl,
          token: token,
          client: MockClient((_) async => http.Response(govde, kod)),
        );

void main() {
  group('cihazSonGorulmeMetni (saf kural)', () {
    final simdi = DateTime(2026, 8, 13, 12, 0);

    test('yakın zaman sözcüklerle, bir haftadan eskisi TARİHLE söylenir', () {
      expect(cihazSonGorulmeMetni(simdi.subtract(const Duration(seconds: 20)), simdi: simdi),
          'Az önce');
      expect(cihazSonGorulmeMetni(simdi.subtract(const Duration(minutes: 5)), simdi: simdi),
          '5 dk önce');
      expect(cihazSonGorulmeMetni(simdi.subtract(const Duration(hours: 3)), simdi: simdi),
          '3 sa önce');
      expect(cihazSonGorulmeMetni(simdi.subtract(const Duration(days: 2)), simdi: simdi),
          '2 gün önce');
      // Bayi güvenlik sorusunda tarihe bakar ("o telefonu ağustosta vermiştim"); "37 gün önce"
      // yazmak onu kafadan takvim hesabı yapmaya zorlardı.
      expect(cihazSonGorulmeMetni(DateTime(2026, 7, 1, 9, 30), simdi: simdi), '01.07.2026');
    });

    test('İLERİ tarihli damga "Az önce" sayılır — negatif süre yazılmaz', () {
      // Cihaz saati geri alınmışsa "−3 dk önce" yazmak veriye güveni sarsar.
      expect(cihazSonGorulmeMetni(simdi.add(const Duration(hours: 2)), simdi: simdi), 'Az önce');
    });

    test('damga yoksa UYDURULMAZ', () {
      expect(cihazSonGorulmeMetni(null, simdi: simdi), 'Son görülme bilinmiyor');
    });
  });

  group('CihazlarEkrani', () {
    testWidgets('liste çizilir; BU CİHAZ işaretli ve EN ÜSTTE', (tester) async {
      final db = await _oturumluDb(cihazId: 'b');
      final govde = jsonEncode({
        'data': [
          {
            'id': 'a',
            'platform': 'android',
            'model': 'Redmi Note 12',
            'app_version': '0.13.0',
            'last_seen_at': DateTime.now().toIso8601String(),
          },
          {
            'id': 'b',
            'platform': 'android',
            'model': 'Samsung A54',
            'app_version': '0.14.0',
            'last_seen_at': DateTime.now().toIso8601String(),
          },
        ],
      });

      await ekranaKoy(tester, CihazlarEkrani(db: db, apiFabrikasi: _sahte(govde)));

      expect(find.text('2 cihaz bu hesaba bağlı.'), findsOneWidget);
      expect(find.text('Samsung A54 · Bu cihaz'), findsOneWidget,
          reason: 'bayinin ilk sorusu "hangisi benimki" — listede aramamalı');
      expect(find.text('Redmi Note 12'), findsOneWidget);

      // SIRALAMA: bu cihaz listenin başında olmalı (sunucu son görülmeye göre sıralar).
      final buCihaz = tester.getTopLeft(find.text('Samsung A54 · Bu cihaz')).dy;
      final oteki = tester.getTopLeft(find.text('Redmi Note 12')).dy;
      expect(buCihaz, lessThan(oteki));

      await kapat(tester);
    });

    testWidgets('UZAKTAN OTURUM KAPATMA VAAT EDİLMEZ', (tester) async {
      // Sunucuda jeton ile cihaz kaydı arasında bağ yok. Bir "Oturumu kapat" düğmesi bayiye
      // kapattığını sandırır, telefon çalışmaya devam eder — güvenlik ekranında olabilecek en
      // kötü şey. BU TEST O DÜĞMENİN SESSİZCE EKLENMESİNİ ENGELLER: bağ kurulduğu gün
      // BİLEREK güncellenecek.
      final db = await _oturumluDb();
      final govde = jsonEncode({
        'data': [
          {'id': 'a', 'platform': 'android', 'model': 'Redmi', 'last_seen_at': null},
        ],
      });

      await ekranaKoy(tester, CihazlarEkrani(db: db, apiFabrikasi: _sahte(govde)));

      expect(find.text('Oturumu kapat'), findsNothing);
      expect(find.text('Çıkar'), findsNothing);
      expect(find.textContaining('yalnız gösterir'), findsOneWidget,
          reason: 'ekran ne YAPMADIĞINI söylemeli');

      await kapat(tester);
    });

    testWidgets('AĞ YOKKEN BOŞ LİSTE GÖSTERİLMEZ — hata söylenir', (tester) async {
      // Bayat/boş bir liste "eski telefonum artık bağlı değil" diye YANLIŞ bir güvenlik
      // izlenimi üretirdi. Güvenlik ekranı bilmediğini bilmediğini söylemek zorundadır.
      final db = await _oturumluDb();

      await ekranaKoy(
        tester,
        CihazlarEkrani(
          db: db,
          apiFabrikasi: (baseUrl, token) => CihazApi(
            baseUrl: baseUrl,
            token: token,
            client: MockClient((_) => Future.error(const SocketExceptionBenzeri())),
          ),
        ),
      );

      expect(find.text('Liste okunamadı'), findsOneWidget);
      expect(find.text('Kayıtlı cihaz yok'), findsNothing);
      expect(find.text('Tekrar dene'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('sunucu hata döndürürse de boş liste DEĞİL, hata gösterilir', (tester) async {
      final db = await _oturumluDb();

      await ekranaKoy(
        tester,
        CihazlarEkrani(db: db, apiFabrikasi: _sahte('{"message":"Unauthenticated."}', kod: 401)),
      );

      expect(find.text('Liste okunamadı'), findsOneWidget);
      expect(find.textContaining('HTTP 401'), findsOneWidget);

      await kapat(tester);
    });
  });
}

/// Ağ arızasını taklit eden istisna — `CihazApi` `on Exception` yakalar.
class SocketExceptionBenzeri implements Exception {
  const SocketExceptionBenzeri();
}
