import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/auth_api.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/screens/customers/customer_form_screen.dart';
import 'package:sipario/screens/customers/customer_list_screen.dart';
import 'package:sipario/screens/login_screen.dart';
import 'package:sipario/screens/money.dart';

/// Dilim 1 UI testleri: telefon normalizasyonu, para biçimi, giriş doğrulaması, müşteri listesi/arama.
class _OkAuthApi implements AuthApi {
  _OkAuthApi(this.baseUrl);
  @override
  final String baseUrl;

  @override
  Future<LoginResult> login(
      {required String email, required String password, required String deviceId}) async {
    return LoginResult(
        token: 't', userId: 'u1', userName: 'P', userRole: 'patron', tenantName: 'B');
  }

  @override
  Future<void> logout(String token) async {}
}

void main() {
  group('normalizePhoneTR', () {
    test('üç yazım da aynı E.164\'e normalize olur (DECISIONS: son 10 hane tekil)', () {
      expect(normalizePhoneTR('05321112233'), '+905321112233');
      expect(normalizePhoneTR('5321112233'), '+905321112233');
      expect(normalizePhoneTR('+90 532 111 22 33'), '+905321112233');
      expect(normalizePhoneTR('0532 111-22-33'), '+905321112233');
    });

    test('geçersiz numaralar reddedilir', () {
      expect(normalizePhoneTR('12345'), isNull);
      expect(normalizePhoneTR(''), isNull);
      expect(normalizePhoneTR('00321112233'), isNull); // ulusal numara 0 ile başlayamaz
    });
  });

  group('formatKurus', () {
    test('int kuruş → TR para biçimi (kayan nokta YOK)', () {
      expect(formatKurus(0), '0,00 ₺');
      expect(formatKurus(150), '1,50 ₺');
      expect(formatKurus(123456), '1.234,56 ₺');
      expect(formatKurus(-2500), '−25,00 ₺');
    });
  });

  group('LoginScreen', () {
    testWidgets('boş form doğrulama hatası verir, giriş çağrılmaz', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var loggedIn = false;
      final session = Session(db, apiFactory: (b) => _OkAuthApi(b));

      await tester.pumpWidget(MaterialApp(
          home: LoginScreen(session: session, onLoggedIn: () => loggedIn = true)));
      await tester.tap(find.text('Giriş yap'));
      await tester.pump();

      expect(find.text('Geçerli bir e-posta girin'), findsOneWidget);
      expect(find.text('Parola gerekli'), findsOneWidget);
      expect(loggedIn, isFalse);
    });

    testWidgets('geçerli girişte onLoggedIn tetiklenir ve oturum kalıcılanır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var loggedIn = false;
      final session = Session(db, apiFactory: (b) => _OkAuthApi(b));

      await tester.pumpWidget(MaterialApp(
          home: LoginScreen(session: session, onLoggedIn: () => loggedIn = true)));
      await tester.enterText(find.byType(TextFormField).at(0), 'patron@bayi.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'sifre123');
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      expect(loggedIn, isTrue);
      expect((await db.syncState()).authToken, 't');
    });

    testWidgets('ekranda kayıt/fiyat/abonelik çağrısı YOKTUR (mağaza kuralı)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final session = Session(db, apiFactory: (b) => _OkAuthApi(b));

      await tester.pumpWidget(
          MaterialApp(home: LoginScreen(session: session, onLoggedIn: () {})));

      for (final yasak in ['Kayıt', 'Kaydol', 'Üye ol', 'Abone', 'Satın al', 'Fiyat', '₺']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mobilde gösterilemez');
      }
    });
  });

  group('watchCustomers (arama sorgusu — saf async, drift akışı .first ile)', () {
    // NOT: Drift watch() akışları GERÇEK zamanda emit eder; testWidgets'ın sahte-zaman kilidinde
    // "arama sonrası yeni akışın emit'ini bekle" deseni güvenilmez (StreamBuilder eski veriyi korur,
    // gecikme yarışı 10 dk zaman aşımına dönebilir — bu vardiyada yaşandı). Sorgu mantığı bu yüzden
    // ekrandan bağımsız watchCustomers()'ta ve burada saf async testle sınanır.
    late AppDatabase db;
    late CustomerRepository repo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = CustomerRepository(db);
      await repo.create(
          name: 'Ayşe Yılmaz',
          phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)]);
      await repo.create(name: 'Mehmet Demir');
    });

    tearDown(() => db.close());

    Future<List<String>> namesFor(String query) async =>
        (await watchCustomers(db, query).first).map((c) => c.name).toList();

    test('boş sorgu tüm arşivsizleri ada göre sıralı döner', () async {
      expect(await namesFor(''), ['Ayşe Yılmaz', 'Mehmet Demir']);
    });

    test('ada göre arama filtreler', () async {
      expect(await namesFor('Ayşe'), ['Ayşe Yılmaz']);
      expect(await namesFor('Demir'), ['Mehmet Demir']);
      expect(await namesFor('yok böyle biri'), isEmpty);
    });

    test('telefona göre arama: farklı yazımlar aynı müşteriyi bulur (son-10 kuralı)', () async {
      expect(await namesFor('0532 111'), ['Ayşe Yılmaz']);
      expect(await namesFor('532111'), ['Ayşe Yılmaz']);
      expect(await namesFor('1122'), ['Ayşe Yılmaz']); // orta parça da eşleşir (LIKE)
      expect(await namesFor('0999'), isEmpty);
    });

    test('arşivlenen müşteri listede görünmez', () async {
      final id = (await watchCustomers(db, 'Mehmet').first).single.id;
      await repo.archive(id);
      expect(await namesFor(''), ['Ayşe Yılmaz']);
    });
  });

  group('CustomerListScreen (widget — yalnız ilk çizim; akış zamanlaması için üstteki nota bak)', () {
    testWidgets('ilk çizim müşterileri ve bakiyeyi gösterir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      });

      await tester.pumpWidget(MaterialApp(home: CustomerListScreen(db: db, writable: true)));
      // İlk emit gerçek zamanda gelir; runAsync içinde bekle, sonra kareyi çiz.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('0,00 ₺'), findsOneWidget);

      // Kapanış temizliği: ağacı boşalt + sahte saati ilerlet (bekleyen widget zamanlayıcıları
      // sönsün — '!timersPending'). db BİLEREK kapatılmaz: akış abonelikli drift db'sini widget-test
      // zonunda kapatmak asılı kalıyor (bu vardiyada 10 dk zaman aşımıyla yaşandı); bellek-içi db
      // süreç sonunda gider.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('salt-okunur kipte müşteri ekleme engellenir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(home: CustomerListScreen(db: db, writable: false)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
      expect(find.byType(CustomerFormScreen), findsNothing);

      // SnackBar'ın gizlenme sayacı sönsün + ağaç boşalsın (üstteki teste bak; db bilerek kapatılmaz).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
