// Müşteri formunda SESLİ GİRİŞ (2026-07-27 bayi isteği: "inputların yanında mikrofon işareti").
//
// Motor eklentisi widget testinde YOKTUR — `sesliGirisUret` dikişinden sahte veriliyor
// (`uriAcici` / `tutamacDeposu` deseninin aynısı). Böylece izin, dinleme ve hata yolları
// platform kanalı olmadan uçtan uca sınanabiliyor.
//
// DİKKAT: dinleme sırasında mikrofonun nabız animasyonu SONSUZ döngüdür — o hâlde
// `pumpAndSettle` ASLA oturmaz (iskelet parıltısı dersinin ikizi). Dinlerken düz `pump` kullanılır.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/customers/customer_form_ops.dart';
import 'package:sipario/screens/customers/customer_form_screen.dart';
import 'package:sipario/theme/app_theme.dart';

/// Sahte motor: ne zaman dinlediğini ve ne söylediğini test belirler.
class SahteSes implements SesliGiris {
  SahteSes({this.acilir = true, this.kapaliNedeni});

  /// `hazirla()` başarılı mı.
  final bool acilir;

  /// Açılmıyorsa kullanıcıya söylenecek gerekçe.
  final String? kapaliNedeni;

  SesDurumu _durum = SesDurumu.bilinmiyor;
  String? _gerekce;
  void Function(String metin)? _onMetin;
  void Function(String? gerekce)? _onBitis;

  int dinlemeSayisi = 0;
  int durdurmaSayisi = 0;
  bool birakildi = false;

  @override
  SesDurumu get durum => _durum;

  @override
  String? get gerekce => _gerekce;

  @override
  Future<bool> hazirla() async {
    if (!acilir) {
      _durum = SesDurumu.kapali;
      _gerekce = kapaliNedeni;
      return false;
    }
    _durum = SesDurumu.hazir;
    return true;
  }

  @override
  Future<void> dinle({
    required void Function(String metin) onMetin,
    required void Function(String? gerekce) onBitis,
  }) async {
    if (!await hazirla()) {
      onBitis(_gerekce);
      return;
    }
    dinlemeSayisi++;
    _durum = SesDurumu.dinliyor;
    _onMetin = onMetin;
    _onBitis = onBitis;
  }

  @override
  Future<void> durdur() async {
    if (_durum != SesDurumu.dinliyor) return;
    durdurmaSayisi++;
    _durum = SesDurumu.hazir;
    _onBitis?.call(null);
    _onMetin = null;
    _onBitis = null;
  }

  @override
  void birak() => birakildi = true;

  /// Test motoru: tanınan metni yayar (kısmi sonuç gibi).
  void soyle(String metin) => _onMetin?.call(metin);

  /// Test motoru: dinlemeyi gerekçeyle bitirir (ağ hatası, izin yok, anlaşılmadı…).
  void hataylaBitir(String gerekce) {
    _durum = SesDurumu.hazir;
    _onBitis?.call(gerekce);
    _onMetin = null;
    _onBitis = null;
  }
}

void main() {
  late SahteSes ses;

  setUp(() {
    ses = SahteSes();
    sesliGirisUret = () => ses;
  });

  tearDown(() {
    // Sızan sahte, sonraki testte sessizce yanlış sonuç üretir.
    sesliGirisUret = SpeechSesliGiris.new;
  });

  Future<void> formuAc(WidgetTester tester, AppDatabase db) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: SipTheme.acik(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => musteriEkleSheet(ctx, db: db),
              child: const Text('AÇ'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('AÇ'));
    await tester.pumpAndSettle();
  }

  /// Dinleme kipinde `pumpAndSettle` KULLANILMAZ (nabız animasyonu sonsuz).
  Future<void> kare(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  Future<void> kapat(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Metin birleştirme (saf)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('sesMetniBirlestir', () {
    test('boş alanda tanınan metin doğrudan yazılır', () {
      expect(sesMetniBirlestir('', 'Ayşe Kaya'), 'Ayşe Kaya');
    });

    test('dolu alanda SONA eklenir — elle yazılan metin EZİLMEZ', () {
      expect(sesMetniBirlestir('Ayşe', 'Kaya'), 'Ayşe Kaya');
      expect(sesMetniBirlestir('Lara Cad. ', 'no 12'), 'Lara Cad. no 12');
    });

    test('boş tanıma alanı bozmaz', () {
      expect(sesMetniBirlestir('Ayşe Kaya', ''), 'Ayşe Kaya');
      expect(sesMetniBirlestir('Ayşe Kaya', '   '), 'Ayşe Kaya');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Yerleşim — hangi alanda mikrofon var
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('mikrofon ad · adres · not alanlarında var, TELEFONDA YOK', (tester) async {
    // Bölge alanı 2026-07-28'de kaldırıldı; mikrofonu da onunla birlikte gitti.
    final db = AppDatabase(NativeDatabase.memory());
    await formuAc(tester, db);

    for (final alan in ['Ad Soyad', 'Adres', 'Not']) {
      expect(find.bySemanticsLabel('Sesle yaz · $alan'), findsOneWidget,
          reason: '$alan alanında mikrofon olmalı');
    }
    // Sesle rakam dikte etmek yanlış numara üretir ve arayan tanımayı kör eder — bilinçli yokluk.
    expect(find.bySemanticsLabel(RegExp('Sesle yaz')), findsNWidgets(3),
        reason: 'telefon alanlarında mikrofon OLMAMALI');

    await kapat(tester);
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Dinleme akışı
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('dokununca dinler, tanınan metin alana yazılır ve mevcut metni EZMEZ',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await formuAc(tester, db);

    // Kullanıcı adın bir kısmını ELLE yazdı.
    await tester.enterText(find.byType(TextField).first, 'Ayşe');
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Sesle yaz · Ad Soyad'));
    await kare(tester);

    // Kullanıcı dinlendiğini GÖRMELİ — sessiz mikrofon güven sorunudur.
    expect(find.text('Dinleniyor… konuşun'), findsOneWidget);
    expect(ses.dinlemeSayisi, 1);

    ses.soyle('Kaya');
    await kare(tester);
    expect(find.text('Ayşe Kaya'), findsOneWidget, reason: 'elle yazılan metin korunmalı');

    // Kısmi sonuç büyüyünce alan TEKRARLAMAZ — taban sabit, tanınan metin değişir.
    ses.soyle('Kaya Yılmaz');
    await kare(tester);
    expect(find.text('Ayşe Kaya Yılmaz'), findsOneWidget);
    expect(find.text('Ayşe Kaya Kaya Yılmaz'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('ikinci dokunuş dinlemeyi durdurur', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await formuAc(tester, db);

    await tester.tap(find.bySemanticsLabel('Sesle yaz · Adres'));
    await kare(tester);
    expect(find.text('Dinleniyor… konuşun'), findsOneWidget);

    // Dinlerken etiket "durdur"a döner — düğme kendi durumunu anlatır.
    await tester.tap(find.bySemanticsLabel('Dinlemeyi durdur'));
    await kare(tester);

    expect(ses.durdurmaSayisi, 1);
    expect(find.text('Dinleniyor… konuşun'), findsNothing);

    await kapat(tester);
  });

  testWidgets('aynı anda TEK alan dinlenir — başka mikrofon öncekini kapatır', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await formuAc(tester, db);

    await tester.tap(find.bySemanticsLabel('Sesle yaz · Ad Soyad'));
    await kare(tester);
    await tester.tap(find.bySemanticsLabel('Sesle yaz · Not'));
    await kare(tester);

    expect(ses.durdurmaSayisi, 1, reason: 'önceki alan kapatılmalı');
    expect(ses.dinlemeSayisi, 2);
    expect(find.text('Dinleniyor… konuşun'), findsOneWidget, reason: 'tek bant görünür');

    await kapat(tester);
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Kapalı / hatalı yollar — düğme GİZLENMEZ, sebebini söyler
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('izin yoksa mikrofon gizlenmez, dokunuş sebebini söyler', (tester) async {
    ses = SahteSes(
      acilir: false,
      kapaliNedeni: 'Mikrofon izni verilmedi — telefon ayarlarından açın',
    );
    sesliGirisUret = () => ses;

    final db = AppDatabase(NativeDatabase.memory());
    await formuAc(tester, db);

    expect(find.bySemanticsLabel('Sesle yaz · Ad Soyad'), findsOneWidget,
        reason: 'pasif ≠ gizli (Oto Sırala / Ara düğmeleriyle aynı desen)');

    await tester.tap(find.bySemanticsLabel('Sesle yaz · Ad Soyad'));
    await kare(tester);

    expect(find.text('Mikrofon izni verilmedi — telefon ayarlarından açın'), findsOneWidget);
    expect(ses.dinlemeSayisi, 0);

    await kapat(tester);
  });

  testWidgets('çevrimdışıyken gerekçe DÜRÜSTÇE söylenir', (tester) async {
    // Offline-first kırmızı çizgisi: sesli giriş bir kolaylıktır, form elle doldurulabilir
    // kalır — ama kullanıcı neden çalışmadığını bilmeli.
    final db = AppDatabase(NativeDatabase.memory());
    await formuAc(tester, db);

    await tester.tap(find.bySemanticsLabel('Sesle yaz · Adres'));
    await kare(tester);
    ses.hataylaBitir('Ses tanıma için internet gerekiyor — çevrimdışıyken elle yazın');
    await kare(tester);

    expect(find.text('Ses tanıma için internet gerekiyor — çevrimdışıyken elle yazın'),
        findsOneWidget);
    expect(find.text('Dinleniyor… konuşun'), findsNothing);

    await kapat(tester);
  });

  testWidgets('sheet kapanınca mikrofon serbest bırakılır', (tester) async {
    // Sahipsiz açık kalan bir kayıt oturumu hem pil hem güven meselesi.
    final db = AppDatabase(NativeDatabase.memory());
    await formuAc(tester, db);

    await tester.tap(find.bySemanticsLabel('Sesle yaz · Ad Soyad'));
    await kare(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));

    expect(ses.birakildi, isTrue);
  });
}
