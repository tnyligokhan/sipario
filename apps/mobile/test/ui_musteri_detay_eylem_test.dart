// MÜŞTERİ DETAYI — Ara · WhatsApp · Konum gerçekten harici uygulama açıyor mu?
//
// SAHA HATASI (2026-07-28): bu üç düğme yalnız toast basıyordu ("Ayşe aranıyor…") ve hiçbir şey
// açmıyordu. Bu, 2026-07-27'de SİPARİŞ satırında düzeltilen hatanın ATLANMIŞ İKİZİYDİ: o gün
// `musteri_eylemleri.dart` yazıldı, sipariş tarafı ona bağlandı, müşteri detayı unutuldu.
// Kod incelemesi bunu görmedi çünkü ekranda "bozuk" bir şey yok — düğme var, dokunuş var,
// hatta bir de mesaj çıkıyor. Yalnız asıl iş yapılmıyor.
//
// DERS: eylemin ÇAĞRILDIĞINI değil, HARİCİ UYGULAMANIN AÇILDIĞINI sınamak gerekir. Bu dosya
// `uriAcici` dikişini sahteleyip gerçekten hangi URI'nin denendiğine bakar.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/orders/musteri_eylemleri.dart';
import 'package:sipario/theme/app_theme.dart';
import 'support/yetki_yardimcilari.dart';

class SahteAcici {
  SahteAcici({this.acilir = true});

  final bool acilir;
  final List<Uri> denenen = [];

  Future<bool> ac(Uri u) async {
    denenen.add(u);
    return acilir;
  }
}

Future<bool> _hicbirSey(Uri _) async => false;

void main() {
  late SahteAcici sahte;

  setUp(() {
    sahte = SahteAcici();
    uriAcici = sahte.ac;
  });

  // Sızan sahte, sonraki testte sessizce yanlış sonuç üretir.
  tearDown(() => uriAcici = _hicbirSey);

  Future<String> musteriKur(
    AppDatabase db,
    WidgetTester tester, {
    bool telefon = true,
    bool konum = true,
  }) async {
    late String id;
    await tester.runAsync(() async {
      id = await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        phones: [
          if (telefon) PhoneInput(phoneE164: '+905324152290', isPrimary: true),
        ],
        addresses: [
          AddressInput(
            addressText: 'Lara Cad. no:12',
            lat: konum ? 36.8969 : null,
            lng: konum ? 30.7133 : null,
            isPrimary: true,
          ),
        ],
      );
    });
    return id;
  }

  Future<void> ekranaKoy(WidgetTester tester, AppDatabase db, String id) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: SipTheme.acik(),
      home: CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> kapat(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('Ara telefon uygulamasını AÇAR (toast değil)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await musteriKur(db, tester);
    await ekranaKoy(tester, db, id);

    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();

    // ARIZANIN TA KENDİSİ: bu liste düne kadar BOŞ kalırdı.
    expect(sahte.denenen.single.toString(), 'tel:+905324152290');
    // Başarıda toast BASILMAZ — hedef uygulama zaten öne gelir.
    expect(find.textContaining('aranıyor'), findsNothing);

    await kapat(tester);
  });

  testWidgets('WhatsApp önce uygulamayı dener, numara +90 ile gider', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await musteriKur(db, tester);
    await ekranaKoy(tester, db, id);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    // Ham "0532…" ile wa.me sessizce BOŞ sayfa açar — bu yüzden numara normalleşmeli.
    expect(sahte.denenen.single.toString(), 'whatsapp://send?phone=905324152290');

    await kapat(tester);
  });

  testWidgets('Konum haritayı kayıtlı koordinatla açar', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await musteriKur(db, tester);
    await ekranaKoy(tester, db, id);

    await tester.tap(find.text('Konum'));
    await tester.pumpAndSettle();

    final u = sahte.denenen.single.toString();
    expect(u, startsWith('geo:36.896900,30.713300'));
    // Etiket müşterinin adıdır: harita uygulamasında pin "Ayşe Yılmaz" diye görünür.
    expect(u, contains('Ay%C5%9Fe%20Y%C4%B1lmaz'));

    await kapat(tester);
  });

  testWidgets('telefonsuz müşteride uygulama açılmaz, NEDEN söylenir', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await musteriKur(db, tester, telefon: false);
    await ekranaKoy(tester, db, id);

    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();

    expect(sahte.denenen, isEmpty, reason: 'boşuna çevirici açılmamalı');
    // Sessiz ölü düğme "uygulama bozuk" dedirtir; dokunuş nedenini söylemeli.
    expect(find.text('Müşterinin kayıtlı telefonu yok'), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('konumsuz müşteride harita açılmaz, NEDEN söylenir', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await musteriKur(db, tester, konum: false);
    await ekranaKoy(tester, db, id);

    await tester.tap(find.text('Konum'));
    await tester.pumpAndSettle();

    expect(sahte.denenen, isEmpty);
    expect(find.text('Konum kayıtlı değil — müşteri detayından alın'), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('hedef uygulama yoksa ÇÖKMEZ, iki aday da denenir', (tester) async {
    sahte = SahteAcici(acilir: false);
    uriAcici = sahte.ac;
    final db = AppDatabase(NativeDatabase.memory());
    final id = await musteriKur(db, tester);
    await ekranaKoy(tester, db, id);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    expect(sahte.denenen.length, 2, reason: 'whatsapp:// sonra wa.me denenmeli');
    expect(find.text('WhatsApp açılamadı — telefonda yüklü değil'), findsOneWidget);

    await kapat(tester);
  });
}
