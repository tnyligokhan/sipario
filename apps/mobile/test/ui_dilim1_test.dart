import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/auth_api.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/theme/components/overlays.dart';
import 'package:sipario/screens/customers/customer_form_screen.dart' show normalizePhoneTR;
import 'package:sipario/screens/customers/customer_list_screen.dart';
import 'package:sipario/screens/login_screen.dart';
import 'package:sipario/screens/money.dart';
import 'support/yetki_yardimcilari.dart';

/// Dilim 1 UI testleri: telefon normalizasyonu, para biçimi, giriş doğrulaması, müşteri listesi/arama.
class _OkAuthApi implements AuthApi {
  _OkAuthApi(this.baseUrl);
  @override
  final String baseUrl;

  @override
  Future<LoginResult> login({
    required String tenantCode,
    required String username,
    required String password,
    required String deviceId,
  }) async {
    return LoginResult(
        token: 't', userId: 'u1', userName: 'P', userRole: 'patron', tenantName: 'B');
  }

  @override
  Future<void> logout(String token) async {}

  /// Bu testlerin konusu değil; yalnız sözleşmeyi tamamlar (`implements AuthApi`).
  @override
  Future<bool> parolaDogrula({required String token, required String password}) async => true;

  @override
  Future<String> parolaSifirla({
    required String tenantCode,
    required String username,
  }) async =>
      'ok';
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

  group('girisHatalari (tasarım s-giris.jsx doğrulamaları — ekrandan bağımsız)', () {
    test('geçerli üçlü hatasızdır', () {
      expect(
        girisHatalari(firma: 'merkezbayi', kullanici: 'mehmet.usta', parola: 'sifre'),
        isEmpty,
      );
    });

    test('firma kodu: 3 haneden kısa ya da yasak karakter reddedilir', () {
      expect(girisHatalari(firma: 'ab', kullanici: 'patron', parola: 'sifre'),
          containsPair('firma', 'Geçersiz firma kodu (en az 3 harf/rakam)'));
      // Nokta ve alt çizgi firma kodunda YOKtur (yalnız harf/rakam/tire) — kullanıcı adından
      // farkı budur; tasarımın iki ayrı regex'i var, ikisi de burada sabitlenir.
      expect(girisHatalari(firma: 'merkez.bayi', kullanici: 'patron', parola: 'sifre'),
          contains('firma'));
      expect(girisHatalari(firma: 'merkez-bayi', kullanici: 'patron', parola: 'sifre'), isEmpty);
    });

    test('kullanıcı adı: e-posta artık GEÇERSİZDİR', () {
      // Giriş yüzeyi e-postadan kullanıcı adına taşındı; "@" içeren giriş sessizce
      // kabul edilirse eski alışkanlık sunucuda 422'ye çarpar ve sebebi anlaşılmaz.
      expect(girisHatalari(firma: 'merkezbayi', kullanici: 'a@b.com', parola: 'sifre'),
          containsPair('kullanici', 'Geçersiz kullanıcı adı (en az 3 harf/rakam)'));
    });

    test('parola: boş ile kısa AYRI mesaj verir', () {
      expect(girisHatalari(firma: 'merkezbayi', kullanici: 'patron', parola: ''),
          containsPair('parola', 'Parola boş bırakılamaz'));
      expect(girisHatalari(firma: 'merkezbayi', kullanici: 'patron', parola: 'abc'),
          containsPair('parola', 'Parola en az 4 karakter'));
    });

    test('sunucu adresi yalnız "Gelişmiş" AÇIKKEN ve doluyken sınanır', () {
      const gecerli = {'firma': 'merkezbayi', 'kullanici': 'patron', 'parola': 'sifre'};
      // Gelişmiş kapalıyken alandaki çöp giriş yolunu tıkamaz (alan zaten görünmüyor).
      expect(
        girisHatalari(
            firma: gecerli['firma']!,
            kullanici: gecerli['kullanici']!,
            parola: gecerli['parola']!,
            sunucu: 'çöp değer'),
        isEmpty,
      );
      expect(
        girisHatalari(
            firma: gecerli['firma']!,
            kullanici: gecerli['kullanici']!,
            parola: gecerli['parola']!,
            sunucu: 'çöp değer',
            gelismis: true),
        containsPair('sunucu', 'Geçersiz sunucu adresi'),
      );
      // Boş bırakmak meşrudur: varsayılan adres kullanılır.
      expect(
        girisHatalari(
            firma: gecerli['firma']!,
            kullanici: gecerli['kullanici']!,
            parola: gecerli['parola']!,
            sunucu: '',
            gelismis: true),
        isEmpty,
      );
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
      await tester.tap(find.text('Giriş Yap'));
      await tester.pump();

      // Tasarım (s-giris.jsx) üç alanı da birlikte doğrular ve her birinin altına yazar.
      expect(find.text('Firma kodu boş bırakılamaz'), findsOneWidget);
      expect(find.text('Kullanıcı adı boş bırakılamaz'), findsOneWidget);
      expect(find.text('Parola boş bırakılamaz'), findsOneWidget);
      expect(loggedIn, isFalse);
    });

    testWidgets('geçerli girişte onLoggedIn tetiklenir ve oturum kalıcılanır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var loggedIn = false;
      final session = Session(db, apiFactory: (b) => _OkAuthApi(b));

      await tester.pumpWidget(MaterialApp(
          home: LoginScreen(session: session, onLoggedIn: () => loggedIn = true)));
      // SİPARİO 3.0: alanlar `SipInput` (bir TextField) — Form/FormState kullanılmıyor.
      // Doğrulama ekranın kendi hata alanlarıyla ve `SipInput(hata:)` ile yapılıyor; hata
      // metninin yerleşimi InputDecorator'ınkiyle tutmadığı için bu bilinçli bir seçim.
      // Sıra tasarımdaki gibi: 0 = firma kodu, 1 = kullanıcı adı, 2 = parola
      // (sunucu adresi yalnız "gelişmiş" açıkken eklenir).
      await tester.enterText(find.byType(TextField).at(0), 'merkezbayi');
      await tester.enterText(find.byType(TextField).at(1), 'mehmet.usta');
      await tester.enterText(find.byType(TextField).at(2), 'sifre123');
      await tester.tap(find.text('Giriş Yap'));
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

    test('boş sorgu tüm arşivsizleri EN SON KAYDEDİLEN ÜSTTE döner', () async {
      // Sıra 2026-08-06'da ADA GÖREden kayıt sırasına çevrildi (Türkçe harfler BINARY
      // collation'da ASCII'den sonra dizildiği için liste rasgele görünüyordu). Kurulumda
      // 'Mehmet Demir' sonra eklendiği için o üstte. Ayrıntılı kilit: musteri_siralama_test.dart.
      expect(await namesFor(''), ['Mehmet Demir', 'Ayşe Yılmaz']);
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
        final repo = CustomerRepository(db);
        await repo.create(name: 'Ayşe Yılmaz'); // bakiye 0 → çip ÇİZİLMEZ
        final borclu = await repo.create(name: 'Borçlu Bahri');
        await LedgerRepository(db).borcEkle(borclu, 34000);
      });

      await tester.pumpWidget(MaterialApp(home: CustomerListScreen(db: db, writable: true, yetki: tamYetki)));
      // İlk emit gerçek zamanda gelir; runAsync içinde bekle, sonra kareyi çiz.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Borçlu Bahri'), findsOneWidget);

      // SİPARİO 3.0 bakiye dili: liste satırında çip YALNIZCA bakiye ≠ 0 iken çizilir.
      // "0,00 ₺" gösterip her satırı gürültüye boğmak yerine, bakışın borçluya gitmesi istenir.
      // (Eski tasarım her müşteride rozet gösteriyordu — bu test o yüzden değişti.)
      expect(find.text('340,00 ₺'), findsOneWidget, reason: 'borçlunun çipi görünmeli');
      expect(find.text('0,00 ₺'), findsNothing,
          reason: 'bakiyesi temiz müşteride çip hiç çizilmez');

      // Kapanış temizliği: ağacı boşalt + sahte saati ilerlet (bekleyen widget zamanlayıcıları
      // sönsün — '!timersPending'). db BİLEREK kapatılmaz: akış abonelikli drift db'sini widget-test
      // zonunda kapatmak asılı kalıyor (bu vardiyada 10 dk zaman aşımıyla yaşandı); bellek-içi db
      // süreç sonunda gider.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('salt-okunur kipte müşteri ekleme engellenir', (tester) async {
      // SİPARİO 3.0 ile bu ekranın ekleme yolu DEĞİŞTİ; test o yüzden yeniden yazıldı:
      //  • FloatingActionButton kalktı → ekleme üst çubuktaki "Yeni" metin düğmesinde
      //    (FAB artık alt navigasyonun ortasında ve kabuğa ait).
      //  • CustomerFormScreen widget'ı kalktı → form bir SHEET (`musteriEkleSheet`).
      //  • SnackBar kalktı → uyarı `SipToast` (Overlay üzerinde yüzen hap).
      // Sınanan DAVRANIŞ aynı kaldı: salt-okunur kipte form AÇILMAZ ve kullanıcı uyarılır.
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(home: CustomerListScreen(db: db, writable: false, yetki: tamYetki)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.tap(find.text('Yeni'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
      // Form sheet'i açılmamalı — başlığı ağaçta olmamalı.
      expect(find.text('Yeni müşteri'), findsNothing);
      expect(find.byType(TextField), findsOneWidget,
          reason: 'yalnız arama alanı olmalı; form alanları açılmamış olmalı');

      // Toast'ın 2,2 sn'lik sayacı sönsün + ağaç boşalsın (üstteki teste bak; db bilerek kapatılmaz).
      await tester.pump(const Duration(seconds: 5));
      SipToast.temizle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
