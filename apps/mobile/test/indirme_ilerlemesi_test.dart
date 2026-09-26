// VERİ İNDİRME İLERLEMESİ (kullanıcı isteği 2026-09-26: "Tüm verileri çekme kısmında verileri
// çekerken ne kadar kaldığını gösteren bir şey olmalı").
//
// Üç şey kilitlenir: (1) motor snapshot sayfalarını saydıkça ilerlemeyi bildirir ve toplamı
// ilk sayfadan alır, (2) tur yarıda koparsa gösterge "sürüyor"da ASILI KALMAZ, (3) ekran toplam
// biliniyorsa yüzde, bilinmiyorsa yalnız inen sayıyı yazar — uydurma yüzde yok.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/isletme/ayarlar/uygulama_ayarlari_ekrani.dart';
import 'package:sipario/sync/indirme_ilerlemesi.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';
import 'package:sipario/theme/app_theme.dart';

import 'support/fake_sync_api.dart';

/// İlk sayfadan sonra ağı kopan sunucu.
class _KopanApi extends FakeSyncApi {
  @override
  Future<PullResponse> pull({required int since, int limit = 500, String? snapshotImleci}) {
    if (pullQueue.isEmpty) throw const SocketExceptionBenzeri();
    return super.pull(since: since, limit: limit, snapshotImleci: snapshotImleci);
  }
}

class SocketExceptionBenzeri implements Exception {
  const SocketExceptionBenzeri();
}

PullResponse _sayfa(int adet, {required bool devamVar, int? toplam, int bas = 0}) => PullResponse(
      mode: 'snapshot',
      cursor: 900,
      hasMore: devamVar,
      currentSeq: 900,
      snapshotImleci: devamVar ? 'customer:m${bas + adet}' : null,
      snapshotToplam: toplam,
      entities: {
        'customer': [
          for (var i = bas; i < bas + adet; i++)
            {'id': 'm$i', 'name': 'Müşteri $i', 'updated_occurred_at': '2026-09-26T10:00:00Z'},
        ],
      },
    );

void main() {
  group('IndirmeIlerlemesi', () {
    test('toplam bilinmiyorsa oran yok — belirsiz çubuk', () {
      final i = IndirmeIlerlemesi()..basla(null);
      i.sayfaIslendi(500);
      expect(i.oran, isNull);
      expect(i.inen, 500);
    });

    test('oran 1’de kırpılır — toplam yaklaşıktır', () {
      final i = IndirmeIlerlemesi()..basla(10);
      i.sayfaIslendi(12);
      expect(i.oran, 1.0);
    });

    test('başlamamış ilerleme sayfa saymaz', () {
      final i = IndirmeIlerlemesi()..sayfaIslendi(5);
      expect(i.inen, 0);
      expect(i.suruyor, isFalse);
    });
  });

  group('motor ilerlemeyi bildirir', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('toplam ilk sayfadan alınır, her sayfada inen artar, sonunda biter', () async {
      final api = FakeSyncApi()
        ..pullQueue.addAll([
          _sayfa(3, devamVar: true, toplam: 7),
          _sayfa(4, devamVar: false, bas: 3),
        ]);
      final gorulen = <(int, int?)>[];
      void dinle() {
        if (indirmeIlerlemesi.suruyor) {
          gorulen.add((indirmeIlerlemesi.inen, indirmeIlerlemesi.toplam));
        }
      }

      indirmeIlerlemesi.addListener(dinle);
      addTearDown(() => indirmeIlerlemesi.removeListener(dinle));

      await SyncEngine(db, api).pull();

      expect(gorulen, [(0, 7), (3, 7), (7, 7)]);
      expect(indirmeIlerlemesi.suruyor, isFalse, reason: 'tur bitince gösterge kapanır');
    });

    test('tur yarıda koparsa gösterge asılı KALMAZ', () async {
      final api = _KopanApi()..pullQueue.add(_sayfa(3, devamVar: true, toplam: 9));

      await expectLater(SyncEngine(db, api).pull(), throwsA(isA<SocketExceptionBenzeri>()));

      expect(indirmeIlerlemesi.suruyor, isFalse);
    });
  });

  group('IndirmeGostergesi', () {
    Future<void> ciz(WidgetTester tester, IndirmeIlerlemesi i) => tester.pumpWidget(
          MaterialApp(
            theme: SipTheme.acik(),
            home: Scaffold(body: IndirmeGostergesi(ilerleme: i)),
          ),
        );

    testWidgets('indirme yokken hiçbir şey çizmez', (tester) async {
      await ciz(tester, IndirmeIlerlemesi());
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('toplam biliniyorsa inen / toplam ve yüzde yazar', (tester) async {
      final i = IndirmeIlerlemesi()..basla(31400);
      await ciz(tester, i);
      i.sayfaIslendi(3200);
      await tester.pump();

      expect(find.text('3.200 / 31.400 kayıt, yüzde 10'), findsOneWidget);
      final cubuk = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(cubuk.value, closeTo(3200 / 31400, 0.0001));
    });

    testWidgets('toplam bilinmiyorsa yalnız inen sayı, belirsiz çubuk', (tester) async {
      final i = IndirmeIlerlemesi()..basla(null);
      await ciz(tester, i);
      i.sayfaIslendi(500);
      await tester.pump();

      expect(find.text('500 kayıt indirildi'), findsOneWidget);
      final cubuk = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(cubuk.value, isNull);
    });

    testWidgets('indirme bitince gösterge kaybolur', (tester) async {
      final i = IndirmeIlerlemesi()..basla(10);
      await ciz(tester, i);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      i.bitti();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
