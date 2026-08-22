// TEK HESAP = TEK CİHAZ — düşürülen oturumun İSTEMCİ tarafı (kullanıcı kararı 2026-08-22).
//
// Sunucu tarafı `apps/api/tests/Feature/Api/TekCihazOturumuTest.php`ta kilitli: hesap yeni bir
// telefonda açılınca eski telefonun token'ı düşer ve o telefon 401 + `code` alır. BU DOSYA
// zincirin ikinci yarısını ölçer: uygulama o 401'i görünce kullanıcıyı giriş ekranına ALIYOR MU,
// SEBEBİNİ yazıyor mu, ve defteri SİLMEDEN mi yapıyor.
//
// ⚠️ NEDEN GERÇEK KÖK WİDGET (`SiparioApp`): karar kökte veriliyor (senkron akışını dinleyen tek
// yer orası). Sahte bir kabukla sınasaydık, kökteki dinleyici hiç bağlanmasa bile test yeşil
// kalırdı — "kill-switch widget'ın içindeyse özellik test edilemez" hatasının aynısı.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/main.dart';
import 'package:sipario/screens/home_shell.dart' show kurulumuDamgala;
import 'package:sipario/screens/login_screen.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/theme/tema_deposu.dart';

/// Her istekte aynı HTTP durumunu atan taşıma — sunucunun "seni tanımıyorum" cevabı.
class _RedApi implements SyncApi {
  _RedApi(this.durum, this.govde);
  final int durum;
  final String govde;
  int turSayaci = 0;

  @override
  Future<PushResponse> push(List<Map<String, Object?>> events) async {
    turSayaci++;
    throw SyncApiException('push', durum, govde);
  }

  @override
  Future<PullResponse> pull({required int since, int limit = 500}) async {
    turSayaci++;
    throw SyncApiException('pull', durum, govde);
  }
}

/// Oturumu AÇIK, kurulumu tamamlanmış bir cihaz. Bekleyen bir outbox kaydı da bırakır:
/// düşürmenin veriye dokunmadığını ölçebilmek için.
Future<AppDatabase> _oturumluCihaz() async {
  final db = AppDatabase(NativeDatabase.memory());
  await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(const SyncMetaCompanion(
    authToken: Value('eski-token'),
    userName: Value('Ahmet Patron'),
    userRole: Value('patron'),
    deviceId: Value('cihaz-1'),
    savedTenantCode: Value('merkezbayi'),
    savedUsername: Value('patron'),
  ));
  await kurulumuDamgala(db); // sihirbaz açılmasın (kabuk doğrudan çizilsin)
  return db;
}

/// Kökü kurar ve ilk senkron turunun bitmesini bekler.
Future<void> _kokuKur(WidgetTester tester, AppDatabase db, SyncApi api) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SiparioApp(db: db, tema: TemaKontrol(depo: TemaDeposu.bellek()), syncApi: api),
  );
  // Açılış oturum kontrolü + ilk tur DİSKE ve mikro-göreve gider: gerçek zaman gerekir.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pump();
  await tester.pump();
}

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // AĞ TETİĞİ SUSTURULUR. Oturum AÇIK bir kök kurduğumuz an `_startSync` connectivity_plus'ın
    // olay kanalına abone olur; testte o kanalın karşılığı yoktur ve `MissingPluginException`
    // ZONE'a düşer — servis onu yutsa bile test çerçevesi "beklenmedik istisna" sayıp DOSYANIN
    // TAMAMINI kırar. Kanalı boş bir uygulamayla kapatmak, sınadığımız şeyi (401 → giriş ekranı)
    // eklentiden bağımsız kılar.
    final mesajci = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    mesajci.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    mesajci.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => <String>['wifi'],
    );
  });

  testWidgets('401 + `oturum_baska_cihazda` → giriş ekranı açılır ve SEBEBİ yazar',
      (tester) async {
    final db = await _oturumluCihaz();
    addTearDown(db.close);

    await _kokuKur(
      tester,
      db,
      _RedApi(401, '{"message":"x","code":"oturum_baska_cihazda"}'),
    );

    expect(find.byType(LoginScreen), findsOneWidget,
        reason: 'düşürülen cihaz kabukta kalırsa sipariş yazar ve hiçbiri gitmez');
    expect(
      find.text('Hesabınız başka bir cihazda açıldı, bu cihazdaki oturum kapatıldı'),
      findsOneWidget,
      reason: 'sebepsiz çıkış, bu özelliğin bir numaralı destek çağrısı olurdu',
    );

    // Token gitti — ama "beni hatırla" kimliği DURUYOR (bir sonraki giriş kolay olsun).
    final meta = await db.syncState();
    expect(meta.authToken, isNull);
    expect(meta.savedTenantCode, 'merkezbayi');
    expect(meta.savedUsername, 'patron');

    await _kapat(tester);
  });

  testWidgets('kod gelmeyen 401 de giriş ekranına döner, ama BAŞKA bir cümleyle', (tester) async {
    // Sunucu 30 gün sonra düşen token satırını budar; o günden sonra gelen 401 çıplaktır.
    // "Başka bir cihazda açıldı" demek o durumda YALAN olurdu.
    final db = await _oturumluCihaz();
    addTearDown(db.close);

    await _kokuKur(tester, db, _RedApi(401, '{"message":"Unauthenticated."}'));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Oturumunuz sona erdi, yeniden giriş yapın'), findsOneWidget);
    expect(find.text('Hesabınız başka bir cihazda açıldı, bu cihazdaki oturum kapatıldı'),
        findsNothing);

    await _kapat(tester);
  });

  testWidgets('403 oturumu KAPATMAZ — kullanıcı kabukta kalır', (tester) async {
    // 403 "kimliğin geçersiz" demez, "bu isteğe yetkin yok" der (rol kapısı). Kuryeyi patrona
    // ait bir uç noktaya dokunduğu için dışarı atmak, çalışan bir oturumu yok etmek olurdu.
    final db = await _oturumluCihaz();
    addTearDown(db.close);

    await _kokuKur(tester, db, _RedApi(403, '{"message":"yetki yok"}'));

    expect(find.byType(LoginScreen), findsNothing);
    expect((await db.syncState()).authToken, 'eski-token');

    await _kapat(tester);
  });

  testWidgets('düşürme YEREL VERİYİ silmez — bekleyen outbox kaydı yerinde durur',
      (tester) async {
    // Kırmızı çizgi #3: hiçbir kayıt kaybolmaz. Eski telefonda gönderilmemiş kayıtlar kalmış
    // olabilir; aynı kullanıcı bu cihaza tekrar girdiğinde onlar kaldığı yerden akmalı.
    final db = await _oturumluCihaz();
    addTearDown(db.close);

    await db.into(db.outbox).insert(OutboxCompanion.insert(
          clientEventId: 'olay-1',
          entityType: 'customer',
          entityId: const Value('musteri-1'),
          op: 'upsert',
          payload: '{"id":"musteri-1","name":"Ahmet"}',
          occurredAt: '2026-08-22T10:00:00.000Z',
          createdAt: '2026-08-22T10:00:00.000Z',
        ));
    final oncekiSayi = (await db.select(db.outbox).get()).length;

    await _kokuKur(tester, db, _RedApi(401, '{"code":"oturum_baska_cihazda"}'));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect((await db.select(db.outbox).get()).length, oncekiSayi,
        reason: 'oturum düşmesi VERİ SİLME değildir');

    await _kapat(tester);
  });
}
