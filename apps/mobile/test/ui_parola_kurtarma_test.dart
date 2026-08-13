// PAROLA KURTARMA — giriş ekranındaki "Parolamı unuttum" akışı (kullanıcı isteği 2026-08-13).
//
// KAPATILAN BOŞLUK: mobilde parola kurtarma yolu HİÇ YOKTU. Parolasını unutan kullanıcının
// yapabildiği tek şey birini aramaktı; pilot bayilerde bu birinci sıradaki destek çağrısıdır.
//
// BU DOSYANIN ASIL KİLİDİ: ekran İKİ GERÇEĞİ DE, İSTEKTEN ÖNCE yazar. Sunucu cevabında
// "bu hesap kurye" diyemez (hesap numaralandırması), dolayısıyla ayrımı söyleyecek olan
// ekrandır. Bu satır silinirse kurye bağlantıyı bekler, hiç gelmez ve "uygulama bozuk" der —
// üstelik hiçbir test kırılmazdı.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/auth_api.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/login_screen.dart';
import 'package:sipario/theme/app_theme.dart';

import 'support/ekran_yardimcilari.dart';

/// İsteği kaydeden sahte API. Gerçek `AuthApi` ağa çıkar; testte dikiş buradan değişir.
class _SahteApi extends AuthApi {
  _SahteApi(String base) : super(baseUrl: base);

  static final istekler = <({String firma, String kullanici})>[];
  static AuthException? hata;

  @override
  Future<String> parolaSifirla({
    required String tenantCode,
    required String username,
  }) async {
    istekler.add((firma: tenantCode, kullanici: username));
    if (hata != null) throw hata!;
    return 'Bu hesap için kayıtlı bir e-posta adresi varsa sıfırlama bağlantısı gönderildi.';
  }

  @override
  Future<void> logout(String token) async {}
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    _SahteApi.istekler.clear();
    _SahteApi.hata = null;
  });

  Future<void> girisEkrani(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: SipTheme.acik(),
      home: LoginScreen(
        session: Session(db, apiFactory: _SahteApi.new),
        onLoggedIn: () {},
      ),
    ));
    await akislariBekle(tester);
  }

  /// ⚠️ KİMLİK GİRİŞ FORMUNDAN DOLDURULUR, sheet'in içinden DEĞİL.
  ///
  /// Sheet açıkken `find.byType(TextField).at(0)` ALTTAKİ giriş ekranının alanını bulur — sheet
  /// onun üstüne çizilir ama ağaçtan silmez. İlk yazımda iki test tam bu yüzden düştü: yazı
  /// giriş formuna gidiyor, sheet'in alanları boş kalıyor, istek hiç gönderilmiyordu.
  /// Gerçek kullanıcı yolu da budur: kimlik zaten yazılmıştır, sheet onu devralır.
  Future<void> sheetiAc(WidgetTester tester, {String firma = '', String kullanici = ''}) async {
    await girisEkrani(tester);
    if (firma.isNotEmpty || kullanici.isNotEmpty) {
      await tester.enterText(find.byType(TextField).at(0), firma);
      await tester.enterText(find.byType(TextField).at(1), kullanici);
      await tester.pump();
    }
    await dokun(tester, find.text('Parolamı unuttum'));
    await sheetAnimasyonu(tester);
  }

  testWidgets('giriş ekranında kurtarma yolu VARDIR', (tester) async {
    await girisEkrani(tester);

    expect(find.text('Parolamı unuttum'), findsOneWidget,
        reason: 'yol yoksa parolasını unutan kullanıcının tek çaresi birini aramak');

    await kapat(tester);
  });

  testWidgets('İKİ GERÇEK de istekten ÖNCE yazılır', (tester) async {
    // Patronun e-postası gerçektir → bağlantı gider. Kurye/operatörünki SENTETİKTİR
    // (`<kullanıcı>@<kod>.sipario.local`) → posta hiçbir yere ulaşmaz. Sunucu bu ayrımı
    // cevabında söyleyemez; ekran söylemek zorunda.
    await sheetiAc(tester);

    expect(find.text('Yöneticiyseniz'), findsOneWidget);
    expect(find.textContaining('sıfırlama bağlantısı gönderilir'), findsOneWidget);
    expect(find.text('Kurye ya da operatörseniz'), findsOneWidget);
    expect(find.textContaining('yöneticiniz belirler'), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('kimlik giriş formundan ÖN DOLDURULUR ve küçük harfe iner', (tester) async {
    // Kullanıcı zaten yazmıştır; aynı iki alanı ikinci kez istemek kurtarma yolunu gereksiz
    // yere zorlaştırırdı. Normalizasyon `login` ile AYNI: sunucu aramayı `lower()` ile yapıyor
    // ve iki taraf ayrışırsa "OzPinar" yazan bayi için istek sessizce hiçbir hesap bulamaz.
    await girisEkrani(tester);
    await tester.enterText(find.byType(TextField).at(0), 'OzPinar');
    await tester.enterText(find.byType(TextField).at(1), 'Patron');
    await tester.pump();

    await dokun(tester, find.text('Parolamı unuttum'));
    await sheetAnimasyonu(tester);
    await dokun(tester, find.text('Sıfırlama Bağlantısı Gönder'));
    await akislariBekle(tester);

    expect(_SahteApi.istekler, hasLength(1));
    expect(_SahteApi.istekler.single.firma, 'ozpinar');
    expect(_SahteApi.istekler.single.kullanici, 'patron');

    await kapat(tester);
  });

  testWidgets('SUNUCUNUN NÖTR METNİ olduğu gibi gösterilir', (tester) async {
    // Metin burada YENİDEN YAZILMAZ: iki yerde yaşayan iki cümle, biri değiştiğinde
    // diğerinin sessizce yalan söylemesi demektir. Ayrıca cevap "gönderildi" DEĞİL
    // "istek alındı" anlamına gelir ve ekran da öyle okunmalıdır.
    await sheetiAc(tester, firma: 'ozpinar', kullanici: 'patron');
    await dokun(tester, find.text('Sıfırlama Bağlantısı Gönder'));
    await akislariBekle(tester);

    expect(find.text('İsteğiniz alındı'), findsOneWidget);
    expect(find.textContaining('kayıtlı bir e-posta adresi varsa'), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('BOŞ alanla istek GÖNDERİLMEZ', (tester) async {
    await sheetiAc(tester);
    // Ön doldurma yok (giriş formu boş) → alanlar boş.
    await dokun(tester, find.text('Sıfırlama Bağlantısı Gönder'));
    await akislariBekle(tester);

    expect(_SahteApi.istekler, isEmpty);
    expect(find.textContaining('Firma kodu ve kullanıcı adını girin'), findsOneWidget);

    await kapat(tester);
  });

  testWidgets('AĞ HATASI kullanıcıya SÖYLENİR — sessizce başarı gösterilmez', (tester) async {
    // Ağ koptuğunda "istek alındı" demek, kullanıcıyı hiç gelmeyecek bir bağlantıyı
    // beklemeye mahkûm ederdi.
    _SahteApi.hata = AuthException('Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.');
    await sheetiAc(tester, firma: 'ozpinar', kullanici: 'patron');
    await dokun(tester, find.text('Sıfırlama Bağlantısı Gönder'));
    await akislariBekle(tester);

    expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);
    expect(find.text('İsteğiniz alındı'), findsNothing);

    await kapat(tester);
  });
}
