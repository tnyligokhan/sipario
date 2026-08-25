// GİRİŞ EKRANI — parola göster/gizle + "Beni hatırla" (2026-08-11 kullanıcı isteği).
//
// İki özelliğin de kendine özgü bir SESSİZ BOZULMA biçimi var ve testler asıl olarak onları
// kovalıyor:
//
//  • Parola gözü: `obscureText` bir TextField ALANIDIR, ekranda görünmez. İkon dönse bile alan
//    gizli kalırsa hiçbir şey çökmez, hiçbir hata çıkmaz — bayi düğmeye basar ve noktalara
//    bakmaya devam eder. O yüzden iddia ikonun kendisine DEĞİL alanın durumuna bakar.
//
//  • Beni hatırla: kutu işaretlenir, giriş yapılır, hiçbir hata görünmez ve alan diske hiç
//    yazılmamıştır. Bu, bu depoda dört kez ödenmiş "tanımlı ama bağlı değil" deseninin
//    aynısıdır (DECISIONS 2026-08-10). İddia bu yüzden EKRANDAN DEĞİL DİSKTEN okur.

// `show Value` DAR TUTULUYOR: drift `isNull`/`isNotNull` adlarını da dışa veriyor ve düz bir
// import matcher'ınkilerle çakışıp dosyayı DERLENMEZ yapıyor (bu depoda bir kez ödendi —
// DECISIONS 2026-08-11, "drift `&` operatörünün dar `show` yüzünden kapsam dışı kalması").
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/auth_api.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/login_screen.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/components/atoms.dart';

class _OkAuthApi extends AuthApi {
  _OkAuthApi(String base) : super(baseUrl: base);

  @override
  Future<LoginResult> login({
    required String tenantCode,
    required String username,
    required String password,
    required String deviceId,
  }) async =>
      LoginResult(
        token: 't',
        userId: 'u1',
        userName: 'Mehmet',
        userRole: 'patron',
        tenantName: 'Merkez Bayi',
      );

  @override
  Future<void> logout(String token) async {}
}

/// Parola alanı (üçüncü `TextField`) şu an gizli mi?
bool _parolaGizli(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).at(2)).obscureText;

Future<void> _ekranaKoy(WidgetTester tester, Session session) async {
  // Test fontu cihaz fontundan ~1.8× geniştir; dar bir tuvalde form taşar ve taşma hatası
  // gerçek bir cihaz kanıtı değildir. Tuval bilerek uzun tutuluyor.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SipTheme.acik(),
    home: LoginScreen(session: session, onLoggedIn: () {}),
  ));
  await tester.pumpAndSettle();
}

Future<void> _formuDoldur(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'merkezbayi');
  await tester.enterText(find.byType(TextField).at(1), 'mehmet.usta');
  await tester.enterText(find.byType(TextField).at(2), 'sifre123');
}

void main() {
  group('hatirlananKimlikCoz (saf kural — ekrandan ve diskten bağımsız)', () {
    SyncMetaData meta({String? firma, String? kullanici}) => SyncMetaData(
          id: 1,
          lastPulledSeq: 0,
          serverTimeOffsetMs: 0,
          snapshotDone: false,
          routeCredits: 0,
          routeCreditsMonthly: 0,
          savedTenantCode: firma,
          savedUsername: kullanici,
        );

    test('ikisi de doluysa kimlik döner', () {
      final k = hatirlananKimlikCoz(meta(firma: 'merkezbayi', kullanici: 'mehmet.usta'));
      expect(k, isNotNull);
      expect(k!.firma, 'merkezbayi');
      expect(k.kullanici, 'mehmet.usta');
    });

    test('hiç yazılmamışsa null (varsayılan: hatırlama KAPALI)', () {
      expect(hatirlananKimlikCoz(meta()), isNull);
    });

    test('YARIM kayıt hatırlama SAYILMAZ', () {
      // Bir alanı doldurup diğerini boş bırakan bir ekran, kullanıcıya hatırlandığını
      // söyleyip hatırlamamış olurdu — hiç hatırlamamaktan kötüdür.
      expect(hatirlananKimlikCoz(meta(firma: 'merkezbayi')), isNull);
      expect(hatirlananKimlikCoz(meta(kullanici: 'mehmet.usta')), isNull);
    });

    test('yalnız boşluktan ibaret değer YOKLUK sayılır', () {
      expect(hatirlananKimlikCoz(meta(firma: '   ', kullanici: 'mehmet.usta')), isNull);
    });
  });

  group('Parola göster/gizle', () {
    testWidgets('varsayılan GİZLİ — omuz üstünden okunmaz', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      expect(_parolaGizli(tester), isTrue);
    });

    testWidgets('göze dokunmak alanı AÇAR, tekrar dokunmak KAPATIR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      // Düğme ikonundan DEĞİL anlamından bulunur: `Semantics` etiketi ekran okuyucunun da
      // gördüğü sözleşmedir ve ikon değişse bile geçerli kalır.
      await tester.tap(find.bySemanticsLabel('Parolayı göster'));
      await tester.pumpAndSettle();

      // ASIL İDDİA: ikon değil ALANIN DURUMU. Dönen bir ikon + gizli kalan bir alan,
      // hiçbir hata üretmeden özelliği tamamen işlevsiz bırakırdı.
      expect(_parolaGizli(tester), isFalse);

      await tester.tap(find.bySemanticsLabel('Parolayı gizle'));
      await tester.pumpAndSettle();
      expect(_parolaGizli(tester), isTrue);
    });

    testWidgets('göz düğmesi alanın 46 px yüksekliğini BOZMAZ', (tester) async {
      // `suffixIcon` kısıtsız bırakılırsa Material 48×48 dayatır ve parola kutusu diğer iki
      // alanla hizasını kaybeder — gözle fark edilmesi zor, testle kolay.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      final kullaniciYuksekligi = tester.getSize(find.byType(SipInput).at(1)).height;
      final parolaYuksekligi = tester.getSize(find.byType(SipInput).at(2)).height;
      expect(parolaYuksekligi, kullaniciYuksekligi);
      expect(parolaYuksekligi, SipInputOlcu.yukseklik);
    });
  });

  group('Beni hatırla', () {
    testWidgets('varsayılan KAPALI ve kimlik diske YAZILMAZ', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      await _formuDoldur(tester);
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      final meta = await db.syncState();
      expect(meta.authToken, 't', reason: 'giriş yine de başarılı olmalı');
      expect(meta.savedTenantCode, isNull);
      expect(meta.savedUsername, isNull);
    });

    testWidgets('işaretliyken firma kodu + kullanıcı adı DİSKE yazılır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      await tester.tap(find.text('Beni hatırla'));
      await tester.pumpAndSettle();
      await _formuDoldur(tester);
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      final meta = await db.syncState();
      expect(meta.savedTenantCode, 'merkezbayi');
      expect(meta.savedUsername, 'mehmet.usta');
    });

    testWidgets('PAROLA HİÇBİR ALANA YAZILMAZ (pazarlıksız)', (tester) async {
      // Bu iddia bir özellik değil bir SINIRDIR: "beni hatırla" bir gün parolayı da saklamaya
      // genişletilmek istenirse bu test kırmızıya döner ve karar yazılı olarak yeniden alınır.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      await tester.tap(find.text('Beni hatırla'));
      await tester.pumpAndSettle();
      await _formuDoldur(tester);
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      // sync_meta'nın TÜM metin alanları taranır — tek tek alan saymak, yarın eklenecek bir
      // kolonu gözden kaçırırdı.
      final satir = await db.customSelect('SELECT * FROM sync_meta WHERE id = 1').getSingle();
      for (final deger in satir.data.values) {
        expect(deger, isNot('sifre123'), reason: 'parola yerelde saklanamaz');
      }
    });

    testWidgets('BÜYÜK HARFLE yazılan kimlik NORMALİZE saklanır', (tester) async {
      // Sunucuya giden ile diske yazılan aynı değer olmalı: bayi "MERKEZBAYI" yazsa da
      // hesabı `merkezbayi`dir ve ertesi gün kutuda onu görmelidir.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      await tester.tap(find.text('Beni hatırla'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'MERKEZBAYI');
      await tester.enterText(find.byType(TextField).at(1), 'Mehmet.Usta');
      await tester.enterText(find.byType(TextField).at(2), 'sifre123');
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      final meta = await db.syncState();
      expect(meta.savedTenantCode, 'merkezbayi');
      expect(meta.savedUsername, 'mehmet.usta');
    });

    testWidgets('ÇIKIŞ hatırlanan kimliği SİLMEZ — özelliğin var oluş sebebi', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final session = Session(db, apiFactory: _OkAuthApi.new);
      await _ekranaKoy(tester, session);

      await tester.tap(find.text('Beni hatırla'));
      await tester.pumpAndSettle();
      await _formuDoldur(tester);
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      await session.logout();

      final meta = await db.syncState();
      expect(meta.authToken, isNull, reason: 'oturum gerçekten kapanmalı');
      expect(meta.savedTenantCode, 'merkezbayi',
          reason: 'token zaten çıkışa kadar duruyor; kimlik burada silinseydi HİÇ okunmazdı');
      expect(meta.savedUsername, 'mehmet.usta');
    });

    testWidgets('kutu boşaltılınca önceki kimlik SİLİNİR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        const SyncMetaCompanion(
          savedTenantCode: Value('eskibayi'),
          savedUsername: Value('eski.kullanici'),
        ),
      );

      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      // Kutu diskteki kayıt yüzünden İŞARETLİ açılmalı; dokunuş onu boşaltır.
      await tester.tap(find.text('Beni hatırla'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'sifre123');
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      final meta = await db.syncState();
      expect(meta.savedTenantCode, isNull, reason: 'kutuyu boşaltmak bir tercihtir');
      expect(meta.savedUsername, isNull);
    });

    testWidgets('hatırlanan kimlik alanları ÖNDOLDURUR ve kutu işaretli açılır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        const SyncMetaCompanion(
          savedTenantCode: Value('merkezbayi'),
          savedUsername: Value('mehmet.usta'),
        ),
      );

      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
          'merkezbayi');
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
          'mehmet.usta');
      // Parola ASLA öndoldurulmaz.
      expect(tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text, isEmpty);

      // Kutunun işaretli AÇILDIĞI: yalnız parolayı yazıp girmek, kimliği korumalı.
      await tester.enterText(find.byType(TextField).at(2), 'sifre123');
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();
      expect((await db.syncState()).savedTenantCode, 'merkezbayi');
    });

    testWidgets('mağaza kuralı — yeni metinler yasaklı sözcük getirmez', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _ekranaKoy(tester, Session(db, apiFactory: _OkAuthApi.new));

      for (final yasak in ['Kayıt', 'Kaydol', 'Üye ol', 'Abone', 'Satın al', 'Fiyat', '₺']) {
        expect(find.textContaining(yasak), findsNothing);
      }
    });
  });
}
