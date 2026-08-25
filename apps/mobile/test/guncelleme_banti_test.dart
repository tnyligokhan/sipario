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
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/guncelleme/guncelleme_banti.dart';
import 'package:sipario/guncelleme/guncelleme_servisi.dart';
import 'package:sipario/guncelleme/guncelleme_sozlesmesi.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/sync/sync_service.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/icons.dart';

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
      expect(find.textContaining('sürüm'), findsNothing);
      expect(find.text(_bilgi.surum), findsNothing);

      await _kapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // TETİKLEYİCİ — "kapatıp açtım, gelmedi" (2026-07-28 saha bulgusu)
  // ═════════════════════════════════════════════════════════════════════════════════════════
  //
  // Kontrol yalnız AÇILIŞTA koşuyordu. Son kullanılanlardan kaydırmak çoğu Android'de süreci
  // ÖLDÜRMEZ — Dart isolate yaşar, `initState` bir daha koşmaz. Bandı görmek için "zorla
  // durdur" gerekiyordu; hiçbir bayi bunu yapmaz. Senkron motoru bu dersi zaten öğrenmişti,
  // güncelleme kontrolü ona bağlanmamıştı.
  group('kontrolGerekli — ne zaman ağa çıkılır', () {
    final t0 = DateTime(2026, 7, 28, 12);
    const aralik = Duration(minutes: 15);

    bool gerekli({
      bool kapali = false,
      GuncellemeDurumu durum = GuncellemeDurumu.yok,
      DateTime? sonKontrol,
      DateTime? simdi,
      bool zorla = false,
    }) =>
        kontrolGerekli(
          kapali: kapali,
          durum: durum,
          sonKontrol: sonKontrol,
          simdi: simdi ?? t0,
          aralik: aralik,
          zorla: zorla,
        );

    test('ilk çağrıda çıkılır', () => expect(gerekli(), isTrue));

    test('mağaza derlemesinde HİÇ çıkılmaz', () => expect(gerekli(kapali: true), isFalse));

    test('bant zaten duruyorsa tekrar sorulmaz', () {
      expect(gerekli(durum: GuncellemeDurumu.bulundu), isFalse);
      expect(gerekli(durum: GuncellemeDurumu.iniyor), isFalse);
    });

    test('aralık dolmadan öne gelme ağa ÇIKMAZ (pil/veri)', () {
      expect(gerekli(sonKontrol: t0.subtract(const Duration(minutes: 3))), isFalse);
    });

    test('aralık dolunca yeniden çıkılır', () {
      expect(gerekli(sonKontrol: t0.subtract(const Duration(minutes: 15))), isTrue);
      expect(gerekli(sonKontrol: t0.subtract(const Duration(hours: 2))), isTrue);
    });

    test('zorla aralığı atlar ama KAPALI kapısını atlamaz', () {
      expect(gerekli(sonKontrol: t0, zorla: true), isTrue);
      expect(gerekli(kapali: true, zorla: true), isFalse,
          reason: 'mağaza derlemesi hiçbir koşulda ağa çıkmamalı');
    });
  });

  group('Öne gelme tetikleyicisi kabuğa BAĞLI mı', () {
    testWidgets('resumed olayı güncelleme kontrolünü çağırır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final once = guncellemeServisi.istekSayisi;

      await _ekranaKoy(
        tester,
        HomeShell(
          db: db,
          session: Session(db),
          sync: SyncService(db),
          onLoggedOut: () {},
        ),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // ARIZANIN TA KENDİSİ: bu sayı düne kadar öne gelmede HİÇ artmıyordu; bant ancak
      // "zorla durdur" sonrası açılışta çıkıyordu.
      expect(guncellemeServisi.istekSayisi, greaterThan(once));

      await _kapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // DURUM ÇUBUĞU — bant çıkınca ikonlar beyaz kalmamalı (2026-07-28 saha bulgusu)
  // ═════════════════════════════════════════════════════════════════════════════════════════
  //
  // Ana ekranın tepesi koyu hero'dur ve ikonlar orada BEYAZ olmalı. Bant araya girince durum
  // çubuğunun altındaki artık hero değil, açık renkli banttır — beyaz ikon orada görünmez ve
  // bayi saati/pili okuyamaz. Bu, kabuğun "hero ekranı" kararının bantları hiç hesaba
  // katmamasından geliyordu.
  group('heroDurumCubugu', () {
    test('ana ekranda, bant yokken beyaz ikon İSTENİR', () {
      expect(heroDurumCubugu(anaSekme: true, kilit: false, bantVar: false), isTrue);
    });

    test('BANT VARKEN beyaz ikon istenmez — asıl bulgu', () {
      expect(heroDurumCubugu(anaSekme: true, kilit: false, bantVar: true), isFalse,
          reason: 'açık renkli bandın üstünde beyaz ikon okunmaz');
    });

    test('ana ekran dışında ve kilitte zaten hero yoktur', () {
      expect(heroDurumCubugu(anaSekme: false, kilit: false, bantVar: false), isFalse);
      expect(heroDurumCubugu(anaSekme: true, kilit: true, bantVar: false), isFalse);
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

      expect(find.text('Yeni sürüm hazır'), findsOneWidget);
      expect(tester.getSize(find.byType(GuncellemeBanti)).height, greaterThan(0));

      await _kapat(tester);
    });

    // ═══════════════════════════════════════════════════════════════════════════════════════
    // 2026-08-25 kullanıcı isteği: "yükleme butonu pek belirgin değil, orada güncelle
    // şeklinde bir ikon olmalı ya da indirme gibi"
    // ═══════════════════════════════════════════════════════════════════════════════════════
    //
    // Sağ köşede eskiden SÜRÜM ROZETİ vardı: dolgulu, accent renkli, düğme gibi duran ama
    // içinde "0.9.0" yazan bir hap. Bilgi taşıyordu, eylem değil — ve bandın dokunulabilir
    // olduğunu söyleyen tek şey alt satırdaki cümleydi.
    testWidgets('sağ köşede İKONLU "Güncelle" düğmesi durur', (tester) async {
      await bandiKur(tester);
      servis.bulunan.value = _bilgi;
      servis.durum.value = GuncellemeDurumu.bulundu;
      await tester.pump();

      expect(find.text('Güncelle'), findsOneWidget, reason: 'eylem sözcüğü görünmeli');
      expect(
        find.byWidgetPredicate((w) => w is SipIcon && w.ad == SipIcons.indir),
        findsOneWidget,
        reason: 'indirme ikonu (aşağı ok) düğmenin içinde olmalı',
      );

      await _kapat(tester);
    });

    testWidgets('HATA hâlinde düğme "Tekrar Dene" der', (tester) async {
      await bandiKur(tester);
      servis.bulunan.value = _bilgi;
      servis.durum.value = GuncellemeDurumu.hata;
      await tester.pump();

      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.text('Güncelle'), findsNothing,
          reason: 'yarım kalmış bir indirmeden sonra "Güncelle" demek ne olduğunu gizler');

      await _kapat(tester);
    });

    // ═══════════════════════════════════════════════════════════════════════════════════════
    // 2026-08-11 kullanıcı kararı: "sadece sürüm yazsın"
    // ═══════════════════════════════════════════════════════════════════════════════════════
    //
    // Eski metin `Güncelleme var — Sipario 0.9.0 (139)` idi. Parantezteki sayı YAPIM
    // numarasıdır: makinenin karşılaştırma anahtarı (CLAUDE.md → Sürümleme), bayiye hiçbir
    // şey söylemeyen bir git sayacı. Ekrandan kalktı ama KARŞILAŞTIRMADAN kalkmadı — o
    // ayrım tam olarak bu iki iddiadır ve ikisi birlikte anlamlıdır.
    testWidgets('SÜRÜM yazar, YAPIM numarasını YAZMAZ', (tester) async {
      // ⚠️ SÜRÜM 2026-08-25'TE ALT SATIRA TAŞINDI (sağ köşe artık eyleme ait), ama KARARIN
      // KENDİSİ DURUYOR: sürüm adı görünür, yapım numarası görünmez. İddia bu yüzden
      // "hangi widget"a değil METNİN VARLIĞINA bakar.
      await bandiKur(tester);
      servis.bulunan.value = _bilgi;
      servis.durum.value = GuncellemeDurumu.bulundu;
      await tester.pump();

      expect(find.textContaining(_bilgi.surum), findsOneWidget, reason: 'sürüm adı yazmalı');
      expect(find.textContaining('${_bilgi.yapim}'), findsNothing,
          reason: 'yapım numarası (139) bayiye gösterilmez — makine anahtarıdır');
      expect(find.textContaining('Sipario'), findsNothing,
          reason: 'uygulamanın kendi adını kendi bandında tekrarlaması gürültüdür');

      await _kapat(tester);
    });

    testWidgets('sürüm YALNIZ "bulundu" hâlinde yazar', (tester) async {
      // İnerken yüzde, hata varken "İndirme yarım kaldı": aynı yerde iki farklı anlam taşıyan
      // bir metin, bayiye indirmenin bittiğini sandırırdı.
      await bandiKur(tester);
      servis.bulunan.value = _bilgi;

      for (final durum in [GuncellemeDurumu.iniyor, GuncellemeDurumu.hata]) {
        servis.durum.value = durum;
        await tester.pump();
        expect(find.textContaining(_bilgi.surum), findsNothing,
            reason: '$durum hâlinde sürüm yazmamalı');
      }

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

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // YENİ SÜRÜM BİLDİRİMİ (kullanıcı isteği 2026-08-25)
  // ═════════════════════════════════════════════════════════════════════════════════════════
  //
  // Bandın bedeli: bayi uygulamayı AÇMADIĞI sürece yeni sürümden haberi olmuyordu. Bildirim o
  // boşluğu kapatır. Burada kilitlenen şey "gerçekten üretiliyor mu" — bandın aylarca ağaca
  // bağlanmamış olması (yukarıdaki ilk grup) tam olarak bu tür bir sessiz kopukluktu.
  group('Güncelleme bildirimi', () {
    /// Sahte bildirim servisiyle kurulmuş güncelleme servisi.
    ({GuncellemeServisi servis, SahteBildirimServisi sahte}) kur() {
      final sahte = SahteBildirimServisi();
      final servis = GuncellemeServisi(bildirim: sahte);
      addTearDown(servis.durum.dispose);
      addTearDown(servis.bulunan.dispose);
      addTearDown(servis.ilerleme.dispose);
      addTearDown(servis.sonBasariliKontrol.dispose);
      return (servis: servis, sahte: sahte);
    }

    test('ÜRETİLEN TASLAK — kategori, kimlik ve metin sözleşmesi', () async {
      final (:servis, :sahte) = kur();

      await servis.bildir(_bilgi);

      expect(sahte.gosterilenler, hasLength(1), reason: 'bildirim gerçekten üretilmeli');
      final t = sahte.gosterilenler.single;
      expect(t.kategori, BildirimKategori.guncellemeVar);
      expect(t.kimlik, 'guncelleme_var:139',
          reason: 'kimlik YAPIMA bağlı: aynı sürüm için ikinci bildirim doğmaz, üzerine yazar');
      expect(t.govde, contains(_bilgi.surum), reason: 'sürüm adı gövdede yazar');
      expect('${t.baslik} ${t.govde} ${t.detay}', isNot(contains('${_bilgi.yapim}')),
          reason: 'yapım numarası makine anahtarıdır, bayiye hiçbir yerde gösterilmez');
      expect(t.yol, isNull,
          reason: 'dokunuş uygulamayı ANA EKRANDA açar; bant zaten orada duruyor');
    });

    test('AYNI SÜRÜM iki kez bildirmez — kimlik üzerine yazar', () async {
      final (:servis, :sahte) = kur();

      await servis.bildir(_bilgi);
      await servis.bildir(_bilgi);

      expect(sahte.gosterilenler, hasLength(1),
          reason: 'uygulama gün içinde birkaç kez yeniden başlasa bile bayi tek satır görür');
    });

    test('kategori ayarları — işi BÖLMEZ, kurye de ALIR', () {
      expect(BildirimKategori.guncellemeVar.headsUp, isFalse,
          reason: 'güncelleme beklenen bir iş değil; ekranın üstünde belirip işi bölmemeli');
      expect(BildirimKategori.guncellemeVar.yalnizYonetici, isFalse,
          reason: 'eski sürümde kalan telefon çoğu zaman kuryenin telefonudur');
    });

    test('bayi kategoriyi KAPATTIYSA bildirim çıkmaz', () async {
      // Ayar ekranındaki anahtarın gerçekten bir şey yapması: kapatınca hiçbir şey
      // değişmeyen bir anahtar, ayarların tamamına olan güveni bozar.
      final sahte = SahteBildirimServisi(
        kapaliKategoriler: {BildirimKategori.guncellemeVar},
      );
      final servis = GuncellemeServisi(bildirim: sahte);
      addTearDown(servis.durum.dispose);
      addTearDown(servis.bulunan.dispose);
      addTearDown(servis.ilerleme.dispose);
      addTearDown(servis.sonBasariliKontrol.dispose);

      await servis.bildir(_bilgi);

      expect(sahte.gosterilenler, isEmpty);
    });

    test('KAPALI derlemede bildirim HİÇ üretilmez — ağa bile çıkılmaz', () async {
      // Mağaza kanalının garantisi: uygulama içi güncelleme yolu tamamen kapalı olduğu için
      // bu bildirim de doğmaz. Ayar listesinde de görünmez (bkz. `_listelenir`).
      final sahte = SahteBildirimServisi();
      final servis = GuncellemeServisi(bildirim: sahte);
      addTearDown(servis.durum.dispose);
      addTearDown(servis.bulunan.dispose);
      addTearDown(servis.ilerleme.dispose);
      addTearDown(servis.sonBasariliKontrol.dispose);

      await servis.sessizKontrol(kapali: true, zorla: true);

      expect(sahte.gosterilenler, isEmpty);
      expect(servis.durum.value, GuncellemeDurumu.yok);
    });
  });
}
