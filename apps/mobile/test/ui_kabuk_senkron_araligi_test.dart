// KABUK → SENKRON ARALIĞI KABLOLAMASI — "hesaplanıyor ama kimse çağırmıyor" kapısı.
//
// `SyncService.aralikDegistir`in KENDİ davranışı üç birim testiyle kilitli
// (`sync_yazim_tetigi_test.dart`: aynı değerde yeniden kurulum yok · durdurulmuş servisi
// diriltmez · tur atmaz). Kilitli OLMAYAN şey, kabuğun onu ÇAĞIRDIĞIYDI: `home_shell.dart`teki
// iki satır (paused dalında `arkaPlanAralik`, resumed dalında `onPlanAralik`) silinse o üç test
// de, yazım tetiğinin 14 testi de yeşil kalırdı — arka planda 30 sn'de bir uyanma sessizce geri
// gelir, kimse görmez.
//
// Bu deponun daha önce ödediği ders bu sınıftandır (2026-07-28): `sessizKontrol()` çalışıyor,
// yeni yapımı buluyor, bildirimleri dolduruyordu — ama bandı hiçbir ekran mount etmemişti.
// Boru hattının son halkası koptuğunda hiçbir şey çökmez, hiçbir şey de olmaz.
//
// BURADA ÖLÇÜLEN: kabuğun ÇAĞRIYI yapması. Çağrının ETKİSİ (zamanlayıcının gerçekten yeniden
// kurulması) birim testlerinin işi — widget testinde gerçek `Timer.periodic` kurdurmak
// "Timer is still pending" ile testi düşürürdü ve ölçtüğü şey zaten orada ölçülüyor.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/sync/sync_service.dart';
import 'package:sipario/theme/app_theme.dart';

/// Kabuğun senkron servisine yaptığı ÇAĞRILARI kaydeden vekil.
///
/// [aralikDegistir] gerçeğini de koşar (`super`): kabuk `start()` çağırmadığı için servis
/// durdurulmuş sayılır ve gerçek uygulama hiçbir `Timer` KURMAZ — widget testinde bekleyen
/// zamanlayıcı bırakmadan asıl kodun içinden geçmiş oluruz.
///
/// [syncNow] BİLEREK `super`e gitmez: `resumed` dalı bir tur atıyor ve o tur gerçek veritabanı
/// + gerçek HTTP taşıması demek olurdu. Burada sınanan tur DEĞİL, aralık çağrısıdır.
class _KayitliSync extends SyncService {
  _KayitliSync(super.db);

  final aralikCagrilari = <Duration>[];
  int syncNowSayaci = 0;

  @override
  void aralikDegistir(Duration every) {
    aralikCagrilari.add(every);
    super.aralikDegistir(every);
  }

  @override
  Future<SyncOutcome> syncNow() async {
    syncNowSayaci++;
    return const SyncOutcome(ok: true);
  }
}

Future<_KayitliSync> _kabuguKur(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  final sync = _KayitliSync(db);
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SipTheme.acik(),
    home: HomeShell(db: db, session: Session(db), sync: sync, onLoggedOut: () {}),
  ));
  await tester.pumpAndSettle();
  sync.aralikCagrilari.clear(); // kuruluş gürültüsü sayılmasın
  return sync;
}

/// Ekranı ağaçtan alır (bekleyen abonelik/zamanlayıcı testi asmasın) — bu deponun `_kapat` deseni.
Future<void> _ekraniKapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('Yaşam döngüsü → senkron aralığı (kablolama)', () {
    testWidgets('paused ARKA PLAN aralığına gevşetir', (tester) async {
      final sync = await _kabuguKur(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(sync.aralikCagrilari, contains(SyncService.arkaPlanAralik),
          reason: 'ekrana bakılmayan cihazda 30 sn\'de bir uyanmak pili boşuna yakar; '
              'kabuk bu çağrıyı yapmazsa aralık ön planda takılı kalır');
      expect(sync.syncNowSayaci, 0, reason: 'arka plana geçerken tur ATILMAZ');
    });

    testWidgets('hidden ve detached da arka plandır', (tester) async {
      final sync = await _kabuguKur(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(sync.aralikCagrilari, contains(SyncService.arkaPlanAralik));

      sync.aralikCagrilari.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      expect(sync.aralikCagrilari, contains(SyncService.arkaPlanAralik),
          reason: 'üç durum da "kullanıcı ekrana bakmıyor" demektir');
    });

    testWidgets('resumed ÖN PLAN aralığına döner ve tek tur atar', (tester) async {
      final sync = await _kabuguKur(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      sync.aralikCagrilari.clear();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(sync.aralikCagrilari, contains(SyncService.onPlanAralik),
          reason: 'patronun yazımı anında push ediliyor ama KURYE onu ancak kendi pull\'unda '
              'görür; öne gelen cihaz 2 dk\'da değil 30 sn\'de bakmalı');
      expect(sync.syncNowSayaci, 1,
          reason: 'öne gelişte TEK tur: `aralikDegistir` tur atmıyor, turu resumed dalı atıyor. '
              'İkisi birden atsaydı her öne gelişte çift istek olurdu');
    });

    testWidgets('inactive arka plan SAYILMAZ (bildirim perdesi / izin diyaloğu)', (tester) async {
      final sync = await _kabuguKur(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(sync.aralikCagrilari, isEmpty,
          reason: 'bildirim perdesini açmak da izin diyaloğu da `inactive` üretir — kullanıcı '
              'hâlâ uygulamanın başındadır. Burada aralığı gevşetmek, telefonu her elleyende '
              'senkronu yavaşlatırdı (konum sayacının aynı gerekçesi)');
      expect(sync.syncNowSayaci, 0, reason: 'inactive resumed değildir, tur da atılmaz');
    });

    testWidgets('arka plan ⇄ ön plan gidiş gelişi aralığı doğru sırada taşır', (tester) async {
      final sync = await _kabuguKur(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(sync.aralikCagrilari, [
        SyncService.arkaPlanAralik,
        SyncService.onPlanAralik,
        SyncService.arkaPlanAralik,
      ], reason: 'her geçişte bir çağrı — biri eksikse cihaz yanlış aralıkta takılı kalır');

      await _ekraniKapat(tester);
    });
  });
}
