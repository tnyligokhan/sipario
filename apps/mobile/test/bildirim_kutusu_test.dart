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
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/bildirim/bildirim_sozlesmesi.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/bildirim_kutusu.dart';
import 'package:sipario/screens/bildirimler_ekrani.dart' show bildirimZamanEtiketi;

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
