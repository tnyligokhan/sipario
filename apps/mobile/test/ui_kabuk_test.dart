// UYGULAMA KABUĞU testleri — alt navigasyon, çekmece (rol kapısı), kurulum sihirbazı
// (ilerleme) ve tema anahtarı. Ana ekranın bento ızgarası `ui_kabuk_ana_test.dart`ta
// (500 satır sınırı); ortak yardımcılar `support/kabuk_yardimcilari.dart`.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/main.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/screens/login_screen.dart';
import 'package:sipario/screens/shell/alt_nav.dart';
import 'package:sipario/screens/shell/cekmece.dart';
import 'package:sipario/screens/shell/cekmece_istatistik.dart';
import 'package:sipario/screens/sihirbaz/izin_sihirbazi.dart';
import 'package:sipario/screens/sihirbaz/sihirbaz_parcalari.dart';
import 'package:sipario/theme/tema_deposu.dart';
import 'package:sipario/theme/tokens.dart';

import 'support/kabuk_yardimcilari.dart';

void main() {
  group('Alt navigasyon — s-bilesenler.jsx AltNav', () {
    /// Sekmeyi kendi durumunda tutan minik kabuk: içeriğin sekmeyle değiştiğini gösterir.
    Widget navKabugu({VoidCallback? onEkle}) =>
        _NavKabugu(onEkle: onEkle, baslangic: SipSekme.ana);

    testWidgets('dört sekme + FAB çizilir; seçili sekmenin etiketi görünür', (tester) async {
      await ekranaKoy(tester, navKabugu(onEkle: () {}));

      for (final etiket in ['Ana', 'Müşteri', 'Sipariş', 'Gün Özeti']) {
        expect(semantikDugme(etiket), findsOneWidget, reason: '$etiket sekmesi yok');
      }
      expect(semantikDugme('Yeni kayıt ekle'), findsOneWidget, reason: 'FAB yok');

      // CSS: yalnız SEÇİLİ sekme etiketini yazar (diğerleri ikon-only).
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Müşteri'), findsNothing);
      expect(find.text('Sipariş'), findsNothing);

      await kapat(tester);
    });

    testWidgets('sekme değişince içerik ve görünen etiket değişir', (tester) async {
      await ekranaKoy(tester, navKabugu());

      expect(find.text('gövde: ana'), findsOneWidget);

      await tester.tap(semantikDugme('Müşteri'));
      await tester.pumpAndSettle();

      expect(find.text('gövde: musteri'), findsOneWidget);
      expect(find.text('gövde: ana'), findsNothing);
      expect(find.text('Müşteri'), findsOneWidget, reason: 'seçilen sekme etiketini açar');
      expect(find.text('Ana'), findsNothing, reason: 'bırakılan sekme ikon-only olur');

      await kapat(tester);
    });

    testWidgets('FAB tek dokunuşta [onEkle]yi çağırır — menüyü KENDİ çizmez', (tester) async {
      // Kullanıcı kararı (2026-07-29): FAB artık iki seçenek sunar (Müşteri Ekle · Sipariş Ekle).
      // Menüyü KABUK açar, `AltNav` DEĞİL — navigasyon hangi ekranların var olduğunu bilmez ve
      // yazma yetkisi (abonelik kilidi) orada durur. Bu test o sınırı kilitler: FAB'ın tek işi
      // dokunuşu yukarı bildirmektir, sheet çizmek değil.
      var cagri = 0;
      await ekranaKoy(tester, navKabugu(onEkle: () => cagri++));

      await tester.tap(semantikDugme('Yeni kayıt ekle'));
      await tester.pumpAndSettle();

      expect(cagri, 1, reason: 'dokunuş kabuğa bildirilir');
      expect(find.text('Müşteri Ekle'), findsNothing,
          reason: 'menü AltNav içinde çizilmez — kabuğun işi');
      expect(find.text('Sipariş Ekle'), findsNothing);

      await kapat(tester);
    });

    testWidgets('gün sonu yuvası rolden BAĞIMSIZ daima çizilir', (tester) async {
      // Kullanıcı kararı (2026-07-26) + tasarım: `AltNav` her zaman 5 yuvadır, rol yalnız
      // çekmecenin YÖNETİM bölümünü etkiler. Kuryede sağ grup tek sekmeye düşünce hap
      // navigasyonun simetrisi de bozuluyordu.
      await ekranaKoy(tester, navKabugu());

      expect(semantikDugme('Gün Özeti'), findsOneWidget);
      expect(semantikDugme('Sipariş'), findsOneWidget);

      await tester.tap(semantikDugme('Gün Özeti'));
      await tester.pumpAndSettle();
      expect(find.text('gövde: gunSonu'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('kilit kipinde FAB ÇİZİLİR ama pasiftir', (tester) async {
      // Tasarımın kilit dalında da `AltNav` tam çizilir (`s-uygulama.jsx:87`). FAB'ı silmek
      // hap navigasyonu yeniden yerleştirip yerleşimi atlatıyordu.
      await ekranaKoy(tester, navKabugu());

      expect(semantikDugme('Yeni kayıt ekle'), findsOneWidget,
          reason: 'salt-okunur kipte de çizilir');
      await tester.tap(semantikDugme('Yeni kayıt ekle'));
      await tester.pumpAndSettle();
      // Dokunma bir şey yapmaz: sekme değişmedi, ekran açılmadı.
      expect(find.text('gövde: ana'), findsOneWidget);

      await kapat(tester);
    });
  });

  group('Çekmece — rol kapısı (K2, pazarlıksız)', () {
    Widget cekmece(
      String rol, {
      DateTime? lisansBitisi,
      ValueChanged<CekmeceGiris>? onGiris,
      bool borclularGorunur = true,
      bool cagriGunluguGorunur = true,
    }) =>
        SipCekmece(
          acik: true,
          onKapat: () {},
          isletmeAdi: 'Öz Pınar Su',
          rol: rol,
          onGiris: onGiris ?? (_) {},
          onCikis: () {},
          onDestek: () {},
          // Senkron damgası VERİLİR: durum şeridi çekmecenin yeni omurgası ve gerçek kullanımda
          // dolu olur. null bırakmak "henüz senkron olmadı" dalını sınardı — o ayrı bir hâl.
          sonSenkron: DateTime(2026, 8, 13, 10, 32),
          lisansBitisi:
              lisansBitisi ?? DateTime.now().toUtc().add(const Duration(days: 90)),
          urunlerGorunur: rol != 'kurye',
          borclularGorunur: borclularGorunur,
          cagriGunluguGorunur: cagriGunluguGorunur,
        );

    testWidgets('patron rolünde YÖNETİM bölümü ve istatistik kartları VAR', (tester) async {
      await ekranaKoy(tester, cekmece('patron'));

      expect(find.text('YÖNETİM'), findsOneWidget);
      expect(find.text('Ürünler'), findsOneWidget);
      expect(find.byType(CekmeceIstatistikleri), findsOneWidget);
      // LİSANS ARTIK PİLLİ BÜYÜK KART DEĞİL, İNCE ÇİP (2026-08-13 yeniden tasarımı): "AKTİF"
      // pili kaldırıldı çünkü çip yüksekliği ~44 punto ve pil için yer yok. Durum RENKLE ve
      // ikonla söyleniyor; kilitlenen şey pilin metni değil, KALAN GÜNÜN yazıyor olmasıdır.
      expect(find.textContaining('gün'), findsWidgets,
          reason: 'kalan gün çipte yazmalı — lisans durumu boş çekmeceden okunamaz');
      // ROL SATIRI ARTIK SENKRONLA BİRLEŞİK DEĞİL (2026-08-13): eskiden "Yönetici · senkron
      // 10:32" tek satırdı ve senkron bilgisi %55 opaklıkta bir ek cümleydi. Senkron kendi
      // DURUM ŞERİDİNE çıktı; rol satırı artık kişiyi anlatıyor ("Yönetici · Gökhan").
      expect(find.text('Yönetici'), findsOneWidget,
          reason: 'kullanıcı adı verilmediğinde satır yalnız rolü yazar');
      expect(find.textContaining('Son senkron'), findsOneWidget,
          reason: 'senkron tazeliği kendi şeridinde, okunabilir bir yerde');

      // BÖLÜM ETİKETLERİ AZALTILDI (2026-08-13 yeniden tasarımı): dokuz satır için dört büyük
      // harf başlık ("İŞ", "YÖNETİM", "HIZLI AYARLAR", "UYGULAMA") vardı ve üçü ayırt edici
      // bilgi taşımıyordu — yalnız dikey alan yiyip taramayı yavaşlatıyorlardı. Tek etiket
      // YÖNETİM'de kaldı, çünkü o ROL sinyali taşır; ayrım artık boşluk ve ayraçla yapılıyor.
      expect(find.text('İŞ'), findsNothing);
      expect(find.text('UYGULAMA'), findsNothing);
      expect(find.text('Borçlular'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('kurye rolünde YÖNETİM bölümü ve istatistik kartları HİÇ çizilmez',
        (tester) async {
      await ekranaKoy(tester, cekmece('kurye'));

      expect(find.text('YÖNETİM'), findsNothing);
      expect(find.text('Ürünler'), findsNothing);
      expect(find.text('Kuryeler'), findsNothing);
      expect(find.text('Muaf Telefonlar'), findsNothing);
      expect(find.byType(CekmeceIstatistikleri), findsNothing,
          reason: 'koşullu görünürlük değil — kuryede hiç kurulmaz');

      // Kuryeye açık kalanlar. Müşteriler/Siparişler artık ÇEKMECEDE DEĞİL — alt navigasyonda
      // (ikisi de tek dokunuş uzakta); çekmece yalnız orada olmayanları taşır.
      expect(find.text('Sipariş Haritası'), findsOneWidget);
      // HIZLI AYARLAR kuryede de vardır: bunlar kendi CİHAZ tercihleridir, dükkân verisi değil.
      expect(find.text('Arayan Tanıma'), findsOneWidget);
      expect(find.text('Hesap'), findsOneWidget);
      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.textContaining('Kurye'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('ALT NAVİGASYONUN KOPYASI satırlar çekmecede YOK', (tester) async {
      // 2026-08-13 yeniden düzeni. Eski çekmecenin ilk bölümü ("MENÜ") alt navigasyonun
      // birebir kopyasıydı: Ana Sayfa · Müşteriler · Siparişler · Gün Özeti. Alt bar her
      // ekranda görünür ve o dört hedefe TEK dokunuşla gider; çekmecedeki kopyaları İKİ
      // dokunuş istiyordu. Menünün en değerli alanı hiçbir yere götürmeyen bir tekrardaydı.
      await ekranaKoy(tester, cekmece('patron'));

      expect(find.text('Ana Sayfa'), findsNothing);
      expect(find.text('Müşteriler'), findsNothing);
      expect(find.text('Siparişler'), findsNothing);
      expect(find.text('Gün Özeti & Kasa Devri'), findsNothing);
      expect(find.text('Kasa Devri'), findsNothing);

      await kapat(tester);
    });

    testWidgets('İŞ bölümü menüden ulaşılamayan üç ekranı taşır', (tester) async {
      // Bu üçü eskiden çekmeceden HİÇ açılamıyordu: Borçlular yalnız ana ekrandaki bento
      // kutusundan, Sipariş Haritası yalnız sipariş listesinin üst çubuğundan, Çağrı Geçmişi
      // ise AYARLARIN üç kat dibinden (bir iş kaydı, ayar değil).
      final gidilen = <CekmeceGiris>[];
      await ekranaKoy(tester, cekmece('patron', onGiris: gidilen.add));

      expect(find.text('Borçlular'), findsOneWidget);
      expect(find.text('Çağrı Geçmişi'), findsOneWidget);
      expect(find.text('Sipariş Haritası'), findsOneWidget);

      await tester.tap(find.text('Çağrı Geçmişi'));
      await tester.pump();
      expect(gidilen, [CekmeceGiris.cagriGunlugu]);

      await kapat(tester);
    });

    testWidgets('YETKİSİ KAPALI satır HİÇ çizilmez (pasif değil)', (tester) async {
      // Kalıcı olarak kapalı bir kapıyı göstermek, kullanıcıya olmayan bir yol tarif etmektir
      // — bu dosyanın ve çekmecenin genel kuralı.
      await ekranaKoy(
        tester,
        cekmece('kurye', borclularGorunur: false, cagriGunluguGorunur: false),
      );

      expect(find.text('Borçlular'), findsNothing);
      expect(find.text('Çağrı Geçmişi'), findsNothing);
      // Kendi cihaz tercihleri KURYEDE DE açık: kapatılan hep DÜKKÂN VERİSİDİR.
      expect(find.text('Arayan Tanıma'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('lisans verisi YOKKEN kart yine çizilir ("bilinmiyor")', (tester) async {
      // Tasarımda `.lst-grid` DAİMA iki karttır (`s-bilesenler.jsx:110-123`); abonelik bu
      // uygulamanın omurgası, boş çekmeceden okunamaz. Sayı uydurulmaz: "—" basılır.
      await ekranaKoy(
        tester,
        SipCekmece(
          acik: true,
          onKapat: () {},
          isletmeAdi: 'Öz Pınar Su',
          rol: 'patron',
          onGiris: (_) {},
          onCikis: () {},
          onDestek: () {},
        ),
      );

      expect(find.byType(CekmeceIstatistikleri), findsOneWidget);
      expect(find.text('—'), findsOneWidget, reason: 'kalan gün UYDURULMAZ');
      expect(find.text('Lisans · bilinmiyor'), findsOneWidget,
          reason: 'çip bilinmediğini SÖYLER; boş bırakmak "lisansım ne oldu"yu cevapsız bırakır');

      await kapat(tester);
    });
  });

  group('Kurulum sihirbazı — s-sihirbaz.jsx', () {
    const kanal = MethodChannel('test/sihirbaz');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, (cagri) async => switch (cagri.method) {
                'status' => <String, dynamic>{
                    'sdkInt': 33,
                    'manufacturer': 'samsung',
                    'hasScreeningRole': true,
                    'hasContactsPermission': true,
                    'canDrawOverlays': true,
                    'hasNotificationPermission': true,
                  },
                'batteryGuide' => <String>['Pil ayarlarını açın'],
                _ => null,
              });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null);
    });

    testWidgets('ilerleme çubuğu adım ilerledikçe artar', (tester) async {
      await ekranaKoy(tester, const IzinSihirbazi(channel: kanal));

      // Karşılama adımında ilerleme çubuğu HENÜZ yok (CSS: .siz-karsilama'da bar çizilmez).
      expect(find.byType(SihirbazIlerleme), findsNothing);
      expect(find.text('Kuruluma Başla'), findsOneWidget);

      await tester.tap(find.text('Kuruluma Başla'));
      await tester.pump();

      double oran() => tester.widget<SihirbazIlerleme>(find.byType(SihirbazIlerleme)).oran;

      expect(find.text('Adım 1/6'), findsOneWidget);
      final ilk = oran();
      expect(ilk, greaterThan(0));

      // İzin verilmiş görünüyor → düğme "Devam"a döner ve adım ilerler.
      expect(find.text('İzin verildi'), findsOneWidget);
      await tester.tap(find.text('Devam'));
      await tester.pump();

      expect(find.text('Adım 2/6'), findsOneWidget);
      final ikinci = oran();
      expect(ikinci, greaterThan(ilk));

      await tester.tap(find.text('Devam'));
      await tester.pump();

      expect(oran(), greaterThan(ikinci));

      await kapat(tester);
    });

    testWidgets('geri düğmesi adımı ve ilerlemeyi geri alır', (tester) async {
      await ekranaKoy(tester, const IzinSihirbazi(channel: kanal));

      await tester.tap(find.text('Kuruluma Başla'));
      await tester.pump();
      await tester.tap(find.text('Devam'));
      await tester.pump();

      final ikinci =
          tester.widget<SihirbazIlerleme>(find.byType(SihirbazIlerleme)).oran;
      expect(find.text('Adım 2/6'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Geri'));
      await tester.pump();

      expect(find.text('Adım 1/6'), findsOneWidget);
      expect(tester.widget<SihirbazIlerleme>(find.byType(SihirbazIlerleme)).oran,
          lessThan(ikinci));

      await kapat(tester);
    });
  });

  group('İlk giriş damgası — sync_meta.setup_completed_at', () {
    // Tasarım girişten sonra sihirbazı KENDİLİĞİNDEN açar (`s-uygulama.jsx:56`) ve kabuğun
    // yerine tam ekran gösterir (`:61`). Kökün (main.dart) bunu bir kez yapmasının dayanağı
    // bu cihaz-yerel damgadır; kararı kilitleyen yer burası.
    test('damga yokken kurulum gerekli, damgalandıktan sonra gerekmez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await kurulumGerekliMi(db), isTrue, reason: 'ilk giriş');

      await kurulumuDamgala(db);

      expect(await kurulumGerekliMi(db), isFalse,
          reason: 'sihirbaz bir daha her girişte önüne dikilmez');
      expect((await db.syncState()).setupCompletedAt, isNotNull);
    });

    test('damga sunucuya gitmez — outbox\'a hiçbir şey düşmez', () async {
      // sync_meta cihaz-yerel bir satırdır; damga bir "olay" değil, yerel tercih.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await kurulumuDamgala(db);

      expect(await db.select(db.outbox).get(), isEmpty);
    });
  });

  group('Tema anahtarı — tema_deposu', () {
    testWidgets('koyuya alınınca context.sip.koyu true olur, jetonlar koyu tabloya geçer',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final tema = TemaKontrol(depo: TemaDeposu.bellek());
      addTearDown(tema.dispose);

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // GERÇEK kök widget ile kurulur: sınanan şey tam olarak `SipTokens` ThemeExtension'ının
      // main.dart'taki kök `MaterialApp`e doğru bağlanması. Sahte bir sarmalayıcı kurulsaydı
      // o bağ kopsa bile test yeşil kalırdı — yani asıl riski ıskalardı.
      await tester.pumpWidget(SiparioApp(db: db, tema: tema));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      // Oturum yok → giriş ekranı.
      expect(find.byType(LoginScreen), findsOneWidget);

      SipTokens jeton() => tester.element(find.byType(LoginScreen)).sip;

      // Varsayılan AÇIK.
      expect(jeton().koyu, isFalse);
      final acikBg = jeton().bg;

      await tema.ayarla(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // tema geçiş animasyonu

      expect(jeton().koyu, isTrue);
      expect(jeton().bg, isNot(acikBg), reason: 'ekran zemini koyu tabloya geçmeli');
      expect(jeton().accent, SipTokens.acik.accent,
          reason: 'accent iki temada da AYNI — durum renkleri tema değişince kaymaz');

      await tema.ayarla(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(jeton().koyu, isFalse);
      expect(jeton().bg, acikBg);

      await kapat(tester);
    });

    test('tercih depoya yazılır ve geri okunur (varsayılan AÇIK)', () async {
      final depo = TemaDeposu.bellek();
      expect(await depo.koyuMu(), isFalse, reason: 'hiç yazılmamışsa açık tema');

      await TemaKontrol(depo: depo).ayarla(true);
      expect(await depo.koyuMu(), isTrue);

      final yeni = TemaKontrol(depo: depo);
      await yeni.yukle();
      expect(yeni.value, isTrue, reason: 'açılışta kayıtlı tercih geri yüklenir');
    });
  });
}

/// Alt navigasyonun sekme durumunu tutan test kabuğu — gövde metni sekmeyle değişir.
class _NavKabugu extends StatefulWidget {
  const _NavKabugu({required this.onEkle, required this.baslangic});

  /// null → FAB pasif (abonelik kilidi).
  final VoidCallback? onEkle;
  final SipSekme baslangic;

  @override
  State<_NavKabugu> createState() => _NavKabuguState();
}

class _NavKabuguState extends State<_NavKabugu> {
  late SipSekme _aktif = widget.baslangic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sip.bg,
      body: Column(
        children: [
          Expanded(child: Center(child: Text('gövde: ${_aktif.name}'))),
          SipAltNav(
            aktif: _aktif,
            onSec: (s) => setState(() => _aktif = s),
            onEkle: widget.onEkle,
          ),
        ],
      ),
    );
  }
}
