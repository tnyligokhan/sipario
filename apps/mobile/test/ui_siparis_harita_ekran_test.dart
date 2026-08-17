// ROTA KONUMU + SİPARİŞ HARİTASI (kullanıcı isteği 2026-07-29).
//
// İki iş, tek dert: "Oto Sırala" nereden başlıyor ve o sıra yeryüzünde neye benziyor?
//
//  A. Oto sıralama kuryenin BULUNDUĞU noktadan başlar (`start`). Konum alınamazsa istek yine
//     gider ama kullanıcıya HANGİ KİPTE sıralandığı söylenir — sessiz bozulma yasak.
//  B. Harita ekranı açık siparişleri rota sırasında numaralı pinlerle çizer.
//
// Bu dosyadaki widget testleri AĞA ve PLATFORM KANALINA hiç uzanmaz: `cihazKonumuOku`,
// `rotaApiUret` ve `haritaKaroSaglayici` dikişleri sahtelenir. Sızan bir sahte bir sonraki testte
// sessizce yanlış sonuç üretir — üçü de tearDown'da geri alınır.


import 'package:drift/native.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/screens/orders/musteri_eylemleri.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';
import 'package:sipario/screens/orders/siparis_harita_ozet.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/harita_ortami.dart';
import 'support/siparis_yardimci.dart';


/// HARİTA EKRANI — pinler · kurye katmanı · karo sağlayıcı · boş durum.
///
/// Bölme gerekçesi: `ui_siparis_harita_test.dart` başlığı.

/// HARİTA EKRANI — PİNLER ve ÖZET SAYFASI.
///
/// Bölme gerekçesi: `ui_siparis_harita_test.dart` başlığı. Karo/kamera kontrolleri
/// `ui_siparis_harita_kontrol_test.dart`ta; ortak fikstür `support/harita_ortami.dart`.
void main() {
  group('Sipariş haritası — pinler ve özet', () {
    setUp(haritaDikisleriniSahtele);


    testWidgets('koordinatlı AÇIK siparişler numaralı pin olur; teslim edilen olmaz',
        (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.8900, lng: 30.7100, sira: 10);
        await siparisEkle(db,
            ad: 'Teslim Edilmiş', lat: 36.8700, lng: 30.7200, sira: 20, teslim: true);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.byType(DurakPini), findsNWidgets(2));
      expect(find.widgetWithText(DurakPini, '1'), findsOneWidget);
      expect(find.widgetWithText(DurakPini, '2'), findsOneWidget);
      expect(find.widgetWithText(DurakPini, '3'), findsNothing,
          reason: 'teslim edilmiş sipariş rotada bir durak değildir');
      // Üst başlıkta durak sayısı — kullanıcı haritayı saymak zorunda kalmasın.
      expect(find.text('2 durak · rota sırası'), findsOneWidget);
      // Konumsuz sipariş yok → bant hiç çizilmez.
      expect(find.byType(KonumsuzBant), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('konumsuz açık siparişin SAYISI bantta yazar', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
        await siparisEkle(db, ad: 'Konumsuz Müşteri', sira: 10);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.byType(DurakPini), findsOneWidget);
      // Metin SÖZLEŞMEDİR: sessizce yutulan sipariş, eksik koşulan rota demektir.
      expect(find.text('1 sipariş konumsuz — haritada yok'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('pine dokununca ÖZET açılır — detay ekranı AÇILMAZ', (tester) async {
      // Kullanıcı isteği 2026-07-29: pin doğrudan detaya gidiyordu. Kurye haritada önce "burada
      // ne var" sorusunu sorar; tam detay bir dokunuş uzakta durmalı, haritayı kaybettirmemeli.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
        await siparisEkle(db,
            ad: 'Mehmet Kaya',
            lat: 36.8900,
            lng: 30.7100,
            sira: 10,
            tutarKurus: 12500,
            not: 'Zili çalma, kapıyı tıklat');
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      // Harita müşteri ADI yazmaz — başlığın belirmesi sayfanın açıldığının kanıtıdır.
      expect(find.byType(DurakOzetGovde), findsNothing);
      await tester.tap(find.widgetWithText(DurakPini, '2'));
      await akisiBekle(tester, ms: 400);

      // Başlık dokunulan PİNİN numarasını taşır: yanlış pine dokunmak sık ve sessiz bir hatadır.
      expect(find.text('2. Durak · Mehmet Kaya'), findsOneWidget);
      expect(find.text(sipTutar(12500)), findsOneWidget);
      expect(find.text('Mehmet Kaya sokağı No: 1'), findsOneWidget);
      expect(find.textContaining('Zili çalma'), findsOneWidget);
      // Asıl sözleşme: DETAY açılmadı.
      expect(find.byType(SiparisDetayGovde), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('özetteki "Sipariş Detayı" detay sayfasını açar', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.8900, lng: 30.7100, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.widgetWithText(DurakPini, '1'));
      await akisiBekle(tester, ms: 400);

      await tester.tap(find.text('Sipariş Detayı'));
      await akisiBekle(tester, ms: 600);

      expect(find.byType(SiparisDetayGovde), findsOneWidget);
      // Detay özetin YERİNE geçer — iki sayfa üst üste kalsaydı geri dönmek iki dokunuş olurdu.
      expect(find.byType(DurakOzetGovde), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('"Yol Tarifi" geo: URI ile harici haritayı açar', (tester) async {
      // Koordinatlar `toStringAsFixed` ile yazılır: cihaz yereli virgüle geçse bile URI bozulmaz.
      final acilanlar = <Uri>[];
      final eskiAcici = uriAcici;
      uriAcici = (u) async {
        acilanlar.add(u);
        return true; // ilk aday açıldı → yedek (Google Maps web) hiç denenmez
      };
      addTearDown(() => uriAcici = eskiAcici);

      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.8900, lng: 30.7100, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.widgetWithText(DurakPini, '1'));
      await akisiBekle(tester, ms: 400);

      await tester.tap(find.text('Yol Tarifi'));
      await akisiBekle(tester, ms: 300);

      expect(acilanlar, hasLength(1));
      expect(acilanlar.single.scheme, 'geo');
      // Sıra ENLEM,BOYLAM — ters yazılmış bir çift kuryeyi başka bir ile gönderir.
      expect(acilanlar.single.toString(), startsWith('geo:36.890000,30.710000'));
      // Özet AÇIK kalır: kurye harici haritadan dönünce durağı yerinde bulmalı.
      expect(find.byType(DurakOzetGovde), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('telefonu OLAN müşteride "Ara" düğmesi tel: URI açar', (tester) async {
      final acilanlar = <Uri>[];
      final eskiAcici = uriAcici;
      uriAcici = (u) async {
        acilanlar.add(u);
        return true;
      };
      addTearDown(() => uriAcici = eskiAcici);

      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db,
            ad: 'Mehmet Kaya',
            lat: 36.8900,
            lng: 30.7100,
            sira: 0,
            telefon: '+905321112233');
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.widgetWithText(DurakPini, '1'));
      await akisiBekle(tester, ms: 400);

      await tester.tap(find.text('Ara'));
      await akisiBekle(tester, ms: 300);

      expect(acilanlar.single.toString(), 'tel:+905321112233');

      await ekraniKapat(tester);
    });

    testWidgets('telefonu OLMAYAN müşteride "Ara" düğmesi HİÇ çizilmez', (tester) async {
      // Hiçbir yere gitmeyen düğme çizilmez: tek başına duran pasif bir "Ara", kullanıcıya
      // uygulamanın bozuk olduğunu düşündürür (liste satırındaki ŞERİT farklı — orada düğmenin
      // kaybolması hizalamayı bozardı, bu yüzden orada pasif çizilir).
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.8900, lng: 30.7100, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.widgetWithText(DurakPini, '1'));
      await akisiBekle(tester, ms: 400);

      expect(find.text('Ara'), findsNothing);
      // Yol tarifi HER durakta vardır — koordinatsız sipariş zaten haritaya girmiyor.
      expect(find.text('Yol Tarifi'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('cihaz konumu pini özet AÇMAZ (o bir durak değil)', (tester) async {
      cihazKonumuOku =
          () async => const CihazKonumu(lat: 36.8850, lng: 30.7060, dogrulukM: 15);

      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.byType(CihazPini));
      await akisiBekle(tester, ms: 400);

      expect(find.byType(DurakOzetGovde), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('hiç durak yoksa boş durum çizilir, harita kurulmaz', (tester) async {
      // Veri yokken haritayı bir şehre sabitlemek kullanıcıya "pinlerim nerede" dedirtir.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Konumsuz Müşteri');
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Haritada gösterilecek sipariş yok'), findsOneWidget);
      expect(find.text('1 sipariş konumsuz — haritada yok'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('cihaz konumu alınabiliyorsa AYRI bir işaret çizilir', (tester) async {
      cihazKonumuOku =
          () async => const CihazKonumu(lat: 36.8850, lng: 30.7060, dogrulukM: 15);

      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.byType(CihazPini), findsOneWidget);
      // Cihaz bir DURAK değildir: numara almaz, durak sayısını da değiştirmez.
      expect(find.text('1 durak · rota sırası'), findsOneWidget);

      await ekraniKapat(tester);
    });

    // ───────────────────────────────────────────────────────────────────────────────────────
    // Stil ve kontroller (kullanıcı isteği 2026-07-29: "harita stili uygulamaya yakın olmalı,
    // gereksiz şeyler kaldırılmalı, harita butonları eklenmeli")
    // ───────────────────────────────────────────────────────────────────────────────────────

  });
}
