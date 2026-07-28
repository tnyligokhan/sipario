// GÜNCELLEME BANDI — "servis buluyor ama kimse çizmiyor" arızasının regresyon kilidi.
//
// 2026-07-28 saha bulgusu: `sessizKontrol()` açılışta koşuyor, `surum.json`u çekiyor, yeni
// yapımı buluyor ve bildirimleri dolduruyordu — ama `GuncellemeBanti` HİÇBİR EKRANDA mount
// edilmemişti. Boru hattının son halkası kopuktu: hiçbir şey çökmüyor, hiçbir şey de olmuyor.
// Teşhisi en zor arıza türü budur ve mevcut testler (hepsi saf fonksiyon) onu göremezdi.
//
// Bu dosya iki ayrı şeyi kilitler:
//   1. Bandın KABUKTA olduğu — kapalıyken bile ağaçta yer tutar, böylece varlığı test edilebilir.
//   2. Bandın açıkken GERÇEKTEN çizdiği ve dokunuşun servise gittiği.
//
// (1) neden böyle kurulmalı: kill-switch derleme sabitinden okunuyor ve varsayılan
// `flutter test` altında kanal `magaza`/yapım 0 — yani KAPALI. Kabuk bandı `if` ile sarsaydı
// ağaçta hiç görünmezdi ve "bağlanmadı" hatası yine kaçardı. Bant koşulsuz mount edilir,
// koşul widget'ın İÇİNDEDİR.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/guncelleme/guncelleme_banti.dart';
import 'package:sipario/guncelleme/guncelleme_servisi.dart';
import 'package:sipario/guncelleme/guncelleme_sozlesmesi.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/sync/sync_service.dart';
import 'package:sipario/theme/app_theme.dart';

const _bilgi = SurumBilgisi(
  yapim: 139,
  surum: '0.9.0',
  apkArm64: 'https://ornek/saha-arm64.apk',
  apkEvrensel: 'https://ornek/saha-evrensel.apk',
  boyutArm64: 30352835,
  boyutEvrensel: 79849837,
);

Future<void> _ekranaKoy(WidgetTester tester, Widget ekran) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: SipTheme.acik(), home: ekran));
  await tester.pump();
}

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('Bant KABUĞA BAĞLI MI (asıl regresyon)', () {
    testWidgets('HomeShell güncelleme bandını ağaca mount eder', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await _ekranaKoy(
        tester,
        HomeShell(
          db: db,
          session: Session(db),
          sync: SyncService(db), // start() çağrılmaz: ağ/timer yok
          onLoggedOut: () {},
        ),
      );
      await tester.pumpAndSettle();

      // ARIZANIN TA KENDİSİ: bu satır 2026-07-28'e kadar `findsNothing` dönerdi.
      expect(find.byType(GuncellemeBanti), findsOneWidget,
          reason: 'bant kabukta yoksa servis güncellemeyi bulsa bile kimse görmez');

      await _kapat(tester);
    });

    testWidgets('kapalı derlemede yer tutar ama HİÇBİR ŞEY çizmez', (tester) async {
      // Mağaza derlemesinin garantisi: ağaçta var, yüksekliği sıfır, ağa çıkılmamış.
      final servis = GuncellemeServisi();
      servis.bulunan.value = _bilgi;
      servis.durum.value = GuncellemeDurumu.bulundu;
      addTearDown(servis.durum.dispose);
      addTearDown(servis.bulunan.dispose);
      addTearDown(servis.ilerleme.dispose);

      await _ekranaKoy(
        tester,
        Scaffold(body: GuncellemeBanti(servis: servis, kapali: true)),
      );

      expect(find.byType(GuncellemeBanti), findsOneWidget);
      expect(tester.getSize(find.byType(GuncellemeBanti)).height, 0);
      expect(find.textContaining('Güncelleme'), findsNothing);

      await _kapat(tester);
    });
  });

  group('Bant AÇIK derlemede', () {
    late GuncellemeServisi servis;

    setUp(() => servis = GuncellemeServisi());

    tearDown(() {
      servis.durum.dispose();
      servis.bulunan.dispose();
      servis.ilerleme.dispose();
    });

    Future<void> bandiKur(WidgetTester tester) => _ekranaKoy(
          tester,
          Scaffold(body: GuncellemeBanti(servis: servis, kapali: false)),
        );

    testWidgets('güncelleme yokken çizilmez', (tester) async {
      await bandiKur(tester);

      expect(tester.getSize(find.byType(GuncellemeBanti)).height, 0,
          reason: 'güncelleme yokken her ekranın tepesinde hayalet boşluk kalmamalı');

      await _kapat(tester);
    });

    testWidgets('güncelleme bulununca bant görünür', (tester) async {
      await bandiKur(tester);
      servis.bulunan.value = _bilgi;
      servis.durum.value = GuncellemeDurumu.bulundu;
      await tester.pump();

      expect(find.textContaining('Güncelleme'), findsOneWidget);
      expect(tester.getSize(find.byType(GuncellemeBanti)).height, greaterThan(0));

      await _kapat(tester);
    });

    testWidgets('indirme sürerken yüzde gösterir ve İKİNCİ dokunuşu almaz', (tester) async {
      await bandiKur(tester);
      servis.bulunan.value = _bilgi;
      servis.durum.value = GuncellemeDurumu.iniyor;
      servis.ilerleme.value = 0.42;
      await tester.pump();

      expect(find.text('%42'), findsOneWidget);
      // İkinci bir indirme başlatmak dosyayı bozar — dokunuş kapalı olmalı.
      // Tasarımda ripple yok: SipDokun `InkWell` değil `GestureDetector` kullanır.
      final dokun = tester.widget<GestureDetector>(find.byType(GestureDetector).first);
      expect(dokun.onTap, isNull);

      await _kapat(tester);
    });

    testWidgets('hata durumunda bant tekrar denenebilir kalır', (tester) async {
      await bandiKur(tester);
      servis.bulunan.value = _bilgi;
      servis.durum.value = GuncellemeDurumu.hata;
      await tester.pump();

      // Yarım kalan indirmeden sonra bayi kilitlenmiş bir bantla kalmamalı.
      // Tasarımda ripple yok: SipDokun `InkWell` değil `GestureDetector` kullanır.
      final dokun = tester.widget<GestureDetector>(find.byType(GestureDetector).first);
      expect(dokun.onTap, isNotNull);

      await _kapat(tester);
    });

    testWidgets('MAĞAZA DİLİ YOK — fiyat/abonelik/satın alma sözcüğü geçmez', (tester) async {
      // BRIEF mağaza kuralı: bu bant `saha` kanalına özel olsa da metin sözleşmesi aynıdır.
      await bandiKur(tester);
      servis.bulunan.value = _bilgi;
      servis.durum.value = GuncellemeDurumu.bulundu;
      await tester.pump();

      for (final yasak in ['abone', 'Abone', 'satın', 'Satın', 'fiyat', 'Fiyat', 'TL', '₺']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mağaza kuralını ihlal eder');
      }

      await _kapat(tester);
    });
  });
}
