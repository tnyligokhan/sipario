// İŞLETME ekranı widget testlerinin paylaşılan yardımcıları.
//
// `ui_isletme_test.dart` 500 satır sınırını aşınca ikiye bölündü (`ui_isletme_ayarlar_test.dart`)
// ve bu yedi yardımcı iki dosyanın ORTAK dili olduğu için buraya taşındı. Kopyalamak yerine
// paylaşıldı: sahte zaman/akış bekleme kuralları bu projede acı çekilerek bulundu, iki kopya
// zamanla ayrışır ve bir dosya "yeşil" görünürken diğeri asılır.
//
// Kurallar (Dilim 1-3 dersleri):
//  • Widget-test sahte zamanında HER gerçek drift çağrısı `tester.runAsync` içinde beklenir —
//    düz `Future` sorgular da asılır.
//  • Akışa abone drift db widget-testte KAPATILMAZ (bellek-içi db süreç sonunda gider).
//  • Dar viewport'ta taşma olmasın diye ekran yükseltilir.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/theme/app_theme.dart';

/// Drift akışlarının çözülmesi için sahte zamanı [tur] kez ilerletir.
Future<void> akislariBekle(WidgetTester tester, {int tur = 4}) async {
  for (var i = 0; i < tur; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump();
  }
}

/// Ekranı uzun bir viewport'ta SİPARİO temasıyla çizer ve akışları bekler.
Future<void> ekranaKoy(WidgetTester tester, Widget ekran) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: SipTheme.acik(), home: ekran));
  await akislariBekle(tester);
}

/// Kapanış: ağacı boşalt + bekleyen zamanlayıcılar (toast/parıltı) sönsün.
Future<void> kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

/// Modal sheet'in açılma/kapanma kayma animasyonunu bitirir. Açılışta bu OLMADAN sheet ekranın
/// altında yarı yoldadır ve düğmesi viewport dışına düştüğü için `tap()` ıskalar; kapanışta ise
/// form alanları ağaçta kalır ve liste satırıyla aynı metni ikinci kez eşleştirir.
Future<void> sheetAnimasyonu(WidgetTester tester) async {
  // İlk kare rotayı yığına alır (animasyon değeri 0); kayma ancak SONRAKİ karede ilerler.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await akislariBekle(tester);
}

/// Sheet'in kaydırma alanındaki bir öğeye dokunur — gönder düğmesi katlamanın altında kalabilir.
Future<void> dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pump();
  await tester.tap(hedef);
  await akislariBekle(tester);
}

/// Bir alt sayfayı (sheet) tek başına açar — arkasındaki liste ekranının alanları
/// `find.byType(TextField)` sırasına karışmasın diye.
Future<void> sheetAc(
  WidgetTester tester,
  Future<void> Function(BuildContext ctx) ac,
) async {
  await ekranaKoy(
    tester,
    Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: () => ac(ctx), child: const Text('AÇ')),
        ),
      ),
    ),
  );
  await tester.tap(find.text('AÇ'));
  await sheetAnimasyonu(tester);
}

/// `users` aynasına kullanıcı ekler (kurye listesi/atama testleri için).
Future<void> kuryeEkle(
  AppDatabase db, {
  required String id,
  required String ad,
  String rol = 'kurye',
  String durum = 'active',
  String? telefon,
}) {
  return db.into(db.users).insert(UsersCompanion.insert(
        id: id,
        name: ad,
        role: rol,
        status: durum,
        phone: Value(telefon),
      ));
}
