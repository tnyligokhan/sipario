// BİLDİRİM KUTUSU — uygulama içi bildirim listesi (kullanıcı isteği 2026-08-21).
//
// Bu dosyanın kilitlediği DÖRT davranış; dördü de yanlış olduğunda ürün ya susar ya bağırır:
//   1. AYNI KİMLİK = AYNI SATIR. Kurallar gün damgalı kimlikler üretir ve AÇILIŞTA yeniden
//      koşar; her koşuda yeni satır açılsaydı kutu bir haftada yüzlerce kopyayla dolardı.
//   2. TAZELEME "OKUNDU"YU SİLMEZ. Silseydi bayi aynı uyarıyı bir daha asla kapatamazdı —
//      açılış taraması onu her seferinde okunmamışa çevirirdi.
//   3. KAPALI KATEGORİ KUTUYA GİRMEZ. Bayi kapattığı şeyi başka bir yerden geri görmemeli.
//   4. ERTELENEN/ATLANAN BİLDİRİM DE KUTUYA GİRER. Sessiz saatte doğan ya da günlük bütçeye
//      takılan bildirim bugüne kadar HİÇBİR yerde görünmüyordu; kutunun asıl kazancı budur.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/bildirim_kutusu.dart';
import 'package:sipario/screens/bildirimler_ekrani.dart';
import 'package:sipario/theme/app_theme.dart';

BildirimTaslagi _taslak({
  String kimlik = 'test-1',
  String baslik = 'Başlık',
  String govde = 'Gövde',
  BildirimKategori kategori = BildirimKategori.gunKapanisHatirlatma,
  String? yol,
}) =>
    BildirimTaslagi(
      kategori: kategori,
      baslik: baslik,
      govde: govde,
      kimlik: kimlik,
      yol: yol,
    );

/// Kategori kapatılabilen, hiçbir şey göstermeyen sahte servis.
class _SahteIcServis implements BildirimServisi {
  final gosterilenler = <String>[];
  final zamanlananlar = <String>[];
  final kapaliKategoriler = <BildirimKategori>{};

  @override
  Future<void> goster(BildirimTaslagi t) async => gosterilenler.add(t.kimlik);

  @override
  Future<void> zamanla(BildirimTaslagi t, DateTime neZaman) async =>
      zamanlananlar.add(t.kimlik);

  @override
  Future<void> iptal(String kimlik) async {}

  @override
  Future<bool> izinDurumu() async => true;

  @override
  Future<bool> izinIste() async => true;

  @override
  Future<bool> kategoriAcikMi(BildirimKategori k) async => !kapaliKategoriler.contains(k);
}

void main() {
  group('BildirimKutusu', () {
    test('yeni taslak satır açar; OKUNMAMIŞ doğar', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);

      await kutu.yaz(_taslak(), occurredAtIso: '2026-08-21T10:00:00.000Z');

      final hepsi = await kutu.watchHepsi().first;
      expect(hepsi, hasLength(1));
      expect(hepsi.single.okunduAt, isNull);
      expect(await kutu.watchOkunmamisSayisi().first, 1);
    });

    test('AYNI KİMLİK ikinci satır AÇMAZ, metni tazeler', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);

      await kutu.yaz(_taslak(baslik: '3 gün kapatılmadı'),
          occurredAtIso: '2026-08-21T10:00:00.000Z');
      await kutu.yaz(_taslak(baslik: '4 gün kapatılmadı'),
          occurredAtIso: '2026-08-22T10:00:00.000Z');

      final hepsi = await kutu.watchHepsi().first;
      expect(hepsi, hasLength(1));
      expect(hepsi.single.baslik, '4 gün kapatılmadı', reason: 'rakam değişmiş olabilir');
      expect(hepsi.single.occurredAt, '2026-08-21T10:00:00.000Z',
          reason: 'doğuş anı korunur; yoksa okunmuş satır her açılışta başa zıplardı');
    });

    test('⭐ TAZELEME "okundu"yu SİLMEZ', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      await kutu.yaz(_taslak(), occurredAtIso: '2026-08-21T10:00:00.000Z');
      await kutu.okunduIsaretle('test-1', okunduAtIso: '2026-08-21T11:00:00.000Z');

      await kutu.yaz(_taslak(baslik: 'yeni metin'),
          occurredAtIso: '2026-08-21T12:00:00.000Z');

      expect(await kutu.watchOkunmamisSayisi().first, 0,
          reason: 'açılış taraması aynı kimliği yeniden yazıyor; okundu damgası kalmalı');
    });

    test('okundu işaretleme damgayı İKİNCİ KEZ ilerletmez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      await kutu.yaz(_taslak(), occurredAtIso: '2026-08-21T10:00:00.000Z');
      await kutu.okunduIsaretle('test-1', okunduAtIso: '2026-08-21T11:00:00.000Z');
      await kutu.okunduIsaretle('test-1', okunduAtIso: '2026-08-21T18:00:00.000Z');

      final satir = (await kutu.watchHepsi().first).single;
      expect(satir.okunduAt, '2026-08-21T11:00:00.000Z',
          reason: 'okunma anı GERÇEKTEN okunduğu andır');
    });

    test('hepsiniOkunduIsaretle yalnız okunmamışlara yazar', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      await kutu.yaz(_taslak(kimlik: 'a'), occurredAtIso: '2026-08-21T10:00:00.000Z');
      await kutu.yaz(_taslak(kimlik: 'b'), occurredAtIso: '2026-08-21T11:00:00.000Z');
      await kutu.okunduIsaretle('a', okunduAtIso: '2026-08-21T10:30:00.000Z');

      await kutu.hepsiniOkunduIsaretle(okunduAtIso: '2026-08-21T20:00:00.000Z');

      final hepsi = await kutu.watchHepsi().first;
      expect(hepsi.firstWhere((b) => b.id == 'a').okunduAt, '2026-08-21T10:30:00.000Z');
      expect(hepsi.firstWhere((b) => b.id == 'b').okunduAt, '2026-08-21T20:00:00.000Z');
      expect(await kutu.watchOkunmamisSayisi().first, 0);
    });

    test('liste YENİDEN ESKİYE sıralıdır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      await kutu.yaz(_taslak(kimlik: 'eski'), occurredAtIso: '2026-08-20T10:00:00.000Z');
      await kutu.yaz(_taslak(kimlik: 'yeni'), occurredAtIso: '2026-08-21T10:00:00.000Z');

      expect((await kutu.watchHepsi().first).map((b) => b.id), ['yeni', 'eski']);
    });

    test('sınır aşılınca EN ESKİLER budanır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      for (var i = 0; i <= kBildirimKutusuSiniri; i++) {
        // Damga i büyüdükçe yenileşir → en eski 'b0' olur.
        await kutu.yaz(_taslak(kimlik: 'b$i'),
            occurredAtIso: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)).toIso8601String());
      }

      final hepsi = await kutu.watchHepsi(limit: 1000).first;
      expect(hepsi, hasLength(kBildirimKutusuSiniri));
      expect(hepsi.map((b) => b.id), isNot(contains('b0')));
    });
  });

  group('KutuluBildirimServisi', () {
    test('goster: kutuya YAZAR ve iç servise DEVREDER', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final ic = _SahteIcServis();
      final servis = KutuluBildirimServisi(ic, BildirimKutusu(db),
          simdi: () => DateTime.utc(2026, 8, 21, 10));

      await servis.goster(_taslak());

      expect(ic.gosterilenler, ['test-1']);
      expect(await BildirimKutusu(db).watchOkunmamisSayisi().first, 1);
    });

    test('⭐ ZAMANLANAN bildirim de kutuya girer (sessiz saatte kaybolmasın)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final ic = _SahteIcServis();
      final servis = KutuluBildirimServisi(ic, BildirimKutusu(db));

      await servis.zamanla(_taslak(), DateTime.utc(2026, 8, 22, 8));

      expect(ic.zamanlananlar, ['test-1']);
      expect(await BildirimKutusu(db).watchOkunmamisSayisi().first, 1,
          reason: 'taslak ŞU AN üretildi; ateşlenmeyi beklersek kutu hiç dolmaz');
    });

    test('KAPALI KATEGORİ kutuya GİRMEZ ama iç servise yine devredilir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final ic = _SahteIcServis()
        ..kapaliKategoriler.add(BildirimKategori.gunKapanisHatirlatma);
      final servis = KutuluBildirimServisi(ic, BildirimKutusu(db));

      await servis.goster(_taslak());

      expect(await BildirimKutusu(db).watchHepsi().first, isEmpty,
          reason: 'bayi kapattığı şeyi başka bir yerden geri görmemeli');
      // Devretmek zararsız: iç servis kendi kapısında zaten eleyecek. Sarmalayıcı ürün kararı
      // VERMEZ, yalnız kaydeder.
      expect(ic.gosterilenler, ['test-1']);
    });
  });

  // TEMİZLEME (kullanıcı isteği 2026-09-29: "bildirimleri temizleme özelliği gerekiyor").
  // Kilitlenen tuzak: kurallar gün damgalı kimliklerle AÇILIŞTA yeniden koşar. Satırı silmek
  // onu bir sonraki açılışta okunmamış olarak geri getirirdi; temizlik bu yüzden damgadır.
  group('BildirimKutusu — temizleme', () {
    test('temizlenen satır listeden ve rozetten düşer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      await kutu.yaz(_taslak(kimlik: 'a'), occurredAtIso: '2026-09-29T10:00:00.000Z');
      await kutu.yaz(_taslak(kimlik: 'b'), occurredAtIso: '2026-09-29T11:00:00.000Z');

      await kutu.temizle('a', anIso: '2026-09-29T12:00:00.000Z');

      expect((await kutu.watchHepsi().first).map((b) => b.id), ['b']);
      expect(await kutu.watchOkunmamisSayisi().first, 1,
          reason: 'listede görünmeyen bildirim için rozet yanmamalı');
    });

    test('⭐ açılış taraması AYNI bildirimi yeniden yazınca temizlenmiş kalır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      await kutu.yaz(_taslak(baslik: 'Dün gün kapatılmadı'),
          occurredAtIso: '2026-09-29T09:00:00.000Z');
      await kutu.hepsiniTemizle(anIso: '2026-09-29T09:05:00.000Z');

      await kutu.yaz(_taslak(baslik: 'Dün gün kapatılmadı'),
          occurredAtIso: '2026-09-29T09:30:00.000Z');

      expect(await kutu.watchHepsi().first, isEmpty,
          reason: 'bayi temizlediği uyarıyı yarım saat sonra geri görmemeli');
      expect(await kutu.watchOkunmamisSayisi().first, 0);
    });

    test('başlığı DEĞİŞEN temizlenmiş bildirim okunmamış olarak geri gelir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      await kutu.yaz(_taslak(baslik: 'Oto sıralama hakkınız azaldı'),
          occurredAtIso: '2026-09-29T09:00:00.000Z');
      await kutu.okunduIsaretle('test-1', okunduAtIso: '2026-09-29T09:01:00.000Z');
      await kutu.temizle('test-1', anIso: '2026-09-29T09:02:00.000Z');

      await kutu.yaz(_taslak(baslik: 'Oto sıralama hakkınız bitti'),
          occurredAtIso: '2026-09-29T15:00:00.000Z');

      final satir = (await kutu.watchHepsi().first).single;
      expect(satir.baslik, 'Oto sıralama hakkınız bitti');
      expect(satir.okunduAt, isNull, reason: 'durum değişti, bu bayi için yeni bir bilgi');
      expect(satir.occurredAt, '2026-09-29T15:00:00.000Z',
          reason: 'yeni bilgi listenin başına gelmeli');
    });

    test('hepsiniTemizle sonrasında gelen yeni bildirim listeye düşer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      await kutu.yaz(_taslak(kimlik: 'eski'), occurredAtIso: '2026-09-29T09:00:00.000Z');
      await kutu.hepsiniTemizle(anIso: '2026-09-29T10:00:00.000Z');

      await kutu.yaz(_taslak(kimlik: 'yeni'), occurredAtIso: '2026-09-29T11:00:00.000Z');

      expect((await kutu.watchHepsi().first).map((b) => b.id), ['yeni'],
          reason: 'temizlik geçmişe dönüktür, geleceği susturmaz');
    });
  });

  group('BildirimlerEkrani — temizleme yüzeyi', () {
    Future<AppDatabase> kur(WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kutu = BildirimKutusu(db);
      await kutu.yaz(_taslak(kimlik: 'a', baslik: 'Birinci uyarı'),
          occurredAtIso: DateTime.now().toUtc().toIso8601String());
      await kutu.yaz(_taslak(kimlik: 'b', baslik: 'İkinci uyarı'),
          occurredAtIso: DateTime.now().toUtc().toIso8601String());
      await tester.pumpWidget(
        MaterialApp(theme: SipTheme.acik(), home: BildirimlerEkrani(db: db)),
      );
      await tester.pumpAndSettle();
      return db;
    }

    Future<void> kapat(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('Temizle onay ister, onaylanınca liste boşalır', (tester) async {
      await kur(tester);

      await tester.tap(find.text('Temizle'));
      await tester.pumpAndSettle();
      expect(find.text('Bildirimler temizlensin mi?'), findsOneWidget);

      await tester.tap(find.text('Temizle').last);
      await tester.pumpAndSettle();

      expect(find.text('Birinci uyarı'), findsNothing);
      expect(find.text('İkinci uyarı'), findsNothing);
      expect(find.text('Bildirim yok'), findsOneWidget);
      expect(find.text('Temizle'), findsNothing, reason: 'boş listede etkisiz eylem sunulmaz');
      await kapat(tester);
    });

    testWidgets('Vazgeç listeye dokunmaz', (tester) async {
      await kur(tester);

      await tester.tap(find.text('Temizle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(find.text('Birinci uyarı'), findsOneWidget);
      expect(find.text('İkinci uyarı'), findsOneWidget);
      await kapat(tester);
    });

    testWidgets('satırı sola kaydırmak yalnız o satırı kaldırır', (tester) async {
      await kur(tester);

      await tester.drag(find.text('İkinci uyarı'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('İkinci uyarı'), findsNothing);
      expect(find.text('Birinci uyarı'), findsOneWidget);
      await kapat(tester);
    });
  });

  group('bildirimZamanEtiketi — saf', () {
    final simdi = DateTime(2026, 8, 21, 12);
    String et(DateTime an) => bildirimZamanEtiketi(an.toUtc().toIso8601String(), simdi: simdi);

    test('dakika · saat · dün · gün · tarih', () {
      expect(et(simdi.subtract(const Duration(seconds: 20))), 'şimdi');
      expect(et(simdi.subtract(const Duration(minutes: 5))), '5 dk önce');
      expect(et(simdi.subtract(const Duration(hours: 3))), '3 sa önce');
      expect(et(simdi.subtract(const Duration(days: 1))), 'Dün');
      expect(et(simdi.subtract(const Duration(days: 3))), '3 gün önce');
      expect(et(simdi.subtract(const Duration(days: 30))), '22.07');
    });

    test('bozuk damga boş döner — ekran çökmez', () {
      expect(bildirimZamanEtiketi('bozuk'), '');
    });
  });
}
